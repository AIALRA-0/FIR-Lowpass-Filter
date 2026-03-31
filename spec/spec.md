# Frozen Project Specification

## Course Specification

- Goal: low-pass FIR filter design and implementation
- Passband edge: `0.2π rad/sample`
- Stopband start: `0.23π rad/sample`
- Minimum stopband attenuation: `80 dB`

## MATLAB Normalization Convention

This project consistently follows the normalized-frequency convention used by MathWorks `firpm` / `firls` / `fir1`:

- `1.0` corresponds to the Nyquist frequency
- Therefore the course values `0.2π` and `0.23π` are written in MATLAB as `0.2` and `0.23`

## Design Targets

1. `baseline_taps100`
   - Fixed at `100 taps`
   - Mainly used to cover the natural interpretation of “100 taps” in the assignment
2. `baseline_order100`
   - Fixed at `order = 100`
   - That is, `101 coefficients`
   - Used to cover the MATLAB-semantic interpretation of “100th order”
3. `final_spec`
   - Allows a higher order
   - Targets a design that truly satisfies `Ast >= 80 dB`

## Winning Criteria

- `performance hero`
  - Prioritized by throughput and frequency performance
- `efficiency hero`
  - Prioritized by `throughput-per-DSP` and `energy-per-sample`

## Fixed-Point Defaults

- Input format: `Q1.15`
- Output quantization: `round-to-nearest + saturation`
- Truncation/saturation is only allowed at the final output
- Intermediate multiplication and accumulation are modeled in full precision

## Items Excluded From Mainline Acceptance

- Mainline results for `xc7z020clg400-2`
- Transpose as a primary design path
- TDM variants
- Full English report variant

## Current Main Platform

- Development board: `MZU04A-4EV`
- Main chip: `XCZU4EV-SFVC784-2I`
- PS serial port: `UART0`, `MIO34/35`
- Main console: `COM9 / CP210x`
- JTAG boot mode: `switch 1-ON 2-ON 3-ON`

## ZU4EV Implementation Defaults

- Default post-route target period: `3.333 ns`
- Aggressive sweep target period: `2.500 ns`
- Mainline system form: `PS + PL + AXI DMA + AXI-Stream FIR shell + AXI-Lite control`
- PS software stack: `Bare-metal Vitis`
