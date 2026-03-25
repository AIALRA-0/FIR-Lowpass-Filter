# 文献与官方资料矩阵

| 来源 | 类型 | 核心主题 | 可借鉴点 | 不直接照搬的原因 |
| --- | --- | --- | --- | --- |
| MathWorks FIR Filter Design | 官方文档 | `firpm` / `firls` / windowing | 设计方法对比、线性相位与对称性基础 | 只覆盖算法设计，不给硬件微架构 |
| MathWorks Fixed-Point Filter Design | 官方文档 | 系数量化、溢出与精度损失 | bit-true 建模、量化分析流程 | 不给具体 FPGA DSP 映射 |
| AMD FIR Compiler PG149 | 官方文档 | FIR IP 结构、symmetry、systolic/transpose | 作为 vendor baseline 与对称利用依据 | IP 是黑盒，不适合作为自定义 RTL 主线 |
| AMD 7-series DSP48E1 User Guide | 官方文档 | pre-adder、multiplier、cascade | 指导 systolic 切分与资源映射 | 不提供完整 FIR 系统实现 |
| Intel FIR Compiler II | 官方文档 | vector input、rounding/saturation | 结果指标与 IP 功能对照 | 平台不同，作为对照而非主线 |
| 2019 symmetry in conventional polyphase FIR | 论文 | conventional polyphase 保留系数对称性 | 支撑 L=2/L=3 路线 | 需要转化为本项目可实现 RTL |
| 2020 3-parallel odd-length FIR | 论文 | L=3、odd-length、乘法器优化 | 支撑 3 并行 hero 设计 | 论文公式需结合本项目位宽与接口重构 |
| 2024+ parallel FIR / FFA papers | 论文 | 混合并行与快速 FIR | 拓展 L=3+pipeline 组合设计 | 复杂度高，需按课程项目范围裁剪 |

## 当前结论

- 主设计算法：`firpm`
- 结构主线：`symmetry + direct-form/systolic + pipeline`
- 并行主线：`polyphase + symmetry`
- `transpose`：保留为对照说明，不进入主线实现

