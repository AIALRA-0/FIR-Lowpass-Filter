# Implementation Blockers

## 当前阻塞

当前阻塞完整结果矩阵封板的问题，已经不再是 `L=3` 放不进器件；当前真正的阻塞收敛成两件事：

- `vendor FIR IP` 仍未加入 ZU4EV 总表
- `PS + PL` 系统壳虽然已经能导出 `.xsa`，但 bare-metal harness 还没有完成端到端验证

## 已确认的现象

- `fir_l3_polyphase`：已完成 ZU4EV `place_design` 与 `route_design`
- `fir_l3_pipe`：已完成 ZU4EV `place_design` 与 `route_design`
- `zu4ev_fir_pipe_systolic_top`：已完成 bitstream 与 `.xsa` 导出

当前结果如下：

| Top | LUT | DSP | WNS (ns) | Fmax (MHz) | Throughput (MS/s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_pipe_systolic` | `16712` | `132` | `1.156` | `459.348` | `459.348` |
| `fir_l3_polyphase` | `34687` | `175` | `-4.533` | `127.129` | `381.388` |
| `fir_l3_pipe` | `34786` | `175` | `-4.925` | `121.095` | `363.284` |

## 结论

- 当前问题不是“资源完全超限”
- 当前问题也不再是“L3 放不进 7020”
- 当前问题是：在 ZU4EV 上，`L3` 已经有不错吞吐，但仍没有赢下 `performance hero` 或 `efficiency hero`
- 要完成完全体封板，我们现在需要的是系统级收口，而不是继续围绕旧平台做资源挣扎
- 系统壳的真实阻塞已从“Vivado BD 能不能起”下降为“Vitis 软件链和板上 smoke vectors 能不能闭环”

## 下一轮最有效的技术动作

- 为 `fir_l3_pipe` 做真正的 DSP48E2 友好 pipeline 深化，把 `L3` 拉近 `fir_pipe_systolic`
- 引入 `vendor FIR IP` 参考线，补齐最终冠军表
- 用 `vitis/zu4ev_baremetal` 对 `zu4ev_fir_pipe_systolic_top.xsa` 跑最小 smoke vectors，完成第一次 `PS + PL` bring-up
- 在系统壳稳定后，把第二个架构接进同一软件 harness，满足“至少两个架构上板”的最终验收
