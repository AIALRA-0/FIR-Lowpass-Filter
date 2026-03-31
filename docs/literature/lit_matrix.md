# Literature and Official Material Matrix

| Source | Type | Core Topic | Reusable Value | Why It Is Not Copied Directly |
| --- | --- | --- | --- | --- |
| MathWorks FIR Filter Design | Official documentation | `firpm` / `firls` / windowing | Design-method comparison, linear-phase and symmetry fundamentals | Covers algorithm design only, not hardware microarchitecture |
| MathWorks Fixed-Point Filter Design | Official documentation | Coefficient quantization, overflow, and precision loss | bit-true modeling and quantization-analysis workflow | Does not provide concrete FPGA DSP mapping |
| AMD FIR Compiler PG149 | Official documentation | FIR IP structure, symmetry, systolic/transpose | Used as the vendor baseline and as evidence for symmetry utilization | The IP is a black box and is unsuitable as the mainline custom RTL path |
| AMD 7-series DSP48E1 User Guide | Official documentation | pre-adder, multiplier, cascade | Guides systolic partitioning and resource mapping | Does not provide a complete FIR system implementation |
| Intel FIR Compiler II | Official documentation | vector input, rounding/saturation | Reference for metrics and IP feature comparison | Different platform, used as comparison rather than the mainline |
| 2019 symmetry in conventional polyphase FIR | Paper | preserving coefficient symmetry in conventional polyphase FIR | Supports the L=2/L=3 direction | Must be translated into RTL that is implementable in this project |
| 2020 3-parallel odd-length FIR | Paper | L=3, odd-length, multiplier optimization | Supports the 3-parallel hero design | The equations must be reworked to match this project's bit widths and interfaces |
| 2024+ parallel FIR / FFA papers | Papers | hybrid parallel and fast FIR | Extends the L=3+pipeline combined design direction | Too complex to use directly and must be trimmed to the course-project scope |

## Current Conclusions

- Main design algorithm: `firpm`
- Main structural direction: `symmetry + direct-form/systolic + pipeline`
- Main parallel direction: `polyphase + symmetry`
- `transpose`: kept only as comparison material and not included in the mainline implementation
