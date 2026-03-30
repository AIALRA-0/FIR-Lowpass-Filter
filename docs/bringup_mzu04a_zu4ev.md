# MZU04A-4EV Bring-Up

本页记录当前主线平台 `MZU04A-4EV / XCZU4EV-SFVC784-2I` 的上板与联机约定，目标是把 JTAG、UART、PS+PL bitstream 与 bare-metal harness 固定成一条可复跑流程。

## 板卡事实

- 开发板：`MZU04A-4EV`
- 主器件：`XCZU4EV-SFVC784-2I`
- JTAG：Vivado Hardware Manager 已能枚举 `xczu4` 与 `arm_dap`
- UART：`COM9 / Silicon Labs CP210x`
- 供电：`12V`
- 主线软件栈：`Bare-metal Vitis`

## 默认接线

- `12V` 外部供电接入开发板
- JTAG 下载线接开发板 JTAG 口
- UART 调试口接主机后，设备管理器应出现 `CP210x` 串口，当前为 `COM9`
- 不把 UART 当成下载链路；下载与调试主链路始终是 JTAG

## 默认启动条件

按本地硬件手册，JTAG bring-up 默认采用：

- `BOOT_MODE[2:0] = ON / ON / ON`
- 上电后先确认板载电源与时钟状态正常，再打开 Vivado Hardware Manager

## 预期枚举结果

运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_jtag_stack.ps1
```

当前预期结果是：

- `Present USB Devices` 同时出现 `FTDI` JTAG 线和 `CP210x` UART
- `hw_server` 能枚举到至少一个 target
- `Enumerated Devices` 里出现：
  - `part=xczu4`
  - `part=arm_dap`

这说明当前链路已经从“驱动排障”阶段进入“系统 bring-up”阶段。

## Bring-Up 顺序

1. 用 `scripts/check_jtag_stack.ps1` 确认 `xczu4` 与 `arm_dap` 可见。
2. 先下载 smoke bitstream，验证：
   - PS UART 正常输出
   - PL 时钟与复位正常
   - AXI-Lite 寄存器可访问
3. 再下载 FIR 系统 bitstream，验证：
   - AXI DMA 正常搬运
   - `fir_stream_shell` 能完成 scalar stream 到 block stream 的打包和还原
   - Bare-metal harness 能打印用例摘要、周期计数、错误计数
4. 最后再跑长用例：
   - `multitone`
   - `stopband sine`
   - `large random buffer`

## 主线系统结构

- PS：`Zynq UltraScale+ MPSoC`
- 数据搬运：`AXI DMA`
- 控制：`AXI-Lite`
- FIR 核：`fir_symm_base` / `fir_pipe_systolic` / `fir_l2_polyphase` / `fir_l3_polyphase` / `fir_l3_pipe`
- 系统壳：`rtl/system/fir_stream_shell.v` 与 `rtl/system/fir_zu4ev_shell.v`
- 软件：`vitis/zu4ev_baremetal`

## 当前已知状态

- RTL 内核级 bit-true 回归已通过
- ZU4EV 上的五个自研架构均已有 post-route 数据
- `fir_pipe_systolic` 与 `vendor FIR IP` 均已完成自动烧录、自动串口抓取与板上验证
- 当前板上正式通过的用例为：
  - `impulse`
  - `step`
  - `random_short`
  - `multitone`
  - `stopband_sine`
  - `large_random_buffer`
- 当前板测结果均满足：
  - `mismatches = 0`
  - `failures = 0`

## 自动化入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch fir_pipe_systolic -ForceHardwareBuild -ForceAppBuild -MaxAttempts 1
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch vendor_fir_ip -ForceHardwareBuild -ForceAppBuild -MaxAttempts 1
```

## 常见问题定位

- 看得到 `CP210x`，但看不到 `xczu4`
  - 先查 JTAG 线与电源，不要把 UART 当成下载线索
- 看得到 `xczu4`，但软件没有串口输出
  - 先确认 `COM9` 没被串口工具占用，再检查 PS UART0 配置和 MIO 分配
- bitstream 能下，但 DMA 不通
  - 先用最小 loopback 和短向量确认 `AXI DMA`、DDR buffer 与 cache flush/invalidate 逻辑

## 非主线扩展

以下设备当前不进入主线验收：

- `MLK FEP DAQ001` 8 通道采集卡
- `HDMI7611` 图像采集卡
- 外部示波器

这些只在主线系统完全闭环后，作为展示增强项再决定是否接入。
