import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN_ROOT = ROOT / "data" / "board_runs"
OUT = ROOT / "data" / "board_results.csv"


def latest_passing_run(arch_dir: Path):
    candidates = sorted([p for p in arch_dir.iterdir() if p.is_dir()], reverse=True)
    for run_dir in candidates:
        uart_json = run_dir / "uart.json"
        if not uart_json.exists():
            continue
        data = json.loads(uart_json.read_text(encoding="utf-8"))
        if data.get("passed"):
            return run_dir, data
    return None, None


def main():
    rows = []
    if not RUN_ROOT.exists():
        return

    for arch_dir in sorted([p for p in RUN_ROOT.iterdir() if p.is_dir()]):
        run_dir, data = latest_passing_run(arch_dir)
        if run_dir is None:
            continue
        for case in data.get("cases", []):
            rows.append(
                {
                    "arch": arch_dir.name,
                    "run_id": run_dir.name,
                    "arch_id": data.get("arch_id"),
                    "started_at": data.get("started_at"),
                    "completed_at": data.get("completed_at"),
                    "case_name": case.get("name"),
                    "length": case.get("length"),
                    "cycles": case.get("cycles"),
                    "mismatches": case.get("mismatches"),
                    "status_hex": case.get("status_hex"),
                    "passed": data.get("passed"),
                    "failures": data.get("summary", {}).get("failures"),
                    "log_path": str((run_dir / "uart.log").relative_to(ROOT)).replace("\\", "/"),
                    "json_path": str((run_dir / "uart.json").relative_to(ROOT)).replace("\\", "/"),
                }
            )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.DictWriter(
            fp,
            fieldnames=[
                "arch",
                "run_id",
                "arch_id",
                "started_at",
                "completed_at",
                "case_name",
                "length",
                "cycles",
                "mismatches",
                "status_hex",
                "passed",
                "failures",
                "log_path",
                "json_path",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
