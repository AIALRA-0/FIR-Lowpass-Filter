# Regression Report

## Status

- MATLAB floating-point design: complete
- MATLAB fixed-point sweep: complete
- Golden-vector generation: complete
- Vivado `xvlog` syntax check: complete
- Vivado `xelab` elaboration: complete
- `fir_symm_base` scalar bit-true: closed
- `fir_pipe_systolic` scalar bit-true: closed
- `fir_l2_polyphase` vector bit-true: closed
- `fir_l3_polyphase` vector bit-true: closed
- `fir_l3_pipe` vector bit-true: closed
- `fir_pipe_systolic` on-board automatic closure: closed
- `vendor FIR IP` on-board automatic closure: closed
- Verified regression cases: `impulse`, `step`, `random_short(1024-sample prefix)`, `lane_alignment`, `passband_edge`, `transition`, `stopband`, `multitone`, `overflow_corner`

## Notes

The current repository already provides:

- automatic golden-vector generation
- compilable scalar and vector testbenches
- Vivado simulation entry points
- `scripts/run_scalar_regression.ps1` as a one-command scalar regression entry
- `scripts/run_vector_regression.ps1` as a one-command vector regression entry
- `scripts/regenerate_vectors.py` as a fallback vector-regeneration path when MATLAB startup fails

The key fixes in this round were:

- the testbench now drives stimulus before the sampling edge, avoiding a one-cycle input offset
- missing memory files now trigger an immediate `fatal`, avoiding false PASS results
- vector quantization was corrected to signed fixed-point saturating quantization, removing the `Q1.15` sign-flip issue where `1.0 -> 16'h8000`
- `fir_symm_base` was changed to explicit `hist_bus` sample selection, removing the all-`x` problem caused by `sample_at()` under xsim
- `round_sat.v` was changed to symmetric nearest rounding so RTL matches the golden model
- `fir_pipe_systolic` now continues to push zero samples after `in_valid=0`, allowing the pipeline tail to drain correctly
- `tb_fir_vector.sv` keeps the strategy of automatically counting `input_frames` / `output_frames` from staged memory files, avoiding fragile xsim `plusargs` behavior on Windows paths
- `fir_l2_polyphase` has been replaced by a true `E0(z^2) / E1(z^2)` polyphase datapath
- `fir_l3_polyphase` / `fir_l3_pipe` have been replaced by true `L=3` polyphase datapaths with a shared `L3 FFA core`
- the `y2` recombination formula in `fir_l3_ffa_core` has been corrected to match the current 5-branch FFA decomposition exactly, removing systematic deviation under `step / lane_alignment`
- `fir_polyphase_coeffs.vh` now allows repeated inclusion across multiple modules, avoiding lost function declarations in mixed `l2/l3` compilation

## Minimum Passing Regression Matrix

| DUT | Cases | Result |
| --- | --- | --- |
| `fir_symm_base` | `impulse` / `step` / `random_short` | PASS |
| `fir_pipe_systolic` | `impulse` / `step` / `random_short` | PASS |
| `fir_l2_polyphase` | `impulse` / `step` / `random_short` / `lane_alignment_l2` | PASS |
| `fir_l3_polyphase` | `impulse` / `step` / `random_short` / `lane_alignment_l3` / `passband_edge` / `transition` / `stopband` / `multitone` / `overflow_corner` | PASS |
| `fir_l3_pipe` | `impulse` / `step` / `random_short` / `lane_alignment_l3` / `passband_edge` / `transition` / `stopband` / `multitone` / `overflow_corner` | PASS |

## Current Limitations

- `scripts/run_vector_regression.ps1` now supports `passband_edge / transition / stopband / multitone / overflow_corner`, but the repository still lacks a single-command wrapper that runs the full matrix and summarizes it into a table
- `fir_l3_pipe` and `fir_l3_polyphase` are numerically identical in simulation and differ only in latency; the current implementation difference is mainly reflected in register count and real Fmax, not in the numerical path

## Board-Level Closure

- `scripts/run_zu4ev_closure.ps1` can now complete:
  - bitstream / `.xsa` refresh
  - XSCT download of bitstream + ELF
  - automatic `COM9` UART capture
  - automatic PASS/FAIL judgment
  - automatic refresh of `data/board_results.csv`
- Latest passing board runs:
  - `fir_pipe_systolic`: `data/board_runs/fir_pipe_systolic/20260330-103046`
  - `vendor_fir_ip`: `data/board_runs/vendor_fir_ip/20260330-103107`
  - Summary: `data/board_results.csv`
- Both architectures passed:
  - `impulse`
  - `step`
  - `random_short`
  - `passband_edge_sine`
  - `transition_sine`
  - `multitone`
  - `stopband_sine`
  - `large_random_buffer`
- Current board-validation results for both architectures are:
  - `mismatches = 0`
  - `failures = 0`

## Current Next Priorities

- Add a unified summary script for the full regression matrix so PASS/FAIL, latency, and maximum error are written directly into a table
- If the next phase continues parallel-structure research, prioritize a deeply pipelined DSP48E2 version of `L=3`
- If the next phase continues presentation enhancement, consider ILA, DAQ, or oscilloscope measurement as non-mainline extensions
