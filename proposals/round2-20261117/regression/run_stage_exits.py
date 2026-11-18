"""Run the existing stage EXIT scripts (scripts/exit_stage_1.py .. exit_stage_8.py) and record real exits (Round 2).

Dispatch only: each script is run unchanged with the pinned Python. Per script: exit code, wall seconds, log hashes and
the list of tracked files that differ from HEAD afterwards. No timestamps in the summary.
Usage: python3 -B run_stage_exits.py <label> [stage numbers...]
"""
import hashlib, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
label = sys.argv[1]
CASES = {1: ['reproducibility', 'planted-bugs', 'spec-lock', 'contract-binding', 'audit-controls'],
         2: ['schema', 'artifact-mismatch', 'method-policy', 'round-trip', 'policy-controls'],
         3: ['correct-typescript', 'self-transfer', 'evidence-labels', 'reproducibility', 'loader-demo', 'cli-demo'],
         4: ['affected-claims', 'unapproved-spec', 'approved-spec'],
         5: ['vacuity', 'mutations'], 6: ['report'],
         7: ['upstream-replay', 'invalid-proof', 'own-proof'],
         8: ['wrapper-proof', 'hostile-outputs', 'evidence-separation']}     # the --case values of each stage script
stages = [(int(x), c) for x in (sys.argv[2:] or list(range(1, 9))) for c in CASES[int(x)]]
out = ROOT / 'results/round2-regression-20261117' / label
out.mkdir(parents=True, exist_ok=False)
head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
summary = {'label': label, 'head': head, 'python': sys.version.split()[0], 'end_to_end': False, 'stages': []}
for n, case in stages:
    script = ROOT / f'scripts/exit_stage_{n}.py'
    t = time.monotonic()
    try:
        p = subprocess.run([sys.executable, str(script), '--case', case], cwd=ROOT, capture_output=True, text=True, timeout=2400)
        code, so, se, timed = p.returncode, p.stdout, p.stderr, False
    except subprocess.TimeoutExpired as e:
        code, so, se, timed = None, (e.stdout or b'').decode(errors='replace') if isinstance(e.stdout, bytes) else (e.stdout or ''), '', True
    (out / f'stage{n}-{case}.stdout.log').write_text(so)
    (out / f'stage{n}-{case}.stderr.log').write_text(se)
    dirty = subprocess.run(['git', 'status', '--short', '--untracked-files=no'], cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
    row = {'stage': n, 'case': case, 'script': f'scripts/exit_stage_{n}.py --case {case}', 'exit': code, 'timed_out': timed,
           'wall_seconds': round(time.monotonic() - t, 1),
           'stdout_sha256': hashlib.sha256(so.encode()).hexdigest(), 'last_line': (so.strip().splitlines() or [''])[-1][:300],
           'stderr_tail': se.strip().splitlines()[-2:] if se.strip() else [],
           'tracked_files_differing_from_head': [l for l in dirty if not l.endswith('.elf')]}
    summary['stages'].append(row)
    (out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
    print(n, case, 'exit', code, row['wall_seconds'], 's |', row['last_line'][:120], flush=True)
