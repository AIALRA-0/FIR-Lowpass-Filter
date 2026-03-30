# Board Stability

本页把“板子跑通一次”和“板子能稳定重复跑”区分开来。为了避免早期调试期的失败 run 污染最终统计，这里主表只采用**当前正式 8-case 套件的最近 3 次通过运行**。

## 最近 3 次正式窗口

| Arch | Expected Case Count | Window Runs | All Passed | Run IDs |
| --- | ---: | ---: | --- | --- |
| `fir_pipe_systolic` | `8` | `3` | `True` | `20260330-112958, 20260330-113315, 20260330-113630` |
| `vendor_fir_ip` | `8` | `3` | `True` | `20260330-113137, 20260330-113453, 20260330-113805` |

## 自研 Hero 稳定性

| Case | Length | Cycles Min | Cycles Mean | Cycles Max | Mismatch Sum | Error Status Count |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `impulse` | `1024` | `1297644` | `1297662.0` | `1297676` | `0` | `0` |
| `step` | `1024` | `1158807` | `1158821.667` | `1158837` | `0` | `0` |
| `random_short` | `1024` | `1529163` | `1529179.667` | `1529205` | `0` | `0` |
| `passband_edge_sine` | `1024` | `1806891` | `1806919.0` | `1806937` | `0` | `0` |
| `transition_sine` | `1024` | `1668051` | `1668055.667` | `1668059` | `0` | `0` |
| `multitone` | `2048` | `1391287` | `1391304.333` | `1391323` | `0` | `0` |
| `stopband_sine` | `1024` | `1575401` | `1575433.667` | `1575459` | `0` | `0` |
| `large_random_buffer` | `2048` | `1854209` | `1854228.333` | `1854251` | `0` | `0` |

## Vendor 基线稳定性

| Case | Length | Cycles Min | Cycles Mean | Cycles Max | Mismatch Sum | Error Status Count |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `impulse` | `1024` | `1297627` | `1297658.0` | `1297687` | `0` | `0` |
| `step` | `1024` | `1158816` | `1158825.667` | `1158843` | `0` | `0` |
| `random_short` | `1024` | `1529170` | `1529186.333` | `1529214` | `0` | `0` |
| `passband_edge_sine` | `1024` | `1806908` | `1806924.333` | `1806948` | `0` | `0` |
| `transition_sine` | `1024` | `1668043` | `1668051.667` | `1668068` | `0` | `0` |
| `multitone` | `2048` | `1391307` | `1391321.667` | `1391332` | `0` | `0` |
| `stopband_sine` | `1024` | `1575448` | `1575465.0` | `1575498` | `0` | `0` |
| `large_random_buffer` | `2048` | `1854248` | `1854267.0` | `1854295` | `0` | `0` |

## 观察

- 两条架构在最近 3 次正式窗口里都做到：
  - `8 / 8` case 全通过
  - `mismatch_sum = 0`
  - `error_status_count = 0`
- cycle 数在 run-to-run 间只有很小波动，符合 JTAG 下载、PS 启动与 DMA 调度带来的正常抖动
- `passband_edge_sine` 与 `transition_sine` 现在已经进入正式板测集合，这意味着：
  - 板上验证不再只看 impulse / step / random
  - 频域边缘行为已经从 MATLAB/RTL 链延伸到板上系统闭环

## 说明

- 历史全量 run 仍保留在 `data/board_runs/`
- 历史全量统计在：
  - `data/analysis/board_stability_arch.csv`
  - `data/analysis/board_stability_cases.csv`
- 正式报告建议优先引用本页对应的最近窗口统计，因为它反映的是**当前最终 harness 与当前正式用例集**，而不是早期调试阶段的混合状态
