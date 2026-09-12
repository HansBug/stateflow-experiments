function run_dataset()
%RUN_DATASET Inspect original academic charts without changing their semantics.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
base = fullfile(pwd, '_external', 'flowrepair', 'ModelsWithRealFaults');
sources = {'door_1/Door_Model_Correct.slx', 'door_1/Door_Model_Incorrect.slx', ...
    'fridge_1/Fridge_Correct.slx', 'fridge_1/Fridge_Faulty.slx', ...
    'elevator_10/Elevator_Correct.slx', 'elevator_10/Elevator_Incorrect_after_Jorge2.slx', ...
    'pacemaker_fault1/Model1_Scenario2_NonFaulty_2020a.slx'};
records = cell(size(sources));
for index = 1:numel(sources)
    path = fullfile(base, sources{index});
    load_system(path);
    [~, model] = fileparts(path);
    root = sfroot;
    machine = root.find('-isa', 'Stateflow.Machine', 'Name', model);
    charts = machine.find('-isa', 'Stateflow.Chart');
    snapshots = arrayfun(@snapshot_chart, charts, 'UniformOutput', false);
    assert(~isempty(charts), 'Experiment:DatasetChart', 'No Stateflow chart found.');
    records{index} = struct('source', sources{index}, ...
        'solver', get_param(model, 'Solver'), 'solver_type', get_param(model, 'SolverType'), ...
        'fixed_step', get_param(model, 'FixedStep'), ...
        'continuous_integrators', numel(find_system(model, 'BlockType', 'Integrator')), ...
        'charts', {snapshots}, 'status', 'loaded-and-extracted', ...
        'import_eligibility', 'not-yet-established');
    bdclose(model);
end
write_json('artifacts/academic-models.json', struct('repository', ...
    'https://github.com/aitorarrietamarcos/StateflowRepairTool', ...
    'revision', '6c5ba07962d972d3eade2448e7212faf74e11a50', 'models', {records}));

% Use the original embedded Signal Builder test and complete plant. Only the
% output collection option changes; no chart, solver, or plant is discretized.
pair = {'Door_Model_Correct', 'Door_Model_Incorrect'};
variables = {'correct_out1', 'out1'};
observations = cell(1, 2);
for index = 1:2
    model = pair{index};
    load_system(fullfile(base, 'door_1', [model '.slx']));
    signalbuilder([model '/Signal Builder'], 'activegroup', 1);
    output = sim(model, 'ReturnWorkspaceOutputs', 'on');
    signal = output.get(variables{index});
    observations{index} = struct('model', model, 'time', signal.Time, 'output', signal.Data);
    bdclose(model);
end
assert(isequal(observations{1}.time, observations{2}.time), ...
    'Experiment:AcademicTime', 'Reference and faulty traces use different time grids.');
difference = abs(observations{1}.output - observations{2}.output);
first = find(difference > 0, 1);
assert(~isempty(first), 'Experiment:AcademicFault', 'Original Door fault was not reproduced.');
save('artifacts/door-original-traces.mat', 'observations', 'difference');
write_json('artifacts/academic-replay.json', struct('status', 'fault-reproduced', ...
    'source', 'ModelsWithRealFaults/door_1', 'test_group', 1, ...
    'sample_count', numel(difference), 'different_samples', nnz(difference), ...
    'max_absolute_difference', max(difference), 'first_difference_time', observations{1}.time(first), ...
    'import_eligibility', 'not-established: continuous plant and after(10,sec) need an explicit controller boundary'));
end
