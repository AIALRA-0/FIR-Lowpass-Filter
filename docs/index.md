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
- `L=3` 当前 non-FFA 版本功能正确，但在 `xc7z020` 上因 `LUT/CARRY4` 超限未能 place

## 导航

- [项目状态](status.md)
- [评分映射](rubric_map.md)
- [文献矩阵](literature/lit_matrix.md)
- [阅读笔记](literature/reading_notes.md)
- [回归报告](../reports/regression_report.md)
- [综合总结](../reports/synth_summary.md)

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
- `P11` 结果矩阵进行中
