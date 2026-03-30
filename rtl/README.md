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
- `rtl/system/fir_stream_shell.v`
- `rtl/system/fir_zu4ev_shell.v`
- `rtl/system/zu4ev_fir_*_top.v`

## 接口约定

- 标量模块：`clk,rst,in_valid,in_sample,out_valid,out_sample`
- 向量模块：`clk,rst,in_valid,in_vec,out_valid,out_vec`
- `in_vec[WIN-1:0]` 为 lane0，即该拍最早样本

## 当前实现状态

- `fir_symm_base`：对称折叠基线，可综合，已通过标量 bit-true 回归
- `fir_pipe_systolic`：对称折叠 + systolic 累加链，可综合，已通过标量 bit-true 回归
- `fir_l2_polyphase`：真正 `L=2 polyphase + symmetry` datapath，已通过向量 bit-true 回归并完成 ZU4EV Vivado 实现
- `fir_l3_polyphase`：共享 `L3 FFA core` 的 `L=3` datapath，已通过全量向量 bit-true 回归并完成 ZU4EV Vivado 实现
- `fir_l3_pipe`：在 `L3 FFA core` 外加输入/输出 pipeline cut 的 `L=3 + pipeline` datapath，已通过全量向量 bit-true 回归并完成 ZU4EV Vivado 实现
- `rtl/system/*`：ZU4EV `PS + PL` 系统壳，统一把 PS 侧看到的接口保持为标量 `Q1.15` stream，PL 内部再完成 `L=2 / L=3` 打包与还原

## 系数来源

- 标量系数由 `rtl/common/fir_params.vh` 与 `rtl/common/fir_coeffs.vh` 自动生成
- `L=2 / L=3` polyphase 分支系数由 `rtl/common/fir_polyphase_params.vh` 与 `rtl/common/fir_polyphase_coeffs.vh` 自动生成

## 当前结论

- 当前最强、最稳的可落板版本仍然是 `fir_pipe_systolic`
- `fir_l2_polyphase` 已经从占位实现升级成真正可综合的并行架构
- `fir_l3_polyphase` / `fir_l3_pipe` 已证明 `FFA` 压缩方向能在 ZU4EV 上形成真正的高吞吐候选
- 下一轮优化重点是 ZU4EV 系统壳、板上 smoke flow 和 vendor FIR IP 对照，而不是继续围绕 7020 做主线设计
