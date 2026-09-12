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
        'solver', get_param(model, 'Solver'), 'fixed_step', get_param(model, 'FixedStep'), ...
        'charts', {snapshots}, 'status', 'loaded-and-extracted', ...
        'import_eligibility', 'not-yet-established');
    bdclose(model);
end
write_json('artifacts/academic-models.json', struct('repository', ...
    'https://github.com/aitorarrietamarcos/StateflowRepairTool', ...
    'revision', '6c5ba07962d972d3eade2448e7212faf74e11a50', 'models', {records}));
end
