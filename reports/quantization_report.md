# Quantization Report

## 最终选择

- 最终浮点滤波器：`firpm / order 260 / 261 taps`
- 默认输入格式：`Q1.15`
- 选中系数位宽：`Wcoef = 20`
- 选中输出位宽：`Wout = 16`
- 选中累加器位宽：`Wacc = 46`
- 量化后通带纹波：`Ap = 0.0305 dB`
- 量化后阻带衰减：`Ast = 81.3994 dB`
- 内部溢出计数：`0`

## 为什么 100 taps 级别不够

本项目没有直接把“100 taps”当成最终答案，而是先保留两条 baseline，把题目歧义吃干净：

| 设计线 | 阶数 / taps | 方法 | Ap (dB) | Ast (dB) | 是否满足规格 |
| --- | ---: | --- | ---: | ---: | --- |
| `baseline_taps100` | `99 / 100` | `firpm` | `0.9920` | `40.0001` | 否 |
| `baseline_order100` | `100 / 101` | `firpm` | `0.9621` | `40.2591` | 否 |
| `final_spec` | `260 / 261` | `firpm` | `0.0304` | `83.9902` | 是 |

结论很直接：

- 在 `wp = 0.2`、`ws = 0.23`、`Ast >= 80 dB` 这个规格下，`100` 左右 taps 只有约 `40 dB` 量级的阻带衰减
- 这不是量化造成的问题，而是**浮点设计本身就没有足够自由度**
- 把阶数提升到 `260` 之后，才获得了足够的 stopband 裕量，量化阶段也才有稳定落地空间

## 为什么 `Wcoef = 20` 是合理拐点

固定点扫描中，当前默认 `Wout = 16` 时的结果如下：

| Coef Width | Ap (dB) | Ast (dB) | Overflow Count | Acc Width | Meets Fixed |
| ---: | ---: | ---: | ---: | ---: | --- |
| `16` | `0.0353` | `67.7052` | `0` | `42` | 否 |
| `18` | `0.0312` | `77.1994` | `0` | `44` | 否 |
| `20` | `0.0305` | `81.3994` | `0` | `46` | 是 |
| `22` | `0.0304` | `83.5251` | `0` | `48` | 是 |
| `24` | `0.0304` | `84.0107` | `0` | `50` | 是 |

这里最关键的不是“位宽越大越好”，而是“第一个安全点在哪里”：

- `Wcoef = 16` 明显不够，阻带只有 `67.7 dB`
- `Wcoef = 18` 已经接近，但仍只有 `77.2 dB`
- `Wcoef = 20` 是第一个稳定跨过 `80 dB` 门槛的点
- 继续加到 `22` 或 `24` 只能换来边际收益，却会继续推高位宽与硬件成本

因此，`Wcoef = 20` 是一个很合理的工程折中点：它不是最宽，但它是第一个满足规格、又能把成本控制住的点。

## 位宽推导

### Pre-adder 与乘法器

当前输入是 `Q1.15`，即 `Win = 16`。为了对称折叠时安全相加，pre-adder 额外保留 `1` 个 guard bit：

```text
Wpre = Win + 1 = 17
```

因此保守乘积位宽为：

```text
Wprod = Wpre + Wcoef = 17 + 20 = 37
```

### 累加器位宽

当前线性相位 odd-length 设计共有 `261 taps`，对称折叠后唯一乘法器数为：

```text
Nuniq = (261 + 1) / 2 = 131
```

项目默认累加器位宽规则是：

```text
Wacc = Win + Wcoef + ceil(log2(Nuniq)) + 2
     = 16 + 20 + ceil(log2(131)) + 2
     = 16 + 20 + 8 + 2
     = 46
```

这里最后的 `+2` 是额外 guard bits，不是随手拍脑袋加上的“保险位”，而是为了把最坏情况累加裕量留出来，避免结构切换时变得脆弱。

### 保守输出上界

量化后系数绝对值和为：

```text
Σ|h_q[k]| = 1,153,458 / 2^19 ≈ 2.2000
```

对 `Q1.15` 输入，最大正幅度整数值为：

```text
|x|max = 32767
```

则整数域下的保守累加上界可写为：

```text
|y|max <= |x|max * Σ|h_q[k]|
        <= 32767 * 1,153,458
        = 37,795,358,286
```

这个上界需要 `37` 个带符号位宽即可容纳，而当前我们实际给了 `46` 位累加器：

- 相对保守上界仍有 `9` bit headroom
- 相对实际仿真观测值 `max_abs_acc = 14,996,190,552`，还有 `11` bit headroom

这也是为什么当前扫描结果里 `overflow_count = 0` 并不是“运气好没炸”，而是有位宽依据支撑的。

## 为什么只在输出边界做 `round + saturate`

项目当前采用的策略是：

- 内部 pre-add、乘法、累加：保持 full precision
- 最终输出：统一 `round-to-nearest + saturate`

这样做的好处是：

- 内部运算不因为中途截断而累积偏差
- RTL、golden vector、board harness 都共享同一条末级量化规则
- `custom` 和 `vendor` 可以在完全相同的输出规则下比较

如果在 branch 内部或 adder tree 中间多次截断，最后虽然也能得到 16-bit 输出，但比较口径会被污染，bit-true 链也会变脆弱。

## 当前结论

- 量化阶段真正的关键不是“位宽要多宽”，而是“第一组稳定满足规格的位宽在哪里”
- 对当前 `261 taps` 设计，`Wcoef = 20` 正好是这个拐点
- `Wacc = 46` 不是浪费，而是保证 `overflow_count = 0` 和跨架构复用的必要安全裕量
- 当前量化后仍保持：
  - `Ap ≈ 0.0305 dB`
  - `Ast ≈ 81.3994 dB`

因此，当前默认 fixed-point 方案是一个有证据支撑、而且对 RTL/board 闭环都友好的工程定案。

## 产物

- `data/fixedpoint_sweep.csv`
- `data/analysis/quantization_threshold.csv`
- `data/analysis/bitwidth_derivation.json`
- `coeffs/final_fixed_q*_full.memh`
- `coeffs/final_fixed_q*_unique.memh`
- `rtl/common/fir_params.vh`
- `rtl/common/fir_coeffs.vh`
