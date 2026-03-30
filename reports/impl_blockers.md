# Implementation Blockers

## 当前阻塞

当前阻塞完整结果矩阵封板的问题，不再是功能正确性，也不再是 `L=3` 放不进 `xc7z020clg400-2`；当前真正的阻塞已经变成 `L=3` 的时序竞争力不足。

## 已确认的现象

- `fir_l3_polyphase`：已完成 `place_design` 与 `route_design`
- `fir_l3_pipe`：已完成 `place_design` 与 `route_design`

当前结果如下：

| Top | LUT | DSP | WNS (ns) | Fmax (MHz) | Throughput (MS/s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_l3_polyphase` | `36716` | `175` | `-14.224` | `52.018` | `156.055` |
| `fir_l3_pipe` | `36852` | `175` | `-14.567` | `51.106` | `153.319` |

## 结论

- 当前问题不是“资源完全超限”
- 当前问题是：虽然 `L3 FFA` 已把实现压进了 `xc7z020`，但关键路径仍然太长，离 `3 * Fmax >= 307.031 MS/s` 的门槛还差很远

## 下一轮最有效的技术动作

- 在 `fir_branch_core_mirror_pair` / `fir_branch_core_full` / `fir_branch_core_symm` 内部分层打 pipeline
- 把当前单拍大加法树改成两级或三级累加网络
- 重新评估 `H01 / H12` 的 DSP/LUT 映射，避免把大乘法树完全留给 LUT 慢路径
- 如果一次内部 pipeline 重构后仍无法达到 `102.344 MHz`，再切换到 `xczu4ev`
