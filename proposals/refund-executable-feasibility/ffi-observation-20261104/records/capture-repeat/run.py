"""Observe the exact existing binary with authenticated upstream LLDB commands."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
SETUP = ROOT / 'results/refund-entry-observation-2026-11-04/upstream-observer'
PREFIX = ROOT / '.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64'
EXE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
FIXTURES = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0003/wire'
DEBUGSERVER = Path('/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/debugserver')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(EXE) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
assert json.loads((SETUP / 'verification.json').read_text())['actual_exit'] == 0
assert json.loads((SETUP / 'target-open-0001/command.json').read_text())['actual_exit'] == 0
files = json.loads((SETUP / 'extracted-files.json').read_text())
for name, record in files.items():
    assert sha(PREFIX.parent / name) == record['sha256'], name
assert sha(DEBUGSERVER) == 'fad3bed0ed81389180c4d1154e122ec86d33e758a922536cb1b95d56addb33b4'
manifest = json.loads((FIXTURES.parent / 'wire-manifest.json').read_text())
for name in ['eligible_duplicate.stdin', 'eligible_duplicate.stdout']:
    assert sha(FIXTURES / name) == manifest[name]

commands = [
    'version',
    'settings set target.inherit-env false',
    'settings set target.disable-aslr false',
    'settings set target.skip-prologue false',
    'settings set target.require-hardware-breakpoint true',
    'settings set target.env-vars LANG=C LC_ALL=C CML_HEAP_SIZE=256 CML_STACK_SIZE=256',
    'target create ' + str(EXE),
    'breakpoint set --hardware --address 0x1000040d0 --shlib refund',
    'breakpoint list --verbose',
    'process launch --stdin ' + str(FIXTURES / 'eligible_duplicate.stdin') +
    ' --stdout ' + str(OUT / 'native.stdout') + ' --stderr ' + str(OUT / 'native.stderr'),
    'process status',
    'breakpoint list --verbose',
    'settings show target.require-hardware-breakpoint',
    'register read x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'memory read --force --binary --outfile ' + str(OUT / 'loaded-code.bin') + ' --size 1 --count 130436 $pc',
    'memory read --binary --outfile ' + str(OUT / 'heap-header.bin') + ' --size 1 --count 40 $x1',
    'memory read --format hex --size 8 --count 5 $x1',
    'expression --allow-jit false -- unsigned long long $forge_bitmap = *(unsigned long long *)$x1',
    'memory read --force --binary --outfile ' + str(OUT / 'loaded-bitmaps.bin') + ' --size 1 --count 20248 $forge_bitmap',
    'memory region $pc',
    'memory region $x1',
    'memory region $x2',
    'memory region $x3',
    'memory region $forge_bitmap',
    'image list',
    'register read x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'memory read --force --binary --outfile ' + str(OUT / 'loaded-stubs.bin') + " --size 1 --count 96 '$pc-96'",
    'breakpoint delete 1',
    'expression --allow-jit false -- unsigned long long $forge_entry = $pc',
    'breakpoint set --hardware --address 0x100025170 --shlib refund',
    'breakpoint set --hardware --address 0x1000251e0 --shlib refund',
    'breakpoint set --hardware --address 0x100025260 --shlib refund',
    'breakpoint set --hardware --address 0x100025098 --shlib refund',
    'breakpoint set --hardware --address 0x100025464 --shlib refund',
    'breakpoint list --verbose',
    'process continue',
    'expression --allow-jit false -- (unsigned long long)0',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'expression --allow-jit false -- unsigned long long $forge_conf = $x0',
    'expression --allow-jit false -- unsigned long long $forge_clen = $x1',
    'expression --allow-jit false -- unsigned long long $forge_data = $x2',
    'expression --allow-jit false -- unsigned long long $forge_alen = $x3',
    'expression --allow-jit false -- unsigned long long $forge_return = $lr',
    'memory read --force --binary --outfile ' + str(OUT / 'call-00-conf-before.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-00-data-before.bin') + " $forge_data '$forge_data+$forge_alen'",
    'breakpoint set --hardware --one-shot true --address $forge_return',
    'breakpoint list --verbose',
    'process continue',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'memory read --force --binary --outfile ' + str(OUT / 'call-00-conf-after.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-00-data-after.bin') + " $forge_data '$forge_data+$forge_alen'",
    'process continue',
    'expression --allow-jit false -- (unsigned long long)1',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'expression --allow-jit false -- $forge_conf = $x0',
    'expression --allow-jit false -- $forge_clen = $x1',
    'expression --allow-jit false -- $forge_data = $x2',
    'expression --allow-jit false -- $forge_alen = $x3',
    'expression --allow-jit false -- $forge_return = $lr',
    'memory read --force --binary --outfile ' + str(OUT / 'call-01-conf-before.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-01-data-before.bin') + " $forge_data '$forge_data+$forge_alen'",
    'breakpoint set --hardware --one-shot true --address $forge_return',
    'breakpoint list --verbose',
    'process continue',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'memory read --force --binary --outfile ' + str(OUT / 'call-01-conf-after.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-01-data-after.bin') + " $forge_data '$forge_data+$forge_alen'",
    'process continue',
    'expression --allow-jit false -- (unsigned long long)2',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'expression --allow-jit false -- $forge_conf = $x0',
    'expression --allow-jit false -- $forge_clen = $x1',
    'expression --allow-jit false -- $forge_data = $x2',
    'expression --allow-jit false -- $forge_alen = $x3',
    'expression --allow-jit false -- $forge_return = $lr',
    'memory read --force --binary --outfile ' + str(OUT / 'call-02-conf-before.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-02-data-before.bin') + " $forge_data '$forge_data+$forge_alen'",
    'breakpoint set --hardware --one-shot true --address $forge_return',
    'breakpoint list --verbose',
    'process continue',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'memory read --force --binary --outfile ' + str(OUT / 'call-02-conf-after.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-02-data-after.bin') + " $forge_data '$forge_data+$forge_alen'",
    'process continue',
    'expression --allow-jit false -- (unsigned long long)3',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'expression --allow-jit false -- $forge_conf = $x0',
    'expression --allow-jit false -- $forge_clen = $x1',
    'expression --allow-jit false -- $forge_data = $x2',
    'expression --allow-jit false -- $forge_alen = $x3',
    'expression --allow-jit false -- $forge_return = $lr',
    'memory read --force --binary --outfile ' + str(OUT / 'call-03-conf-before.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-03-data-before.bin') + " $forge_data '$forge_data+$forge_alen'",
    'breakpoint set --hardware --one-shot true --address $forge_return',
    'breakpoint list --verbose',
    'process continue',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'memory read --force --binary --outfile ' + str(OUT / 'call-03-conf-after.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'call-03-data-after.bin') + " $forge_data '$forge_data+$forge_alen'",
    'process continue',
    'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr',
    'breakpoint list --verbose',
    'memory read --force --binary --outfile ' + str(OUT / 'code-before-exit.bin') + ' --size 1 --count 130436 $forge_entry',
    'process continue',
    'process status',
]
source = OUT / 'commands.lldb'
assert not source.exists()
source.write_text('\n'.join(commands) + '\n')
argv = [str(PREFIX / 'bin/lldb'), '--no-lldbinit', '--batch', '--source', str(source)]
env = os.environ.copy()
env['LLDB_DEBUGSERVER_PATH'] = str(DEBUGSERVER)
record = {'argv': argv, 'cwd': str(OUT), 'actual_exit': None,
          'debugger_sha256': sha(PREFIX / 'bin/lldb'),
          'debugger_library_sha256': sha(PREFIX / 'lib/liblldb.23.1.5.dylib'),
          'debugserver_path': str(DEBUGSERVER), 'debugserver_sha256': sha(DEBUGSERVER),
          'commands_sha256': sha(source), 'executable_sha256': sha(EXE),
          'stdin_sha256': sha(FIXTURES / 'eligible_duplicate.stdin'),
          'expected_stdout_sha256': sha(FIXTURES / 'eligible_duplicate.stdout'),
          'rebuild': 'NOT RUN', 'signing': 'NOT RUN', 'end_to_end': False}
(OUT / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
started = time.monotonic()
with (OUT / 'debugger.log').open('wb') as log:
    child = subprocess.run(argv, cwd=OUT, env=env, stdout=log, stderr=subprocess.STDOUT)
record.update(actual_exit=child.returncode, wall_seconds=time.monotonic() - started,
              executable_unchanged=sha(EXE) == record['executable_sha256'])
(OUT / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((OUT / 'debugger.log').read_text()[-6500:], flush=True)
raise SystemExit(child.returncode)
