function export_coeffs(root, final_design)
%EXPORT_COEFFS Export selected floating-point coefficients.

coeffs_dir = fullfile(root, 'coeffs');
ensure_dir(coeffs_dir);

float_csv = fullfile(coeffs_dir, 'final_float.csv');
float_txt = fullfile(coeffs_dir, 'final_float.txt');

coeffs = final_design.coeffs(:);
T = table((0:numel(coeffs)-1).', coeffs, 'VariableNames', {'index', 'coefficient'});
writetable(T, float_csv);

fid = fopen(float_txt, 'w');
assert(fid ~= -1, 'Failed to open %s for writing.', float_txt);
cleanup = onCleanup(@() fclose(fid));
for idx = 1:numel(coeffs)
    fprintf(fid, '%.18g\n', coeffs(idx));
end
end

