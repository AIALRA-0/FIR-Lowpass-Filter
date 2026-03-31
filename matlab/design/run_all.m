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
local_plot_orders(root, order_table, spec);
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
figure('Visible', 'off', 'Position', [100 100 920 980]);
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
labels = {'baseline\_taps100', 'baseline\_order100', 'final\_spec'};
responses = {m0, m1, mf};
colors = [ ...
    59 110 165; ...
    129 178 154; ...
    224 122 95] ./ 255;
for idx = 1:3
    nexttile;
    plot(w ./ pi, responses{idx}, 'LineWidth', 1.4, 'Color', colors(idx, :)); hold on;
    xline(spec.wp, '--k');
    xline(spec.ws, '--r');
    yline(-spec.ast_min_db, ':r');
    text(spec.wp + 0.005, -14, 'Wp = 0.20', 'Color', 'k', 'FontSize', 8, 'Rotation', 90, 'VerticalAlignment', 'top');
    text(spec.ws + 0.005, -14, 'Ws = 0.23', 'Color', 'r', 'FontSize', 8, 'Rotation', 90, 'VerticalAlignment', 'top');
    text(0.84, -spec.ast_min_db + 2.5, 'Ast target = -80 dB', 'Color', 'r', 'FontSize', 8);
    grid on;
    xlim([0 1]);
    ylim([-125 5]);
    ylabel('Magnitude (dB)');
    title(labels{idx}, 'Interpreter', 'none');
    if idx == 3
        xlabel('Normalized Frequency (\times\pi rad/sample)');
    end
end
sgtitle('Floating-Point Frequency Response Comparison');
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

function local_plot_orders(root, order_table, spec)
plot_dir = fullfile(root, 'docs', 'assets', 'plots');
final_rows = order_table(strcmp(order_table.design_group, 'final_spec'), :);
figure('Visible', 'off', 'Position', [100 100 960 540]);
hold on;
combos = unique(final_rows(:, {'method', 'ap_target_db'}), 'rows');
combo_count = height(combos);
palette = lines(max(combo_count, 9));
for idx = 1:combo_count
    method = combos.method{idx};
    ap_target = combos.ap_target_db(idx);
    mask = strcmp(final_rows.method, method) & abs(final_rows.ap_target_db - ap_target) < 1e-12;
    subset = sortrows(final_rows(mask, :), 'order');
    plot(subset.order, subset.ast_db, '-.', ...
        'Color', palette(idx, :), ...
        'LineWidth', 1.2, ...
        'MarkerSize', 8, ...
        'DisplayName', sprintf('%s, Ap=%.2f dB', method, ap_target));
end
yline(spec.ast_min_db, '--k');
text(max(final_rows.order) + 6, spec.ast_min_db + 1.0, 'Ast target = 80 dB', 'Color', 'k', 'FontSize', 8, 'VerticalAlignment', 'bottom');
grid on;
xlim([min(final_rows.order) - 5, 650]);
ylim([max(0, min(final_rows.ast_db) - 8), max(final_rows.ast_db) + 8]);
xlabel('Order');
ylabel('Stopband Attenuation (dB)');
title('Final-Spec Order vs Stopband Attenuation');
legend('Location', 'EastOutside');
saveas(gcf, fullfile(plot_dir, 'order_vs_ast.png'));
close(gcf);
end

function local_plot_weights(root, weight_table)
plot_dir = fullfile(root, 'docs', 'assets', 'plots');
figure('Visible', 'off', 'Position', [100 100 820 720]);
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
methods = unique(weight_table.method, 'stable');
colors = [59 110 165; 224 122 95] ./ 255;
metrics = {'ast_db', 'ap_db'};
ylabels = {'Stopband Attenuation (dB)', 'Passband Ripple (dB)'};
titles = {'Ast vs Stopband Weight', 'Ap vs Stopband Weight'};
for mid = 1:2
    nexttile;
    hold on;
    for idx = 1:numel(methods)
        subset = weight_table(strcmp(weight_table.method, methods{idx}), :);
        subset = sortrows(subset, 'stop_weight');
        plot(subset.stop_weight, subset.(metrics{mid}), '-o', 'LineWidth', 1.2, 'MarkerSize', 4.5, 'Color', colors(idx, :), 'DisplayName', methods{idx});
    end
    set(gca, 'XScale', 'log');
    grid on;
    xlabel('Stopband Weight (log scale)');
    ylabel(ylabels{mid});
    title(titles{mid});
end
nexttile(1);
yline(80, '--k');
text(1.02, 80.6, '80 dB target', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
legend('Location', 'southeast');
sgtitle('Weight Sweep Tradeoff for firpm and firls');
saveas(gcf, fullfile(plot_dir, 'weight_tradeoff.png'));
close(gcf);
end

function local_write_report(root, summary)
report_path = fullfile(root, 'reports', 'floating_design_report.md');
fid = fopen(report_path, 'w');
assert(fid ~= -1, 'Failed to open floating design report.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Floating-Point Design Report\n\n');
fprintf(fid, '## Final Design\n\n');
fprintf(fid, '- Design ID: `%s`\n', summary.final_design.design_id);
fprintf(fid, '- Method: `%s`\n', summary.final_design.method);
fprintf(fid, '- Order: `%d`\n', summary.final_design.order);
fprintf(fid, '- Taps: `%d`\n', summary.final_design.taps);
fprintf(fid, '- Passband ripple: `%.4f dB`\n', summary.final_design.ap_db);
fprintf(fid, '- Stopband attenuation: `%.4f dB`\n\n', summary.final_design.ast_db);
fprintf(fid, '## Dual Baselines\n\n');
fprintf(fid, '- baseline_taps100: `%s`, `%s`, Ast=`%.4f dB`\n', ...
    summary.baseline_taps100.design_id, summary.baseline_taps100.method, summary.baseline_taps100.ast_db);
fprintf(fid, '- baseline_order100: `%s`, `%s`, Ast=`%.4f dB`\n', ...
    summary.baseline_order100.design_id, summary.baseline_order100.method, summary.baseline_order100.ast_db);
fprintf(fid, '\n## Artifacts\n\n');
fprintf(fid, '- `data/design_space.csv`\n');
fprintf(fid, '- `data/weight_tradeoff.csv`\n');
fprintf(fid, '- `coeffs/final_float.csv`\n');
fprintf(fid, '- `docs/assets/plots/freqresp_float_compare.png`\n');
fprintf(fid, '- `docs/assets/plots/order_vs_ast.png`\n');
fprintf(fid, '- `docs/assets/plots/weight_tradeoff.png`\n');
end
