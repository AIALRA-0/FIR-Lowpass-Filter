# Board Validation

## Status

The ZU4EV board-level automation closure is now running stably. Both of the current formal acceptance architectures have completed:

- automatic bitstream generation and export
- automatic `.xsa` export
- automatic XSCT/JTAG download of bitstream + ELF
- automatic `COM9 / CP210x` UART capture
- automatic judgment for smoke + frequency-edge + long-run cases

The current formal endgame targets are:

- `fir_pipe_systolic`
- `vendor_fir_ip`

## Latest Passing Board Runs

| Arch | Run ID | Arch ID | Result | Log |
| --- | --- | ---: | --- | --- |
| `fir_pipe_systolic` | `20260330-113630` | `1` | PASS | `data/board_runs/fir_pipe_systolic/20260330-113630/uart.log` |
| `vendor_fir_ip` | `20260330-113805` | `5` | PASS | `data/board_runs/vendor_fir_ip/20260330-113805/uart.log` |

## Current Formal On-Board Cases

| Case | Length | Purpose |
| --- | ---: | --- |
| `impulse` | `1024` | impulse response and coefficient ordering |
| `step` | `1024` | DC convergence |
| `random_short` | `1024` | bit-true smoke |
| `passband_edge_sine` | `1024` | passband-edge preservation |
| `transition_sine` | `1024` | transition-band behavior |
| `multitone` | `2048` | multitone stability |
| `stopband_sine` | `1024` | stopband suppression |
| `large_random_buffer` | `2048` | long-buffer + DMA stability |

The latest formal runs of both architectures satisfy:

- `8 / 8` cases passed
- `mismatches = 0`
- `failures = 0`
- `status = 0x00000001`

## Stability Over the Latest 3 Formal Windows

| Arch | Window Runs | All Passed | Run IDs |
| --- | ---: | --- | --- |
| `fir_pipe_systolic` | `3` | `True` | `20260330-112958, 20260330-113315, 20260330-113630` |
| `vendor_fir_ip` | `3` | `True` | `20260330-113137, 20260330-113453, 20260330-113805` |

More detailed per-case cycle statistics are available in:

- `reports/board_stability.md`
- `data/analysis/board_stability_recent_arch.csv`
- `data/analysis/board_stability_recent_cases.csv`

## Key Observations

- The real system-level blocker resolved in this round was the `AXI DMA -> HPC0 -> OCM` address map. After `assign_bd_address`, Vivado marked `SEG_ps_0_HPC0_LPS_OCM` as excluded by default; restoring that segment mapping removed the DMA decode error.
- The bare-metal harness now runs stably on static DMA buffers in OCM and no longer depends on the DDR/cache-maintenance path for mainline acceptance.
- `passband_edge_sine` and `transition_sine` have now entered the formal board-validation suite, which means on-board validation no longer checks only impulse/step/random and now covers frequency-edge behavior directly tied to the filter spec.
- The cycle counts of `fir_pipe_systolic` and `vendor_fir_ip` are very close, which shows that under the current system shell, the fixed overhead of PS/DMA/stream-shell infrastructure is a large fraction of the total.

## Source-of-Truth Files

- Summary CSV: `data/board_results.csv`
- Recent-window stability: `data/analysis/board_stability_recent_arch.csv`
- Full-history stability: `data/analysis/board_stability_arch.csv`
- Raw UART JSON: `data/board_runs/<arch>/<run_id>/uart.json`
- Raw UART log: `data/board_runs/<arch>/<run_id>/uart.log`

## Automation Entry Points

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch fir_pipe_systolic -ForceAppBuild -MaxAttempts 2
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch vendor_fir_ip -ForceAppBuild -MaxAttempts 2
```

After each successful closure run, the script automatically refreshes:

- `data/board_results.csv`
- `data/analysis/board_stability_*.csv`
- `data/impl_results.csv`
- `data/analysis/*.csv`
