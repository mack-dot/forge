"""Separate evidence reader for the five local read_error_generic cases.

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. It is not a proof checker and gives no independent proof assurance.

Usage: python3 -I -B validate_evidence.py
"""
from pathlib import Path
import hashlib, json, sys

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
FROZEN = {
    'import.sml': '3018afad63a80620fbf3f4ed04a606d1121da0cb77460c3cfea7542351b2bdc1',
    'wrong-exception.sml': 'c47b9f260e3e638a6fe91f75f263b37c4652bc68210447df0d3b898d308f19ee',
    'omitted-event.sml': 'd7cd686252cf99d571cee7a764720e7ff5db2ef1121d94416fd455601dee190e',
}
OLD_CANDIDATE = ROOT / 'proposals/refund-executable-feasibility/read-event-gap-20261107/records/generic-read-0001.sml'
OLD_SHA = '7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6'
NEW_SHA = '90e827dc782bcfe23f0518cca18facf649d434f59421d593bc436a187f003ae3'
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
MISMATCH = 'Exact generic read statement mismatch'
THEORY = 'forge_refundGenericReadError'
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(name):
    folder = OUT / name
    record = json.loads((folder / 'command.json').read_text())
    stdout = (folder / 'stdout.log').read_text()
    stderr = (folder / 'stderr.log').read_text()
    require(record['stdout_sha256'] == sha(folder / 'stdout.log'), name + ': stdout hash differs from record')
    require(record['stderr_sha256'] == sha(folder / 'stderr.log'), name + ': stderr hash differs from record')
    require(record['source_sha256'] == sha(folder / 'proof.sml'), name + ': executed source differs from record')
    require(record['inputs_unchanged_after'] is True, name + ': recorded inputs changed')
    require(record['wall_timeout'] is False, name + ': wall timeout')
    require(record['cpu_seconds_limit'] == 120 and record['wall_seconds_limit'] == 150, name + ': limits differ')
    objects = {str(p.relative_to(folder)): sha(p) for p in sorted((folder / '.hol').rglob('*')) if p.is_file()}
    require(objects == record['objects'], name + ': exported objects differ from record')
    return record, stdout, stderr


def statement(text):
    start = text.index('store_thm ("read_error_generic", ``')
    return text[start:text.index('``,\n  rpt strip_tac')]


old, new = OLD_CANDIDATE.read_text(), (OUT / 'generic-read-0002.sml').read_text()
require(sha(OLD_CANDIDATE) == OLD_SHA, 'frozen candidate 0001 changed')
require(sha(OUT / 'generic-read-0002.sml') == NEW_SHA, 'candidate 0002 changed')
require(statement(old) == statement(new), 'theorem statement bytes differ between candidates')
old_lines, new_lines = old.splitlines(), new.splitlines()
require(old_lines[:36] == new_lines[:36] and old_lines[40:] == new_lines[42:],
        'candidate 0002 differs outside the two tactic regions')
for name, digest in FROZEN.items():
    require(sha(OUT / name) == digest, name + ': not the frozen prepared input')

proof, out, err = case('proof-0001')
require(proof['actual_exit'] == 0 and proof['source_sha256'] == NEW_SHA, 'proof: exit or source')
require('CHECKED read_error_generic' in out and 'READ_EVENT_GAP_COMPLETE' in out, 'proof: markers')
require(len(proof['objects']) == 4, 'proof: object count')

repeat, out, err = case('repeat')
require(repeat['actual_exit'] == 0 and repeat['source_sha256'] == NEW_SHA, 'repeat: exit or source')
require('READ_EVENT_GAP_COMPLETE' in out, 'repeat: marker')
require(repeat['objects'] == proof['objects'], 'repeat: exports differ from proof')

imported, out, err = case('import')
lines = out.splitlines()
require(imported['actual_exit'] == 0 and imported['source_sha256'] == FROZEN['import.sml'], 'import: exit or source')
require('GENERIC_IMPORT_COMPLETE' in lines and not imported['objects'], 'import: marker or objects')
require('IMPORTED_ORACLES DISK_THM' in lines and 'IMPORTED_HYPOTHESES 0' in lines
        and 'IMPORTED_TAGGED_AXIOMS 0' in lines, 'import: oracle, hypothesis or axiom line')
nodes = [line.split(' ', 1)[1].split(':', 1)[0] for line in lines if line.startswith('CLOSURE_NODE ')]
axioms = {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}
require(nodes[:1] == [THEORY] and len(nodes) == len(set(nodes)), 'import: closure node list')
require(axioms == BOOL_AXIOMS, 'import: closure axioms are not the four Boolean axioms')
theory_inputs = [a for a in imported['argv'] if THEORY + 'Theory' in a]
require(theory_inputs == [str(OUT / 'proof-0001' / (THEORY + 'Theory' + s)) for s in ('.sig', '.sml')],
        'import: theory files are not the proof-0001 exports')

control_exits = {}
for name in ('wrong-exception', 'omitted-event'):
    control, out, err = case(name)
    control_exits[name] = control['actual_exit']
    require(control['actual_exit'] == 1 and control['source_sha256'] == FROZEN[name + '.sml'], name + ': exit or source')
    require(MISMATCH in err and 'GENERIC_IMPORT_COMPLETE' not in out and not control['objects'],
            name + ': not the intended statement-mismatch rejection')
    require('IMPORTED_THEOREM' not in out, name + ': theorem accepted before the mismatch check')

summary = {
    'cases': {'proof-0001': proof['actual_exit'], 'repeat': repeat['actual_exit'], 'import': imported['actual_exit'],
              **control_exits},
    'candidate_sha256': NEW_SHA, 'statement_sha256': hashlib.sha256(statement(new).encode()).hexdigest(),
    'exports': proof['objects'], 'closure_nodes': len(nodes), 'closure_axioms': sorted(axioms),
    'scope': 'Byte, exit and marker binding only. Not a proof checker. No independent replay.',
    'failures': failures, 'end_to_end': False,
}
print(json.dumps(summary, indent=1))
raise SystemExit(1 if failures else 0)
