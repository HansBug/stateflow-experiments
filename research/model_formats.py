"""Inspect downloaded model containers; this is not a Stateflow semantic parser."""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
from zipfile import ZipFile, is_zipfile
import xml.etree.ElementTree as ET


def xml_charts(parts):
    charts = []
    for name, content in parts:
        if not name.endswith('.xml'):
            continue
        root = ET.fromstring(content)
        for chart in root.iter('chart'):
            if chart.get('Ref') is not None:
                continue
            properties = {p.get('Name'): p.text for p in chart.findall('P')}
            labels = [p.text or '' for p in chart.iter('P') if p.get('Name') == 'labelString']
            charts.append({
                'part': name, 'id': chart.get('id'), 'name': properties.get('name'),
                'counts': {kind: sum(1 for _ in chart.iter(kind))
                           for kind in ('state', 'transition', 'junction', 'data', 'event')},
                'and_state_count': sum(p.text == 'AND_STATE' for p in chart.iter('P')),
                'time_label_count': sum(bool(re.search(r'\b(after|before|at|every|temporalCount)\s*\(', label)) for label in labels),
                'chart_properties': {k: v for k, v in properties.items()
                                     if k in ('decomposition', 'updateMethod', 'sampleTime', 'actionLanguage')},
            })
    return charts


def inspect_bytes(raw):
    if is_zipfile(io.BytesIO(raw)):
        with ZipFile(io.BytesIO(raw)) as archive:
            charts = xml_charts((name, archive.read(name)) for name in archive.namelist() if name.endswith('.xml'))
            return {'format': 'zip-xml', 'parts': archive.namelist(), 'charts': charts}
    text = raw.decode('utf-8-sig')
    if text.startswith('# MathWorks OPC Text Package'):
        text = re.split(r'^__MWOPC_PACKAGE_END__\s*$', text, maxsplit=1, flags=re.M)[0]
        sections = re.split(r'^__MWOPC_PART_BEGIN__ ([^\r\n]+)\r?\n', text, flags=re.M)
        parts = list(zip(sections[1::2], sections[2::2]))
        return {'format': 'opc-text-xml', 'parts': [name for name, _ in parts], 'charts': xml_charts(parts)}
    if re.search(r'^\s*(Model|Library)\s*\{', text):
        # ponytail: declaration-line counts only; native MATLAB must resolve the classic MDL object graph.
        start = re.search(r'^Stateflow\s*\{', text, re.M)
        body = text[start.start():] if start else ''
        return {'format': 'classic-mdl-text', 'stateflow_section': start is not None,
                'declaration_line_counts': {kind: len(re.findall(r'^\s*' + kind + r'\s*\{', body, re.M))
                                            for kind in ('chart', 'state', 'transition', 'junction', 'data', 'event')},
                'note': 'Lexical screening counts, not parsed or linked Stateflow objects.'}
    raise ValueError('Unrecognized model container')


def check():
    xml = '<Stateflow><chart id="2"><P Name="name">C</P><Children><state SSID="1"/></Children></chart></Stateflow>'
    packed = io.BytesIO()
    with ZipFile(packed, 'w') as archive:
        archive.writestr('simulink/blockdiagram.xml', xml)
    zipped = inspect_bytes(packed.getvalue())
    assert zipped['charts'][0]['counts']['state'] == 1
    opc = '# MathWorks OPC Text Package\nModel {}\n__MWOPC_PART_BEGIN__ /simulink/stateflow.xml\n' + xml + '\n__MWOPC_PACKAGE_END__\n'
    assert inspect_bytes(opc.encode())['charts'][0]['name'] == 'C'
    classic = b'Model {\n}\nStateflow {\n  chart {\n  }\n  state {\n  }\n}\n'
    assert inspect_bytes(classic)['declaration_line_counts']['state'] == 1
    assert xml_charts([('ref.xml', '<Stateflow><chart Ref="chart_2"/></Stateflow>')]) == []
    print('PASS: ZIP with embedded Stateflow, OPC text, classic MDL screening, chart-reference exclusion')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', type=Path, nargs='*')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        check()
    else:
        if not args.files or args.output is None:
            parser.error('provide model files and --output, or use --check')
        rows = []
        for file in args.files:
            raw = file.read_bytes()
            rows.append({'file': file.name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), **inspect_bytes(raw)})
        args.output.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
        print('Inspected', len(rows), 'files; native load and import eligibility are not implied.')
