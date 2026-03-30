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
| P09 | `L=3` polyphase / `L=3 + pipeline` | 完成 | 已实现共享 `L3 FFA core`，两个版本均通过 bit-true 回归并成功在 `xc7z020` 上 place/route |
| P10 | 统一验证链 | 完成 | 标量与向量最小回归链已打通，`impulse / step / random_short / lane_alignment` 可一键运行 |
| P11 | Vivado 综合 / 实现 | 进行中 | 五个自研架构的 Vivado 结果已刷新；`L3` 已 fit 但时序远低于 hero 门槛，vendor FIR IP 尚未加入总表 |
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
- `fir_l3_polyphase`：`WNS = -14.224 ns`，`Fmax = 52.018 MHz`，`throughput = 156.055 MS/s`，`36716 LUT`，`175 DSP`
- `fir_l3_pipe`：`WNS = -14.567 ns`，`Fmax = 51.106 MHz`，`throughput = 153.319 MS/s`，`36852 LUT`，`175 DSP`

## 当前结论

- 当前已成功落板的版本里，`fir_pipe_systolic` 同时是 `performance hero` 与 `efficiency hero`
- `fir_l2_polyphase` 证明了真正 polyphase datapath 已进入可综合、可回归状态，但在 `xc7z020` 上并不比高质量标量流水线更划算
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已完成 `FFA` 级压缩并成功 fit 到 `xc7z020`，但当前关键阻塞已从“资源放不下”转为“时序严重不过”
- 当前 `L3` 系列吞吐均低于 `fir_pipe_systolic` 的 `307.031 MS/s`，因此尚未达到预设 hero 门槛
- JTAG 侧当前也已有独立结论：`hw_server` 能枚举 Digilent target，但两条 target 都读不到器件，详见 `docs/bringup_xc7z020_jtag.md`
