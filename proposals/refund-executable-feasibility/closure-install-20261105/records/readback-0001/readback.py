"""Check exact local HOL records and evidence identities, not new semantics."""
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
expected = {'closure-0001': 1, 'closure-0002': 0, 'closure-repeat': 0,
            'exact-import': 0, 'injected-install': 1, 'wrong-program': 1}
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

a, b = records['closure-0002'], records['closure-repeat']
assert a['objects'] == b['objects'] and len(a['objects']) == 4
assert a['source_sha256'] == b['source_sha256'] == sha(OUT / 'closure.sml')
assert 'REFUND_CLOS_HAS_INSTALL F' in log('closure-0002')
assert 'cv_repLib.NeedsTranslation' in log('closure-0001')
assert 'REFUND_CLOS_HAS_INSTALL T' in log('injected-install')
assert 'EQF_ELIM' in log('injected-install')
assert 'Exact statement mismatch: refund_closure_no_install' in log('wrong-program')
positive = (OUT / 'closure.sml').read_text()
fragment = '  (SND(backend$to_clos arm8_config$arm8_backend_config'
assert positive.count(fragment) == 1
assert (OUT / 'injected-install.sml').read_text() == positive.replace(
    fragment, '  (closLang$Op backend_common$None closLang$Install [] :: SND(backend$to_clos arm8_config$arm8_backend_config')
claim = (OUT / 'expected.sml').read_text()
assert claim.count('forge_refundWholeProg$refund_prog') == 1
assert (OUT / 'wrong-program.sml').read_text() == claim.replace('forge_refundWholeProg$refund_prog', '[]')
assert log('exact-import').count('IMPORTED refund_closure_no_install EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0') == 1

closure = {n: ps.split(',') if ps else [] for n, ps in re.findall(
    r'^CLOSURE_NODE ([^:]+):(.*)$', log('exact-import'), re.M)}
assert 'forge_refundClosureInstall' in closure
assert all(p in closure for ps in closure.values() for p in ps)
axioms = set(re.findall(r'^CLOSURE_AXIOM (.*)$', log('exact-import'), re.M))
assert axioms == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
index = {}
for path in TC.rglob('*Theory.dat'):
    index.setdefault(path.name, set()).add(path.resolve())
files, builtin = {}, {}
for name in closure:
    if name == 'min':
        path = TC / 'HOL/src/postkernel/Theory.sml'
        assert closure[name] == []
        assert 'The "min" theory is already installed; it has no parents.' in path.read_text()
        builtin[name] = {'source_sha256': sha(path), 'heap_sha256': a['heap_sha256']}
        continue
    filename = name + 'Theory.dat'
    paths = {OUT / 'closure-0002/.hol/objs' / filename} if name == 'forge_refundClosureInstall' else index.get(filename, set())
    assert len(paths) == 1, (name, paths)
    path = next(iter(paths))
    for ext in ['.dat', '.sig', '.sml']:
        assert path.with_suffix(ext).exists()
    for ext in ['.dat', '.sig', '.sml', '.uo', '.ui']:
        f = path.with_suffix(ext)
        if f.exists():
            files[str(f)] = sha(f)

base = read(OUT / 'baseline.json')
for name, digest in base['source_hashes'].items():
    data = subprocess.run(['git', 'show', 'cd9155694c16831373ab695a670794f23282ed62:' + name],
                          cwd=TC / 'cakeml', capture_output=True, check=True).stdout
    assert hashlib.sha256(data).hexdigest() == digest == sha(OUT / 'upstream' / name) == sha(TC / 'cakeml' / name)
extra = read(OUT / 'additional-sources.json')
for name, digest in extra['hashes'].items():
    repo, relative = name.split('/', 1)
    pin = {'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3',
           'cakeml': 'cd9155694c16831373ab695a670794f23282ed62'}[repo]
    data = subprocess.run(['git', 'show', pin + ':' + relative], cwd=TC / repo,
                          capture_output=True, check=True).stdout
    assert hashlib.sha256(data).hexdigest() == digest == sha(OUT / 'upstream-additional' / name) == sha(TC / name)
assert sha(Path(extra['local_compiler_script']['path'])) == extra['local_compiler_script']['sha256'] == sha(OUT / 'compiler-input.sml')
for path, digest in base['protected'].items():
    assert sha(ROOT / path) == digest
assert sha(ROOT / 'FORGE_MISSION.md') == base['mission_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == base['native_sha256']
prior = {}
for name in ['runtime-premises-20261104', 'installation-premise-20261104', 'target-install-bridge-20261105']:
    path = ROOT / 'proposals/refund-executable-feasibility' / name
    manifest = read(path / 'manifest.json')
    for member, digest in manifest.items():
        assert sha(path / member) == digest
    prior[name] = {'manifest_sha256': sha(path / 'manifest.json'), 'members': len(manifest)}
result = {'actual_exit': 0, 'recorded_child_exits': expected,
          'proof_hashes': {n: sha(OUT / n) for n in ['closure.sml', 'expected.sml', 'injected-install.sml', 'wrong-program.sml']},
          'identical_exports': a['objects'], 'exact_import_statements': 1,
          'closure': closure, 'closure_node_count': len(closure), 'closure_axioms': sorted(axioms),
          'dependency_files': files, 'dependency_file_count': len(files), 'builtin_dependencies': builtin,
          'pinned_source_hashes': base['source_hashes'], 'additional_source_hashes': extra['hashes'],
          'local_compiler_script': extra['local_compiler_script'],
          'protected_files_unchanged': len(base['protected']), 'prior_packets': prior,
          'native_sha256': sha(native),
          'scope': 'Exact refund closure syntax under default ARM8 config contains no Install. Lower-pass preservation and target installer exclusion NOT_ESTABLISHED.',
          'native_or_hosted_execution': 'NOT RUN', 'independent_full_chain_replay': 'NOT RUN',
          'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in
                 ['closure', 'dependency_files', 'pinned_source_hashes', 'additional_source_hashes']}, indent=2))
