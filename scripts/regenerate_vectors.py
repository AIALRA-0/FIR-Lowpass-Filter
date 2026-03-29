from __future__ import annotations

import csv
import json
from pathlib import Path

import numpy as np


REPO_ROOT = Path(__file__).resolve().parent.parent


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def round_away_from_zero(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=np.float64)
    return np.where(values >= 0.0, np.floor(values + 0.5), np.ceil(values - 0.5))


def quantize_signed_frac(values: np.ndarray, width: int, frac_bits: int) -> np.ndarray:
    scale = 2 ** frac_bits
    raw = round_away_from_zero(np.asarray(values, dtype=np.float64) * scale).astype(np.int64)
    min_int = -(2 ** (width - 1))
    max_int = 2 ** (width - 1) - 1
    return np.clip(raw, min_int, max_int)


def twos_hex(value: int, width: int) -> str:
    if value < 0:
        value += 1 << width
    digits = (width + 3) // 4
    return f"{value:0{digits}X}"


def write_memh(path: Path, values: np.ndarray, width: int) -> None:
    lines = [twos_hex(int(v), width) for v in np.asarray(values).reshape(-1)]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def pack_lanes(signal_int: np.ndarray, lanes: int, width: int) -> np.ndarray:
    sig = np.asarray(signal_int, dtype=np.int64).reshape(-1)
    frames = (sig.size + lanes - 1) // lanes
    if sig.size < frames * lanes:
        sig = np.pad(sig, (0, frames * lanes - sig.size))
    packed = np.zeros(frames, dtype=np.uint64)
    for frame in range(frames):
        base = frame * lanes
        accum = 0
        for lane in range(lanes):
            value = int(sig[base + lane])
            if value < 0:
                value += 1 << width
            accum |= (value & ((1 << width) - 1)) << (lane * width)
        packed[frame] = np.uint64(accum)
    return packed


def sim_fixed_response(
    coeffs_q: np.ndarray,
    input_signal: np.ndarray,
    input_width: int,
    input_frac_bits: int,
    coef_width: int,
    output_width: int,
) -> tuple[np.ndarray, np.ndarray]:
    coeff_int = quantize_signed_frac(coeffs_q, coef_width, coef_width - 1)
    input_int = quantize_signed_frac(input_signal, input_width, input_frac_bits)
    full_conv = np.convolve(input_int.astype(np.float64), coeff_int.astype(np.float64))
    shift = coef_width - 1
    rounded = round_away_from_zero(full_conv / float(2 ** shift)).astype(np.int64)
    out_min = -(2 ** (output_width - 1))
    out_max = 2 ** (output_width - 1) - 1
    output_int = np.clip(rounded, out_min, out_max)
    output_float = output_int.astype(np.float64) / float(2 ** input_frac_bits)
    return input_int, output_int.astype(np.int64), output_float


def build_cases(spec: dict) -> list[dict]:
    vg = spec["vector_generation"]
    rng = np.random.RandomState(vg["seed"])
    t_sine = np.arange(vg["sine_length"], dtype=np.float64)
    t_mt = np.arange(vg["multitone_length"], dtype=np.float64)
    random_signal = 2.0 * rng.rand(vg["random_length"]) - 1.0
    overflow = 0.98 * np.resize(np.array([1.0, -1.0]), vg["random_length"])
    lane_l2 = np.array(
        [0.875, -0.625, 0.5, -0.375, 0.3125, -0.25, 0.1875, -0.125, 0.09375, -0.0625, 0.046875, -0.03125, 0.0234375, -0.015625, 0.01171875, -0.0078125, 0.005859375],
        dtype=np.float64,
    )
    lane_l3 = np.array(
        [0.8125, -0.6875, 0.5625, -0.4375, 0.34375, -0.28125, 0.21875, -0.171875, 0.140625, -0.109375, 0.0859375, -0.0703125, 0.0546875, -0.04296875, 0.03515625, -0.02734375, 0.021484375, -0.017578125, 0.013671875, -0.01171875],
        dtype=np.float64,
    )
    return [
        {"name": "impulse", "note": "Impulse response", "signal": np.r_[1.0, np.zeros(vg["impulse_length"] - 1)]},
        {"name": "step", "note": "Step response", "signal": np.full(vg["step_length"], 0.8)},
        {"name": "random", "note": "Uniform random full-scale", "signal": random_signal},
        {"name": "random_short", "note": "1024-sample regression subset", "signal": random_signal[:1024]},
        {
            "name": "passband_edge",
            "note": "Near passband edge sinusoid",
            "signal": 0.8 * np.sin(np.pi * (spec["wp"] * 0.98) * t_sine),
        },
        {
            "name": "transition",
            "note": "Transition-band sinusoid",
            "signal": 0.8 * np.sin(np.pi * ((spec["wp"] + spec["ws"]) / 2.0) * t_sine),
        },
        {
            "name": "stopband",
            "note": "Stopband sinusoid",
            "signal": 0.8 * np.sin(np.pi * (spec["ws"] * 1.02) * t_sine),
        },
        {
            "name": "multitone",
            "note": "Passband+transition+stopband multi-tone",
            "signal": 0.35 * np.sin(np.pi * 0.12 * t_mt)
            + 0.25 * np.sin(np.pi * 0.21 * t_mt)
            + 0.2 * np.sin(np.pi * 0.35 * t_mt),
        },
        {
            "name": "overflow_corner",
            "note": "Alternating near-full-scale sequence",
            "signal": overflow[: vg["random_length"]],
        },
        {
            "name": "lane_alignment_l2",
            "note": "Non-multiple-of-2 patterned sequence for lane ordering and flush checks",
            "signal": lane_l2,
        },
        {
            "name": "lane_alignment_l3",
            "note": "Non-multiple-of-3 patterned sequence for lane ordering and flush checks",
            "signal": lane_l3,
        },
    ]


