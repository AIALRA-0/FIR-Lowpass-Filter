# RTL 结构说明

## 公共模块

- `rtl/common/delay_line.v`
- `rtl/common/fir_delay_signed.v`
- `rtl/common/fir_branch_core_symm.v`
- `rtl/common/fir_branch_core_full.v`
- `rtl/common/fir_branch_core_mirror_pair.v`
- `rtl/common/fir_l3_ffa_core.v`
- `rtl/common/preadd_mult.v`
- `rtl/common/round_sat.v`
- `rtl/common/valid_pipe.v`
- `rtl/common/fir_params.vh`
- `rtl/common/fir_coeffs.vh`
- `rtl/common/fir_polyphase_params.vh`
- `rtl/common/fir_polyphase_coeffs.vh`

## 架构模块

- `rtl/fir_symm_base/fir_symm_base.v`
- `rtl/fir_pipe_systolic/fir_pipe_systolic.v`
- `rtl/fir_l2_polyphase/fir_l2_polyphase.v`
- `rtl/fir_l3_polyphase/fir_l3_polyphase.v`
- `rtl/fir_l3_pipe/fir_l3_pipe.v`

## 接口约定

- 标量模块：`clk,rst,in_valid,in_sample,out_valid,out_sample`
- 向量模块：`clk,rst,in_valid,in_vec,out_valid,out_vec`
- `in_vec[WIN-1:0]` 为 lane0，即该拍最早样本

## 当前实现状态

- `fir_symm_base`：对称折叠基线，可综合，已通过标量 bit-true 回归
- `fir_pipe_systolic`：对称折叠 + systolic 累加链，可综合，已通过标量 bit-true 回归
- `fir_l2_polyphase`：真正 `L=2 polyphase + symmetry` datapath，已通过向量 bit-true 回归并完成 Vivado 实现
- `fir_l3_polyphase`：共享 `L3 FFA core` 的 `L=3` datapath，已通过全量向量 bit-true 回归并完成 Vivado 实现
- `fir_l3_pipe`：在 `L3 FFA core` 外加输入/输出 pipeline cut 的 `L=3 + pipeline` datapath，已通过全量向量 bit-true 回归并完成 Vivado 实现

## 系数来源

- 标量系数由 `rtl/common/fir_params.vh` 与 `rtl/common/fir_coeffs.vh` 自动生成
- `L=2 / L=3` polyphase 分支系数由 `rtl/common/fir_polyphase_params.vh` 与 `rtl/common/fir_polyphase_coeffs.vh` 自动生成

## 当前结论

- 当前最强、最稳的可落板版本仍然是 `fir_pipe_systolic`
- `fir_l2_polyphase` 已经从占位实现升级成真正可综合的并行架构
- `fir_l3_polyphase` / `fir_l3_pipe` 已证明 `FFA` 压缩方向能把 `L3` 压进 `xc7z020`
- 下一轮优化重点不再是“能不能放下”，而是“如何把 `L3` 时序拉到至少 `102.344 MHz`”
