# Regression Report

## 状态

- MATLAB 浮点设计：完成
- MATLAB 固定点扫描：完成
- 黄金向量生成：完成
- Vivado `xvlog` 语法检查：完成
- Vivado `xelab` 展开：完成
- xsim `tb_fir_scalar` / `impulse`：未通过，当前表现为全 `x` mismatch，说明 DUT 与 testbench 的时序/初始化联调仍需修复
- 详细 xsim bit-true 回归：进行中

## 说明

当前仓库已经具备：

- 自动生成黄金向量
- 可编译的标量与向量 testbench
- Vivado 仿真入口

但 bit-true 仿真链尚未闭环，后续需要优先修正 `tb_fir_scalar` 与 `fir_symm_base` 的对齐问题，再扩展到 `fir_pipe_systolic` 和向量版。
