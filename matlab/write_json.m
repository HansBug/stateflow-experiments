function write_json(path, value)
%WRITE_JSON Save an experiment record, closing the file even on failure.
[fid, message] = fopen(path, 'w');
assert(fid >= 0, 'Experiment:FileOpen', '%s', message);
cleanup = onCleanup(@() fclose(fid));
text = jsonencode(value, 'PrettyPrint', true);
assert(fwrite(fid, text, 'char') == numel(text), ...
    'Experiment:ShortWrite', 'Failed to write the complete JSON record.');
end
