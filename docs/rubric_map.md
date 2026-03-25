# Rubric 映射

## 1. MATLAB 设计说明与 Verilog 结构说明（20%）

- `spec/spec.md`
- `matlab/design/*.m`
- `reports/floating_design_report.md`
- `rtl/README.md`

## 2. 原始与量化后频率响应、量化影响、溢出处理（20%）

- `matlab/fixed/*.m`
- `data/fixedpoint_sweep.csv`
- `reports/quantization_report.md`

## 3. 流水线和/或并行 FIR 架构设计（20%）

- `docs/assets/dfg/*.mmd`
- `docs/assets/dfg/*.svg`
- `reports/architecture_math.md`
- `rtl/fir_*`

## 4. 详细硬件实现结果（20%）

- `vivado/tcl/*.tcl`
- `data/impl_results.csv`
- `reports/synth_summary.md`

## 5. 分析与总结（20%）

- `README.md`
- `docs/index.md`
- `report/latex/sections/05_analysis.tex`

