import json
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / "spec" / "spec.json").read_text(encoding="utf-8"))
FLOAT_SUMMARY_PATH = ROOT / "data" / "floating_design_summary.json"


def load_taps() -> int:
    if FLOAT_SUMMARY_PATH.exists():
        summary = json.loads(FLOAT_SUMMARY_PATH.read_text(encoding="utf-8"))
        return int(summary["final_design"]["taps"])
    return int(SPEC["baseline_order"]) + 1


def unique_mults(taps: int) -> int:
    return (taps + 1) // 2


def phase_lengths(taps: int, lanes: int):
    return [(taps - phase + lanes - 1) // lanes for phase in range(lanes) if taps - phase > 0]


def unique_mults_polyphase(taps: int, lanes: int) -> int:
    return sum(unique_mults(n) for n in phase_lengths(taps, lanes))


def build_architectures(taps: int):
    half_adds = taps // 2
    uniq = unique_mults(taps)
    l2_mults = unique_mults_polyphase(taps, 2)
    l3_mults = unique_mults_polyphase(taps, 3)
    return [
        {
            "name": "direct_form",
            "title": "Direct-Form FIR",
            "mult": taps,
            "add": max(taps - 1, 0),
            "reg": max(taps - 1, 0),
            "latency": 1,
            "spc": 1,
            "critical_path": "adder chain across full tap set",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> MUL[Tap multipliers]",
                "MUL --> ACC[Full adder chain]",
                "ACC --> OUT[Output]",
            ],
        },
        {
            "name": "symmetry_folded",
            "title": "Symmetry-Folded FIR",
            "mult": uniq,
            "add": half_adds + max(uniq - 1, 0),
            "reg": max(taps - 1, 0),
            "latency": 1,
            "spc": 1,
            "critical_path": "pre-add plus folded accumulation",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> PAIR[Symmetric sample pairing]",
                "PAIR --> PRE[Pre-adders]",
                "PRE --> MUL[Unique multipliers]",
                "MUL --> ACC[Folded accumulator]",
                "ACC --> OUT[Output]",
            ],
        },
        {
            "name": "pipelined_systolic",
            "title": "Pipelined Systolic FIR",
            "mult": uniq,
            "add": half_adds + max(uniq - 1, 0),
            "reg": max(taps - 1, 0) + uniq,
            "latency": uniq + 1,
            "spc": 1,
            "critical_path": "single pre-add, multiply, accumulate stage",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> PRE[Pre-add stage]",
                "PRE --> MUL[Multiplier stage]",
                "MUL --> DLY[Per-tap product delays]",
                "DLY --> ACC[Systolic accumulator chain]",
                "ACC --> OUT[Output]",
            ],
        },
        {
            "name": "l2_polyphase",
            "title": "L=2 Polyphase FIR",
            "mult": l2_mults,
            "add": l2_mults + max(l2_mults - 2, 0),
            "reg": taps + l2_mults,
            "latency": unique_mults(max(phase_lengths(taps, 2))) + 2,
            "spc": 2,
            "critical_path": "subfilter accumulation per phase",
            "mermaid": [
                "IN[2-lane input] --> DEMUX[Phase split]",
                "DEMUX --> E0[Even polyphase branch]",
                "DEMUX --> E1[Odd polyphase branch]",
                "E0 --> COMB[Recombine outputs]",
                "E1 --> COMB",
                "COMB --> OUT[2-lane output]",
            ],
        },
        {
            "name": "l3_polyphase_ffa",
            "title": "L=3 Polyphase / FFA FIR",
            "mult": l3_mults,
            "add": l3_mults + max(l3_mults - 3, 0),
            "reg": taps + l3_mults,
            "latency": unique_mults(max(phase_lengths(taps, 3))) + 3,
            "spc": 3,
            "critical_path": "phase branch plus recombination",
            "mermaid": [
                "IN[3-lane input] --> DEMUX[Three-phase split]",
                "DEMUX --> E0[Phase-0 branch]",
                "DEMUX --> E1[Phase-1 branch]",
                "DEMUX --> E2[Phase-2 branch]",
                "E0 --> FFA[Recombine / FFA stage]",
                "E1 --> FFA",
                "E2 --> FFA",
                "FFA --> OUT[3-lane output]",
            ],
        },
        {
            "name": "l3_pipeline",
            "title": "L=3 + Pipeline FIR",
            "mult": l3_mults,
            "add": l3_mults + max(l3_mults - 3, 0),
            "reg": taps + 2 * l3_mults,
            "latency": unique_mults(max(phase_lengths(taps, 3))) + 6,
            "spc": 3,
            "critical_path": "single pipelined substage",
            "mermaid": [
                "IN[3-lane input] --> PRE[Pre-process pipeline]",
                "PRE --> SUB[Polyphase subfilters]",
                "SUB --> POST[Post-process pipeline]",
                "POST --> OUT[3-lane output]",
            ],
        },
    ]


