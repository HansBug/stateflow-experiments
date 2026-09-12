function run_semantics()
%RUN_SEMANTICS Check action ordering, activity logging, and guard priority.
cleanup = onCleanup(@() bdclose('all'));
model = create_controller();
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
idle = chart.find('-isa', 'Stateflow.State', 'Name', 'Idle');
active = chart.find('-isa', 'Stateflow.State', 'Name', 'Active');
running = chart.find('-isa', 'Stateflow.State', 'Name', 'Running');
idle.LabelString = sprintf('Idle\nentry: y = y*10+1;\nexit: y = y*10+2;');
active.LabelString = sprintf('Active\nentry: y = y*10+5;\nduring: y = y*10+7;\nexit: y = y*10+2;');
running.LabelString = sprintf('Running\nentry: y = y*10+6;\nduring: y = y*10+8;\nexit: y = y*10+9;');
transitions = chart.find('-isa', 'Stateflow.Transition');
for index = 1:numel(transitions)
    if isempty(transitions(index).Source) && transitions(index).Destination == idle
        transitions(index).LabelString = '/y = 0;';
    end
end
edge = chart.find('-isa', 'Stateflow.Transition', 'LabelString', '[u >= 1]');
edge.LabelString = '[u >= 1]{y = y*10+3;}/y = y*10+4;';
states = chart.find('-isa', 'Stateflow.State');
for index = 1:numel(states)
    states(index).LoggingInfo.DataLogging = true;
    states(index).LoggingInfo.NameMode = 'Custom';
    states(index).LoggingInfo.LoggingName = sprintf('state_%d', states(index).SSIdNumber);
end
set_param(model, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
input = Simulink.SimulationInput(model);
input = input.setExternalInput([(0:3)', [0;1;1;0]]);
input = input.setModelParameter('StopTime', '3');
output = sim(input);
observed = output.yout.getElement(1).Values;
write_json('artifacts/action-order.json', struct('time', observed.Time, ...
    'output', observed.Data));
assert(isequal(observed.Data(:), [1;132456;13245678;13245678921]), ...
    'Experiment:ActionOrder', 'Condition/exit/transition/entry/during order differs.');
activity = cell(1, output.logsout.numElements);
for index = 1:numel(activity)
    signal = output.logsout.getElement(index);
    activity{index} = struct('name', signal.Name, 'time', signal.Values.Time, ...
        'active', signal.Values.Data);
end
assert(numel(activity) == 3, 'Experiment:Activity', 'Expected all three state activity traces.');
write_json('artifacts/state-activity.json', struct('signals', {activity}));

model = create_controller();
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
idle = chart.find('-isa', 'Stateflow.State', 'Name', 'Idle');
edge = chart.find('-isa', 'Stateflow.Transition', 'LabelString', '[u >= 1]');
other = Stateflow.State(chart);
other.LabelString = sprintf('Other\nentry: y = 999;');
other.Position = [480 30 120 80];
competing = Stateflow.Transition(chart);
competing.Source = idle;
competing.Destination = other;
competing.LabelString = '[u >= 1]';
edge.ExecutionOrder = 1;
competing.ExecutionOrder = 2;
first = simulate_controller(model);
assert(first.output(2) == 11, 'Experiment:Priority', 'First eligible transition did not win.');
competing.ExecutionOrder = 1;
second = simulate_controller(model);
assert(second.output(2) == 999, 'Experiment:PriorityChange', 'Priority edit did not change the winner.');
write_json('artifacts/priority.json', struct('original', first, 'reordered', second));
write_json('artifacts/semantics-result.json', struct('status', 'passed', ...
    'checks', {{'condition-vs-transition-action', 'nested-entry-exit-during-order', ...
    'state-activity-logging', 'conflicting-guards', 'priority-edit'}}));
end
