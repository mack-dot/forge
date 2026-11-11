"""Run the real incremental gate, then corrupt its genuine booking receipt.

No mock verifier, fabricated passing receipt, or alteration of PR #30 is used.
An exit of 1 means that the security regression failed (unsafe adoption).
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time

HEAD = '561d2dda904daf18f17a0fede93f28b502d72884'


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def export(repo, destination):
    data = subprocess.check_output(['git', '-C', str(repo), 'archive', HEAD])
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for entry in archive.getmembers():
            if entry.name.startswith('/') or '..' in Path(entry.name).parts or not (entry.isdir() or entry.isfile()):
                raise RuntimeError('Unexpected trusted archive entry')
        archive.extractall(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    root, candidate = out / 'trusted', out / 'candidate'
    export(args.repo, root)
    shutil.copytree(root, candidate)
    path = candidate / 'impl/Booking.dfy'
    before = path.read_text()
    assert before.count('other < value') == 1
    path.write_text(before.replace('other < value', 'other <= value'))
    (root / '.toolchain').symlink_to((args.repo / '.toolchain').resolve(), target_is_directory=True)
    rows = []
    env = {k: v for k, v in os.environ.items() if k in
           ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'DOTNET_ROOT')}
    env['PYTHONDONTWRITEBYTECODE'] = '1'

    def run(label):
        argv = [sys.executable, '-B', 'gate/incremental.py', '--candidate', str(candidate),
                '--evidence', 'build/' + label + '.json', '--work', 'build/' + label]
        start = time.perf_counter_ns()
        with (out / (label + '.log')).open('wb') as log:
            child = subprocess.run(argv, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
        row = {'label': label, 'argv': argv, 'cwd': str(root), 'exit_code': child.returncode,
               'wall_seconds': (time.perf_counter_ns() - start) / 1e9}
        operation_path = root / 'build' / label / 'operation.json'
        if operation_path.exists():
            row['operation'] = json.loads(operation_path.read_text())
        rows.append(row)
        write(out / 'commands.json', rows)
        return row

    cold = run('cold')
    if cold['exit_code'] != 0:
        return 2
    receipt = cold['operation']['obligations']['booking']
    assert receipt['result'] == 'established' and receipt['reused'] is False
    cache = root / 'build/obligation-cache' / (receipt['cache_key'] + '.json')
    write(out / 'original-receipt.json', json.loads(cache.read_text()))
    forged = json.loads(cache.read_text())
    forged['evidence_sha256'] = '0' * 64
    forged['artifact_sha256'] = '1' * 64
    assert forged['cache_key'] == receipt['cache_key'] and forged['result'] == 'established'
    write(cache, forged)
    write(out / 'corrupted-receipt.json', forged)
    warm = run('corrupted')
    adopted = warm.get('operation', {}).get('obligations', {}).get('booking', {})
    unsafe = warm['exit_code'] == 0 and adopted.get('reused') is True
    write(out / 'result.json', {
        'source_commit': HEAD,
        'source_tree': subprocess.check_output(['git', '-C', str(args.repo), 'rev-parse', HEAD + '^{tree}']).decode().strip(),
        'candidate_booking_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'cold_exit': cold['exit_code'], 'corrupted_exit': warm['exit_code'],
        'cache_key_preserved': forged['cache_key'] == receipt['cache_key'],
        'established_preserved': forged['result'] == 'established',
        'corrupted_receipt_adopted': unsafe,
        'fresh_booking_log_exists': (root / 'build/corrupted/obligations/booking-0.log').exists(),
        'expected': 'reject corrupted evidence; never adopt it',
        'security_regression_passed': not unsafe,
        'hosted_execution': False, 'release_admission': False})
    return 1 if unsafe else 0


if __name__ == '__main__':
    raise SystemExit(main())
