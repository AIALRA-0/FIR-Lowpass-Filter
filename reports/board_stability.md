# Board Stability

This page distinguishes between “the board ran successfully once” and “the board can run stably and repeatedly.” To avoid failed runs from the early debug phase polluting the final statistics, the main table here uses only the **most recent 3 passing runs of the current formal 8-case suite**.

## Latest 3 Formal Windows

| Arch | Expected Case Count | Window Runs | All Passed | Run IDs |
| --- | ---: | ---: | --- | --- |
| `fir_pipe_systolic` | `8` | `3` | `True` | `20260330-112958, 20260330-113315, 20260330-113630` |
| `vendor_fir_ip` | `8` | `3` | `True` | `20260330-113137, 20260330-113453, 20260330-113805` |

## Custom Hero Stability

| Case | Length | Cycles Min | Cycles Mean | Cycles Max | Mismatch Sum | Error Status Count |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `impulse` | `1024` | `1297644` | `1297662.0` | `1297676` | `0` | `0` |
| `step` | `1024` | `1158807` | `1158821.667` | `1158837` | `0` | `0` |
| `random_short` | `1024` | `1529163` | `1529179.667` | `1529205` | `0` | `0` |
| `passband_edge_sine` | `1024` | `1806891` | `1806919.0` | `1806937` | `0` | `0` |
| `transition_sine` | `1024` | `1668051` | `1668055.667` | `1668059` | `0` | `0` |
| `multitone` | `2048` | `1391287` | `1391304.333` | `1391323` | `0` | `0` |
| `stopband_sine` | `1024` | `1575401` | `1575433.667` | `1575459` | `0` | `0` |
| `large_random_buffer` | `2048` | `1854209` | `1854228.333` | `1854251` | `0` | `0` |

## Vendor Baseline Stability

| Case | Length | Cycles Min | Cycles Mean | Cycles Max | Mismatch Sum | Error Status Count |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `impulse` | `1024` | `1297627` | `1297658.0` | `1297687` | `0` | `0` |
| `step` | `1024` | `1158816` | `1158825.667` | `1158843` | `0` | `0` |
| `random_short` | `1024` | `1529170` | `1529186.333` | `1529214` | `0` | `0` |
| `passband_edge_sine` | `1024` | `1806908` | `1806924.333` | `1806948` | `0` | `0` |
| `transition_sine` | `1024` | `1668043` | `1668051.667` | `1668068` | `0` | `0` |
| `multitone` | `2048` | `1391307` | `1391321.667` | `1391332` | `0` | `0` |
| `stopband_sine` | `1024` | `1575448` | `1575465.0` | `1575498` | `0` | `0` |
| `large_random_buffer` | `2048` | `1854248` | `1854267.0` | `1854295` | `0` | `0` |

## Observations

- In the latest 3 formal windows, both architectures achieved:
  - `8 / 8` cases passed
  - `mismatch_sum = 0`
  - `error_status_count = 0`
- The cycle count varies only slightly from run to run, which is consistent with normal jitter from JTAG download, PS startup, and DMA scheduling
- `passband_edge_sine` and `transition_sine` are now part of the formal board-validation set, which means:
  - On-board validation no longer checks only impulse / step / random
  - Edge-of-band frequency behavior has now been extended from the MATLAB/RTL chain into the full on-board system closure

## Notes

- The complete historical run set remains under `data/board_runs/`
- Full historical statistics are in:
  - `data/analysis/board_stability_arch.csv`
  - `data/analysis/board_stability_cases.csv`
- Formal reporting should prefer the recent-window statistics on this page because they reflect the **current final harness and the current formal case suite**, rather than a mixed state that includes early debug runs
