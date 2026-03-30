# ZU4EV System Shell Status

## 当前结果

`vivado/tcl/zu4ev/build_zu4ev_system.tcl` 已经在本机 Vivado 2024.1 上完成一次真实运行，成功产出：

- bitstream
- `.xsa`
- 基于 `Zynq UltraScale+ MPSoC + AXI DMA + AXI-Lite + FIR shell` 的系统硬件平台

当前已验证通过的系统顶层是：

- `zu4ev_fir_pipe_systolic_top`

产物位置：

- `build/zu4ev_system/zu4ev_fir_pipe_systolic_top/zu4ev_fir_pipe_systolic_top.xsa`

## 系统结构

- PS：`zynq_ultra_ps_e`
- 控制总线：`M_AXI_HPM0_LPD + M_AXI_HPM0_FPD -> SmartConnect -> AXI DMA Lite + FIR control regs`
- 数据总线：`AXI DMA <-> SmartConnect <-> S_AXI_HPC0_FPD`
- PL 数据壳：`fir_stream_shell`
- 板级封装：`fir_zu4ev_shell`

## 已解决的问题

- `common.tcl` 在 `zu4ev/` 子目录下调用时仓库根路径解析错误
- `module reference` 缺少 `.vh` 头文件导致 FIR shell 无法实例化
- Windows 路径带空格导致 `.bd` 路径被拆开
- MPSoC 同时暴露 `HPM0_FPD` 与 `HPM0_LPD`，未完成地址路径会触发 `validate_bd_design` 失败

## 当前保留警告

- `S_AXI_HPC0_FPD` 与 `SmartConnect` 存在 `ARUSER/AWUSER` 位宽警告
- `axi_dma` 与中间互连仍有若干性能与 DRC advisory
- 当前系统壳只验证了 `zu4ev_fir_pipe_systolic_top` 这一条主线

这些警告目前没有阻止 bitstream 与 `.xsa` 生成，但在上板与长期维护阶段需要继续收口。

## 下一步

1. 用 `vitis/zu4ev_baremetal` 导入 `.xsa`，跑 `impulse / step / random_short` smoke vectors。
2. 把 `zu4ev_fir_l2_top` 或 `zu4ev_fir_l3_top` 接进同一套系统壳，满足至少两个架构上板。
3. 在系统壳稳定后，再把 `vendor FIR IP` 纳入 ZU4EV 总表。
