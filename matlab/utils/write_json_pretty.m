function write_json_pretty(path_str, data)
%WRITE_JSON_PRETTY Write JSON data with deterministic formatting.

json_text = jsonencode(data, 'PrettyPrint', true);
fid = fopen(path_str, 'w');
assert(fid ~= -1, 'Failed to open %s for writing.', path_str);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', json_text);
end

