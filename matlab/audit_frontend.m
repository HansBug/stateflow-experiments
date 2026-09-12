function audit_frontend()
%AUDIT_FRONTEND Distinguish native compilation from importer metadata/grammar limits.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
records = {};
languages = {'MATLAB', 'C'};
labels = {sprintf('Idle\nentry: %% native MATLAB comment\ny = 0;'), ...
    sprintf('Idle\nentry: // native C comment\ny = 0;')};
for i = 1:numel(languages)
    model = create_controller(['comment_probe_' num2str(i)]);
    root = sfroot;
    chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
    chart.ActionLanguage = languages{i};
    idle = chart.find('-isa', 'Stateflow.State', 'Name', 'Idle');
    idle.LabelString = labels{i};
    record = compiled_facts(model);
    record.source = 'synthetic native comment probe';
    record.language = languages{i};
    record.label = idle.LabelString;
    records{end+1} = record; %#ok<AGROW>
end
bdclose('all');
path = fullfile(pwd, '_external', 'flowrepair', 'ModelsWithRealFaults', 'door_1', 'Door_Model_Correct.slx');
handle = load_system(path);
record = compiled_facts(get_param(handle, 'Name'));
record.source = 'flowrepair/door_1/Door_Model_Correct.slx';
records{end+1} = record;
write_json('artifacts/frontend-audit.json', struct('release', version('-release'), 'records', {records}));
assert(all(cellfun(@(r) strcmp(r.status, 'compiled'), records)), ...
    'Experiment:NativeCompileAudit', 'Inspect native compile failures in frontend-audit.json');
end

function result = compiled_facts(model)
result = struct('model', model, 'status', 'pending', 'charts', {{}}, 'error_id', '', 'error', '');
termination = onCleanup(@() feval(model, [], [], [], 'term'));
try
    % MException: native model compilation or compiled-property access can fail;
    % preserve its identifier and message rather than label it parser unsupported.
    feval(model, [], [], [], 'compile');
    root = sfroot;
    machine = root.find('-isa', 'Stateflow.Machine', 'Name', model);
    charts = machine.find('-isa', 'Stateflow.Chart');
    for i = 1:numel(charts)
        chart = charts(i);
        fact = struct('path', chart.Path, 'data', {{}}, ...
            'compiled_widths', get_param(chart.Path, 'CompiledPortWidths'), ...
            'compiled_dimensions', get_param(chart.Path, 'CompiledPortDimensions'), ...
            'compiled_types', get_param(chart.Path, 'CompiledPortDataTypes'));
        data = chart.find('-isa', 'Stateflow.Data');
        for j = 1:numel(data)
            item = data(j);
            fact.data{end+1} = struct('ssid', item.SSIdNumber, 'name', item.Name, ...
                'scope', item.Scope, 'port', item.Port, 'declared_size', item.Props.Array.Size); %#ok<AGROW>
        end
        result.charts{end+1} = fact;
    end
    result.status = 'compiled';
catch failure
    result.status = 'native_compile_error';
    result.error_id = failure.identifier;
    result.error = failure.message;
end
end
