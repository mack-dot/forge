"""Separate evidence reader for the third 2026-11-12 continuation.

It imports no producer code and runs no HOL. It binds bytes, exits and markers
only. An exit code is not semantic verification: this reader cannot tell
whether a theorem is true. It checks that the recorded files are the files the
HOL child read and wrote and that each case ended as recorded.

Usage: python3 -I -B verify_cases_r3.py [<results root override>]
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
NATIVE = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
summary = {}

# 1. memory_assumption from the published installed predicate.
ins = ROOT / 'refund-initializer-installed-local-20261112/attempt-0001'
case(ins, 'explore-0001', 1, source='explore-0001.sml', objects=0)   # script error: plain `use` of a file with quotations
case(ins, 'explore-0002', 1, source='explore-0002.sml', objects=0)   # script error: undeclared name in a late step
case(ins, 'explore-0003', 0, ['EXPLORE_COMPLETE'], objects=0, source='explore-0003.sml')
proof, lines = case(ins, 'installed-0001', 0, ['RUNTIME_PROOF_COMPLETE', 'REMAINING_ANTECEDENTS 2',
                    'HEAP_LEMMA_STORED', 'MODEL_INSTANCE_STORED'], objects=4, source='installed-0001.sml')
require([l.split(' ', 1)[1] for l in lines if l.startswith('CHECKED ')] ==
        ['heap_region_extends', 'arm8_machine_model_instance', 'refund_initialization_installed'], 'installed: checked list')
repeat, _ = case(ins, 'repeat', 0, ['RUNTIME_PROOF_COMPLETE'], objects=4, source='installed-0001.sml')
require(proof['objects'] == repeat['objects'], 'installed: repeat exports differ')
_, lines = case(ins, 'audit', 0, ['TRACE_IMPORT_COMPLETE', 'IMPORTED_THEOREM refund_initialization_installed'],
                objects=0, source='audit.sml')
require(sum(1 for l in lines if l.startswith('KEPT_PREMISE ')) == 2, 'installed: kept premise count')
ins_nodes = closure(lines, 'installed/audit')
case(ins, 'missing-installed', 1, ['AFTER_POSITIVE_AUDIT'], source='missing-installed.sml',
     stderr_has='Exact statement mismatch: missing installed premise', **CONTROL)
case(ins, 'other-bitmaps', 1, ['AFTER_POSITIVE_AUDIT'], source='other-bitmaps.sml',
     stderr_has='Exact statement mismatch: installed state for other bitmaps', **CONTROL)
require((ins / 'heap-lemma-statement.txt').read_text().rstrip('\n') in (ins / 'installed-0001.sml').read_text(),
        'installed: proof source lacks the heap lemma statement text')
summary['refund_initialization_installed'] = {'exports': proof['objects'], 'closure_nodes': ins_nodes,
                                              'candidate_sha256': proof['source_sha256']}

# 2. Installer call site in the exact native code.
site = ROOT / 'refund-install-site-local-20261112/attempt-0001'
scan = json.loads((site / 'entry-branches.json').read_text())
require(scan['native_sha256'] == NATIVE and scan['targets']['-32']['count'] == 1
        and scan['targets']['-32']['sites'][0]['word'] == '17fffb6b'
        and scan['targets']['-32']['sites'][0]['code_offset'] == 4660, 'site: scan record changed')
require('"17fffb6b"' in (site / 'install-site-0001.sml').read_text(), 'site: proof source does not name the scanned word')
proof, _ = case(site, 'install-site-0001', 0, ['NATIVE_STEP_COMPLETE'], objects=4, source='install-site-0001.sml')
repeat, _ = case(site, 'repeat', 0, ['NATIVE_STEP_COMPLETE'], objects=4, source='install-site-0001.sml')
require(proof['objects'] == repeat['objects'], 'site: repeat exports differ')
_, lines = case(site, 'import', 0, ['NATIVE_IMPORT_COMPLETE', 'IMPORTED_ORACLES DISK_THM'], objects=0, source='import.sml')
site_nodes = closure(lines, 'site/import')
case(site, 'wrong-target', 1, ['AFTER_POSITIVE_AUDIT'], source='wrong-target.sml',
     stderr_has='Exact statement mismatch: wrong branch target', **CONTROL)
require((site / 'install-site-statement.txt').read_text().rstrip('\n') in (site / 'import.sml').read_text(),
        'site: import lacks the statement text')
summary['install_call_site_step'] = {'exports': proof['objects'], 'closure_nodes': site_nodes,
                                     'candidate_sha256': proof['source_sha256']}

summary.update({'scope': 'Byte, exit and marker binding only. Not a proof checker. No independent replay.',
                'failures': failures, 'end_to_end': False})
print(json.dumps(summary, indent=1))
raise SystemExit(1 if failures else 0)
