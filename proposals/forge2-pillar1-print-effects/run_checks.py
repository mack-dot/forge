"""Dispatch the pinned Dafny for the print-effect experiment (U414). Not a verifier. Not part of the gate.

Each case records the checker exit and the last output line. 'expect' is None for exploratory cases: they are recorded,
never counted as a pass. Output: a new attempt directory under results/; no timestamps.
"""
from pathlib import Path
import hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[2]
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
GATE = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
        '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']   # gate/backends/dafny.py OPTIONS
P = ['--track-print-effects']
D = ['--enforce-determinism']
F = 'proposals/forge2-pillar1-print-effects/fixtures/'
CASES = [  # name, file, extra options, expected exit (None = exploratory), required text
    ('print-mutant-survives-current-gate-options', F + 'PrintEffect.dfy', [], 0, 'verified, 0 errors'),
    ('print-mutant-with-track-print-effects', F + 'PrintEffect.dfy', P, None, ''),
    ('print-mutant-marked-with-track-print-effects', F + 'PrintEffectMarked.dfy', P, None, ''),
    ('print-mutant-marked-spaced-with-track-print-effects', F + 'PrintEffectMarkedSpaced.dfy', P, None, ''),
    ('gatecmd-print-mutant-current-options', F + 'PrintEffect.dfy', [], None, ''),
    ('gatecmd-print-mutant-with-track-print-effects', F + 'PrintEffect.dfy', P, None, ''),
    ('gatecmd-print-mutant-marked-with-track-print-effects', F + 'PrintEffectMarked.dfy', P, None, ''),
    ('gatecmd-print-mutant-marked-spaced-with-track-print-effects', F + 'PrintEffectMarkedSpaced.dfy', P, None, ''),
    ('gatecmd-approved-ledger-impl-with-track-print-effects', 'impl/Ledger.dfy', P, 0, 'verified, 0 errors'),
    ('gatecmd-probe-print-mutant-with-track-print-effects', F + 'PrintEffect.dfy', P, 2, 'the enclosing method must be marked with {:print}'),
    ('gatecmd-probe-print-mutant-marked-with-track-print-effects', F + 'PrintEffectMarked.dfy', P, 2, '{:print}'),
    ('gatecmd-probe-print-mutant-marked-spaced-with-track-print-effects', F + 'PrintEffectMarkedSpaced.dfy', P, 2, '{:print}'),
    ('gatecmd-probe-print-mutant-marked-WITHOUT-the-option', F + 'PrintEffectMarked.dfy', [], None, ''),
    ('gatecmd-probe-approved-ledger-impl-with-track-print-effects', 'impl/Ledger.dfy', P, 0, 'verified, 0 errors'),
    ('nondeterministic-choice-current-gate-options', F + 'NondeterministicChoice.dfy', [], None, ''),
    ('nondeterministic-choice-with-enforce-determinism', F + 'NondeterministicChoice.dfy', D, None, ''),
    ('approved-ledger-impl-with-track-print-effects', 'impl/Ledger.dfy', P, 0, 'verified, 0 errors'),
    ('approved-booking-impl-with-track-print-effects', 'impl/Booking.dfy', P, 0, 'verified, 0 errors'),
    ('approved-refund-impl-with-track-print-effects', 'impl/Refund.dfy', P, 0, 'verified, 0 errors'),
    ('approved-ledger-impl-with-enforce-determinism', 'impl/Ledger.dfy', D, None, ''),
    ('approved-booking-impl-with-enforce-determinism', 'impl/Booking.dfy', D, None, ''),
    ('approved-refund-impl-with-enforce-determinism', 'impl/Refund.dfy', D, None, ''),
]
out_root = ROOT / 'results/forge2-print-effects-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
out = out_root / f'attempt-{n:04d}'
out.mkdir(parents=True)
ver = subprocess.run([str(DAFNY), '--version'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
summary = {'attempt': out.name, 'dafny_version': ver, 'gate_options': GATE, 'end_to_end': False, 'cases': []}
failed = False
for name, path, extra, want, needle in CASES:
    if not (ROOT / path).is_file():
        summary['cases'].append({'name': name, 'file': path, 'result': 'FILE MISSING'}); failed = True; continue
    binding = ['gate/ContractBinding.dfy'] if name.startswith('gatecmd-') else []   # the ledger gate's real file pair
    if name.startswith('gatecmd-probe-'):
        binding.append(F + 'CallerProbe.dfy')                                   # candidate addition to the binding
    run = subprocess.run([str(DAFNY), 'verify', path, *binding, *GATE, *extra], cwd=ROOT, capture_output=True, text=True)
    (out / (name + '.stdout.log')).write_text(run.stdout); (out / (name + '.stderr.log')).write_text(run.stderr)
    text = run.stdout + run.stderr
    if want is None:
        res = 'RECORDED (exploratory)'
    else:
        ok = run.returncode == want and needle in text
        res = 'PASS' if ok else 'FAIL'; failed = failed or not ok
    errs = [l for l in text.splitlines() if 'Error' in l][:3]
    summary['cases'].append({'name': name, 'file': path, 'file_sha256': hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
                             'extra_options': extra, 'checker_exit': run.returncode, 'expected_checker_exit': want,
                             'result': res, 'first_errors': errs, 'last_line': (text.strip().splitlines() or [''])[-1]})
summary['scenario_exit'] = 1 if failed else 0
(out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
for c in summary['cases']:
    print(c['name'], '| exit', c.get('checker_exit'), '|', c['result'], '|', (c.get('first_errors') or [c.get('last_line', '')])[0][:150])
raise SystemExit(summary['scenario_exit'])
