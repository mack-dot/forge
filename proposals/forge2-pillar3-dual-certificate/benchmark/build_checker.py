"""Verify once and compile the Dafny dual-certificate checker to JavaScript with the pinned Dafny (Round 2 task 4).

Dispatch only. Records the verification wall time (paid once), the compile exit and the hashes of the Dafny source and of
the generated module. Output under build/ (ignored by git). No timestamps in the record.
"""
from pathlib import Path
import hashlib, json, subprocess, sys, time

ROOT = Path(__file__).resolve().parents[3]
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']   # gate/backends/dafny.py OPTIONS
SRC = 'proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy'
out = ROOT / 'build/round2-dualcert'
out.mkdir(parents=True, exist_ok=True)
for name in ('model.js', 'model.cjs'):
    (out / name).unlink(missing_ok=True)
t = time.monotonic()
verify = subprocess.run([str(DAFNY), 'verify', SRC, *OPTIONS], cwd=ROOT, capture_output=True, text=True)
verify_seconds = round(time.monotonic() - t, 3)
t = time.monotonic()
build = subprocess.run([str(DAFNY), 'build', SRC, '--target', 'js', '--output', 'build/round2-dualcert/model', *OPTIONS],
                       cwd=ROOT, capture_output=True, text=True)
build_seconds = round(time.monotonic() - t, 3)
record = {'source': SRC, 'source_sha256': hashlib.sha256((ROOT / SRC).read_bytes()).hexdigest(),
          'verify_exit': verify.returncode, 'verify_last_line': (verify.stdout.strip().splitlines() or [''])[-1],
          'verify_wall_seconds': verify_seconds, 'build_exit': build.returncode, 'build_wall_seconds': build_seconds,
          'build_last_line': (build.stdout.strip().splitlines() or [''])[-1], 'end_to_end': False}
if build.returncode == 0 and (out / 'model.js').is_file():
    module = (out / 'model.js').read_bytes() + b'\nmodule.exports = { BookingDualCert, runtime: _dafny };\n'
    (out / 'model.cjs').write_bytes(module)
    record['module_sha256'] = hashlib.sha256(module).hexdigest()
print(json.dumps(record, indent=1, sort_keys=True))
(out / 'build-record.json').write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
raise SystemExit(0 if verify.returncode == 0 and build.returncode == 0 and 'module_sha256' in record else 1)
