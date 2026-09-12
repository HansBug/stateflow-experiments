# Stateflow experiments

Reproducible, public GitHub Actions experiments for using native MathWorks
Stateflow as a source-model frontend and independent execution oracle.

This repository tests tooling access and concrete behavior. It is not a
Stateflow-to-FCSTM importer or a claim of semantic equivalence.

## Experiment contract

- Use MATLAB R2022b, Simulink, and Stateflow on an Ubuntu runner through the
  official MATLAB Actions public-project licensing path.
- Create, inspect, save, reload, simulate, mutate, and repair a deterministic,
  single-rate hierarchical chart through the official API.
- Export source element identities and concrete input/output observations.
- Exercise coverage, a Simulink Test harness, and Design Verifier test generation.
- Read public FlowRepair models from a pinned upstream checkout. Keep upstream
  models outside this repository and report provenance and observed limitations.
- Record optional code-generation licensing separately from simulation success.

Run `Stateflow experiments` with `workflow_dispatch`, or push a change. Each
MATLAB step is a separate process; artifacts are uploaded even if a step fails.
All required checks fail the workflow on an unexpected result.

## Boundaries

The intended importer domain is deterministic discrete periodic controllers with
one active hierarchical path. Successful native execution of a broader Stateflow
model does not establish that it belongs to this subset. Parallel regions,
asynchronous events/messages, continuous dynamics, and arbitrary host code need
explicit rejection by a future importer. Timing, initialization, action ordering,
numeric types, and transition priority need independent mapping tests.

Public MATLAB Actions license products automatically except transformation
products. This does not grant a local desktop/Docker license or permit MATLAB
Engine for Python under batch licensing. See the official sources below.

## Sources

- [MATLAB Actions licensing](https://github.com/matlab-actions/setup-matlab#licensing)
- [Stateflow API](https://www.mathworks.com/help/stateflow/api/overview-of-the-stateflow-api.html)
- [FlowRepair repository](https://github.com/aitorarrietamarcos/StateflowRepairTool)
- [FlowRepair paper](https://doi.org/10.1016/j.infsof.2025.108010)
- [Hype Meets Reality](https://arxiv.org/abs/2608.19347)

Original experiment scripts are MIT licensed. Third-party materials retain their
own terms. This repository does not redistribute the FlowRepair dataset.
