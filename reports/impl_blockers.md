# Implementation Closure

## 当前状态

原先这里记录的两个系统级阻塞都已经关闭：

- `vendor FIR IP` 已加入最终对照
- `PS + PL` 系统壳已经完成 bare-metal 端到端验证

## 已确认的现象

- `fir_l3_polyphase`：已完成 ZU4EV `place_design` 与 `route_design`
- `fir_l3_pipe`：已完成 ZU4EV `place_design` 与 `route_design`
- `zu4ev_fir_pipe_systolic_top`：已完成 bitstream、`.xsa` 与板上闭环
- `zu4ev_fir_vendor_top`：已完成 bitstream、`.xsa` 与板上闭环

当前结果如下：

| Top | LUT | DSP | WNS (ns) | Fmax (MHz) | Throughput (MS/s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_pipe_systolic` | `16712` | `132` | `1.156` | `459.348` | `459.348` |
| `fir_l3_polyphase` | `34687` | `175` | `-4.533` | `127.129` | `381.388` |
| `fir_l3_pipe` | `34786` | `175` | `-4.925` | `121.095` | `363.284` |

## 结论

- 当前问题不是“资源完全超限”
- 当前问题也不再是“L3 放不进 7020”
- 当前剩余的改进空间只在性能优化与展示增强，不再是主线验收阻塞
- 在 ZU4EV 上，`L3` 已经有不错吞吐，但仍没有赢下 `performance hero` 或 `efficiency hero`
- 当前系统级收口已经完成，后续优化应以“锦上添花”为定位

## 后续可选增强

- 为 `fir_l3_pipe` 做真正的 DSP48E2 友好 pipeline 深化，把 `L3` 拉近 `fir_pipe_systolic`
- 在系统壳稳定后，把第二个架构接进同一软件 harness，满足“至少两个架构上板”的最终验收
- 如有展示需求，再接入 ILA、DAQ、HDMI7611 或示波器
