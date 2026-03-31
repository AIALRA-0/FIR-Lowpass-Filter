# MZU04A-4EV Bring-Up

This page records the current board-level and connectivity conventions for the mainline platform `MZU04A-4EV / XCZU4EV-SFVC784-2I`. The goal is to lock JTAG, UART, the PS+PL bitstream, and the bare-metal harness into one repeatable flow.

## Board Facts

- Development board: `MZU04A-4EV`
- Main device: `XCZU4EV-SFVC784-2I`
- JTAG: Vivado Hardware Manager can already enumerate `xczu4` and `arm_dap`
- UART: `COM9 / Silicon Labs CP210x`
- Power: `12V`
- Mainline software stack: `Bare-metal Vitis`

## Default Cabling

- Connect `12V` external power to the development board
- Connect the JTAG download cable to the board's JTAG port
- After connecting the UART debug port to the host, Device Manager should show a `CP210x` serial port, currently `COM9`
- Do not treat UART as the download path; the main download and debug path is always JTAG

## Default Boot Conditions

According to the local hardware manual, the default JTAG bring-up mode is:

- `BOOT_MODE[2:0] = ON / ON / ON`
- After power-on, first confirm that the on-board power and clock status are normal, then open Vivado Hardware Manager

## Expected Enumeration Results

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_jtag_stack.ps1
```

The current expected result is:

- `Present USB Devices` shows both the `FTDI` JTAG cable and the `CP210x` UART
- `hw_server` can enumerate at least one target
- `Enumerated Devices` includes:
  - `part=xczu4`
  - `part=arm_dap`

This means the current chain has moved from the “driver troubleshooting” stage into the “system bring-up” stage.

## Bring-Up Order

1. Use `scripts/check_jtag_stack.ps1` to confirm that `xczu4` and `arm_dap` are visible.
2. Download a smoke bitstream first and verify:
   - PS UART prints correctly
   - PL clocks and resets are normal
   - AXI-Lite registers are accessible
3. Then download the FIR system bitstream and verify:
   - AXI DMA transfers correctly
   - `fir_stream_shell` can pack and unpack scalar streams into block streams
   - The bare-metal harness can print case summaries, cycle counts, and error counts
4. Only then run long cases:
   - `multitone`
   - `stopband sine`
   - `large random buffer`

## Mainline System Structure

- PS: `Zynq UltraScale+ MPSoC`
- Data movement: `AXI DMA`
- Control: `AXI-Lite`
- FIR cores: `fir_symm_base` / `fir_pipe_systolic` / `fir_l2_polyphase` / `fir_l3_polyphase` / `fir_l3_pipe`
- System shell: `rtl/system/fir_stream_shell.v` and `rtl/system/fir_zu4ev_shell.v`
- Software: `vitis/zu4ev_baremetal`

## Current Known Status

- RTL kernel-level bit-true regression has passed
- All five custom architectures on ZU4EV already have post-route data
- Both `fir_pipe_systolic` and `vendor FIR IP` have completed automatic programming, automatic UART capture, and on-board validation
- The currently passing formal on-board cases are:
  - `impulse`
  - `step`
  - `random_short`
  - `multitone`
  - `stopband_sine`
  - `large_random_buffer`
- Current board-validation results satisfy:
  - `mismatches = 0`
  - `failures = 0`

## Automation Entry Points

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch fir_pipe_systolic -ForceHardwareBuild -ForceAppBuild -MaxAttempts 1
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch vendor_fir_ip -ForceHardwareBuild -ForceAppBuild -MaxAttempts 1
```

## Common Troubleshooting

- `CP210x` is visible, but `xczu4` is not
  - Check the JTAG cable and power first, and do not treat UART as the download clue
- `xczu4` is visible, but the software prints nothing on the serial port
  - First confirm that `COM9` is not occupied by another serial tool, then check PS UART0 configuration and MIO assignment
- The bitstream downloads, but DMA does not work
  - First verify `AXI DMA`, the DDR/OCM buffer path, and cache flush/invalidate logic with a minimum loopback and short vectors

## Non-Mainline Extensions

The following devices are currently outside mainline acceptance:

- `MLK FEP DAQ001` 8-channel acquisition card
- `HDMI7611` video capture card
- External oscilloscope

These will only be considered as presentation enhancements after the mainline system is fully closed.
