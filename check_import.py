"""One integration gate for source facts -> AST -> model -> semantic diagnostics."""
import copy
import json
from pathlib import Path
from convert_corpus import lower, Unsupported
from source_ast import parse, sf, SourceParserError
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
for spelling in ('~=', '<>'):
    guard = parse('[u ' + spelling + ' 0]', 'transition').cond
    assert isinstance(guard, sf.RelExpr) and guard.op == '!='
state = parse('Idle/\nen: y = 1;', 'state_op')
assert isinstance(state.en_op.op, sf.Assign)
try:
    parse('Idle\ny = 1;', 'state_op')
except SourceParserError:
    # SourceParserError: the upstream transformer would drop this unlabelled action.
    pass
else:
    raise AssertionError('Unlabelled action was silently lost')
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
