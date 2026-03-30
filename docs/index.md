# FIR Lowpass Filter Research Kit

这是本项目的 GitHub Pages 入口页。当前主线平台已经完全切换为 `MZU04A-4EV / XCZU4EV-SFVC784-2I`，站点围绕课程评分点、工程结果和上板验证同步组织。

## 当前最重要的结果

- 最终满足规格的滤波器为 `firpm / order 260 / 261 taps`
- 默认固定点为 `Q1.15 + Wcoef20 + Wout16 + Wacc46`
- 标量与向量 bit-true 回归均已打通
- 当前自研最佳实现是 `fir_pipe_systolic`
  - `459.348 MHz`
  - `459.348 MS/s`
  - `132 DSP`
  - `3.803 nJ/sample`
- `L=2 polyphase` 已成为真正 `polyphase + symmetry` RTL
- `L=3` 已升级为共享 `L3 FFA core` 的真实压缩并行架构，并在 ZU4EV 上达到 `381.388 MS/s`
- `PS + PL` 系统壳已经能导出 bitstream 与 `.xsa`
- `fir_pipe_systolic` 与 `vendor FIR IP` 都已完成自动烧录、自动串口抓取与板上闭环
- `vendor FIR IP` 已成为正式工业基线，当前系统壳下更省 LUT/FF 与功耗
- 最新正式板测套件已经扩展到 `8` 个用例，包含 `passband_edge_sine` 与 `transition_sine`
- `fir_pipe_systolic` 与 `vendor FIR IP` 都已完成最近 `3` 次正式窗口重复运行，全部 `8/8` case 通过

## 导航

- [项目状态](status.md)
- [评分映射](rubric_map.md)
- [文献矩阵](literature/lit_matrix.md)
- [阅读笔记](literature/reading_notes.md)
- [综合总结](../reports/synth_summary.md)
- [方法口径](../reports/methodology_summary.md)
- [时序/功耗分析](../reports/timing_power_analysis.md)
- [回归报告](../reports/regression_report.md)
- [ZU4EV Bring-Up](bringup_mzu04a_zu4ev.md)
- [系统壳状态](../reports/system_shell_status.md)
- [JTAG 状态报告](../reports/jtag_status.md)
- [板测报告](../reports/board_validation.md)
- [板测稳定性](../reports/board_stability.md)
- [Vendor 对照](../reports/vendor_vs_custom.md)

## 章节

1. MATLAB 设计说明
2. 量化与固定点分析
3. 架构设计与 DFG/SFG
4. 验证与回归
5. ZU4EV 硬件实现结果
6. 上板与系统验证
7. 结论与后续工作

## 当前里程碑

- `P00-P05` 研究、规格、滤波器设计、固定点和 DFG 已完成
- `P06-P10` 标量、流水线、L=2、L=3 RTL 与统一 bit-true 回归已完成
- `P11` ZU4EV 实现矩阵与 board-shell 结果都已刷新，`vendor FIR IP` 已加入最终对照
- `P12` Pages / README / LaTeX 已同步当前 ZU4EV 主线、板测结果与 vendor 基线
