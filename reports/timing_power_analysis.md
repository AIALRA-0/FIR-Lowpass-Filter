# Timing And Power Analysis

本页把当前最有信息密度的实现分析集中起来：功耗分层、关键路径分解、以及路由状态。它们全部来自 routed report，而不是手工估计。

## 功耗方法说明

- 当前功耗数据来自 Vivado routed `report_power`
- 当前模式是 vectorless，`Confidence Level = Medium`
- 因此这些数字最适合做**相对比较**，不适合作为绝对 sign-off 功耗
- 对本项目来说，最重要的不是“总功耗到底是不是精确到毫瓦”，而是：
  - `custom` 与 `vendor` 的相对排序
  - `PS8` 与 `FIR shell` 的分层占比
  - 为什么我们必须区分 `kernel scope` 和 `board-shell scope`

## Board-Shell 功耗分层

| Top | Total (W) | Dynamic (W) | Static (W) | PS8 (W) | FIR shell (W) | DMA (W) | Interconnect (W) | Control (W) | Confidence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `zu4ev_fir_pipe_systolic_top` | `2.971` | `2.516` | `0.455` | `2.228` | `0.238` | `0.016` | `0.009` | `0.022` | `Medium` |
| `zu4ev_fir_vendor_top` | `2.861` | `2.408` | `0.454` | `2.228` | `0.132` | `0.014` | `0.008` | `0.022` | `Medium` |

## 功耗结论

- whole-system 总功耗差异不大，`custom` 比 `vendor` 高约 `0.110 W`
- 这个差异里，`PS8` 基本固定在 `2.228 W`，说明**系统总功耗主要由 PS 主导**
- 真正能体现 FIR 结构差异的，是 `fir_shell_0`
  - `custom`: `0.238 W`
  - `vendor`: `0.132 W`
- 也就是说，在当前 ZU4EV 系统壳下，自研 shell 的 FIR 子系统动态功耗约比 vendor 高 `0.106 W`
- 这正是我们坚持 `kernel scope + board-shell scope` 双口径的原因：
  - 如果只看 whole-system total power，PS8 会把 FIR 内核差异淹没
  - 如果只看 kernel scope，又看不到最终系统集成的真实代价

## 关键路径分解

| Top | Source | Destination | Data Path (ns) | Logic (ns) | Route (ns) | Logic Levels | WNS (ns) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `acc_pipe_reg[130][45]` | `u_output_fifo` BRAM DIN | `2.859` | `1.348` | `1.511` | `13` | `0.458` |
| `zu4ev_fir_vendor_top` | `m_axis_data_tdata_int_reg[7]` | `u_output_fifo` BRAM DIN | `2.877` | `1.263` | `1.614` | `11` | `0.452` |

## 关键路径结论

- 当前系统层最坏路径已经不是“FIR 乘加本身”
- `custom` 的最坏路径从 `acc_pipe_reg` 出发，经过 `u_round_sat` 再写到输出 FIFO BRAM
- `vendor` 的最坏路径也落在 FIR 输出到 FIFO 的系统接口区，而不是 PS 侧控制路径
- 两条路径都呈现明显的 routing-dominant 特征：
  - `custom`：route 占 `52.851%`
  - `vendor`：route 占 `56.100%`
- 这说明在当前 shell 下，性能瓶颈已经推进到：
  - rounding/saturation
  - FIFO 写入口
  - 局部互连与布局

## 路由状态

| Top | Logical Nets | Routable Nets | Fully Routed Nets | Routing Errors | Fully Routed (%) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `159196` | `29571` | `29571` | `0` | `100.0` |
| `zu4ev_fir_vendor_top` | `130345` | `22955` | `22955` | `0` | `100.0` |

## 路由解释

- 两条系统壳都已经完整布通，没有 routing error
- `custom` 的逻辑网和可布线网都明显多于 `vendor`
- 这和最终资源结果一致：
  - `custom` 保留了自研 shell、可解释的 rounding/saturation 与控制路径
  - `vendor` 在 FIR 核本体上更紧凑，因此系统壳里的路由压力也更低

## 归一化效率补充

| Top | Throughput (MS/s) | Throughput/DSP | Throughput/kLUT | Throughput/W | Energy/sample (nJ) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fir_pipe_systolic` | `459.348` | `3.480` | `27.486` | `262.935` | `3.803` |
| `fir_l2_polyphase` | `278.668` | `1.064` | `47.489` | `209.840` | `4.766` |
| `fir_l3_polyphase` | `381.388` | `2.179` | `10.995` | `109.468` | `9.135` |
| `fir_l3_pipe` | `363.284` | `2.076` | `10.443` | `102.478` | `9.758` |
| `zu4ev_fir_pipe_systolic_top` | `347.826` | `2.635` | `17.174` | `117.074` | `8.542` |
| `zu4ev_fir_vendor_top` | `347.102` | `2.650` | `39.194` | `121.322` | `8.243` |

## 总结

- 在自研 kernel scope 下，`fir_pipe_systolic` 仍然是最强解：
  - 最高吞吐
  - 最低 `energy/sample`
  - 最好的 `throughput/DSP`
- 在 board-shell scope 下，`vendor FIR IP` 的最终系统更省：
  - 更低 LUT/FF
  - 更低 `FIR shell` 动态功耗
  - 略低 `energy/sample`
- 最重要的分析结论不是“谁绝对更强”，而是：
  - **自研 hero 赢在研究型 RTL 质量和架构透明度**
  - **vendor 基线赢在系统层资源紧凑度与集成成熟度**
