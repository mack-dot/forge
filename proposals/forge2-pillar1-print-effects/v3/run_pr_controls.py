"""PR-gate controls for proposal version 3 (Round 3). Dispatch only; the gate decides.

Trusted side: a scratch git worktree T that holds HEAD plus step A of build_v3.py. The gate runs FROM T:
    python3 gate/incremental.py --profile local --candidate <dir> --evidence build/... --work build/...
This is the command of gate/pr_check.py except for the toolchain profile (the wrapper uses --profile linux and needs a
pull-request event; NOT run here). Each case sets up the trusted side (ratification records) and a candidate tree.
Usage: python3 -B run_pr_controls.py <trusted-worktree>
"""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[2]
T = Path(sys.argv[1]).resolve()
DIRS = ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github', 'impl', 'bugs', 'scripts')
FILES = ('spec.lock', 'AGENTS.md', 'evidence.json')
PROTECTED_DIRS, PROTECTED_FILES = ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github'), ('spec.lock', 'AGENTS.md')
RAT = T / 'governance/gate-ratifications'
PROPOSAL = 'proposals/forge2-pillar1-print-effects/v3/PROPOSAL-V3.md'
sha = lambda b: hashlib.sha256(b).hexdigest()
out_root = FORGE / 'results/round3-pr-controls-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
out = out_root / f'attempt-{n:04d}'
out.mkdir(parents=True)


def manifest(root):
    result = {}
    for d in PROTECTED_DIRS:
        for p in sorted((root / d).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc':
                result[p.relative_to(root).as_posix()] = sha(p.read_bytes())
    for f in PROTECTED_FILES:
        if (root / f).is_file():
            result[f] = sha((root / f).read_bytes())
    return result


def copy_tree(src, dst):
    for d in DIRS:
        shutil.copytree(src / d, dst / d, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for f in FILES:
        shutil.copyfile(src / f, dst / f)


def sub(path, old, new):
    text = path.read_text()
    assert text.count(old) >= 1, (path, old)
    path.write_text(text.replace(old, new, 1))


def record_for(candidate, controls, name='0001-print-effects.json', mutate=None):
    """Write a ratification record on the TRUSTED side for exactly the protected difference T -> candidate."""
    a, b = manifest(T), manifest(candidate)
    files = {k: {'old_sha256': a.get(k), 'new_sha256': b.get(k)} for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)}
    rec = {'id': name[:-5], 'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False, 'files': files,
           'controls': [{'path': c, 'sha256': sha((candidate / c).read_bytes()), 'expect': 'rejected'} for c in controls],
           'proposal': PROPOSAL, 'proposal_sha256': sha((T / PROPOSAL).read_bytes()),
           'trusted_origin': 'Maintainer-controlled base checkout; candidate-owned metadata is not authorization'}
    if mutate:
        mutate(rec)
    RAT.mkdir(parents=True, exist_ok=True)
    (RAT / name).write_text(json.dumps(rec, indent=1, sort_keys=True) + '\n')
    return rec


# ---- candidate edits ----
def benign(c):
    sub(c / 'impl/Ledger.dfy', 'var debit := state.balances[request.sender] - request.amount - 1;',
        'var debit := state.balances[request.sender] - (request.amount + 1);')
def buggy(c): shutil.copyfile(T / 'bugs/off_by_one.dfy', c / 'impl/Ledger.dfy')
def gate_code(c): sub(c / 'gate/backends/dafny.py', "'--resource-limit', '1000000'", "'--resource-limit', '1'")
def pins(c): sub(c / 'toolchain/pins.json', '"--verify-included-files"', '"--verify-included-files", "--no-verify"')
def schema(c): p = c / 'schemas/evidence.schema.json'; p.write_text(p.read_text() + '\n')
def policy_scope(c):
    p = c / 'policy/tiers.yaml'; d = json.loads(p.read_text()); del d['tiers']['critical']['required_claims']['C4']; p.write_text(json.dumps(d, indent=2) + '\n')
def audit_off(c): sub(c / 'gate/backends/dafny.py', "        if audit.returncode != 0:\n", "        if False:\n")
def manifest_off(c): sub(c / 'gate/incremental.py', "def protected_manifest(root):\n    result = {}\n", "def protected_manifest(root):\n    return {}\n    result = {}\n")
def scope_narrow(c):    # review case t6: bugs/ is refused for scope, and the audit result is ignored
    sub(c / 'gate/backends/dafny.py', "not in (ROOT / 'impl', ROOT / 'bugs'):", "not in (ROOT / 'impl',):")
    sub(c / 'gate/backends/dafny.py', "        if audit.returncode != 0:\n", "        if False:\n")
def approval_record(c): (c / 'gate/approvals/extra.json').write_text('{}\n')
def step_b(c): subprocess.run([sys.executable, '-I', '-B', str(HERE.parent / 'v2/build_v2.py'), str(c)], check=True, capture_output=True)
def extra_comment_in_ratified_file(c): p = c / 'gate/backends/dafny.py'; p.write_text(p.read_text() + '\n# one more line\n')
def lock_other_field(c): sub(c / 'spec/refund/spec.lock', '"dafny_version": "4.11.0"', '"dafny_version": "4.11.1"')
def own_record(c):
    (c / 'governance/gate-ratifications').mkdir(parents=True)
    a, b = manifest(T), manifest(c)
    files = {k: {'old_sha256': a.get(k), 'new_sha256': b.get(k)} for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)}
    (c / 'governance/gate-ratifications/self.json').write_text(json.dumps({'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False,
        'files': files, 'controls': [], 'proposal': PROPOSAL, 'proposal_sha256': sha((T / PROPOSAL).read_bytes())}) + '\n')
