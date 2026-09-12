function run_persistence()
%RUN_PERSISTENCE Verify source identities and repaired behavior in a new process.
cleanup = onCleanup(@() bdclose('all'));
load_system(fullfile('artifacts', 'periodic_controller.slx'));
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', 'periodic_controller/Controller');
snapshot = snapshot_chart(chart);
saved = jsondecode(fileread('artifacts/source-model.json'));
assert(isequal(sort([snapshot.states.ssid]), sort([saved.states.ssid])));
assert(isequal(sort([snapshot.transitions.ssid]), sort([saved.transitions.ssid])));
trace = simulate_controller('periodic_controller');
assert(isequal(trace.output(:), [0;11;22;0;11;22]));
write_json('artifacts/persistence-result.json', struct('status', 'passed', ...
    'checks', {{'separate-process-load', 'stable-state-and-transition-ssids', 'saved-repair-replay'}}));
end
