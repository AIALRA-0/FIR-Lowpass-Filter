# JTAG Status

Checked at: 2026-03-29T21:16:24

## Toolchain

- Vivado bin: E:\Xilinx\Vivado\2024.1\bin
- hw_server: E:\Xilinx\Vivado\2024.1\bin\hw_server.bat
- Digilent installer: E:\Xilinx\Vivado\2024.1\data\xicom\cable_drivers\nt64\digilent\install_digilent.exe

## Present USB Devices

- USB Serial Converter | class=USB | provider=FTDI | inf=oem104.inf | service=FTDIBUS | instance=USB\VID_0403&PID_6014\210512180081
- USB Serial Converter | class=USB | provider=FTDI | inf=oem104.inf | service=FTDIBUS | instance=USB\VID_0403&PID_6014\210299BBCF40
- USB-SERIAL CH340 (COM7) | class=Ports | provider=wch.cn | inf=oem187.inf | service=CH341SER_A64 | instance=USB\VID_1A86&PID_7523\5&27EC4662&0&10

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
- target_count: 2

- localhost:3121/xilinx_tcf/Digilent/210299BBCF40 | open_rc=1 | device_count=0 | message=ERROR: [Common 17-39] 'open_hw_target' failed due to earlier errors. 
- localhost:3121/xilinx_tcf/Digilent/210512180081 | open_rc=1 | device_count=0 | message=ERROR: [Common 17-39] 'open_hw_target' failed due to earlier errors. 

## Diagnosis

- hw_server can see Digilent targets, but open_hw_target found no devices. This points to an empty JTAG chain, cable orientation issue, wrong header, bad board seating, wrong boot mode, or board power problem.
- CH340 is UART only and is not part of the JTAG path.
- The FTDI devices are currently bound to the generic FTDI driver. That is not necessarily the main blocker if hw_server already enumerates Digilent targets.

## Next Actions

- Physically isolate the two FTDI cables. Unplug one, rerun this script, and identify which serial belongs to the 7z020 board.
- Verify 14-pin JTAG ribbon orientation and pin-1 alignment on the baseboard header.
- Confirm JTAG boot mode from board docs: BOOT_MODE0=ON and BOOT_MODE1=ON.
- Keep only 12V power and the 14-pin JTAG cable during bring-up. Treat CH340 as unrelated UART.
- If hw_server still sees targets but device_count=0, focus on cable/header/core-board seating and JTAG chain continuity before reinstalling drivers.
- Reinstall drivers only if hw_server stops enumerating the Digilent targets at all.
