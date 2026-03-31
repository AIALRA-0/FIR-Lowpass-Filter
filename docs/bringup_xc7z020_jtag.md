# 7z020 JTAG Bring-Up

This page organizes the JTAG board-bring-up chain for the `xc7z020clg400-2` development board and the current host-side detection results into a repeatable flow.

## Board Facts

- `CH340 / COM7` is `USB-UART` and does not carry JTAG.
- JTAG uses the separate `14-pin` connector on the baseboard; the documentation states that this port is hard-wired to the core board's `6-pin JTAG`.
- The current project's default target board is `xc7z020clg400-2`.
- According to the board documentation, the fixed JTAG boot mode is:
  - `BOOT_MODE0 = ON`
  - `BOOT_MODE1 = ON`

## Current Host-Side Conclusion

- Windows can see:
  - `USB-SERIAL CH340 (COM7)`
  - two `VID_0403&PID_6014` FTDI devices
- `pnputil` shows that both Digilent and Xilinx cable drivers are installed.
- The current `hw_server` can enumerate two Digilent targets:
  - `210299BBCF40`
  - `210512180081`
- But `open_hw_target` reports `No devices detected on target ...` for both targets

This means the main blocker is no longer “Vivado cannot see the download cable at all,” but rather “the download cable is visible, yet no device IDCODE is being read on the JTAG chain.”

## Run the Script First

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_jtag_stack.ps1
```

The script outputs:

- [jtag_status.json](/c:/Users/AIALRA-PORTABLE/Desktop/Project%201/data/hardware/jtag_status.json)
- [jtag_status.md](/c:/Users/AIALRA-PORTABLE/Desktop/Project%201/reports/jtag_status.md)

## Recommended Troubleshooting Order

1. Isolate the cables first.
Keep only the 14-pin cable for the 7z020, unplug any other FTDI/Digilent cables, and rerun the script to confirm which serial belongs to the current target board.

2. Reconfirm the physical connection.
Focus on the 14-pin JTAG cable orientation, Pin 1 alignment, whether the baseboard JTAG connector is fully inserted, and whether the core board is firmly seated.

3. Reconfirm boot mode and power.
Make sure the board is powered by `12V`, is stably powered on, and that `BOOT_MODE0/1` are set to JTAG mode.

4. Recheck Hardware Manager.
If the script can already see the target but `device_count=0`, do not start with CH340 troubleshooting and do not assume a Vivado version issue first; prioritize the possibility that the JTAG chain itself is not returning a device response.

5. Consider driver reinstall only at the end.
Only raise driver rebinding to top priority when `hw_server` cannot enumerate the target at all.

## Suggested Board-Bring-Up Order

1. Start with a minimal smoke design or a known-stable `fir_pipe_systolic` bitstream.
2. Confirm that the device can be read and that the bitstream can be downloaded.
3. Then switch to the FIR experiment bitstream.

## Conclusion in the Current Project Context

- The RTL and implementation issues of `L3` are already decoupled from the JTAG chain.
- The current main blockers for the 7z020 flow are:
  - FIR side: `L3` can now fit, but timing is still too poor to reach the hero-throughput target.
  - Board side: `hw_server` can see the download cable, but the JTAG target cannot read the device.
