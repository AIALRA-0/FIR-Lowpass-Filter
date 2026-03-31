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
ANALYSIS_DIR = ROOT / "data" / "analysis"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)


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


def load_spec() -> dict:
    path = ROOT / "spec" / "spec.json"
    return json.loads(path.read_text(encoding="utf-8"))


def load_design_space() -> pd.DataFrame:
    path = ROOT / "data" / "design_space.csv"
    return pd.read_csv(path)


def load_weight_tradeoff() -> pd.DataFrame:
    path = ROOT / "data" / "weight_tradeoff.csv"
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


def parse_coeff_csv(text: str) -> np.ndarray:
    return np.array([float(token) for token in text.split(",")], dtype=float)


def select_baseline_row(df: pd.DataFrame, group_name: str) -> pd.Series:
    subset = df[df["design_group"] == group_name].copy()
    subset = subset.sort_values(["ast_db", "ap_db", "taps"], ascending=[False, True, True])
    return subset.iloc[0]


def select_final_row(df: pd.DataFrame) -> pd.Series:
    subset = df[(df["design_group"] == "final_spec") & (df["meets_spec"] == 1)].copy()
    if subset.empty:
        subset = df[df["design_group"] == "final_spec"].copy()
        subset = subset.sort_values(["ast_db"], ascending=[False])
        return subset.iloc[0]
    subset["even_penalty"] = 1 - subset["odd_length"].astype(int)
    subset = subset.sort_values(["taps", "even_penalty", "group_delay_samples"], ascending=[True, True, True])
    return subset.iloc[0]


def freq_response_db(coeffs: np.ndarray, worN: int = 8192) -> tuple[np.ndarray, np.ndarray]:
    w, h = signal.freqz(coeffs, worN=worN)
    return w / np.pi, 20.0 * np.log10(np.maximum(np.abs(h), 1e-14))


def plot_resource_vs_throughput(df: pd.DataFrame) -> None:
    kernel = df[df["scope"] == "kernel"].copy()
    labels = {
        "fir_symm_base": "Base",
        "fir_pipe_systolic": "Pipe",
        "fir_l2_polyphase": "L2",
        "fir_l3_polyphase": "L3",
        "fir_l3_pipe": "L3+Pipe",
    }
    offsets = {
        "fir_symm_base": (8, -2),
        "fir_pipe_systolic": (8, 6),
        "fir_l2_polyphase": (8, 6),
        "fir_l3_polyphase": (8, 8),
        "fir_l3_pipe": (8, -14),
    }
    colors = {
        "fir_symm_base": "#3b6ea5",
        "fir_pipe_systolic": "#e07a5f",
        "fir_l2_polyphase": "#81b29a",
        "fir_l3_polyphase": "#f2cc8f",
        "fir_l3_pipe": "#8d99ae",
    }

    fig, ax = plt.subplots(figsize=(8.8, 5.4))
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
            xytext=offsets.get(top, (8, 6)),
            fontsize=9,
            bbox=dict(boxstyle="round,pad=0.18", facecolor="white", edgecolor="none", alpha=0.8),
        )
    ax.margins(x=0.10, y=0.12)
    ax.set_xlabel("LUT")
    ax.set_ylabel("Throughput (MS/s)")
    ax.set_title("Kernel Scope: Resource vs Throughput")
    style_axes(ax)
    save(fig, "resource_vs_throughput.png")


