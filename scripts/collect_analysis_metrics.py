from __future__ import annotations

import csv
import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
ANALYSIS_DIR = DATA_DIR / "analysis"
IMPL_RESULTS = DATA_DIR / "impl_results.csv"
FIXED_SWEEP = DATA_DIR / "fixedpoint_sweep.csv"
DESIGN_SPACE = DATA_DIR / "design_space.csv"
FLOAT_SUMMARY = json.loads((DATA_DIR / "floating_design_summary.json").read_text(encoding="utf-8"))
FIXED_SUMMARY = json.loads((DATA_DIR / "fixed_design_summary.json").read_text(encoding="utf-8"))
SPEC = json.loads((ROOT / "spec" / "spec.json").read_text(encoding="utf-8"))

SYSTEM_REPORTS = {
    "zu4ev_fir_pipe_systolic_top": {
        "scope": "board_shell",
        "arch": "board_shell_custom",
        "timing_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_pipe_systolic_top" / "zu4ev_fir_pipe_systolic_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_timing_summary_routed.rpt",
        "power_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_pipe_systolic_top" / "zu4ev_fir_pipe_systolic_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_power_routed.rpt",
        "route_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_pipe_systolic_top" / "zu4ev_fir_pipe_systolic_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_route_status.rpt",
    },
    "zu4ev_fir_vendor_top": {
        "scope": "board_shell",
        "arch": "board_shell_vendor_ip",
        "timing_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_vendor_top" / "zu4ev_fir_vendor_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_timing_summary_routed.rpt",
        "power_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_vendor_top" / "zu4ev_fir_vendor_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_power_routed.rpt",
        "route_report": ROOT / "build" / "zu4ev_system" / "zu4ev_fir_vendor_top" / "zu4ev_fir_vendor_top.runs" / "impl_1" / "fir_mpsoc_system_wrapper_route_status.rpt",
    },
}


def parse_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as fp:
        return list(csv.DictReader(fp))


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def int_bits_needed(max_abs_value: int) -> int:
    if max_abs_value <= 0:
        return 1
    return math.floor(math.log2(max_abs_value)) + 2


def parse_top_path_metrics(report_path: Path) -> dict[str, object]:
    text = report_path.read_text(encoding="utf-8", errors="ignore")
    source_match = re.search(r"Source:\s+([^\r\n]+)", text)
    dest_match = re.search(r"Destination:\s+([^\r\n]+)", text)
    data_match = re.search(
        r"Data Path Delay:\s+([\d\.]+)ns\s+\(logic\s+([\d\.]+)ns.*?route\s+([\d\.]+)ns",
        text,
        re.DOTALL,
    )
    logic_levels_match = re.search(r"Logic Levels:\s+(\d+)", text)
    wns_match = re.search(r"Setup\s*:\s*\d+\s+Failing Endpoints,\s+Worst Slack\s+([-\d\.]+)ns", text)
    req_match = re.search(r"Requirement:\s+([\d\.]+)ns", text)

    if not (source_match and dest_match and data_match and logic_levels_match and wns_match and req_match):
        raise RuntimeError(f"Failed to parse timing path metrics from {report_path}")

    data_delay = float(data_match.group(1))
    logic_delay = float(data_match.group(2))
    route_delay = float(data_match.group(3))
    return {
        "source": source_match.group(1).strip(),
        "destination": dest_match.group(1).strip(),
        "requirement_ns": float(req_match.group(1)),
        "wns_ns": float(wns_match.group(1)),
        "data_path_delay_ns": data_delay,
        "logic_delay_ns": logic_delay,
        "route_delay_ns": route_delay,
        "route_fraction_pct": round((route_delay / data_delay) * 100.0, 3) if data_delay else 0.0,
        "logic_fraction_pct": round((logic_delay / data_delay) * 100.0, 3) if data_delay else 0.0,
        "logic_levels": int(logic_levels_match.group(1)),
    }


