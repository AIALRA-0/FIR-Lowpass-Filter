# Synthesis Summary

The current implementation results are split into two explicit framings:

- `kernel scope`: fair comparison among the five custom RTL kernels
- `board-shell scope`: final system comparison for `PS + AXI DMA + FIR shell + bare-metal harness`

This separation is necessary because if both kinds of numbers are mixed together, the fixed overhead of PS8 and DMA will hide the differences among the FIR kernels themselves.

## Kernel Scope

| Top | Arch | Fmax est (MHz) | Throughput (MS/s) | LUT | FF | DSP | Power (W) | Energy/sample (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | `symmetry_folded` | `127.065` | `127.065` | `2810` | `3569` | `126` | `0.880` | `6.926` |
| `fir_pipe_systolic` | `pipelined_systolic` | `459.348` | `459.348` | `16712` | `17224` | `132` | `1.747` | `3.803` |
| `fir_l2_polyphase` | `l2_polyphase` | `139.334` | `278.668` | `5868` | `2439` | `262` | `1.328` | `4.766` |
| `fir_l3_polyphase` | `l3_polyphase` | `127.129` | `381.388` | `34687` | `6914` | `175` | `3.484` | `9.135` |
| `fir_l3_pipe` | `l3_pipeline` | `121.095` | `363.284` | `34786` | `7199` | `175` | `3.545` | `9.758` |

## Normalized Efficiency in Kernel Scope

| Top | Throughput/DSP | Throughput/kLUT | Throughput/W | Notes |
| --- | ---: | ---: | ---: | --- |
| `fir_symm_base` | `1.008` | `45.219` | `144.392` | Extremely small area, but both frequency and energy efficiency are surpassed by the pipelined version |
| `fir_pipe_systolic` | `3.480` | `27.486` | `262.935` | The current custom `performance hero` and `efficiency hero` |
| `fir_l2_polyphase` | `1.064` | `47.489` | `209.840` | Strong LUT utilization efficiency, but a relatively high DSP cost |
| `fir_l3_polyphase` | `2.179` | `10.995` | `109.468` | High throughput, but clearly higher LUT and power cost |
| `fir_l3_pipe` | `2.076` | `10.443` | `102.478` | The deeper pipeline did not produce an energy-efficiency advantage |

## Board-Shell Scope

| Top | Arch | Fmax est (MHz) | Throughput (MS/s) | LUT | FF | DSP | BRAM | Power (W) | Energy/sample (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `board_shell_custom` | `347.826` | `347.826` | `20253` | `21909` | `132` | `3.0` | `2.971` | `8.542` |
| `zu4ev_fir_vendor_top` | `board_shell_vendor_ip` | `347.102` | `347.102` | `8856` | `13428` | `131` | `3.0` | `2.861` | `8.243` |

## Normalized Efficiency in Board-Shell Scope

| Top | Throughput/DSP | Throughput/kLUT | Throughput/W | Notes |
| --- | ---: | ---: | ---: | --- |
| `zu4ev_fir_pipe_systolic_top` | `2.635` | `17.174` | `117.074` | The custom shell keeps almost the same system frequency as the vendor version |
| `zu4ev_fir_vendor_top` | `2.650` | `39.194` | `121.322` | The current winner for system-level resource efficiency and energy efficiency |

## Current Conclusions

- `fir_pipe_systolic` is the `performance hero` in the current custom RTL matrix
  - highest `Fmax`
  - highest `throughput`
  - lowest `energy/sample`
  - best `throughput/DSP`
- `fir_l2_polyphase` has proven that true `polyphase + symmetry` RTL can enter the full implementation chain
  - but at the moment it looks more like an intermediate high-throughput / high-DSP-cost solution
- `fir_l3_polyphase` and `fir_l3_pipe` have evolved from “can they fit” into “are they worth it”
  - their throughput is already high enough to be presentation-worthy
  - but they still do not beat a high-quality scalar pipeline
- `vendor FIR IP` is the current industrial-baseline winner under `board-shell scope`
  - almost the same frequency as the custom system shell
  - lower LUT / FF
  - slightly lower `power` and `energy/sample`

## Timing and Power Notes

- Current target device: `xczu4ev-sfvc784-2-i`
- Default kernel-scope target period: `3.333 ns`
- Current board-shell PL clock: `3.750 ns`
- Current power numbers come from routed vectorless `report_power`
- `Confidence Level = Medium`

Therefore, the current power numbers should be interpreted as:

- **very suitable for relative comparison**
- **not suitable as final sign-off absolute power**

More detailed critical-path, power-breakdown, and routing explanations are in:

- `reports/timing_power_analysis.md`
- `data/analysis/power_breakdown.csv`
- `data/analysis/critical_path_breakdown.csv`
- `data/analysis/route_status.csv`
