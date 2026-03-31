# Testbench Notes

## Scalar Testbench

- File: `tb/tb_fir_scalar.sv`
- Default DUT: `fir_symm_base`
- The DUT can be switched with macros, for example:
  - `xvlog -sv -d DUT_PIPE ... tb/tb_fir_scalar.sv`
- Recommended direct usage:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut base -Case impulse`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut pipe -Case step`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut pipe -Case random_short`

## Vector Testbench

- File: `tb/tb_fir_vector.sv`
- Default DUT: `fir_l2_polyphase`
- The DUT and lane count can be switched with macros, for example:
  - `xvlog -sv ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_L3 ... tb/tb_fir_vector.sv`
  - `xvlog -sv -d DUT_L3_PIPE ... tb/tb_fir_vector.sv`
- Recommended direct usage:
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l2 -Case impulse`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l2 -Case lane_alignment`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l3 -Case random_short`
  - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l3_pipe -Case step`

## Plusargs

- `+INPUT_FILE=<path>`
- `+GOLDEN_FILE=<path>`

The default case is `vectors/impulse/`.
If run from a `build/sim/...` directory, the testbench will first search for staged vectors; if they are not found, it falls back to the repository-root paths.

The current testbench automatically counts input frames and golden output frames after `readmemh`, so passing an additional `+INPUT_LEN` is usually no longer necessary.

## Current Minimum Regression Set

- Scalar:
  - `impulse`
  - `step`
  - `random_short`
- Vector:
  - `impulse`
  - `step`
  - `random_short`
  - `lane_alignment_l2`
  - `lane_alignment_l3`
