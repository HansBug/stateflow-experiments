function run_core()
%RUN_CORE Assert native creation, persistence, mutation, and behavioral repair.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
write_json('artifacts/environment.json', struct('release', version('-release'), ...
    'version', version, 'products', ver, 'platform', computer));
model = create_controller();
save_system(model, fullfile('artifacts', [model '.slx']));
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
before = snapshot_chart(chart);
write_json('artifacts/source-model.json', before);
baseline = simulate_controller(model);
write_json('artifacts/baseline.json', baseline);
assert(isequal(baseline.output(:), [0; 11; 22; 0; 11; 22]), ...
    'Experiment:Behavior', 'Initialization or hierarchical action order changed.');
bdclose(model);
load_system(fullfile('artifacts', [model '.slx']));
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
assert(isequaln(before, snapshot_chart(chart)), 'Experiment:Persistence', ...
    'Source facts or session-independent element identities changed after reload.');
reloaded = simulate_controller(model);
assert(isequaln(baseline, reloaded), 'Experiment:Replay', 'Reload changed behavior.');
edge = chart.find('-isa', 'Stateflow.Transition', 'LabelString', '[u >= 1]');
assert(numel(edge) == 1);
edge.LabelString = '[u >= 2]';
faulty = simulate_controller(model);
write_json('artifacts/faulty.json', faulty);
assert(any(faulty.output(:) ~= baseline.output(:)), 'Experiment:Mutation', ...
    'The guard mutation must be observable.');
edge.LabelString = '[u >= 1]';
repaired = simulate_controller(model);
assert(isequaln(baseline, repaired), 'Experiment:Repair', 'Repair did not restore behavior.');
write_json('artifacts/repair.json', struct('transition_ssid', edge.SSIdNumber, ...
    'faulty_label', '[u >= 2]', 'repaired_label', edge.LabelString, 'trace', repaired));
save_system(model, fullfile('artifacts', [model '.slx']));
write_json('artifacts/core-result.json', struct('status', 'passed', ...
    'checks', {{'create', 'source-extraction', 'hierarchical-actions', ...
    'save-reload', 'stable-ssids', 'input-replay', 'guard-mutation', 'repair'}}));
end
