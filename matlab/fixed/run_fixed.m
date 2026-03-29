addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'utils')));

root = project_root();
addpath(genpath(fullfile(root, 'matlab')));
spec = load_spec();

floating_data = load(fullfile(root, 'data', 'floating_design.mat'));
final_float = floating_data.final_design;

ensure_dir(fullfile(root, 'coeffs'));
ensure_dir(fullfile(root, 'data'));
ensure_dir(fullfile(root, 'reports'));

coef_widths = spec.fixed_point.coef_width_candidates(:).';
output_widths = spec.fixed_point.output_width_candidates(:).';
ap_limit = spec.design_selection.ap_max_db + 0.02;
ast_limit = spec.ast_min_db - 1.0;

rows = {};
row_idx = 1;
test_vectors = local_build_eval_vectors(spec);

for wcoef = coef_widths
    coeffs_q = quantize_coeffs(final_float.coeffs, wcoef);
    metrics = evaluate_fir_metrics(coeffs_q, spec);
    for wout = output_widths
        overflow_count = 0;
        max_abs_acc = 0;
        acc_width = 0;
        for vidx = 1:numel(test_vectors)
            sim_result = sim_fixed_response(coeffs_q, spec, wcoef, wout, test_vectors{vidx}.signal);
            overflow_count = overflow_count + sim_result.overflow_count;
            max_abs_acc = max(max_abs_acc, sim_result.max_abs_acc);
            acc_width = sim_result.acc_width;
        end
        meets_fixed = (metrics.ap_db <= ap_limit) && (metrics.ast_db >= ast_limit) && (overflow_count == 0);
        rows(row_idx, :) = { ...
            sprintf('q%02d_o%02d', wcoef, wout), ...
            wcoef, ...
            wout, ...
            metrics.ap_db, ...
            metrics.ast_db, ...
            overflow_count, ...
            max_abs_acc, ...
            acc_width, ...
            meets_fixed, ...
            string(strjoin(compose('%.18g', coeffs_q(:).'), ',')) ...
            }; %#ok<AGROW>
        row_idx = row_idx + 1;
    end
end

fixed_table = cell2table(rows, 'VariableNames', { ...
    'design_id', 'coef_width', 'output_width', 'ap_db', 'ast_db', ...
    'overflow_count', 'max_abs_acc', 'acc_width', 'meets_fixed', 'coeff_csv'});
writetable(fixed_table, fullfile(root, 'data', 'fixedpoint_sweep.csv'));

valid_rows = fixed_table(fixed_table.meets_fixed, :);
if isempty(valid_rows)
    warning('No fixed-point candidate met the current default limits. Falling back to best attenuation with zero overflow if available.');
    zero_overflow = fixed_table(fixed_table.overflow_count == 0, :);
    if isempty(zero_overflow)
        [~, idx] = min(fixed_table.overflow_count);
        valid_rows = fixed_table(idx, :);
    else
        [~, idx] = max(zero_overflow.ast_db);
        valid_rows = zero_overflow(idx, :);
    end
else
    [~, idx] = sortrows(table(valid_rows.coef_width, valid_rows.output_width, -valid_rows.ast_db, ...
        'VariableNames', {'coef_width', 'output_width', 'neg_ast'}), {'coef_width', 'output_width', 'neg_ast'});
    valid_rows = valid_rows(idx(1), :);
end

selected = valid_rows(1, :);
selected_coeffs = local_parse_coeff_csv(selected.coeff_csv{1});

local_export_fixed_files(root, spec, selected, selected_coeffs, final_float.taps);
local_write_quant_report(root, final_float, selected);

summary = struct( ...
    'coef_width', selected.coef_width(1), ...
    'output_width', selected.output_width(1), ...
    'ap_db', selected.ap_db(1), ...
    'ast_db', selected.ast_db(1), ...
    'overflow_count', selected.overflow_count(1), ...
    'acc_width', selected.acc_width(1), ...
    'taps', final_float.taps, ...
    'order', final_float.order ...
    );
write_json_pretty(fullfile(root, 'data', 'fixed_design_summary.json'), summary);

disp('Fixed-point design flow completed.');

function coeffs = local_parse_coeff_csv(csv_text)
parts = split(string(csv_text), ',');
coeffs = str2double(parts);
coeffs = coeffs(:).';
end

function vectors = local_build_eval_vectors(spec)
n = spec.vector_generation.random_length;
rng(spec.vector_generation.seed);
vectors = { ...
    struct('name', 'impulse', 'signal', [1; zeros(spec.vector_generation.impulse_length - 1, 1)]), ...
    struct('name', 'step', 'signal', ones(spec.vector_generation.step_length, 1) * 0.8), ...
    struct('name', 'random', 'signal', 2 * rand(n, 1) - 1), ...
    struct('name', 'alt', 'signal', 0.95 * repmat([1; -1], ceil(n / 2), 1)) ...
    };
vectors{4}.signal = vectors{4}.signal(1:n);
end

function local_export_fixed_files(root, spec, selected, coeffs, taps)
coeffs_dir = fullfile(root, 'coeffs');
rtl_dir = fullfile(root, 'rtl', 'common');
ensure_dir(coeffs_dir);
ensure_dir(rtl_dir);

wcoef = selected.coef_width(1);
coeff_int = quantize_signed_frac(coeffs(:), wcoef, wcoef - 1);

full_memh = fullfile(coeffs_dir, sprintf('final_fixed_q%d_full.memh', wcoef));
local_write_hex_file(full_memh, coeff_int, wcoef);

unique_int = coeff_int(1:ceil(numel(coeff_int) / 2));
uniq_memh = fullfile(coeffs_dir, sprintf('final_fixed_q%d_unique.memh', wcoef));
local_write_hex_file(uniq_memh, unique_int, wcoef);

params_vh = fullfile(rtl_dir, 'fir_params.vh');
fid = fopen(params_vh, 'w');
assert(fid ~= -1, 'Failed to write fir_params.vh.');
cleanup0 = onCleanup(@() fclose(fid));
fprintf(fid, '`ifndef FIR_PARAMS_VH\n');
fprintf(fid, '`define FIR_PARAMS_VH\n');
fprintf(fid, '`define FIR_TAPS %d\n', taps);
fprintf(fid, '`define FIR_UNIQ %d\n', numel(unique_int));
fprintf(fid, '`define FIR_WIN %d\n', spec.fixed_point.input_width);
fprintf(fid, '`define FIR_WCOEF %d\n', wcoef);
fprintf(fid, '`define FIR_WOUT %d\n', selected.output_width(1));
fprintf(fid, '`define FIR_SHIFT %d\n', wcoef - 1);
fprintf(fid, '`define FIR_WACC %d\n', selected.acc_width(1));
fprintf(fid, '`endif\n');

coeff_vh = fullfile(rtl_dir, 'fir_coeffs.vh');
fid = fopen(coeff_vh, 'w');
assert(fid ~= -1, 'Failed to write fir_coeffs.vh.');
cleanup1 = onCleanup(@() fclose(fid));
fprintf(fid, '`ifndef FIR_COEFFS_VH\n');
fprintf(fid, '`define FIR_COEFFS_VH\n');
fprintf(fid, 'function automatic signed [`FIR_WCOEF-1:0] fir_coeff_at;\n');
fprintf(fid, '  input integer idx;\n');
fprintf(fid, '  begin\n');
fprintf(fid, '    case (idx)\n');
for idx = 1:numel(unique_int)
    if unique_int(idx) < 0
        fprintf(fid, '      %d: fir_coeff_at = -%d''sd%d;\n', idx - 1, wcoef, abs(unique_int(idx)));
    else
        fprintf(fid, '      %d: fir_coeff_at = %d''sd%d;\n', idx - 1, wcoef, unique_int(idx));
    end
end
fprintf(fid, '      default: fir_coeff_at = %d''sd0;\n', wcoef);
fprintf(fid, '    endcase\n');
fprintf(fid, '  end\n');
fprintf(fid, 'endfunction\n');
fprintf(fid, '`endif\n');

local_export_polyphase_files(coeffs_dir, rtl_dir, coeff_int, wcoef);
end

function local_write_hex_file(path_str, values, width)
fid = fopen(path_str, 'w');
assert(fid ~= -1, 'Failed to write %s', path_str);
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(values)
    fprintf(fid, '%s\n', local_twos_hex(values(idx), width));
end
end

function text = local_twos_hex(value, width)
if value < 0
    value = value + 2^width;
end
digits = ceil(width / 4);
text = upper(dec2hex(value, digits));
end

function local_write_quant_report(root, float_design, selected)
report_path = fullfile(root, 'reports', 'quantization_report.md');
fid = fopen(report_path, 'w');
assert(fid ~= -1, 'Failed to open quantization report.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Quantization Report\n\n');
fprintf(fid, '- Floating-point taps: `%d`\n', float_design.taps);
fprintf(fid, '- Selected coefficient width: `%d`\n', selected.coef_width(1));
fprintf(fid, '- Selected output width: `%d`\n', selected.output_width(1));
fprintf(fid, '- Quantized passband ripple: `%.4f dB`\n', selected.ap_db(1));
fprintf(fid, '- Quantized stopband attenuation: `%.4f dB`\n', selected.ast_db(1));
fprintf(fid, '- Internal overflow count: `%d`\n', selected.overflow_count(1));
fprintf(fid, '- Accumulator width: `%d`\n', selected.acc_width(1));
fprintf(fid, '\n## 产物\n\n');
fprintf(fid, '- `data/fixedpoint_sweep.csv`\n');
fprintf(fid, '- `coeffs/final_fixed_q*_full.memh`\n');
fprintf(fid, '- `coeffs/final_fixed_q*_unique.memh`\n');
fprintf(fid, '- `rtl/common/fir_params.vh`\n');
fprintf(fid, '- `rtl/common/fir_coeffs.vh`\n');
fprintf(fid, '- `coeffs/final_fixed_q*_l2_e*.memh`\n');
fprintf(fid, '- `coeffs/final_fixed_q*_l3_e*.memh`\n');
fprintf(fid, '- `rtl/common/fir_polyphase_params.vh`\n');
fprintf(fid, '- `rtl/common/fir_polyphase_coeffs.vh`\n');
end

function local_export_polyphase_files(coeffs_dir, rtl_dir, coeff_int, wcoef)
branches = { ...
    struct('name', 'l2_e0', 'full', coeff_int(1:2:end), 'uniq', coeff_int(1:2:end)), ...
    struct('name', 'l2_e1', 'full', coeff_int(2:2:end), 'uniq', coeff_int(2:2:end)), ...
    struct('name', 'l3_e0', 'full', coeff_int(1:3:end), 'uniq', coeff_int(1:3:end)), ...
    struct('name', 'l3_e1', 'full', coeff_int(2:3:end), 'uniq', coeff_int(2:3:end)), ...
    struct('name', 'l3_e2', 'full', coeff_int(3:3:end), 'uniq', coeff_int(3:3:end)) ...
    };

branches{1}.uniq = branches{1}.full(1:ceil(numel(branches{1}.full) / 2));
branches{2}.uniq = branches{2}.full(1:numel(branches{2}.full) / 2);
branches{4}.uniq = branches{4}.full(1:ceil(numel(branches{4}.full) / 2));

for bidx = 1:numel(branches)
    b = branches{bidx};
    local_write_hex_file(fullfile(coeffs_dir, sprintf('final_fixed_q%d_%s_full.memh', wcoef, b.name)), b.full, wcoef);
    local_write_hex_file(fullfile(coeffs_dir, sprintf('final_fixed_q%d_%s_unique.memh', wcoef, b.name)), b.uniq, wcoef);
end

params_path = fullfile(rtl_dir, 'fir_polyphase_params.vh');
fid = fopen(params_path, 'w');
assert(fid ~= -1, 'Failed to write fir_polyphase_params.vh.');
cleanup0 = onCleanup(@() fclose(fid));
fprintf(fid, '`ifndef FIR_POLYPHASE_PARAMS_VH\n');
fprintf(fid, '`define FIR_POLYPHASE_PARAMS_VH\n');
fprintf(fid, '`define FIR_L2_E0_TAPS %d\n', numel(branches{1}.full));
fprintf(fid, '`define FIR_L2_E0_UNIQ %d\n', numel(branches{1}.uniq));
fprintf(fid, '`define FIR_L2_E1_TAPS %d\n', numel(branches{2}.full));
fprintf(fid, '`define FIR_L2_E1_UNIQ %d\n', numel(branches{2}.uniq));
fprintf(fid, '`define FIR_L3_E0_TAPS %d\n', numel(branches{3}.full));
fprintf(fid, '`define FIR_L3_E0_UNIQ %d\n', numel(branches{3}.uniq));
fprintf(fid, '`define FIR_L3_E1_TAPS %d\n', numel(branches{4}.full));
fprintf(fid, '`define FIR_L3_E1_UNIQ %d\n', numel(branches{4}.uniq));
fprintf(fid, '`define FIR_L3_E2_TAPS %d\n', numel(branches{5}.full));
fprintf(fid, '`define FIR_L3_E2_UNIQ %d\n', numel(branches{5}.uniq));
fprintf(fid, '`endif\n');

coeff_path = fullfile(rtl_dir, 'fir_polyphase_coeffs.vh');
fid = fopen(coeff_path, 'w');
assert(fid ~= -1, 'Failed to write fir_polyphase_coeffs.vh.');
cleanup1 = onCleanup(@() fclose(fid));
fprintf(fid, '`ifndef FIR_POLYPHASE_COEFFS_VH\n');
fprintf(fid, '`define FIR_POLYPHASE_COEFFS_VH\n\n');
local_write_polyphase_function(fid, 'fir_l2_e0_coeff_at', branches{1}.uniq, wcoef);
local_write_polyphase_function(fid, 'fir_l2_e1_coeff_at', branches{2}.uniq, wcoef);
local_write_polyphase_function(fid, 'fir_l3_e0_coeff_at', branches{3}.full, wcoef);
local_write_polyphase_function(fid, 'fir_l3_e1_coeff_at', branches{4}.uniq, wcoef);
local_write_polyphase_function(fid, 'fir_l3_e2_coeff_at', branches{5}.full, wcoef);
fprintf(fid, '`endif\n');
end

function local_write_polyphase_function(fid, func_name, values, width)
fprintf(fid, 'function automatic signed [`FIR_WCOEF-1:0] %s;\n', func_name);
fprintf(fid, '  input integer idx;\n');
fprintf(fid, '  begin\n');
fprintf(fid, '    case (idx)\n');
for idx = 1:numel(values)
    value = values(idx);
    if value < 0
        fprintf(fid, '      %d: %s = -%d''sd%d;\n', idx - 1, func_name, width, abs(value));
    else
        fprintf(fid, '      %d: %s = %d''sd%d;\n', idx - 1, func_name, width, value);
    end
end
fprintf(fid, '      default: %s = %d''sd0;\n', func_name, width);
fprintf(fid, '    endcase\n');
fprintf(fid, '  end\n');
fprintf(fid, 'endfunction\n\n');
end
