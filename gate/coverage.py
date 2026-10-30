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
import obligations

# Ledger files whose correctness this gate re-establishes (spec and lock only with approval).
LEDGER_SCOPE = ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'spec.lock')
# Inputs of the ledger check that are never covered by its claims.
LEDGER_CHECK_ONLY = ('gate/ContractBinding.dfy',)
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


def listing(directory, untracked, include_bytecode=False):
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
        # In the trusted base, bytecode caches are build products. In a candidate every file
        # counts, so planted bytecode is an (uncovered) change.
        names += [(relative / name).as_posix() for name in files + links
                  if include_bytecode or not name.endswith(('.pyc', '.pyo'))]
    return 'walk', names


def inventory(directory, untracked, include_bytecode=False):
    """(method, {path: 'mode sha256'}); links are recorded by target text, never followed."""
    method, names = listing(directory, untracked, include_bytecode)
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
    candidate_method, after = inventory(candidate, ('.git',), include_bytecode=True)
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
    # A reader that is itself a changed path is still a reader of the target.
    found, seen, pending = {}, set(), [(target, target) for target in targets]
    while pending:
        current, origin = pending.pop()
        for reader in sorted(readers.get(current, ())):
            if reader not in seen and reader != origin:
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


def assess(base, candidate, mode, before, after, approved, records):
    verified = {'impl/Ledger.dfy'} | set(approved)
    """Classify every change against the obligation graph; an empty 'findings' list means full coverage.

    records: obligation name -> run record (from obligations.run) for the affected obligations.
    """
    rows = changes(before, after)
    changed = [row['path'] for row in rows]
    covered_paths = obligations.all_inputs()
    for row in rows:
        row['covered_by'] = sorted(name for name in ['ledger-proof'] + list(obligations.OBLIGATIONS)
                                   if row['path'] in obligations.inputs_of(name))
    findings = [{'path': row['path'], 'reason': 'UNCOVERED_CHANGE',
                 'detail': row['change'] + '; no obligation lists this path as an input'}
                for row in rows if not row['covered_by']]
    for path, names in sorted(obligations.not_reestablishable(changed, verified).items()):
        findings.append({'path': path, 'reason': 'NOT_REESTABLISHABLE',
                         'detail': 'bound input of ' + ', '.join(names) + ': the obligation runs this file '
                         'as part of its harness, so a changed copy cannot be judged by it; '
                         'the change needs a gate update under review'})
    # A reader of a changed file must belong to an obligation that also depends on that file.
    for reader, origin in sorted(dafny_dependents(candidate, after, changed).items()):
        names = [name for name in ['ledger-proof'] + list(obligations.OBLIGATIONS)
                 if reader in obligations.inputs_of(name) and origin in obligations.inputs_of(name)]
        if not names:
            findings.append({'path': origin, 'reason': 'UNKNOWN_DEPENDENCY',
                             'detail': reader + ' includes it (directly or transitively); no obligation depends on both'})
    for lock, target in lock_dependents(base, changed):
        names = [name for name in obligations.OBLIGATIONS
                 if lock in obligations.inputs_of(name) and target in obligations.inputs_of(name)]
        if not names:
            findings.append({'path': target, 'reason': 'UNKNOWN_DEPENDENCY',
                             'detail': lock + ' pins its digest; no obligation depends on both'})
    affected = obligations.affected(changed)
    uncovered = any(f['reason'] in ('UNCOVERED_CHANGE', 'NOT_REESTABLISHABLE') for f in findings)
    for name in affected:
        if name == 'ledger-proof':
            continue
        record = records.get(name)
        if record is None and uncovered:
            continue  # obligations are not run while a change is uncovered; the finding above explains it
        if record is None or record.get('result') != 'established':
            findings.append({'path': name, 'reason': 'OBLIGATION_NOT_ESTABLISHED',
                             'detail': (record or {}).get('reason', 'no record')})
    claims = []
    for name in ['ledger-proof'] + list(obligations.OBLIGATIONS):
        declaration = obligations.OBLIGATIONS.get(name)
        if name == 'ledger-proof':
            status = 'established (fresh snapshot proof on the candidate)'
            claim_methods = {claim: 'source_proof' for claim in ('C1', 'C2', 'C3', 'C4', 'C5')}
            scope = 'impl/Ledger.dfy refines the approved ledger spec'
        else:
            claim_methods, scope = declaration['claims'], declaration['scope']
            if name in records:
                record = records[name]
                status = ('established (reused: identical input digests)' if record.get('reused')
                          else 'established (fresh run)') if record.get('result') == 'established' else record.get('result')
            else:
                status = 'not affected by this change (not re-run; no new claim made)'
        claims.append({'obligation': name, 'scope': scope, 'claims': claim_methods, 'status': status,
                       'affected': name in affected})
    return {'inventory': mode, 'changed': rows, 'affected_obligations': affected, 'obligations': records,
            'claims': claims, 'findings': findings, 'covered': not findings}


def summary(result, limit=12):
    shown = ['%s %s (%s)' % (f['reason'], f['path'], f['detail']) for f in result['findings'][:limit]]
    more = len(result['findings']) - len(shown)
    return '; '.join(shown) + ('; and %d more' % more if more > 0 else '')
