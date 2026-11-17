"""Fresh Stage 6 experiment ("epoch 2") with the version 3 gate, in a SCRATCH worktree (Round 3). Dispatch only.

The epoch 1 records are first copied unchanged to results/stage6-epoch1 and docs/reuse-benchmark-epoch1.md and the
copy is compared file by file. Then the records that depend on the gate bytes are produced again by real runs:
  scripts/benchmark_reuse.py (75 pairs), scripts/check_stage_6.py (restored unchanged from commit 8159a79d),
  check_stage6_inputs.py (post-run identity check), scripts/exit_stage_6.py --case report (twice).
accounting.json is NOT regenerated: it is the authoring usage record of epoch 1 and stays as that.
Usage: python3 -B stage6_epoch2.py <scratch-worktree>
"""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[2]
W = Path(sys.argv[1]).resolve()
assert W != FORGE and (W / '.git').is_file(), 'run only in a scratch git worktree'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
tree = lambda d: {p.relative_to(d).as_posix(): sha(p) for p in sorted(Path(d).rglob('*')) if p.is_file()}
steps = []


def run(label, argv):
    t = time.monotonic()
    p = subprocess.run(argv, cwd=W, capture_output=True, text=True)
    steps.append({'label': label, 'argv': [a.replace(str(W), '<W>').replace(str(FORGE), '<FORGE>') for a in argv], 'exit': p.returncode,
                  'wall_seconds': round(time.monotonic() - t, 1), 'last_line': ((p.stdout + p.stderr).strip().splitlines() or [''])[-1][:300]})
    print(label, 'exit', p.returncode, steps[-1]['wall_seconds'], 's |', steps[-1]['last_line'][:160], flush=True)
    return p.returncode


old, s6 = W / 'results/stage6-epoch1', W / 'results/stage6'
assert not old.exists(), 'epoch 1 archive exists already'
epoch1_report = json.loads((s6 / 'report.json').read_text())
shutil.copytree(s6, old)
shutil.copyfile(W / 'docs/reuse-benchmark.md', W / 'docs/reuse-benchmark-epoch1.md')
head = {l.split('\t')[1][len('results/stage6/'):]: l.split()[2] for l in subprocess.run(['git', 'ls-tree', '-r', 'HEAD', 'results/stage6'], cwd=W, capture_output=True, text=True).stdout.splitlines()}
blob = lambda p: hashlib.sha1(b'blob %d\0' % p.stat().st_size + p.read_bytes()).hexdigest()
archive_equals_head = {k: blob(old / k) for k in head} == head and sorted(tree(old)) == sorted(head)
for name in ('benchmark.json', 'input-identities.json', 'controls-final.json', 'source-evidence.json', 'report.json'):
    (s6 / name).unlink()
for name in ('runs', 'development', 'controls', 'controls-2'):
    shutil.rmtree(s6 / name)
for p in list(s6.glob('report-*')) + list(s6.glob('preflight*')):
    p.unlink()
shutil.rmtree(W / 'build/stage6', ignore_errors=True)
script = subprocess.run(['git', 'show', '8159a79d:scripts/check_stage_6.py'], cwd=W, capture_output=True, check=True).stdout
(W / 'scripts/check_stage_6.py').write_bytes(script)
ok = run('benchmark', [sys.executable, 'scripts/benchmark_reuse.py']) == 0
ok = ok and run('controls', [sys.executable, 'scripts/check_stage_6.py']) == 0
ok = ok and run('input-identities', [sys.executable, str(HERE / 'check_stage6_inputs.py')]) == 0
ok = ok and run('report EXIT, call 1', [sys.executable, 'scripts/exit_stage_6.py', '--case', 'report']) == 0
first = {n: sha(W / n) for n in ('results/stage6/report.json', 'docs/reuse-benchmark.md')} if ok else None
ok = ok and run('report EXIT, call 2', [sys.executable, 'scripts/exit_stage_6.py', '--case', 'report']) == 0
record = {'epoch1_archive_equals_HEAD_file_by_file': archive_equals_head, 'steps': steps, 'end_to_end': False,
          'report_reproduced_byte_identical': bool(ok and first == {n: sha(W / n) for n in first}),
          'check_stage_6_sha256': hashlib.sha256(script).hexdigest(), 'scenario_exit': 0 if ok and archive_equals_head else 1}
if ok:
    new = json.loads((s6 / 'report.json').read_text())
    record['conditions'] = {c: {'epoch1_verifier_process_s': round(epoch1_report['conditions'][c]['verifier_process_ns'] / 1e9, 1),
                                'epoch2_verifier_process_s': round(new['conditions'][c]['verifier_process_ns'] / 1e9, 1),
                                'epoch1_solver_resources': epoch1_report['conditions'][c]['checked_solver_resources'],
                                'epoch2_solver_resources': new['conditions'][c]['checked_solver_resources'],
                                'epoch1_reused_members': epoch1_report['conditions'][c]['reused_members'],
                                'epoch2_reused_members': new['conditions'][c]['reused_members']} for c in new['conditions']}
(W / 'results/stage6-epoch2-run.json').write_text(json.dumps(record, indent=1) + '\n')
print(json.dumps({k: record[k] for k in ('epoch1_archive_equals_HEAD_file_by_file', 'report_reproduced_byte_identical', 'scenario_exit')}))
raise SystemExit(record['scenario_exit'])
