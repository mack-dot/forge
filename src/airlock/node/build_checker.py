"""Build the Dafny-compiled BookingDualCert checker for booking_check.cjs (Goal 20, inventory airlock).

Usage: python3 src/airlock/node/build_checker.py

No compiled BookingDualCert module is tracked in git. This script is the only way to get one. It runs the pinned
Dafny 4.11.0 (`.toolchain/dafny-4.11.0`) once to verify and once to build the source to JavaScript, with the same
options as proposals/forge2-pillar3-dual-certificate/benchmark/build_checker.py. It appends the same export line.
It writes build/airlock/checker/model.cjs (build/ is ignored by git) and a build record next to it.

It compares the bytes with the module SHA-256 that the tracked benchmark build record holds. Exit codes:
0 = verified, built, and equal to the recorded bytes; 1 = verify or build failed; 4 = built, but the bytes differ
from the record (then the module is kept as model.unpinned.cjs only, never as model.cjs).
Run one Dafny process at a time. No timestamps go into the record.
"""
from pathlib import Path
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[3]
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
# Same options as the Slice 3 benchmark build (gate/backends/dafny.py OPTIONS without --track-print-effects).
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']
SRC = 'proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy'
RECORD = 'proposals/forge2-pillar3-dual-certificate/benchmark/records/build-record.json'
OUT = 'build/airlock/checker'
EXPORT = b'\nmodule.exports = { BookingDualCert, runtime: _dafny };\n'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def last_line(text):
    return (text.strip().splitlines() or [''])[-1]


def main():
    out = ROOT / OUT
    out.mkdir(parents=True, exist_ok=True)
    for name in ('model.js', 'model.cjs', 'model.unpinned.cjs', 'build-record.json'):
        (out / name).unlink(missing_ok=True)
    recorded = json.loads((ROOT / RECORD).read_text())
    source_sha = sha((ROOT / SRC).read_bytes())
    verify = subprocess.run([str(DAFNY), 'verify', SRC, *OPTIONS], cwd=ROOT, capture_output=True, text=True)
    record = {'source': SRC, 'source_sha256': source_sha, 'recorded_source_sha256': recorded['source_sha256'],
              'recorded_module_sha256': recorded['module_sha256'], 'verify_exit': verify.returncode,
              'verify_last_line': last_line(verify.stdout), 'end_to_end': False}
    if verify.returncode == 0:
        build = subprocess.run([str(DAFNY), 'build', SRC, '--target', 'js', '--output', OUT + '/model', *OPTIONS],
                               cwd=ROOT, capture_output=True, text=True)
        record['build_exit'] = build.returncode
        record['build_last_line'] = last_line(build.stdout)
    if record.get('build_exit') == 0 and (out / 'model.js').is_file():
        module = (out / 'model.js').read_bytes() + EXPORT
        record['module_sha256'] = sha(module)
        record['equal_to_record'] = record['module_sha256'] == recorded['module_sha256']
        name = 'model.cjs' if record['equal_to_record'] else 'model.unpinned.cjs'
        (out / name).write_bytes(module)
        record['module_path'] = OUT + '/' + name
    text = json.dumps(record, indent=1, sort_keys=True) + '\n'
    (out / 'build-record.json').write_text(text)
    sys.stdout.write(text)
    if 'module_sha256' not in record:
        return 1
    return 0 if record['equal_to_record'] else 4


if __name__ == '__main__':
    raise SystemExit(main())
