# Synthesis Summary

当前已完成并汇总到 `data/impl_results.csv` 的架构：

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | symmetry_folded | 51.538 | 2785 | 3552 | 126 | 0.755 | 14.649 |
| `fir_pipe_systolic` | pipelined_systolic | 264.410 | 16643 | 17332 | 132 | 1.238 | 4.682 |

说明：

- `fir_symm_base` 未满足当前 `5 ns` 目标约束
- `fir_pipe_systolic` 已满足并显著提高频率
- 结果来自 `xc7z020clg400-2`，Vivado 2024.1
- 目前功耗为 vectorless 估计，后续可替换为基于仿真活动的更高置信度结果