def to_mermaid(arch) -> str:
    lines = ["flowchart LR"]
    lines.extend(f"    {edge}" for edge in arch["mermaid"])
    return "\n".join(lines) + "\n"


def to_svg(arch) -> str:
    width = 1040
    height = 280
    x_positions = [40, 240, 440, 640, 860]
    labels = ["Input", "Stage 1", "Stage 2", "Stage 3", "Output"]
    y = 90
    boxes = []
    arrows = []
    for idx, label in enumerate(labels):
        x = x_positions[idx]
        boxes.append(
            f'<rect x="{x}" y="{y}" width="140" height="70" rx="12" fill="#f7f3eb" stroke="#1f2937" stroke-width="2"/>'
        )
        boxes.append(
            f'<text x="{x + 70}" y="{y + 40}" text-anchor="middle" font-family="Georgia" font-size="20">{escape(label)}</text>'
        )
    for idx in range(len(x_positions) - 1):
        x1 = x_positions[idx] + 140
        x2 = x_positions[idx + 1]
        arrows.append(
            f'<line x1="{x1}" y1="{y + 35}" x2="{x2}" y2="{y + 35}" stroke="#7c3aed" stroke-width="3" marker-end="url(#arrow)"/>'
        )
    metrics = (
        f"{arch['title']} | mult={arch['mult']} add={arch['add']} reg={arch['reg']} "
        f"latency={arch['latency']} spc={arch['spc']}"
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  <text x="40" y="45" font-family="Georgia" font-size="28" font-weight="bold">{escape(arch['title'])}</text>
  <text x="40" y="70" font-family="Consolas" font-size="16">{escape(metrics)}</text>
  {''.join(boxes)}
  {''.join(arrows)}
  <text x="40" y="230" font-family="Consolas" font-size="16">critical path: {escape(arch['critical_path'])}</text>
</svg>
"""


def write_report(architectures):
    lines = [
        "# Architecture Math",
        "",
        "以下统计用于 DFG/SFG 展示和 RTL 预算；最终资源与频率以 Vivado 报告为准。",
        "",
        "| Architecture | #mult | #add | #reg | samples/cycle | latency | Critical path |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for arch in architectures:
        lines.append(
            f"| {arch['name']} | {arch['mult']} | {arch['add']} | {arch['reg']} | {arch['spc']} | {arch['latency']} | {arch['critical_path']} |"
        )
    (ROOT / "reports" / "architecture_math.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    taps = load_taps()
    out_dir = ROOT / "docs" / "assets" / "dfg"
    out_dir.mkdir(parents=True, exist_ok=True)
    architectures = build_architectures(taps)
    for arch in architectures:
        (out_dir / f"{arch['name']}.mmd").write_text(to_mermaid(arch), encoding="utf-8")
        (out_dir / f"{arch['name']}.svg").write_text(to_svg(arch), encoding="utf-8")
    write_report(architectures)


if __name__ == "__main__":
    main()

