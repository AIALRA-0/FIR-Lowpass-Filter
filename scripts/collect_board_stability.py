from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN_ROOT = ROOT / "data" / "board_runs"
ANALYSIS_DIR = ROOT / "data" / "analysis"


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    run_records: dict[str, list[dict[str, object]]] = defaultdict(list)
    case_stats: dict[tuple[str, str], dict[str, object]] = defaultdict(
        lambda: {
            "run_ids": [],
            "length": None,
            "cycles": [],
            "mismatch_sum": 0,
            "error_status_count": 0,
            "case_observations": 0,
            "passed_case_observations": 0,
        }
    )
    arch_stats: dict[str, dict[str, object]] = defaultdict(
        lambda: {
            "run_ids": [],
            "total_runs": 0,
            "passed_runs": 0,
            "summary_failures_total": 0,
        }
    )

    if not RUN_ROOT.exists():
        return

    for arch_dir in sorted(path for path in RUN_ROOT.iterdir() if path.is_dir()):
        for run_dir in sorted(path for path in arch_dir.iterdir() if path.is_dir()):
            uart_json = run_dir / "uart.json"
            if not uart_json.exists():
                continue
            data = json.loads(uart_json.read_text(encoding="utf-8"))
            arch = arch_dir.name
            summary = data.get("summary") or {}
            run_records[arch].append(
                {
                    "run_id": run_dir.name,
                    "passed": bool(data.get("passed")),
                    "case_count": int(summary.get("case_count", 0) or 0),
                    "failures": int(summary.get("failures", 0) or 0),
                    "cases": data.get("cases", []),
                }
            )
            arch_stats[arch]["total_runs"] += 1
            arch_stats[arch]["run_ids"].append(run_dir.name)
            arch_stats[arch]["summary_failures_total"] += int(summary.get("failures", 0) or 0)
            if data.get("passed"):
                arch_stats[arch]["passed_runs"] += 1

            for case in data.get("cases", []):
                key = (arch, str(case.get("name")))
                stat = case_stats[key]
                stat["run_ids"].append(run_dir.name)
                stat["length"] = int(case.get("length", 0) or 0)
                stat["cycles"].append(int(case.get("cycles", 0) or 0))
                stat["mismatch_sum"] += int(case.get("mismatches", 0) or 0)
                stat["case_observations"] += 1
                if data.get("passed"):
                    stat["passed_case_observations"] += 1
                if int(str(case.get("status_hex", "0")), 16) & 0x4:
                    stat["error_status_count"] += 1

    arch_rows = []
    for arch, stat in sorted(arch_stats.items()):
        total_runs = int(stat["total_runs"])
        passed_runs = int(stat["passed_runs"])
        arch_rows.append(
            {
                "arch": arch,
                "total_runs": total_runs,
                "passed_runs": passed_runs,
                "pass_rate_pct": round((passed_runs / total_runs) * 100.0, 3) if total_runs else 0.0,
                "summary_failures_total": int(stat["summary_failures_total"]),
                "latest_run_id": max(stat["run_ids"]) if stat["run_ids"] else "",
            }
        )

    case_rows = []
    for (arch, case_name), stat in sorted(case_stats.items()):
        cycles = [int(value) for value in stat["cycles"]]
        observations = int(stat["case_observations"])
        case_rows.append(
            {
                "arch": arch,
                "case_name": case_name,
                "length": int(stat["length"] or 0),
                "observations": observations,
                "passed_case_observations": int(stat["passed_case_observations"]),
                "cycles_min": min(cycles) if cycles else "",
                "cycles_mean": round(sum(cycles) / len(cycles), 3) if cycles else "",
                "cycles_max": max(cycles) if cycles else "",
                "mismatch_sum": int(stat["mismatch_sum"]),
                "error_status_count": int(stat["error_status_count"]),
                "latest_run_id": max(stat["run_ids"]) if stat["run_ids"] else "",
            }
        )

    write_csv(
        ANALYSIS_DIR / "board_stability_arch.csv",
        arch_rows,
        ["arch", "total_runs", "passed_runs", "pass_rate_pct", "summary_failures_total", "latest_run_id"],
    )
    write_csv(
        ANALYSIS_DIR / "board_stability_cases.csv",
        case_rows,
        [
            "arch",
            "case_name",
            "length",
            "observations",
            "passed_case_observations",
            "cycles_min",
            "cycles_mean",
            "cycles_max",
            "mismatch_sum",
            "error_status_count",
            "latest_run_id",
        ],
    )

    recent_arch_rows = []
    recent_case_rows = []
    for arch, runs in sorted(run_records.items()):
        passed_runs = [run for run in runs if run["passed"]]
        if not passed_runs:
            continue
        expected_case_count = max(int(run["case_count"]) for run in passed_runs)
        recent_runs = sorted(
            [run for run in passed_runs if int(run["case_count"]) == expected_case_count],
            key=lambda item: str(item["run_id"]),
            reverse=True,
        )[:3]
        recent_runs = list(reversed(recent_runs))
        if not recent_runs:
            continue

        recent_arch_rows.append(
            {
                "arch": arch,
                "expected_case_count": expected_case_count,
                "window_runs": len(recent_runs),
                "all_passed": all(bool(run["passed"]) for run in recent_runs),
                "run_ids": ",".join(str(run["run_id"]) for run in recent_runs),
            }
        )

        recent_case_stats: dict[str, dict[str, object]] = defaultdict(
            lambda: {
                "length": 0,
                "cycles": [],
                "mismatch_sum": 0,
                "error_status_count": 0,
            }
        )
        for run in recent_runs:
            for case in run["cases"]:
                stat = recent_case_stats[str(case.get("name"))]
                stat["length"] = int(case.get("length", 0) or 0)
                stat["cycles"].append(int(case.get("cycles", 0) or 0))
                stat["mismatch_sum"] += int(case.get("mismatches", 0) or 0)
                if int(str(case.get("status_hex", "0")), 16) & 0x4:
                    stat["error_status_count"] += 1

        for case_name, stat in sorted(recent_case_stats.items()):
            cycles = [int(value) for value in stat["cycles"]]
            recent_case_rows.append(
                {
                    "arch": arch,
                    "case_name": case_name,
                    "length": int(stat["length"]),
                    "window_runs": len(recent_runs),
                    "cycles_min": min(cycles) if cycles else "",
                    "cycles_mean": round(sum(cycles) / len(cycles), 3) if cycles else "",
                    "cycles_max": max(cycles) if cycles else "",
                    "mismatch_sum": int(stat["mismatch_sum"]),
                    "error_status_count": int(stat["error_status_count"]),
                    "run_ids": ",".join(str(run["run_id"]) for run in recent_runs),
                }
            )

    write_csv(
        ANALYSIS_DIR / "board_stability_recent_arch.csv",
        recent_arch_rows,
        ["arch", "expected_case_count", "window_runs", "all_passed", "run_ids"],
    )
    write_csv(
        ANALYSIS_DIR / "board_stability_recent_cases.csv",
        recent_case_rows,
        [
            "arch",
            "case_name",
            "length",
            "window_runs",
            "cycles_min",
            "cycles_mean",
            "cycles_max",
            "mismatch_sum",
            "error_status_count",
            "run_ids",
        ],
    )


if __name__ == "__main__":
    main()
