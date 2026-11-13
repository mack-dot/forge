"""Separate evidence reader for the 2026-11-12 continuation cases.

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. Artifact integrity is not semantic proof validity: this reader cannot
tell whether a theorem is true. It can tell whether the recorded files are the
files the HOL child read and wrote, and whether each case ended as recorded.

Usage: python3 -I -B verify_cases.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
NATIVE = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(folder, name, exit_code, markers=(), absent=(), objects=None, source=None):
    path = folder / name
    record = json.loads((path / 'command.json').read_text())
    out = (path / 'stdout.log').read_text(errors='replace')
    tag = folder.parent.name + '/' + name
    require(record['actual_exit'] == exit_code, tag + ': exit %r, expected %r' % (record['actual_exit'], exit_code))
    require(record['stdout_sha256'] == sha(path / 'stdout.log'), tag + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(path / 'stderr.log'), tag + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(path / 'proof.sml'), tag + ': executed source differs from record')
    require(record['inputs_unchanged_after'] is True and record['wall_timeout'] is False, tag + ': inputs or timeout')
    lines = out.splitlines()
    for marker in markers:
        require(marker in lines, tag + ': missing marker ' + marker)
    for marker in absent:
        require(marker not in out, tag + ': forbidden marker ' + marker)
    found = {str(p.relative_to(path)): sha(p) for p in sorted((path / '.hol').rglob('*')) if p.is_file()}
    require(found == record['objects'], tag + ': exported objects differ from record')
    if objects is not None:
        require(len(found) == objects, tag + ': object count %d, expected %d' % (len(found), objects))
    if source is not None:
        require(record['source_sha256'] == sha(folder / source), tag + ': source is not ' + source)
    return record, lines


def closure(lines, tag):
    axioms = {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}
    nodes = [line for line in lines if line.startswith('CLOSURE_NODE ')]
    require(axioms == BOOL_AXIOMS, tag + ': closure axioms are not the four Boolean axioms')
    return len(nodes)


summary = {}

# ARM8 six-step composition.
arm = ROOT / 'refund-arm8-compose-local-20261112/attempt-0001'
binding = json.loads((arm / 'statement-binding.json').read_text())
require(binding['native_sha256'] == NATIVE, 'arm8: statement is not bound to the native executable')
statement = (arm / 'statement.txt').read_text()
require(binding['code_premise'] in statement and binding['separation_premise'] in statement,
        'arm8: statement text does not contain the bound code bytes')
for name in ('compose-0001.sml', 'import.sml', 'wrong-status.sml', 'missing-separation-v2.sml', 'untaken-branch-v2.sml'):
    require(statement.rstrip('\n') in (arm / name).read_text(), 'arm8: ' + name + ' does not hold the statement text')
proof, _ = case(arm, 'compose-0001', 0, ['NATIVE_STEP_COMPLETE'], objects=4, source='compose-0001.sml')
repeat, _ = case(arm, 'repeat', 0, ['NATIVE_STEP_COMPLETE'], objects=4, source='compose-0001.sml')
require(proof['objects'] == repeat['objects'], 'arm8: repeat exports differ')
_, lines = case(arm, 'import', 0, ['NATIVE_IMPORT_COMPLETE', 'IMPORTED_ORACLES DISK_THM', 'IMPORTED_HYPOTHESES 0',
                                    'IMPORTED_TAGGED_AXIOMS 0'], objects=0, source='import.sml')
arm_nodes = closure(lines, 'arm8/import')
case(arm, 'wrong-status', 1, ['AFTER_POSITIVE_AUDIT'], ['UNEXPECTED_CONTROL_ACCEPTANCE'], 0, 'wrong-status.sml')
require('Exact statement mismatch: wrong status byte' in (arm / 'wrong-status/stderr.log').read_text(errors='replace'),
        'arm8/wrong-status: not the intended mismatch')
for name in ('missing-separation-v2', 'untaken-branch-v2'):
    case(arm, name, 1, ['AFTER_POSITIVE_AUDIT', 'CONTROL_HARNESS_PROVES_ORIGINAL'],
         ['UNEXPECTED_CONTROL_ACCEPTANCE'], 0, name + '.sml')
    require('first subgoal not solved by second tactic' in (arm / name / 'stderr.log').read_text(errors='replace'),
            'arm8/' + name + ': not the intended proof failure')
for name in ('missing-separation', 'untaken-branch'):   # first versions: script errors, never counted
    require('no current theory when proving' in (arm / name / 'stderr.log').read_text(errors='replace'),
            'arm8/' + name + ': preserved script error changed')
summary['ffiread_error_return'] = {'exports': proof['objects'], 'closure_nodes': arm_nodes,
                                   'candidate_sha256': proof['source_sha256']}

# Initializer machine-config corollary.
init = ROOT / 'refund-initializer-machine-local-20261112/attempt-0001'
proof, lines = case(init, 'machine-0001', 0, ['RUNTIME_PROOF_COMPLETE', 'REMAINING_ANTECEDENTS 6'], objects=4,
                    source='machine-0001.sml')
require(sum(1 for line in lines if line.startswith('DISCHARGED_CONDITION ')) == 9, 'initializer: discharged count')
repeat, _ = case(init, 'repeat', 0, ['RUNTIME_PROOF_COMPLETE', 'REMAINING_ANTECEDENTS 6'], objects=4, source='machine-0001.sml')
require(proof['objects'] == repeat['objects'], 'initializer: repeat exports differ')
_, lines = case(init, 'audit-0002', 0, ['TRACE_IMPORT_COMPLETE', 'IMPORTED_THEOREM refund_initialization_machine'],
                objects=0, source='audit.sml')
require(sum(1 for line in lines if line.startswith('KEPT_PREMISE ')) == 6, 'initializer: kept premise count')
init_nodes = closure(lines, 'initializer/audit-0002')
require(not (init / 'audit/command.json').exists(), 'initializer: interrupted audit has a result record')
require(not (init / 'no-machine-config').exists() and not (init / 'missing-memory').exists(),
        'initializer: controls exist; the reader must be extended before they count')
summary['refund_initialization_machine'] = {'exports': proof['objects'], 'closure_nodes': init_nodes,
                                            'candidate_sha256': proof['source_sha256'], 'controls': 'NOT_RUN'}

summary.update({'scope': 'Byte, exit and marker binding only. Not a proof checker. No independent replay.',
                'failures': failures, 'end_to_end': False})
print(json.dumps(summary, indent=1))
raise SystemExit(1 if failures else 0)
