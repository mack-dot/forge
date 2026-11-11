"""Run the established Dafny checker and retain its actual result."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys, time
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
case = OUT / sys.argv[1]
case.mkdir(exist_ok=False)
shutil.copytree(OUT / 'inputs', case / 'inputs')
if len(sys.argv) > 2:
    shutil.copy2(Path(sys.argv[2]), case / 'inputs/Boundary.dfy')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
argv = [str(ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'), 'verify', 'Boundary.dfy',
        '--solver-path', str(ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'),
        '--resource-limit', '1000000', '--verification-time-limit', '0', '--cores', '1',
        '--verify-included-files', '--log-format', 'csv;LogFileName=verification.csv']
record = {'argv': argv, 'cwd': str(case / 'inputs'), 'end_to_end': False,
          'inputs': {str(p.relative_to(case / 'inputs')): sha(p) for p in (case / 'inputs').rglob('*') if p.is_file()}}
(case / 'invocation.json').write_text(json.dumps(record, indent=2) + '\n')
start = time.monotonic()
with (case / 'stdout.log').open('wb') as stdout, (case / 'stderr.log').open('wb') as stderr:
    p = subprocess.run(argv, cwd=case / 'inputs', stdout=stdout, stderr=stderr)
record.update(actual_exit=p.returncode, wall_seconds=time.monotonic()-start)
(case / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'case': case.name, 'actual_exit': p.returncode, 'wall_seconds': record['wall_seconds']}), flush=True)
print((case / 'stdout.log').read_text()[-4000:], flush=True)
print((case / 'stderr.log').read_text()[-1000:], flush=True)
raise SystemExit(p.returncode)
