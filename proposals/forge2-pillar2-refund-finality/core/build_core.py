"""Verify and compile the refund minter decision core with the pinned Dafny (Round 3 task 3). Dispatch only.

Checks: the core verifies (exit 0); two wrong cores are rejected (exit 4); dafny audit has 0 findings; then
dafny build --target js. Output under build/round3-refund-core (ignored by git). No timestamps.
"""
from pathlib import Path
import hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[3]
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']   # gate/backends/dafny.py OPTIONS
P = 'proposals/forge2-pillar2-refund-finality/core/'
out = ROOT / 'build/round3-refund-core'
out.mkdir(parents=True, exist_ok=True)
for name in ('model.js', 'model.cjs'):
    (out / name).unlink(missing_ok=True)
rows, failed = [], False
for name, args, want, needle in [
        ('core verifies', ['verify', P + 'RefundMinterCore.dfy', *OPTIONS], 0, 'verified, 0 errors'),
        ('control: core that signs everything is rejected', ['verify', P + 'fixtures/CoreSignsEverything.dfy', *OPTIONS], 4, 'postcondition could not be proved'),
        ('control: core that keeps the remaining amount is rejected', ['verify', P + 'fixtures/CoreKeepsRemaining.dfy', *OPTIONS], 4, 'postcondition could not be proved'),
        ('audit', ['audit', P + 'RefundMinterCore.dfy'], 0, '0 findings'),
        ('compile to JavaScript', ['build', P + 'RefundMinterCore.dfy', '--target', 'js', '--output', 'build/round3-refund-core/model', *OPTIONS], 0, '')]:
    run = subprocess.run([str(DAFNY), *args], cwd=ROOT, capture_output=True, text=True)
    text = run.stdout + run.stderr
    ok = run.returncode == want and needle in text
    failed = failed or not ok
    rows.append({'check': name, 'checker_exit': run.returncode, 'expected_checker_exit': want, 'result': 'PASS' if ok else 'FAIL',
                 'last_line': (run.stdout.strip().splitlines() or [''])[-1][:200]})
    print(name, '| exit', run.returncode, '|', rows[-1]['result'], '|', rows[-1]['last_line'][:110], flush=True)
record = {'rows': rows, 'end_to_end': False, 'scenario_exit': 1 if failed else 0,
          'sources': {f: hashlib.sha256((ROOT / f).read_bytes()).hexdigest() for f in (P + 'RefundMinterCore.dfy', 'impl/Refund.dfy', 'spec/refund/RefundSpec.dfy')}}
if not failed and (out / 'model.js').is_file():
    module = (out / 'model.js').read_bytes() + b'\nmodule.exports = { RefundMinterCore, Refund, runtime: _dafny };\n'
    (out / 'model.cjs').write_bytes(module)
    record['module_sha256'] = hashlib.sha256(module).hexdigest()
(out / 'build-record.json').write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
raise SystemExit(1 if failed or 'module_sha256' not in record else 0)
