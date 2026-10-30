"""Find every change between the trusted base and a PR candidate, and the claims it touches.

The ledger PR gate establishes C1-C5 for impl/Ledger.dfy only. A change is covered
only when that check established it and no other claim reads the changed file.
This module reports facts; it does not decide correctness or interpret Dafny.
"""

import json
import os
from pathlib import Path
import posixpath
import re
import stat
import subprocess

from common import digest

# Ledger files whose correctness this gate re-establishes (spec and lock only with approval).
LEDGER_SCOPE = ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'spec.lock')
# Inputs of the ledger check that are never covered by its claims.
LEDGER_CHECK_ONLY = ('gate/ContractBinding.dfy',)
# Readers of ledger files that are not Dafny includes. Each entry names the code that
# reads the file; claims built on them are not re-established by the PR gate.
DECLARED_CONSUMERS = {
    'impl/Ledger.dfy': (
        ('gate/booking.py', 'the booking gate audits and verifies against this file'),
        ('gate/backends/typescript.py', 'tested_against_proved_model claims for ts/ledger.ts use the model compiled from this file'),
        ('scripts/build_model.py', 'builds the JavaScript model from this file'),
        ('scripts/stage5_tools.py', 'Stage 5 witness and spec-report checks read this file'),
        ('tests/Basic.dfy', 'imports module Ledger without an include; compiled beside this file by scripts/exit_stage_1.py'),
        ('evidence.json', 'committed ledger evidence names the artifact that includes this file'),
    ),
    'spec/LedgerSpec.dfy': (
        ('gate/booking.py', 'the booking gate pins this spec through spec/booking/spec.lock'),
        ('gate/backends/typescript.py', 'tested_against_proved_model claims take their statements from this spec'),
        ('scripts/build_model.py', 'checks this spec against spec.lock before building the model'),
        ('scripts/stage5_tools.py', 'Stage 5 witness and spec-report checks read this spec'),
        ('evidence.json', 'committed ledger evidence names the artifact that includes this file'),
    ),
    'spec.lock': (
        ('gate/booking.py', 'the booking gate pins this lock through spec/booking/spec.lock'),
        ('gate/backends/typescript.py', 'dafny.describe reads this lock for the model'),
        ('scripts/build_model.py', 'reads the spec digest from this lock'),
        ('scripts/stage5_tools.py', 'reads this lock'),
    ),
}
# Untracked trees in a trusted checkout (see .gitignore); used only without git.
BASE_UNTRACKED = ('.git', '.toolchain', 'build', 'node_modules', 'TestResults')
class Unsupported(Exception):
    """C1-C5 hold, but the PR changes something no established claim covers."""


