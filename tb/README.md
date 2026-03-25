# Testbench 说明

## 标量 testbench

- 文件：`tb/tb_fir_scalar.sv`
- 默认 DUT：`fir_symm_base`
- 可通过宏切换 DUT，例如：
  - `xvlog -sv -d DUT_MODULE=fir_pipe_systolic ... tb/tb_fir_scalar.sv`

## 向量 testbench

- 文件：`tb/tb_fir_vector.sv`
- 默认 DUT：`fir_l2_polyphase`
- 可通过宏切换 DUT 与 lane 数，例如：
  - `xvlog -sv -d DUT_MODULE=fir_l2_polyphase -d LANES=2 ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_MODULE=fir_l3_polyphase -d LANES=3 ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_MODULE=fir_l3_pipe -d LANES=3 ... tb/tb_fir_vector.sv`

## Plusargs

- `+INPUT_FILE=<path>`
- `+GOLDEN_FILE=<path>`
- `+INPUT_LEN=<N>`

默认 case 为 `vectors/impulse/`。