PRINT_BUGS = ['bugs/print_effect.dfy', 'bugs/print_effect_marked.dfy']


def wrong_digest(rec): rec['files']['gate/backends/dafny.py']['new_sha256'] = '0' * 64
def wrong_proposal(rec): rec['proposal_sha256'] = '0' * 64
def not_tier0(rec): rec['tier'] = 1
def tier_false(rec): rec['tier'] = False
def control_replaces_trusted_bug(rec): rec['controls'].append({'path': 'bugs/off_by_one.dfy', 'sha256': sha((T / 'bugs/off_by_one.dfy').read_bytes()), 'expect': 'rejected'})
def control_outside_bugs(rec): rec['controls'].append({'path': 'impl/Ledger.dfy', 'sha256': '0' * 64, 'expect': 'rejected'})

# name, candidate edits, trusted-side record (None | (controls, mutate)), expected gate exit, note
CASES = [
    ('positive: benign implementation edit, no protected change', [benign], None, 0, 'legitimate change; no record needed'),
    ('unratified gate code edit', [gate_code], None, 1, '(a) rejecting by default'),
    ('unratified toolchain pins edit', [pins], None, 1, '(a) rejecting by default'),
    ('unratified step B (print effects) with NO record on the trusted side', [step_b], None, 1, 'no ratification, no entry'),
    ('step B with a ratification record written by the CANDIDATE itself', [step_b, own_record], None, 1, 'self-approval must fail'),
    ('RATIFIED step B, exact bytes', [step_b], (PRINT_BUGS, None), 0, '(d) ratified change is accepted; controls run'),
    ('ratified step B + buggy implementation', [step_b, buggy], (PRINT_BUGS, None), 1, 'ratification does not carry a bad implementation'),
    ('ratified step B + one more protected edit (schema)', [step_b, schema], ('B', None), 1, '(b) split-edit in one head tree'),
    ('ratified step B + policy scope edit + buggy implementation', [step_b, policy_scope, buggy], ('B', None), 1, '(b) split-edit'),
    ('ratified step B + one more line in a ratified file', [step_b, extra_comment_in_ratified_file], ('B', None), 1, 'bytes differ from the ratified digest'),
    ('record with one wrong digest (tampered record)', [step_b], (PRINT_BUGS, wrong_digest), 1, '(c) tampered ratification digest'),
    ('record whose proposal digest does not match the trusted text', [step_b], (PRINT_BUGS, wrong_proposal), 1, '(c) tampered record'),
    ('record that is not tier 0', [step_b], (PRINT_BUGS, not_tier0), 1, 'wrong record class'),
    ('record with a control outside bugs/', [step_b], (PRINT_BUGS, control_outside_bugs), 1, 'malformed record fails closed'),
    ('RATIFIED weakened gate: resource limit 1 (record matches exactly)', [gate_code], ([], None), 1, 'non-weakening controls: baseline no longer accepted'),
    ('RATIFIED weakened gate: audit result ignored (record matches exactly)', [audit_off], ([], None), 1, 'non-weakening controls: a planted bug would be accepted'),
    ('RATIFIED gate whose protected_manifest returns nothing (record matches exactly)', [manifest_off], ([], None), 1, 'review finding 1 (t3): function probe'),
    ('RATIFIED gate that refuses bugs/ for scope and ignores the audit (record matches exactly)', [scope_narrow], ([], None), 1, 'review finding 1 (t6): rejection reason must be a proof or audit result'),
    ('record whose control replaces a trusted planted bug', [step_b], (PRINT_BUGS, control_replaces_trusted_bug), 1, 'review finding 1 (t4)'),
    ('record with "tier": false', [step_b], (PRINT_BUGS, tier_false), 1, 'review finding 4'),
    ('RATIFIED new file under gate/approvals/ (record matches exactly)', [approval_record], ([], None), 1, 'review finding 5: outside Tier-0'),
    ('RATIFIED policy edit (record matches exactly)', [policy_scope], ([], None), 1, 'scope: Tier-0 covers gate/ and toolchain/ only'),
    ('RATIFIED step B + another field changed in spec/refund/spec.lock (record matches exactly)', [step_b, lock_other_field], (PRINT_BUGS, None), 1, 'scope: a lock may only be re-bound'),
]
STEP_B_TREE = out / 'reference-step-b'
copy_tree(T, STEP_B_TREE); step_b(STEP_B_TREE)
(T / PROPOSAL).parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(HERE / 'PROPOSAL-V3.md', T / PROPOSAL)
head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=T, capture_output=True, text=True).stdout.strip()
summary = {'attempt': out.name, 'trusted_tree': 'HEAD ' + head + ' + build_v3.py step A', 'gate': 'gate/incremental.py --profile local (run from the trusted tree)',
           'wrapper_gate_pr_check_py': 'NOT RUN (needs a pull-request event and the linux profile)', 'end_to_end': False, 'cases': []}