def plot_power_vs_throughput(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(9.2, 5.6))
    scope_styles = {
        "kernel": ("#e07a5f", "o"),
        "board_shell": ("#3b6ea5", "s"),
    }
    labels = {
        "fir_symm_base": "Base-k",
        "fir_pipe_systolic": "Pipe-k",
        "fir_l2_polyphase": "L2-k",
        "fir_l3_polyphase": "L3-k",
        "fir_l3_pipe": "L3+P-k",
        "zu4ev_fir_pipe_systolic_top": "Custom-bs",
        "zu4ev_fir_vendor_top": "Vendor-bs",
    }
    offsets = {
        "fir_symm_base": (8, 4),
        "fir_pipe_systolic": (8, 6),
        "fir_l2_polyphase": (8, 4),
        "fir_l3_polyphase": (8, 8),
        "fir_l3_pipe": (8, -14),
        "zu4ev_fir_pipe_systolic_top": (-30, 8),
        "zu4ev_fir_vendor_top": (-30, -14),
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
            labels.get(row["top"], row["top"]),
            (row["power_total_w"], row["throughput_msps_est"]),
            textcoords="offset points",
            xytext=offsets.get(row["top"], (8, 6)),
            fontsize=8,
        )
    ax.scatter([], [], color="#e07a5f", marker="o", label="kernel scope")
    ax.scatter([], [], color="#3b6ea5", marker="s", label="board-shell scope")
    ax.margins(x=0.14, y=0.10)
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
    fig, ax = plt.subplots(figsize=(7.4, 4.9))
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
    ax.legend(frameon=False, loc="upper left", bbox_to_anchor=(1.01, 1.0), borderaxespad=0.0)
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
    ax.legend(
        frameon=False,
        loc="upper left",
        bbox_to_anchor=(1.01, 1.0),
        borderaxespad=0.0,
    )
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
    spec = load_spec()
    w_float, h_float = signal.freqz(float_coeffs, worN=4096)
    w_fixed, h_fixed = signal.freqz(fixed_coeffs, worN=4096)

    freq_float = w_float / np.pi
    freq_fixed = w_fixed / np.pi
    mag_float = 20.0 * np.log10(np.maximum(np.abs(h_float), 1e-12))
    mag_fixed = 20.0 * np.log10(np.maximum(np.abs(h_fixed), 1e-12))

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(freq_float, mag_float, label="float", color="#3b6ea5", linewidth=2.0)
    ax.plot(freq_fixed, mag_fixed, label="quantized Q20", color="#e07a5f", linewidth=1.6)
    ax.axvline(spec["wp"], color="#222222", linestyle="--", linewidth=1.0)
    ax.axvline(spec["ws"], color="#cc3333", linestyle="--", linewidth=1.0)
    ax.axhline(-spec["ast_min_db"], color="#cc3333", linestyle=":", linewidth=1.0)
    ax.text(
        spec["wp"] + 0.005,
        -14,
        "Wp = 0.20",
        color="#222222",
        fontsize=8,
        rotation=90,
        va="top",
    )
    ax.text(
        spec["ws"] + 0.005,
        -14,
        "Ws = 0.23",
        color="#cc3333",
        fontsize=8,
        rotation=90,
        va="top",
    )
    ax.text(
        0.84,
        -spec["ast_min_db"] + 2.5,
        "Ast target = -80 dB",
        color="#cc3333",
        fontsize=8,
    )
    ax.set_xlim(0.0, 1.0)
    ax.set_ylim(-120, 5)
    ax.set_xlabel("Normalized Frequency (× Nyquist)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_title("Float vs Quantized Frequency Response")
    ax.legend(frameon=False)
    style_axes(ax)
    save(fig, "freqresp_quantized_compare.png")


def plot_order_vs_ast(df: pd.DataFrame, spec: dict) -> None:
    final_rows = df[df["design_group"] == "final_spec"].copy()
    final_rows = final_rows.sort_values(["method", "ap_target_db", "order"])
    combos = (
        final_rows[["method", "ap_target_db"]]
        .drop_duplicates()
        .sort_values(["method", "ap_target_db"])
        .itertuples(index=False, name=None)
    )
    palette = [
        "#1f77b4",
        "#ff7f0e",
        "#2ca02c",
        "#d62728",
        "#9467bd",
        "#8c564b",
        "#e377c2",
        "#7f7f7f",
        "#17becf",
    ]

    fig, ax = plt.subplots(figsize=(8.6, 5.4))
    for idx, (method, ap_target) in enumerate(combos):
        subset = final_rows[
            (final_rows["method"] == method)
            & (np.isclose(final_rows["ap_target_db"], ap_target))
        ].copy()
        subset = subset.sort_values("order")
        ax.plot(
            subset["order"],
            subset["ast_db"],
            linestyle="-",
            marker=".",
            markersize=8,
            linewidth=1.2,
            color=palette[idx % len(palette)],
            label=f"{method}, Ap={ap_target:.2f} dB",
        )

    ax.axhline(spec["ast_min_db"], color="#444444", linestyle="--", linewidth=1.0, alpha=0.8)
    ax.text(
        final_rows["order"].max() + 6,
        spec["ast_min_db"] + 1.0,
        "Ast target = 80 dB",
        fontsize=8,
        color="#444444",
        va="bottom",
        bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor="none", alpha=0.75),
    )
    ax.set_xlim(final_rows["order"].min() - 5, 650)
    ymin = max(0.0, final_rows["ast_db"].min() - 8.0)
    ymax = final_rows["ast_db"].max() + 8.0
    ax.set_ylim(ymin, ymax)
    ax.set_xlabel("Order")
    ax.set_ylabel("Stopband Attenuation (dB)")
    ax.set_title("Final-Spec Order vs Stopband Attenuation")
    ax.legend(frameon=False, loc="center left", bbox_to_anchor=(1.02, 0.5))
    style_axes(ax)
    save(fig, "order_vs_ast.png")


