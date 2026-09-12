# Stateflow experiments

Public GitHub Actions experiments for using native MathWorks Stateflow as a
source-model frontend and independent execution oracle. No user MATLAB license
or repository license secret was supplied to these experiments.

[公开模型与文件格式调查](docs/public-models.zh.md) ·
[单向导入边界](docs/import-architecture.zh.md) ·
[Separate SysML v2 experiments](https://github.com/HansBug/sysmlv2-experiment) ·
[Public workflow runs](https://github.com/HansBug/stateflow-experiments/actions)

This is an experiment repository. It does not implement a Stateflow-to-FCSTM
importer or establish semantic equivalence for the Stateflow language.

## Observed capabilities

Environment: MATLAB **R2022b**, Ubuntu 22.04, official MATLAB Actions v3.
The current experiment revision is `add4a279d6b641d249ee3e89232bf9f4eada425d`.
Results below describe concrete probes, not blanket product compatibility.
[Validated workflow run](https://github.com/HansBug/stateflow-experiments/actions/runs/34692475531) ·
[Checked-in result summary](research/stateflow-observed.json).

| Workflow | Observed result | Evidence |
|---|---|---|
| Create, inspect, simulate, save and reload a hierarchical chart | Passed | `core-result.json`, `source-model.json`, `baseline.json` |
| Mutate a guard, observe a fault, repair it and replay | Passed | `faulty.json`, `repair.json` |
| Reopen the saved repair in a separate MATLAB process; retain SSIDs | Passed | `persistence-result.json` |
| Condition/transition actions, hierarchical entry/exit/during ordering | Passed | `action-order.json`, `semantics-result.json` |
| State activity logging; conflicting guards and priority edits | Passed | `state-activity.json`, `priority.json` |
| Native coverage collection and HTML report | Passed | `coverage-result.json`, coverage reports |
| External harness creation and simulation | Passed | `harness-result.json` |
| Simulink Test Manager simulation smoke test | Passed | `test-manager-result.json`, `test-results.mldatx` |
| Load and inspect seven original FlowRepair model files | Passed | `academic-models.json` |
| Replay the original Door correct/faulty pair | Fault reproduced | `academic-replay.json`, `door-original-traces.mat` |
| Apply the known Door source/priority correction and replay a saved candidate | Reference trace restored | `academic-repair.json` |
| SLDV test generation, property proving and generated witness replay | Blocked by licensing in this environment | `sldv-result.json`, `proof-result.json`; see licensing below |
| Simulink Coder C generation | Blocked by licensing in this environment | `codegen-result.json` |

The original Door replay produced **30,001 samples**, **15,995 differing samples**,
and a first difference at **14.006 seconds**. It uses the embedded Signal Builder
scenario and the full original plant, with the original solver and timing.
The separate known-reference repair probe edits transition SSID 16's source and
priority, saves a candidate, and checks its trace against the correct model.
That probe is an API smoke test supplied with the correct-model difference; it
is not an automatic repair algorithm or evidence of repair generalization.

## Run and inspect

Run `Stateflow experiments` with `workflow_dispatch`, or push a change. Each
MATLAB step is a separate process. The workflow uploads an artifact named
`stateflow-R2022b-<attempt>` containing JSON results, traces, reports, and the
synthetic models. Third-party source/candidate model files remain in the pinned
external checkout and are not included in the uploaded artifacts.

```bash
gh workflow run stateflow.yml --repo HansBug/stateflow-experiments
gh run list --repo HansBug/stateflow-experiments
gh run download RUN_ID --repo HansBug/stateflow-experiments --dir evidence
```

Required behavioral assertions fail the workflow on a mismatch. Optional
license probes explicitly report `license-unavailable`; a green workflow does
not mean that those blocked analysis or generation operations ran. The SLDV
replay/proof and C-generation branches remain unvalidated past their licensing
boundaries. Test Manager currently exercises simulation infrastructure, and
coverage collection does not claim complete decision or MC/DC coverage.
The Test Manager process also emitted AWT `HeadlessException` messages during
teardown while returning a passed test result and exit code zero. This run
validates batch execution and exported results; interactive GUI use was not tested.

## Licensing findings

[MATLAB Actions documentation](https://github.com/matlab-actions/setup-matlab#licensing)
states that public projects automatically receive product licenses except for
transformation products. Installation itself succeeded for Stateflow, Simulink
Test, Coverage, Design Verifier and Coder, including their dependencies.

Actual R2022b execution established a narrower usable set: simulation, coverage
and Test Manager work; SLDV's model-representation stage reported
`Unable to check out the Simulink Design Verifier license which is needed to translate design`.
The Coder probe reported a missing `Real-Time_Workshop` license. The failed native
SLDV attempts are preserved in
[run 34691938079](https://github.com/HansBug/stateflow-experiments/actions/runs/34691938079).
These findings are about the tested environment, not every MATLAB release or
institutional license configuration.

This route does not provide a local desktop/Docker license. MATLAB batch
licensing does not support MATLAB Engine APIs for Python, so file-based batch
execution is the tested integration approach. The public batch-token request
page stated that new requests were not being accepted when checked on
2026-09-12. Optional licensed workflows can be revisited when access is available.

## Import and dataset boundaries

Current scope is **one-way Stateflow → FCSTM**, with source mappings for later
diagnosis and replay. Reverse conversion and source repair are outside this phase.
The [public model survey](docs/public-models.zh.md) adds FlowRepair, CoCoSim/GPCA,
SLNET, and MathWorks application sources, with actual file-layout observations.

The intended importer domain is deterministic discrete periodic controllers with
one active hierarchical path. Parallel regions, asynchronous events/messages,
continuous internal dynamics, arbitrary host code, and unsupported time/numeric
semantics require explicit handling or rejection. A native model loading and
running does not establish import eligibility.

The fixed FlowRepair checkout is
`6c5ba07962d972d3eade2448e7212faf74e11a50`. The offline XML inventory records
74 SLX files: 72 contain `sec)` label fragments and 5 contain Integrator blocks.
These are screening hints. Files include correct models and fault variants;
they are not 74 independent systems. All seven charts inspected natively have
inherited activation/sample settings. The Door model includes `after(10,sec)`
and a continuous plant, so its controller boundary remains to be established.

Reproduce the inventory with:

```bash
python research/flowrepair_inventory.py \
  _external/flowrepair/ModelsWithRealFaults research/flowrepair-inventory.json
```

The independent [SysML v2 experiment repository](https://github.com/HansBug/sysmlv2-experiment) successfully reuses
the official Pilot workspace to validate models, link references across
resources, inspect typed state/transition elements and source spans, and reject
an unresolved type. It does not provide a SysML state-machine execution oracle
or a complete FCSTM importer.

## Sources

- [MATLAB Actions licensing](https://github.com/matlab-actions/setup-matlab#licensing)
- [Batch licensing limitations](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/alternates/non-interactive/MATLAB-BATCH.md#limitations)
- [Batch token availability](https://www.mathworks.com/support/batch-tokens.html)
- [Stateflow API](https://www.mathworks.com/help/stateflow/api/overview-of-the-stateflow-api.html)
- [FlowRepair repository](https://github.com/aitorarrietamarcos/StateflowRepairTool)
- [FlowRepair paper](https://doi.org/10.1016/j.infsof.2025.108010)
- [Hype Meets Reality](https://arxiv.org/abs/2608.19347)
- [Official SysML v2 Pilot](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation)

Original experiment scripts are MIT licensed. Third-party materials retain their
own terms. This repository does not redistribute the FlowRepair dataset.
