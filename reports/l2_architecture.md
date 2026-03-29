# L=2 Architecture

## 架构定义

当前 `fir_l2_polyphase` 已不再是“顺序调用两次标量 FIR”的参考内核，而是一个真正的 `2-parallel polyphase` datapath。

系数分解为：

- `E0[k] = h[2k]`，长度 `131`
- `E1[k] = h[2k+1]`，长度 `130`

其中：

- `E0` 线性相位对称，可折叠为 `66` 个 unique multipliers
- `E1` 线性相位对称，可折叠为 `65` 个 unique multipliers

输入按 block time 重排：

- `x0[m] = x[2m]`
- `x1[m] = x[2m+1]`

输出方程为：

- `y0[m] = E0*x0 + z^-1(E1*x1)`
- `y1[m] = E0*x1 + E1*x0`

RTL 中对应四条子路径：

- `u00 = E0(x0)`
- `u01 = E0(x1)`
- `u10 = E1(x0)`
- `u11 = E1(x1)`

最终组合为：

- `lane0 = u00 + delay_1block(u11)`
- `lane1 = u01 + u10`

## 运算量

| 项目 | 数值 |
| --- | ---: |
| taps | 261 |
| samples/cycle | 2 |
| branch lengths | `131 + 130` |
| branch unique multipliers | `66 + 65` |
| total branch instances | 4 |
| total branch multipliers in RTL | `66 + 66 + 65 + 65 = 262` |
| final lane adders | 2 个 `WACC` 级合成加法 |
| block delay | `u11` 路 1 个 block delay |
| rounding位置 | 仅在最终 lane 合成后 |
| latency_cycles | 1 |

## 回归状态

- `impulse`：PASS
- `step`：PASS
- `random_short`：PASS
- `lane_alignment_l2`：PASS

## Vivado 结果

目标器件：`xc7z020clg400-2`

| 指标 | 数值 |
| --- | ---: |
| WNS | `-13.936 ns` |
| Fmax est | `52.809 MHz` |
| Throughput | `105.619 MS/s` |
| LUT | `13472` |
| FF | `4396` |
| DSP | `212` |
| Power | `1.647 W` |
| Energy/sample est | `15.594 nJ` |

## 结论

- 这条线已经满足“真正 polyphase datapath”的研究要求，不再是占位型参考实现
- 在 `xc7z020` 上，`L=2` 带来了吞吐翻倍，但没有带来更好的时序或能效
- 下一轮若要把 `L=2` 做成更强竞争者，应进一步压缩矩阵加法网络和 branch 内部寄存器切分，而不是回退到简单复制两份 FIR
