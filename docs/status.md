# Project Status

## Milestones

| Phase | Name | Status | Notes |
| --- | --- | --- | --- |
| P00 | Repository bootstrap and governance | Complete | Directory layout, conventions, documentation entry points, and LaTeX main document established |
| P01 | Specification freeze, rubric mapping, and research-question definition | Complete | `spec/spec.json` became the single source of truth |
| P02 | Literature and official-material matrix | Complete | The matrix and reading-note skeleton have been created |
| P03 | Floating-point design-space sweep | Complete | `final_spec` has been selected as `firpm / order 260 / 261 taps` |
| P04 | Fixed-point model and quantization decision | Complete | The default bit widths were selected as `Q1.15 + Wcoef20 + Wout16 + Wacc46` |
| P05 | DFG/SFG generator | Complete | Mermaid / SVG / `architecture_math.md` have been generated |
| P06 | Shared RTL skeleton and baseline | Complete | `fir_symm_base` completed bit-true scalar regression |
| P07 | Pipelined systolic | Complete | `fir_pipe_systolic` completed bit-true scalar regression and refreshed Vivado results |
| P08 | `L=2` polyphase | Complete | The reference kernel was replaced with true `polyphase + symmetry` RTL and passed vector regression and Vivado implementation |
| P09 | `L=3` polyphase / `L=3 + pipeline` | Complete | A shared `L3 FFA core` has been implemented; both versions passed bit-true regression and completed ZU4EV post-route |
| P10 | Unified verification chain | Complete | The minimum scalar and vector regression chain is fully connected; `impulse / step / random_short / lane_alignment` run in one command |
| P11 | Vivado synthesis / implementation | Complete | Results for five custom RTL architectures plus two board-shell flows have been summarized; `vendor FIR IP` is now part of the final comparison |
| P12 | Pages / LaTeX / Overleaf | Complete | README, Pages, Markdown reports, and LaTeX have been synchronized with the current ZU4EV mainline, board-validation results, and vendor baseline |

## Current Default Environment

- MATLAB: `R2024b`
- Main FPGA: `xczu4ev-sfvc784-2-i`
- Development board: `MZU04A-4EV`
- UART: `COM9 / CP210x`
- Report language: English mainline
- Git flow: direct push to `main`

## Current Data Snapshot

- `final_spec` floating-point: `Ap = 0.0304 dB`, `Ast = 83.9902 dB`
- Fixed-point defaults: `Wcoef = 20`, `Wout = 16`, `Wacc = 46`
- `fir_symm_base`: `WNS = -4.537 ns`, `Fmax = 127.065 MHz`
- `fir_pipe_systolic`: `WNS = 1.156 ns`, `Fmax = 459.348 MHz`
- `fir_l2_polyphase`: `WNS = -3.844 ns`, `Fmax = 139.334 MHz`, `throughput = 278.668 MS/s`
- Scalar regression: `fir_symm_base` / `fir_pipe_systolic` passed `impulse`, `step`, and `random_short`
- Vector regression: `fir_l2_polyphase` / `fir_l3_polyphase` / `fir_l3_pipe` passed `impulse`, `step`, `random_short`, and `lane_alignment`
- `fir_l3_polyphase`: `WNS = -4.533 ns`, `Fmax = 127.129 MHz`, `throughput = 381.388 MS/s`, `34687 LUT`, `175 DSP`
- `fir_l3_pipe`: `WNS = -4.925 ns`, `Fmax = 121.095 MHz`, `throughput = 363.284 MS/s`, `34786 LUT`, `175 DSP`
- board-shell: `zu4ev_fir_pipe_systolic_top` = `347.826 MHz`, `20253 LUT`, `21909 FF`, `132 DSP`
- board-shell: `zu4ev_fir_vendor_top` = `347.102 MHz`, `8856 LUT`, `13428 FF`, `131 DSP`
- Board-validation closure:
  - `fir_pipe_systolic`: `data/board_runs/fir_pipe_systolic/20260330-113630`
  - `vendor_fir_ip`: `data/board_runs/vendor_fir_ip/20260330-113805`
  - Summary: `data/board_results.csv`
  - Both architectures completed `8` on-board cases, with `mismatches = 0`
  - Stability over the latest `3` formal windows: `data/analysis/board_stability_recent_arch.csv`

## Current Conclusions

- In the current ZU4EV custom implementation matrix, `fir_pipe_systolic` is both the `performance hero` and the `efficiency hero`
- `fir_l2_polyphase` proves that a true polyphase datapath has entered a state that is synthesizable, regressable, and fairly comparable on a larger device
- `fir_l3_polyphase` and `fir_l3_pipe` are no longer limited by 7020 area; the current conclusion becomes: `L3` has strong throughput, but it still does not beat a high-quality scalar pipeline
- The current main question for `L3` is no longer “can it fit,” but “how do we turn the `DSP48E2`-friendly high-performance version into a real second-place candidate”
- `vendor FIR IP` has completed automatic programming and board validation under the same ZU4EV system shell and is now the formal industrial baseline
- Under `board-shell scope`, the vendor version leads with lower LUT/FF and slightly lower `energy/sample`; within the custom RTL matrix, `fir_pipe_systolic` remains the strongest research-oriented implementation
- The analysis layer now includes methodology framing, power breakdown, critical-path decomposition, bit-width derivation, and recent-window stability statistics
