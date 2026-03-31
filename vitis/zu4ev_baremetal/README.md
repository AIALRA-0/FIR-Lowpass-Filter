# ZU4EV Bare-Metal Harness

This directory stores the mainline bare-metal project source files for `MZU04A-4EV / XCZU4EV-SFVC784-2I`. The mainline strategy is fixed as follows:

- `PS UART0` is connected to the on-board `CP2104`, and the host-side console is `COM9`
- JTAG is used to download the bitstream / ELF
- `AXI DMA + AXI-Stream FIR shell + AXI-Lite control` acts as the unified system shell
- The software only uses scalar `Q1.15` sample arrays, without distinguishing `scalar / L2 / L3`

## Build Prerequisites

- First run `vivado/tcl/zu4ev/build_zu4ev_system.tcl` inside Vivado
- Export an `.xsa` that includes the bitstream
- Use Vitis/XSCT to create the standalone platform and this application from that `.xsa`

## Current Smoke-Test Coverage

- `impulse`
- `step`
- `random_short`

These vectors are automatically exported from `vectors/` in the repository by `scripts/export_zu4ev_vectors.py`.
