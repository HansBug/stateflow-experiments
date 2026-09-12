"""Inventory source files without asserting Stateflow import eligibility."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as ET


def inventory(base):
    records = []
    for path in sorted(base.rglob('*.slx')):
        charts = []
        integrators = 0
        with ZipFile(path) as archive:
            for name in archive.namelist():
                if not name.endswith('.xml'):
                    continue
                if 'stateflow/chart' in name:
                    root = ET.fromstring(archive.read(name))
                    labels = [node.text or '' for node in root.iter('P')
                              if node.get('Name') == 'labelString']
                    charts.append({
                        'file': name,
                        'sec_or_msec_label_count': sum('sec)' in label for label in labels),
                        'and_state_count': sum(node.text == 'AND_STATE' for node in root.iter('P')),
                        'state_count': sum(1 for _ in root.iter('state')),
                    })
                if name == 'simulink/blockdiagram.xml' or '/systems/' in name:
                    root = ET.fromstring(archive.read(name))
                    integrators += sum(node.get('BlockType') == 'Integrator'
                                       for node in root.iter('Block'))
        if not charts:
            raise ValueError('Unrecognized or missing chart layout: ' + str(path))
        records.append({'source': path.relative_to(base).as_posix(),
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'charts': charts, 'integrator_blocks': integrators})
    if not records:
        raise ValueError('No SLX input files')
    return {
        'upstream': 'aitorarrietamarcos/StateflowRepairTool',
        'revision': '6c5ba07962d972d3eade2448e7212faf74e11a50',
        'method': 'Offline XML inventory. The sec) substring and Integrator block counts are screening hints, not a complete semantic classifier.',
        'file_count': len(records),
        'files_with_time_labels': sum(any(c['sec_or_msec_label_count'] for c in r['charts']) for r in records),
        'files_with_integrators': sum(r['integrator_blocks'] > 0 for r in records),
        'model_files': records,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('models', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = inventory(args.models)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print({key: result[key] for key in ('file_count', 'files_with_time_labels', 'files_with_integrators')})
