"""Separate evidence reader for the 2026-11-13 continuation (U360-U363).

It imports no producer code and runs no HOL or container. It binds bytes, exits
and markers only. An exit code is not semantic verification: this reader cannot
tell whether a theorem is true or who made a file.

Usage: python3 -I -B verify_cases_r4.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
HANDLER = ROOT / 'refund-install-handler-local-20261113/attempt-0001'
REPLAY = ROOT / 'm1-clean-replay-20261113'
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(name, exit_code, markers=(), absent=('UNEXPECTED_CONTROL_ACCEPTANCE',), stderr_has=None):
    path = HANDLER / name
    record = json.loads((path / 'command.json').read_text())
    lines = (path / 'stdout.log').read_text(errors='replace').splitlines()
    err = (path / 'stderr.log').read_text(errors='replace')
    require(record['actual_exit'] == exit_code, name + ': exit %r, expected %r' % (record['actual_exit'], exit_code))
    require(record['stdout_sha256'] == sha(path / 'stdout.log'), name + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(path / 'stderr.log'), name + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(path / 'proof.sml'), name + ': executed source differs from record')
    require(record['source_sha256'] == sha(HANDLER / record['source']), name + ': kept source differs from record')
    require(record['inputs_unchanged_after'] is True and record['wall_timeout'] is False, name + ': inputs or timeout')
    for marker in markers:
        require(marker in lines, name + ': missing marker ' + marker)
    for marker in absent:
        require(marker not in lines, name + ': forbidden marker ' + marker)
    if stderr_has:
        require(stderr_has in err, name + ': stderr lacks ' + stderr_has)
    for rel, digest in record['objects'].items():
        require(sha(path / rel) == digest, name + ': export differs from record: ' + rel)
    return record, lines


# Local proof, import, repeat and controls.
proof, proof_lines = case('proof-0001', 0, ('HANDLER_PROOF_COMPLETE', 'REMOVED_CLAUSES 1'))
require(len(proof['objects']) == 4, 'proof-0001: expected four exports')
require(sum(1 for line in proof_lines if line.startswith('CHECKED ')) == 4, 'proof-0001: expected four checked theorems')
repeat, _ = case('repeat', 0, ('HANDLER_PROOF_COMPLETE',))
require(repeat['objects'] == proof['objects'], 'repeat: exports are not byte-identical to proof-0001')
require(repeat['source_sha256'] == proof['source_sha256'], 'repeat: source differs from proof-0001')
_, import_lines = case('import', 0, ('HANDLER_IMPORT_COMPLETE',))
require(sum(1 for line in import_lines if line.startswith('IMPORTED ') and line.endswith('EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0')) == 4,
        'import: expected four exact imports')
require({line.split(' ', 1)[1] for line in import_lines if line.startswith('CLOSURE_AXIOM ')} == BOOL_AXIOMS, 'import: axiom set')
case('missing-exclusion', 1, ('AFTER_POSITIVE_AUDIT',), stderr_has='Exact statement mismatch: missing installer exclusion')
case('wrong-return-register-v2', 1, ('AFTER_POSITIVE_AUDIT',), stderr_has='MATCH_MP_TAC')
stop, _ = case('wrong-return-register', -24, ('AFTER_POSITIVE_AUDIT',))  # resource stop; not counted as a rejection
_, search_lines = case('search-install-pc', 0, ('EXPLORE_COMPLETE', 'CONCLUDE_PC_INEQUALITY 4'))
require(not any(line.startswith('CONCLUSION_HIT ') and 'evaluate' in line for line in search_lines), 'search: unexpected evaluator hit')

# Clean-container replay: attempt-0001 keeps its script error; attempt-0002 is the counted run.
first = REPLAY / 'attempt-0001'
require((first / 'container-exit.txt').read_text().strip() == '30', 'replay attempt-0001: recorded exit is not 30')
second = REPLAY / 'attempt-0002'
require((second / 'container-exit.txt').read_text().strip() == '0', 'replay attempt-0002: container exit is not 0')
recorded_inputs = dict(reversed(line.split('  ', 1)) for line in (second / 'inputs.sha256').read_text().splitlines())
for rel, digest in recorded_inputs.items():
    require(sha(second / rel) == digest, 'replay: input differs from record: ' + rel)
steps = [line.split('\t') for line in (second / 'out/steps.tsv').read_text().splitlines()]
require(len(steps) == 12 and all(step[1] == '0' for step in steps), 'replay: a build step did not exit 0')
cases = {line.split('\t')[0]: line.split('\t')[1:] for line in (second / 'out/cases.tsv').read_text().splitlines()}
expected = {'compose-0001': '0', 'compose-import': '0', 'wrong-status': '1',
            'install-site-0001': '0', 'install-import': '0', 'wrong-target': '1'}
require({k: v[0] for k, v in cases.items()} == expected, 'replay: case exits differ from expected')
for name, marker in (('compose-0001', 'NATIVE_STEP_COMPLETE'), ('compose-import', 'NATIVE_IMPORT_COMPLETE'),
                     ('install-site-0001', 'NATIVE_STEP_COMPLETE'), ('install-import', 'NATIVE_IMPORT_COMPLETE'),
                     ('wrong-status', 'AFTER_POSITIVE_AUDIT'), ('wrong-target', 'AFTER_POSITIVE_AUDIT')):
    lines = (second / 'out' / name / 'stdout.log').read_text(errors='replace').splitlines()
    require(marker in lines, 'replay ' + name + ': missing marker ' + marker)
    require('UNEXPECTED_CONTROL_ACCEPTANCE' not in lines, 'replay ' + name + ': forbidden marker')
# The proof sources in the container are the host sources; the exports equal the host exports.
host = {'compose-0001': (ROOT / 'refund-arm8-compose-local-20261112/attempt-0001', 'compose-0001'),
        'install-site-0001': (ROOT / 'refund-install-site-local-20261112/attempt-0001', 'install-site-0001')}
for name, (folder, host_case) in host.items():
    record = json.loads((folder / host_case / 'command.json').read_text())
    require(sha(second / 'out' / name / 'proof.sml') == record['source_sha256'], 'replay ' + name + ': source differs from host record')
    for rel, digest in record['objects'].items():
        if rel.startswith('.hol/objs/'):
            require(sha(second / 'out' / name / rel) == digest, 'replay ' + name + ': export differs from host export: ' + rel)

print(json.dumps({'failures': failures, 'end_to_end': False,
                  'scope': 'Bytes, exits and markers only. Not semantic verification.'}, indent=1))
raise SystemExit(1 if failures else 0)
