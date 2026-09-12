"""Test all native labels before converter gates, including upstream/adapter differences."""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_corpus import items
from source_ast import parse, SourceParserError
from lark.exceptions import UnexpectedInput
from ss2hcsp.matlab.parser import state_op_parser, transition_parser


def upstream_error(label, kind):
    try:
        (state_op_parser if kind == 'state_op' else transition_parser).parse(label)
    except (UnexpectedInput, TypeError, ValueError, AssertionError) as error:
        # UnexpectedInput: upstream grammar rejection; TypeError/AssertionError:
        # upstream transformer rejects AST shape; ValueError: literal conversion.
        return type(error).__name__ + ': ' + str(error)
    return None


def compare(label, kind):
    raw_error = upstream_error(label, kind)
    try:
        parse(label, kind)
    except SourceParserError as error:
        # SourceParserError: the checked adapter reports a grammar/transformer rejection.
        return {'status': 'both_reject' if raw_error else 'adapter_only_reject',
                'label': label, 'detail': str(error), 'upstream_error': raw_error}
    return {'status': 'adapter_only_accept' if raw_error else 'both_accept'}


def audit(source):
    rows = []
    for model in source['models']:
        if model['status'] != 'extracted':
            continue
        for chart in items(model['charts']):
            labels = [('state_op', state['label'], state['ssid']) for state in items(chart['states'])]
            labels += [('transition', '' if not edge['source_ssid'] and edge['label'].strip() == '?' else edge['label'], edge['ssid'])
                       for edge in items(chart['transitions'])]
            for kind, label, ssid in labels:
                row = {'dataset': model['dataset'], 'source': model['source'], 'chart': chart['path'],
                       'ssid': ssid, 'kind': kind, 'language': chart['action_language']}
                row.update(compare(label, kind))
                rows.append(row)
    summary = {'labels': len(rows), 'results': dict(Counter(r['status'] for r in rows)),
               'by_language': {lang: dict(Counter(r['status'] for r in rows if r['language'] == lang))
                               for lang in sorted({r['language'] for r in rows})}}
    return {'summary': summary, 'records': rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--native', type=Path, help='Optional audit_frontend.m output for native/parser comparison')
    args = parser.parse_args()
    result = audit(json.loads(args.source.read_text(encoding='utf-8')))
    if args.native:
        native = json.loads(args.native.read_text(encoding='utf-8'))
        for record in native['records']:
            assert record['status'] == 'compiled', record
            if 'label' in record:
                record['label_comparison'] = compare(record['label'], 'state_op')
                assert record['label_comparison']['status'] == 'both_reject', 'Revisit the measured comment limitation'
        result['native_probes'] = native
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result['summary'], indent=2))
