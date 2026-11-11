"""Bind executed HOL records to exact bytes. This does not check proofs."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
OUT = Path(__file__).resolve().parent
TC = ROOT/'.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
logs = lambda n: ''.join((OUT/n/f).read_text() for f in ['stdout.log', 'stderr.log'])
assert not (OUT/'readback.json').exists()
expected = {'init-parent': 0, 'static-0001': 1, 'static-0002': 0,
            'static-0003': 0, 'exact-import-0001': 1, 'exact-import-0002': 0,
            'parent-repeat': 0, 'static-repeat': 0,
            'wrong-code': 1, 'wrong-oracle': 1, 'missing-memory': 1, 'missing-memory-0002': 1}
records = {n: read(OUT/n/'command.json') for n in expected}
heap = sha(TC/'cakeml/misc/cakeml-heap')
for n, code in expected.items():
    r = records[n]
    assert r['actual_exit'] == code and r['end_to_end'] is False, n
    source = OUT/n/('proof.sml' if 'completion_marker' in r else 'audit.sml')
    assert sha(source) == r['source_sha256'] and r['heap_sha256'] == heap, n
    for name, digest in r.get('objects', {}).items():
        assert sha(OUT/n/name) == digest, (n, name)
    for parent, objects in r.get('imported_objects', {}).items():
        for name, digest in objects.items():
            assert sha(OUT/n/parent/name) == digest == sha(OUT/parent/name)
    if 'completion_marker' in r:
        assert r['completion_marker'] == (code == 0), n
    else:
        assert r['import_complete'] == (n == 'exact-import-0002'), n
assert 'not found in theory' in logs('static-0001') and 'backend_common' in logs('static-0001')
assert 'REMAINING_ANTECEDENTS 16' in logs('static-0002')
assert 'Wrong complete premise count: refund_initialization_static' in logs('exact-import-0001')
for n in ['static-0003', 'static-repeat']:
    assert 'REMAINING_ANTECEDENTS 15' in logs(n)
for a, b in [('init-parent', 'parent-repeat'), ('static-0003', 'static-repeat')]:
    assert records[a]['objects'] == records[b]['objects']
    assert records[a]['source_sha256'] == records[b]['source_sha256']
    assert len(records[a]['objects']) == 4
log = logs('exact-import-0002')
markers = re.findall(r'^IMPORTED .*$', log, re.M)
assert len(markers) == 7 and all('HYPOTHESES 0 TAGGED_AXIOMS 0' in s for s in markers)
assert sum('EXACT_OR_KERNEL_NORMALIZED true' in s for s in markers) == 5
assert sum('KERNEL_PREMISES_EQUIVALENT true' in s for s in markers) == 2
for n in ['wrong-code', 'wrong-oracle', 'missing-memory', 'missing-memory-0002']:
    assert all(marker in logs(n) for marker in markers), n
    assert 'AFTER_POSITIVE_AUDIT' in logs(n)
    assert 'UNEXPECTED_CONTROL_ACCEPTANCE' not in logs(n)
assert 'Exact statement mismatch: refund_lab_code' in logs('wrong-code')
assert 'Exact statement mismatch: refund_lab_oracle' in logs('wrong-oracle')
assert 'No match' in logs('missing-memory') and 'MATCH_MP_TAC' in logs('missing-memory')
assert 'unsolved goals' in logs('missing-memory-0002') and 'memory_assumption' in logs('missing-memory-0002')
assert read(OUT/'validation-sequence-failure.json')['actual_exit'] == 1
assert read(OUT/'validation-completion.json')['actual_exit'] == 0
closure = {n: p.split(',') if p else [] for n, p in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$', log, re.M)}
assert closure and all(p in closure for ps in closure.values() for p in ps)
axioms = set(re.findall(r'^CLOSURE_AXIOM (.*)$', log, re.M))
assert axioms == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
index = {}
for p in TC.rglob('*Theory.dat'):
    index.setdefault(p.name, set()).add(p.resolve())
own = {Path(f).name: OUT/n/f for n in ['init-parent', 'static-0003']
       for f in records[n]['objects'] if f.endswith('Theory.dat')}
files, builtins = {}, {}
for name in closure:
    if name == 'min':
        p = TC/'HOL/src/postkernel/Theory.sml'
        assert closure[name] == []
        assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
        builtins[name] = {'source_sha256': sha(p), 'heap_sha256': heap}
        continue
    filename = name + 'Theory.dat'
    paths = {own[filename]} if filename in own else index.get(filename, set())
    assert len(paths) == 1, (name, paths)
    p = next(iter(paths))
    for ext in ['.dat', '.sig', '.sml']:
        assert p.with_suffix(ext).is_file()
    for ext in ['.dat', '.sig', '.sml', '.uo', '.ui']:
        q = p.with_suffix(ext)
        if q.exists():
            files[str(q)] = sha(q)
base = read(OUT/'baseline.json')
sources = {**base['source_hashes'], **read(OUT/'supplemental-sources.json')}
for name, digest in sources.items():
    data = subprocess.check_output(['git', 'show', 'cd9155694c16831373ab695a670794f23282ed62:'+name], cwd=TC/'cakeml')
    assert hashlib.sha256(data).hexdigest() == digest == sha(TC/'cakeml'/name) == sha(OUT/'upstream'/name)
for name, digest in base['protected'].items():
    assert sha(ROOT/name) == digest
assert sha(ROOT/'FORGE_MISSION.md') == base['mission_sha256'] == sha(WT/'FORGE_MISSION.md')
native = ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == base['native_sha256']
pins = {'cakeml': 'cd9155694c16831373ab695a670794f23282ed62',
        'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for name, pin in pins.items():
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=TC/name).decode().strip() == pin
    assert subprocess.run(['git', 'diff', '--quiet', 'HEAD'], cwd=TC/name).returncode == 0
prior_packets = {}
for name in ['initialization-success-checkpoint-20261105', 'pointer-witness-validation-20261105']:
    rel = Path('proposals/refund-executable-feasibility')/name
    for root in [ROOT, WT]:
        manifest = read(root/rel/'manifest.json')
        for path, digest in manifest.items():
            assert sha(root/rel/path) == digest
    assert sha(ROOT/rel/'manifest.json') == sha(WT/rel/'manifest.json')
    prior_packets[name] = {'manifest_sha256': sha(ROOT/rel/'manifest.json'), 'members_per_copy': len(manifest)}
assert prior_packets['initialization-success-checkpoint-20261105']['manifest_sha256'] == base['prior_manifest_sha256']
result = {'actual_exit': 0, 'base_commit': base['base_commit'],
          'recorded_child_exits': expected, 'checked_statements': 7,
          'remaining_antecedents': {'original': 17, 'final': 15},
          'identical_exports': {n: records[n]['objects'] for n in ['init-parent', 'static-0003']},
          'closure': closure, 'closure_node_count': len(closure), 'closure_axioms': sorted(axioms),
          'dependency_files': files, 'dependency_file_count': len(files), 'builtin_dependencies': builtins,
          'source_hashes': sources, 'source_pin_count': len(sources), 'protected_paths': len(base['protected']),
          'prior_packets': prior_packets, 'native_sha256': sha(native),
          'source_sha256': records['static-0003']['source_sha256'],
          'local_wall_seconds': {n: records[n]['wall_seconds'] for n in records},
          'independent_full_chain_replay': 'NOT RUN', 'native_or_hosted_execution': 'NOT RUN',
          'admission': 'NOT RUN', 'backup_restore': 'NOT RUN', 'end_to_end': False}
(OUT/'readback.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k: v for k, v in result.items() if k not in
                 ['closure', 'dependency_files', 'source_hashes', 'identical_exports', 'local_wall_seconds']}))
