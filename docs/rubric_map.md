# Rubric Mapping

## 1. MATLAB Design Description and Verilog Structure Description (20%)

- `spec/spec.md`
- `matlab/design/*.m`
- `reports/floating_design_report.md`
- `rtl/README.md`

## 2. Original and Quantized Frequency Response, Quantization Impact, and Overflow Handling (20%)

- `matlab/fixed/*.m`
- `data/fixedpoint_sweep.csv`
- `reports/quantization_report.md`

## 3. Pipelined and/or Parallel FIR Architecture Design (20%)

- `docs/assets/dfg/*.mmd`
- `docs/assets/dfg/*.svg`
- `reports/architecture_math.md`
- `rtl/fir_*`

## 4. Detailed Hardware Implementation Results (20%)

- `vivado/tcl/*.tcl`
- `data/impl_results.csv`
- `reports/synth_summary.md`

## 5. Analysis and Conclusions (20%)

- `README.md`
- `docs/index.md`
- `report/latex/sections/05_analysis.tex`
