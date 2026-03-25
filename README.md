# FIR Lowpass Filter Research Kit

面向课程项目与作品集双用途的低通 FIR 研究型工程。项目围绕同一套 MATLAB 规格、同一套固定点模型、同一套 RTL 验证链路，系统比较以下实现：

- `baseline_taps100`
- `baseline_order100`
- `final_spec`
- `symmetry-folded baseline`
- `pipelined systolic`
- `L=2 polyphase`
- `L=3 polyphase / FFA`
- `L=3 + pipeline`
- `vendor FIR IP`

## 项目目标

- 满足规格：`wp = 0.2`、`ws = 0.23`、`Ast >= 80 dB`
- 保留题目歧义下的双 baseline：`100 taps` 与 `order = 100`
- 完成浮点设计、固定点量化、bit-true 向量、RTL、Vivado 批处理、GitHub Pages、LaTeX 报告
- 输出可复现、可对比、可展示的研究型工程

## 快速开始

1. 配置工具路径：
   - 复制 `config/toolchains.local.example.json` 为 `config/toolchains.local.json`
   - 或设置环境变量 `MATLAB_BIN`、`VIVADO_BIN`
2. 运行 MATLAB 浮点设计：
   - `matlab -batch "run('matlab/design/run_all.m')"`
3. 运行固定点量化：
   - `matlab -batch "run('matlab/fixed/run_fixed.m')"`
4. 生成验证向量：
   - `matlab -batch "run('matlab/vectors/gen_vectors.m')"`
5. 生成 DFG/SFG 图：
   - `python scripts/generate_dfg.py`
6. 运行 Vivado 批处理：
   - `vivado -mode batch -source vivado/tcl/run_all.tcl`

## 当前状态

- 规格真源：[`spec/spec.json`](spec/spec.json)
- 项目状态：[`docs/status.md`](docs/status.md)
- Rubric 映射：[`docs/rubric_map.md`](docs/rubric_map.md)
- 文献矩阵：[`docs/literature/lit_matrix.md`](docs/literature/lit_matrix.md)
- GitHub Pages 入口：[`docs/index.md`](docs/index.md)
- LaTeX 主文档：[`report/latex/main.tex`](report/latex/main.tex)

## 当前已产出的关键结果

- `final_spec`：`firpm`，`order = 260`，`261 taps`
- 浮点结果：`Ap = 0.0304 dB`，`Ast = 83.9902 dB`
- 固定点默认：`Q1.15` 输入，`20-bit` 系数，`16-bit` 输出，`46-bit` 累加器
- 量化后结果：`Ap = 0.0305 dB`，`Ast = 81.3994 dB`
- 已完成 Vivado 实现：
  - `fir_symm_base`：约 `51.5 MHz`，`2785 LUT`，`3552 FF`，`126 DSP`
  - `fir_pipe_systolic`：约 `264.4 MHz`，`16643 LUT`，`17332 FF`，`132 DSP`

## 目录结构

```text
spec/           规格真源与说明
config/         工具链配置模板
matlab/         浮点、固定点、向量生成脚本
coeffs/         导出的系数文件
vectors/        黄金输入输出向量
rtl/            Verilog RTL
tb/             Testbench
vivado/         非工程模式 TCL
data/           CSV/JSON 结果真源
docs/           GitHub Pages 内容
report/latex/   Overleaf/LaTeX 报告真源
scripts/        Python 自动化脚本
reports/        研究与实现分析 Markdown
```

## 结果判定

- `performance hero`：最大吞吐或最高 `throughput / Fclk` 表现最优
- `efficiency hero`：`throughput-per-DSP` 或 `energy-per-sample` 表现最优

## 同步约定

- 主分支：`main`
- 阶段 tag：`phase-00-bootstrap`、`phase-01-spec-freeze` 等
- 文档语言：中文优先，英文后续人工精修
