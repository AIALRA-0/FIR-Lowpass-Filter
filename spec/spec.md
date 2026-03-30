# 项目规格冻结

## 课程规格

- 目标：低通 FIR 滤波器设计与实现
- 通带边界：`0.2π rad/sample`
- 阻带起始：`0.23π rad/sample`
- 最低阻带衰减：`80 dB`

## MATLAB 归一化约定

本项目统一采用 MathWorks `firpm` / `firls` / `fir1` 的归一化频率规则：

- `1.0` 对应 Nyquist 频率
- 因此课程中的 `0.2π`、`0.23π` 在 MATLAB 中写为 `0.2`、`0.23`

## 设计对象

1. `baseline_taps100`
   - 固定 `100 taps`
   - 主要用于处理题目中 “100 taps” 的自然理解
2. `baseline_order100`
   - 固定 `order = 100`
   - 即 `101 coefficients`
   - 用于处理 MATLAB 语义中的 “100 阶”
3. `final_spec`
   - 允许增加阶数
   - 目标为真正满足 `Ast >= 80 dB`

## 胜出标准

- `performance hero`
  - 优先按吞吐量与频率表现评定
- `efficiency hero`
  - 优先按 `throughput-per-DSP` 与 `energy-per-sample` 评定

## 固定点默认值

- 输入格式：`Q1.15`
- 输出量化：`round-to-nearest + saturation`
- 只有最终输出允许截断/饱和
- 中间乘法与累加采用 full precision 建模

## 不进入主线验收的内容

- `xc7z020clg400-2` 的主线结果
- transpose 主设计
- TDM 变体
- 英文完整版报告

## 当前主平台

- 开发板：`MZU04A-4EV`
- 主芯片：`XCZU4EV-SFVC784-2I`
- PS 串口：`UART0`，`MIO34/35`
- 主控制台：`COM9 / CP210x`
- JTAG 启动模式：`开关 1-ON 2-ON 3-ON`

## ZU4EV 实现默认值

- 默认 post-route 目标周期：`3.333 ns`
- 激进 sweep 目标周期：`2.500 ns`
- 主线系统形态：`PS + PL + AXI DMA + AXI-Stream FIR shell + AXI-Lite control`
- PS 软件栈：`Bare-metal Vitis`
