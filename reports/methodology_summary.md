# Methodology Summary

本页把当前项目最容易分散在脚本和日志里的“比较口径”集中起来，避免后续报告只剩结论而没有方法说明。

## 设计与量化口径

- 规格真源：`spec/spec.json`
- 滤波器类型：低通、线性相位 FIR
- 频率边界：`wp = 0.2`、`ws = 0.23`
- 阻带指标：`Ast >= 80 dB`
- 题目歧义处理：同时保留 `baseline_taps100` 与 `baseline_order100`
- 主设计方法：`firpm`
- 最终浮点设计：`order = 260`、`261 taps`
- 默认固定点：`Q1.15 + Wcoef20 + Wout16 + Wacc46`
- 内部策略：full precision accumulate，末级统一 `round + saturate`

## RTL 回归口径

| Scope | 入口脚本 | DUT | 用例 |
| --- | --- | --- | --- |
| 标量 bit-true | `scripts/run_scalar_regression.ps1` | `fir_symm_base`、`fir_pipe_systolic` | `impulse`、`step`、`random_short` |
| 向量 bit-true | `scripts/run_vector_regression.ps1` | `fir_l2_polyphase`、`fir_l3_polyphase`、`fir_l3_pipe` | `impulse`、`step`、`random_short`、`lane_alignment`、`passband_edge`、`transition`、`stopband`、`multitone`、`overflow_corner` |
| 黄金向量生成 | `matlab/vectors/gen_vectors.m` 或 `scripts/regenerate_vectors.py` | 全部 RTL/board 用例共享 | 标量、`L=2`、`L=3` 全部从同一套 fixed-point 系数导出 |

## 综合与实现口径

| 项目 | 设置 |
| --- | --- |
| 工具 | `Vivado 2024.1` |
| 主器件 | `xczu4ev-sfvc784-2-i` |
| kernel scope 目标周期 | `3.333 ns` |
| board-shell scope 当前时钟 | `3.750 ns` |
| 结果真源 | `data/impl_results.csv` |
| 功耗口径 | routed `report_power`，当前为 vectorless |
| 功耗可信度 | `Medium` |
| 比较方式 | 分开报告 `kernel scope` 与 `board-shell scope` |

## 板级自动化闭环口径

| 阶段 | 工具/脚本 | 作用 |
| --- | --- | --- |
| Preflight | `scripts/check_jtag_stack.ps1` | 确认 `xczu4`、`arm_dap`、`COM9 / CP210x` |
| App build | `scripts/build_zu4ev_app.ps1` | 导出 `.xsa`、生成 bare-metal app、保存 `build_info.json` |
| Programming | `scripts/program_zu4ev.ps1` + XSCT/JTAG | 自动下载 bitstream + ELF |
| UART capture | `scripts/capture_uart.py` | 自动抓取 case 日志并判定 `PASS/FAIL` |
| Closure | `scripts/run_zu4ev_closure.ps1` | 串联 preflight、build、program、capture、collect |

## 当前正式板测套件

| Case | 长度 | 目的 |
| --- | ---: | --- |
| `impulse` | `1024` | 核对冲激响应与系数序列 |
| `step` | `1024` | 检查 DC 收敛与稳态 |
| `random_short` | `1024` | 低成本随机 bit-true smoke |
| `passband_edge_sine` | `1024` | 检查通带边缘幅度保持 |
| `transition_sine` | `1024` | 检查过渡带抑制趋势 |
| `multitone` | `2048` | 检查多音叠加下的整体行为 |
| `stopband_sine` | `1024` | 检查阻带抑制 |
| `large_random_buffer` | `2048` | 长 buffer 下 DMA + FIR 稳定性 |

## 当前正式比较口径

- `kernel scope`：只比较 FIR RTL 内核本体，不掺入 PS/DMA/UART 开销。
- `board-shell scope`：比较 `PS + AXI DMA + FIR shell + bare-metal harness` 的最终系统。
- 板上正式收尾对象固定为两条：
  - `fir_pipe_systolic`
  - `vendor_fir_ip`
- `L=2 / L=3` 仍然保留在实现矩阵与分析章节中，但当前不上板作为最终收尾主角。