def parse_power_metrics(report_path: Path) -> dict[str, object]:
    text = report_path.read_text(encoding="utf-8", errors="ignore")

    def grab(pattern: str) -> float:
        match = re.search(pattern, text)
        if match is None:
            raise RuntimeError(f"Failed to parse pattern {pattern!r} from {report_path}")
        return float(match.group(1))

    def grab_optional_component(name: str) -> float:
        match = re.search(rf"\|\s*{re.escape(name)}\s*\|\s*([\d\.<>]+)", text)
        if match is None:
            return 0.0
        token = match.group(1).replace("<", "")
        return float(token)

    def grab_hierarchy(name: str) -> float:
        match = re.search(rf"\|\s*{re.escape(name)}\s*\|\s*([\d\.]+)\s*\|", text)
        if match is None:
            return 0.0
        return float(match.group(1))

    confidence_match = re.search(r"\|\s*Overall confidence level\s*\|\s*([A-Za-z]+)", text)
    if confidence_match is None:
        raise RuntimeError(f"Failed to parse confidence level from {report_path}")

    return {
        "power_total_w": grab(r"Total On-Chip Power \(W\)\s*\|\s*([\d\.]+)"),
        "power_dynamic_w": grab(r"Dynamic \(W\)\s*\|\s*([\d\.]+)"),
        "power_static_w": grab(r"Device Static \(W\)\s*\|\s*([\d\.]+)"),
        "clock_power_w": grab_optional_component("Clocks"),
        "clb_logic_power_w": grab_optional_component("CLB Logic"),
        "signals_power_w": grab_optional_component("Signals"),
        "bram_power_w": grab_optional_component("Block RAM"),
        "dsp_power_w": grab_optional_component("DSPs"),
        "ps8_power_w": grab_optional_component("PS8"),
        "ps_static_w": grab_optional_component("PS Static"),
        "pl_static_w": grab_optional_component("PL Static"),
        "hier_ps_w": grab_hierarchy("ps_0"),
        "hier_fir_shell_w": grab_hierarchy("fir_shell_0"),
        "hier_dma_w": grab_hierarchy("axi_dma_0"),
        "hier_ctrl_w": grab_hierarchy("ctrl_smc"),
        "hier_data_ic_w": grab_hierarchy("data_ic"),
        "confidence_level": confidence_match.group(1),
    }


def parse_route_status(report_path: Path) -> dict[str, object]:
    text = report_path.read_text(encoding="utf-8", errors="ignore")

    def grab(pattern: str) -> int:
        match = re.search(pattern, text)
        if match is None:
            raise RuntimeError(f"Failed to parse pattern {pattern!r} from {report_path}")
        return int(match.group(1))

    logical_nets = grab(r"# of logical nets.*?:\s+(\d+)")
    routable_nets = grab(r"# of routable nets.*?:\s+(\d+)")
    fully_routed_nets = grab(r"# of fully routed nets.*?:\s+(\d+)")
    routing_errors = grab(r"# of nets with routing errors.*?:\s+(\d+)")
    return {
        "logical_nets": logical_nets,
        "routable_nets": routable_nets,
        "fully_routed_nets": fully_routed_nets,
        "routing_errors": routing_errors,
        "fully_routed_pct": round((fully_routed_nets / routable_nets) * 100.0, 3) if routable_nets else 0.0,
    }


def emit_efficiency_metrics() -> None:
    rows = []
    for row in parse_csv(IMPL_RESULTS):
        throughput = float(row["throughput_msps_est"])
        lut = int(float(row["lut"]))
        dsp = int(float(row["dsp"]))
        power_total = float(row["power_total_w"])
        rows.append(
            {
                "top": row["top"],
                "architecture": row["architecture"],
                "scope": "board_shell" if row["architecture"].startswith("board_shell") else "kernel",
                "samples_per_cycle": int(float(row["samples_per_cycle"])),
                "latency_cycles": int(float(row["latency_cycles"])),
                "fmax_mhz_est": float(row["fmax_mhz_est"]),
                "throughput_msps_est": throughput,
                "lut": lut,
                "dsp": dsp,
                "power_total_w": power_total,
                "energy_per_sample_nj_est": float(row["energy_per_sample_nj_est"]),
                "throughput_per_dsp_msps": round(throughput / dsp, 6) if dsp else "",
                "throughput_per_klut_msps": round(throughput / (lut / 1000.0), 6) if lut else "",
                "throughput_per_w_msps": round(throughput / power_total, 6) if power_total else "",
            }
        )
    write_csv(
        ANALYSIS_DIR / "efficiency_metrics.csv",
        rows,
        [
            "top",
            "architecture",
            "scope",
            "samples_per_cycle",
            "latency_cycles",
            "fmax_mhz_est",
            "throughput_msps_est",
            "lut",
            "dsp",
            "power_total_w",
            "energy_per_sample_nj_est",
            "throughput_per_dsp_msps",
            "throughput_per_klut_msps",
            "throughput_per_w_msps",
        ],
    )


