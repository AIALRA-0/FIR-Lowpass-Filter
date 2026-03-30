# 7z020 JTAG Bring-Up

本页把 `xc7z020clg400-2` 开发板的 JTAG 上板链路和当前主机检测结果整理成可复跑的流程。

## 板卡事实

- `CH340 / COM7` 是 `USB-UART`，不承担 JTAG。
- JTAG 走底板独立 `14-pin` 接口；资料说明该口与核心板 `6-pin JTAG` 硬连通。
- 当前工程默认目标板为 `xc7z020clg400-2`。
- JTAG 启动模式按板卡资料固定为：
  - `BOOT_MODE0 = ON`
  - `BOOT_MODE1 = ON`

## 当前机器侧结论

- Windows 能看到：
  - `USB-SERIAL CH340 (COM7)`
  - 两个 `VID_0403&PID_6014` FTDI 设备
- `pnputil` 显示 Digilent 与 Xilinx cable driver 均已安装。
- 当前 `hw_server` 能枚举到两个 Digilent target：
  - `210299BBCF40`
  - `210512180081`
- 但 `open_hw_target` 对两条 target 都报 `No devices detected on target ...`

这意味着当前的主阻塞已经不是“Vivado 完全看不到下载线”，而是“下载线可见，但 JTAG 链上没有读到器件 IDCODE”。

## 先跑脚本

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_jtag_stack.ps1
```

脚本会输出：

- [jtag_status.json](/c:/Users/AIALRA-PORTABLE/Desktop/Project%201/data/hardware/jtag_status.json)
- [jtag_status.md](/c:/Users/AIALRA-PORTABLE/Desktop/Project%201/reports/jtag_status.md)

## 推荐排障顺序

1. 先隔离线缆。
只保留 7z020 的 14-pin 下载线，拔掉其他 FTDI/Digilent 线，再重跑脚本，确认哪一个 serial 才是当前目标板。

2. 再确认物理连接。
重点检查 14-pin JTAG 线方向、Pin 1 对位、底板 JTAG 口是否插实、核心板是否坐稳。

3. 再确认启动模式和供电。
确保板子已接 `12V`、上电稳定，且 `BOOT_MODE0/1` 为 JTAG 模式。

4. 再验证 Hardware Manager。
如果脚本已经能看到 target，但 `device_count=0`，不要先折腾 CH340，也不要先假设是 Vivado 版本问题；优先把问题当成 JTAG 链本身没有器件响应。

5. 最后才考虑驱动重装。
只有当 `hw_server` 连 target 都枚举不到时，才把驱动绑定重新提到最高优先级。

## 建议的上板顺序

1. 先用极简 smoke design 或已经稳定的 `fir_pipe_systolic` bitstream。
2. 确认能读到器件、能下载 bitstream。
3. 再切换到 FIR 实验 bitstream。

## 当前项目语境下的结论

- `L3` 的 RTL 与实现问题已经和 JTAG 链路解耦。
- 当前 7z020 的工程主阻塞是：
  - FIR 侧：`L3` 已能 fit，但时序太差，尚未达到 hero 吞吐门槛。
  - 上板侧：`hw_server` 能看到下载线，但 JTAG target 读不到器件。
