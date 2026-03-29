# Synthesis Summary

当前已完成并汇总到 `data/impl_results.csv` 的架构：

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | symmetry_folded | 52.469 | 2839 | 3569 | 126 | 0.752 | 14.332 |
| `fir_pipe_systolic` | pipelined_systolic | 307.031 | 16710 | 17224 | 132 | 1.213 | 3.951 |
| `fir_l2_polyphase` | l2_polyphase | 52.809 | 13472 | 4396 | 212 | 1.647 | 15.594 |

## 当前结论

- `fir_pipe_systolic` 是当前成功落板版本中的 `performance hero`
  - 最高 `Fmax`
  - 最高 `throughput`
  - 最低 `energy/sample`
- `fir_l2_polyphase` 已证明真正的 `polyphase + symmetry` RTL 能进入综合和实现链，但在 `xc7z020` 上没有打赢高质量标量流水线
- `fir_symm_base` 保留为最重要的面积/可解释性基线

## 当前未成功落板的架构

| Top | 状态 | 直接阻塞 |
| --- | --- | --- |
| `fir_l3_polyphase` | `place_design` 前失败 | `CARRY4 26769 > 13300`，`LUT as Logic 77369 > 53200` |
| `fir_l3_pipe` | `place_design` 前失败 | `CARRY4 26769 > 13300`，`LUT as Logic 77385 > 53200` |

## 分析

- `fir_l2_polyphase` 的吞吐提高到 `105.619 MS/s`，但仍受长组合路径影响，没有达到“并行就更快”的理想状态
- `fir_l3_polyphase` 与 `fir_l3_pipe` 当前采用的是“真实 polyphase、但尚未做 FFA / cross-branch sharing”的保守实现，因此功能正确但资源代价过高
- 现阶段最清楚的技术方向不是继续 brute-force 展开 `L=3`，而是：
  - 引入 `FFA`
  - 做 `E0 / E2` 跨分支共享
  - 或切换到更大器件，例如 `xczu4ev`

## 说明

- 结果来自 `xc7z020clg400-2`，Vivado 2024.1
- 当前功耗仍为 vectorless 估计，后续可替换为基于仿真活动的功耗分析
- 当前 `data/impl_results.csv` 仅收录成功产生实现报告的版本；失败版本的原因记录在对应 `build/vivado/<top>/vivado.log`
