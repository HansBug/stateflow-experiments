function result = snapshot_chart(chart)
%SNAPSHOT_CHART Export source facts without assigning FCSTM execution semantics.
result = struct('path', chart.Path, 'action_language', chart.ActionLanguage, ...
    'activation', chart.ChartUpdate, 'sample_time', chart.SampleTime, ...
    'decomposition', chart.Decomposition, 'states', [], 'transitions', [], 'data', []);
states = chart.find('-isa', 'Stateflow.State');
if ~isempty(states)
    [~, order] = sort([states.SSIdNumber]);
    states = states(order);
end
for index = 1:numel(states)
    state = states(index);
    parent = state.getParent;
    result.states = [result.states, struct('ssid', state.SSIdNumber, ...
        'name', state.Name, 'path', state.Path, 'label', state.LabelString, ...
        'parent_class', class(parent), 'parent_name', parent.Name, ...
        'decomposition', state.Decomposition)]; %#ok<AGROW>
end
transitions = chart.find('-isa', 'Stateflow.Transition');
if ~isempty(transitions)
    [~, order] = sort([transitions.SSIdNumber]);
    transitions = transitions(order);
end
for index = 1:numel(transitions)
    transition = transitions(index);
    source = [];
    destination = [];
    if ~isempty(transition.Source)
        source = transition.Source.SSIdNumber;
    end
    if ~isempty(transition.Destination)
        destination = transition.Destination.SSIdNumber;
    end
    result.transitions = [result.transitions, struct('ssid', transition.SSIdNumber, ...
        'source_ssid', source, 'destination_ssid', destination, ...
        'label', transition.LabelString, 'priority', transition.ExecutionOrder)]; %#ok<AGROW>
end
data = chart.find('-isa', 'Stateflow.Data');
if ~isempty(data)
    [~, order] = sort([data.SSIdNumber]);
    data = data(order);
end
for index = 1:numel(data)
    item = data(index);
    result.data = [result.data, struct('ssid', item.SSIdNumber, ...
        'name', item.Name, 'scope', item.Scope, 'type', item.DataType)]; %#ok<AGROW>
end
end