def plot_float_frequency_compare(df: pd.DataFrame, spec: dict) -> None:
    baseline_taps = select_baseline_row(df, "baseline_taps100")
    baseline_order = select_baseline_row(df, "baseline_order100")
    final_row = select_final_row(df)
    rows = [
        ("baseline_taps100", parse_coeff_csv(baseline_taps["coeff_csv"]), "#3b6ea5"),
        ("baseline_order100", parse_coeff_csv(baseline_order["coeff_csv"]), "#81b29a"),
        ("final_spec", parse_coeff_csv(final_row["coeff_csv"]), "#e07a5f"),
    ]

    fig, axes = plt.subplots(3, 1, figsize=(9.2, 10.2), sharex=True)
    for ax, (label, coeffs, color) in zip(axes, rows):
        freq, mag = freq_response_db(coeffs)
        ax.plot(freq, mag, color=color, linewidth=1.4)
        ax.axvline(spec["wp"], color="#222222", linestyle="--", linewidth=1.0)
        ax.axvline(spec["ws"], color="#cc3333", linestyle="--", linewidth=1.0)
        ax.axhline(-spec["ast_min_db"], color="#cc3333", linestyle=":", linewidth=1.0)
        ax.text(spec["wp"] + 0.005, -14, "Wp = 0.20", color="#222222", fontsize=8, rotation=90, va="top")
        ax.text(spec["ws"] + 0.005, -14, "Ws = 0.23", color="#cc3333", fontsize=8, rotation=90, va="top")
        ax.text(0.84, -spec["ast_min_db"] + 2.5, "Ast target = -80 dB", color="#cc3333", fontsize=8)
        ax.set_xlim(0.0, 1.0)
        ax.set_ylim(-125, 5)
        ax.set_ylabel("Magnitude (dB)")
        ax.set_title(label)
        style_axes(ax)
    axes[-1].set_xlabel("Normalized Frequency (× Nyquist)")
    fig.suptitle("Floating-Point Frequency Response Comparison", y=0.995)
    save(fig, "freqresp_float_compare.png")


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


def plot_weight_tradeoff(df: pd.DataFrame) -> None:
    labels = {
        "firpm": "firpm",
        "firls": "firls",
    }
    colors = {
        "firpm": "#e07a5f",
        "firls": "#3b6ea5",
    }
    markers = {
        "ast_db": "o",
        "ap_db": "x",
    }

    fig, axes = plt.subplots(2, 1, figsize=(8.2, 7.2), sharex=True)
    metric_defs = [
        ("ast_db", "Stopband Attenuation (dB)", "Ast vs Stopband Weight"),
        ("ap_db", "Passband Ripple (dB)", "Ap vs Stopband Weight"),
    ]

    for ax, (metric, ylabel, title) in zip(axes, metric_defs):
        for method in sorted(df["method"].unique()):
            subset = df[df["method"] == method].sort_values("stop_weight")
            ax.plot(
                subset["stop_weight"],
                subset[metric],
                marker=markers[metric],
                markersize=4.5,
                linewidth=1.2,
                color=colors.get(method, "#666666"),
                label=labels.get(method, method),
            )
        ax.set_xscale("log")
        ax.set_xlabel("Stopband Weight (log scale)")
        ax.set_ylabel(ylabel)
        ax.set_title(title)
        style_axes(ax)

    axes[0].axhline(80.0, color="#666666", linestyle="--", linewidth=1.0, alpha=0.8)
    axes[0].text(
        1.02,
        80.6,
        "80 dB target",
        fontsize=8,
        color="#555555",
    )
    axes[0].legend(frameon=False, loc="lower right")
    fig.suptitle("Weight Sweep Tradeoff for firpm and firls", y=0.98)
    save(fig, "weight_tradeoff.png")


