# Regression Report

## 状态

- MATLAB 浮点设计：完成
- MATLAB 固定点扫描：完成
- 黄金向量生成：完成
- Vivado `xvlog` 语法检查：完成
- Vivado `xelab` 展开：完成
- `fir_symm_base` 标量 bit-true：已闭环
- `fir_pipe_systolic` 标量 bit-true：已闭环
- `fir_l2_polyphase` 向量 bit-true：已闭环
- `fir_l3_polyphase` 向量 bit-true：已闭环
- `fir_l3_pipe` 向量 bit-true：已闭环
- 已验证最小用例：`impulse`、`step`、`random_short(1024-sample prefix)`、`lane_alignment`

## 说明

当前仓库已经具备：

- 自动生成黄金向量
- 可编译的标量与向量 testbench
- Vivado 仿真入口
- `scripts/run_scalar_regression.ps1` 一键标量回归入口
- `scripts/run_vector_regression.ps1` 一键向量回归入口
- `scripts/regenerate_vectors.py` 在 MATLAB 启动异常时的向量重生成后备方案

本轮修复的关键点：

- testbench 改为在采样边沿前驱动激励，避免输入错一拍
- memory file 不存在时立即 `fatal`，避免“假通过”
- 向量量化修正为 signed fixed-point 饱和量化，消除了 `Q1.15` 下 `1.0 -> 16'h8000` 的符号翻转问题
- `fir_symm_base` 改为显式 `hist_bus` 选取样本，消除了 `sample_at()` 在 xsim 中导致的全 `x` 问题
- `round_sat.v` 改为对称 nearest rounding，使 RTL 与黄金模型一致
- `fir_pipe_systolic` 在 `in_valid=0` 后仍继续推进零样本，能够正确排空流水线尾部
- `tb_fir_vector.sv` 改为从已加载的 memory 文件自动统计 `input_frames` / `output_frames`，避免 xsim `plusargs` 在 Windows 路径下的脆弱行为
- `fir_l2_polyphase` 已替换为真实 `E0(z^2) / E1(z^2)` polyphase datapath
- `fir_l3_polyphase` / `fir_l3_pipe` 已替换为真实 `E0(z^3) / E1(z^3) / E2(z^3)` polyphase datapath

## 已通过的最小回归矩阵

| DUT | 用例 | 结果 |
| --- | --- | --- |
| `fir_symm_base` | `impulse` / `step` / `random_short` | PASS |
| `fir_pipe_systolic` | `impulse` / `step` / `random_short` | PASS |
| `fir_l2_polyphase` | `impulse` / `step` / `random_short` / `lane_alignment_l2` | PASS |
| `fir_l3_polyphase` | `impulse` / `step` / `random_short` / `lane_alignment_l3` | PASS |
| `fir_l3_pipe` | `impulse` / `step` / `random_short` / `lane_alignment_l3` | PASS |

## 当前限制

- 当前正式回归矩阵仍以最小闭环用例为主，`dc / passband / transition / stopband / multitone / overflow_corner` 这些全量展示用例已经生成，但还未全部纳入每次提交都运行的快速回归
- `fir_l3_pipe` 与 `fir_l3_polyphase` 在仿真上完全一致，仅延迟不同；当前实现差异主要体现在寄存器数量与预期 Fmax，而不是数值路径

## 当前下一优先级

- 为 `dc / passband_edge / transition / stopband / multitone / overflow_corner` 增加批量回归封装
- 将 `vendor FIR IP` 纳入同一条 bit-true / latency 对齐检查链
- 为 `L=3` 引入 `FFA / cross-branch sharing`，解决当前 `xc7z020` 上的资源超限
