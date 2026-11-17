"""Dispatch the pinned Dafny on the Pillar I determinism checks (U410). This is not a verifier and not part of the gate.

Each case records the CHECKER exit (Dafny) and, separately, the SCENARIO result: a negative control passes only
when Dafny rejects the file for the expected reason. Output: a new attempt directory under results/; no timestamps.
Usage: python3 -I -B run_checks.py
"""
from pathlib import Path
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']   # same as gate/backends/dafny.py
PINNED_VERSION = '4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2'
REL = 'proposals/forge2-pillar1-spec-determinism/'
CASES = [  # name, file, expected checker exit, required substring of the output, kind
    ('approved-ledger-spec-is-deterministic', REL + 'LedgerDeterminism.dfy', 0, 'verified, 0 errors', 'positive'),
    ('approved-booking-spec-is-deterministic', REL + 'BookingDeterminism.dfy', 0, 'verified, 0 errors', 'positive'),
    ('approved-refund-spec-is-deterministic', REL + 'RefundDeterminism.dfy', 0, 'verified, 0 errors', 'positive'),
    ('planted-noframe-spec-two-implementations-verify', REL + 'fixtures/NoFrameImpls.dfy', 0, 'verified, 0 errors', 'control-positive'),
    ('planted-noframe-spec-determinism-rejected', REL + 'fixtures/NoFrameDeterminism.dfy', 4,
     'NoFrameDeterminism.dfy(38,15): Related location: this is the postcondition that could not be proved', 'negative-control'),
    ('trojan-against-approved-spec-rejected', REL + 'fixtures/TrojanAgainstApprovedSpec.dfy', 4,
     'a postcondition could not be proved', 'negative-control'),
]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


out_root = ROOT / 'results/forge2-pillar1-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
out = out_root / f'attempt-{n:04d}'
out.mkdir(parents=True)
version = subprocess.run([str(DAFNY), '--version'], cwd=ROOT, capture_output=True, text=True)
summary = {'attempt': out.name, 'dafny_version_exit': version.returncode, 'dafny_version': version.stdout.strip(),
           'dafny_version_pinned': version.stdout.strip() == PINNED_VERSION, 'options': OPTIONS, 'end_to_end': False,
           'inputs': {p: sha(ROOT / p) for p in ['spec/LedgerSpec.dfy', 'spec/booking/BookingSpec.dfy', 'spec/refund/RefundSpec.dfy', 'spec.lock'] + sorted({c[1] for c in CASES}) +
                      [REL + 'fixtures/LedgerSpecNoFrame.dfy']},
           'cases': []}
failed = not summary['dafny_version_pinned']
for name, path, want, needle, kind in CASES:
    run = subprocess.run([str(DAFNY), 'verify', path, *OPTIONS], cwd=ROOT, capture_output=True, text=True)
    (out / (name + '.stdout.log')).write_text(run.stdout)
    (out / (name + '.stderr.log')).write_text(run.stderr)
    text = run.stdout + run.stderr
    ok = run.returncode == want and needle in text
    failed = failed or not ok
    summary['cases'].append({'name': name, 'file': path, 'kind': kind, 'checker_exit': run.returncode,
                             'expected_checker_exit': want, 'required_output_text': needle,
                             'required_output_text_found': needle in text, 'scenario_result': 'PASS' if ok else 'FAIL',
                             'last_line': (run.stdout.strip().splitlines() or [''])[-1]})
summary['scenario_exit'] = 1 if failed else 0
(out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
print(json.dumps({'attempt': out.name, 'scenario_exit': summary['scenario_exit'],
                  'cases': [(c['name'], c['checker_exit'], c['scenario_result']) for c in summary['cases']]}, indent=1))
raise SystemExit(summary['scenario_exit'])
