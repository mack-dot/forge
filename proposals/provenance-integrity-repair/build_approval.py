#!/usr/bin/env python3
"""Build the unapplied candidate lock, diff and approval manifest.

This script never writes under gate/, spec/ or policy/. It applies the diff only
to a scratch copy and compares the result with the candidate bytes.
"""
import argparse
import difflib
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LOCK = 'gate/provenance/implementation.lock'
INSTALLED_LOCK_SHA = '6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa'
CANDIDATES = {
    'gate/provenance/release.py': HERE / 'release.py',
    'gate/provenance/producer.py': HERE / 'producer.py',
    'gate/provenance/artifact-identities.json': HERE / 'artifact-identities.json',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def protected():
    out = {}
    for top in ('gate', 'spec', 'policy'):
        for path in sorted((ROOT / top).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                out[str(path.relative_to(ROOT))] = sha(path.read_bytes())
    return out


def unified(path, old, new):
    old_lines = old.decode().splitlines(keepends=True) if old is not None else []
    new_lines = new.decode().splitlines(keepends=True)
    head = f'diff --git a/{path} b/{path}\n'
    if old is None:
        head += 'new file mode 100644\n'
    body = ''.join(difflib.unified_diff(old_lines, new_lines,
                                        '/dev/null' if old is None else 'a/' + path, 'b/' + path))
    return head + body


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scratch', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    failures = []
    before = protected()

    installed_lock = (ROOT / LOCK).read_bytes()
    if sha(installed_lock) != INSTALLED_LOCK_SHA:
        failures.append('INSTALLED_LOCK_CHANGED')
    lock = json.loads(installed_lock)
    for path, source in CANDIDATES.items():
        lock['files'][path] = sha(source.read_bytes())
    lock['files'] = dict(sorted(lock['files'].items()))
    candidate_lock = (json.dumps(lock, sort_keys=True, indent=2) + '\n').encode()
    if (json.dumps(json.loads(installed_lock), sort_keys=True, indent=2) + '\n').encode() != installed_lock:
        failures.append('LOCK_SERIALIZATION_NOT_REPRODUCED')
    (args.output / 'implementation.lock').write_bytes(candidate_lock)

    targets = {path: source.read_bytes() for path, source in CANDIDATES.items()}
    targets[LOCK] = candidate_lock
    diff = ''
    entries = []
    for path in sorted(targets):
        old_path = ROOT / path
        old = old_path.read_bytes() if old_path.exists() else None
        diff += unified(path, old, targets[path])
        entries.append({'path': path, 'action': 'create' if old is None else 'replace',
                        'installed_sha256': None if old is None else sha(old),
                        'installed_bytes': None if old is None else len(old),
                        'proposed_sha256': sha(targets[path]), 'proposed_bytes': len(targets[path])})
    diff_bytes = diff.encode()
    (args.output / 'proposed.diff').write_bytes(diff_bytes)

    scratch = args.scratch
    if scratch.exists():
        failures.append('SCRATCH_EXISTS')
    else:
        for path in targets:
            if (ROOT / path).exists():
                (scratch / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, scratch / path)
        check = subprocess.run(['git', 'apply', '--check', '--verbose', str((args.output / 'proposed.diff').resolve())],
                               cwd=scratch, capture_output=True, text=True)
        apply = subprocess.run(['git', 'apply', str((args.output / 'proposed.diff').resolve())],
                               cwd=scratch, capture_output=True, text=True)
        (args.output / 'apply-check.json').write_text(json.dumps({
            'cwd': str(scratch), 'check_exit_code': check.returncode, 'check_stdout': check.stdout,
            'check_stderr': check.stderr, 'apply_exit_code': apply.returncode,
            'apply_stderr': apply.stderr}, indent=2, sort_keys=True) + '\n')
        if check.returncode or apply.returncode:
            failures.append('DIFF_DOES_NOT_APPLY')
        for path, data in targets.items():
            if not (scratch / path).exists() or (scratch / path).read_bytes() != data:
                failures.append('APPLIED_BYTES_MISMATCH:' + path)

    for path, expected in lock['files'].items():
        actual = targets.get(path, (ROOT / path).read_bytes() if (ROOT / path).exists() else None)
        if actual is None or sha(actual) != expected:
            failures.append('CANDIDATE_LOCK_INPUT:' + path)

    after = protected()
    if after != before:
        failures.append('PROTECTED_TREE_CHANGED')
    manifest = {
        'status': 'awaiting_exact_byte_approval', 'applied': False, 'end_to_end': False,
        'installed_lock_sha256': INSTALLED_LOCK_SHA,
        'proposed_lock_sha256': sha(candidate_lock),
        'controller_must_supply_lock_sha256': sha(candidate_lock),
        'diff_sha256': sha(diff_bytes), 'diff_bytes': len(diff_bytes),
        'files': entries,
        'unchanged_protected_files': len([p for p in before if p not in targets]),
        'protected_tree_before_equals_after': after == before,
        'failures': failures,
    }
    (args.output / 'approval-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
