"""Separate evidence reader for the P1/P2 continuation (U368-U370).

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r6.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
P1 = ROOT / 'refund-p1-lab-closure-local-20261113/attempt-0001'
P2 = ROOT / 'refund-p2-lab-invariant-local-20261113/attempt-0001'
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(folder, name, exit_code, markers=(), stderr_has=None):
    path = folder / name
    record = json.loads((path / 'command.json').read_text())
    lines = (path / 'stdout.log').read_text(errors='replace').splitlines()
    tag = folder.parent.name + '/' + name
    require(record['actual_exit'] == exit_code, tag + ': exit %r, expected %r' % (record['actual_exit'], exit_code))
    require(record['stdout_sha256'] == sha(path / 'stdout.log'), tag + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(path / 'stderr.log'), tag + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(path / 'proof.sml'), tag + ': executed source differs from record')
    require(record['source_sha256'] == sha(folder / record['source']), tag + ': kept source differs from record')
    require(record['inputs_unchanged_after'] is True and record['wall_timeout'] is False, tag + ': inputs or timeout')
    for marker in markers:
        require(marker in lines, tag + ': missing marker ' + marker)
    require('UNEXPECTED_CONTROL_ACCEPTANCE' not in lines, tag + ': forbidden marker')
    if stderr_has:
        require(stderr_has in (path / 'stderr.log').read_text(errors='replace'), tag + ': stderr lacks ' + stderr_has)
    for rel, digest in record['objects'].items():
        require(sha(path / rel) == digest, tag + ': export differs from record: ' + rel)
    return record, lines


def axioms(lines):
    return {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}


def imported(lines):
    return sum(1 for line in lines if line.startswith('IMPORTED ') and line.endswith('EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0'))


# P1: lab closure.
proof, lines = case(P1, 'proof-0001', 0, ('P1_PROOF_COMPLETE', 'SAME_AS_STORED code data ffis conf', 'CHECKED refund_lab_install_closure'))
require(sum(1 for line in lines if line.startswith('CHECKED ')) == 9, 'p1 proof: expected nine checked theorems')
repeat, _ = case(P1, 'repeat', 0, ('P1_PROOF_COMPLETE', 'SAME_AS_STORED code data ffis conf'))
require(repeat['objects'] == proof['objects'] and repeat['source_sha256'] == proof['source_sha256'], 'p1 repeat: not byte-identical')
_, lines = case(P1, 'import', 0, ('P1_IMPORT_COMPLETE', 'ORACLE_IS_DEFINED true entries 552'))
require(imported(lines) == 8 and axioms(lines) == BOOL_AXIOMS, 'p1 import: statements or axioms')
case(P1, 'naive-statement', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: naive P1 without the InstallData exclusion')
case(P1, 'naive-closure', 1, ('AFTER_POSITIVE_AUDIT',), 'Lab closure rejected for section 29 alone: F')
# Resolution level.
rproof, lines = case(P1, 'resolve-0001', 0, ('P1_PROOF_COMPLETE', 'CHECKED refund_lab_refs_resolve_outside'))
rrepeat, _ = case(P1, 'resolve-repeat', 0, ('P1_PROOF_COMPLETE',))
require(rrepeat['objects'] == rproof['objects'], 'resolve repeat: not byte-identical')
_, lines = case(P1, 'resolve-import', 0, ('P1_IMPORT_COMPLETE',))
require(imported(lines) == 5 and axioms(lines) == BOOL_AXIOMS, 'resolve import: statements or axioms')
case(P1, 'resolve-naive', 1, ('AFTER_POSITIVE_AUDIT',), 'Resolution check rejected for section 29 alone: F')
case(P1, 'explore-0004', -24)   # resource stop, not counted
# P2: two lemmas only.
lproof, lines = case(P2, 'lemmas-0001', 0, ('P2_PROOF_COMPLETE', 'CHECKED asm_inst_val_inv', 'CHECKED write_bytearray_val_inv'))
require(any(line.startswith('PROPOSED_NOT_PROVED one_step') for line in lines), 'p2: the open lemma is not marked as proposed')
lrepeat, _ = case(P2, 'lemmas-repeat', 0, ('P2_PROOF_COMPLETE',))
require(lrepeat['objects'] == lproof['objects'], 'p2 repeat: not byte-identical')
_, lines = case(P2, 'lemmas-import', 0, ('P2_IMPORT_COMPLETE',))
require(imported(lines) == 2 and axioms(lines) == BOOL_AXIOMS, 'p2 import: statements or axioms')
case(P2, 'lemmas-missing-premise', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing Word premise')
case(P2, 'explore-0004', -24)
case(P2, 'explore-0017', -24)

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
