"""Dispatch the existing pinned Rocq compiler; no new checker or admission."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path('/Users/mackianni/forge')
HERE = Path(__file__).resolve().parent
case = sys.argv[1]
assert case in ['positive', 'negative', 'audit']
source = HERE / case / {'positive': 'Behavior.v', 'negative': 'WrongGcd.v', 'audit': 'Audit.v'}[case]
record = HERE / (case + '-command.json')
assert not record.exists()
old = ROOT / 'results/runtime-process-prefix-2026-11-03/attempt-0002/positive-command.json'
prior = json.loads(old.read_text())
assert prior['actual_exit'] == 0
argv = prior['argv']
cmd = argv[:argv.index('--mount')]
cmd[cmd.index('--name') + 1] = 'forge-vertical-slice-' + case + '-20261103-0001'
for i, arg in enumerate(argv):
    if arg != '--mount':
        continue
    mount = argv[i + 1]
    if 'target=/trial' in mount:
        continue
    assert mount.endswith(',readonly')
    cmd += ['--mount', mount]
if case != 'positive':
    cmd += ['--mount', 'type=bind,source=' + str(HERE / 'positive') + ',target=/behavior,readonly']
cmd += ['--mount', 'type=bind,source=' + str(source.parent) + ',target=/trial', '-w', '/trial']
image_index = argv.index('rocq') - 1
cmd += argv[image_index:image_index + 3]
flags = argv[image_index + 3:-4]
assert argv[-4:-1] == ['-Q', '/trial', 'ForgeProcessPrefix']
cmd += flags
if case != 'positive':
    cmd += ['-Q', '/behavior', 'ForgeSlice']
cmd += ['-Q', '/trial', {'positive': 'ForgeSlice', 'negative': 'ForgeSliceNegative', 'audit': 'ForgeSliceAudit'}[case], '/trial/' + source.name]
start = time.monotonic()
with (HERE / (case + '.log')).open('wb') as log:
    proc = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT)
result = {'argv': cmd, 'actual_exit': proc.returncode,
          'wall_seconds': time.monotonic() - start,
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'end_to_end': False, 'accepted_claim': False,
          'independent_recursive_kernel': 'NOT RUN'}
record.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
raise SystemExit(proc.returncode)
