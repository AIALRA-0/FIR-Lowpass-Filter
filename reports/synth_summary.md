# Synthesis Summary

当前实现结果分成两个明确口径：

- `kernel scope`：五个自研 RTL 内核的公平比较
- `board-shell scope`：最终 `PS + AXI DMA + FIR shell + bare-metal harness` 系统对照

这种分层是必要的，因为如果把两类数字混在一起，PS8 和 DMA 的固定开销会掩盖 FIR 核本体差异。

## Kernel Scope

| Top | Arch | Fmax est (MHz) | Throughput (MS/s) | LUT | FF | DSP | Power (W) | Energy/sample (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `fir_symm_base` | `symmetry_folded` | `127.065` | `127.065` | `2810` | `3569` | `126` | `0.880` | `6.926` |
| `fir_pipe_systolic` | `pipelined_systolic` | `459.348` | `459.348` | `16712` | `17224` | `132` | `1.747` | `3.803` |
| `fir_l2_polyphase` | `l2_polyphase` | `139.334` | `278.668` | `5868` | `2439` | `262` | `1.328` | `4.766` |
| `fir_l3_polyphase` | `l3_polyphase` | `127.129` | `381.388` | `34687` | `6914` | `175` | `3.484` | `9.135` |
| `fir_l3_pipe` | `l3_pipeline` | `121.095` | `363.284` | `34786` | `7199` | `175` | `3.545` | `9.758` |

## Kernel Scope 归一化效率

| Top | Throughput/DSP | Throughput/kLUT | Throughput/W | 备注 |
| --- | ---: | ---: | ---: | --- |
| `fir_symm_base` | `1.008` | `45.219` | `144.392` | 面积极小，但频率和能效都被流水线版超越 |
| `fir_pipe_systolic` | `3.480` | `27.486` | `262.935` | 当前自研 `performance hero` 与 `efficiency hero` |
| `fir_l2_polyphase` | `1.064` | `47.489` | `209.840` | LUT 利用效率很强，但 DSP 代价偏大 |
| `fir_l3_polyphase` | `2.179` | `10.995` | `109.468` | 吞吐高，但 LUT 与功耗代价明显 |
| `fir_l3_pipe` | `2.076` | `10.443` | `102.478` | 深流水线没有换来能效优势 |

## Board-Shell Scope

| Top | Arch | Fmax est (MHz) | Throughput (MS/s) | LUT | FF | DSP | BRAM | Power (W) | Energy/sample (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `board_shell_custom` | `347.826` | `347.826` | `20253` | `21909` | `132` | `3.0` | `2.971` | `8.542` |
| `zu4ev_fir_vendor_top` | `board_shell_vendor_ip` | `347.102` | `347.102` | `8856` | `13428` | `131` | `3.0` | `2.861` | `8.243` |

## Board-Shell Scope 归一化效率

| Top | Throughput/DSP | Throughput/kLUT | Throughput/W | 备注 |
| --- | ---: | ---: | ---: | --- |
| `zu4ev_fir_pipe_systolic_top` | `2.635` | `17.174` | `117.074` | 自研 shell 保持了与 vendor 几乎相同的系统频率 |
| `zu4ev_fir_vendor_top` | `2.650` | `39.194` | `121.322` | 当前系统层资源与能效基线赢家 |

## 当前结论

- `fir_pipe_systolic` 是当前自研 RTL 矩阵中的 `performance hero`
  - 最高 `Fmax`
  - 最高 `throughput`
  - 最低 `energy/sample`
  - 最好的 `throughput/DSP`
- `fir_l2_polyphase` 已证明真正的 `polyphase + symmetry` RTL 能进入完整实现链
  - 但当前更像高吞吐 / 高 DSP 消耗的中间解
- `fir_l3_polyphase` 与 `fir_l3_pipe` 已经从“能不能放下”进化到“值不值得”
  - 它们的吞吐已经具备展示价值
  - 但当前还没有赢过高质量标量流水线
- `vendor FIR IP` 是当前 `board-shell scope` 下的工业基线赢家
  - 与自研系统壳几乎相同的频率
  - 更低的 LUT / FF
  - 略低的 `power` 与 `energy/sample`

## 时序与功耗说明

- 当前目标器件：`xczu4ev-sfvc784-2-i`
- kernel scope 默认目标周期：`3.333 ns`
- board-shell 当前 PL 时钟：`3.750 ns`
- 当前功耗来自 routed vectorless `report_power`
- `Confidence Level = Medium`

因此，当前功耗数字应理解为：

- **非常适合做相对比较**
- **不应被当作最终 sign-off 绝对功耗**

更详细的关键路径、功耗分层和路由解释见：

- `reports/timing_power_analysis.md`
- `data/analysis/power_breakdown.csv`
- `data/analysis/critical_path_breakdown.csv`
- `data/analysis/route_status.csv`
