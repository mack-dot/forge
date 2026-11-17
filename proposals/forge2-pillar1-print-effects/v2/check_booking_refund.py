"""Step 1C (Round 2, U423): do the booking and refund gates need their own non-printing caller? Measured, nothing applied.

In a scratch copy of spec/, impl/, tests/ and gate/, the pinned Dafny verifies the gates' real file sets with and without
--track-print-effects, for the approved implementations and for mutants whose main method prints and carries {:print}.
Dispatch only. Output: results/round2-print-booking-refund-20261117/attempt-N/summary.json. No timestamps.
"""
from pathlib import Path
import json, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[3]
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
GATE = ['--solver-path', str(ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'), '--resource-limit', '1000000',
        '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']
SETS = {'refund': ['impl/Refund.dfy', 'gate/refund/Bindings.dfy'], 'booking': ['tests/booking/SuccessfulExecution.dfy']}
out_root = ROOT / 'results/round2-print-booking-refund-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
out = out_root / f'attempt-{n:04d}'
out.mkdir(parents=True)
rows, failed = [], False


def mutate(d):
    r = (d / 'impl/Refund.dfy').read_text()
    a = '  method Assess(context: Context, response: ModelResponse)'
    assert r.count(a) == 1
    i = r.index(a); b = r.index('\n  {', i)
    (d / 'impl/Refund.dfy').write_text(r[:i] + a.replace('method Assess', 'method {:print} Assess') + r[i + len(a):b] + '\n  {\n    print "leak\\n";' + r[b + len('\n  {'):])
    k = (d / 'impl/Booking.dfy').read_text()
    a = '  method {:isolate_assertions} Apply ... {'
    assert k.count(a) == 1
    (d / 'impl/Booking.dfy').write_text(k.replace(a, '  method {:isolate_assertions} {:print} Apply ... {\n    print "leak\\n";'))


with tempfile.TemporaryDirectory() as tmp:
    for variant in ('approved', 'print-marked mutant'):
        d = Path(tmp) / variant.split()[0]
        for name in ('spec', 'impl', 'tests', 'gate'):
            shutil.copytree(ROOT / name, d / name, ignore=shutil.ignore_patterns('__pycache__'))
        if variant != 'approved':
            mutate(d)
        for gate, files in SETS.items():
            for option in (False, True):
                run = subprocess.run([str(DAFNY), 'verify', *files, *GATE, *(['--track-print-effects'] if option else [])],
                                     cwd=d, capture_output=True, text=True)
                want = 2 if (variant != 'approved' and option) else 0
                tag = f'{gate}-{variant.split()[0]}-{"with" if option else "without"}-option'
                (out / (tag + '.log')).write_text(run.stdout + run.stderr)
                errs = [l for l in (run.stdout + run.stderr).splitlines() if 'Error' in l]
                rows.append({'gate_files': gate, 'implementation': variant, 'track_print_effects': option, 'checker_exit': run.returncode,
                             'expected_checker_exit': want, 'first_error': (errs[0].split(': ', 1)[-1][:150] if errs else ''),
                             'result': 'PASS' if run.returncode == want else 'FAIL'})
                failed = failed or run.returncode != want
                print(tag, 'exit', run.returncode, rows[-1]['result'], '|', rows[-1]['first_error'][:100], flush=True)
(out / 'summary.json').write_text(json.dumps({'attempt': out.name, 'end_to_end': False, 'scenario_exit': 1 if failed else 0, 'rows': rows}, indent=1, sort_keys=True) + '\n')
raise SystemExit(1 if failed else 0)
