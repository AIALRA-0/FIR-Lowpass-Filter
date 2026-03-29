# Testbench 说明

## 标量 testbench

- 文件：`tb/tb_fir_scalar.sv`
- 默认 DUT：`fir_symm_base`
- 可通过宏切换 DUT，例如：
  - `xvlog -sv -d DUT_PIPE ... tb/tb_fir_scalar.sv`
- 推荐直接使用：
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut base -Case impulse`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut pipe -Case step`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut pipe -Case random_short`

## 向量 testbench

- 文件：`tb/tb_fir_vector.sv`
- 默认 DUT：`fir_l2_polyphase`
- 可通过宏切换 DUT 与 lane 数，例如：
  - `xvlog -sv ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_L3 ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_L3_PIPE ... tb/tb_fir_vector.sv`
- 推荐直接使用：
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l2 -Case impulse`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l2 -Case lane_alignment`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l3 -Case random_short`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l3_pipe -Case step`

## Plusargs

- `+INPUT_FILE=<path>`
- `+GOLDEN_FILE=<path>`

默认 case 为 `vectors/impulse/`。
若从 `build/sim/...` 目录运行，testbench 会优先查找 staged 向量；若找不到，再回退到仓库根目录路径。

当前 testbench 会在 `readmemh` 后自动统计输入帧数与黄金输出帧数，因此通常不再需要额外传 `+INPUT_LEN`。

## 当前最小回归集合

- 标量：
  - `impulse`
  - `step`
  - `random_short`
- 向量：
  - `impulse`
  - `step`
  - `random_short`
  - `lane_alignment_l2`
  - `lane_alignment_l3`
