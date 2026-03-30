# Vendor vs Custom

## 比较范围

本页分两个口径讨论：

- `kernel scope`：自研 RTL 内核之间的公平比较
- `board-shell scope`：`PS + AXI DMA + FIR shell + bare-metal harness` 的最终上板对照

## Kernel Scope

在纯自研 RTL 内核矩阵中，当前冠军仍然是 `fir_pipe_systolic`：

- `459.348 MHz`
- `459.348 MS/s`
- `132 DSP`
- `3.803 nJ/sample`

这说明对于本项目这类 261 taps、线性相位、严格 bit-true 的 FIR，精心实现的对称折叠 + systolic 流水线仍然是最强的自研工程解。

## Board-Shell Scope

在同一套 ZU4EV 系统壳下，`custom` 和 `vendor` 都已经完成自动烧录与板上验证：

| Top | Arch | Fmax est (MHz) | LUT | FF | DSP | BRAM | Power (W) | Energy/sample est (nJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `board_shell_custom` | `347.826` | `20253` | `21909` | `132` | `3.0` | `2.971` | `8.542` |
| `zu4ev_fir_vendor_top` | `board_shell_vendor_ip` | `347.102` | `8856` | `13428` | `131` | `3.0` | `2.861` | `8.243` |

## 功耗分层

如果只看 whole-system total power，两条设计看起来差距不大：

- `custom total = 2.971 W`
- `vendor total = 2.861 W`

但把 routed power 按 hierarchy 拆开以后，差异就更清楚：

| Top | PS8 (W) | FIR shell (W) | DMA (W) | Interconnect (W) |
| --- | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `2.228` | `0.238` | `0.016` | `0.009` |
| `zu4ev_fir_vendor_top` | `2.228` | `0.132` | `0.014` | `0.008` |

这说明：

- `PS8` 基本是固定背景功耗
- 真正体现 FIR 架构差异的，是 `fir_shell_0`
- 在当前系统壳下，自研 shell 的 FIR 子系统动态功耗明显高于 vendor

## 关键路径观察

两条系统壳都已经不是“FIR MAC 本体最慢”，而是落在 FIR 输出到 FIFO 的系统接口区：

| Top | Data Path (ns) | Logic (ns) | Route (ns) | Logic Levels | WNS (ns) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `zu4ev_fir_pipe_systolic_top` | `2.859` | `1.348` | `1.511` | `13` | `0.458` |
| `zu4ev_fir_vendor_top` | `2.877` | `1.263` | `1.614` | `11` | `0.452` |

两条路径都表现出 routing-dominant 特征，这也是为什么二者系统层频率几乎相同，而不会像 kernel scope 那样拉开更明显差距。

## 结论

- 在 `board-shell scope` 下，`vendor FIR IP` 更省 LUT/FF，功耗和 `energy/sample` 也略优。
- 在 `board-shell scope` 下，自研 `fir_pipe_systolic` 的频率略高，但差距很小。
- 两条架构都通过了相同板上用例，且 `mismatches = 0`，因此这个结论是建立在同一条功能验收链上的。
- 最终项目叙事应保持诚实：
  - `fir_pipe_systolic` 是当前最强的自研研究型架构，也是课程项目里最有价值的自定义实现。
  - `vendor FIR IP` 是更精简、更工业化的现成基线，在系统层面对面积与能效更有优势。

## 为什么这个对照有价值

- 它证明我们不是只会“把 RTL 跑起来”，而是知道工业界现成基线是什么，并能在同一平台、同一位宽、同一向量、同一板测流程下做对照。
- 它也让项目结论更可信：不是所有指标都由自研版本获胜，但自研版本在架构透明度、研究可解释性、DFG/SFG 展示、以及从 MATLAB 到 RTL 到板测的全链闭环上更有展示价值。
