function root = project_root()
%PROJECT_ROOT Return repository root from the location of this utility file.

this_file = mfilename('fullpath');
utils_dir = fileparts(this_file);
matlab_dir = fileparts(utils_dir);
root = fileparts(matlab_dir);
end

