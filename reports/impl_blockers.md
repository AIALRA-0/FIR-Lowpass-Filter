# Implementation Blockers

## 当前阻塞

当前唯一阻塞完整结果矩阵封板的问题，不是功能正确性，而是 `L=3` 系列在 `xc7z020clg400-2` 上的资源体积过大。

## 已确认的现象

- `fir_l3_polyphase`：`opt_design` 通过，`place_design` 前 DRC 失败
- `fir_l3_pipe`：`opt_design` 通过，`place_design` 前 DRC 失败

失败原因如下：

| Top | CARRY4 | LUT as Logic |
| --- | ---: | ---: |
| `fir_l3_polyphase` | `26769 / 13300` | `77369 / 53200` |
| `fir_l3_pipe` | `26769 / 13300` | `77385 / 53200` |

## 结论

- 当前问题不是“代码写错”或“流水线还不够深”
- 当前问题是：在未做 `FFA / cross-branch sharing` 的情况下，`L=3` 的真实 polyphase 展开对 `xc7z020` 来说逻辑体积过大

## 下一轮最有效的技术动作

- 为 `L=3` 引入 `FFA`
- 合并 `E0 / E2` 的跨分支共享
- 压缩矩阵加法网络
- 或将 `L=3` 迁移到更大器件，例如 `xczu4ev`
