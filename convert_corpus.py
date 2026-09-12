"""Convert the supported native Stateflow snapshot subset through pyfcstm AST/model validation."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from source_ast import parse as parse_source, sf, SourceParserError

from pyfcstm.dsl import parse_with_grammar_entry
from pyfcstm.dsl.error import GrammarParseError
from pyfcstm.model import parse_dsl_node_to_state_machine
from pyfcstm.diagnostics import inspect_model
from pyfcstm.utils.validate import ModelValidationError


class Unsupported(ValueError):
    def __init__(self, code, detail):
        self.code = code
        super().__init__(detail)


def items(value):
    return value if isinstance(value, list) else [value]


def expression(node, names):
    if isinstance(node, sf.Var):
        if node.name not in names:
            raise Unsupported('unknown_symbol', node.name)
        return names[node.name]
    if isinstance(node, sf.AConst) and isinstance(node.value, (int, float)):
        return json.dumps(node.value)
    if isinstance(node, sf.BConst):
        return json.dumps(node.value)
    if isinstance(node, sf.RelExpr):
        return '(' + expression(node.expr1, names) + ' ' + node.op + ' ' + expression(node.expr2, names) + ')'
    if isinstance(node, (sf.OpExpr, sf.LogicExpr)):
        op = {'&&': 'and', '||': 'or', '~': 'not'}.get(node.op_name, node.op_name)
        args = [expression(arg, names) for arg in node.exprs]
        if op in ('-', 'not') and len(args) == 1:
            return '(' + op + ' ' + args[0] + ')'
        if op in ('+', '-', '*', '/', 'and', 'or') and len(args) == 2:
            return '(' + args[0] + ' ' + op + ' ' + args[1] + ')'
        raise Unsupported('operator', node.op_name)
    raise Unsupported('expression_kind', type(node).__name__)


def assignments(node, names):
    if isinstance(node, sf.Skip):
        return ''
    if isinstance(node, sf.Sequence):
        return assignments(node.cmd1, names) + ' ' + assignments(node.cmd2, names)
    if isinstance(node, sf.Assign) and isinstance(node.lname, sf.Var):
        if node.lname.name not in names:
            raise Unsupported('assignment_target', node.lname.name)
        return names[node.lname.name] + ' = ' + expression(node.expr, names) + ';'
    raise Unsupported('action_kind', type(node).__name__)


def lower(chart):
    for field, code in [('junction_count', 'junction'), ('event_count', 'event'),
                        ('function_count', 'function'), ('truth_table_count', 'truth_table')]:
        if field not in chart:
            raise Unsupported('missing_source_fact', field)
        if chart[field]:
            raise Unsupported(code, f'{field}={chart[field]}')
    if chart['decomposition'] != 'EXCLUSIVE_OR':
        raise Unsupported('parallel', chart['decomposition'])
    states = {s['ssid']: s for s in items(chart['states'])}
    if not states:
        raise Unsupported('no_states', chart['path'])
    parents = {sid: s['parent_ssid'] or None for sid, s in states.items()}
    children = {sid: [] for sid in [None, *states]}
    for sid, state in states.items():
        if state['decomposition'] != 'EXCLUSIVE_OR':
            raise Unsupported('parallel', state['name'])
        children[parents[sid]].append(sid)
    names, declarations, mapping = {}, [], []
    data = items(chart['data'])
    for index, variable in enumerate(data):
        if variable['scope'] not in ('Input', 'Output', 'Local') or variable['parent_class'] != 'Stateflow.Chart':
            raise Unsupported('data_scope', variable['name'])
        if str(variable['size']).strip() not in ('', '1', '[1]', '[1 1]'):
            raise Unsupported('data_shape', variable['name'] + ': ' + str(variable['size']))
        if variable['name'] in names:
            raise Unsupported('shadowed_data', variable['name'])
        source_type = variable['type']
        if source_type not in ('boolean', 'double', 'single', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'):
            raise Unsupported('data_type', source_type)
        names[variable['name']] = f'v{index}'
    for variable in data:
        target_type = 'float' if variable['type'] in ('double', 'single') else 'int'
        initial = expression(parse_source(variable['initial'] or '0', 'expr'), names)
        if variable['type'] == 'boolean':
            initial = {'true': '1', 'false': '0'}.get(initial, initial)
        declarations.append(f'def {target_type} {names[variable["name"]]} = {initial};')
        mapping.append({'source_ssid': variable['ssid'], 'source_name': variable['name'], 'kind': 'data', 'target': names[variable['name']], 'source_type': variable['type']})
    transitions = {sid: [] for sid in children}
    for t in sorted(items(chart['transitions']), key=lambda t: (t['priority'], t['ssid'])):
        src, dst = t['source_ssid'] or None, t['destination_ssid'] or None
        if dst not in states or (src is not None and src not in states):
            raise Unsupported('non_state_endpoint', str(t['ssid']))
        owner = parents[dst]
        if src is not None and parents[src] != owner:
            raise Unsupported('cross_hierarchy_transition', str(t['ssid']))
        label = t['label'].strip()
        # Native Stateflow represents an empty default label as '?'; the existing
        # native creation/simulation probe exercises this exact representation.
        if src is None and label == '?':
            label = ''
        parsed = parse_source(label, 'transition')
        if parsed.event is not None:
            raise Unsupported('transition_event', type(parsed.event).__name__)
        if not isinstance(parsed.cond_act, sf.Skip):
            raise Unsupported('condition_action', str(t['ssid']))
        guard = '' if parsed.cond is None else ' : if [' + expression(parsed.cond, names) + ']'
        body = assignments(parsed.tran_act, names)
        effect = ' effect { ' + body + ' }' if body else ''
        source_name = '[*]' if src is None else f'S{src}'
        transitions[owner].append((src, f'{source_name} -> S{dst}{guard}{effect};', t['ssid']))
    def target_path(sid):
        return 'Controller' if sid is None else target_path(parents[sid]) + f'.S{sid}'
    def emit(sid, indent):
        name = 'Controller' if sid is None else f'S{sid}'
        lines = [indent + f'state {name} {{']
        if sid is not None:
            state = states[sid]
            parsed = parse_source(state['label'], 'state_op')
            for action, operation in [('enter', parsed.en_op), ('during', parsed.du_op), ('exit', parsed.ex_op)]:
                if operation is None:
                    continue
                if action == 'during' and children[sid]:
                    raise Unsupported('composite_during', state['name'])
                lines.append(indent + '    ' + action + ' { ' + assignments(operation.op, names) + ' }')
            mapping.append({'kind': 'state', 'source_ssid': sid, 'source_name': state['name'], 'target': target_path(sid)})
        if children[sid] and not any(src is None for src, _, _ in transitions[sid]):
            raise Unsupported('initial_transition_count', name)
        for child in children[sid]:
            lines.extend(emit(child, indent + '    '))
        for index, (_, text, ssid) in enumerate(transitions[sid]):
            lines.append(indent + '    ' + text)
            mapping.append({'kind': 'transition', 'source_ssid': ssid, 'target_owner': target_path(sid), 'target_declaration_index': index})
        lines.append(indent + '}')
        return lines
    dsl = '\n'.join(declarations + emit(None, '')) + '\n'
    return dsl, mapping


def run(source, output):
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    for model in source['models']:
        identity = {'dataset': model['dataset'], 'source': model['source']}
        if model['status'] != 'extracted':
            rows.append({**identity, 'status': 'extraction_error', 'detail': model['error'], 'code': model['error_id']})
            continue
        if not model['charts']:
            rows.append({**identity, 'status': 'no_chart'})
        for chart in items(model['charts']):
            row = {**identity, 'chart': chart['path']}
            key = hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()[:16]
            try:
                dsl, mapping = lower(chart)
                ast = parse_with_grammar_entry(dsl, 'state_machine_dsl')
                target = parse_dsl_node_to_state_machine(ast)
                report = inspect_model(target, enable_verify=True).to_json()
                errors = [d for d in report['diagnostics'] if d['severity'] == 'error']
                row.update(status='semantic_error' if errors else 'converted', diagnostics=report['diagnostics'])
                folder = output / key
                folder.mkdir(exist_ok=True)
                (folder / 'model.fcstm').write_text(dsl)
                (folder / 'inspect.json').write_text(json.dumps(report, indent=2) + '\n')
                (folder / 'mapping.json').write_text(json.dumps({'source': row, 'elements': mapping,
                    'assumptions': ['Chart-only periodic execution profile; source scheduling/plant not translated.',
                                    'Mathematical numeric abstraction; no bit-exact or trace-equivalence claim.'],
                    'activation': chart['activation'], 'sample_time': chart['sample_time']}, indent=2) + '\n')
                row.update(artifact=key, ast_type=type(ast).__name__, model_type=type(target).__name__)
            except Unsupported as error:
                # Unsupported: lower() names source constructs outside the implemented subset.
                row.update(status='unsupported', code=error.code, detail=str(error))
            except SourceParserError as error:
                # SourceParserError: the pinned external source parser rejected a label/expression.
                row.update(status='source_parser_error', code=type(error).__name__, detail=str(error))
            except (GrammarParseError, ModelValidationError) as error:
                # GrammarParseError: generated DSL grammar failure; ModelValidationError: invalid target semantics.
                row.update(status='target_error', code=type(error).__name__, detail=str(error))
            rows.append(row)
    summary = {'source_model_files': len(source['models']), 'results': dict(Counter(r['status'] for r in rows)),
               'unsupported_first_reason': dict(Counter(r['code'] for r in rows if r['status'] == 'unsupported')),
               'by_dataset': {name: dict(Counter(r['status'] for r in rows if r['dataset'] == name)) for name in sorted({r['dataset'] for r in rows})}}
    (output / 'results.json').write_text(json.dumps({'summary': summary, 'records': rows}, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    run(json.loads(args.source.read_text()), args.output)
