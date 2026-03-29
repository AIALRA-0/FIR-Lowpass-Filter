import csv
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "vivado"
OUT = ROOT / "data" / "impl_results.csv"
SPEC = json.loads((ROOT / "spec" / "spec.json").read_text(encoding="utf-8"))
FLOAT_SUMMARY = json.loads((ROOT / "data" / "floating_design_summary.json").read_text(encoding="utf-8"))


TOP_META = {
    "fir_symm_base": {"arch": "symmetry_folded", "samples_per_cycle": 1, "latency_cycles": 1},
    "fir_pipe_systolic": {"arch": "pipelined_systolic", "samples_per_cycle": 1, "latency_cycles": (FLOAT_SUMMARY["final_design"]["taps"] + 1) // 2},
    "fir_l2_polyphase": {"arch": "l2_polyphase", "samples_per_cycle": 2, "latency_cycles": 1},
    "fir_l3_polyphase": {"arch": "l3_polyphase", "samples_per_cycle": 3, "latency_cycles": 1},
    "fir_l3_pipe": {"arch": "l3_pipeline", "samples_per_cycle": 3, "latency_cycles": 3},
}


def parse_utilization(report_path: Path):
    text = report_path.read_text(encoding="utf-8", errors="ignore")
    lut = int(re.search(r"\|\s*Slice LUTs\s*\|\s*(\d+)", text).group(1))
    ff = int(re.search(r"\|\s*Slice Registers\s*\|\s*(\d+)", text).group(1))
    dsp = int(re.search(r"\|\s*DSPs\s*\|\s*(\d+)", text).group(1))
    bram_match = re.search(r"\|\s*Block RAM Tile\s*\|\s*([\d\.]+)", text)
    bram = float(bram_match.group(1)) if bram_match else 0.0
    return lut, ff, dsp, bram


def parse_timing(report_path: Path):
    lines = report_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    target_period = 5.0
    wns = None
    tns = None
    for idx, line in enumerate(lines):
        if "WNS(ns)" in line and idx + 2 < len(lines):
            candidate = lines[idx + 2].strip()
            parts = candidate.split()
            if len(parts) >= 2:
                wns = float(parts[0])
                tns = float(parts[1])
                break
    if wns is None:
        raise RuntimeError(f"Failed to parse WNS/TNS from {report_path}")
    fmax_mhz = 1000.0 / (target_period - wns)
    return target_period, wns, tns, fmax_mhz


def parse_power(report_path: Path):
    text = report_path.read_text(encoding="utf-8", errors="ignore")
    total = float(re.search(r"Total On-Chip Power \(W\)\s*\|\s*([\d\.]+)", text).group(1))
    dynamic = float(re.search(r"Dynamic \(W\)\s*\|\s*([\d\.]+)", text).group(1))
    static = float(re.search(r"Static Power\s*\|\s*([\d\.]+)", text).group(1))
    return total, dynamic, static


def collect_row(top_name: str):
    build_dir = BUILD / top_name
    util = build_dir / "utilization.rpt"
    timing = build_dir / "timing_summary.rpt"
    power = build_dir / "power.rpt"
    if not (util.exists() and timing.exists() and power.exists()):
        return None

    lut, ff, dsp, bram = parse_utilization(util)
    target_period, wns, tns, fmax_mhz = parse_timing(timing)
    power_total, power_dynamic, power_static = parse_power(power)
    meta = TOP_META[top_name]
    throughput_msps = meta["samples_per_cycle"] * fmax_mhz
    energy_per_sample_nj = (power_total / (throughput_msps * 1e6)) * 1e9
    return {
        "top": top_name,
        "architecture": meta["arch"],
        "part": SPEC["target_part"],
        "taps": FLOAT_SUMMARY["final_design"]["taps"],
        "samples_per_cycle": meta["samples_per_cycle"],
        "latency_cycles": meta["latency_cycles"],
        "target_period_ns": target_period,
        "wns_ns": wns,
        "tns_ns": tns,
        "fmax_mhz_est": round(fmax_mhz, 3),
        "throughput_msps_est": round(throughput_msps, 3),
        "lut": lut,
        "ff": ff,
        "dsp": dsp,
        "bram": bram,
        "power_total_w": power_total,
        "power_dynamic_w": power_dynamic,
        "power_static_w": power_static,
        "energy_per_sample_nj_est": round(energy_per_sample_nj, 6),
        "report_dir": str(build_dir.relative_to(ROOT)).replace("\\", "/"),
    }


def main():
    rows = []
    for top_name in TOP_META:
        row = collect_row(top_name)
        if row is not None:
            rows.append(row)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.DictWriter(fp, fieldnames=list(rows[0].keys()) if rows else [])
        if rows:
            writer.writeheader()
            writer.writerows(rows)


if __name__ == "__main__":
    main()
