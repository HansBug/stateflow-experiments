"""One integration gate for source facts -> AST -> model -> semantic diagnostics."""
import copy
import json
from pathlib import Path
from convert_corpus import lower, Unsupported
from pyfcstm.dsl import parse_with_grammar_entry
from pyfcstm.model import parse_dsl_node_to_state_machine
from pyfcstm.diagnostics import inspect_model
from pyfcstm.simulate import SimulationRuntime

chart = json.loads((Path(__file__).parent / 'research/import-canary.json').read_text())
dsl, mapping = lower(chart)
ast = parse_with_grammar_entry(dsl, 'state_machine_dsl')
model = parse_dsl_node_to_state_machine(ast)
report = inspect_model(model, enable_verify=True).to_json()
assert not [d for d in report['diagnostics'] if d['severity'] == 'error']
assert len(report['states']) == 4
assert len([m for m in mapping if m['kind'] == 'transition']) == 4
runtime = SimulationRuntime(model)
runtime.cycle()
assert '.'.join(runtime.current_state.path) == 'Controller.S3'
for field, value, code in [('junction_count', 1, 'junction'), ('decomposition', 'PARALLEL_AND', 'parallel')]:
    unsupported = copy.deepcopy(chart)
    unsupported[field] = value
    try:
        lower(unsupported)
    except Unsupported as error:
        # Unsupported: deliberate source constructs outside the converter's declared subset.
        assert error.code == code
    else:
        raise AssertionError('Unsupported source construct was silently accepted')
print('PASS: native snapshot -> FCSTM AST -> model -> semantic checks -> first cycle; unsupported cases rejected')
