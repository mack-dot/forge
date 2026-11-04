import hashlib, json, shutil, subprocess, sys, time
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
attempt = OUT / ('proof-' + sys.argv[1])
attempt.mkdir(exist_ok=False)
source = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT / 'UnicodeRelation.dfy'
shutil.copyfile(source, attempt / 'UnicodeRelation.dfy')
shutil.copyfile(OUT / 'Library.dfy', attempt / 'Library.dfy')
shutil.copytree(OUT / 'library', attempt / 'library')
shutil.copytree(OUT / 'transport', attempt / 'transport')
argv = [str(ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'), 'verify',
        'UnicodeRelation.dfy', '--solver-path',
        str(ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'),
        '--resource-limit', '1000000', '--verification-time-limit', '0',
        '--cores', '1', '--verify-included-files',
        '--bprint', 'translated.bpl',
        '--log-format', 'csv;LogFileName=verification.csv']
t = time.monotonic()
with (attempt / 'verify.log').open('wb') as log:
    result = subprocess.run(argv, cwd=attempt, stdout=log, stderr=subprocess.STDOUT)
record = {'argv': argv, 'cwd': str(attempt), 'actual_exit': result.returncode,
          'wall_seconds': time.monotonic() - t,
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'end_to_end': False}
(attempt / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
print((attempt / 'verify.log').read_text(errors='replace')[-5000:], flush=True)
raise SystemExit(result.returncode)
