"""Bind protected spec changes to an approval in the trusted base checkout."""

from common import Rejected, canonical, digest, read_json


def authorize(root, trusted, proposed):
    changed = sorted(name for name in trusted.keys() | proposed.keys()
                     if trusted.get(name) != proposed.get(name))
    if not changed:
        return None
    expected_paths = {'spec/LedgerSpec.dfy', 'spec.lock'}
    if set(changed) == expected_paths:
        for path in sorted((root / 'gate/approvals').glob('*.json')):
            record = read_json(path)
            if (record.get('decision') != 'approved_as_written'
                    or set(record.get('base_inputs', {})) != expected_paths
                    or set(record.get('approved_inputs', {})) != expected_paths):
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
    raise Rejected('UNAPPROVED_PROTECTED_CHANGE: ' + ', '.join(changed)
                   + '; approval of exact spec text is required; PR labels do not authorize it')
