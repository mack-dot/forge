"""Bind protected changes to an approval or a ratification in the trusted base checkout.

Two exact-bytes paths exist. Both read ONLY the trusted base checkout; nothing in the candidate authorizes anything.
1. Spec approval (unchanged): gate/approvals/*.json for spec/LedgerSpec.dfy with spec.lock.
2. Tier-0 gate ratification: governance/gate-ratifications/*.json for files under gate/ and toolchain/, except
   gate/approvals/ and gate/provenance/. The record names every changed protected file with its old and new SHA-256.
   A spec.lock file may be covered only when its new bytes are its old bytes with the digests of ratified toolchain
   files replaced (one pass).
"""

import re

from common import Rejected, digest, read_json

SPEC_PATHS = {'spec/LedgerSpec.dfy', 'spec.lock'}
RATIFICATION_DIR = 'governance/gate-ratifications'
RATIFIABLE_PREFIXES = ('gate/', 'toolchain/')
# Not ratifiable at Tier 0: spec approval records and the provenance (signing) trust files.
EXCLUDED_PREFIXES = ('gate/approvals/', 'gate/provenance/')
CONTROL_PREFIX = 'bugs/'
SHA256 = re.compile('[0-9a-f]{64}')


def _ratifiable(name):
    return name.startswith(RATIFIABLE_PREFIXES) and not name.startswith(EXCLUDED_PREFIXES)


def _trusted_file(root, relative, label):
    if not isinstance(relative, str) or not relative or relative.startswith('/') or '..' in relative.split('/'):
        raise Rejected(label + ': path in the trusted record is not a plain relative path')
    path = root / relative
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
        raise Rejected(label + ': trusted file is missing, a link, or outside the base checkout: ' + relative)
    return path


def _spec_approval(root, trusted, proposed):
    for path in sorted((root / 'gate/approvals').glob('*.json')):
        record = read_json(path)
        if (record.get('decision') != 'approved_as_written'
                or set(record.get('base_inputs', {})) != SPEC_PATHS
                or set(record.get('approved_inputs', {})) != SPEC_PATHS):
            continue
        if (all(trusted.get(name) == value for name, value in record['base_inputs'].items())
                and all(proposed.get(name) == value for name, value in record['approved_inputs'].items())):
            proposal = root / record['proposal']
            if (proposal.is_symlink() or not proposal.resolve().is_relative_to(root.resolve())
                    or digest(proposal.read_bytes()) != record['proposal_sha256']):
                raise Rejected('APPROVAL_BINDING: trusted proposal differs from the approved text')
            return {'record': path.relative_to(root).as_posix(),
                    'record_sha256': digest(path.read_bytes()),
                    'proposal_revision': record['proposal_revision'],
                    'proposal_sha256': record['proposal_sha256'],
                    'base_inputs': record['base_inputs'],
                    'approved_inputs': record['approved_inputs']}
    return None


def _lock_rebind_only(root, candidate, name, files, trusted, proposed):
    """True only if the new lock bytes are the old bytes with ratified toolchain digests replaced."""
    if candidate is None or name.rsplit('/', 1)[-1] != 'spec.lock' or not trusted.get(name) or not proposed.get(name):
        return False
    old_path, new_path = root / name, candidate / name
    if old_path.is_symlink() or new_path.is_symlink() or not old_path.is_file() or not new_path.is_file():
        return False
    old_bytes, new_bytes = old_path.read_bytes(), new_path.read_bytes()
    if digest(old_bytes) != trusted[name] or digest(new_bytes) != proposed[name]:
        return False
    try:
        text = old_bytes.decode('utf-8')
    except UnicodeDecodeError:
        return False
    # One pass, all digests at once: a new digest is never replaced again.
    mapping = {}
    for other, entry in files.items():
        if other.startswith('toolchain/') and entry['old_sha256'] and entry['new_sha256']:
            if mapping.get(entry['old_sha256'], entry['new_sha256']) != entry['new_sha256']:
                return False
            mapping[entry['old_sha256']] = entry['new_sha256']
    replaced = []
    def swap(match):
        if match.group(0) in mapping:
            replaced.append(match.group(0))
            return mapping[match.group(0)]
        return match.group(0)
    return SHA256.sub(swap, text).encode('utf-8') == new_bytes and bool(replaced)