def build_method_choice_summary(df: pd.DataFrame) -> pd.DataFrame:
    final_spec = df[df["design_group"] == "final_spec"].copy()
    rows = []
    for method in sorted(final_spec["method"].unique()):
        subset = final_spec[(final_spec["method"] == method) & (final_spec["meets_spec"] == 1)].copy()
        if subset.empty:
            continue
        subset = subset.sort_values(["taps", "ap_db", "order"])
        best = subset.iloc[0]
        rows.append(
            {
                "method": method,
                "order": int(best["order"]),
                "taps": int(best["taps"]),
                "ap_target_db": float(best["ap_target_db"]),
                "ap_db": float(best["ap_db"]),
                "ast_db": float(best["ast_db"]),
            }
        )
    summary = pd.DataFrame(rows)
    summary.to_csv(ANALYSIS_DIR / "method_choice_summary.csv", index=False)
    return summary


def plot_method_choice(summary: pd.DataFrame) -> None:
    labels = {
        "firpm": "firpm",
        "firls": "firls",
        "kaiser": "kaiserord+fir1",
    }
    colors = {
        "firpm": "#e07a5f",
        "firls": "#3b6ea5",
        "kaiser": "#81b29a",
    }

    fig, ax = plt.subplots(figsize=(8, 4.8))
    x = np.arange(len(summary))
    bars = ax.bar(
        x,
        summary["taps"],
        color=[colors.get(method, "#666666") for method in summary["method"]],
        edgecolor="black",
        linewidth=0.7,
    )
    ax.set_xticks(x)
    ax.set_xticklabels([labels.get(method, method) for method in summary["method"]])
    ax.set_ylabel("Minimum Taps Meeting Spec")
    ax.set_title("Method Comparison: Minimum Taps Required for final_spec")
    style_axes(ax)
    for bar, row in zip(bars, summary.itertuples(index=False)):
        ax.text(
            bar.get_x() + bar.get_width() / 2.0,
            bar.get_height() + 4,
            f"Ast={row.ast_db:.2f} dB\nAp={row.ap_db:.3f} dB",
            ha="center",
            va="bottom",
            fontsize=8,
        )
    save(fig, "method_choice_min_taps.png")


def write_manifest() -> None:
    manifest = {
        "generated_plots": [
            "order_vs_ast.png",
            "weight_tradeoff.png",
            "freqresp_float_compare.png",
            "resource_vs_throughput.png",
            "power_vs_throughput.png",
            "route_vs_logic_delay.png",
            "board_shell_power_breakdown.png",
            "board_validation_cycles.png",
            "freqresp_quantized_compare.png",
            "coef_width_vs_ast.png",
            "method_choice_min_taps.png",
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
    spec = load_spec()
    design_space = load_design_space()
    weight_tradeoff = load_weight_tradeoff()
    float_coeffs = load_final_float_coeffs()
    fixed_coeffs = load_final_fixed_coeffs()
    quant = pd.read_csv(ROOT / "data" / "analysis" / "quantization_threshold.csv")
    method_choice = build_method_choice_summary(design_space)

    plot_order_vs_ast(design_space, spec)
    plot_float_frequency_compare(design_space, spec)
    plot_resource_vs_throughput(efficiency)
    plot_power_vs_throughput(efficiency)
    plot_route_vs_logic_delay(critical)
    plot_board_shell_power_breakdown(power)
    plot_board_validation_cycles(board)
    plot_quantized_response(float_coeffs, fixed_coeffs)
    plot_quantization_threshold(quant)
    plot_weight_tradeoff(weight_tradeoff)
    plot_method_choice(method_choice)
    write_manifest()


if __name__ == "__main__":
    main()
