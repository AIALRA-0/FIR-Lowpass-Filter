# Methodology Summary

This page consolidates the “comparison framing” that is otherwise easy to scatter across scripts and logs, so later reports do not end up with conclusions but no explanation of method.

## Design and Quantization Framing

- Specification source of truth: `spec/spec.json`
- Filter type: low-pass, linear-phase FIR
- Frequency boundaries: `wp = 0.2`, `ws = 0.23`
- Stopband requirement: `Ast >= 80 dB`
- Ambiguity handling in the assignment: keep both `baseline_taps100` and `baseline_order100`
- Main design method: `firpm`
- Final floating-point design: `order = 260`, `261 taps`
- Default fixed-point format: `Q1.15 + Wcoef20 + Wout16 + Wacc46`
- Internal policy: full-precision accumulate, unified final-stage `round + saturate`

## RTL Regression Framing

| Scope | Entry Script | DUT | Cases |
| --- | --- | --- | --- |
| scalar bit-true | `scripts/run_scalar_regression.ps1` | `fir_symm_base`, `fir_pipe_systolic` | `impulse`, `step`, `random_short` |
| vector bit-true | `scripts/run_vector_regression.ps1` | `fir_l2_polyphase`, `fir_l3_polyphase`, `fir_l3_pipe` | `impulse`, `step`, `random_short`, `lane_alignment`, `passband_edge`, `transition`, `stopband`, `multitone`, `overflow_corner` |
| golden-vector generation | `matlab/vectors/gen_vectors.m` or `scripts/regenerate_vectors.py` | shared by all RTL/board cases | scalar, `L=2`, and `L=3` all exported from the same fixed-point coefficients |

## Synthesis and Implementation Framing

| Item | Setting |
| --- | --- |
| Tool | `Vivado 2024.1` |
| Main device | `xczu4ev-sfvc784-2-i` |
| kernel-scope target period | `3.333 ns` |
| board-shell-scope current clock | `3.750 ns` |
| Result source of truth | `data/impl_results.csv` |
| Power framing | routed `report_power`, currently vectorless |
| Power confidence | `Medium` |
| Comparison method | report `kernel scope` and `board-shell scope` separately |

## Board-Level Automation Closure Framing

| Stage | Tool/Script | Purpose |
| --- | --- | --- |
| Preflight | `scripts/check_jtag_stack.ps1` | confirm `xczu4`, `arm_dap`, `COM9 / CP210x` |
| App build | `scripts/build_zu4ev_app.ps1` | export `.xsa`, generate bare-metal app, save `build_info.json` |
| Programming | `scripts/program_zu4ev.ps1` + XSCT/JTAG | automatically download bitstream + ELF |
| UART capture | `scripts/capture_uart.py` | automatically capture case logs and decide `PASS/FAIL` |
| Closure | `scripts/run_zu4ev_closure.ps1` | chain preflight, build, program, capture, and collection |

## Current Formal Board-Validation Suite

| Case | Length | Purpose |
| --- | ---: | --- |
| `impulse` | `1024` | check impulse response and coefficient sequence |
| `step` | `1024` | check DC convergence and steady state |
| `random_short` | `1024` | low-cost random bit-true smoke |
| `passband_edge_sine` | `1024` | check passband-edge magnitude preservation |
| `transition_sine` | `1024` | check transition-band suppression trend |
| `multitone` | `2048` | check overall behavior under multitone superposition |
| `stopband_sine` | `1024` | check stopband suppression |
| `large_random_buffer` | `2048` | check DMA + FIR stability under long buffers |

## Current Formal Comparison Framing

- `kernel scope`: compare only the FIR RTL kernels themselves, without PS/DMA/UART overhead.
- `board-shell scope`: compare the final `PS + AXI DMA + FIR shell + bare-metal harness` system.
- The formal on-board endgame targets are fixed to:
  - `fir_pipe_systolic`
  - `vendor_fir_ip`
- `L=2 / L=3` remain in the implementation matrix and analysis chapters, but are currently not the final on-board endgame protagonists.
