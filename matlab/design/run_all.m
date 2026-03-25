addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'utils')));

root = project_root();
addpath(genpath(fullfile(root, 'matlab')));
spec = load_spec();

ensure_dir(fullfile(root, 'data'));
ensure_dir(fullfile(root, 'coeffs'));
ensure_dir(fullfile(root, 'reports'));
ensure_dir(fullfile(root, 'docs', 'assets', 'plots'));

order_table = sweep_orders(spec);
weight_table = sweep_weights(spec);

writetable(order_table, fullfile(root, 'data', 'design_space.csv'));
writetable(weight_table, fullfile(root, 'data', 'weight_tradeoff.csv'));

valid_final = order_table(strcmp(order_table.design_group, 'final_spec') & order_table.meets_spec, :);
if isempty(valid_final)
    warning('No final_spec candidate met the full specification. Falling back to best stopband attenuation.');
    valid_final = order_table(strcmp(order_table.design_group, 'final_spec'), :);
    [~, best_idx] = max(valid_final.ast_db);
    valid_final = valid_final(best_idx, :);
else
    [~, sort_idx] = sortrows(table(valid_final.taps, ~valid_final.odd_length, valid_final.group_delay_samples, ...
        'VariableNames', {'taps', 'even_penalty', 'delay'}), {'taps', 'even_penalty', 'delay'});
    valid_final = valid_final(sort_idx(1), :);
end

baseline_taps = local_select_baseline(order_table, 'baseline_taps100');
baseline_order = local_select_baseline(order_table, 'baseline_order100');

final_coeffs = local_parse_coeff_csv(valid_final.coeff_csv{1});
baseline_taps_coeffs = local_parse_coeff_csv(baseline_taps.coeff_csv{1});
baseline_order_coeffs = local_parse_coeff_csv(baseline_order.coeff_csv{1});

final_design = struct( ...
    'design_id', valid_final.design_id{1}, ...
    'design_group', valid_final.design_group{1}, ...
    'method', valid_final.method{1}, ...
    'order', valid_final.order(1), ...
    'taps', valid_final.taps(1), ...
    'ap_db', valid_final.ap_db(1), ...
    'ast_db', valid_final.ast_db(1), ...
    'coeffs', final_coeffs ...
    );

baseline_designs = struct( ...
    'baseline_taps100', struct('design_id', baseline_taps.design_id{1}, 'method', baseline_taps.method{1}, ...
        'order', baseline_taps.order(1), 'taps', baseline_taps.taps(1), 'ap_db', baseline_taps.ap_db(1), ...
        'ast_db', baseline_taps.ast_db(1), 'coeffs', baseline_taps_coeffs), ...
    'baseline_order100', struct('design_id', baseline_order.design_id{1}, 'method', baseline_order.method{1}, ...
        'order', baseline_order.order(1), 'taps', baseline_order.taps(1), 'ap_db', baseline_order.ap_db(1), ...
        'ast_db', baseline_order.ast_db(1), 'coeffs', baseline_order_coeffs) ...
    );

save(fullfile(root, 'data', 'floating_design.mat'), 'final_design', 'baseline_designs', 'order_table', 'weight_table', 'spec');
export_coeffs(root, final_design);

summary = struct( ...
    'final_design', rmfield(final_design, 'coeffs'), ...
    'baseline_taps100', rmfield(baseline_designs.baseline_taps100, 'coeffs'), ...
    'baseline_order100', rmfield(baseline_designs.baseline_order100, 'coeffs') ...
    );
write_json_pretty(fullfile(root, 'data', 'floating_design_summary.json'), summary);

local_plot_frequency(root, spec, baseline_taps_coeffs, baseline_order_coeffs, final_coeffs);
local_plot_orders(root, order_table);
local_plot_weights(root, weight_table);
local_write_report(root, summary);

disp('Floating-point design flow completed.');

function row = local_select_baseline(order_table, group_name)
group_rows = order_table(strcmp(order_table.design_group, group_name), :);
[~, idx] = sortrows(table(-group_rows.ast_db, group_rows.ap_db, group_rows.taps, ...
    'VariableNames', {'neg_ast', 'ap_db', 'taps'}), {'neg_ast', 'ap_db', 'taps'});
row = group_rows(idx(1), :);
end

function coeffs = local_parse_coeff_csv(csv_text)
parts = split(string(csv_text), ',');
coeffs = str2double(parts);
coeffs = coeffs(:).';
end

