# L=2 Architecture

## Architecture Definition

The current `fir_l2_polyphase` is no longer a reference kernel that “calls a scalar FIR twice in sequence,” but a true `2-parallel polyphase` datapath.

The coefficients are decomposed as:

- `E0[k] = h[2k]`, length `131`
- `E1[k] = h[2k+1]`, length `130`

Specifically:

- `E0` is linear-phase symmetric and can be folded into `66` unique multipliers
- `E1` is linear-phase symmetric and can be folded into `65` unique multipliers

The input is rearranged in block time:

- `x0[m] = x[2m]`
- `x1[m] = x[2m+1]`

The output equations are:

- `y0[m] = E0*x0 + z^-1(E1*x1)`
- `y1[m] = E0*x1 + E1*x0`

These correspond to four subpaths in RTL:

- `u00 = E0(x0)`
- `u01 = E0(x1)`
- `u10 = E1(x0)`
- `u11 = E1(x1)`

The final combination is:

- `lane0 = u00 + delay_1block(u11)`
- `lane1 = u01 + u10`

## Operation Count

| Item | Value |
| --- | ---: |
| taps | 261 |
| samples/cycle | 2 |
| branch lengths | `131 + 130` |
| branch unique multipliers | `66 + 65` |
| total branch instances | 4 |
| total branch multipliers in RTL | `66 + 66 + 65 + 65 = 262` |
| final lane adders | 2 synthesized `WACC`-level adders |
| block delay | 1 block delay on the `u11` path |
| rounding position | only after final lane recombination |
| latency_cycles | 1 |

## Regression Status

- `impulse`: PASS
- `step`: PASS
- `random_short`: PASS
- `lane_alignment_l2`: PASS

## Vivado Results

Target device: `xc7z020clg400-2`

| Metric | Value |
| --- | ---: |
| WNS | `-13.936 ns` |
| Fmax est | `52.809 MHz` |
| Throughput | `105.619 MS/s` |
| LUT | `13472` |
| FF | `4396` |
| DSP | `212` |
| Power | `1.647 W` |
| Energy/sample est | `15.594 nJ` |

## Conclusions

- This path already satisfies the research requirement of being a true polyphase datapath and is no longer a placeholder-style reference implementation
- On `xc7z020`, `L=2` doubles throughput but does not provide better timing or energy efficiency
- If the next round is meant to make `L=2` a stronger competitor, the focus should be on further compressing the matrix adder network and the register partitioning inside each branch, rather than falling back to simply duplicating two FIRs
