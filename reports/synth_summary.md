# Synthesis Summary

当前已完成并汇总到 `data/impl_results.csv` 的架构：

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | symmetry_folded | 52.469 | 2839 | 3569 | 126 | 0.752 | 14.332 |
| `fir_pipe_systolic` | pipelined_systolic | 307.031 | 16710 | 17224 | 132 | 1.213 | 3.951 |
| `fir_l2_polyphase` | l2_polyphase | 52.809 | 13472 | 4396 | 212 | 1.647 | 15.594 |
| `fir_l3_polyphase` | l3_polyphase | 52.018 | 36716 | 8907 | 175 | 3.199 | 20.499 |
| `fir_l3_pipe` | l3_pipeline | 51.106 | 36852 | 9158 | 175 | 3.250 | 21.198 |

## 当前结论

- `fir_pipe_systolic` 是当前成功落板版本中的 `performance hero`
  - 最高 `Fmax`
  - 最高 `throughput`
  - 最低 `energy/sample`
- `fir_l2_polyphase` 已证明真正的 `polyphase + symmetry` RTL 能进入综合和实现链，但在 `xc7z020` 上没有打赢高质量标量流水线
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已从“资源放不下”推进到“可成功 place/route”，说明 `L3 FFA` 压缩方向是有效的
- 但 `L3` 目前仍明显打不过 `fir_pipe_systolic` 的 `307.031 MS/s`，因此还不能成为主 hero design
- `fir_symm_base` 保留为最重要的面积/可解释性基线

## 分析

- `fir_l2_polyphase` 的吞吐提高到 `105.619 MS/s`，但仍受长组合路径影响，没有达到“并行就更快”的理想状态
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已实现共享 `L3 FFA core`，资源压缩足以让两者在 `xc7z020` 上完成 `place_design` 与 `route_design`
- 当前 `L3` 的主阻塞已不是资源，而是关键路径过长：
  - `fir_l3_polyphase`：约 `52.018 MHz`
  - `fir_l3_pipe`：约 `51.106 MHz`
- 这说明当前 pipeline cut 还没有打到真正的临界加法/乘法边界，下一轮优化应优先聚焦：
  - 在 `fir_branch_core_*` 内部打寄存器
  - 把 pair/full branch 的大加法树改成更短的分层累加
  - 明确控制 DSP / LUT 的乘法映射，而不是仅依赖综合器默认决策
  - 如果 7020 仍达不到 `102.344 MHz` 门槛，再启动 `ZU4EV` fallback

## 说明

- 结果来自 `xc7z020clg400-2`，Vivado 2024.1
- 当前功耗仍为 vectorless 估计，后续可替换为基于仿真活动的功耗分析
- 当前 `data/impl_results.csv` 已收录五个自研架构；vendor FIR IP 仍待加入
