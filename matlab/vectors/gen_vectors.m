addpath(genpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'utils')));

root = project_root();
addpath(genpath(fullfile(root, 'matlab')));
spec = load_spec();

floating_data = load(fullfile(root, 'data', 'floating_design.mat'));
fixed_summary = jsondecode(fileread(fullfile(root, 'data', 'fixed_design_summary.json')));
fixed_table = readtable(fullfile(root, 'data', 'fixedpoint_sweep.csv'));

row = fixed_table(fixed_table.coef_width == fixed_summary.coef_width & ...
    fixed_table.output_width == fixed_summary.output_width, :);
coeffs_q = local_parse_coeff_csv(row.coeff_csv{1});

vectors_root = fullfile(root, 'vectors');
ensure_dir(vectors_root);

cases = local_build_cases(spec);
for cidx = 1:numel(cases)
    c = cases{cidx};
    case_dir = fullfile(vectors_root, c.name);
    ensure_dir(case_dir);

    sim_result = sim_fixed_response(coeffs_q, spec, fixed_summary.coef_width, fixed_summary.output_width, c.signal);
    input_int = quantize_signed_frac(c.signal(:), spec.fixed_point.input_width, spec.fixed_point.input_frac_bits);
    local_write_memh(fullfile(case_dir, 'input_scalar.memh'), input_int, spec.fixed_point.input_width);
    local_write_memh(fullfile(case_dir, 'golden_scalar.memh'), sim_result.output_int(:), fixed_summary.output_width);

    in_l2 = pack_lanes(c.signal, 2, spec.fixed_point.input_width, spec.fixed_point.input_frac_bits);
    in_l3 = pack_lanes(c.signal, 3, spec.fixed_point.input_width, spec.fixed_point.input_frac_bits);
    out_l2 = pack_lanes(sim_result.output_float, 2, fixed_summary.output_width, spec.fixed_point.input_frac_bits);
    out_l3 = pack_lanes(sim_result.output_float, 3, fixed_summary.output_width, spec.fixed_point.input_frac_bits);

    local_write_packed_memh(fullfile(case_dir, 'input_l2.memh'), in_l2, spec.fixed_point.input_width * 2);
    local_write_packed_memh(fullfile(case_dir, 'input_l3.memh'), in_l3, spec.fixed_point.input_width * 3);
    local_write_packed_memh(fullfile(case_dir, 'golden_l2.memh'), out_l2, fixed_summary.output_width * 2);
    local_write_packed_memh(fullfile(case_dir, 'golden_l3.memh'), out_l3, fixed_summary.output_width * 3);

    meta = struct( ...
        'name', c.name, ...
        'length', numel(c.signal), ...
        'coef_width', fixed_summary.coef_width, ...
        'output_width', fixed_summary.output_width, ...
        'note', c.note ...
        );
    write_json_pretty(fullfile(case_dir, 'meta.json'), meta);
end

summary = struct( ...
    'selected_design', floating_data.final_design.design_id, ...
    'taps', floating_data.final_design.taps, ...
    'vector_cases', {cellfun(@(x) x.name, cases, 'UniformOutput', false)} ...
    );
write_json_pretty(fullfile(vectors_root, 'summary.json'), summary);

disp('Vector generation completed.');

function coeffs = local_parse_coeff_csv(csv_text)
parts = split(string(csv_text), ',');
coeffs = str2double(parts);
coeffs = coeffs(:).';
end

function cases = local_build_cases(spec)
nrand = spec.vector_generation.random_length;
nsine = spec.vector_generation.sine_length;
nmt = spec.vector_generation.multitone_length;
rng(spec.vector_generation.seed);
t_sine = (0:nsine-1).';
t_mt = (0:nmt-1).';
random_signal = 2 * rand(nrand, 1) - 1;
lane_l2 = [ ...
    0.875; -0.625; 0.5; -0.375; 0.3125; -0.25; 0.1875; -0.125; ...
    0.09375; -0.0625; 0.046875; -0.03125; 0.0234375; -0.015625; ...
    0.01171875; -0.0078125; 0.005859375];
lane_l3 = [ ...
    0.8125; -0.6875; 0.5625; -0.4375; 0.34375; -0.28125; 0.21875; -0.171875; ...
    0.140625; -0.109375; 0.0859375; -0.0703125; 0.0546875; -0.04296875; ...
    0.03515625; -0.02734375; 0.021484375; -0.017578125; 0.013671875; -0.01171875];
cases = { ...
    struct('name', 'impulse', 'note', 'Impulse response', 'signal', [1; zeros(spec.vector_generation.impulse_length - 1, 1)]), ...
    struct('name', 'step', 'note', 'Step response', 'signal', ones(spec.vector_generation.step_length, 1) * 0.8), ...
    struct('name', 'random', 'note', 'Uniform random full-scale', 'signal', random_signal), ...
    struct('name', 'random_short', 'note', '1024-sample regression subset', 'signal', random_signal(1:1024)), ...
    struct('name', 'passband_edge', 'note', 'Near passband edge sinusoid', 'signal', 0.8 * sin(pi * (spec.wp * 0.98) * t_sine)), ...
    struct('name', 'transition', 'note', 'Transition-band sinusoid', 'signal', 0.8 * sin(pi * ((spec.wp + spec.ws) / 2) * t_sine)), ...
    struct('name', 'stopband', 'note', 'Stopband sinusoid', 'signal', 0.8 * sin(pi * (spec.ws * 1.02) * t_sine)), ...
    struct('name', 'multitone', 'note', 'Passband+transition+stopband multi-tone', ...
        'signal', 0.35 * sin(pi * 0.12 * t_mt) + 0.25 * sin(pi * 0.21 * t_mt) + 0.2 * sin(pi * 0.35 * t_mt)), ...
    struct('name', 'overflow_corner', 'note', 'Alternating near-full-scale sequence', ...
        'signal', 0.98 * repmat([1; -1], ceil(nrand / 2), 1)), ...
    struct('name', 'lane_alignment_l2', 'note', 'Non-multiple-of-2 patterned sequence for lane ordering and flush checks', 'signal', lane_l2), ...
    struct('name', 'lane_alignment_l3', 'note', 'Non-multiple-of-3 patterned sequence for lane ordering and flush checks', 'signal', lane_l3) ...
    };
cases{9}.signal = cases{9}.signal(1:nrand);
end

function local_write_memh(path_str, values, width)
fid = fopen(path_str, 'w');
assert(fid ~= -1, 'Failed to write %s', path_str);
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(values)
    fprintf(fid, '%s\n', local_twos_hex(values(idx), width));
end
end

function local_write_packed_memh(path_str, packed_values, width)
fid = fopen(path_str, 'w');
assert(fid ~= -1, 'Failed to write %s', path_str);
cleanup = onCleanup(@() fclose(fid));
digits = ceil(width / 4);
for idx = 1:numel(packed_values)
    fprintf(fid, '%0*X\n', digits, packed_values(idx));
end
end

function text = local_twos_hex(value, width)
if value < 0
    value = value + 2^width;
end
digits = ceil(width / 4);
text = upper(dec2hex(value, digits));
end
