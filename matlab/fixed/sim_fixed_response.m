function result = sim_fixed_response(coeffs_q, spec, coef_width, output_width, input_signal)
%SIM_FIXED_RESPONSE Simulate fixed-point FIR behavior with full-precision internal arithmetic.

win = spec.fixed_point.input_width;
fin = spec.fixed_point.input_frac_bits;
coeff_int = quantize_signed_frac(coeffs_q(:), coef_width, coef_width - 1);
input_int = quantize_signed_frac(input_signal(:), win, fin);
full_conv = conv(double(input_int), double(coeff_int));

nuniq = ceil(numel(coeffs_q) / 2);
wacc = win + coef_width + ceil(log2(max(nuniq, 1))) + spec.fixed_point.extra_acc_guard_bits;
acc_min = -2^(wacc - 1);
acc_max = 2^(wacc - 1) - 1;
overflow_count = sum(full_conv < acc_min | full_conv > acc_max);

shift = coef_width - 1;
rounded = round(full_conv ./ 2^shift);
out_min = -2^(output_width - 1);
out_max = 2^(output_width - 1) - 1;
saturated = min(max(rounded, out_min), out_max);

result.output_int = saturated(:);
result.output_float = saturated(:) ./ 2^fin;
result.overflow_count = overflow_count;
result.max_abs_acc = max(abs(full_conv));
result.acc_width = wacc;
result.coef_width = coef_width;
result.output_width = output_width;
end
