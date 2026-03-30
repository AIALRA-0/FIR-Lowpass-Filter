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
| P09 | `L=3` polyphase / `L=3 + pipeline` | 完成 | 已实现共享 `L3 FFA core`，两个版本均通过 bit-true 回归并完成 ZU4EV post-route |
| P10 | 统一验证链 | 完成 | 标量与向量最小回归链已打通，`impulse / step / random_short / lane_alignment` 可一键运行 |
| P11 | Vivado 综合 / 实现 | 进行中 | ZU4EV 自研五个架构结果已刷新；`zu4ev_fir_pipe_systolic_top` 已导出 `.xsa`；`vendor FIR IP` 仍待纳入总表 |
| P12 | Pages / LaTeX / Overleaf | 进行中 | 文档骨架已建立，当前正在同步 ZU4EV 主线、系统壳与上板流程 |

## 当前默认环境

- MATLAB：`R2024b`
- 主 FPGA：`xczu4ev-sfvc784-2-i`
- 开发板：`MZU04A-4EV`
- UART：`COM9 / CP210x`
- 报告语言：中文优先
- Git 流程：直接推送 `main`

## 当前数据快照

- `final_spec` 浮点：`Ap = 0.0304 dB`，`Ast = 83.9902 dB`
- 固定点默认：`Wcoef = 20`，`Wout = 16`，`Wacc = 46`
- `fir_symm_base`：`WNS = -4.537 ns`，`Fmax = 127.065 MHz`
- `fir_pipe_systolic`：`WNS = 1.156 ns`，`Fmax = 459.348 MHz`
- `fir_l2_polyphase`：`WNS = -3.844 ns`，`Fmax = 139.334 MHz`，`throughput = 278.668 MS/s`
- 标量回归：`fir_symm_base` / `fir_pipe_systolic` 已通过 `impulse`、`step`、`random_short`
- 向量回归：`fir_l2_polyphase` / `fir_l3_polyphase` / `fir_l3_pipe` 已通过 `impulse`、`step`、`random_short`、`lane_alignment`
- `fir_l3_polyphase`：`WNS = -4.533 ns`，`Fmax = 127.129 MHz`，`throughput = 381.388 MS/s`，`34687 LUT`，`175 DSP`
- `fir_l3_pipe`：`WNS = -4.925 ns`，`Fmax = 121.095 MHz`，`throughput = 363.284 MS/s`，`34786 LUT`，`175 DSP`
- 系统壳：`build/zu4ev_system/zu4ev_fir_pipe_systolic_top/zu4ev_fir_pipe_systolic_top.xsa` 已导出

## 当前结论

- 在当前 ZU4EV 自研矩阵中，`fir_pipe_systolic` 同时是 `performance hero` 与 `efficiency hero`
- `fir_l2_polyphase` 证明了真正 polyphase datapath 已进入可综合、可回归、可在大器件上公平比较的状态
- `fir_l3_polyphase` 和 `fir_l3_pipe` 已不再受 7020 面积限制，当前结论变成：`L3` 吞吐很强，但仍未打赢高质量标量流水线
- `L3` 当前主问题不是“能不能放下”，而是“如何把 `DSP48E2` 友好的高性能版本做成真正的第二名候选”
- JTAG 链路已经从“驱动排障”阶段进入“系统 bring-up”阶段，当前能够枚举到 `xczu4` 与 `arm_dap`，详见 `docs/bringup_mzu04a_zu4ev.md`
- 系统级主线已经从“只有 RTL 内核”进入“可导出 Vitis 平台”的阶段，下一步是把 `vitis/zu4ev_baremetal` 与该 `.xsa` 真正联调起来
