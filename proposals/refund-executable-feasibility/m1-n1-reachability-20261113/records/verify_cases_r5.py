"""Separate evidence reader for the N1 continuation (U364-U365).

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r5.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
N1 = ROOT / 'refund-n1-reachability-local-20261113/attempt-0001'
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(name, exit_code, markers=(), stderr_has=None):
    path = N1 / name
    record = json.loads((path / 'command.json').read_text())
    lines = (path / 'stdout.log').read_text(errors='replace').splitlines()
    require(record['actual_exit'] == exit_code, name + ': exit %r, expected %r' % (record['actual_exit'], exit_code))
    require(record['stdout_sha256'] == sha(path / 'stdout.log'), name + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(path / 'stderr.log'), name + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(path / 'proof.sml'), name + ': executed source differs from record')
    require(record['source_sha256'] == sha(N1 / record['source']), name + ': kept source differs from record')
    require(record['inputs_unchanged_after'] is True and record['wall_timeout'] is False, name + ': inputs or timeout')
    for marker in markers:
        require(marker in lines, name + ': missing marker ' + marker)
    require('UNEXPECTED_CONTROL_ACCEPTANCE' not in lines, name + ': forbidden marker')
    if stderr_has:
        require(stderr_has in (path / 'stderr.log').read_text(errors='replace'), name + ': stderr lacks ' + stderr_has)
    for rel, digest in record['objects'].items():
        require(sha(path / rel) == digest, name + ': export differs from record: ' + rel)
    return record, lines


proof, lines = case('proof-0001', 0, ('N1_PROOF_COMPLETE', 'CHECKED install_stubs_unreferenced'))
require(sum(1 for line in lines if line.startswith('CHECKED ')) == 11, 'proof-0001: expected eleven checked theorems')
require(len(proof['objects']) == 3, 'proof-0001: expected three exports (.dat, .sig, .sml)')
repeat, _ = case('repeat', 0, ('N1_PROOF_COMPLETE',))
require(repeat['objects'] == proof['objects'] and repeat['source_sha256'] == proof['source_sha256'], 'repeat: not byte-identical')
_, lines = case('import', 0, ('N1_IMPORT_COMPLETE',))
require(sum(1 for line in lines if line.startswith('IMPORTED ') and line.endswith('EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0')) == 10,
        'import: expected ten exact imports')
require({line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')} == BOOL_AXIOMS, 'import: axiom set')
case('naive-statement', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: naive N1 without the InstallData exclusion')
case('naive-closure', 1, ('AFTER_POSITIVE_AUDIT',), 'Closure rejected for Install_location alone: F')
_, lines = case('explore-0016', 0, ('EXPLORE_COMPLETE',))
case('explore-0007', -15)  # stopped by the agent; not counted
_, lines = case('explore-0014', 0, ('CALLERS_OF 29 = [31]', 'CALLERS_OF 31 = [31]', 'CLOSED_29_31 T', 'CLOSED_29_ONLY F'))

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
