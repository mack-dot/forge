"""Use the authenticated existing LLDB CLI; no target function calls or JIT."""
from pathlib import Path
import hashlib, json, os, subprocess, sys
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent / sys.argv[1]
OUT.mkdir(exist_ok=False)
INPUT = OUT / 'stdin-directory'
INPUT.mkdir()
PREFIX = ROOT / '.toolchain/experiments/refund-entry-lldb-23.1.5/observer/LLVM-23.1.5-macOS-ARM64'
EXE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
DEBUG = Path('/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/debugserver')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
old = json.loads((OUT.parent / 'observer-static/command.json').read_text())
assert sha(PREFIX / 'bin/lldb') == old['debugger_sha256']
assert sha(PREFIX / 'lib/liblldb.23.1.5.dylib') == old['library_sha256']
assert sha(DEBUG) == old['debugserver_sha256']
assert sha(EXE) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
registers = 'register read x0 x1 x2 x3 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 fp lr sp pc cpsr'
commands = [
    'version', 'settings set target.inherit-env false',
    'settings set target.disable-aslr false', 'settings set target.skip-prologue false',
    'settings set target.require-hardware-breakpoint true',
    'settings set target.env-vars LANG=C LC_ALL=C CML_HEAP_SIZE=256 CML_STACK_SIZE=256',
    'target create ' + str(EXE),
    'breakpoint set --hardware --address 0x100025170 --shlib refund',
    'breakpoint set --hardware --one-shot true --address 0x1000251ac --shlib refund',
    'breakpoint set --hardware --address 0x100025464 --shlib refund',
    'breakpoint list --verbose',
    'process launch --stdin ' + str(INPUT) + ' --stdout ' + str(OUT / 'native.stdout') + ' --stderr ' + str(OUT / 'native.stderr'),
    'process status', registers,
    'expression --allow-jit false -- unsigned long long $forge_conf = $x0',
    'expression --allow-jit false -- unsigned long long $forge_clen = $x1',
    'expression --allow-jit false -- unsigned long long $forge_data = $x2',
    'expression --allow-jit false -- unsigned long long $forge_alen = $x3',
    'expression --allow-jit false -- unsigned long long $forge_return = $lr',
    'memory read --force --binary --outfile ' + str(OUT / 'conf-before.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'data-before.bin') + " $forge_data '$forge_data+$forge_alen'",
    'memory read --force --binary --outfile ' + str(OUT / 'loaded-ffiread.bin') + ' --size 1 --count 112 $pc',
    'breakpoint delete 1',
    'breakpoint set --hardware --one-shot true --address $forge_return',
    'process continue', 'process status', registers,
    'process continue', 'process status', registers,
    'memory read --force --binary --outfile ' + str(OUT / 'conf-after.bin') + " $forge_conf '$forge_conf+$forge_clen'",
    'memory read --force --binary --outfile ' + str(OUT / 'data-after.bin') + " $forge_data '$forge_data+$forge_alen'",
    'process continue', 'process status', registers,
    'process continue', 'process status', 'breakpoint list --verbose',
]
(OUT / 'commands.lldb').write_text('\n'.join(commands) + '\n')
argv = [str(PREFIX / 'bin/lldb'), '--no-lldbinit', '--batch', '--source', str(OUT / 'commands.lldb')]
record = {'argv':argv,'commands_sha256':sha(OUT / 'commands.lldb'),
          'executable_sha256':sha(EXE),'debugger_sha256':sha(PREFIX / 'bin/lldb'),
          'debugserver_sha256':sha(DEBUG),'fixture':'directory opened as stdin',
          'scope':'Finite debugger observation; no universal C/OS/frame proof', 'end_to_end':False}
(OUT / 'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
with (OUT / 'debugger.log').open('wb') as log:
    child = subprocess.run(argv,cwd=OUT,env=dict(os.environ,LLDB_DEBUGSERVER_PATH=str(DEBUG)),stdout=log,stderr=subprocess.STDOUT)
record.update(actual_debugger_exit=child.returncode,executable_unchanged=sha(EXE)==record['executable_sha256'])
(OUT / 'command.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2));raise SystemExit(child.returncode)
