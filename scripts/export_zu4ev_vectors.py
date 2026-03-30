from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "vectors"
OUT_DIR = ROOT / "vitis" / "zu4ev_baremetal" / "src" / "generated"
CASES = (
    ("impulse", "impulse"),
    ("step", "step"),
    ("random_short", "random_short"),
    ("passband_edge_sine", "passband_edge"),
    ("transition_sine", "transition"),
    ("multitone", "multitone"),
    ("stopband_sine", "stopband"),
    ("large_random_buffer", "random"),
)


def load_memh(path: Path) -> list[int]:
    values = []
    for line in path.read_text(encoding="utf-8").splitlines():
        token = line.strip()
        if not token:
            continue
        raw = int(token, 16)
        if raw & 0x8000:
            raw -= 0x10000
        values.append(raw)
    return values


def emit_header(case_info: list[dict[str, object]]) -> str:
    max_length = max(int(item["length"]) for item in case_info)
    lines = [
        "#ifndef FIR_ZU4EV_VECTORS_H",
        "#define FIR_ZU4EV_VECTORS_H",
        "",
        "#include <stdint.h>",
        "",
        f"#define FIR_MAX_VECTOR_LENGTH {max_length}U",
        "",
        "typedef struct {",
        "    const char *name;",
        "    uint32_t length;",
        "    const int16_t *input;",
        "    const int16_t *golden;",
        "} fir_vector_case_t;",
        "",
    ]
    for item in case_info:
        symbol = item["symbol"]
        length = item["length"]
        lines.extend(
            [
                f"extern const int16_t {symbol}_input[{length}];",
                f"extern const int16_t {symbol}_golden[{length}];",
                "",
            ]
        )
    lines.extend(
        [
            f"extern const fir_vector_case_t g_fir_vector_cases[{len(case_info)}];",
            f"extern const uint32_t g_fir_vector_case_count;",
            "",
            "#endif",
            "",
        ]
    )
    return "\n".join(lines)


def emit_array(name: str, values: list[int]) -> list[str]:
    lines = [f"const int16_t {name}[{len(values)}] = {{"]
    for idx in range(0, len(values), 8):
        chunk = ", ".join(str(v) for v in values[idx:idx + 8])
        lines.append(f"    {chunk},")
    lines.append("};")
    lines.append("")
    return lines


def emit_source(case_info: list[dict[str, object]]) -> str:
    lines = [
        '#include "generated/fir_vectors.h"',
        "",
    ]
    for item in case_info:
        lines.extend(emit_array(f"{item['symbol']}_input", item["input"]))
        lines.extend(emit_array(f"{item['symbol']}_golden", item["golden"]))
    lines.extend(
        [
            f"const fir_vector_case_t g_fir_vector_cases[{len(case_info)}] = {{",
        ]
    )
    for item in case_info:
        lines.append(
            f'    {{"{item["name"]}", {item["length"]}, {item["symbol"]}_input, {item["symbol"]}_golden}},'
        )
    lines.extend(
        [
            "};",
            "",
            f"const uint32_t g_fir_vector_case_count = {len(case_info)};",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    case_info = []
    for case_name, vector_dir_name in CASES:
        vector_dir = VECTORS / vector_dir_name
        meta = json.loads((vector_dir / "meta.json").read_text(encoding="utf-8"))
        case_len = int(meta["length"])
        input_values = load_memh(vector_dir / "input_scalar.memh")[:case_len]
        golden_values = load_memh(vector_dir / "golden_scalar.memh")[:case_len]
        if len(input_values) != case_len:
            raise RuntimeError(f"{case_name}: expected {case_len} input samples, got {len(input_values)}")
        if len(golden_values) != case_len:
            raise RuntimeError(f"{case_name}: expected {case_len} golden samples, got {len(golden_values)}")
        case_info.append(
            {
                "name": case_name,
                "symbol": f"fir_case_{case_name}",
                "length": case_len,
                "input": input_values,
                "golden": golden_values,
            }
        )
    (OUT_DIR / "fir_vectors.h").write_text(emit_header(case_info), encoding="utf-8")
    (OUT_DIR / "fir_vectors.c").write_text(emit_source(case_info), encoding="utf-8")


if __name__ == "__main__":
    main()
