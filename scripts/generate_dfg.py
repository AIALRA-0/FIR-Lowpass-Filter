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
            "critical_path": "tap multiply plus full-width adder tree",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> MUL[261 tap multipliers]",
                "COEF[Coeff ROM] --> MUL",
                "MUL --> ACC[Full adder tree]",
                "ACC --> QS[Round / Saturate]",
                "QS --> OUT[Output]",
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
            "critical_path": "pre-add plus folded adder tree",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> PAIR[Symmetric pairing]",
                "PAIR --> PRE[Pre-add x_k + x_n-k]",
                "COEF[Unique coeff ROM] --> MUL",
                "PRE --> MUL[131 unique multipliers]",
                "MUL --> ACC[Folded adder tree]",
                "ACC --> QS[Round / Saturate]",
                "QS --> OUT[Output]",
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
            "critical_path": "single DSP48-friendly MAC stage",
            "mermaid": [
                "IN[Input sample] --> DL[Delay line]",
                "DL --> PRE[Symmetric pre-add]",
                "PRE --> DSP0[DSP stage 0]",
                "COEF[Coeff / tap regs] --> DSP0",
                "DSP0 --> REG0[Pipe regs]",
                "REG0 --> DSPK[DSP stage 1..k]",
                "DSPK --> ACC[Systolic accum chain]",
                "ACC --> QS[Round / Saturate]",
                "QS --> OUT[Output]",
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
            "critical_path": "single phase branch plus lane recombine",
            "mermaid": [
                "IN[2-lane block input] --> DEMUX[Deinterleave x0 / x1]",
                "DEMUX --> E0[Even branch E0]",
                "DEMUX --> E1[Odd branch E1]",
                "E0 --> COMB[Lane recombine]",
                "E1 --> COMB",
                "COMB --> QS[Round / Saturate]",
                "QS --> OUT[2-lane output]",
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
            "critical_path": "polyphase branch plus FFA recombine",
            "mermaid": [
                "IN[3-lane block input] --> DEMUX[Deinterleave x0 / x1 / x2]",
                "DEMUX --> E0[Phase branch E0]",
                "DEMUX --> E1[Phase branch E1]",
                "DEMUX --> E2[Phase branch E2]",
                "E0 --> FFA[Shared L3 FFA recombine]",
                "E1 --> FFA",
                "E2 --> FFA",
                "FFA --> QS[Round / Saturate]",
                "QS --> OUT[3-lane output]",
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
            "critical_path": "single pipelined branch / recombine stage",
            "mermaid": [
                "IN[3-lane block input] --> INREG[Input regs]",
                "INREG --> E0[Phase branch E0]",
                "INREG --> E1[Phase branch E1]",
                "INREG --> E2[Phase branch E2]",
                "E0 --> BREG[Branch output regs]",
                "E1 --> BREG",
                "E2 --> BREG",
                "BREG --> RREG[Recombine regs]",
                "RREG --> QS[Round / Saturate]",
                "QS --> OUT[3-lane output]",
            ],
        },
    ]


def to_mermaid(arch) -> str:
    lines = ["flowchart LR"]
    lines.extend(f"    {edge}" for edge in arch["mermaid"])
    return "\n".join(lines) + "\n"


def multiline_text(x: float, y: float, lines, font_size: int = 18, weight: str = "normal") -> str:
    if isinstance(lines, str):
        lines = [lines]
    start_y = y - (len(lines) - 1) * (font_size + 4) / 2 + font_size / 2 - 2
    tspans = []
    for idx, line in enumerate(lines):
        dy = 0 if idx == 0 else font_size + 4
        tspans.append(
            f'<tspan x="{x}" dy="{dy if idx else 0}">{escape(str(line))}</tspan>'
        )
    return (
        f'<text x="{x}" y="{start_y}" text-anchor="middle" font-family="Georgia" '
        f'font-size="{font_size}" font-weight="{weight}">{"".join(tspans)}</text>'
    )


def box(node) -> str:
    return (
        f'<rect x="{node["x"]}" y="{node["y"]}" width="{node["w"]}" height="{node["h"]}" '
        f'rx="12" fill="{node.get("fill", "#f7f3eb")}" stroke="{node.get("stroke", "#1f2937")}" '
        f'stroke-width="{node.get("stroke_width", 2)}"/>'
        + multiline_text(
            node["x"] + node["w"] / 2,
            node["y"] + node["h"] / 2,
            node["label"],
            font_size=node.get("font_size", 17),
            weight=node.get("font_weight", "normal"),
        )
    )


def anchor(node, which: str):
    if which == "left":
        return (node["x"], node["y"] + node["h"] / 2)
    if which == "right":
        return (node["x"] + node["w"], node["y"] + node["h"] / 2)
    if which == "top":
        return (node["x"] + node["w"] / 2, node["y"])
    if which == "bottom":
        return (node["x"] + node["w"] / 2, node["y"] + node["h"])
    raise ValueError(which)


def edge(nodes, src, dst, src_anchor="right", dst_anchor="left", path=None, color="#7c3aed", dashed=False):
    x1, y1 = anchor(nodes[src], src_anchor)
    x2, y2 = anchor(nodes[dst], dst_anchor)
    pts = [(x1, y1)]
    if path:
        pts.extend(path)
    pts.append((x2, y2))
    points = " ".join(f"{x},{y}" for x, y in pts)
    dash = ' stroke-dasharray="8 6"' if dashed else ""
    return (
        f'<polyline fill="none" points="{points}" stroke="{color}" stroke-width="3"{dash} '
        f'marker-end="url(#arrow)"/>'
    )


def note(x: float, y: float, text: str, size: int = 15, color: str = "#374151") -> str:
    return f'<text x="{x}" y="{y}" font-family="Consolas" font-size="{size}" fill="{color}">{escape(text)}</text>'


def circle(cx: float, cy: float, r: float, label: str, fill: str = "#ffffff", stroke: str = "#1f2937", size: int = 20):
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'
        f'<text x="{cx}" y="{cy + size / 3 - 2}" text-anchor="middle" font-family="Georgia" font-size="{size}" font-weight="bold">{escape(label)}</text>'
    )


