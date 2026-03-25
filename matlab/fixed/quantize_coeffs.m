function q = quantize_coeffs(coeffs, width)
%QUANTIZE_COEFFS Quantize floating-point coefficients into signed fractional fixed-point.

scale = 2^(width - 1);
raw = round(coeffs .* scale);
raw = min(max(raw, -scale), scale - 1);
q = raw ./ scale;
end

