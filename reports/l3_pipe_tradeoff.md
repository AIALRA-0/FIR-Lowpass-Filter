# L=3 + Pipeline Tradeoff

## 目标

`fir_l3_pipe` 不再是简单的“外面包一级寄存器”，而是在 `fir_l3_polyphase` 数学完全不变的前提下，对三处关键位置插入流水线：

- 输入 lane capture
- subfilter outputs 到矩阵加法之间
- 最终矩阵加法到 `round_sat` 之间

## 当前实现

当前版本与 `fir_l3_polyphase` 的关系是：

- 数值路径相同
- 向量回归结果完全一致
- 仅 latency 增加

固定差异：

| 指标 | `fir_l3_polyphase` | `fir_l3_pipe` |
| --- | ---: | ---: |
| samples/cycle | 3 | 3 |
| latency_cycles | 1 | 3 |
| numerical result | bit-exact | bit-exact |

## 回归状态

- `impulse`：PASS
- `step`：PASS
- `random_short`：PASS
- `lane_alignment_l3`：PASS

## 当前器件结果

在 `xc7z020clg400-2` 上，`fir_l3_pipe` 与 `fir_l3_polyphase` 一样在 `place_design` 前被资源检查挡住：

- `CARRY4` 需求 `26769`，器件仅 `13300`
- `LUT as Logic` 需求 `77385`，器件仅 `53200`

这说明目前的 pipeline 插入还不足以改变“当前 non-FFA L3 数学展开过大”的本质问题。

## 结论

- `fir_l3_pipe` 已完成“真实 pipeline 版本”的功能闭环
- 但在当前器件上，主矛盾不是关键路径，而是数学展开导致的总体逻辑体积
- 因此下一轮若继续优化 `L=3`，优先级应是压缩运算图，而不是继续堆寄存器
