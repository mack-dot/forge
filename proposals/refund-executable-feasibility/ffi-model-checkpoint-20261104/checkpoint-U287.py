"""Preserve a documentation checkpoint. This does not check a semantic claim."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
RAW = ROOT / 'results/refund-ffi-observation-2026-11-04'
REL = Path('proposals/refund-executable-feasibility/ffi-model-checkpoint-20261104')
PACKET = ROOT / REL
WT = Path('/private/tmp/forge-readiness-docs-20261103')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

assert not PACKET.exists()
assert not (WT / REL).exists()
assert sha(ROOT / 'FORGE_MISSION.md') == '7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c'
assert sha(ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund') == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
PACKET.mkdir(parents=True)

def copy(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    assert sha(source) == sha(dest)

for name in ['run_model_check.py', 'prepare_constructor_check.py',
             'constructor-preparation.json', 'constructor-api-correction.json',
             'constructor-environment-correction.json', 'constructor-equation-readback.json']:
    copy(RAW / name, PACKET / 'records' / name)

diagnostics = []
for case, expected in [('constructor-diagnostic', 1), ('constructor-diagnostic-0002', 1),
                       ('constructor-diagnostic-0003', 0)]:
    source = RAW / ('model-' + case)
    record = json.loads((source / 'command.json').read_text())
    assert record['actual_exit'] == expected
    assert record['source_sha256'] == sha(source / 'check.sml')
    assert not record['completion_marker'] and not record['objects']
    diagnostics.append({'case': case, 'actual_exit': expected, 'source_sha256': record['source_sha256']})
    for name in ['check.sml', 'invocation.json', 'command.json', 'stdout.log', 'stderr.log']:
        copy(source / name, PACKET / 'records' / ('model-' + case) / name)

model = RAW / 'model-positive-0002'
assert not (model / 'command.json').exists()
assert not (model / 'interruption.json').exists()
for name in ['check.sml', 'invocation.json']:
    copy(model / name, PACKET / 'records/model-positive-0002' / name)
for name in ['stdout.log', 'stderr.log']:
    (PACKET / 'records/model-positive-0002' / (name + '.snapshot')).write_bytes((model / name).read_bytes())
log = (PACKET / 'records/model-positive-0002/stdout.log.snapshot').read_text()
checked = re.findall(r'^OBSERVED_FFI_(\d+)_CHECKED$', log, re.M)
assert checked and 'OBSERVED_FFI_MODEL_CHECK_COMPLETE' not in log

prepared = RAW / 'model-positive-0003'
assert not (prepared / 'invocation.json').exists()
assert sha(prepared / 'check.sml') == '7fad635b24005ac0d7dc3a9a0b5a33e91d19f634ff1c87607e95d0f7b429ac68'
copy(prepared / 'check.sml', PACKET / 'records/model-positive-0003/check.sml')

compiler = ROOT / 'results/refund-arm8-compile-2026-11-04/attempt-0001/behavior-0001'
assert not (compiler / 'command.json').exists()
copy(compiler / 'invocation.json', PACKET / 'records/compiler/invocation.json')
(PACKET / 'records/compiler/build.log.snapshot').write_bytes((compiler / 'build.log').read_bytes())
proc = subprocess.run(['ps', '-p', '47209,47239,91808,91810', '-o', 'pid,ppid,etime,time,stat,command'], capture_output=True, text=True)
assert proc.returncode == 0
assert all(re.search(r'^\s*' + str(pid) + r'\s', proc.stdout, re.M) for pid in [47209,47239,91808,91810])
(PACKET / 'records/processes.txt').write_text(proc.stdout)

guard = {
    'actual_exit': 1,
    'reason': 'A proposed input-construction replacement required no first proof marker. The guard found that proof checking had already started and raised AssertionError.',
    'signal_sent': False, 'interruption_record_written': False,
    'replacement_proof_started': False,
    'consequence': 'Keep original model child 91810 running; do not duplicate it.',
    'end_to_end': False,
}
(PACKET / 'records/replacement-guard.json').write_text(json.dumps(guard, indent=2) + '\n')

record = {
    'actual_exit': 0, 'scope': 'Saved-record, file identity and current-process checkpoint only',
    'model_checked_equation_indices_in_snapshot': checked,
    'model_terminal_exit': None, 'compiler_terminal_exit': None,
    'constructor_diagnostics': diagnostics,
    'prepared_constructor_proof': 'NOT RUN', 'negative_controls': 'NOT RUN',
    'proof_reproduction_and_import': 'NOT RUN', 'end_to_end': False,
}
(PACKET / 'records/checkpoint.json').write_text(json.dumps(record, indent=2) + '\n')
copy(Path(__file__), PACKET / 'checkpoint-U287.py')
print(json.dumps(record, indent=2))
