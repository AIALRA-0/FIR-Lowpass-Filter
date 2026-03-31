# L=3 + Pipeline Tradeoff

## Goal

`fir_l3_pipe` is no longer a simple “one more register wrapped around the outside.” Instead, while keeping the math of `fir_l3_polyphase` exactly unchanged, it inserts pipeline cuts at three key points:

- input lane capture
- between subfilter outputs and the matrix adder
- between the final matrix adder and `round_sat`

## Current Implementation

The current version relates to `fir_l3_polyphase` as follows:

- identical numerical path
- fully identical vector-regression results
- increased latency only

The fixed differences are:

| Metric | `fir_l3_polyphase` | `fir_l3_pipe` |
| --- | ---: | ---: |
| samples/cycle | 3 | 3 |
| latency_cycles | 1 | 3 |
| numerical result | bit-exact | bit-exact |

## Regression Status

- `impulse`: PASS
- `step`: PASS
- `random_short`: PASS
- `lane_alignment_l3`: PASS

## Current Device Results

On `xc7z020clg400-2`, `fir_l3_pipe`, just like `fir_l3_polyphase`, is blocked by resource checks before `place_design`:

- `CARRY4` demand `26769`, while the device only has `13300`
- `LUT as Logic` demand `77385`, while the device only has `53200`

This shows that the current pipeline insertion is still insufficient to change the underlying problem that the current non-FFA `L3` mathematical expansion is too large.

## Conclusions

- `fir_l3_pipe` has completed the functional closure of a true pipelined version
- But on the current device, the main contradiction is not the critical path; it is the overall logic volume caused by the mathematical expansion
- Therefore, if the next optimization round continues on `L=3`, the priority should be compressing the computation graph rather than continuing to add registers