function local_plot_frequency(root, spec, b0, b1, bf)
plot_dir = fullfile(root, 'docs', 'assets', 'plots');
[w, m0] = local_mag_db(b0);
[~, m1] = local_mag_db(b1);
[~, mf] = local_mag_db(bf);
figure('Visible', 'off');
plot(w ./ pi, m0, 'LineWidth', 1.2); hold on;
plot(w ./ pi, m1, 'LineWidth', 1.2);
plot(w ./ pi, mf, 'LineWidth', 1.5);
xline(spec.wp, '--k', 'Wp');
xline(spec.ws, '--r', 'Ws');
yline(-spec.ast_min_db, ':r', 'Ast min');
grid on;
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
title('Floating-Point Frequency Response Comparison');
legend('baseline\_taps100', 'baseline\_order100', 'final\_spec', 'Location', 'SouthWest');
saveas(gcf, fullfile(plot_dir, 'freqresp_float_compare.png'));
close(gcf);
end

function [w, mag_db] = local_mag_db(b)
nfft = 65536;
h = fft(b(:), nfft);
half_len = floor(nfft / 2) + 1;
h = h(1:half_len);
w = linspace(0, pi, half_len).';
mag_db = 20 * log10(abs(h) + 1e-14);
end

function local_plot_orders(root, order_table)
plot_dir = fullfile(root, 'docs', 'assets', 'plots');
final_rows = order_table(strcmp(order_table.design_group, 'final_spec'), :);
figure('Visible', 'off');
gscatter(final_rows.order, final_rows.ast_db, final_rows.method);
grid on;
xlabel('Order');
ylabel('Stopband Attenuation (dB)');
title('Final-Spec Order vs Stopband Attenuation');
saveas(gcf, fullfile(plot_dir, 'order_vs_ast.png'));
close(gcf);
end

function local_plot_weights(root, weight_table)
plot_dir = fullfile(root, 'docs', 'assets', 'plots');
figure('Visible', 'off');
plot(weight_table.stop_weight, weight_table.ast_db, 'o', 'MarkerSize', 5); hold on;
plot(weight_table.stop_weight, weight_table.ap_db, 'x', 'MarkerSize', 5);
grid on;
xlabel('Stopband Weight');
ylabel('Metric Value (dB)');
title('Baseline Weight Sweep Tradeoff');
legend('Ast', 'Ap', 'Location', 'Best');
saveas(gcf, fullfile(plot_dir, 'weight_tradeoff.png'));
close(gcf);
end

function local_write_report(root, summary)
report_path = fullfile(root, 'reports', 'floating_design_report.md');
fid = fopen(report_path, 'w');
assert(fid ~= -1, 'Failed to open floating design report.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Floating-Point Design Report\n\n');
fprintf(fid, '## 最终方案\n\n');
fprintf(fid, '- 设计 ID: `%s`\n', summary.final_design.design_id);
fprintf(fid, '- 方法: `%s`\n', summary.final_design.method);
fprintf(fid, '- Order: `%d`\n', summary.final_design.order);
fprintf(fid, '- Taps: `%d`\n', summary.final_design.taps);
fprintf(fid, '- Passband ripple: `%.4f dB`\n', summary.final_design.ap_db);
fprintf(fid, '- Stopband attenuation: `%.4f dB`\n\n', summary.final_design.ast_db);
fprintf(fid, '## 双 Baseline\n\n');
fprintf(fid, '- baseline_taps100: `%s`, `%s`, Ast=`%.4f dB`\n', ...
    summary.baseline_taps100.design_id, summary.baseline_taps100.method, summary.baseline_taps100.ast_db);
fprintf(fid, '- baseline_order100: `%s`, `%s`, Ast=`%.4f dB`\n', ...
    summary.baseline_order100.design_id, summary.baseline_order100.method, summary.baseline_order100.ast_db);
fprintf(fid, '\n## 产物\n\n');
fprintf(fid, '- `data/design_space.csv`\n');
fprintf(fid, '- `data/weight_tradeoff.csv`\n');
fprintf(fid, '- `coeffs/final_float.csv`\n');
fprintf(fid, '- `docs/assets/plots/freqresp_float_compare.png`\n');
fprintf(fid, '- `docs/assets/plots/order_vs_ast.png`\n');
fprintf(fid, '- `docs/assets/plots/weight_tradeoff.png`\n');
end
