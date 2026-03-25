# Quantization Report

- Floating-point taps: `261`
- Selected coefficient width: `20`
- Selected output width: `16`
- Quantized passband ripple: `0.0305 dB`
- Quantized stopband attenuation: `81.3994 dB`
- Internal overflow count: `0`
- Accumulator width: `46`

## 产物

- `data/fixedpoint_sweep.csv`
- `coeffs/final_fixed_q*_full.memh`
- `coeffs/final_fixed_q*_unique.memh`
- `rtl/common/fir_params.vh`
- `rtl/common/fir_coeffs.vh`
