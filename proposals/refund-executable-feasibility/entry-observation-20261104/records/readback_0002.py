"""Check saved observer records and identities; this is not a semantic checker."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
EXE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
EXPECTED = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT / 'readback.json').exists()
assert sha(EXE) == EXPECTED
attempts = {}
for name in ['attempt-0001', 'attempt-0002', 'attempt-0003']:
    directory = OUT / name
    record = json.loads((directory / 'command.json').read_text())
    assert record['actual_exit'] == -10
    assert record['executable_sha256'] == EXPECTED
    assert record['executable_unchanged'] is True
    assert record['end_to_end'] is False
    assert sha(directory / 'entry_observer.py') == record['observer_sha256']
    assert sha(directory / 'commands.lldb') == record['commands_sha256']
    assert sha(Path(record['argv'][0])) == record['debugger_sha256']
    log = (directory / 'debugger.log').read_text()
    if name == 'attempt-0001':
        diagnosis = json.loads((directory / 'diagnostic-summary.json').read_text())
        assert any('ObjectFileMachO::ParseSymtab' in frame['symbol']
                   for frame in diagnosis['faulting_thread_frames'])
        for item in diagnosis['raw_records']:
            assert sha(Path(item['copy'])) == item['sha256']
    else:
        assert 'ObjectFileMachO::ParseSymtab' in log
    assert 'FORGE_ENTRY_OBSERVATION_COMPLETE' not in log
    assert not (directory / 'entry-observation.json').exists()
    assert not (directory / 'process-exit.json').exists()
    attempts[name] = {
        'actual_debugger_exit': record['actual_exit'],
        'command_sha256': sha(directory / 'command.json'),
        'debugger_log_sha256': sha(directory / 'debugger.log'),
        'entry_state': 'NOT_ESTABLISHED',
        'target_exit': 'NOT_RECORDED',
    }
probe = json.loads((OUT / 'target-open-0002/command.json').read_text())
assert probe['actual_exit'] == 0 and probe['native_execution'] == 'NOT RUN'
baseline = json.loads((ROOT / 'results/refund-caller-2026-11-04/attempt-0001/original-inputs-postflight.json').read_text())
for name, expected in baseline['input_sha256'].items():
    assert sha(ROOT / name) == expected, name
assert sha(ROOT / 'FORGE_MISSION.md') == '7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c'
query = subprocess.run(['ps', '-axo', 'pid=,ppid=,stat=,comm='], capture_output=True, text=True)
assert query.returncode == 0
matching = [line for line in query.stdout.splitlines() if str(EXE) in line]
(OUT / 'process-presence-after-0003.json').write_text(json.dumps({
    'argv': ['ps', '-axo', 'pid=,ppid=,stat=,comm='],
    'actual_exit': query.returncode, 'matching_exact_target_processes': matching,
    'target_exit': 'NOT_RECORDED', 'end_to_end': False,
}, indent=2) + '\n')
behavior = ROOT / 'results/refund-arm8-compile-2026-11-04/attempt-0001/behavior-0001'
live = subprocess.run(['ps', '-p', '47209,47239', '-o', 'pid=,ppid=,etime=,stat=,comm='], capture_output=True, text=True)
state = {'argv': ['ps', '-p', '47209,47239', '-o', 'pid=,ppid=,etime=,stat=,comm='],
         'query_exit': live.returncode, 'stdout': live.stdout,
         'terminal_record_present': (behavior / 'command.json').exists(),
         'end_to_end': False}
if state['terminal_record_present']:
    state['terminal_record'] = json.loads((behavior / 'command.json').read_text())
else:
    state['proof_exit'] = 'IN_PROGRESS' if live.returncode == 0 else 'NOT_RECORDED'
(OUT / 'behavior-process-checkpoint.json').write_text(json.dumps(state, indent=2) + '\n')
(OUT / 'behavior-log-tail.txt').write_text('\n'.join((behavior / 'build.log').read_text().splitlines()[-16:]) + '\n')
result = {'actual_exit': 0, 'attempts': attempts, 'target_open_probe_exit': 0,
          'executable_sha256': sha(EXE), 'protected_input_count': len(baseline['input_sha256']),
          'protected_input_changes': [], 'mission_unchanged': True,
          'new_proof_or_observation': False, 'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