def text_label(x: float, y: float, text: str, size: int = 15, color: str = "#111827", anchor: str = "middle"):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Georgia" font-size="{size}" fill="{color}">{escape(text)}</text>'


def simple_rect(x: float, y: float, w: float, h: float, label, fill: str = "#f7f3eb", stroke: str = "#1f2937"):
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'
        + multiline_text(x + w / 2, y + h / 2, label, font_size=16)
    )


def line(x1, y1, x2, y2, color="#374151", width=2, dashed=False):
    dash = ' stroke-dasharray="7 5"' if dashed else ""
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}"{dash}/>'


def arrow_line(x1, y1, x2, y2, color="#7c3aed", width=2.5):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}" marker-end="url(#arrow)"/>'


def polyline(points, color="#7c3aed", width=2.5):
    pts = " ".join(f"{x},{y}" for x, y in points)
    return f'<polyline fill="none" points="{pts}" stroke="{color}" stroke-width="{width}" marker-end="url(#arrow)"/>'


def direct_form_svg(arch):
    width, height = 1320, 430
    elems = []
    chain_y = 98
    mul_y = 228
    acc_y = 330

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    tap_xs = [100, 260, 420, 620, 820]
    tap_labels = ["x[n]", "x[n-1]", "x[n-2]", "⋯", "x[n-(N-1)]"]
    coeff_labels = ["h[0]", "h[1]", "h[2]", "⋯", "h[N-1]"]
    add_xs = [260, 420, 620, 820]

    elems.append(simple_rect(55, chain_y, 90, 46, ["x[n]"], fill="#eef2ff"))
    elems.append(simple_rect(230, chain_y, 60, 46, ["z⁻¹"], fill="#f7f3eb"))
    elems.append(simple_rect(390, chain_y, 60, 46, ["z⁻¹"], fill="#f7f3eb"))
    elems.append(simple_rect(790, chain_y, 60, 46, ["z⁻¹"], fill="#f7f3eb"))
    elems.append(text_label(620, chain_y + 28, "⋯", size=30))

    elems.append(arrow_line(145, chain_y + 23, 230, chain_y + 23))
    elems.append(arrow_line(290, chain_y + 23, 390, chain_y + 23))
    elems.append(arrow_line(450, chain_y + 23, 590, chain_y + 23))
    elems.append(arrow_line(650, chain_y + 23, 790, chain_y + 23))

    for x, sig, coeff in zip(tap_xs, tap_labels, coeff_labels):
        elems.append(line(x, chain_y + 46, x, mul_y - 28, color="#6b7280", width=1.8))
        elems.append(text_label(x + 18, 158, sig, size=14, anchor="start"))
        elems.append(circle(x, mul_y, 24, "×", fill="#fef3c7"))
        elems.append(text_label(x + 18, mul_y - 46, coeff, size=14, color="#16a34a", anchor="start"))

    for x in add_xs:
        elems.append(circle(x, acc_y, 22, "+", fill="#fee2e2"))

    elems.append(line(100, mul_y + 24, 100, acc_y, color="#6b7280", width=1.8))
    elems.append(polyline([(100, acc_y), (238, acc_y)]))
    elems.append(line(260, mul_y + 24, 260, acc_y - 22, color="#6b7280", width=1.8))
    elems.append(polyline([(282, acc_y), (398, acc_y)]))
    elems.append(line(420, mul_y + 24, 420, acc_y - 22, color="#6b7280", width=1.8))
    elems.append(polyline([(442, acc_y), (598, acc_y)]))
    elems.append(line(620, mul_y + 24, 620, acc_y - 22, color="#6b7280", width=1.8))
    elems.append(polyline([(642, acc_y), (798, acc_y)]))
    elems.append(line(820, mul_y + 24, 820, acc_y - 22, color="#6b7280", width=1.8))

    elems.append(simple_rect(930, acc_y - 26, 120, 52, ["round / sat"], fill="#ede9fe"))
    elems.append(simple_rect(1115, acc_y - 26, 90, 52, ["y[n]"], fill="#eef2ff"))
    elems.append(arrow_line(842, acc_y, 930, acc_y))
    elems.append(arrow_line(1050, acc_y, 1115, acc_y))

    elems.append(note(40, 388, "critical path: tap multiplier plus full-width accumulation"))
    elems.append(note(40, 412, "direct form: every tap owns its own multiplier; delay chain fans out to all taps"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def symmetry_folded_svg(arch):
    width, height = 1380, 470
    elems = []
    sample_y = 88
    pre_y = 176
    mul_y = 258
    acc_y = 348

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    pair_cols = [220, 440, 660, 880]
    sample_pairs = [
        ("x[n]", "x[n-(N-1)]"),
        ("x[n-1]", "x[n-(N-2)]"),
        ("⋯", "⋯"),
        ("x[n-M]", ""),
    ]
    coeff_labels = ["h[0]", "h[1]", "⋯", "h[M]"]
    add_xs = [440, 660, 880]

    # sample nodes / pair sources
    for x, (top_lab, bot_lab) in zip(pair_cols, sample_pairs):
        if top_lab == "⋯":
            elems.append(text_label(x, sample_y + 10, "⋯", size=28))
            elems.append(text_label(x, sample_y + 54, "⋯", size=28))
        elif bot_lab:
            elems.append(simple_rect(x - 90, sample_y, 80, 40, [top_lab], fill="#eef2ff"))
            elems.append(simple_rect(x + 10, sample_y, 110, 40, [bot_lab], fill="#eef2ff"))
        else:
            elems.append(simple_rect(x - 55, sample_y + 22, 110, 40, [top_lab], fill="#eef2ff"))

    # pre-add / center pass-through row
    elems.append(circle(pair_cols[0], pre_y, 22, "+", fill="#fee2e2"))
    elems.append(circle(pair_cols[1], pre_y, 22, "+", fill="#fee2e2"))
    elems.append(circle(pair_cols[2], pre_y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(pair_cols[3] - 55, pre_y - 22, 110, 44, ["center tap"], fill="#e0f2fe"))

    # wires into pre-adds
    for x in pair_cols[:2]:
        elems.append(line(x - 50, sample_y + 40, x - 50, pre_y, color="#6b7280", width=1.8))
        elems.append(line(x + 65, sample_y + 40, x + 65, pre_y, color="#6b7280", width=1.8))
        elems.append(line(x - 50, pre_y, x - 22, pre_y, color="#6b7280", width=1.8))
        elems.append(line(x + 65, pre_y, x + 22, pre_y, color="#6b7280", width=1.8))
    elems.append(text_label(pair_cols[2], pre_y - 56, "omitted mirror pairs", size=14))
    elems.append(line(pair_cols[2], sample_y + 18, pair_cols[2], pre_y - 22, color="#6b7280", width=1.8, dashed=True))
    elems.append(line(pair_cols[3], sample_y + 62, pair_cols[3], pre_y - 22, color="#6b7280", width=1.8))

    # multipliers
    for x, coeff in zip(pair_cols, coeff_labels):
        elems.append(circle(x, mul_y, 24, "×", fill="#fef3c7"))
        elems.append(line(x, pre_y + 22, x, mul_y - 24, color="#6b7280", width=1.8))
        elems.append(text_label(x + 18, mul_y - 44, coeff, size=14, color="#16a34a", anchor="start"))

    for x in add_xs:
        elems.append(circle(x, acc_y, 22, "+", fill="#fee2e2"))

    elems.append(line(220, mul_y + 24, 220, acc_y, color="#6b7280", width=1.8))
    elems.append(polyline([(220, acc_y), (418, acc_y)]))
    elems.append(line(440, mul_y + 24, 440, acc_y - 22, color="#6b7280", width=1.8))
    elems.append(polyline([(462, acc_y), (638, acc_y)]))
    elems.append(line(660, mul_y + 24, 660, acc_y - 22, color="#6b7280", width=1.8))
    elems.append(polyline([(682, acc_y), (858, acc_y)]))
    elems.append(line(880, mul_y + 24, 880, acc_y - 22, color="#6b7280", width=1.8))

    elems.append(simple_rect(980, acc_y - 26, 120, 52, ["round / sat"], fill="#ede9fe"))
    elems.append(simple_rect(1165, acc_y - 26, 90, 52, ["y[n]"], fill="#eef2ff"))
    elems.append(arrow_line(902, acc_y, 980, acc_y))
    elems.append(arrow_line(1100, acc_y, 1165, acc_y))

    elems.append(note(40, 420, "critical path: pre-add plus folded accumulation"))
    elems.append(note(40, 444, "symmetry folded: mirrored samples share one multiplier after pre-add"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def pipelined_systolic_svg(arch):
    width, height = 1420, 420
    elems = []
    y = 210

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    elems.append(simple_rect(60, 110, 90, 40, ["x[n-k]"], fill="#eef2ff"))
    elems.append(simple_rect(60, 180, 120, 40, ["x[n-(N-1-k)]"], fill="#eef2ff"))
    elems.append(circle(240, y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(300, y - 22, 70, 44, ["reg"], fill="#ddd6fe"))
    elems.append(circle(450, y, 24, "×", fill="#fef3c7"))
    elems.append(text_label(470, 170, "h[k]", size=14, color="#16a34a", anchor="start"))
    elems.append(simple_rect(520, y - 22, 70, 44, ["reg"], fill="#ddd6fe"))
    elems.append(circle(690, y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(760, y - 22, 70, 44, ["reg"], fill="#ddd6fe"))
    elems.append(text_label(915, y - 34, "⋯  systolic cells  ⋯", size=20))
    elems.append(circle(1120, y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(1190, y - 22, 90, 44, ["round / sat"], fill="#ede9fe"))
    elems.append(simple_rect(1310, y - 22, 70, 44, ["y[n]"], fill="#eef2ff"))

    elems.append(line(150, 130, 218, y, color="#6b7280", width=1.8))
    elems.append(line(180, 200, 218, y, color="#6b7280", width=1.8))
    elems.append(arrow_line(262, y, 300, y))
    elems.append(arrow_line(370, y, 426, y))
    elems.append(arrow_line(474, y, 520, y))
    elems.append(simple_rect(620, 110, 90, 40, ["acc[k-1]"], fill="#eef2ff"))
    elems.append(line(665, 150, 665, 188, color="#6b7280", width=1.8))
    elems.append(line(665, 188, 668, 188, color="#6b7280", width=1.8))
    elems.append(arrow_line(590, y, 668, y))
    elems.append(arrow_line(712, y, 760, y))
    elems.append(arrow_line(830, y, 1098, y))
    elems.append(arrow_line(1142, y, 1190, y))
    elems.append(arrow_line(1280, y, 1310, y))

    elems.append(note(40, 378, "critical path: one pre-add, one multiply, one local accumulate"))
    elems.append(note(40, 402, "systolic pipeline: the long folded path is split into repeated DSP-friendly MAC cells"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def l2_polyphase_svg(arch):
    width, height = 1450, 470
    elems = []

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    top_y = 150
    bot_y = 290
    lane_y = 220

    elems.append(simple_rect(60, 110, 90, 40, ["x0[m]"], fill="#eef2ff"))
    elems.append(simple_rect(60, 250, 90, 40, ["x1[m]"], fill="#eef2ff"))

    elems.append(circle(250, top_y, 24, "×", fill="#fef3c7"))
    elems.append(text_label(268, top_y - 34, "E0[k]", size=14, color="#16a34a", anchor="start"))
    elems.append(circle(430, top_y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(520, top_y - 22, 90, 44, ["E0 acc"], fill="#ddd6fe"))

    elems.append(circle(250, bot_y, 24, "×", fill="#fde68a"))
    elems.append(text_label(268, bot_y - 34, "E1[k]", size=14, color="#16a34a", anchor="start"))
    elems.append(circle(430, bot_y, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(520, bot_y - 22, 90, 44, ["E1 acc"], fill="#ddd6fe"))

    elems.append(circle(830, 180, 22, "+", fill="#fee2e2"))
    elems.append(circle(830, 260, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(920, 160, 120, 44, ["lane0 / y0"], fill="#ede9fe"))
    elems.append(simple_rect(920, 240, 120, 44, ["lane1 / y1"], fill="#ede9fe"))
    elems.append(simple_rect(1100, 188, 110, 52, ["round / sat"], fill="#ede9fe"))
    elems.append(simple_rect(1260, 188, 100, 52, ["2-lane out"], fill="#eef2ff"))

    elems.append(arrow_line(150, 130, 226, top_y))
    elems.append(arrow_line(150, 270, 226, bot_y))
    elems.append(arrow_line(274, top_y, 408, top_y))
    elems.append(arrow_line(452, top_y, 520, top_y))
    elems.append(arrow_line(274, bot_y, 408, bot_y))
    elems.append(arrow_line(452, bot_y, 520, bot_y))

    elems.append(text_label(700, 116, "delay E1 branch by one sample for y0", size=14))
    elems.append(line(610, top_y, 700, top_y, color="#7c3aed", width=2.5))
    elems.append(line(610, bot_y, 700, bot_y, color="#7c3aed", width=2.5))
    elems.append(line(700, bot_y, 700, 180, color="#6b7280", width=1.8, dashed=True))
    elems.append(arrow_line(700, 180, 808, 180))
    elems.append(arrow_line(610, top_y, 808, 180))
    elems.append(arrow_line(610, bot_y, 808, 260))
    elems.append(arrow_line(700, top_y, 808, 260))

    elems.append(arrow_line(852, 180, 920, 180))
    elems.append(arrow_line(852, 260, 920, 260))
    elems.append(arrow_line(1040, 202, 1100, 214))
    elems.append(arrow_line(1040, 262, 1100, 214))
    elems.append(arrow_line(1210, 214, 1260, 214))

    elems.append(note(40, 418, "critical path: one polyphase branch plus lane recombine"))
    elems.append(note(40, 442, "L2 polyphase: E0 and E1 compute in parallel, then recombine into y0 and y1"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def l3_polyphase_ffa_svg(arch):
    width, height = 1500, 520
    elems = []
    rows = [140, 240, 340]
    labels = ["x0[m]", "x1[m]", "x2[m]"]
    coeffs = ["E0[k]", "E1[k]", "E2[k]"]

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    for y, sig, coef in zip(rows, labels, coeffs):
        elems.append(simple_rect(60, y - 20, 90, 40, [sig], fill="#eef2ff"))
        elems.append(circle(260, y, 24, "×", fill="#fef3c7"))
        elems.append(text_label(278, y - 34, coef, size=14, color="#16a34a", anchor="start"))
        elems.append(circle(430, y, 22, "+", fill="#fee2e2"))
        elems.append(simple_rect(520, y - 22, 90, 44, ["branch"], fill="#ddd6fe"))
        elems.append(arrow_line(150, y, 236, y))
        elems.append(arrow_line(284, y, 408, y))
        elems.append(arrow_line(452, y, 520, y))

    elems.append(circle(860, 150, 22, "+", fill="#fee2e2"))
    elems.append(circle(860, 240, 22, "+", fill="#fee2e2"))
    elems.append(circle(860, 330, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(950, 128, 120, 44, ["y0 recombine"], fill="#ede9fe"))
    elems.append(simple_rect(950, 218, 120, 44, ["y1 recombine"], fill="#ede9fe"))
    elems.append(simple_rect(950, 308, 120, 44, ["y2 recombine"], fill="#ede9fe"))
    elems.append(simple_rect(1140, 218, 130, 52, ["shared FFA core"], fill="#fee2e2"))
    elems.append(simple_rect(1330, 218, 100, 52, ["3-lane out"], fill="#eef2ff"))

    elems.append(text_label(710, 108, "cross-branch recombination matrix", size=14))
    elems.append(line(610, 140, 730, 140, color="#7c3aed", width=2.5))
    elems.append(line(610, 240, 730, 240, color="#7c3aed", width=2.5))
    elems.append(line(610, 340, 730, 340, color="#7c3aed", width=2.5))
    elems.append(line(730, 140, 730, 150, color="#6b7280", width=1.8))
    elems.append(line(730, 240, 730, 240, color="#6b7280", width=1.8))
    elems.append(line(730, 340, 730, 330, color="#6b7280", width=1.8))
    elems.append(arrow_line(730, 150, 838, 150))
    elems.append(arrow_line(730, 240, 838, 240))
    elems.append(arrow_line(730, 330, 838, 330))
    elems.append(line(610, 240, 780, 150, color="#2563eb", width=1.8, dashed=True))
    elems.append(line(610, 340, 800, 150, color="#dc2626", width=1.8, dashed=True))
    elems.append(line(610, 140, 790, 240, color="#059669", width=1.8, dashed=True))
    elems.append(line(610, 340, 790, 240, color="#d97706", width=1.8, dashed=True))
    elems.append(line(610, 140, 800, 330, color="#7c3aed", width=1.8, dashed=True))
    elems.append(line(610, 240, 780, 330, color="#db2777", width=1.8, dashed=True))

    elems.append(arrow_line(882, 150, 950, 150))
    elems.append(arrow_line(882, 240, 950, 240))
    elems.append(arrow_line(882, 330, 950, 330))
    elems.append(arrow_line(1070, 150, 1140, 244))
    elems.append(arrow_line(1070, 240, 1140, 244))
    elems.append(arrow_line(1070, 330, 1140, 244))
    elems.append(arrow_line(1270, 244, 1330, 244))

    elems.append(note(40, 468, "critical path: one polyphase branch plus shared FFA recombine"))
    elems.append(note(40, 492, "L3 polyphase / FFA: three branches feed one shared recombination core with cross-branch mixing"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def l3_pipeline_svg(arch):
    width, height = 1560, 540
    elems = []
    rows = [150, 250, 350]
    labels = ["x0[m]", "x1[m]", "x2[m]"]
    coeffs = ["E0[k]", "E1[k]", "E2[k]"]

    elems.append(text_label(40, 40, arch["title"], size=28, anchor="start"))
    elems.append(note(40, 66, f"mult={arch['mult']} add={arch['add']} reg={arch['reg']} latency={arch['latency']} spc={arch['spc']}"))

    for y, sig, coef in zip(rows, labels, coeffs):
        elems.append(simple_rect(60, y - 20, 90, 40, [sig], fill="#eef2ff"))
        elems.append(circle(250, y, 24, "×", fill="#fef3c7"))
        elems.append(text_label(268, y - 34, coef, size=14, color="#16a34a", anchor="start"))
        elems.append(simple_rect(340, y - 22, 70, 44, ["reg"], fill="#ddd6fe"))
        elems.append(circle(500, y, 22, "+", fill="#fee2e2"))
        elems.append(simple_rect(590, y - 22, 70, 44, ["reg"], fill="#ddd6fe"))
        elems.append(arrow_line(150, y, 226, y))
        elems.append(arrow_line(274, y, 340, y))
        elems.append(arrow_line(410, y, 478, y))
        elems.append(arrow_line(522, y, 590, y))

    elems.append(text_label(800, 110, "registered branch outputs", size=14))
    elems.append(simple_rect(760, 200, 110, 44, ["breg"], fill="#c4b5fd"))
    elems.append(simple_rect(980, 200, 110, 44, ["rreg"], fill="#c4b5fd"))
    elems.append(circle(1220, 180, 22, "+", fill="#fee2e2"))
    elems.append(circle(1220, 250, 22, "+", fill="#fee2e2"))
    elems.append(circle(1220, 320, 22, "+", fill="#fee2e2"))
    elems.append(simple_rect(1310, 158, 120, 44, ["y0 / y1 / y2"], fill="#ede9fe"))
    elems.append(simple_rect(1310, 238, 120, 44, ["round / sat"], fill="#ede9fe"))
    elems.append(simple_rect(1310, 318, 120, 44, ["3-lane out"], fill="#eef2ff"))

    for y in rows:
        elems.append(arrow_line(660, y, 760, 222))
    elems.append(arrow_line(870, 222, 980, 222))
    elems.append(arrow_line(1090, 222, 1198, 180))
    elems.append(arrow_line(1090, 222, 1198, 250))
    elems.append(arrow_line(1090, 222, 1198, 320))
    elems.append(arrow_line(1242, 180, 1310, 180))
    elems.append(arrow_line(1242, 250, 1310, 260))
    elems.append(arrow_line(1242, 320, 1310, 340))

    elems.append(note(40, 490, "critical path: one branch stage or one registered recombine stage"))
    elems.append(note(40, 514, "L3 pipeline: branch outputs are registered before the final recombination network"))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  {''.join(elems)}
</svg>
"""


def diagram_for_arch(arch):
    name = arch["name"]
    if name == "direct_form":
        nodes = {
            "inp": {"x": 40, "y": 120, "w": 120, "h": 64, "label": ["Input", "samples"], "fill": "#f7f3eb"},
            "dl": {"x": 215, "y": 120, "w": 145, "h": 64, "label": ["Delay line", f"{arch['mult']} taps"], "fill": "#eef2ff"},
            "coef": {"x": 420, "y": 40, "w": 135, "h": 54, "label": ["Coeff ROM"], "fill": "#ecfccb"},
            "mul": {"x": 420, "y": 120, "w": 150, "h": 64, "label": [f"{arch['mult']} tap", "multipliers"], "fill": "#fef3c7"},
            "acc": {"x": 635, "y": 120, "w": 165, "h": 64, "label": ["Full adder tree", f"{arch['add']} adds"], "fill": "#fee2e2"},
            "qs": {"x": 865, "y": 120, "w": 145, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1070, "y": 120, "w": 120, "h": 64, "label": ["Output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "dl"),
            edge(nodes, "dl", "mul"),
            edge(nodes, "coef", "mul", src_anchor="bottom", dst_anchor="top", color="#16a34a"),
            edge(nodes, "mul", "acc"),
            edge(nodes, "acc", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(40, 255, f"critical path: {arch['critical_path']}"),
            note(40, 280, "structure: no folding, all taps multiply independently"),
        ]
        return 1235, 310, nodes, edges, notes

    if name == "symmetry_folded":
        nodes = {
            "inp": {"x": 35, "y": 135, "w": 120, "h": 64, "label": ["Input", "samples"], "fill": "#f7f3eb"},
            "dl": {"x": 195, "y": 135, "w": 130, "h": 64, "label": ["Delay line"], "fill": "#eef2ff"},
            "pair": {"x": 365, "y": 135, "w": 160, "h": 64, "label": ["Symmetric", "pairing"], "fill": "#e0f2fe"},
            "pre": {"x": 565, "y": 135, "w": 150, "h": 64, "label": ["Pre-add", r"x_k + x_N-1-k"], "fill": "#fef3c7"},
            "coef": {"x": 760, "y": 48, "w": 145, "h": 54, "label": ["Unique coeff", f"ROM ({arch['mult']})"], "fill": "#ecfccb"},
            "mul": {"x": 760, "y": 135, "w": 155, "h": 64, "label": [f"{arch['mult']} unique", "multipliers"], "fill": "#fde68a"},
            "acc": {"x": 960, "y": 135, "w": 160, "h": 64, "label": ["Folded", "adder tree"], "fill": "#fee2e2"},
            "qs": {"x": 1160, "y": 135, "w": 140, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1340, "y": 135, "w": 110, "h": 64, "label": ["Output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "dl"),
            edge(nodes, "dl", "pair"),
            edge(nodes, "pair", "pre"),
            edge(nodes, "pre", "mul"),
            edge(nodes, "coef", "mul", src_anchor="bottom", dst_anchor="top", color="#16a34a"),
            edge(nodes, "mul", "acc"),
            edge(nodes, "acc", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(35, 265, f"critical path: {arch['critical_path']}"),
            note(35, 290, "structure: mirror samples are paired before multiplication"),
        ]
        return 1485, 320, nodes, edges, notes

    if name == "pipelined_systolic":
        nodes = {
            "inp": {"x": 35, "y": 135, "w": 120, "h": 64, "label": ["Input", "samples"], "fill": "#f7f3eb"},
            "dl": {"x": 185, "y": 135, "w": 125, "h": 64, "label": ["Delay line"], "fill": "#eef2ff"},
            "pre": {"x": 340, "y": 135, "w": 145, "h": 64, "label": ["Symmetric", "pre-add"], "fill": "#fef3c7"},
            "coef": {"x": 525, "y": 48, "w": 145, "h": 54, "label": ["Coeff / tap", "registers"], "fill": "#ecfccb"},
            "dsp0": {"x": 525, "y": 135, "w": 145, "h": 64, "label": ["DSP48", "stage 0"], "fill": "#fde68a"},
            "preg": {"x": 710, "y": 135, "w": 135, "h": 64, "label": ["Pipeline", "regs"], "fill": "#ddd6fe"},
            "dspk": {"x": 885, "y": 135, "w": 155, "h": 64, "label": ["DSP48", "stage 1..k"], "fill": "#fde68a"},
            "acc": {"x": 1085, "y": 135, "w": 165, "h": 64, "label": ["Systolic", "accum chain"], "fill": "#fee2e2"},
            "qs": {"x": 1290, "y": 135, "w": 140, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1470, "y": 135, "w": 110, "h": 64, "label": ["Output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "dl"),
            edge(nodes, "dl", "pre"),
            edge(nodes, "pre", "dsp0"),
            edge(nodes, "coef", "dsp0", src_anchor="bottom", dst_anchor="top", color="#16a34a"),
            edge(nodes, "dsp0", "preg"),
            edge(nodes, "preg", "dspk"),
            edge(nodes, "dspk", "acc"),
            edge(nodes, "acc", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(35, 265, f"critical path: {arch['critical_path']}"),
            note(35, 290, "structure: MAC chain is cut into DSP-friendly pipeline stages"),
        ]
        return 1615, 320, nodes, edges, notes

    if name == "l2_polyphase":
        nodes = {
            "inp": {"x": 35, "y": 155, "w": 140, "h": 64, "label": ["2-lane", "input block"], "fill": "#f7f3eb"},
            "demux": {"x": 220, "y": 155, "w": 155, "h": 64, "label": ["Deinterleave", "x0 / x1"], "fill": "#e0f2fe"},
            "e0": {"x": 450, "y": 85, "w": 165, "h": 64, "label": ["Even branch", "E0(z²)"], "fill": "#fef3c7"},
            "e1": {"x": 450, "y": 225, "w": 165, "h": 64, "label": ["Odd branch", "E1(z²)"], "fill": "#fde68a"},
            "comb": {"x": 700, "y": 155, "w": 170, "h": 64, "label": ["Lane", "recombine"], "fill": "#fee2e2"},
            "qs": {"x": 930, "y": 155, "w": 140, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1110, "y": 155, "w": 130, "h": 64, "label": ["2-lane", "output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "demux"),
            edge(nodes, "demux", "e0", dst_anchor="left", path=[(390, 187), (390, 117)]),
            edge(nodes, "demux", "e1", dst_anchor="left", path=[(390, 187), (390, 257)]),
            edge(nodes, "e0", "comb", src_anchor="right", dst_anchor="left", path=[(655, 117), (655, 187)]),
            edge(nodes, "e1", "comb", src_anchor="right", dst_anchor="left", path=[(655, 257), (655, 187)]),
            edge(nodes, "comb", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(35, 330, f"critical path: {arch['critical_path']}"),
            note(35, 355, "structure: two polyphase branches plus lane-level recombine"),
        ]
        return 1270, 385, nodes, edges, notes

    if name == "l3_polyphase_ffa":
        nodes = {
            "inp": {"x": 35, "y": 175, "w": 150, "h": 64, "label": ["3-lane", "input block"], "fill": "#f7f3eb"},
            "demux": {"x": 220, "y": 175, "w": 170, "h": 64, "label": ["Deinterleave", "x0 / x1 / x2"], "fill": "#e0f2fe"},
            "e0": {"x": 470, "y": 65, "w": 170, "h": 64, "label": ["Phase branch", "E0(z³)"], "fill": "#fef3c7"},
            "e1": {"x": 470, "y": 175, "w": 170, "h": 64, "label": ["Phase branch", "E1(z³)"], "fill": "#fde68a"},
            "e2": {"x": 470, "y": 285, "w": 170, "h": 64, "label": ["Phase branch", "E2(z³)"], "fill": "#fdba74"},
            "ffa": {"x": 735, "y": 175, "w": 185, "h": 64, "label": ["Shared L3", "FFA recombine"], "fill": "#fee2e2"},
            "qs": {"x": 980, "y": 175, "w": 145, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1165, "y": 175, "w": 135, "h": 64, "label": ["3-lane", "output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "demux"),
            edge(nodes, "demux", "e0", path=[(415, 207), (415, 97)]),
            edge(nodes, "demux", "e1"),
            edge(nodes, "demux", "e2", path=[(415, 207), (415, 317)]),
            edge(nodes, "e0", "ffa", src_anchor="right", dst_anchor="left", path=[(675, 97), (675, 207)]),
            edge(nodes, "e1", "ffa"),
            edge(nodes, "e2", "ffa", src_anchor="right", dst_anchor="left", path=[(675, 317), (675, 207)]),
            edge(nodes, "ffa", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(35, 390, f"critical path: {arch['critical_path']}"),
            note(35, 415, "structure: three phase branches feed one shared recombination core"),
        ]
        return 1335, 445, nodes, edges, notes

    if name == "l3_pipeline":
        nodes = {
            "inp": {"x": 35, "y": 175, "w": 150, "h": 64, "label": ["3-lane", "input block"], "fill": "#f7f3eb"},
            "inreg": {"x": 215, "y": 175, "w": 150, "h": 64, "label": ["Input", "registers"], "fill": "#ddd6fe"},
            "e0": {"x": 430, "y": 65, "w": 165, "h": 64, "label": ["Branch", "E0"], "fill": "#fef3c7"},
            "e1": {"x": 430, "y": 175, "w": 165, "h": 64, "label": ["Branch", "E1"], "fill": "#fde68a"},
            "e2": {"x": 430, "y": 285, "w": 165, "h": 64, "label": ["Branch", "E2"], "fill": "#fdba74"},
            "breg": {"x": 665, "y": 175, "w": 170, "h": 64, "label": ["Branch output", "registers"], "fill": "#ddd6fe"},
            "rreg": {"x": 900, "y": 175, "w": 175, "h": 64, "label": ["Recombine", "pipeline regs"], "fill": "#c4b5fd"},
            "qs": {"x": 1135, "y": 175, "w": 145, "h": 64, "label": ["Round /", "Saturate"], "fill": "#ede9fe"},
            "out": {"x": 1320, "y": 175, "w": 130, "h": 64, "label": ["3-lane", "output"], "fill": "#f7f3eb"},
        }
        edges = [
            edge(nodes, "inp", "inreg"),
            edge(nodes, "inreg", "e0", path=[(390, 207), (390, 97)]),
            edge(nodes, "inreg", "e1"),
            edge(nodes, "inreg", "e2", path=[(390, 207), (390, 317)]),
            edge(nodes, "e0", "breg", src_anchor="right", dst_anchor="left", path=[(620, 97), (620, 207)]),
            edge(nodes, "e1", "breg"),
            edge(nodes, "e2", "breg", src_anchor="right", dst_anchor="left", path=[(620, 317), (620, 207)]),
            edge(nodes, "breg", "rreg"),
            edge(nodes, "rreg", "qs"),
            edge(nodes, "qs", "out"),
        ]
        notes = [
            note(35, 390, f"critical path: {arch['critical_path']}"),
            note(35, 415, "structure: branch outputs are registered before final recombination"),
        ]
        return 1485, 445, nodes, edges, notes

    raise ValueError(name)


def to_svg(arch) -> str:
    if arch["name"] == "direct_form":
        return direct_form_svg(arch)
    if arch["name"] == "symmetry_folded":
        return symmetry_folded_svg(arch)
    if arch["name"] == "pipelined_systolic":
        return pipelined_systolic_svg(arch)
    if arch["name"] == "l2_polyphase":
        return l2_polyphase_svg(arch)
    if arch["name"] == "l3_polyphase_ffa":
        return l3_polyphase_ffa_svg(arch)
    if arch["name"] == "l3_pipeline":
        return l3_pipeline_svg(arch)
    width, height, nodes, edges, notes = diagram_for_arch(arch)
    metrics = (
        f"{arch['title']} | mult={arch['mult']} add={arch['add']} reg={arch['reg']} "
        f"latency={arch['latency']} spc={arch['spc']}"
    )
    boxes = "".join(box(node) for node in nodes.values())
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/>
    </marker>
  </defs>
  <rect width="{width}" height="{height}" fill="#fffdf8"/>
  <text x="35" y="40" font-family="Georgia" font-size="28" font-weight="bold">{escape(arch['title'])}</text>
  <text x="35" y="66" font-family="Consolas" font-size="15">{escape(metrics)}</text>
  {boxes}
  {''.join(edges)}
  {''.join(notes)}
</svg>
"""


def write_report(architectures):
    lines = [
        "# Architecture Math",
        "",
        "The statistics below are used for DFG/SFG presentation and RTL budgeting; final resource and frequency numbers must follow the Vivado reports.",
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
