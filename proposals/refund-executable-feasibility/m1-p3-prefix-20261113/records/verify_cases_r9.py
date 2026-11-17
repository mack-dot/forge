"""Separate evidence reader for the P3 preparation continuation (U377-U379).

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r9.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
RUN = ROOT / 'refund-p3-target-prefix-local-20261113/attempt-0001'
PUBLISHED = '6cfb4a5f85277e9e4de0ff83f14b515be5d100cedb9375f44e85b072d731b433'
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(name, exit_code, markers=(), stderr_has=None):
    path = RUN / name
    record = json.loads((path / 'command.json').read_text())
    lines = (path / 'stdout.log').read_text(errors='replace').splitlines()
    require(record['actual_exit'] == exit_code, name + ': exit %r, expected %r' % (record['actual_exit'], exit_code))
    require(record['stdout_sha256'] == sha(path / 'stdout.log'), name + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(path / 'stderr.log'), name + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(path / 'proof.sml'), name + ': executed source differs from record')
    require(record['source_sha256'] == sha(RUN / record['source']), name + ': kept source differs from record')
    require(record['inputs_unchanged_after'] is True and record['wall_timeout'] is False, name + ': inputs or timeout')
    for marker in markers:
        require(marker in lines, name + ': missing marker ' + marker)
    require('UNEXPECTED_CONTROL_ACCEPTANCE' not in lines, name + ': forbidden marker')
    if stderr_has:
        require(stderr_has in (path / 'stderr.log').read_text(errors='replace'), name + ': stderr lacks ' + stderr_has)
    for rel, digest in record['objects'].items():
        require(sha(path / rel) == digest, name + ': export differs from record: ' + rel)
    return record, lines


p, lines = case('prefix-0001', 0, ('P3_PROOF_COMPLETE', 'CHECKED no_install_prefix_segment', 'CHECKED no_install_prefix_next'))
require(sum(1 for line in lines if line.startswith('CHECKED ')) == 6, 'prefix: expected six checked theorems')
r, _ = case('prefix-repeat', 0, ('P3_PROOF_COMPLETE',))
require(r['objects'] == p['objects'] and r['source_sha256'] == p['source_sha256'], 'prefix repeat: not byte-identical')
_, lines = case('prefix-import', 0, ('P3_IMPORT_COMPLETE',))
require(sum(1 for line in lines if line.startswith('IMPORTED ')) == 6, 'prefix import: expected six statements')
require({line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')} == BOOL_AXIOMS, 'prefix import: axiom set')
case('prefix-missing-first', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing prefix fact for the first segment')
case('prefix-invalid-layout', 1, ('AFTER_POSITIVE_AUDIT',), 'Halt claim refuted for an invalid layout')
s, lines = case('statement-0002', 0, ('P3_PROOF_COMPLETE', 'FIDELITY published statement recovered by removing the two additions',
                                     'STRENGTHENED_STATEMENT (PROPOSED, NOT PROVED)', 'CHECKED refund_alloc_backend_correct',
                                     'ORACLE_CONSTANTS forge_refundLabClosure$refund_alloc_oracle,backend$set_oracle'))
require(any('no_install_prefix mc_conf s1.ffi (s1.clock + k) ms1' in line for line in lines), 'statement: prefix bound is not s1.clock + k')
sr, _ = case('statement-repeat', 0, ('P3_PROOF_COMPLETE',))
require(sr['objects'] == s['objects'], 'statement repeat: not byte-identical')
case('statement-0001', 0)   # superseded: its proposed statement had the wrong prefix bound
copy = Path(__file__).resolve().parent.parent / 'published/lab_to_targetProofScript.sml'
require(sha(copy) == PUBLISHED, 'published proof copy differs from the pinned source hash')

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
