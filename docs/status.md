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
| P06 | RTL 公共骨架与基线 | 完成 | `fir_symm_base` 已完成 bit-true 标量回归 |
| P07 | 流水线 systolic | 完成 | `fir_pipe_systolic` 已完成 bit-true 标量回归并刷新 Vivado 结果 |
| P08 | `L=2` polyphase | 完成 | 已替换参考内核为真正 `polyphase + symmetry` RTL，并通过向量回归与 Vivado 实现 |
| P09 | `L=3` polyphase / `L=3 + pipeline` | 部分完成 | 两个版本都已替换参考内核并通过 bit-true 回归，但当前 non-FFA 版本在 `xc7z020` 上 place 前资源超限 |
| P10 | 统一验证链 | 完成 | 标量与向量最小回归链已打通，`impulse / step / random_short / lane_alignment` 可一键运行 |
| P11 | Vivado 综合 / 实现 | 进行中 | `base / pipe / L2` 已刷新结果；`L3 / L3_pipe` 当前受器件资源限制，vendor FIR IP 尚未加入总表 |
| P12 | Pages / LaTeX / Overleaf | 进行中 | 文档骨架已建立，正在同步最新结果 |

## 当前默认环境

- MATLAB：`R2024b`
- 主 FPGA：`xc7z020clg400-2`
- 报告语言：中文优先
- Git 流程：直接推送 `main`

## 当前数据快照

- `final_spec` 浮点：`Ap = 0.0304 dB`，`Ast = 83.9902 dB`
- 固定点默认：`Wcoef = 20`，`Wout = 16`，`Wacc = 46`
- `fir_symm_base`：`WNS = -14.059 ns`，`Fmax = 52.469 MHz`
- `fir_pipe_systolic`：`WNS = 1.743 ns`，`Fmax = 307.031 MHz`
- `fir_l2_polyphase`：`WNS = -13.936 ns`，`Fmax = 52.809 MHz`，`throughput = 105.619 MS/s`
- 标量回归：`fir_symm_base` / `fir_pipe_systolic` 已通过 `impulse`、`step`、`random_short`
- 向量回归：`fir_l2_polyphase` / `fir_l3_polyphase` / `fir_l3_pipe` 已通过 `impulse`、`step`、`random_short`、`lane_alignment`
- `fir_l3_polyphase` / `fir_l3_pipe` 当前在 `xc7z020clg400-2` 上 place 前失败：
  - `CARRY4` 需求 `26769`，器件仅 `13300`
  - `LUT as Logic` 需求约 `77k`，器件仅 `53200`

## 当前结论

- 当前已成功落板的版本里，`fir_pipe_systolic` 同时是 `performance hero` 与 `efficiency hero`
- `fir_l2_polyphase` 证明了真正 polyphase datapath 已进入可综合、可回归状态，但在 `xc7z020` 上并不比高质量标量流水线更划算
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已完成功能正确性，但要成为最终比赛级架构，下一步必须引入 `FFA / cross-branch sharing` 或切换到更大器件
