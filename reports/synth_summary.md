# Synthesis Summary

当前已完成并汇总到 `data/impl_results.csv` 的架构：

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | symmetry_folded | 127.065 | 2810 | 3569 | 126 | 0.880 | 6.926 |
| `fir_pipe_systolic` | pipelined_systolic | 459.348 | 16712 | 17224 | 132 | 1.747 | 3.803 |
| `fir_l2_polyphase` | l2_polyphase | 139.334 | 5868 | 2439 | 262 | 1.328 | 4.766 |
| `fir_l3_polyphase` | l3_polyphase | 127.129 | 34687 | 6914 | 175 | 3.484 | 9.135 |
| `fir_l3_pipe` | l3_pipeline | 121.095 | 34786 | 7199 | 175 | 3.545 | 9.758 |

## 当前结论

- `fir_pipe_systolic` 是当前成功落板版本中的 `performance hero`
  - 最高 `Fmax`
  - 最高 `throughput`
  - 最低 `energy/sample`
- `fir_l2_polyphase` 已证明真正的 `polyphase + symmetry` RTL 能在 ZU4EV 上进入公平实现链，但当前更像高吞吐 / 高 DSP 消耗的中间解
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已经不再被面积卡死，说明 `L3 FFA` 压缩路线对大器件是可落地的
- 但 `L3` 目前仍打不过 `fir_pipe_systolic` 的 `459.348 MS/s`，也没有赢下能效，因此还不能成为主 hero design
- `fir_symm_base` 保留为最重要的面积/可解释性基线

## 分析

- 当前目标器件已切到 `xczu4ev-sfvc784-2-i`，约束周期是 `3.333 ns`
- `fir_pipe_systolic` 是目前唯一真正闭合该目标周期的自研架构，`WNS = +1.156 ns`
- `fir_l2_polyphase` 的吞吐达到 `278.668 MS/s`，说明 `2 samples/cycle` 路线在 ZU4EV 上已经具备竞争力，但 DSP 代价偏大
- `fir_l3_polyphase` 与 `fir_l3_pipe` 都达到 `> 360 MS/s` 的吞吐级别，说明 `L=3` 方向已经具备展示价值
- 当前 `L3` 的主阻塞已从“放不下”进一步收敛为“时序和能效还不如 `fir_pipe_systolic`”
- 下一轮优化应优先聚焦：
  - 在 `fir_branch_core_*` 内部继续增加 DSP48E2 友好的分层 pipeline
  - 控制 `L3` 的 LUT 参与度，减少大加法树对 Fmax 的拖累
  - 补齐 `vendor FIR IP` 基线和 ZU4EV `PS + PL` 系统壳结果，完成最终横向比较

## 说明

- 结果来自 `xczu4ev-sfvc784-2-i`，Vivado 2024.1
- 当前功耗仍为 vectorless 估计，后续可替换为基于仿真活动的功耗分析
- 当前 `data/impl_results.csv` 已收录五个自研架构；vendor FIR IP 仍待加入
