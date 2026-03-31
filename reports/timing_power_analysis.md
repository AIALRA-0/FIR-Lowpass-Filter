# Timing And Power Analysis

This page concentrates the most information-dense implementation analysis currently available: power breakdown, critical-path decomposition, and routing status. All of them come from routed reports rather than hand estimates.

## Power Method Notes

- The current power data comes from Vivado routed `report_power`
- The current mode is vectorless, with `Confidence Level = Medium`
- Therefore these numbers are best suited for **relative comparison**, not for absolute sign-off power
- For this project, the key question is not “is the total power precise down to the milliwatt,” but rather:
  - the relative ordering of `custom` and `vendor`
  - the layered contribution of `PS8` and the `FIR shell`
  - why we must distinguish between `kernel scope` and `board-shell scope`

## Board-Shell Power Breakdown

| Top | Total (W) | Dynamic (W) | Static (W) | PS8 (W) | FIR shell (W) | DMA (W) | Interconnect (W) | Control (W) | Confidence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `zu4ev_fir_pipe_systolic_top` | `2.971` | `2.516` | `0.455` | `2.228` | `0.238` | `0.016` | `0.009` | `0.022` | `Medium` |
| `zu4ev_fir_vendor_top` | `2.861` | `2.408` | `0.454` | `2.228` | `0.132` | `0.014` | `0.008` | `0.022` | `Medium` |

## Power Conclusions

- The whole-system total power difference is small: `custom` is about `0.110 W` higher than `vendor`
- Within that gap, `PS8` is essentially fixed at `2.228 W`, which shows that **whole-system total power is dominated by PS**
- The real FIR-architecture difference is reflected by `fir_shell_0`
  - `custom`: `0.238 W`
  - `vendor`: `0.132 W`
- In other words, under the current ZU4EV system shell, the FIR subsystem dynamic power of the custom shell is about `0.106 W` higher than the vendor version
- That is exactly why we insist on the dual framing of `kernel scope + board-shell scope`:
  - if we only look at whole-system total power, PS8 hides the FIR-kernel difference
  - if we only look at kernel scope, we miss the real integration cost of the final system

## Critical-Path Decomposition

| Top | Source | Destination | Data Path (ns) | Logic (ns) | Route (ns) | Logic Levels | WNS (ns) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `acc_pipe_reg[130][45]` | `u_output_fifo` BRAM DIN | `2.859` | `1.348` | `1.511` | `13` | `0.458` |
| `zu4ev_fir_vendor_top` | `m_axis_data_tdata_int_reg[7]` | `u_output_fifo` BRAM DIN | `2.877` | `1.263` | `1.614` | `11` | `0.452` |

## Critical-Path Conclusions

- The current worst path at system level is no longer “the FIR MAC itself”
- The worst path of `custom` starts from `acc_pipe_reg`, passes through `u_round_sat`, and then writes into the output FIFO BRAM
- The worst path of `vendor` also lands in the system-interface region from FIR output to FIFO, not on the PS-side control path
- Both paths clearly show routing-dominant behavior:
  - `custom`: route accounts for `52.851%`
  - `vendor`: route accounts for `56.100%`
- This indicates that under the current shell, the performance bottleneck has already moved to:
  - rounding/saturation
  - FIFO write ingress
  - local interconnect and placement

## Routing Status

| Top | Logical Nets | Routable Nets | Fully Routed Nets | Routing Errors | Fully Routed (%) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `159196` | `29571` | `29571` | `0` | `100.0` |
| `zu4ev_fir_vendor_top` | `130345` | `22955` | `22955` | `0` | `100.0` |

## Routing Interpretation

- Both system shells are now fully routed, with no routing errors
- `custom` has significantly more logical nets and routable nets than `vendor`
- This matches the final resource results:
  - `custom` keeps the custom shell, explainable rounding/saturation, and explicit control paths
  - `vendor` is more compact in the FIR kernel itself, so the routing pressure in the system shell is also lower

## Additional Normalized Efficiency

| Top | Throughput (MS/s) | Throughput/DSP | Throughput/kLUT | Throughput/W | Energy/sample (nJ) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_pipe_systolic` | `459.348` | `3.480` | `27.486` | `262.935` | `3.803` |
| `fir_l2_polyphase` | `278.668` | `1.064` | `47.489` | `209.840` | `4.766` |
| `fir_l3_polyphase` | `381.388` | `2.179` | `10.995` | `109.468` | `9.135` |
| `fir_l3_pipe` | `363.284` | `2.076` | `10.443` | `102.478` | `9.758` |
| `zu4ev_fir_pipe_systolic_top` | `347.826` | `2.635` | `17.174` | `117.074` | `8.542` |
| `zu4ev_fir_vendor_top` | `347.102` | `2.650` | `39.194` | `121.322` | `8.243` |

## Summary

- Under custom kernel scope, `fir_pipe_systolic` is still the strongest solution:
  - highest throughput
  - lowest `energy/sample`
  - best `throughput/DSP`
- Under board-shell scope, the final system built with `vendor FIR IP` is leaner:
  - lower LUT/FF
  - lower `FIR shell` dynamic power
  - slightly lower `energy/sample`
- The most important analytical conclusion is not “who is absolutely stronger,” but:
  - **the custom hero wins in research-grade RTL quality and architectural transparency**
  - **the vendor baseline wins in system-level compactness and integration maturity**
