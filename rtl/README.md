# RTL 结构说明

## 公共模块

- `rtl/common/delay_line.v`
- `rtl/common/fir_delay_signed.v`
- `rtl/common/preadd_mult.v`
- `rtl/common/round_sat.v`
- `rtl/common/valid_pipe.v`
- `rtl/common/fir_params.vh`
- `rtl/common/fir_coeffs.vh`

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
- 当前系数由 `rtl/common/fir_params.vh` 与 `rtl/common/fir_coeffs.vh` 自动生成

## 当前实现状态

- `fir_symm_base`：对称折叠基线，可综合
- `fir_pipe_systolic`：对称折叠 + systolic 累加链，可综合
- `fir_l2_polyphase` / `fir_l3_polyphase`：先提供功能正确的向量参考内核，后续再继续压缩到 symmetry-preserving polyphase datapath
- `fir_l3_pipe`：在 `L=3` 参考内核外再加一级输出流水

