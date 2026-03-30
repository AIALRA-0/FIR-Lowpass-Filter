from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import signal


ROOT = Path(__file__).resolve().parents[1]
PLOTS_DIR = ROOT / "docs" / "assets" / "plots"
PLOTS_DIR.mkdir(parents=True, exist_ok=True)


def load_efficiency() -> pd.DataFrame:
    path = ROOT / "data" / "analysis" / "efficiency_metrics.csv"
    return pd.read_csv(path)


def load_power_breakdown() -> pd.DataFrame:
    path = ROOT / "data" / "analysis" / "power_breakdown.csv"
    return pd.read_csv(path)


def load_critical_paths() -> pd.DataFrame:
    path = ROOT / "data" / "analysis" / "critical_path_breakdown.csv"
    return pd.read_csv(path)


def load_board_results() -> pd.DataFrame:
    path = ROOT / "data" / "board_results.csv"
    return pd.read_csv(path)


def load_final_float_coeffs() -> np.ndarray:
    path = ROOT / "coeffs" / "final_float.csv"
    df = pd.read_csv(path)
    return df["coefficient"].to_numpy(dtype=float)


def load_final_fixed_coeffs() -> np.ndarray:
    path = ROOT / "coeffs" / "final_fixed_q20_full.memh"
    values = []
    for line in path.read_text(encoding="utf-8").splitlines():
        token = line.strip()
        if not token:
            continue
        raw = int(token, 16)
        if raw >= (1 << 19):
            raw -= (1 << 20)
        values.append(raw / float(1 << 19))
    return np.array(values, dtype=float)


def style_axes(ax: plt.Axes) -> None:
    ax.grid(True, linestyle="--", linewidth=0.6, alpha=0.35)
    ax.set_axisbelow(True)


def save(fig: plt.Figure, name: str) -> None:
    fig.tight_layout()
    fig.savefig(PLOTS_DIR / name, dpi=180, bbox_inches="tight")
    plt.close(fig)


def plot_resource_vs_throughput(df: pd.DataFrame) -> None:
    kernel = df[df["scope"] == "kernel"].copy()
    labels = {
        "fir_symm_base": "Base",
        "fir_pipe_systolic": "Pipe",
        "fir_l2_polyphase": "L2",
        "fir_l3_polyphase": "L3",
        "fir_l3_pipe": "L3+Pipe",
    }
    colors = {
        "fir_symm_base": "#3b6ea5",
        "fir_pipe_systolic": "#e07a5f",
        "fir_l2_polyphase": "#81b29a",
        "fir_l3_polyphase": "#f2cc8f",
        "fir_l3_pipe": "#8d99ae",
    }

    fig, ax = plt.subplots(figsize=(8, 5))
    for _, row in kernel.iterrows():
        top = row["top"]
        ax.scatter(
            row["lut"],
            row["throughput_msps_est"],
            s=120,
            color=colors.get(top, "#444444"),
            edgecolors="black",
            linewidths=0.7,
        )
        ax.annotate(
            labels.get(top, top),
            (row["lut"], row["throughput_msps_est"]),
            textcoords="offset points",
            xytext=(6, 6),
            fontsize=9,
        )
    ax.set_xlabel("LUT")
    ax.set_ylabel("Throughput (MS/s)")
    ax.set_title("Kernel Scope: Resource vs Throughput")
    style_axes(ax)
    save(fig, "resource_vs_throughput.png")


def plot_power_vs_throughput(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    scope_styles = {
        "kernel": ("#e07a5f", "o"),
        "board_shell": ("#3b6ea5", "s"),
    }
    for _, row in df.iterrows():
        color, marker = scope_styles.get(row["scope"], ("#444444", "o"))
        ax.scatter(
            row["power_total_w"],
            row["throughput_msps_est"],
            s=120,
            color=color,
            marker=marker,
            edgecolors="black",
            linewidths=0.7,
        )
        ax.annotate(
            row["top"],
            (row["power_total_w"], row["throughput_msps_est"]),
            textcoords="offset points",
            xytext=(6, 6),
            fontsize=8,
        )
    ax.scatter([], [], color="#e07a5f", marker="o", label="kernel scope")
    ax.scatter([], [], color="#3b6ea5", marker="s", label="board-shell scope")
    ax.set_xlabel("Power (W)")
    ax.set_ylabel("Throughput (MS/s)")
    ax.set_title("Power vs Throughput")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "power_vs_throughput.png")


def plot_route_vs_logic_delay(df: pd.DataFrame) -> None:
    labels = [
        "custom" if "pipe" in top else "vendor"
        for top in df["top"].tolist()
    ]
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.bar(labels, df["logic_delay_ns"], label="logic", color="#e07a5f")
    ax.bar(
        labels,
        df["route_delay_ns"],
        bottom=df["logic_delay_ns"],
        label="route",
        color="#3b6ea5",
    )
    for idx, row in enumerate(df.itertuples(index=False)):
        ax.text(
            idx,
            row.data_path_delay_ns + 0.04,
            f"WNS={row.wns_ns:.3f}",
            ha="center",
            va="bottom",
            fontsize=8,
        )
    ax.set_ylabel("Delay (ns)")
    ax.set_title("Board-Shell Critical Path: Logic vs Route Delay")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "route_vs_logic_delay.png")