def load_selected_coeffs() -> tuple[np.ndarray, dict]:
    summary = load_json(REPO_ROOT / "data" / "fixed_design_summary.json")
    with (REPO_ROOT / "data" / "fixedpoint_sweep.csv").open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if int(row["coef_width"]) == int(summary["coef_width"]) and int(row["output_width"]) == int(summary["output_width"]):
                coeffs = np.array([float(x) for x in row["coeff_csv"].split(",")], dtype=np.float64)
                return coeffs, summary
    raise RuntimeError("Selected coefficient row not found in fixedpoint_sweep.csv")


def main() -> None:
    spec = load_json(REPO_ROOT / "spec" / "spec.json")
    coeffs_q, summary = load_selected_coeffs()
    vectors_root = REPO_ROOT / "vectors"
    vectors_root.mkdir(parents=True, exist_ok=True)

    for case in build_cases(spec):
        case_dir = vectors_root / case["name"]
        case_dir.mkdir(parents=True, exist_ok=True)

        input_int, output_int, output_float = sim_fixed_response(
            coeffs_q=coeffs_q,
            input_signal=np.asarray(case["signal"], dtype=np.float64),
            input_width=int(spec["fixed_point"]["input_width"]),
            input_frac_bits=int(spec["fixed_point"]["input_frac_bits"]),
            coef_width=int(summary["coef_width"]),
            output_width=int(summary["output_width"]),
        )

        write_memh(case_dir / "input_scalar.memh", input_int, int(spec["fixed_point"]["input_width"]))
        write_memh(case_dir / "golden_scalar.memh", output_int, int(summary["output_width"]))

        input_l2 = pack_lanes(input_int, 2, int(spec["fixed_point"]["input_width"]))
        input_l3 = pack_lanes(input_int, 3, int(spec["fixed_point"]["input_width"]))
        golden_l2 = pack_lanes(output_int, 2, int(summary["output_width"]))
        golden_l3 = pack_lanes(output_int, 3, int(summary["output_width"]))

        write_memh(case_dir / "input_l2.memh", input_l2, int(spec["fixed_point"]["input_width"]) * 2)
        write_memh(case_dir / "input_l3.memh", input_l3, int(spec["fixed_point"]["input_width"]) * 3)
        write_memh(case_dir / "golden_l2.memh", golden_l2, int(summary["output_width"]) * 2)
        write_memh(case_dir / "golden_l3.memh", golden_l3, int(summary["output_width"]) * 3)

        meta = {
            "name": case["name"],
            "length": int(np.asarray(case["signal"]).size),
            "coef_width": int(summary["coef_width"]),
            "output_width": int(summary["output_width"]),
            "note": case["note"],
        }
        (case_dir / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    summary_json = {
        "selected_design": f"q{int(summary['coef_width']):02d}_o{int(summary['output_width']):02d}",
        "taps": int(summary["taps"]),
        "vector_cases": [case["name"] for case in build_cases(spec)],
    }
    (vectors_root / "summary.json").write_text(json.dumps(summary_json, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
