# Implementation Closure

## Current Status

The two system-level blockers originally recorded here have both been closed:

- `vendor FIR IP` has been added to the final comparison
- The `PS + PL` system shell has completed bare-metal end-to-end validation

## Confirmed Observations

- `fir_l3_polyphase`: completed ZU4EV `place_design` and `route_design`
- `fir_l3_pipe`: completed ZU4EV `place_design` and `route_design`
- `zu4ev_fir_pipe_systolic_top`: completed bitstream, `.xsa`, and on-board closure
- `zu4ev_fir_vendor_top`: completed bitstream, `.xsa`, and on-board closure

The current results are:

| Top | LUT | DSP | WNS (ns) | Fmax (MHz) | Throughput (MS/s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_pipe_systolic` | `16712` | `132` | `1.156` | `459.348` | `459.348` |
| `fir_l3_polyphase` | `34687` | `175` | `-4.533` | `127.129` | `381.388` |
| `fir_l3_pipe` | `34786` | `175` | `-4.925` | `121.095` | `363.284` |

## Conclusions

- The current issue is no longer “resources exceed the limit completely”
- The current issue is also no longer “L3 cannot fit on the 7020”
- The only remaining improvement space is in performance optimization and presentation enhancement, not in mainline acceptance blockers
- On ZU4EV, `L3` already has good throughput, but it still has not won either the `performance hero` or `efficiency hero`
- The current system-level closure is complete, and future optimization should be treated as “nice-to-have polish”

## Optional Follow-Up Enhancements

- Deepen the truly DSP48E2-friendly pipeline for `fir_l3_pipe` to bring `L3` closer to `fir_pipe_systolic`
- After the system shell is stable, connect a second architecture into the same software harness to satisfy the final acceptance target of “at least two architectures on board”
- If presentation value is needed, later add ILA, DAQ, HDMI7611, or an oscilloscope