def plot_board_shell_power_breakdown(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    labels = ["custom", "vendor"]
    parts = [
        ("hier_ps_w", "PS8", "#3b6ea5"),
        ("hier_fir_shell_w", "FIR shell", "#e07a5f"),
        ("hier_dma_w", "DMA", "#81b29a"),
        ("hier_data_ic_w", "Interconnect", "#f2cc8f"),
        ("hier_ctrl_w", "Control", "#8d99ae"),
        ("power_static_w", "Static", "#c9c9c9"),
    ]

    bottom = [0.0] * len(df)
    for column, label, color in parts:
        values = df[column].tolist()
        ax.bar(labels, values, bottom=bottom, label=label, color=color)
        bottom = [b + v for b, v in zip(bottom, values)]

    ax.set_ylabel("Power (W)")
    ax.set_title("Board-Shell Power Breakdown")
    ax.legend(frameon=False, ncol=2)
    style_axes(ax)
    save(fig, "board_shell_power_breakdown.png")


def plot_board_validation_cycles(df: pd.DataFrame) -> None:
    latest = (
        df.sort_values(["arch", "run_id"])
        .groupby("arch", as_index=False)
        .tail(8)
        .copy()
    )
    pivot = latest.pivot(index="case_name", columns="arch", values="cycles")
    case_order = [
        "impulse",
        "step",
        "random_short",
        "passband_edge_sine",
        "transition_sine",
        "multitone",
        "stopband_sine",
        "large_random_buffer",
    ]
    pivot = pivot.reindex(case_order)

    fig, ax = plt.subplots(figsize=(10, 5))
    x = range(len(pivot.index))
    width = 0.36
    custom = pivot["fir_pipe_systolic"].tolist()
    vendor = pivot["vendor_fir_ip"].tolist()
    ax.bar([i - width / 2 for i in x], custom, width=width, label="custom", color="#e07a5f")
    ax.bar([i + width / 2 for i in x], vendor, width=width, label="vendor", color="#3b6ea5")
    ax.set_xticks(list(x))
    ax.set_xticklabels(pivot.index, rotation=20, ha="right")
    ax.set_ylabel("Cycles")
    ax.set_title("Latest Board Validation Cycles by Case")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "board_validation_cycles.png")


def plot_quantized_response(float_coeffs: np.ndarray, fixed_coeffs: np.ndarray) -> None:
    w_float, h_float = signal.freqz(float_coeffs, worN=4096)
    w_fixed, h_fixed = signal.freqz(fixed_coeffs, worN=4096)

    freq_float = w_float / np.pi
    freq_fixed = w_fixed / np.pi
    mag_float = 20.0 * np.log10(np.maximum(np.abs(h_float), 1e-12))
    mag_fixed = 20.0 * np.log10(np.maximum(np.abs(h_fixed), 1e-12))

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(freq_float, mag_float, label="float", color="#3b6ea5", linewidth=2.0)
    ax.plot(freq_fixed, mag_fixed, label="quantized Q20", color="#e07a5f", linewidth=1.6)
    ax.axvline(0.2, color="#666666", linestyle="--", linewidth=1.0)
    ax.axvline(0.23, color="#666666", linestyle="--", linewidth=1.0)
    ax.axhline(-80.0, color="#888888", linestyle=":", linewidth=1.0)
    ax.set_xlim(0.0, 1.0)
    ax.set_ylim(-120, 5)
    ax.set_xlabel("Normalized Frequency (× Nyquist)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_title("Float vs Quantized Frequency Response")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "freqresp_quantized_compare.png")


def plot_quantization_threshold(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(7.5, 4.5))
    ax.plot(df["coef_width"], df["ast_db"], marker="o", color="#3b6ea5", linewidth=2.0)
    ax.axhline(80.0, color="#e07a5f", linestyle="--", linewidth=1.2, label="80 dB target")
    for _, row in df.iterrows():
        ax.annotate(
            f"{int(row['coef_width'])}",
            (row["coef_width"], row["ast_db"]),
            textcoords="offset points",
            xytext=(0, 8),
            ha="center",
            fontsize=8,
        )
    ax.set_xlabel("Coefficient Width")
    ax.set_ylabel("Stopband Attenuation (dB)")
    ax.set_title("Coefficient Width Sweep vs Stopband Attenuation")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "coef_width_vs_ast.png")


def write_manifest() -> None:
    manifest = {
        "generated_plots": [
            "resource_vs_throughput.png",
            "power_vs_throughput.png",
            "route_vs_logic_delay.png",
            "board_shell_power_breakdown.png",
            "board_validation_cycles.png",
            "freqresp_quantized_compare.png",
            "coef_width_vs_ast.png",
        ]
    }
    (PLOTS_DIR / "report_plot_manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    efficiency = load_efficiency()
    power = load_power_breakdown()
    critical = load_critical_paths()
    board = load_board_results()
    float_coeffs = load_final_float_coeffs()
    fixed_coeffs = load_final_fixed_coeffs()
    quant = pd.read_csv(ROOT / "data" / "analysis" / "quantization_threshold.csv")

    plot_resource_vs_throughput(efficiency)
    plot_power_vs_throughput(efficiency)
    plot_route_vs_logic_delay(critical)
    plot_board_shell_power_breakdown(power)
    plot_board_validation_cycles(board)
    plot_quantized_response(float_coeffs, fixed_coeffs)
    plot_quantization_threshold(quant)
    write_manifest()


if __name__ == "__main__":
    main()
