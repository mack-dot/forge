"""Separate evidence reader for the P2 continuation (U371-U373).

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r7.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
STEP = ROOT / 'refund-p2-lab-invariant-local-20261113/attempt-0002'
RUN = ROOT / 'refund-p2-lab-run-local-20261113/attempt-0001'
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


def checked(lines):
    return sum(1 for line in lines if line.startswith('CHECKED '))


def imported(lines):
    return sum(1 for line in lines if line.startswith('IMPORTED ') and line.endswith('EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0'))


def axioms(lines):
    return {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}


# Generic one-step, whole-run and prefix theorems.
step, lines = case(STEP, 'step-0002', 0, ('P2_PROOF_COMPLETE', 'CHECKED region_one_step', 'CHECKED region_prefix', 'CHECKED region_step_callffi'))
require(checked(lines) == 17, 'step: expected seventeen checked theorems')
rep, _ = case(STEP, 'step-repeat-0002', 0, ('P2_PROOF_COMPLETE',))
require(rep['objects'] == step['objects'] and rep['source_sha256'] == step['source_sha256'], 'step repeat: not byte-identical')
_, lines = case(STEP, 'step-import-0002', 0, ('P2_IMPORT_COMPLETE',))
require(imported(lines) == 5 and axioms(lines) == BOOL_AXIOMS, 'step import: statements or axioms')
case(STEP, 'step-missing-hyp', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing static hypothesis')
case(STEP, 'step-refute-weakened-v3', 1, ('AFTER_POSITIVE_AUDIT',), 'Weakened claim refuted by a concrete run')
case(STEP, 'step-0001', 1)              # script error in the witness term; nothing exported
require(json.loads((STEP / 'step-0001/command.json').read_text())['objects'] == {}, 'step-0001: unexpected exports')
# Generic walk bridge.
walk, lines = case(STEP, 'walk-0001', 0, ('P2_PROOF_COMPLETE', 'CHECKED hyp_walk_region_hyp'))
wrep, _ = case(STEP, 'walk-repeat', 0, ('P2_PROOF_COMPLETE',))
require(wrep['objects'] == walk['objects'], 'walk repeat: not byte-identical')
_, lines = case(STEP, 'walk-import', 0, ('P2_IMPORT_COMPLETE',))
require(imported(lines) == 2 and axioms(lines) == BOOL_AXIOMS, 'walk import: statements or axioms')
# Application to the exact lab program.
run, lines = case(RUN, 'run-0001', 0, ('RUN_PROOF_COMPLETE', 'CHECKED refund_lab_run_avoids_install'))
require(checked(lines) == 5, 'run: expected five checked theorems')
rrep, _ = case(RUN, 'run-repeat', 0, ('RUN_PROOF_COMPLETE',))
require(rrep['objects'] == run['objects'], 'run repeat: not byte-identical')
_, lines = case(RUN, 'run-import', 0, ('RUN_IMPORT_COMPLETE',))
require(imported(lines) == 4 and axioms(lines) == BOOL_AXIOMS, 'run import: statements or axioms')
require(not any('forge_refundArm8Compile$oracle' in line for line in lines), 'run import: the unspecified oracle occurs')
case(RUN, 'run-missing-premise', 1, ('AFTER_POSITIVE_AUDIT',), 'Exact statement mismatch: missing value premise on the start state')
case(RUN, 'run-naive', 1, ('AFTER_POSITIVE_AUDIT',), 'Walk check rejected for section 29 alone: F')
init, lines = case(RUN, 'init-0002', 0, ('RUN_PROOF_COMPLETE', 'CHECKED refund_lab_init_run_avoids_install'))
irep, _ = case(RUN, 'init-repeat', 0, ('RUN_PROOF_COMPLETE',))
require(irep['objects'] == init['objects'], 'init repeat: not byte-identical')
_, lines = case(RUN, 'init-import', 0, ('RUN_IMPORT_COMPLETE', 'ORACLE_CONSTANTS forge_refundLabClosure$refund_alloc_oracle,backend$set_oracle'))
require(imported(lines) == 1 and axioms(lines) == BOOL_AXIOMS, 'init import: statements or axioms')

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
