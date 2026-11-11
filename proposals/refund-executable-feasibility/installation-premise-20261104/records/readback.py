"""Read back exact local checks; this is not an independent proof replay."""
from pathlib import Path
import hashlib, json, re, subprocess
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
HT = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
assert not (OUT / 'readback.json').exists()
expected = {**{f'positive-{i:04}': 1 for i in range(1, 6)},
            'oracle-0001': 1, 'oracle-0002': 0, 'oracle-repeat': 0,
            'oracle-import': 0, 'missing-resource': 1, 'wrong-program': 1}
records = {n: read(OUT / n / 'command.json') for n in expected}
def log(n):
    return (OUT / n / 'stdout.log').read_text() + (OUT / n / 'stderr.log').read_text()
for n, code in expected.items():
    r = records[n]
    assert r['actual_exit'] == code and r['end_to_end'] is False, n
    src = OUT / n / ('audit.sml' if 'imported_objects' in r else 'proof.sml')
    assert sha(src) == r['source_sha256'], n
    for p, digest in r.get('objects', {}).items():
        assert sha(OUT / n / p) == digest
    for source, objects in r.get('imported_objects', {}).items():
        for p, digest in objects.items():
            assert sha(OUT / n / source / p) == digest == sha(OUT / source / p)
for n in [f'positive-{i:04}' for i in range(1, 6)] + ['oracle-0001']:
    assert not records[n]['completion_marker'] and not records[n]['objects'], n
assert 'standard_stubs_require_reachability' in log('positive-0005')
assert 'no solution found' in log('positive-0005')
partial = re.findall(r'Saved theorem _+ "([^"]+)"', log('positive-0005'))
assert partial == ['emitted_install_jump', 'install_jump_offset',
                   'install_jump_destination', 'stub_contains_install'], partial
assert records['oracle-0002']['objects'] == records['oracle-repeat']['objects']
assert len(records['oracle-0002']['objects']) == 4
assert records['oracle-0002']['source_sha256'] == records['oracle-repeat']['source_sha256'] == sha(OUT / 'oracle.sml')
for n in ['oracle-0002', 'oracle-repeat']:
    assert records[n]['completion_marker']
assert records['oracle-import']['import_complete']
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$', log('oracle-import'), re.M)) == 3
original = (OUT / 'expected-oracle.sml').read_text()
assert sha(OUT / 'expected-oracle.sml') == records['oracle-import']['source_sha256']
fragment = '''     backendProof$is_safe_for_space (:64) ffi pe arm8_target$arm8_config cfg
       forge_refundWholeProg$refund_prog stack_heap_limit'''
assert original.count(fragment) == 1
assert (OUT / 'missing-resource.sml').read_text() == original.replace(fragment, '     T')
assert original.count('forge_refundWholeProg$refund_prog') == 3
assert (OUT / 'wrong-program.sml').read_text() == original.replace('forge_refundWholeProg$refund_prog', '([]:ast$dec list)')
for n in ['missing-resource', 'wrong-program']:
    assert 'Exact statement mismatch: refund_data_oracle_independence' in log(n)
    assert not records[n]['import_complete']
    assert 'INSTALL_IMPORT_COMPLETE' not in log(n)
closure = {n: ps.split(',') if ps else [] for n, ps in
           re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$', log('oracle-import'), re.M)}
assert all(p in closure for ps in closure.values() for p in ps)
axioms = set(re.findall(r'^CLOSURE_AXIOM (.*)$', log('oracle-import'), re.M))
assert axioms == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
index = {}
for p in HT.rglob('*Theory.dat'):
    index.setdefault(p.name, set()).add(p.resolve())
files, builtin = {}, {}
for name in closure:
    if name == 'min':
        assert closure[name] == []
        p = HT / 'HOL/src/postkernel/Theory.sml'
        assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
        builtin[name] = {'source_sha256': sha(p), 'heap_sha256': sha(HT / 'cakeml/misc/cakeml-heap')}
        continue
    candidates = ({OUT / 'oracle-0002/.hol/objs/forge_refundDataOracleTheory.dat'}
                  if name == 'forge_refundDataOracle' else index.get(name + 'Theory.dat', set()))
    assert len(candidates) == 1, (name, list(map(str, candidates)))
    p = next(iter(candidates))
    for ext in ['.dat', '.sig', '.sml']:
        assert p.with_suffix(ext).exists()
    for ext in ['.dat', '.sig', '.sml', '.uo', '.ui']:
        f = p.with_suffix(ext)
        if f.exists():
            files[str(f)] = sha(f)
baseline = read(OUT / 'baseline.json')
sources = {**baseline['source_hashes'], **read(OUT / 'additional-sources.json')['hashes']}
pin = 'cd9155694c16831373ab695a670794f23282ed62'
for p, digest in sources.items():
    blob = subprocess.run(['git', 'show', pin + ':' + p], cwd=HT / 'cakeml', capture_output=True, check=True).stdout
    assert hashlib.sha256(blob).hexdigest() == digest == sha(OUT / 'upstream' / p) == sha(HT / 'cakeml' / p)
for p, digest in baseline['protected'].items():
    assert sha(ROOT / p) == digest
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
loaded = ROOT / 'results/refund-entry-observation-2026-11-04/attempt-fullmap/loaded-code.bin'
byte_record = read(OUT / 'byte-readback.json')
assert sha(native) == baseline['native_sha256'] == byte_record['native_sha256']
assert sha(loaded) == byte_record['loaded_code_sha256']
assert len(loaded.read_bytes()) == 130436
assert native.read_bytes()[16592:16592 + 130436] == loaded.read_bytes()
assert native.read_bytes()[21252:21256].hex() == loaded.read_bytes()[4660:4664].hex() == '6bfbff17'
assert sha(OUT / 'otool.stdout') == byte_record['disassembly_sha256']
packets = {}
for name in ['runtime-premises-20261104', 'compiled-behavior-20261104', 'resource-binding-20261104']:
    p = ROOT / 'proposals/refund-executable-feasibility' / name
    manifest = read(p / 'manifest.json')
    for f, digest in manifest.items():
        assert sha(p / f) == digest
    packets[name] = {'members': len(manifest), 'manifest_sha256': sha(p / 'manifest.json')}
result = {'actual_exit': 0, 'recorded_exits': expected,
          'proof_sha256': sha(OUT / 'oracle.sml'), 'expected_claim_sha256': sha(OUT / 'expected-oracle.sml'),
          'identical_exports': records['oracle-0002']['objects'], 'exact_import_statements': 3,
          'installation_status': 'STOPPED after five failed attempts; no complete export',
          'partial_installation_statements_in_failed_log': partial,
          'negative_reasons': {n: 'Exact statement mismatch: refund_data_oracle_independence' for n in ['missing-resource', 'wrong-program']},
          'closure': closure, 'closure_node_count': len(closure), 'closure_axioms': sorted(axioms),
          'dependency_files': files, 'dependency_file_count': len(files), 'builtin_dependencies': builtin,
          'pinned_source_hashes': sources, 'protected_files_unchanged': len(baseline['protected']),
          'prior_packet_members': packets, 'byte_readback_sha256': sha(OUT / 'byte-readback.json'),
          'scope': 'Conditional data-level oracle independence only. Machine installation reachability and resource sufficiency remain unproved.',
          'independent_full_chain_replay': 'NOT RUN', 'native_execution': 'NOT RUN', 'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in ['closure', 'dependency_files', 'pinned_source_hashes', 'identical_exports']}, indent=2))
