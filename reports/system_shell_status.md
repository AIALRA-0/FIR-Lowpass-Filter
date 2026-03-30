# ZU4EV System Shell Status

## 当前结果

`vivado/tcl/zu4ev/build_zu4ev_system.tcl` 已经在本机 Vivado 2024.1 上完成一次真实运行，成功产出：

- bitstream
- `.xsa`
- 基于 `Zynq UltraScale+ MPSoC + AXI DMA + AXI-Lite + FIR shell` 的系统硬件平台

当前已验证通过并完成自动板测闭环的系统顶层是：

- `zu4ev_fir_pipe_systolic_top`
- `zu4ev_fir_vendor_top`

产物位置：

- `build/zu4ev_system/zu4ev_fir_pipe_systolic_top/zu4ev_fir_pipe_systolic_top.xsa`
- `build/zu4ev_system/zu4ev_fir_vendor_top/zu4ev_fir_vendor_top.xsa`

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
- `AXI DMA` 通过 `HPC0` 访问 OCM 时，`SEG_ps_0_HPC0_LPS_OCM` 被 Vivado 自动排除，导致 MM2S decode error
- 当前 bare-metal harness 的 DMA buffer 已切到 OCM 静态数组，系统级 smoke / long-run 已验证通过

## 当前保留警告

- `S_AXI_HPC0_FPD` 与 `SmartConnect` 存在 `ARUSER/AWUSER` 位宽警告
- `axi_dma` 与中间互连仍有若干性能与 DRC advisory
- `vendor FIR IP` 的独立 kernel-scope 综合脚本仍未并入默认 `run_vivado_impl.ps1` 流程；当前主线使用 board-shell scope 作为工业基线口径

这些警告目前没有阻止 bitstream 与 `.xsa` 生成，但在上板与长期维护阶段需要继续收口。

## 当前结论

- `scripts/run_zu4ev_closure.ps1` 已经实现完整的 `build -> download -> run -> capture -> judge` 自动闭环
- 两条正式验收架构都已通过板测：
  - `fir_pipe_systolic`
  - `vendor_fir_ip`
- 板测真源位于：
  - `data/board_runs/`
  - `data/board_results.csv`
