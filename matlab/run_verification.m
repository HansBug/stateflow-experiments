function run_verification()
%RUN_VERIFICATION Exercise native coverage, test harnesses, and test generation.
mkdir('artifacts');
cleanup = onCleanup(@() bdclose('all'));
model = create_controller('verification_controller');
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
sltest.harness.open([model '/Controller'], 'controller_harness');
sim('controller_harness', 'StopTime', '5');
sltest.harness.close([model '/Controller'], 'controller_harness');
write_json('artifacts/harness-result.json', struct('status', 'created-and-simulated', ...
    'name', harnesses.name));
testFile = sltest.testmanager.TestFile(fullfile(pwd, 'artifacts', 'controller_tests.mldatx'));
suite = createTestSuite(testFile, 'Controller simulation');
testCase = createTestCase(suite, 'simulation', 'Native harness execution');
setProperty(testCase, 'Model', model, 'HarnessOwner', [model '/Controller'], ...
    'HarnessName', 'controller_harness');
saveToFile(testFile);
testResults = run(testCase);
write_json('artifacts/test-manager-result.json', struct('outcome', char(testResults.Outcome)));
assert(strcmp(char(testResults.Outcome), 'Passed'), ...
    'Experiment:TestManager', 'Test Manager simulation did not pass.');
sltest.testmanager.exportResults(testResults, fullfile(pwd, 'artifacts', 'test-results.mldatx'));
[licensed, message] = license('checkout', 'Simulink_Design_Verifier');
if ~licensed
    write_json('artifacts/sldv-result.json', struct('status', 'license-unavailable', ...
        'message', message, 'generated_tests_replayed', false));
    return;
end
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
runOptions = sldvruntestopts;
runOptions.coverageEnabled = true;
[outputs, generatedCoverage] = sldvruntest(model, files.DataFile, runOptions);
assert(~isempty(outputs) && ~isempty(generatedCoverage), ...
    'Experiment:GeneratedReplay', 'Generated tests were not replayed with coverage.');
cvhtml('artifacts/generated-test-coverage', generatedCoverage);
write_json('artifacts/generated-replay.json', struct('status', 'passed', ...
    'test_count', numel(outputs)));
end
