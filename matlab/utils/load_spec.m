function spec = load_spec()
%LOAD_SPEC Load the repository-wide FIR project specification.

root = project_root();
spec_file = fullfile(root, 'spec', 'spec.json');
raw = fileread(spec_file);
spec = jsondecode(raw);
end

