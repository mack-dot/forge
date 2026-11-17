"""PR-gate controls for version 3 on MAIN's gate lineage (Stage 11 obligation gate). Dispatch only; the gate decides.

Trusted side T: a scratch worktree on the local branch that holds origin/main plus step A. Candidates are real clones
with committed changes (main's gate needs both). Gate command, run from T:
    python3 gate/incremental.py --profile local --candidate <clone> --evidence build/... --work build/...
Exit classes of main's gate: 0 VERIFIED, 1 REJECTED, 2 NOT_ESTABLISHED, 3 UNSUPPORTED.
NOT run: gate/pr_check.py (pull-request event, linux profile).
Usage: python3 -B run_pr_controls_main.py <trusted-worktree> <reduced-step-B-commit> <full-step-B-commit>
"""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[2]
T = Path(sys.argv[1]).resolve()
REDUCED, FULL = sys.argv[2], sys.argv[3]
BASE = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=T, capture_output=True, text=True).stdout.strip()
RAT = T / 'governance/gate-ratifications'
PROPOSAL = 'proposals/forge2-pillar1-print-effects/v3/PROPOSAL-V3.md'
REDUCED_FILES = ['gate/ContractBinding.dfy', 'gate/backends/dafny.py', 'gate/refund.py', 'spec/refund/spec.lock', 'toolchain/pins.json', 'evidence.json']
sha = lambda b: hashlib.sha256(b).hexdigest()
out_root = FORGE / 'results/round3-pr-controls-main-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
out = out_root / f'attempt-{n:04d}'
out.mkdir(parents=True)
git = lambda cwd, *a: subprocess.run(['git', '-C', str(cwd), *a], capture_output=True, text=True, check=True).stdout


def manifest(root):
    result = {}
    for d in ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github'):
        for p in sorted((root / d).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc':
                result[p.relative_to(root).as_posix()] = sha(p.read_bytes())
    for f in ('spec.lock', 'AGENTS.md'):
        if (root / f).is_file():
            result[f] = sha((root / f).read_bytes())
    return result


def sub(path, old, new):
    text = path.read_text()
    assert text.count(old) >= 1, (path, old)
    path.write_text(text.replace(old, new, 1))


def record_for(candidate, controls, mutate=None):
    a, b = manifest(T), manifest(candidate)
    files = {k: {'old_sha256': a.get(k), 'new_sha256': b.get(k)} for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)}
    rec = {'id': '0001-print-effects', 'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False, 'files': files,
           'controls': [{'path': c, 'sha256': sha((candidate / c).read_bytes()), 'expect': 'rejected'} for c in controls],
           'proposal': PROPOSAL, 'proposal_sha256': sha((T / PROPOSAL).read_bytes()),
           'trusted_origin': 'Maintainer-controlled base checkout; candidate-owned metadata is not authorization'}
    if mutate:
        mutate(rec)
    RAT.mkdir(parents=True, exist_ok=True)
    (RAT / '0001-print-effects.json').write_text(json.dumps(rec, indent=1, sort_keys=True) + '\n')


def reduced(c): git(c, 'checkout', REDUCED, '--', *REDUCED_FILES)
def full(c): git(c, 'checkout', FULL, '--', '.'); git(c, 'checkout', REDUCED, '--', 'evidence.json')
def benign(c): sub(c / 'impl/Ledger.dfy', 'var debit := state.balances[request.sender] - request.amount - 1;', 'var debit := state.balances[request.sender] - (request.amount + 1);')
def buggy(c): shutil.copyfile(T / 'bugs/off_by_one.dfy', c / 'impl/Ledger.dfy')
def gate_code(c): sub(c / 'gate/backends/dafny.py', "'--resource-limit', '1000000'", "'--resource-limit', '1'")
def pins(c): sub(c / 'toolchain/pins.json', '"--verify-included-files"', '"--verify-included-files", "--no-verify"')
def schema(c): p = c / 'schemas/evidence.schema.json'; p.write_text(p.read_text() + '\n')
def more_in_ratified(c): p = c / 'gate/backends/dafny.py'; p.write_text(p.read_text() + '\n# one more line\n')
def audit_off(c): sub(c / 'gate/backends/dafny.py', "        if audit.returncode != 0:\n", "        if False:\n")
def policy_scope(c):
    p = c / 'policy/tiers.yaml'; d = json.loads(p.read_text()); del d['tiers']['critical']['required_claims']['C4']; p.write_text(json.dumps(d, indent=2) + '\n')
def own_record(c):
    (c / 'governance/gate-ratifications').mkdir(parents=True)
    a, b = manifest(T), manifest(c)
    files = {k: {'old_sha256': a.get(k), 'new_sha256': b.get(k)} for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)}
    (c / 'governance/gate-ratifications/self.json').write_text(json.dumps({'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False,
        'files': files, 'controls': [], 'proposal': PROPOSAL, 'proposal_sha256': sha((T / PROPOSAL).read_bytes())}) + '\n')
