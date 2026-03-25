function [dp, ds] = db_to_dev(ap_db, ast_db)
%DB_TO_DEV Convert passband ripple / stopband attenuation in dB to linear deviations.

dp = (10^(ap_db / 20) - 1) / (10^(ap_db / 20) + 1);
ds = 10^(-ast_db / 20);
end

