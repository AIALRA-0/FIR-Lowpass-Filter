# Vendor vs Custom

## Comparison Framing

This page discusses the comparison under two different framings:

- `kernel scope`: fair comparison among custom RTL kernels
- `board-shell scope`: final on-board comparison of `PS + AXI DMA + FIR shell + bare-metal harness`

## Kernel Scope

Within the pure custom RTL kernel matrix, the current champion is still `fir_pipe_systolic`:

- `459.348 MHz`
- `459.348 MS/s`
- `132 DSP`
- `3.803 nJ/sample`

This shows that for a project like this one, with 261 taps, linear phase, and strict bit-true FIR behavior, a carefully implemented symmetry-folded + systolic pipeline is still the strongest custom engineering solution.

## Board-Shell Scope

Under the same ZU4EV system shell, both `custom` and `vendor` have already completed automatic programming and on-board validation:

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | BRAM | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `board_shell_custom` | `347.826` | `20253` | `21909` | `132` | `3.0` | `2.971` | `8.542` |
| `zu4ev_fir_vendor_top` | `board_shell_vendor_ip` | `347.102` | `8856` | `13428` | `131` | `3.0` | `2.861` | `8.243` |

## Power Breakdown

If we only look at whole-system total power, the two designs seem fairly close:

- `custom total = 2.971 W`
- `vendor total = 2.861 W`

But once routed power is broken down by hierarchy, the difference becomes clearer:

| Top | PS8 (W) | FIR shell (W) | DMA (W) | Interconnect (W) |
| --- | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `2.228` | `0.238` | `0.016` | `0.009` |
| `zu4ev_fir_vendor_top` | `2.228` | `0.132` | `0.014` | `0.008` |

This shows that:

- `PS8` is basically a fixed background power cost
- The real FIR-architecture difference is reflected by `fir_shell_0`
- Under the current system shell, the FIR subsystem dynamic power of the custom shell is clearly higher than the vendor version

## Critical-Path Observations

Neither system shell now has “the FIR MAC core itself” as the slowest path; both land in the system-interface region from FIR output to FIFO:

| Top | Data Path (ns) | Logic (ns) | Route (ns) | Logic Levels | WNS (ns) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `2.859` | `1.348` | `1.511` | `13` | `0.458` |
| `zu4ev_fir_vendor_top` | `2.877` | `1.263` | `1.614` | `11` | `0.452` |

Both paths show routing-dominant behavior, which is why the two system-level frequencies are almost the same and do not separate as clearly as they do under kernel scope.

## Conclusions

- Under `board-shell scope`, `vendor FIR IP` uses less LUT/FF and is also slightly better in power and `energy/sample`.
- Under `board-shell scope`, the custom `fir_pipe_systolic` runs at a slightly higher frequency, but the gap is very small.
- Both architectures passed the same on-board cases with `mismatches = 0`, so the conclusion is based on the same functional acceptance chain.
- The final project narrative should stay honest:
  - `fir_pipe_systolic` is the strongest current custom research architecture and the most valuable custom implementation in the course project.
  - `vendor FIR IP` is the leaner, more industrial ready-made baseline and has the system-level advantage in area and energy efficiency.

## Why This Comparison Matters

- It proves that we are not only capable of “making RTL run,” but also understand what the industrial baseline looks like and can compare against it on the same platform, with the same bit widths, the same vectors, and the same board-validation flow.
- It also makes the project conclusion more credible: not every metric is won by the custom version, but the custom version has more presentation value in architectural transparency, research interpretability, DFG/SFG presentation, and full-chain closure from MATLAB to RTL to board validation.
