function run_proof()
%RUN_PROOF Prove a simple invariant, falsify another, and replay its witness.
cleanup = onCleanup(@() bdclose('all'));
[licensed, message] = license('checkout', 'Simulink_Design_Verifier');
if ~licensed
    write_json('artifacts/proof-result.json', struct('status', 'license-unavailable', ...
        'message', message, 'proof_executed', false, 'witness_replayed', false));
    return;
end
model = create_controller('property_controller');
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
active = chart.find('-isa', 'Stateflow.State', 'Name', 'Active');
running = chart.find('-isa', 'Stateflow.State', 'Name', 'Running');
active.LabelString = sprintf('Active\nentry: y = 1;');
running.LabelString = 'Running';
add_block('simulink/Logic and Bit Operations/Compare To Constant', ...
    [model '/Property'], 'relop', '<=', 'const', '1');
add_block('simulink/Model Verification/Assertion', [model '/Assertion'], ...
    'stopWhenAssertionFail', 'off');
add_line(model, 'Controller/1', 'Property/1');
add_line(model, 'Property/1', 'Assertion/1');
save_system(model, fullfile('artifacts', [model '.slx']));
options = sldvoptions;
options.Mode = 'PropertyProving';
options.MaxProcessTime = 60;
options.SaveHarnessModel = 'off';
options.SaveReport = 'off';
options.OutputDir = fullfile(pwd, 'artifacts', 'proof');
[status, files] = sldvrun(model, options, false);
assert(status == 1, 'Experiment:ProofRun', 'Property proving did not complete.');
data = load(files.DataFile, 'sldvData');
statuses = {data.sldvData.Objectives.status};
write_json('artifacts/proof-result.json', struct('status_code', status, 'objectives', {statuses}));
assert(any(strcmp(statuses, 'Valid')), 'Experiment:Proof', 'No proven objective.');

set_param([model '/Property'], 'relop', '==', 'const', '0');
options.ProvingStrategy = 'FindViolation';
options.MaxViolationSteps = 10;
options.OutputDir = fullfile(pwd, 'artifacts', 'counterexample');
[status, files] = sldvrun(model, options, false);
assert(status == 1, 'Experiment:CounterexampleRun', 'Counterexample search did not complete.');
data = load(files.DataFile, 'sldvData');
statuses = {data.sldvData.Objectives.status};
write_json('artifacts/counterexample-result.json', struct('status_code', status, 'objectives', {statuses}));
assert(any(strcmp(statuses, 'Falsified')), 'Experiment:Counterexample', 'No falsified objective.');
outputs = sldvruntest(model, files.DataFile, sldvruntestopts);
violated = false;
for index = 1:numel(outputs)
    signal = outputs(index).yout.getElement(1).Values;
    violated = violated || any(signal.Data(:) ~= 0);
end
assert(violated, 'Experiment:WitnessReplay', 'Native replay did not exhibit the violation.');
write_json('artifacts/witness-replay.json', struct('status', 'violation-reproduced', ...
    'test_count', numel(outputs)));
end
