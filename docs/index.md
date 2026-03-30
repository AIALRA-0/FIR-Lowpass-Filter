# FIR Lowpass Filter Research Kit

这是本项目的 GitHub Pages 入口页。站点围绕课程评分点与工程展示同时组织。

## 当前最重要的结果

- 最终满足规格的滤波器为 `firpm / order 260 / 261 taps`
- 默认固定点为 `Q1.15 + Wcoef20 + Wout16 + Wacc46`
- 标量与向量 bit-true 回归均已打通
- 当前成功落板的最佳实现是 `fir_pipe_systolic`
  - `307.031 MHz`
  - `132 DSP`
  - `3.951 nJ/sample`
- `L=2 polyphase` 已成为真正 polyphase RTL 并成功实现
- `L=3` 现在已采用共享 `L3 FFA core` 并成功 fit 到 `xc7z020`
- 当前 `L=3` 的主阻塞已变成时序，而不是资源：约 `51-52 MHz`

## 导航

- [项目状态](status.md)
- [评分映射](rubric_map.md)
- [文献矩阵](literature/lit_matrix.md)
- [阅读笔记](literature/reading_notes.md)
- [回归报告](../reports/regression_report.md)
- [综合总结](../reports/synth_summary.md)
- [JTAG Bring-Up](bringup_xc7z020_jtag.md)
- [JTAG 状态报告](../reports/jtag_status.md)

## 章节

1. MATLAB 设计说明
2. 量化与固定点分析
3. 架构设计与 DFG/SFG
4. 验证与回归
5. 硬件实现结果
6. 结论与后续工作

## 当前里程碑

- `P00-P02` 研究与规格基线完成
- `P03-P07` 标量设计、固定点、DFG、流水线完成
- `P08-P10` 真正 polyphase RTL 与统一回归完成
- `P11` 结果矩阵已刷新，当前剩余主任务是 `L3` 时序优化与 vendor FIR IP 对照