failed = False
for k, (name, edits, record, want, note) in enumerate(CASES):
    shutil.rmtree(RAT, ignore_errors=True)
    cand = out / f'candidate-{k:02d}'
    copy_tree(T, cand)
    for e in edits:
        e(cand)
    if record is not None:
        controls, mutate = record
        # 'B' = the record ratifies exactly step B (the reference tree), while the candidate holds more than step B.
        record_for(STEP_B_TREE if controls == 'B' else cand, PRINT_BUGS if controls == 'B' else controls, mutate=mutate)
    work = Path('build') / f'round3-pr-{out.name}-{k:02d}'
    shutil.rmtree(T / work, ignore_errors=True); (T / (str(work) + '-evidence.json')).unlink(missing_ok=True)
    run = subprocess.run([sys.executable, 'gate/incremental.py', '--profile', 'local', '--candidate', str(cand),
                          '--evidence', str(work) + '-evidence.json', '--work', str(work)], cwd=T, capture_output=True, text=True)
    (out / f'case-{k:02d}.log').write_text(run.stdout + run.stderr)
    lines = [l for l in (run.stdout + run.stderr).strip().splitlines() if l.strip()]
    op = json.loads((T / work / 'operation.json').read_text()) if (T / work / 'operation.json').is_file() else {}
    controls_run = [(c['path'], c['exit_code']) for c in op.get('ratification_controls', [])]
    replay = None
    if run.returncode == 0 and record is not None:      # what gate/pr_check.py does: run the saved command, compare bytes
        bundle = json.loads((T / (str(work) + '-evidence.json')).read_text())
        again = subprocess.run(bundle['evidence'][0]['reproduce_cmd'].split(), cwd=T, capture_output=True, text=True)
        replay = {'exit': again.returncode, 'byte_identical': again.returncode == 0 and
                  (T / 'build/change-evidence.json').read_bytes() == (T / (str(work) + '-evidence.json')).read_bytes()}
    ok = run.returncode == want and (replay is None or replay['byte_identical'])
    failed = failed or not ok
    summary['cases'].append({'replay_of_saved_command': replay, 'case': k, 'name': name, 'note': note, 'edits': [e.__name__ for e in edits], 'trusted_record': record is not None,
                             'gate_exit': run.returncode, 'expected_gate_exit': want, 'gate_last_line': (lines[-1][:260] if lines else ''),
                             'ratification_controls': controls_run, 'scenario_result': 'PASS' if ok else 'FAIL'})
    shutil.rmtree(cand)
    print(f'{k:02d} gate exit {run.returncode} (expected {want}) {"PASS" if ok else "FAIL"} | {name} | {(lines[-1] if lines else "")[:120]}', flush=True)
shutil.rmtree(RAT, ignore_errors=True); shutil.rmtree(STEP_B_TREE)
summary['evasions'] = [c['name'] for c in summary['cases'] if c['expected_gate_exit'] == 1 and c['gate_exit'] == 0]
summary['scenario_exit'] = 1 if failed else 0
(out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
print(json.dumps({'attempt': out.name, 'scenario_exit': summary['scenario_exit'], 'evasions': summary['evasions']}))
raise SystemExit(summary['scenario_exit'])
