function metrics = evaluate_fir_metrics(b, spec)
%EVALUATE_FIR_METRICS Compute frequency-response metrics for an FIR filter.

nfft = 65536;
h = fft(b(:), nfft);
half_len = floor(nfft / 2) + 1;
h = h(1:half_len);
w = linspace(0, pi, half_len).';
mag_db = 20 * log10(abs(h) + 1e-14);

passband_mask = (w <= spec.wp * pi);
stopband_mask = (w >= spec.ws * pi);

passband_mag = mag_db(passband_mask);
stopband_mag = mag_db(stopband_mask);

metrics.ap_db = max(passband_mag) - min(passband_mag);
metrics.passband_max_db = max(passband_mag);
metrics.passband_min_db = min(passband_mag);
metrics.ast_db = -max(stopband_mag);
metrics.transition_width = spec.ws - spec.wp;
metrics.group_delay_samples = (numel(b) - 1) / 2;
metrics.nfft = nfft;
metrics.w = w;
metrics.mag_db = mag_db;
end
