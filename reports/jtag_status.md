# JTAG Status

Checked at: 2026-03-30T11:38:05

## Active Platform

- board_name: MZU04A-4EV
- target_part: xczu4ev-sfvc784-2-i
- uart_console: COM9
- jtag_boot_switch: ON / ON / ON

## Toolchain

- Vivado bin: E:\Xilinx\Vivado\2024.1\bin
- hw_server: E:\Xilinx\Vivado\2024.1\bin\hw_server.bat
- Digilent installer: E:\Xilinx\Vivado\2024.1\data\xicom\cable_drivers\nt64\digilent\install_digilent.exe

## Present USB Devices

- Silicon Labs CP210x USB to UART Bridge (COM9) | class=Ports | provider=Silicon Laboratories Inc. | inf=oem195.inf | service=silabser | instance=USB\VID_10C4&PID_EA60\0244B448
- USB Serial Converter | class=USB | provider=FTDI | inf=oem104.inf | service=FTDIBUS | instance=USB\VID_0403&PID_6014\210299BBCF40

## Installed Driver Hints

- > Original Name:      digiftdibus.inf
- > Provider Name:      Digilent Inc.
  Class Name:         USB
- > Original Name:      digiftdiport.inf
- > Provider Name:      Digilent Inc.
  Class Name:         Ports
- > Provider Name:      Digilent Inc.
  Class Name:         USB
- > Original Name:      ftdibus.inf
- > Provider Name:      FTDI
  Class Name:         USB
- > Original Name:      ftdibus.inf
- > Provider Name:      FTDI
  Class Name:         USB
- > Original Name:      ftdiport.inf
- > Provider Name:      FTDI
  Class Name:         Ports
- > Original Name:      ftdiport.inf
- > Provider Name:      FTDI
  Class Name:         Ports
- > Original Name:      windrvr6.inf
  Provider Name:      Jungo
- > Provider Name:      Xilinx
  Class Name:         Xilinx Drivers
- > Provider Name:      Xilinx
  Class Name:         Net
- > Original Name:      xpcwinusb.inf
- > Provider Name:      Xilinx, Inc.
  Class Name:         Programming cables

## hw_server Probe

- server_url: localhost:3121
- target_count: 1

- localhost:3121/xilinx_tcf/Digilent/210299BBCF40 | open_rc=0 | device_count=2 | message=

## Enumerated Devices

- localhost:3121/xilinx_tcf/Digilent/210299BBCF40 | part=xczu4 | idcode=00000100011100100001000010010011
- localhost:3121/xilinx_tcf/Digilent/210299BBCF40 | part=arm_dap | idcode=01011011101000000000010001110111

## Diagnosis

- At least one JTAG target returned a device. Driver and chain basics are alive.
- CP210x is UART only and is not part of the JTAG path.
- The FTDI devices are currently bound to the generic FTDI driver. That is not necessarily the main blocker if hw_server already enumerates Digilent targets.
- The active chain is already enumerating xczu4, so the project can move from cable triage to smoke bitstream and PS+PL bring-up.

## Next Actions

- Keep JTAG and UART responsibilities separate: FTDI/Digilent is the download chain, and CH340/CP210x is only the console.
- If xczu4 is already visible, proceed to smoke bitstream, AXI-Lite register readback, and AXI DMA loopback before spending more time on driver reinstalls.
- Keep 12V power applied during bring-up and verify the board remains in the documented JTAG boot switch setting.
- If hw_server ever drops back to target_count=0, revisit cable visibility and driver binding first.
- Use docs/bringup_mzu04a_zu4ev.md as the board-level source of truth for the next stage.