def wrong_digest(rec): rec['files']['gate/backends/dafny.py']['new_sha256'] = '0' * 64
def wrong_proposal(rec): rec['proposal_sha256'] = '0' * 64
PRINT = ['bugs/print_effect.dfy', 'bugs/print_effect_marked.dfy']
# name, candidate edits, trusted record: None | (reference edits or None for "the candidate itself", controls, mutate), expected exit, note
CASES = [
    ('positive: benign implementation edit, no protected change', [benign], None, 0, 'legitimate change'),
    ('unratified gate code edit', [gate_code], None, 1, '(a)'),
    ('unratified toolchain pins edit', [pins], None, 1, '(a)'),
    ('reduced step B with NO record on the trusted side', [reduced], None, 1, '(a)'),
    ('reduced step B with a record written by the CANDIDATE', [reduced, own_record], None, 1, 'self-approval must fail'),
    ('RATIFIED reduced step B (five protected files + regenerated evidence.json)', [reduced], (None, [], None), 0, '(d) every obligation re-established with the ratified gate'),
    ('ratified reduced step B + buggy implementation', [reduced, buggy], ([reduced], [], None), 1, 'ratification does not carry a bad implementation'),
    ('ratified reduced step B + schema edit', [reduced, schema], ([reduced], [], None), 1, '(b) split edit'),
    ('ratified reduced step B + one more line in a ratified file', [reduced, more_in_ratified], ([reduced], [], None), 1, '(b) bytes differ from the ratified digest'),
    ('record with one wrong digest', [reduced], (None, [], wrong_digest), 1, '(c) tampered record'),
    ('record with a wrong proposal digest', [reduced], (None, [], wrong_proposal), 1, '(c) tampered record'),
    ('RATIFIED weakened gate: audit result ignored', [audit_off], (None, [], None), 1, 'controls: a planted bug would be accepted'),
    ('RATIFIED policy edit', [policy_scope], (None, [], None), 1, 'scope'),
    ('RATIFIED FULL step B (adds linux pins, two planted print bugs, exit_stage_5.py)', [full], (None, PRINT, None), 3, "main's coverage rule: four files are inputs of no obligation; UNSUPPORTED, not accepted"),
]
(T / PROPOSAL).parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(HERE / 'PROPOSAL-V3.md', T / PROPOSAL)
summary = {'attempt': out.name, 'trusted_tree': 'origin/main + step A, commit ' + BASE, 'gate': "main's gate/incremental.py --profile local, run from the trusted tree",
           'wrapper_gate_pr_check_py': 'NOT RUN', 'end_to_end': False, 'cases': []}
failed = False


def clone(path, edits):
    subprocess.run(['git', 'clone', '-q', '--no-checkout', str(FORGE), str(path)], check=True, capture_output=True)
    git(path, 'checkout', '-q', '--detach', BASE)
    for e in edits:
        e(path)
    git(path, 'add', '-A')
    if git(path, 'status', '--porcelain').strip():
        git(path, '-c', 'user.name=control', '-c', 'user.email=control@invalid', 'commit', '-q', '-m', 'control candidate')


for k, (name, edits, record, want, note) in enumerate(CASES):
    shutil.rmtree(RAT, ignore_errors=True)
    cand = out / f'candidate-{k:02d}'
    clone(cand, edits)
    if record is not None:
        ref_edits, controls, mutate = record
        ref = cand
        if ref_edits is not None:
            ref = out / f'reference-{k:02d}'
            clone(ref, ref_edits)
        record_for(ref, controls, mutate)
        if ref is not cand:
            shutil.rmtree(ref)
    work = Path('build') / f'round3-prmain-{out.name}-{k:02d}'
    shutil.rmtree(T / work, ignore_errors=True); (T / (str(work) + '-evidence.json')).unlink(missing_ok=True)
    run = subprocess.run([sys.executable, 'gate/incremental.py', '--profile', 'local', '--candidate', str(cand),
                          '--evidence', str(work) + '-evidence.json', '--work', str(work)], cwd=T, capture_output=True, text=True)
    (out / f'case-{k:02d}.log').write_text((run.stdout + run.stderr).replace(str(Path.home()), '<HOME>'))
    lines = [l for l in (run.stdout + run.stderr).strip().splitlines() if l.strip()]
    op = json.loads((T / work / 'operation.json').read_text()) if (T / work / 'operation.json').is_file() else {}
    ok = run.returncode == want
    failed = failed or not ok
    summary['cases'].append({'case': k, 'name': name, 'note': note, 'edits': [e.__name__ for e in edits], 'trusted_record': record is not None,
                             'gate_exit': run.returncode, 'expected_gate_exit': want, 'gate_last_line': (lines[-1][:300] if lines else '').replace(str(out), '<OUT>'),
                             'ratification_controls': [(c['path'], c['exit_code']) for c in op.get('ratification_controls', [])],
                             'obligations': {k2: v.get('result') for k2, v in (op.get('obligations') or {}).items()}, 'scenario_result': 'PASS' if ok else 'FAIL'})
    shutil.rmtree(cand)
    print(f'{k:02d} gate exit {run.returncode} (expected {want}) {"PASS" if ok else "FAIL"} | {name} | {(lines[-1] if lines else "")[:110]}', flush=True)
shutil.rmtree(RAT, ignore_errors=True)
summary['evasions'] = [c['name'] for c in summary['cases'] if c['expected_gate_exit'] != 0 and c['gate_exit'] == 0]
summary['scenario_exit'] = 1 if failed else 0
(out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
print(json.dumps({'attempt': out.name, 'scenario_exit': summary['scenario_exit'], 'evasions': summary['evasions']}))
raise SystemExit(summary['scenario_exit'])
