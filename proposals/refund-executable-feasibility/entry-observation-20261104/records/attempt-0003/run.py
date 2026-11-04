"""Launch the existing exact refund file under LLDB; never sign or rebuild it."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
NATIVE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004'
EXE = NATIVE / 'native-build-0001/refund'
FIXTURES = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0003/wire'
LLDB = Path('/Applications/Xcode.app/Contents/Developer/usr/bin/lldb')
EXPECTED = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(EXE) == EXPECTED
assert json.loads((NATIVE / 'identity-0001/result.json').read_text())['actual_exit'] == 0
manifest = json.loads((FIXTURES.parent / 'wire-manifest.json').read_text())
stdin = FIXTURES / 'eligible_duplicate.stdin'
stdout = FIXTURES / 'eligible_duplicate.stdout'
assert sha(stdin) == manifest[stdin.name] and sha(stdout) == manifest[stdout.name]
commands = [
    'version',
    'settings set target.preload-symbols false',
    'settings set target.load-script-from-symbol-file false',
    'settings set target.inherit-env false',
    'settings set target.disable-aslr false',
    'settings set target.skip-prologue false',
    'settings set target.require-hardware-breakpoint true',
    'target create --no-dependents ' + str(EXE),
    'command script import ' + str(OUT / 'entry_observer.py'),
    'forge-entry-begin',
    'forge-entry-observe',
    'forge-entry-resume',
]
source = OUT / 'commands.lldb'
assert not source.exists()
source.write_text('\n'.join(commands) + '\n')
argv = [str(LLDB), '--no-lldbinit', '--batch', '--source', str(source)]
invocation = {'argv': argv, 'cwd': str(ROOT), 'actual_exit': None,
              'executable_sha256': EXPECTED, 'debugger_sha256': sha(LLDB),
              'observer_sha256': sha(OUT / 'entry_observer.py'),
              'commands_sha256': sha(source), 'stdin_sha256': sha(stdin),
              'expected_stdout_sha256': sha(stdout),
              'rebuild': 'NOT RUN', 'signing': 'NOT RUN', 'end_to_end': False}
(OUT / 'invocation.json').write_text(json.dumps(invocation, indent=2) + '\n')
started = time.monotonic()
with (OUT / 'debugger.log').open('wb') as log:
    child = subprocess.run(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
record = dict(invocation, actual_exit=child.returncode,
              wall_seconds=time.monotonic() - started,
              executable_unchanged=sha(EXE) == EXPECTED)
(OUT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((OUT / 'debugger.log').read_text(errors='replace')[-5000:], flush=True)
raise SystemExit(child.returncode)
