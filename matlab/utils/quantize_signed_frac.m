function values_int = quantize_signed_frac(values, width, frac_bits)
%QUANTIZE_SIGNED_FRAC Quantize floating-point values to signed fixed-point integers.

scale = 2^frac_bits;
raw = round(values(:) .* scale);
min_int = -2^(width - 1);
max_int = 2^(width - 1) - 1;
values_int = min(max(raw, min_int), max_int);
end