def _controls(record, root):
    controls = record.get('controls')
    if not isinstance(controls, list):
        raise Rejected('RATIFICATION_BINDING: the trusted record has no list of controls')
    seen = set()
    for control in controls:
        path = control.get('path') if isinstance(control, dict) else None
        if (not isinstance(control, dict) or set(control) != {'path', 'sha256', 'expect'} or control['expect'] != 'rejected'
                or not isinstance(path, str) or not path.startswith(CONTROL_PREFIX) or not path.endswith('.dfy')
                or '/' in path[len(CONTROL_PREFIX):] or '..' in path or path in seen
                or not isinstance(control['sha256'], str) or not SHA256.fullmatch(control['sha256'])):
            raise Rejected('RATIFICATION_BINDING: malformed control in the trusted record')
        if (root / path).exists() or (root / path).is_symlink():
            raise Rejected('RATIFICATION_BINDING: a control may not replace a planted bug of the trusted base: ' + path)
        seen.add(path)
    return controls


def _gate_ratification(root, trusted, proposed, changed, candidate):
    folder = root / RATIFICATION_DIR
    if not folder.exists():
        return None
    if folder.is_symlink() or not folder.is_dir():
        raise Rejected('RATIFICATION_BINDING: the trusted ratification folder is not a plain directory')
    for path in sorted(folder.glob('*.json')):
        if path.is_symlink() or not path.is_file():
            raise Rejected('RATIFICATION_BINDING: a trusted ratification record is not a plain file: ' + path.name)
        record = read_json(path)
        files = record.get('files') if isinstance(record, dict) else None
        tier = record.get('tier') if isinstance(record, dict) else None
        if (not isinstance(files, dict) or record.get('decision') != 'ratified_as_written'
                or not isinstance(tier, int) or isinstance(tier, bool) or tier != 0
                or record.get('end_to_end') is not False or set(files) != set(changed)):
            continue
        if not all(isinstance(files[name], dict) and set(files[name]) == {'old_sha256', 'new_sha256'}
                   and files[name]['old_sha256'] == trusted.get(name)
                   and files[name]['new_sha256'] == proposed.get(name) for name in changed):
            continue
        for name in changed:
            if not _ratifiable(name) and not _lock_rebind_only(root, candidate, name, files, trusted, proposed):
                raise Rejected('RATIFICATION_SCOPE: a gate ratification cannot cover ' + name)
        proposal = _trusted_file(root, record.get('proposal'), 'RATIFICATION_BINDING')
        if digest(proposal.read_bytes()) != record.get('proposal_sha256'):
            raise Rejected('RATIFICATION_BINDING: trusted proposal differs from the ratified text')
        return {'kind': 'gate_ratification', 'tier': 0,
                'record': path.relative_to(root).as_posix(),
                'record_sha256': digest(path.read_bytes()),
                'proposal_sha256': record['proposal_sha256'],
                'files': files, 'controls': _controls(record, root),
                # Same shape as a spec approval, for the code that treats approved files as verified inputs.
                'base_inputs': {name: files[name]['old_sha256'] for name in changed if files[name]['old_sha256']},
                'approved_inputs': {name: files[name]['new_sha256'] for name in changed if files[name]['new_sha256']}}
    return None


def authorize(root, trusted, proposed, candidate=None):
    changed = sorted(name for name in trusted.keys() | proposed.keys()
                     if trusted.get(name) != proposed.get(name))
    if not changed:
        return None
    if set(changed) == SPEC_PATHS:
        approval = _spec_approval(root, trusted, proposed)
        if approval:
            return approval
    ratification = _gate_ratification(root, trusted, proposed, changed, candidate)
    if ratification:
        return ratification
    raise Rejected('UNAPPROVED_PROTECTED_CHANGE: ' + ', '.join(changed)
                   + '; approval of exact spec text or a Tier-0 ratification of exact gate bytes in the trusted base'
                   + ' is required; PR labels and candidate files do not authorize it')
