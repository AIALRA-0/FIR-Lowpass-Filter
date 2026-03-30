# Board Validation

## 状态

ZU4EV 板级自动化闭环已经稳定跑通，当前两条正式验收架构都完成了：

- bitstream 自动生成与导出
- `.xsa` 自动导出
- XSCT/JTAG 自动下载 bitstream + ELF
- `COM9 / CP210x` 串口自动抓取
- smoke + 频域边缘 + long-run 自动判定

当前正式收尾对象：

- `fir_pipe_systolic`
- `vendor_fir_ip`

## 最新通过的板测运行

| Arch | Run ID | Arch ID | 结果 | 日志 |
| --- | --- | ---: | --- | --- |
| `fir_pipe_systolic` | `20260330-113630` | `1` | PASS | `data/board_runs/fir_pipe_systolic/20260330-113630/uart.log` |
| `vendor_fir_ip` | `20260330-113805` | `5` | PASS | `data/board_runs/vendor_fir_ip/20260330-113805/uart.log` |

## 当前正式板上用例

| Case | Length | 目的 |
| --- | ---: | --- |
| `impulse` | `1024` | 冲激响应与系数次序 |
| `step` | `1024` | DC 收敛 |
| `random_short` | `1024` | bit-true smoke |
| `passband_edge_sine` | `1024` | 通带边缘保持 |
| `transition_sine` | `1024` | 过渡带行为 |
| `multitone` | `2048` | 多音稳定性 |
| `stopband_sine` | `1024` | 阻带抑制 |
| `large_random_buffer` | `2048` | 长 buffer + DMA 稳定性 |

两条架构的最新正式运行均满足：

- `8 / 8` case 通过
- `mismatches = 0`
- `failures = 0`
- `status = 0x00000001`

## 最近 3 次正式窗口稳定性

| Arch | Window Runs | All Passed | Run IDs |
| --- | ---: | --- | --- |
| `fir_pipe_systolic` | `3` | `True` | `20260330-112958, 20260330-113315, 20260330-113630` |
| `vendor_fir_ip` | `3` | `True` | `20260330-113137, 20260330-113453, 20260330-113805` |

更细的每用例 cycle 统计见：

- `reports/board_stability.md`
- `data/analysis/board_stability_recent_arch.csv`
- `data/analysis/board_stability_recent_cases.csv`

## 关键观察

- 这轮真正解决的系统阻塞是 `AXI DMA -> HPC0 -> OCM` 地址映射。`assign_bd_address` 之后，Vivado 默认把 `SEG_ps_0_HPC0_LPS_OCM` 标成 excluded；恢复该段映射后，DMA decode error 消失。
- bare-metal harness 当前稳定运行于 OCM 上的静态 DMA buffer，不再依赖 DDR/cache 维护路径来完成主线验收。
- `passband_edge_sine` 与 `transition_sine` 现在已经进入正式板测集合，说明板上验证已经不再只看 impulse/step/random，而是开始覆盖与滤波规格直接相关的频域边缘行为。
- `fir_pipe_systolic` 与 `vendor_fir_ip` 的 cycle 数非常接近，说明在当前系统壳下，PS/DMA/stream shell 的固定开销占比很高。

## 真源文件

- 汇总 CSV：`data/board_results.csv`
- 最近窗口稳定性：`data/analysis/board_stability_recent_arch.csv`
- 全历史稳定性：`data/analysis/board_stability_arch.csv`
- 原始 UART JSON：`data/board_runs/<arch>/<run_id>/uart.json`
- 原始 UART 日志：`data/board_runs/<arch>/<run_id>/uart.log`

## 自动化入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch fir_pipe_systolic -ForceAppBuild -MaxAttempts 2
powershell -ExecutionPolicy Bypass -File scripts/run_zu4ev_closure.ps1 -Arch vendor_fir_ip -ForceAppBuild -MaxAttempts 2
```

每次 closure 成功后，脚本会自动刷新：

- `data/board_results.csv`
- `data/analysis/board_stability_*.csv`
- `data/impl_results.csv`
- `data/analysis/*.csv`
