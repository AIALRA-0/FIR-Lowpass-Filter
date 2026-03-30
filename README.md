# FIR Lowpass Filter Research Kit

面向课程项目与作品集双用途的低通 FIR 研究型工程。当前主线已经完全迁移到 `MZU04A-4EV / XCZU4EV-SFVC784-2I`，并围绕同一套 MATLAB 规格、同一套固定点模型、同一套 bit-true 验证链路，对比以下实现：

- `baseline_taps100`
- `baseline_order100`
- `final_spec`
- `symmetry-folded baseline`
- `pipelined systolic`
- `L=2 polyphase`
- `L=3 polyphase / FFA`
- `L=3 + pipeline`
- `vendor FIR IP`

## 当前三分钟结论

- 满足规格的最终滤波器是 `firpm / order 260 / 261 taps`
- 默认固定点是 `Q1.15 + Wcoef20 + Wout16 + Wacc46`
- 标量与向量 bit-true 回归都已经闭环
- 主平台已经切到 `XCZU4EV-SFVC784-2I`，JTAG 可识别 `xczu4` 与 `arm_dap`，UART 控制台是 `COM9 / CP210x`
- `PS + PL` 系统壳已经能在 Vivado 中生成 bitstream 与 `.xsa`，当前验证通过的系统顶层是 `zu4ev_fir_pipe_systolic_top`
- 当前自研架构里的 `performance hero` 与 `efficiency hero` 都是 `fir_pipe_systolic`
  - `459.348 MHz`
  - `459.348 MS/s`
  - `132 DSP`
  - `3.803 nJ/sample`
- `fir_l3_polyphase` 已经是共享 `L3 FFA core` 的真实压缩并行架构，并在 ZU4EV 上达到 `381.388 MS/s`
- 当前主阻塞不再是“L3 放不下”，而是系统级壳、上板软件链和 vendor FIR IP 还没有全部收口

## 项目目标

- 满足规格：`wp = 0.2`、`ws = 0.23`、`Ast >= 80 dB`
- 保留题目歧义下的双 baseline：`100 taps` 与 `order = 100`
- 完成浮点设计、固定点量化、bit-true 向量、RTL、Vivado 批处理、GitHub Pages、LaTeX 报告
- 在 `MZU04A-4EV` 上完成 `PS + PL + Bare-metal Vitis` 的可演示系统
- 输出可复现、可对比、可展示的研究型工程

## 快速开始

1. 配置工具路径：
   - 复制 `config/toolchains.local.example.json` 为 `config/toolchains.local.json`
   - 或设置环境变量 `MATLAB_BIN`、`VIVADO_BIN`
2. 运行设计与量化：
   - `matlab -batch "run('matlab/design/run_all.m')"`
   - `matlab -batch "run('matlab/fixed/run_fixed.m')"`
3. 生成验证向量与系统侧 C 数组：
   - `matlab -batch "run('matlab/vectors/gen_vectors.m')"`
   - `python scripts/export_zu4ev_vectors.py`
4. 运行 RTL 回归：
   - `powershell -ExecutionPolicy Bypass -File scripts/run_scalar_regression.ps1 -Dut base -Case impulse`
   - `powershell -ExecutionPolicy Bypass -File scripts/run_vector_regression.ps1 -Dut l3 -Case random_short`
5. 运行 ZU4EV 实现矩阵：
   - `powershell -ExecutionPolicy Bypass -File scripts/run_vivado_impl.ps1 -Top all`
6. 运行 JTAG / 硬件探测：
   - `powershell -ExecutionPolicy Bypass -File scripts/check_jtag_stack.ps1`
7. 构建 ZU4EV PS+PL 系统壳：
   - `vivado -mode batch -source vivado/tcl/zu4ev/build_zu4ev_system.tcl`

## 当前状态

- 规格真源：[`spec/spec.json`](spec/spec.json)
- 项目状态：[`docs/status.md`](docs/status.md)
- GitHub Pages 入口：[`docs/index.md`](docs/index.md)
- JTAG / 上板指南：[`docs/bringup_mzu04a_zu4ev.md`](docs/bringup_mzu04a_zu4ev.md)
- 系统壳状态：[`reports/system_shell_status.md`](reports/system_shell_status.md)
- 文献矩阵：[`docs/literature/lit_matrix.md`](docs/literature/lit_matrix.md)
- LaTeX 主文档：[`report/latex/main.tex`](report/latex/main.tex)

## 当前已产出的关键结果

- `final_spec`：`firpm`，`order = 260`，`261 taps`
- 浮点结果：`Ap = 0.0304 dB`，`Ast = 83.9902 dB`
- 量化后结果：`Ap = 0.0305 dB`，`Ast = 81.3994 dB`
- 最小回归已通过：
  - 标量：`fir_symm_base`、`fir_pipe_systolic`
  - 向量：`fir_l2_polyphase`、`fir_l3_polyphase`、`fir_l3_pipe`
- ZU4EV Vivado 实现结果：
  - `fir_symm_base`：`127.065 MHz`，`2810 LUT`，`3569 FF`，`126 DSP`
  - `fir_pipe_systolic`：`459.348 MHz`，`16712 LUT`，`17224 FF`，`132 DSP`
  - `fir_l2_polyphase`：`278.668 MS/s`，`5868 LUT`，`2439 FF`，`262 DSP`
  - `fir_l3_polyphase`：`381.388 MS/s`，`34687 LUT`，`6914 FF`，`175 DSP`
  - `fir_l3_pipe`：`363.284 MS/s`，`34786 LUT`，`7199 FF`，`175 DSP`

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
vitis/          Bare-metal Vitis 系统软件
data/           CSV/JSON 结果真源
docs/           GitHub Pages 内容
report/latex/   Overleaf/LaTeX 报告真源
scripts/        自动化脚本
reports/        研究与实现分析 Markdown
```

## 结果判定

- `performance hero`：最大吞吐表现最优
- `efficiency hero`：`energy/sample` 与 `throughput/DSP` 综合表现最优

当前在 ZU4EV 自研矩阵里，二者都由 `fir_pipe_systolic` 获胜。

## 当前硬件状态

- 主板卡：`MZU04A-4EV`
- 主器件：`XCZU4EV-SFVC784-2I`
- UART：`COM9 / CP210x`
- JTAG：Vivado Hardware Manager 已能枚举 `xczu4` 与 `arm_dap`
- 供电：`12V`
- 当前 bring-up 文档：[`docs/bringup_mzu04a_zu4ev.md`](docs/bringup_mzu04a_zu4ev.md)

## 同步约定

- 主分支：`main`
- 阶段 tag：`phase-00-bootstrap`、`phase-01-spec-freeze` 等
- 文档语言：中文优先，英文后续人工精修
- 7020 历史结果只保留在 git 历史和附录素材里，不再进入主叙事
