# L=3 Architecture

## Architecture Definition

The current `fir_l3_polyphase` has replaced the old reference kernel and become a true `3-parallel polyphase` datapath.

The coefficients are decomposed as:

- `E0[k] = h[3k]`, length `87`
- `E1[k] = h[3k+1]`, length `87`
- `E2[k] = h[3k+2]`, length `87`

The symmetry-utilization strategy at this stage is:

- `E1` still keeps symmetry folding internally, with `44` unique multipliers
- `E0` and `E2` are cross-branch mirrors, but this stage does not share them across branches, so each is implemented as a full branch

The input rearrangement is:

- `x0[m] = x[3m]`
- `x1[m] = x[3m+1]`
- `x2[m] = x[3m+2]`

The output matrix is:

- `y0[m] = E0*x0 + z^-1(E1*x2 + E2*x1)`
- `y1[m] = E0*x1 + E1*x0 + z^-1(E2*x2)`
- `y2[m] = E0*x2 + E1*x1 + E2*x0`

## Operation Count

| Item | Value |
| --- | ---: |
| taps | 261 |
| samples/cycle | 3 |
| branch lengths | `87 + 87 + 87` |
| unique multipliers per branch family | `87 / 44 / 87` |
| total branch instances | 9 |
| effective branch multipliers in current RTL | `3*87 + 3*44 + 3*87 = 654` |
| delayed matrix terms | `E1*x2`, `E2*x1`, `E2*x2` |
| rounding position | only after final lane recombination |
| latency_cycles | 1 |

## Regression Status

- `impulse`: PASS
- `step`: PASS
- `random_short`: PASS
- `lane_alignment_l3`: PASS

## Current Device Results

Target device: `xc7z020clg400-2`

Synthesis and `opt_design` can complete, but DRC before `place_design` already reports resource overflow:

- `CARRY4` demand `26769`, while the device only has `13300`
- `LUT as Logic` demand `77369`, while the device only has `53200`

This is enough to prove that the current version already has:

- correct lane scheduling
- correct polyphase math
- synthesizable RTL

But it is still not the final competition-grade implementation on the current device.

## Conclusions

- This path has been upgraded from a “reference kernel” to a “true polyphase datapath”
- The current non-FFA implementation is enough to validate the architecture and regression chain, but it is not suitable as the final hero design on `xc7z020`
- The next truly valuable optimization directions are:
  - `FFA`
  - cross-branch sharing between `E0 / E2`
  - matrix-network compression
  - or migration to a larger device
