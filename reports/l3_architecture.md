# L=3 Architecture

## 架构定义

当前 `fir_l3_polyphase` 已替换原先的参考内核，成为真实 `3-parallel polyphase` datapath。

系数分解为：

- `E0[k] = h[3k]`，长度 `87`
- `E1[k] = h[3k+1]`，长度 `87`
- `E2[k] = h[3k+2]`，长度 `87`

本阶段的对称性利用策略为：

- `E1` 内部仍保持对称折叠，唯一乘法器 `44`
- `E0` 与 `E2` 是跨分支镜像，但本阶段不做跨分支共享，各自按 full branch 实现

输入重排为：

- `x0[m] = x[3m]`
- `x1[m] = x[3m+1]`
- `x2[m] = x[3m+2]`

输出矩阵为：

- `y0[m] = E0*x0 + z^-1(E1*x2 + E2*x1)`
- `y1[m] = E0*x1 + E1*x0 + z^-1(E2*x2)`
- `y2[m] = E0*x2 + E1*x1 + E2*x0`

## 运算量

| 项目 | 数值 |
| --- | ---: |
| taps | 261 |
| samples/cycle | 3 |
| branch lengths | `87 + 87 + 87` |
| unique multipliers per branch family | `87 / 44 / 87` |
| total branch instances | 9 |
| effective branch multipliers in current RTL | `3*87 + 3*44 + 3*87 = 654` |
| delayed matrix terms | `E1*x2`、`E2*x1`、`E2*x2` |
| rounding位置 | 仅在最终 lane 合成后 |
| latency_cycles | 1 |

## 回归状态

- `impulse`：PASS
- `step`：PASS
- `random_short`：PASS
- `lane_alignment_l3`：PASS

## 当前器件结果

目标器件：`xc7z020clg400-2`

综合与 `opt_design` 可以完成，但 `place_design` 前的 DRC 已经报出资源超限：

- `CARRY4` 需求 `26769`，器件仅 `13300`
- `LUT as Logic` 需求 `77369`，器件仅 `53200`

这说明当前版本已经足够证明：

- lane 调度正确
- polyphase 数学正确
- RTL 可综合

但它还不是当前器件上的最终比赛级实现。

## 结论

- 这条线已经从“参考内核”升级成了“真实 polyphase datapath”
- 当前 non-FFA 实现能验证架构与回归链，但不适合直接作为 `xc7z020` 的最终 hero design
- 下一轮真正有价值的优化方向是：
  - `FFA`
  - `E0 / E2` 跨分支共享
  - matrix network 压缩
  - 或迁移到更大器件
