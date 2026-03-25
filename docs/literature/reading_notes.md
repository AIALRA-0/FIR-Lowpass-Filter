# 阅读笔记

## MathWorks FIR Filter Design

- `firpm` 适合作为主设计路线，因为它以 minimax/equiripple 为核心
- 线性相位 FIR 的对称系数可直接转化为硬件折叠乘法器
- 固定系数数目时，过渡带与阻带衰减之间需要 tradeoff

## MathWorks Fixed-Point Filter Design

- 即使中间乘加 full precision，系数量化也会改变频率响应
- 溢出、舍入噪声和最终输出位宽需要分开建模
- bit-true 向量是连接 MATLAB 与 RTL 的关键

## AMD FIR Compiler / DSP48E1

- 对称系数与 pre-adder 非常适合低通线性相位 FIR
- systolic/pipelined direct form 更贴近 DSP slice 级联
- transpose 可低延迟，但不是本项目主线

## Polyphase / Parallel 文献

- 并行不是复制多条 FIR，而是重构数据流与子滤波器
- `L=2` 和 `L=3` 的价值在于同时提升吞吐并尽量保留 symmetry
- `L=3 + pipeline` 是否最终胜出，由综合结果决定

