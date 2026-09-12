"""Measure the pinned CoCoSim MATLAB parser's output and syntax-error contract."""
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

PIN = 'ebb91b7dfbc52bfe5074766281fd3fb8446976c9'
directory = Path('artifacts/cocosim-parser')
directory.mkdir(parents=True, exist_ok=True)
jar = directory / 'Matlab-Parser.jar'
url = 'https://raw.githubusercontent.com/NASA-SW-VnV/CoCoSim/' + PIN + '/src/frontEnd/IR/Matlab_IR/Matlab-Parser.jar'
with urllib.request.urlopen(url) as response:
    jar.write_bytes(response.read())
rows = []
for name, code in [('assignment', 'x = 1;'), ('guard', 'y = x ~= 0;'), ('invalid', 'x = ;'),
                   ('state-label', 'Idle\nentry: x = 1;'), ('transition-label', '[x > 0] / x = 1;')]:
    file = directory / (name + '.m')
    file.write_text(code)
    result = subprocess.run(['java', '-cp', str(jar), 'cocosim.matlab2IR.EM2JSON', str(file)], capture_output=True, text=True, timeout=30)
    rows.append({'case': name, 'source': code, 'exit_code': result.returncode,
                 'stdout': result.stdout, 'stderr': result.stderr})
output = {'revision': PIN, 'jar_url': url, 'jar_sha256': hashlib.sha256(jar.read_bytes()).hexdigest(), 'results': rows}
(directory / 'observed.json').write_text(json.dumps(output, indent=2) + '\n')
assert not rows[0]['stderr'] and json.loads(rows[0]['stdout'])['statements'][0]['type'] == 'assignment'
assert rows[2]['exit_code'] == 0 and rows[2]['stderr'] and json.loads(rows[2]['stdout'])['statements']
print('Confirmed: valid MATLAB assignment AST; invalid input also returns partial AST with exit code zero.')
