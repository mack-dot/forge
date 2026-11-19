"""Dispatch the pinned Dafny for the finality-protocol model (U415). Not a verifier. Not part of the gate.

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
F = 'proposals/forge2-pillar2-finality-protocol/fixtures/'
CASES = [  # name, file, extra options, expected exit, required text
    ('finality-protocol-model-verifies', 'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy', [], 0, 'verified, 0 errors'),
    ('control-no-nonce-check-rejected', F + 'NoNonceCheck.dfy', [], 4, 'could not be proved'),
    ('control-no-state-check-rejected', F + 'NoStateCheck.dfy', [], 4, 'could not be proved'),
    ('control-no-id-check-rejected', F + 'NoIdCheck.dfy', [], 4, 'could not be proved'),
    ('control-no-ideal-mac-rejected', F + 'NoIdealMac.dfy', [], 4, 'could not be proved'),
]
out_root = ROOT / 'results/forge2-pillar2-20261117'
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