def emit_quantization_threshold() -> None:
    rows = []
    selected_output_width = int(FIXED_SUMMARY["output_width"])
    for row in parse_csv(FIXED_SWEEP):
        if int(row["output_width"]) != selected_output_width:
            continue
        rows.append(
            {
                "design_id": row["design_id"],
                "coef_width": int(row["coef_width"]),
                "output_width": int(row["output_width"]),
                "ap_db": float(row["ap_db"]),
                "ast_db": float(row["ast_db"]),
                "overflow_count": int(row["overflow_count"]),
                "acc_width": int(row["acc_width"]),
                "meets_fixed": int(row["meets_fixed"]),
            }
        )
    rows.sort(key=lambda item: item["coef_width"])
    write_csv(
        ANALYSIS_DIR / "quantization_threshold.csv",
        rows,
        ["design_id", "coef_width", "output_width", "ap_db", "ast_db", "overflow_count", "acc_width", "meets_fixed"],
    )


def emit_design_tradeoffs() -> None:
    rows = parse_csv(DESIGN_SPACE)

    def choose_row(design_group: str, method: str | None = None, meets_spec: int | None = None) -> dict[str, object]:
        candidates = [row for row in rows if row["design_group"] == design_group]
        if method is not None:
            candidates = [row for row in candidates if row["method"] == method]
        if meets_spec is not None:
            candidates = [row for row in candidates if int(row["meets_spec"]) == meets_spec]
        if not candidates:
            raise RuntimeError(f"No candidates for design_group={design_group}, method={method}, meets_spec={meets_spec}")
        candidates.sort(key=lambda row: (int(row["order"]), float(row["ap_db"])))
        chosen = candidates[0]
        return {
            "design_id": chosen["design_id"],
            "design_group": chosen["design_group"],
            "method": chosen["method"],
            "order": int(chosen["order"]),
            "taps": int(chosen["taps"]),
            "ap_db": float(chosen["ap_db"]),
            "ast_db": float(chosen["ast_db"]),
            "meets_spec": int(chosen["meets_spec"]),
        }

    summary = {
        "baseline_taps100_best_firpm": choose_row("baseline_taps100", method="firpm"),
        "baseline_order100_best_firpm": choose_row("baseline_order100", method="firpm"),
        "final_spec_selected": choose_row("final_spec", method="firpm", meets_spec=1),
    }
    (ANALYSIS_DIR / "design_tradeoff_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def emit_bitwidth_derivation() -> None:
    selected = FIXED_SUMMARY
    input_width = int(SPEC["fixed_point"]["input_width"])
    coef_width = int(selected["coef_width"])
    output_width = int(selected["output_width"])
    acc_width = int(selected["acc_width"])
    preadd_guard = int(SPEC["fixed_point"]["guard_bits_preadd"])
    taps = int(FLOAT_SUMMARY["final_design"]["taps"])
    unique_mult = (taps + 1) // 2

    sweep_rows = parse_csv(FIXED_SWEEP)
    matching_row = next(
        (
            row
            for row in sweep_rows
            if int(row["coef_width"]) == coef_width and int(row["output_width"]) == output_width
        ),
        None,
    )
    if matching_row is None:
        raise RuntimeError("Failed to locate selected fixed-point row in fixedpoint_sweep.csv")

    coeff_path = ROOT / "coeffs" / f"final_fixed_q{coef_width}_full.memh"
    coeff_values = []
    for line in coeff_path.read_text(encoding="utf-8").splitlines():
        token = line.strip()
        if not token:
            continue
        raw = int(token, 16)
        if raw & (1 << (coef_width - 1)):
            raw -= 1 << coef_width
        coeff_values.append(raw)

    frac_bits = coef_width - 1
    sum_abs_int = sum(abs(value) for value in coeff_values)
    sum_int = sum(coeff_values)
    max_input_int = (1 << (input_width - 1)) - 1
    conservative_acc_bound = max_input_int * sum_abs_int
    observed_max_abs_acc = int(matching_row["max_abs_acc"])
    preadd_width = input_width + preadd_guard
    preadd_max = (1 << (input_width - 1)) - 1
    preadd_abs_bound = preadd_max * 2
    product_abs_bound = preadd_abs_bound * max(abs(value) for value in coeff_values)

    payload = {
        "input_width": input_width,
        "coef_width": coef_width,
        "output_width": output_width,
        "acc_width": acc_width,
        "preadd_guard_bits": preadd_guard,
        "taps": taps,
        "unique_multipliers": unique_mult,
        "preadd_width": preadd_width,
        "product_width_conservative": preadd_width + coef_width,
        "sum_coeff_int": sum_int,
        "sum_abs_coeff_int": sum_abs_int,
        "sum_coeff_float": sum_int / float(1 << frac_bits),
        "sum_abs_coeff_float": sum_abs_int / float(1 << frac_bits),
        "max_input_int": max_input_int,
        "preadd_abs_bound_int": preadd_abs_bound,
        "product_abs_bound_int": product_abs_bound,
        "product_bits_conservative": int_bits_needed(product_abs_bound),
        "conservative_acc_bound_int": conservative_acc_bound,
        "conservative_acc_bits": int_bits_needed(conservative_acc_bound),
        "observed_max_abs_acc": observed_max_abs_acc,
        "observed_acc_bits": int_bits_needed(observed_max_abs_acc),
        "acc_headroom_bits_vs_conservative": acc_width - int_bits_needed(conservative_acc_bound),
        "acc_headroom_bits_vs_observed": acc_width - int_bits_needed(observed_max_abs_acc),
        "overflow_count": int(matching_row["overflow_count"]),
    }
    (ANALYSIS_DIR / "bitwidth_derivation.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def emit_system_report_breakdowns() -> None:
    power_rows = []
    timing_rows = []
    route_rows = []
    for top, meta in SYSTEM_REPORTS.items():
        power = parse_power_metrics(meta["power_report"])
        timing = parse_top_path_metrics(meta["timing_report"])
        route = parse_route_status(meta["route_report"])

        power_rows.append(
            {
                "top": top,
                "architecture": meta["arch"],
                "scope": meta["scope"],
                **power,
            }
        )
        timing_rows.append(
            {
                "top": top,
                "architecture": meta["arch"],
                "scope": meta["scope"],
                **timing,
            }
        )
        route_rows.append(
            {
                "top": top,
                "architecture": meta["arch"],
                "scope": meta["scope"],
                **route,
            }
        )

    write_csv(
        ANALYSIS_DIR / "power_breakdown.csv",
        power_rows,
        [
            "top",
            "architecture",
            "scope",
            "power_total_w",
            "power_dynamic_w",
            "power_static_w",
            "clock_power_w",
            "clb_logic_power_w",
            "signals_power_w",
            "bram_power_w",
            "dsp_power_w",
            "ps8_power_w",
            "ps_static_w",
            "pl_static_w",
            "hier_ps_w",
            "hier_fir_shell_w",
            "hier_dma_w",
            "hier_ctrl_w",
            "hier_data_ic_w",
            "confidence_level",
        ],
    )
    write_csv(
        ANALYSIS_DIR / "critical_path_breakdown.csv",
        timing_rows,
        [
            "top",
            "architecture",
            "scope",
            "source",
            "destination",
            "requirement_ns",
            "wns_ns",
            "data_path_delay_ns",
            "logic_delay_ns",
            "route_delay_ns",
            "logic_fraction_pct",
            "route_fraction_pct",
            "logic_levels",
        ],
    )
    write_csv(
        ANALYSIS_DIR / "route_status.csv",
        route_rows,
        [
            "top",
            "architecture",
            "scope",
            "logical_nets",
            "routable_nets",
            "fully_routed_nets",
            "routing_errors",
            "fully_routed_pct",
        ],
    )


def main() -> None:
    ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)
    emit_efficiency_metrics()
    emit_quantization_threshold()
    emit_design_tradeoffs()
    emit_bitwidth_derivation()
    emit_system_report_breakdowns()


if __name__ == "__main__":
    main()
