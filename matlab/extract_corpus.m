function extract_corpus()
%EXTRACT_CORPUS Export every discovered source model, including explicit failures.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
roots = {'flowrepair', 'cocosim', 'slnet_sample', 'mars'};
records = {};
for ri = 1:numel(roots)
    source = roots{ri};
    base = fullfile(pwd, '_external', source);
    if strcmp(source, 'flowrepair')
        base = fullfile(base, 'ModelsWithRealFaults');
    elseif strcmp(source, 'cocosim')
        base = fullfile(base, 'stateflow');
    elseif strcmp(source, 'mars')
        base = fullfile(base, 'Examples', 'Stateflow');
    end
    files = [dir(fullfile(base, '**', '*.slx')); dir(fullfile(base, '**', '*.mdl'))];
    for fi = 1:numel(files)
        path = fullfile(files(fi).folder, files(fi).name);
        record = struct('dataset', source, 'source', strrep(path(numel(base)+2:end), '\', '/'), ...
            'status', 'pending', 'charts', {{}}, 'error_id', '', 'error', '');
        fprintf('SOURCE %s %s\n', source, record.source);
        try
            % MException: load_system may reject missing dependencies, incompatible
            % releases or invalid source models; snapshot properties may be unavailable.
            % Each failure is a dataset result, never counted as successful conversion.
            bdclose('all');
            handle = load_system(path);
            model = get_param(handle, 'Name');
            root = sfroot;
            machine = root.find('-isa', 'Stateflow.Machine', 'Name', model);
            if ~isempty(machine)
                charts = machine.find('-isa', 'Stateflow.Chart');
                record.charts = arrayfun(@import_snapshot, charts, 'UniformOutput', false);
            end
            record.status = 'extracted';
        catch failure
            record.status = 'extraction_error';
            record.error_id = failure.identifier;
            record.error = failure.message;
            record.error_stack = failure.stack;
        end
        records{end+1} = record; %#ok<AGROW>
        write_json('artifacts/corpus-source.json', struct('matlab_release', version('-release'), 'models', {records}));
    end
end
% A small chart without unsupported actions keeps the conversion path testable
% even when an external dataset consists entirely of out-of-scope models.
model = create_controller('import_canary');
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
active = chart.find('-isa', 'Stateflow.State', 'Name', 'Active');
active.LabelString = sprintf('Active\nentry: y = 10;\nexit: y = -10;');
record = struct('dataset', 'synthetic', 'source', 'import_canary.slx', 'status', 'extracted', ...
    'charts', {{import_snapshot(chart)}}, 'error_id', '', 'error', '');
records{end+1} = record;
write_json('artifacts/corpus-source.json', struct('matlab_release', version('-release'), 'models', {records}));
assert(numel(records) > 1, 'Experiment:EmptyCorpus', 'No external models discovered.');
end

function result = import_snapshot(chart)
result = snapshot_chart(chart);
result.junction_count = numel(chart.find('-isa', 'Stateflow.Junction'));
result.event_count = numel(chart.find('-isa', 'Stateflow.Event'));
result.function_count = numel(chart.find('-isa', 'Stateflow.EMFunction')) + ...
    numel(chart.find('-isa', 'Stateflow.Function'));
result.truth_table_count = numel(chart.find('-isa', 'Stateflow.TruthTable'));
result.chart_class = class(chart);
states = chart.find('-isa', 'Stateflow.State');
for index = 1:numel(result.states)
    state = states([states.SSIdNumber] == result.states(index).ssid);
    parent = state.getParent;
    result.states(index).parent_ssid = [];
    if isa(parent, 'Stateflow.State')
        result.states(index).parent_ssid = parent.SSIdNumber;
    end
end
data = chart.find('-isa', 'Stateflow.Data');
for index = 1:numel(result.data)
    item = data([data.SSIdNumber] == result.data(index).ssid);
    result.data(index).initial = item.Props.InitialValue;
    result.data(index).size = item.Props.Array.Size;
    result.data(index).parent_class = class(item.getParent);
end
end
