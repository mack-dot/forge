"""Check saved outcomes and artifact binding. This is not a semantic verifier."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
FT = ROOT / '.toolchain/experiments/refund-dafny-frontend-20261104'
HT = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
SRC = FT / 'dafny-compat'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
assert not (OUT / 'readback.json').exists()

exits = {
    'build-0001': 0, 'build-0002': 0, 'build-0003': 0,
    'export-0001': 1, 'export-0002': 1, 'export-0003': 0, 'export-repeat': 0,
    'upstream-example': 0, 'named-example': 0,
    'two-modules': 1, 'root-code': 1, 'nested-module': 1,
    'abstract-module': 1, 'nonempty-frame': 1, 'sequence-int': 1,
    'wrong-amount': 0, 'swapped-fields': 0, 'swapped-inputs': 0, 'missing-contract': 0,
    'hol-0001': 1, 'hol-0002': 1, 'hol-0003': 1, 'hol-0004': 0, 'hol-repeat': 0,
    'hol-wrong-amount': 1, 'hol-swapped-fields': 1, 'hol-swapped-inputs': 1,
    'hol-missing-contract': 1, 'hol-trailing': 1,
    'import-0001': 0, 'relation-0001': 0, 'relation-repeat': 0, 'relation-import': 0,
    'bridge-0001': 0, 'bridge-repeat': 0, 'bridge-import': 0,
}
records = {}
for case, expected in exits.items():
    p = OUT / case
    r = records[case] = read(p / 'command.json')
    assert r['actual_exit'] == expected and r['end_to_end'] is False, case
    if (p / 'Bake.cs').exists():
        assert sha(p / 'Bake.cs') == r['source_sha256'], case
        assert sha(p / 'frontend.patch') == r['patch_sha256'], case
    else:
        source = p / ('proof.sml' if (p / 'proof.sml').exists() else 'audit.sml')
        assert sha(source) == r['source_sha256'], case
    if 'input_sha256' in r:
        source = p / ('input.dfy' if (p / 'input.dfy').exists() else 'input.sexp')
        assert sha(source) == r['input_sha256'], case
    for name, digest in r.get('objects', {}).items():
        assert sha(p / name) == digest, (case, name)
    if 'output_sha256' in r and r['output_sha256'] is not None:
        assert sha(p / 'output.sexp') == r['output_sha256'], case

log = lambda case: (OUT / case / 'stdout.log').read_text() + (OUT / case / 'stderr.log').read_text()
assert 'SeqNeq' in log('export-0001')
assert 'Unsupported SetDisplayExpr' in log('export-0002')
front_controls = {
    'two-modules': 'Unsupported List`1', 'root-code': 'Unsupported List`1',
    'nested-module': 'Unsupported List`1', 'abstract-module': 'Unsupported List`1',
    'nonempty-frame': 'Unsupported SetDisplayExpr', 'sequence-int': 'Unsupported SeqType',
}
for case, reason in front_controls.items():
    assert reason in log(case), (case, reason)
    assert not (OUT / case / 'output.sexp').exists(), case

negative_reasons = {
    'hol-wrong-amount': ('source_full_result', 'amount + 1 = amount'),
    'hol-swapped-fields': ('source_full_result', 'request = charge'),
    'hol-swapped-inputs': ('Failed to prove theorem "source_signature"', 'First unsolved sub-goal is\n\nF'),
    'hol-missing-contract': ('Failed to prove theorem "source_postconditions"', 'First unsolved sub-goal is\n\nF'),
    'hol-trailing': ('Trailing export bytes',),
}
for case, terms in negative_reasons.items():
    text = log(case)
    # A rejected theorem, not an exporter failure or a claimed admission decision.
    assert all(term in text for term in terms), (case, terms)
    assert 'SOURCE_BINDING_COMPLETE' not in text
    assert not records[case]['objects']
    assert not list((OUT / case).glob('.hol/objs/*Theory.dat'))

reproductions = {}
for first, second, marker in [
    ('hol-0004', 'hol-repeat', 'SOURCE_BINDING_COMPLETE'),
    ('relation-0001', 'relation-repeat', 'SOURCE_RELATION_COMPLETE'),
    ('bridge-0001', 'bridge-repeat', 'SOURCE_BRIDGE_COMPLETE'),
]:
    a, b = records[first], records[second]
    assert a['objects'] == b['objects'] and len(a['objects']) == 4, first
    assert a['source_sha256'] == b['source_sha256'], first
    assert marker in log(first) and marker in log(second), first
    for name in a['objects']:
        assert (OUT / first / name).read_bytes() == (OUT / second / name).read_bytes()
    reproductions[first] = a['objects']

flat = ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'
assert sha(flat) == 'a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d'
export = OUT / 'export-0003/output.sexp'
assert sha(export) == '58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d'
assert export.read_bytes() == (OUT / 'export-repeat/output.sexp').read_bytes()
assert (OUT / 'trailing-input.sexp').read_bytes() == export.read_bytes() + b' ATTACK'
upstream_example = OUT.parent / 'attempt-0001/upstream-plus-one.sexp'
assert upstream_example.read_bytes() == (OUT / 'upstream-example/output.sexp').read_bytes()
assert upstream_example.read_bytes() == (OUT / 'named-example/output.sexp').read_bytes()

closure = {}
axioms = set()
for case, count in [('import-0001', 7), ('relation-import', 1), ('bridge-import', 1)]:
    text = log(case)
    statements = re.findall(r'^IMPORTED .*$', text, re.M)
    assert len(statements) == count
    assert all('EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0' in x for x in statements)
    assert records[case]['import_complete'] and 'SOURCE_IMPORT_COMPLETE' in text
    nodes = {n: parents.split(',') if parents else [] for n, parents in
             re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$', text, re.M)}
    for name, parents in nodes.items():
        if name in closure:
            assert closure[name] == parents, name
        closure[name] = parents
    axioms.update(re.findall(r'^CLOSURE_AXIOM (.+)$', text, re.M))
assert all(p in closure for parents in closure.values() for p in parents)
assert axioms == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
index = {}
for p in HT.rglob('*Theory.dat'):
    index.setdefault(p.name, set()).add(p.resolve())
own = {
    'forge_refundSourceBinding': OUT / 'hol-0004/.hol/objs/forge_refundSourceBindingTheory.dat',
    'forge_refundSourceRelation': OUT / 'relation-0001/.hol/objs/forge_refundSourceRelationTheory.dat',
    'forge_refundCompiledInputBinding': OUT / 'bridge-0001/.hol/objs/forge_refundCompiledInputBindingTheory.dat',
}
dependencies = {}
builtins = {}
for name in closure:
    if name == 'min':
        assert closure[name] == []
        source = HT / 'HOL/src/postkernel/Theory.sml'
        assert 'The "min" theory is already installed; it has no parents.' in source.read_text()
        builtins[name] = {'source_sha256': sha(source), 'heap_sha256': sha(HT / 'cakeml/misc/cakeml-heap')}
        continue
    candidates = {own[name]} if name in own else index.get(name + 'Theory.dat', set())
    assert len(candidates) == 1, (name, sorted(str(p) for p in candidates))
    data = next(iter(candidates))
    for ext in ['.dat', '.sig', '.sml']:
        assert data.with_suffix(ext).exists(), (name, ext)
    for ext in ['.dat', '.sig', '.sml', '.uo', '.ui']:
        f = data.with_suffix(ext)
        if f.exists():
            dependencies[str(f)] = sha(f)

git = lambda args, cwd: subprocess.check_output(['git'] + args, cwd=cwd, text=True).strip()
pin = '6eb1ed63544a2e22c151db9b575f4308b8f329b0'
assert git(['rev-parse', 'HEAD'], SRC) == pin
assert git(['rev-parse', 'HEAD^{tree}'], SRC) == 'ab2b12b545d8b6e725c47ac067f8c07705a47bd6'
assert git(['diff', '--name-only'], SRC) == 'Source/DafnyDriver/Commands/Bake.cs'
subprocess.run(['git', 'diff', '--check'], cwd=SRC, check=True)
assert not git(['diff', '--name-only'], FT / 'dafny')
patch = subprocess.check_output(['git', 'diff', '--', 'Source/DafnyDriver/Commands/Bake.cs'], cwd=SRC)
assert patch == (OUT / 'export-0003/frontend.patch').read_bytes()
assert hashlib.sha256(patch).hexdigest() == 'df88831bcc41bb19b3148aed5f69332cde0e626e33d21538da8ef4f4dbf04a6a'
assert sha(SRC / 'Source/DafnyDriver/Commands/Bake.cs') == records['export-0003']['source_sha256']
assert sha(SRC / 'Binaries/net8.0/DafnyDriver.dll') == records['export-0003']['driver_sha256']
build = read(OUT.parent / 'attempt-0001/build-identities-0002.json')
for name, digest in build['locks'].items():
    assert sha(SRC / name) == digest == sha(FT / 'dafny' / name), name
for name, digest in build['output_files'].items():
    assert sha(FT / 'dafny' / name) == digest, name

baseline = read(ROOT / 'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name, digest in baseline['protected'].items():
    assert sha(ROOT / name) == digest, name
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
prior_members = {}
for packet in ['compiled-behavior-20261104', 'resource-binding-20261104']:
    p = ROOT / 'proposals/refund-executable-feasibility' / packet
    members = read(p / 'manifest.json')
    for name, digest in members.items():
        assert sha(p / name) == digest, (packet, name)
    prior_members[packet] = len(members)
result = {
    'actual_exit': 0, 'recorded_exits': exits, 'source_sha256': sha(flat),
    'export_sha256': sha(export), 'frontend_pin': pin,
    'frontend_patch_sha256': hashlib.sha256(patch).hexdigest(),
    'frontend_driver_sha256': records['export-0003']['driver_sha256'],
    'dependency_locks': build['locks'], 'prior_frontend_outputs_unchanged': len(build['output_files']),
    'closure': closure, 'closure_node_count': len(closure), 'closure_axioms': sorted(axioms),
    'dependency_files': dependencies, 'dependency_file_count': len(dependencies),
    'builtin_dependencies': builtins, 'identical_exports': reproductions,
    'negative_reasons': negative_reasons, 'protected_files_unchanged': len(baseline['protected']),
    'native_sha256': sha(native), 'prior_packets_verified': prior_members,
    'scope': 'Identity and recorded-outcome audit; HOL proofs concern parsed AST behavior. Unverified frontend, Unicode connection, physical runtime and independent authenticated assurance remain explicit gaps.',
    'end_to_end': False,
}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in
                  ['closure', 'dependency_files', 'identical_exports', 'dependency_locks']}, indent=2))
