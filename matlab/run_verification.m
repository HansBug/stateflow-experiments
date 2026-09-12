function run_verification()
%RUN_VERIFICATION Exercise native coverage, test harnesses, and test generation.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
model = create_controller();
save_system(model, fullfile('artifacts', [model '.slx']));
set_param(model, 'LoadExternalInput', 'off');
coverage = cvsim(cvtest(model));
assert(~isempty(coverage), 'Experiment:Coverage', 'No coverage object returned.');
cvsave('artifacts/coverage.cvt', coverage);
cvhtml('artifacts/coverage', coverage);
write_json('artifacts/coverage-result.json', struct('status', 'passed'));
sltest.harness.create([model '/Controller'], 'Name', 'controller_harness', ...
    'Source', 'Inport', 'Sink', 'Outport', 'SaveExternally', true, ...
    'HarnessPath', fullfile(pwd, 'artifacts'));
harnesses = sltest.harness.find(model);
assert(numel(harnesses) == 1, 'Experiment:Harness', 'Harness was not created.');
write_json('artifacts/harness-result.json', struct('status', 'passed', 'name', harnesses.name));
options = sldvoptions;
options.Mode = 'TestGeneration';
options.MaxProcessTime = 60;
options.ModelCoverageObjectives = 'Decision';
options.SaveHarnessModel = 'off';
options.SaveReport = 'off';
options.OutputDir = fullfile(pwd, 'artifacts', 'sldv');
[status, files] = sldvrun(model, options, false);
write_json('artifacts/sldv-result.json', struct('status_code', status, 'files', files));
assert(status == 1, 'Experiment:SLDV', 'Design Verifier did not finish normally.');
assert(isfile(files.DataFile), 'Experiment:SLDVData', 'No generated test data.');
end
