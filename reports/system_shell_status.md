# ZU4EV System Shell Status

## Current Results

`vivado/tcl/zu4ev/build_zu4ev_system.tcl` has completed one real run on this machine under Vivado 2024.1 and successfully produced:

- bitstream
- `.xsa`
- a system hardware platform based on `Zynq UltraScale+ MPSoC + AXI DMA + AXI-Lite + FIR shell`

The system tops that have currently been validated and have completed automatic board-validation closure are:

- `zu4ev_fir_pipe_systolic_top`
- `zu4ev_fir_vendor_top`

Artifact locations:

- `build/zu4ev_system/zu4ev_fir_pipe_systolic_top/zu4ev_fir_pipe_systolic_top.xsa`
- `build/zu4ev_system/zu4ev_fir_vendor_top/zu4ev_fir_vendor_top.xsa`

## System Structure

- PS: `zynq_ultra_ps_e`
- Control bus: `M_AXI_HPM0_LPD + M_AXI_HPM0_FPD -> SmartConnect -> AXI DMA Lite + FIR control regs`
- Data bus: `AXI DMA <-> SmartConnect <-> S_AXI_HPC0_FPD`
- PL data shell: `fir_stream_shell`
- Board-level wrapper: `fir_zu4ev_shell`

## Resolved Issues

- `common.tcl` resolved the repository root incorrectly when called from the `zu4ev/` subdirectory
- the `module reference` path was missing `.vh` headers, preventing FIR shell instantiation
- Windows paths containing spaces caused the `.bd` path to be split
- when MPSoC exposed both `HPM0_FPD` and `HPM0_LPD`, incomplete address paths caused `validate_bd_design` failure
- when `AXI DMA` accessed OCM through `HPC0`, Vivado automatically excluded `SEG_ps_0_HPC0_LPS_OCM`, causing MM2S decode error
- the current bare-metal harness DMA buffer has moved to static OCM arrays, and system-level smoke / long-run validation has passed

## Current Retained Warnings

- `S_AXI_HPC0_FPD` and `SmartConnect` still emit `ARUSER/AWUSER` width warnings
- `axi_dma` and the intermediate interconnect still have several performance and DRC advisory warnings
- the standalone kernel-scope synthesis flow for `vendor FIR IP` is still not merged into the default `run_vivado_impl.ps1` flow; the current mainline uses `board-shell scope` as the industrial-baseline framing

These warnings do not currently block bitstream or `.xsa` generation, but they still need to be closed down for board-level maintenance and long-term upkeep.

## Current Conclusions

- `scripts/run_zu4ev_closure.ps1` now implements the full automated `build -> download -> run -> capture -> judge` closure
- Both formal acceptance architectures have passed board validation:
  - `fir_pipe_systolic`
  - `vendor_fir_ip`
- The board-validation source data is located in:
  - `data/board_runs/`
  - `data/board_results.csv`
