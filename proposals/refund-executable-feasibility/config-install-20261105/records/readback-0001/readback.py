"""Bind existing HOL outcomes to exact statements, inputs and preserved records."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
assert not (OUT / 'readback.json').exists()
expected = {'config-0001': 0, 'config-repeat': 0, 'space-0001': 1,
            'space-0002': 0, 'space-repeat': 0,
            **{'trace-000' + str(i): 1 for i in range(1, 6)},
            'exact-import': 1, 'wrong-program': 1, 'missing-space': 1,
            'retained-bound': 1, 'exact-import-0002': 0, 'wrong-program-0002': 1,
            'missing-space-0002': 1, 'retained-bound-0002': 1,
            'trace-corollary-0002': 1, 'trace-corollary-0003': 1,
            'trace-corollary-0004': 0, 'trace-repeat': 0, 'trace-import': 0,
            'missing-nonerror': 1, 'missing-trace-space': 1}
records = {n: read(OUT / n / 'command.json') for n in expected}

def log(name):
    return ''.join((OUT / name / f).read_text() for f in ['stdout.log', 'stderr.log'])

for name, code in expected.items():
    c = records[name]
    assert c['actual_exit'] == code and c['end_to_end'] is False, name
    source = OUT / name / ('proof.sml' if 'completion_marker' in c else 'audit.sml')
    assert sha(source) == c['source_sha256'], name
    assert sha(TC / 'cakeml/misc/cakeml-heap') == c['heap_sha256']
    for path, digest in c.get('objects', {}).items():
        assert sha(OUT / name / path) == digest
    for src, objects in c.get('imported_objects', {}).items():
        for path, digest in objects.items():
            assert sha(OUT / name / src / path) == digest == sha(OUT / src / path)
    if 'completion_marker' in c:
        assert c['completion_marker'] == (code == 0)
        if code:
            assert c['objects'] == {}
    else:
        assert c['import_complete'] == (code == 0)

exports = {}
for first, repeat, source in [('config-0001', 'config-repeat', 'config.sml'),
                              ('space-0002', 'space-repeat', 'space.sml'),
                              ('trace-corollary-0004', 'trace-repeat', 'trace.sml')]:
    a, b = records[first], records[repeat]
    assert a['objects'] == b['objects'] and len(a['objects']) == 4
    assert a['source_sha256'] == b['source_sha256'] == sha(OUT / source)
    exports[first] = a['objects']
parent = read(OUT / 'closure-parent/command.json')
prior_parent = ROOT / 'proposals/refund-executable-feasibility/closure-install-20261105/records/closure-0002'
assert parent == read(prior_parent / 'command.json')
for f, h in parent['objects'].items():
    assert sha(OUT / 'closure-parent' / f) == h == sha(prior_parent / f)
exports['closure-parent'] = parent['objects']
assert 'Failed to prove theorem "install_suffix_unbounded"' in log('space-0001')
assert 'UNSOLVED MustTerminate' in log('trace-0002')
assert 'Failed to prove theorem "safe_run_single_epoch"' in log('trace-0005')
assert 'Saved theorem _______ "bounded_stack_single_epoch"' in log('trace-0005')
stop = read(OUT / 'trace-stop.json')
assert stop['status'] == 'STOPPED_AT_FIVE' and not stop['complete_theory_export']
assert len(list(OUT.glob('trace-000[0-9]'))) == 5
accounting = read(OUT / 'attempt-accounting-final.json')
assert accounting['complete_bundle_actual_exit'] == 0
assert accounting['bounded_stack_single_epoch']['successful_attempt'] == 5
assert accounting['safe_run_single_epoch']['successful_attempt'] == 4
prefix = (OUT / 'trace-0005/proof.sml').read_text().split('val safe_run_single_epoch')[0]
for case in ['trace-corollary-0002', 'trace-corollary-0003', 'trace-corollary-0004', 'trace-repeat']:
    assert (OUT / case / 'proof.sml').read_text().split('val safe_run_single_epoch')[0] == prefix
assert hashlib.sha256(prefix.encode()).hexdigest() == read(OUT / 'attempt-accounting.json')['unchanged_successful_prefix_sha256']

claim = (OUT / 'expected.sml').read_text()
changes = {
    'wrong-program': ('     forge_refundWholeProg$refund_prog))``,refund_config_no_install)',
                      '     []))``,refund_config_no_install)', 'refund_config_no_install'),
    'missing-space': (' wordSem$word_lang_safe_for_space initial start /\\',
                      ' T /\\', 'safe_run_excludes_install_suffix'),
    'retained-bound': ('wordSem$evaluate (suffix,t) = (res,u) ==> u.stack_max = NONE',
                       'wordSem$evaluate (suffix,t) = (res,u) ==> u.stack_max = SOME 0',
                       'install_suffix_unbounded')}
for name, (old, new, theorem) in changes.items():
    assert claim.count(old) == 1
    assert (OUT / (name + '.sml')).read_text() == claim.replace(old, new)
    assert 'Exact statement mismatch: ' + theorem in log(name + '-0002')
for name in ['exact-import', 'wrong-program', 'missing-space', 'retained-bound']:
    assert 'Structure (wordPropsTheory) has not been declared' in log(name)
    assert records[name]['source_sha256'] == records[name + '-0002']['source_sha256']
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',
                      log('exact-import-0002'), re.M)) == 6

trace_claim = (OUT / 'expected-trace.sml').read_text()
for name, old, new, theorem in [
    ('missing-nonerror', ' /\\ res <> SOME wordSem$Error', '', 'bounded_stack_single_epoch'),
    ('missing-trace-space', ' wordSem$word_lang_safe_for_space initial start /\\', ' T /\\', 'safe_run_single_epoch')]:
    assert trace_claim.count(old) == 1
    assert (OUT / (name + '.sml')).read_text() == trace_claim.replace(old, new)
    assert 'Exact statement mismatch: ' + theorem in log(name)
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$', log('trace-import'), re.M)) == 3
closure = {}
for name, parents in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$', log('exact-import-0002') + log('trace-import'), re.M):
    ps = parents.split(',') if parents else []
    assert name not in closure or closure[name] == ps
    closure[name] = ps
assert all(n in closure for n in ['forge_refundClosureInstall', 'forge_refundConfigInstall', 'forge_installSpaceBarrier'])
assert 'forge_spaceInstallTrace' in closure
assert all(p in closure for ps in closure.values() for p in ps)
axioms = set(re.findall(r'^CLOSURE_AXIOM (.*)$', log('exact-import-0002') + log('trace-import'), re.M))
assert axioms == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
index = {}
for path in TC.rglob('*Theory.dat'):
    index.setdefault(path.name, set()).add(path.resolve())
own = {Path(f).name: OUT / n / f for n, objects in exports.items()
       for f in objects if f.endswith('Theory.dat')}
files, builtin = {}, {}
for name in closure:
    if name == 'min':
        path = TC / 'HOL/src/postkernel/Theory.sml'
        assert closure[name] == []
        assert 'The "min" theory is already installed; it has no parents.' in path.read_text()
        builtin[name] = {'source_sha256': sha(path), 'heap_sha256': parent['heap_sha256']}
        continue
    filename = name + 'Theory.dat'
    paths = {own[filename]} if filename in own else index.get(filename, set())
    assert len(paths) == 1, (name, paths)
    path = next(iter(paths))
    for ext in ['.dat', '.sig', '.sml']:
        assert path.with_suffix(ext).exists()
    for ext in ['.dat', '.sig', '.sml', '.uo', '.ui']:
        f = path.with_suffix(ext)
        if f.exists():
            files[str(f)] = sha(f)

base = read(OUT / 'baseline.json')
sources = {**base['source_hashes'], **read(OUT / 'additional-sources.json')['hashes']}
for name, digest in sources.items():
    data = subprocess.run(['git', 'show', 'cd9155694c16831373ab695a670794f23282ed62:' + name],
                          cwd=TC / 'cakeml', capture_output=True, check=True).stdout
    assert hashlib.sha256(data).hexdigest() == digest == sha(OUT / 'upstream' / name) == sha(TC / 'cakeml' / name)
for path, digest in base['protected'].items():
    assert sha(ROOT / path) == digest
assert sha(ROOT / 'FORGE_MISSION.md') == base['mission_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == base['native_sha256']
prior = {}
for name in ['runtime-premises-20261104', 'installation-premise-20261104',
             'target-install-bridge-20261105', 'closure-install-20261105']:
    path = ROOT / 'proposals/refund-executable-feasibility' / name
    manifest = read(path / 'manifest.json')
    for member, digest in manifest.items():
        assert sha(path / member) == digest
    prior[name] = {'manifest_sha256': sha(path / 'manifest.json'), 'members': len(manifest)}
result = {'actual_exit': 0, 'recorded_child_exits': expected,
          'proof_hashes': {n: sha(OUT / n) for n in ['config.sml', 'space.sml', 'trace.sml', 'expected.sml', 'expected-trace.sml']},
          'identical_exports': exports, 'new_exported_theorems': 8, 'exact_import_statements': 9,
          'historical_parent': 'closure-parent; not a new source replay',
          'trace_bundle': accounting, 'superseded_stop_record_preserved': stop, 'closure': closure, 'closure_node_count': len(closure),
          'closure_axioms': sorted(axioms), 'dependency_files': files,
          'dependency_file_count': len(files), 'builtin_dependencies': builtin,
          'pinned_source_hashes': sources, 'protected_files_unchanged': len(base['protected']),
          'prior_packets': prior, 'native_sha256': sha(native),
          'scope': 'Refund closure binding under set_oracle and conditional word-level installation-space barriers plus single-epoch trace theorem. Target installer exclusion NOT_ESTABLISHED.',
          'native_or_hosted_execution': 'NOT RUN', 'independent_full_chain_replay': 'NOT RUN',
          'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in
                 ['closure', 'dependency_files', 'pinned_source_hashes', 'identical_exports']}, indent=2))
