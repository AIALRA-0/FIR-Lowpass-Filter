# FIR Lowpass Filter Research Kit

This is the GitHub Pages entry page for the project. The mainline platform has now fully switched to `MZU04A-4EV / XCZU4EV-SFVC784-2I`, and the site is organized around course grading points, engineering results, and on-board validation.

## Most Important Current Results

- The final filter that meets the specification is `firpm / order 260 / 261 taps`
- The default fixed-point format is `Q1.15 + Wcoef20 + Wout16 + Wacc46`
- Both scalar and vector bit-true regressions are fully working
- The current best custom implementation is `fir_pipe_systolic`
  - `459.348 MHz`
  - `459.348 MS/s`
  - `132 DSP`
  - `3.803 nJ/sample`
- `L=2 polyphase` has become a true `polyphase + symmetry` RTL
- `L=3` has been upgraded into a true compressed parallel architecture with a shared `L3 FFA core`, reaching `381.388 MS/s` on ZU4EV
- The `PS + PL` system shell can now export both bitstream and `.xsa`
- Both `fir_pipe_systolic` and `vendor FIR IP` have completed automatic programming, automatic UART capture, and on-board closure
- `vendor FIR IP` has become the formal industrial baseline and currently uses less LUT/FF and power under the same system shell
- The latest formal board-validation suite has been expanded to `8` cases, including `passband_edge_sine` and `transition_sine`
- Both `fir_pipe_systolic` and `vendor FIR IP` have completed the most recent `3` repeated formal windows, and all `8/8` cases passed

## Navigation

- [Project Status](status.md)
- [Rubric Mapping](rubric_map.md)
- [Literature Matrix](literature/lit_matrix.md)
- [Reading Notes](literature/reading_notes.md)
- [Synthesis Summary](../reports/synth_summary.md)
- [Methodology Summary](../reports/methodology_summary.md)
- [Timing / Power Analysis](../reports/timing_power_analysis.md)
- [Regression Report](../reports/regression_report.md)
- [ZU4EV Bring-Up](bringup_mzu04a_zu4ev.md)
- [System Shell Status](../reports/system_shell_status.md)
- [JTAG Status Report](../reports/jtag_status.md)
- [Board Validation Report](../reports/board_validation.md)
- [Board Stability](../reports/board_stability.md)
- [Vendor Comparison](../reports/vendor_vs_custom.md)

## Sections

1. MATLAB Design Description
2. Quantization and Fixed-Point Analysis
3. Architecture Design and DFG/SFG
4. Verification and Regression
5. ZU4EV Hardware Implementation Results
6. On-Board and System Validation
7. Conclusions and Follow-Up Work

## Current Milestones

- `P00-P05` research, specification, filter design, fixed-point work, and DFG are complete
- `P06-P10` scalar, pipelined, L=2, L=3 RTL and unified bit-true regression are complete
- `P11` the ZU4EV implementation matrix and board-shell results have both been refreshed, and `vendor FIR IP` has been added to the final comparison
- `P12` Pages / README / LaTeX have been synchronized with the current ZU4EV mainline, board-validation results, and vendor baseline
