"""Separate evidence reader for the second 2026-11-12 continuation.

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true. It checks that the recorded files are the files the
HOL child read and wrote and that each case ended as recorded.

Usage: python3 -I -B verify_cases_r2.py [<results root override>]
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/Users/mackianni/forge/results')
BOOL_AXIOMS = {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
failures = []


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        failures.append(message)


def case(folder, name, exit_code, markers=(), absent=(), objects=None, source=None, stderr_has=None):
    path = folder / name
    record = json.loads((path / 'command.json').read_text())
    out = (path / 'stdout.log').read_text(errors='replace')
    err = (path / 'stderr.log').read_text(errors='replace')
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
    if stderr_has is not None:
        require(stderr_has in err, tag + ': stderr lacks ' + repr(stderr_has))
    return record, lines


def closure(lines, tag):
    axioms = {line.split(' ', 1)[1] for line in lines if line.startswith('CLOSURE_AXIOM ')}
    require(axioms == BOOL_AXIOMS, tag + ': closure axioms are not the four Boolean axioms')
    return sum(1 for line in lines if line.startswith('CLOSURE_NODE '))


CONTROL = dict(absent=['UNEXPECTED_CONTROL_ACCEPTANCE'], objects=0)
summary = {}

# 1. Basis-oracle instance of read_error_generic, and the oracle lemma.
ffi = ROOT / 'refund-ffi-instance-local-20261112/attempt-0001'
old = ROOT / 'refund-ffi-oracle-local-20261112/attempt-0001'
case(ffi, 'explore-0001', 1, source='explore-0001.sml')          # script error: theory file not supplied
case(ffi, 'explore-0002', 0, ['EXPLORE_COMPLETE'], objects=0)
proof, _ = case(ffi, 'instance-0001', 0, ['FFI_INSTANCE_COMPLETE'], objects=4, source='instance-0001.sml')
repeat, _ = case(ffi, 'repeat', 0, ['FFI_INSTANCE_COMPLETE'], objects=4, source='instance-0001.sml')
require(proof['objects'] == repeat['objects'], 'ffi: instance repeat exports differ')
_, lines = case(ffi, 'import', 0, ['FFI_IMPORT_COMPLETE', 'IMPORTED_ORACLES DISK_THM', 'IMPORTED_HYPOTHESES 0',
                                    'IMPORTED_TAGGED_AXIOMS 0'], objects=0, source='import.sml')
ffi_nodes = closure(lines, 'ffi/import')
case(ffi, 'wrong-exception', 1, ['AFTER_POSITIVE_AUDIT'], source='wrong-exception.sml',
     stderr_has='Exact statement mismatch: wrong exception', **CONTROL)
for name in ('instance-missing-read-none', 'oracle-missing-read-none'):
    case(ffi, name, 1, ['AFTER_POSITIVE_AUDIT', 'CONTROL_HARNESS_PROVES_ORIGINAL'], source=name + '.sml',
         stderr_has='unsolved goals', **CONTROL)
orig = json.loads((old / 'oracle-0001/command.json').read_text())
again, _ = case(ffi, 'oracle-repeat', 0, ['FFI_ORACLE_COMPLETE'], objects=4, source='oracle-0001.sml')
require(again['objects'] == orig['objects'] and again['source_sha256'] == orig['source_sha256'],
        'ffi: oracle repeat differs from oracle-0001')
for text, name in (('instance-statement.txt', 'instance-0001.sml'), ('instance-statement.txt', 'import.sml'),
                   ('oracle-statement.txt', 'import.sml')):
    require((ffi / text).read_text().rstrip('\n') in (ffi / name).read_text(), 'ffi: ' + name + ' lacks ' + text)
summary['read_error_basis_instance'] = {'exports': proof['objects'], 'closure_nodes': ffi_nodes,
                                        'candidate_sha256': proof['source_sha256']}

# 2. Controls for the six-premise initializer theorem (U349).
mach = ROOT / 'refund-initializer-machine-local-20261112/attempt-0001'
case(mach, 'no-machine-config', 1, ['AFTER_POSITIVE_AUDIT', 'CONTROL_HARNESS_PROVES_ORIGINAL'],
     source='no-machine-config.sml', stderr_has='unsolved goals', **CONTROL)
limit, _ = case(mach, 'missing-memory', -24, ['AFTER_POSITIVE_AUDIT', 'CONTROL_HARNESS_PROVES_ORIGINAL'],
                source='missing-memory.sml', **CONTROL)        # CPU limit: a resource stop, never counted
case(mach, 'missing-memory-statement', 1, ['AFTER_POSITIVE_AUDIT'], source='missing-memory-statement.sml',
     stderr_has='Exact statement mismatch: missing memory_assumption', **CONTROL)
summary['refund_initialization_machine_controls'] = {'no-machine-config': 1, 'missing-memory': 'CPU limit, not counted',
                                                     'missing-memory-statement': 1}

# 3. Two-premise initializer corollary.
al = ROOT / 'refund-initializer-aligned-local-20261112/attempt-0001'
proof, lines = case(al, 'aligned-0001', 0, ['RUNTIME_PROOF_COMPLETE', 'REMAINING_ANTECEDENTS 2'], objects=4,
                    source='aligned-0001.sml')
require(sum(1 for line in lines if line.startswith('DISCHARGED_CONDITION ')) == 4, 'aligned: discharged count')
repeat, _ = case(al, 'repeat', 0, ['RUNTIME_PROOF_COMPLETE', 'REMAINING_ANTECEDENTS 2'], objects=4, source='aligned-0001.sml')
require(proof['objects'] == repeat['objects'], 'aligned: repeat exports differ')
_, lines = case(al, 'audit', 0, ['TRACE_IMPORT_COMPLETE', 'IMPORTED_THEOREM refund_initialization_aligned'],
                objects=0, source='audit.sml')
require(sum(1 for line in lines if line.startswith('KEPT_PREMISE ')) == 2, 'aligned: kept premise count')
al_nodes = closure(lines, 'aligned/audit')
case(al, 'unaligned-domain', 1, ['AFTER_POSITIVE_AUDIT'], source='unaligned-domain.sml',
     stderr_has='Exact statement mismatch: unaligned memory domains', **CONTROL)
case(al, 'missing-memory-statement', 1, ['AFTER_POSITIVE_AUDIT'], source='missing-memory-statement.sml',
     stderr_has='Exact statement mismatch: missing memory_assumption', **CONTROL)
summary['refund_initialization_aligned'] = {'exports': proof['objects'], 'closure_nodes': al_nodes,
                                            'candidate_sha256': proof['source_sha256']}

# 4. Install-stub lemmas (U298, first executable obligation).
st = ROOT / 'refund-install-stub-local-20261112/attempt-0001'
first, lines = case(st, 'stub-0001', -24, source='stub-0001.sml', objects=0)     # CPU limit in an optional third lemma
require(sum(1 for line in lines if line.startswith('LEMMA_PROVED ')) == 2 and 'INSTALL_STUB_COMPLETE' not in lines,
        'stub: first run record changed')
proof, _ = case(st, 'stub-0002', 0, ['INSTALL_STUB_COMPLETE'], objects=4, source='stub-0002.sml')
case(st, 'import', 1, source='import.sml', objects=0)                  # script error: parents not loaded first
case(st, 'wrong-polarity', 1, source='wrong-polarity.sml', objects=0)  # same script error; not a control result
_, lines = case(st, 'import-0002', 0, ['INSTALL_STUB_IMPORT_COMPLETE'], objects=0, source='import.sml')
st_nodes = closure(lines, 'stub/import-0002')
case(st, 'wrong-polarity-0002', 1, ['AFTER_POSITIVE_AUDIT'], source='wrong-polarity.sml',
     stderr_has='Exact statement mismatch: stub claimed install-free', **CONTROL)
summary['install_stub_lemmas'] = {'exports': proof['objects'], 'closure_nodes': st_nodes,
                                  'candidate_sha256': proof['source_sha256']}

summary.update({'scope': 'Byte, exit and marker binding only. Not a proof checker. No independent replay.',
                'failures': failures, 'end_to_end': False})
print(json.dumps(summary, indent=1))
raise SystemExit(1 if failures else 0)
