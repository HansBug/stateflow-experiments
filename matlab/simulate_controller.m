function trace = simulate_controller(model)
%SIMULATE_CONTROLLER Sample a fixed input sequence and return boundary outputs.
time = (0:5)';
values = [0; 1; 1; 0; 1; 1];
input = Simulink.SimulationInput(model);
input = input.setExternalInput([time, values]);
result = sim(input);
signal = result.yout.getElement(1).Values;
trace = struct('time', signal.Time, 'output', signal.Data, ...
    'input_time', time, 'input', values);
end
