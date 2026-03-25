function b = design_filter_backend(order, method, spec, stop_weight, ap_target_db, ast_target_db)
%DESIGN_FILTER_BACKEND Design FIR taps through the Python/SciPy backend.

root = project_root();
script_path = fullfile(root, 'scripts', 'design_fir_one.py');

command = sprintf(['python "%s" --method %s --order %d --wp %.16g --ws %.16g ' ...
    '--stop-weight %.16g --ap-target %.16g --ast-target %.16g'], ...
    script_path, method, order, spec.wp, spec.ws, stop_weight, ap_target_db, ast_target_db);
[status, output] = system(command);
assert(status == 0, 'Python FIR backend failed: %s', output);

payload = jsondecode(output);
b = payload.coeffs(:).';
end

