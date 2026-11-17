"""Separate evidence reader for the lab-level exclusion continuation (U374-U376).

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r8.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
ALIGNED = ROOT / 'refund-p2-lab-aligned-local-20261113/attempt-0001'
EXCL = ROOT / 'refund-p2-lab-init-local-20261113/attempt-0001'
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


def count(lines, prefix):
    return sum(1 for line in lines if line.startswith(prefix))


def axioms(lines):
    return {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}


a, lines = case(ALIGNED, 'aligned-0001', 0, ('P2_PROOF_COMPLETE', 'CHECKED region2_prefix', 'CHECKED all_address_premise_not_implied'))
require(count(lines, 'CHECKED ') == 20, 'aligned: expected twenty checked theorems')
ar, _ = case(ALIGNED, 'aligned-repeat', 0, ('P2_PROOF_COMPLETE',))
require(ar['objects'] == a['objects'] and ar['source_sha256'] == a['source_sha256'], 'aligned repeat: not byte-identical')
_, lines = case(ALIGNED, 'aligned-import', 0, ('P2_IMPORT_COMPLETE',))
require(count(lines, 'IMPORTED ') == 5 and axioms(lines) == BOOL_AXIOMS, 'aligned import: statements or axioms')
case(ALIGNED, 'aligned-missing-coverage', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing coverage condition')
e, lines = case(EXCL, 'excl-0001', 0, ('RUN_PROOF_COMPLETE', 'CHECKED refund_lab_good_init_avoids_install', 'CHECKED refund_lab_aligned_init_avoids_install'))
er, _ = case(EXCL, 'excl-repeat', 0, ('RUN_PROOF_COMPLETE',))
require(er['objects'] == e['objects'] and er['source_sha256'] == e['source_sha256'], 'exclusion repeat: not byte-identical')
_, lines = case(EXCL, 'excl-import', 0, ('RUN_IMPORT_COMPLETE', 'PREMISE_COUNT 2', 'PREMISE_HEADS good_init_state,=evaluate',
     'PREMISES_MENTION loc_good=false val_inv=false mval_inv=false region_hyp=false',
     'ORACLE_CONSTANTS forge_refundLabClosure$refund_alloc_oracle,backend$set_oracle'))
require(count(lines, 'IMPORTED ') == 2 and axioms(lines) == BOOL_AXIOMS, 'exclusion import: statements or axioms')
case(EXCL, 'excl-missing-init', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing initial-state premise')

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
