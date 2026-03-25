function ensure_dir(path_str)
%ENSURE_DIR Create a directory if it does not already exist.

if ~exist(path_str, 'dir')
    mkdir(path_str);
end
end

