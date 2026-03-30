# ZU4EV Bare-Metal Harness

这一目录保存 `MZU04A-4EV / XCZU4EV-SFVC784-2I` 的主线裸机工程源文件。主线策略固定为：

- `PS UART0` 连接板上 `CP2104`，主机侧控制台为 `COM9`
- JTAG 下载 bitstream / ELF
- `AXI DMA + AXI-Stream FIR shell + AXI-Lite control` 作为统一系统壳
- 软件只使用标量 `Q1.15` 样本数组，不区分 `scalar / L2 / L3`

## 构建前提

- 先在 Vivado 里运行 `vivado/tcl/zu4ev/build_zu4ev_system.tcl`
- 导出包含 bitstream 的 `.xsa`
- 用 Vitis/XSCT 基于该 `.xsa` 创建 standalone 平台和本应用

## 当前烟测内容

- `impulse`
- `step`
- `random_short`

这些向量由 `scripts/export_zu4ev_vectors.py` 从仓库内 `vectors/` 自动导出。
