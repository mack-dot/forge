"""Run one HOL script against the rebuilt CakeML basis heap (Round 3, M1 step A). Dispatch only; not a proof checker.

Usage: python3 -I -B run_basis_case.py <case> <source.sml>
Records argv, exit, wall time, peak memory and hashes. Output: results/round3-m1-input-premise-20261117/<case>/.
"""
from pathlib import Path
import hashlib, json, os, resource, shutil, subprocess, sys, time

FORGE = Path(__file__).resolve().parents[3]
TC = FORGE / '.toolchain/experiments/refund-cakeml-20261104'
HEAP = TC / 'cakeml/basis/basis-heap'
out = FORGE / 'results/round3-m1-input-premise-20261117' / sys.argv[1]
out.mkdir(parents=True, exist_ok=False)
src = Path(sys.argv[2]).resolve()
shutil.copyfile(src, out / 'proof.sml')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(HEAP), str(out / 'proof.sml')]
env = dict(os.environ, HOLDIR=str(TC / 'HOL'), CAKEMLDIR=str(TC / 'cakeml'), FORGE_OUT=str(out))
env['PATH'] = str(TC / 'poly-install/bin') + os.pathsep + env['PATH']
t = time.monotonic()
with (out / 'stdout.log').open('wb') as o, (out / 'stderr.log').open('wb') as e:
    p = subprocess.run(argv, cwd=TC / 'cakeml/basis', env=env, stdout=o, stderr=e,
                       preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CPU, (900, 900)))
text = (out / 'stdout.log').read_text(errors='replace')
rec = {'case': sys.argv[1], 'argv': [a.replace(str(FORGE), '<FORGE>') for a in argv], 'source_sha256': sha(src), 'heap_sha256': sha(HEAP),
       'actual_exit': p.returncode, 'wall_seconds': round(time.monotonic() - t, 1),
       'max_rss_mib': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss // 2 ** 20,
       'markers': [m for m in ('EXACT_COMPLETE',) if m in text.splitlines()], 'stdout_sha256': sha(out / 'stdout.log'),
       'objects': {x.name: sha(x) for x in sorted((out / '.hol/objs').glob('*'))} if (out / '.hol/objs').is_dir() else {}, 'end_to_end': False}
(out / 'command.json').write_text(json.dumps(rec, indent=1) + '\n')
print(json.dumps({k: rec[k] for k in ('actual_exit', 'wall_seconds', 'max_rss_mib', 'markers')}))
raise SystemExit(p.returncode if p.returncode >= 0 else 1)
