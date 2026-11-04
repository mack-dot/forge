"""Dispatch pinned Dafny. Keep each source, raw output and actual exit separate."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
Z3 = ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'
case = sys.argv[1]
work = OUT / case
shutil.copytree(OUT / 'source', work)
source = work / 'Transport.dfy'
body = source.read_text()
if case == 'negative-charge-empty':
    line = '    requires (encodedCharge == "" <==> context.chargeId == "")\n'
    assert body.count(line) == 1
    body = body.replace(line, '')
elif case == 'negative-reason':
    clause = ('    requires SameAllowedReason(\n'
              '      if response.Candidate? then response.reason else "", encodedReason)\n')
    assert body.count(clause) == 1
    body = body.replace(clause, '')
elif case == 'negative-original-id':
    clause = '    assert ok ==> reason == response.reason;\n'
    assert body.count(clause) == 1
    body = body.replace(clause, clause +
                        '    assert ok ==> charge == context.chargeId; // Intentionally unproved.\n')
source.write_text(body)
argv = [str(DAFNY), 'verify', 'Transport.dfy', '--solver-path', str(Z3),
        '--resource-limit', '1000000', '--verification-time-limit', '0',
        '--cores', '1', '--verify-included-files', '--unicode-char=true']
with (work / 'stdout.log').open('wb') as stdout, (work / 'stderr.log').open('wb') as stderr:
    result = subprocess.run(argv, cwd=work, stdout=stdout, stderr=stderr)
record = {'argv': argv, 'cwd': str(work), 'actual_exit': result.returncode,
          'sources': {str(p.relative_to(work)): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in sorted(work.rglob('*.dfy'))},
          'tool_sha256': hashlib.sha256(DAFNY.read_bytes()).hexdigest(),
          'solver_sha256': hashlib.sha256(Z3.read_bytes()).hexdigest(),
          'scope': 'Conditional source representation transport only',
          'concrete_codec_proved': False, 'native_refund_proved': False,
          'end_to_end': False}
(work / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'case': case, 'actual_exit': result.returncode}))
print((work / 'stdout.log').read_text())
print((work / 'stderr.log').read_text())
raise SystemExit(result.returncode)
