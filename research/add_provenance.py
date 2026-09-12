"""Attach original file hashes and native-snapshot hashes after MATLAB extraction."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

path = Path(sys.argv[1])
source = json.loads(path.read_text())
subdirs = {'flowrepair': 'ModelsWithRealFaults', 'cocosim': 'stateflow',
           'slnet_sample': '', 'mars': 'Examples/Stateflow'}
commits = {}
for model in source['models']:
    dataset = model['dataset']
    native = {k: v for k, v in model.items() if k not in ('snapshot_sha256', 'sha256', 'source_revision')}
    model['snapshot_sha256'] = hashlib.sha256(json.dumps(native, sort_keys=True).encode()).hexdigest()
    if dataset == 'synthetic':
        model['sha256'] = None  # Generated in memory; the snapshot is the measured input.
        continue
    checkout = Path('_external') / dataset
    if dataset not in commits:
        commits[dataset] = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
    original = checkout / subdirs[dataset] / model['source']
    model['sha256'] = hashlib.sha256(original.read_bytes()).hexdigest()
    model['source_revision'] = commits[dataset]
source['source_revisions'] = commits
path.write_text(json.dumps(source, indent=2) + '\n')
