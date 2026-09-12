function model = create_controller(model)
%CREATE_CONTROLLER Build a single-rate hierarchical chart with ordered actions.
if nargin == 0
    model = 'periodic_controller';
end
bdclose('all');
load_system('sflib');
new_system(model);
set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '1', 'StartTime', '0', 'StopTime', '5', ...
    'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset', ...
    'ReturnWorkspaceOutputs', 'on');
add_block('simulink/Sources/In1', [model '/u'], 'SampleTime', '1');
add_block('sflib/Chart', [model '/Controller']);
add_block('simulink/Sinks/Out1', [model '/y']);
root = sfroot;
chart = root.find('-isa', 'Stateflow.Chart', 'Path', [model '/Controller']);
chart.ActionLanguage = 'MATLAB';
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '1';
input = Stateflow.Data(chart);
input.Name = 'u';
input.Scope = 'Input';
input.DataType = 'double';
input.Props.Array.Size = '1';
output = Stateflow.Data(chart);
output.Name = 'y';
output.Scope = 'Output';
output.DataType = 'double';
output.Props.Array.Size = '1';
idle = Stateflow.State(chart);
idle.Position = [30 30 100 80];
idle.LabelString = sprintf('Idle\nentry: y = 0;');
active = Stateflow.State(chart);
active.Position = [200 30 220 220];
active.LabelString = sprintf('Active\nentry: y = 10;\nduring: y = y + 10;\nexit: y = -10;');
running = Stateflow.State(active);
running.Position = [240 120 130 80];
running.LabelString = sprintf('Running\nentry: y = y + 1;\nduring: y = y + 1;\nexit: y = y + 100;');
initial = Stateflow.Transition(chart);
initial.Destination = idle;
initial.DestinationOClock = 0;
initial.SourceEndpoint = [80 0];
initial.MidPoint = [80 15];
initial.LabelString = '';
nested = Stateflow.Transition(active);
nested.Destination = running;
nested.DestinationOClock = 0;
nested.SourceEndpoint = [300 90];
nested.MidPoint = [302 105];
nested.LabelString = '';
assert(nested.getParent == active, 'Experiment:DefaultParent', ...
    'Default transition geometry must remain inside the containing state.');
enter = Stateflow.Transition(chart);
enter.Source = idle;
enter.Destination = active;
enter.LabelString = '[u >= 1]';
leave = Stateflow.Transition(chart);
leave.Source = active;
leave.Destination = idle;
leave.LabelString = '[u < 1]';
add_line(model, 'u/1', 'Controller/1');
add_line(model, 'Controller/1', 'y/1');
end
