function run_codegen()
%RUN_CODEGEN Distinguish unavailable transformation licensing from build success.
cleanup = onCleanup(@() bdclose('all'));
[licensed, message] = license('checkout', 'Real-Time_Workshop');
if ~licensed
    write_json('artifacts/codegen-result.json', struct('status', 'license-unavailable', ...
        'feature', 'Real-Time_Workshop', 'message', message, 'build_executed', false));
    return;
end
model = create_controller('codegen_controller');
set_param(model, 'SystemTargetFile', 'grt.tlc', 'GenCodeOnly', 'on');
save_system(model, fullfile(pwd, 'artifacts', [model '.slx']));
slbuild(model);
generated = dir(fullfile([model '_grt_rtw'], '*.c'));
assert(~isempty(generated), 'Experiment:Codegen', 'No generated C files.');
write_json('artifacts/codegen-result.json', struct('status', 'generated-c', ...
    'build_executed', true, 'file_count', numel(generated)));
end