INCLUDE = re.compile(rb'^\s*include\s+"([^"]+)"', re.MULTILINE)
GIT = ['git', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null']


def git(directory, *arguments):
    child = subprocess.run(GIT + ['-C', str(directory), *arguments], capture_output=True)
    if child.returncode:
        raise RuntimeError('REVISION_ERROR: git ' + arguments[0] + ' failed in ' + str(directory)
                           + '\n' + child.stderr.decode(errors='replace'))
    return child.stdout


def listing(directory, untracked):
    """Tracked paths from git when present (clean tree required); otherwise every file."""
    if (directory / '.git').exists():
        if git(directory, 'status', '--porcelain=v1', '-z', '--untracked-files=no'):
            raise RuntimeError('REVISION_ERROR: ' + ('trusted base' if untracked == BASE_UNTRACKED else 'candidate')
                               + ' tree has uncommitted changes to tracked files: ' + str(directory))
        names = [n.decode('utf-8', 'surrogateescape')
                 for n in git(directory, 'ls-files', '-z').split(b'\0') if n]
        return 'git', names
    names = []
    for parent, folders, files in os.walk(directory):
        relative = Path(parent).relative_to(directory)
        if relative == Path('.'):
            folders[:] = [f for f in folders if f not in untracked]
        links = [f for f in folders if (Path(parent) / f).is_symlink()]
        folders[:] = [f for f in folders if f not in links]
        # Bytecode caches are build products, never inputs; any other file is inventoried.
        names += [(relative / name).as_posix() for name in files + links
                  if not name.endswith(('.pyc', '.pyo'))]
    return 'walk', names


def inventory(directory, untracked):
    """(method, {path: 'mode sha256'}); links are recorded by target text, never followed."""
    method, names = listing(directory, untracked)
    result = {}
    for name in names:
        path = directory / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            result[name] = '120000 ' + digest(os.readlink(path).encode('utf-8', 'surrogateescape'))
        elif stat.S_ISREG(info.st_mode):
            result[name] = ('100755 ' if info.st_mode & 0o111 else '100644 ') + digest(path.read_bytes())
        else:
            raise RuntimeError('REVISION_ERROR: unsupported file type: ' + name)
    return method, result


def inventories(base, candidate):
    """Return (methods, base entries, candidate entries)."""
    base_method, before = inventory(base, BASE_UNTRACKED)
    candidate_method, after = inventory(candidate, ('.git',))
    return base_method + '/' + candidate_method, before, after


def changes(before, after):
    rows = []
    for name in sorted(before.keys() | after.keys()):
        if before.get(name) != after.get(name):
            kind = 'added' if name not in before else 'deleted' if name not in after else 'modified'
            rows.append({'path': name, 'change': kind})
    return rows


def includes_of(name, content):
    folder = posixpath.dirname(name)
    return {posixpath.normpath(posixpath.join(folder, target.decode('utf-8', 'surrogateescape')))
            for target in INCLUDE.findall(content)}


def dafny_dependents(candidate, entries, targets):
    """Tracked .dfy files that include any target, directly or transitively."""
    readers = {}
    for name in entries:
        if name.endswith('.dfy') and entries[name].startswith('100'):
            for included in includes_of(name, (candidate / name).read_bytes()):
                readers.setdefault(included, set()).add(name)
    found, seen, pending = {}, set(targets), [(target, target) for target in targets]
    while pending:
        current, origin = pending.pop()
        for reader in sorted(readers.get(current, ())):
            if reader not in seen:
                seen.add(reader)
                pending.append((reader, origin))
                if reader not in LEDGER_SCOPE + LEDGER_CHECK_ONLY:
                    found[reader] = origin
    return found


def lock_dependents(base, targets):
    """Approved spec locks (trusted base) that pin a target's digest."""
    found = []
    for lock in sorted((base / 'spec').rglob('spec.lock')):
        pinned = json.loads(lock.read_text()).get('dependencies', {})
        found += [(lock.relative_to(base).as_posix(), target) for target in targets if target in pinned]
    return found


def assess(base, candidate, mode, before, after, approved):
    """Classify every change; an empty 'findings' list means full coverage."""
    rows = changes(before, after)
    established = {'impl/Ledger.dfy'} | set(approved)
    findings = [{'path': row['path'], 'reason': 'UNCOVERED_CHANGE',
                 'detail': row['change'] + '; no claim established by this check covers it'}
                for row in rows if row['path'] not in established]
    covered = sorted(row['path'] for row in rows if row['path'] in established)
    for reader, origin in sorted(dafny_dependents(candidate, after, covered).items()):
        findings.append({'path': origin, 'reason': 'DEPENDENT_NOT_REESTABLISHED',
                         'detail': reader + ' includes it (directly or transitively); not re-checked here'})
    for lock, target in lock_dependents(base, covered):
        findings.append({'path': target, 'reason': 'DEPENDENT_NOT_REESTABLISHED',
                         'detail': lock + ' pins its digest; those claims are not re-checked here'})
    for target in covered:
        for reader, why in DECLARED_CONSUMERS.get(target, ()):
            findings.append({'path': target, 'reason': 'DEPENDENT_NOT_REESTABLISHED',
                             'detail': reader + ': ' + why})
    return {'inventory': mode, 'changed': rows, 'established_paths': covered,
            'findings': findings, 'covered': not findings}


def summary(result, limit=12):
    shown = ['%s %s (%s)' % (f['reason'], f['path'], f['detail']) for f in result['findings'][:limit]]
    more = len(result['findings']) - len(shown)
    return '; '.join(shown) + ('; and %d more' % more if more > 0 else '')
