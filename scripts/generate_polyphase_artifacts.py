from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def decode_coeffs() -> tuple[list[int], int]:
    summary = load_json(ROOT / "data" / "fixed_design_summary.json")
    coef_width = int(summary["coef_width"])
    with (ROOT / "data" / "fixedpoint_sweep.csv").open("r", encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp)
        for row in reader:
            if int(row["coef_width"]) == coef_width and int(row["output_width"]) == int(summary["output_width"]):
                coeffs = [int(round(float(item) * (1 << (coef_width - 1)))) for item in row["coeff_csv"].split(",")]
                return coeffs, coef_width
    raise RuntimeError("Selected fixed-point coefficient row not found")


def twos_hex(value: int, width: int) -> str:
    if value < 0:
        value += 1 << width
    digits = (width + 3) // 4
    return f"{value:0{digits}X}"


def write_memh(path: Path, values: list[int], width: int) -> None:
    path.write_text("".join(f"{twos_hex(v, width)}\n" for v in values), encoding="ascii")


def emit_function_lines(name: str, values: list[int], width: int) -> list[str]:
    lines = [
        f"function automatic signed [`FIR_WCOEF-1:0] {name};",
        "  input integer idx;",
        "  begin",
        "    case (idx)",
    ]
    for idx, value in enumerate(values):
        if value < 0:
            lines.append(f"      {idx}: {name} = -{width}'sd{abs(value)};")
        else:
            lines.append(f"      {idx}: {name} = {width}'sd{value};")
    lines.extend(
        [
            f"      default: {name} = {width}'sd0;",
            "    endcase",
            "  end",
            "endfunction",
            "",
        ]
    )
    return lines


def main() -> None:
    coeffs, coef_width = decode_coeffs()

    branches = {
        "l2_e0": {"values": coeffs[0::2], "uniq": coeffs[0::2][: (len(coeffs[0::2]) + 1) // 2]},
        "l2_e1": {"values": coeffs[1::2], "uniq": coeffs[1::2][: len(coeffs[1::2]) // 2]},
        "l3_e0": {"values": coeffs[0::3], "uniq": coeffs[0::3]},
        "l3_e1": {"values": coeffs[1::3], "uniq": coeffs[1::3][: (len(coeffs[1::3]) + 1) // 2]},
        "l3_e2": {"values": coeffs[2::3], "uniq": coeffs[2::3]},
    }

    coeff_dir = ROOT / "coeffs"
    coeff_dir.mkdir(parents=True, exist_ok=True)
    for name, meta in branches.items():
        write_memh(coeff_dir / f"final_fixed_q{coef_width}_{name}_full.memh", meta["values"], coef_width)
        write_memh(coeff_dir / f"final_fixed_q{coef_width}_{name}_unique.memh", meta["uniq"], coef_width)

    params_lines = [
        "`ifndef FIR_POLYPHASE_PARAMS_VH",
        "`define FIR_POLYPHASE_PARAMS_VH",
        f"`define FIR_L2_E0_TAPS {len(branches['l2_e0']['values'])}",
        f"`define FIR_L2_E0_UNIQ {len(branches['l2_e0']['uniq'])}",
        f"`define FIR_L2_E1_TAPS {len(branches['l2_e1']['values'])}",
        f"`define FIR_L2_E1_UNIQ {len(branches['l2_e1']['uniq'])}",
        f"`define FIR_L3_E0_TAPS {len(branches['l3_e0']['values'])}",
        f"`define FIR_L3_E0_UNIQ {len(branches['l3_e0']['uniq'])}",
        f"`define FIR_L3_E1_TAPS {len(branches['l3_e1']['values'])}",
        f"`define FIR_L3_E1_UNIQ {len(branches['l3_e1']['uniq'])}",
        f"`define FIR_L3_E2_TAPS {len(branches['l3_e2']['values'])}",
        f"`define FIR_L3_E2_UNIQ {len(branches['l3_e2']['uniq'])}",
        "`endif",
        "",
    ]
    (ROOT / "rtl" / "common" / "fir_polyphase_params.vh").write_text("\n".join(params_lines), encoding="ascii")

    coeff_lines = [
        "`ifndef FIR_POLYPHASE_COEFFS_VH",
        "`define FIR_POLYPHASE_COEFFS_VH",
        "",
    ]
    coeff_lines.extend(emit_function_lines("fir_l2_e0_coeff_at", branches["l2_e0"]["uniq"], coef_width))
    coeff_lines.extend(emit_function_lines("fir_l2_e1_coeff_at", branches["l2_e1"]["uniq"], coef_width))
    coeff_lines.extend(emit_function_lines("fir_l3_e0_coeff_at", branches["l3_e0"]["values"], coef_width))
    coeff_lines.extend(emit_function_lines("fir_l3_e1_coeff_at", branches["l3_e1"]["uniq"], coef_width))
    coeff_lines.extend(emit_function_lines("fir_l3_e2_coeff_at", branches["l3_e2"]["values"], coef_width))
    coeff_lines.append("`endif")
    coeff_lines.append("")
    (ROOT / "rtl" / "common" / "fir_polyphase_coeffs.vh").write_text("\n".join(coeff_lines), encoding="ascii")


if __name__ == "__main__":
    main()
