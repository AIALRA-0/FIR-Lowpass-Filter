# 项目状态

## 里程碑

| 阶段 | 名称 | 状态 | 备注 |
| --- | --- | --- | --- |
| P00 | 仓库引导与治理 | 完成 | 目录、规范、文档入口、LaTeX 主文档已建立 |
| P01 | 规格冻结、评分映射、研究问题定义 | 完成 | `spec/spec.json` 成为单一真源 |
| P02 | 文献与官方资料矩阵 | 完成 | 已建立矩阵与阅读笔记骨架 |
| P03 | 浮点设计空间扫描 | 完成 | `final_spec` 已选定为 `firpm / order 260 / 261 taps` |
| P04 | 固定点模型与量化定案 | 完成 | 默认位宽已选定为 `Q1.15 + Wcoef20 + Wout16 + Wacc46` |
| P05 | DFG/SFG 生成器 | 完成 | Mermaid / SVG / `architecture_math.md` 已生成 |
| P06 | RTL 公共骨架与基线 | 完成 | 基线与 systolic RTL 已通过 `xvlog` 语法检查 |
| P07-P11 | 向量架构 / 验证 / Vivado | 进行中 | Baseline 与 pipe 已完成 Vivado；L2/L3 等待进一步实现结果 |
| P12 | Pages / LaTeX / Overleaf | 进行中 | 文档骨架已建立 |

## 当前默认环境

- MATLAB：`R2024b`
- 主 FPGA：`xc7z020clg400-2`
- 报告语言：中文优先
- Git 流程：直接推送 `main`

## 当前数据快照

- `final_spec` 浮点：`Ap = 0.0304 dB`，`Ast = 83.9902 dB`
- 固定点默认：`Wcoef = 20`，`Wout = 16`，`Wacc = 46`
- `fir_symm_base`：`WNS = -14.403 ns`
- `fir_pipe_systolic`：`WNS = 1.218 ns`
