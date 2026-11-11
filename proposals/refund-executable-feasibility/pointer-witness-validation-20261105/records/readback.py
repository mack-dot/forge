"""Bind actual HOL records to exact files; this does not check proofs."""
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
logs = lambda n: ''.join((OUT/n/f).read_text() for f in ('stdout.log','stderr.log'))
assert not (OUT/'readback.json').exists()
expected = {'pointer-0001':1,'pointer-0002':1,'normalization-diagnostic':0,'pointer-0003':0,
            'pointer-repeat':0,'exact-import-0001':0,'wrong-pointer':1,'missing-prefix':1,'missing-space':1}
records = {n:read(OUT/n/'command.json') for n in expected}
heap = sha(TC/'cakeml/misc/cakeml-heap')
for n, code in expected.items():
    r = records[n]
    assert r['actual_exit'] == code and r['end_to_end'] is False, n
    source = OUT/n/('proof.sml' if 'completion_marker' in r else 'audit.sml')
    assert sha(source) == r['source_sha256'] and r['heap_sha256'] == heap, n
    for f,h in r.get('objects',{}).items():
        assert sha(OUT/n/f) == h, (n,f)
    for parent, objects in r.get('imported_objects',{}).items():
        for f,h in objects.items():
            assert sha(OUT/n/parent/f) == h == sha(OUT/parent/f), (n,parent,f)
    if 'completion_marker' in r:
        assert r['completion_marker'] == (n in ('pointer-0003','pointer-repeat')), n
    else:
        assert r['import_complete'] == (n == 'exact-import-0001'), n
for n in ('pointer-0001','pointer-0002'):
    assert 'Pointer premise shape mismatch' in logs(n)
    for name in ('refund_initializer_oracle_independence','refund_pointer_fixed_point','refund_fixed_syntax_pointer_witness'):
        assert 'Saved theorem' in logs(n) and name in logs(n)
assert 'POINTER_NORMALIZATION_DIAGNOSTIC_COMPLETE' in logs('normalization-diagnostic')
for marker in ('SECOND_NORMALIZATION_MATCH false','WITNESS_CHANGED false','REQUIRED_CHANGED false'):
    assert marker in logs('normalization-diagnostic')
a,b = records['pointer-0003'],records['pointer-repeat']
assert a['objects'] == b['objects'] and len(a['objects']) == 4
assert a['source_sha256'] == b['source_sha256']
for n in ('pointer-0003','pointer-repeat'):
    assert 'REMAINING_ANTECEDENTS 7' in logs(n)
log = logs('exact-import-0001')
markers = re.findall(r'^IMPORTED .*$',log,re.M)
assert len(markers) == 4 and all('HYPOTHESES 0 TAGGED_AXIOMS 0' in x for x in markers)
assert len([x for x in markers if 'KERNEL_NORMALIZED_EXACT true' in x]) == 3
assert 'KERNEL_PREMISES_EQUIVALENT true' in markers[3]
for n in ('wrong-pointer','missing-prefix','missing-space'):
    assert all(x in logs(n) for x in markers), n
    assert 'AFTER_POSITIVE_AUDIT' in logs(n), n
    assert 'UNEXPECTED_CONTROL_ACCEPTANCE' not in logs(n), n
assert 'Exact statement mismatch: refund_fixed_syntax_pointer_witness' in logs('wrong-pointer')
assert 'Exact statement mismatch: refund_pointer_fixed_point' in logs('missing-prefix')
assert 'First unsolved sub-goal is' in logs('missing-space')
assert 'data_lang_safe_for_space' in logs('missing-space') and 'unsolved goals' in logs('missing-space')
closure = {n:p.split(',') if p else [] for n,p in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',log,re.M)}
assert closure and all(p in closure for ps in closure.values() for p in ps)
axioms = set(re.findall(r'^CLOSURE_AXIOM (.*)$',log,re.M))
assert axioms == {'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
exports = {'pointer-0003':a['objects']}
for name in ('space-parent','trace-parent','word-parent','data-parent','refund-parent',
             'init-parent','epoch-parent','oracle-parent','stack-parent'):
    r = read(OUT/name/'command.json')
    assert r['actual_exit'] == 0 and r['completion_marker']
    exports[name] = r['objects']
    for f,h in r['objects'].items():
        assert sha(OUT/name/f) == h
index = {}
for p in TC.rglob('*Theory.dat'):
    index.setdefault(p.name,set()).add(p.resolve())
own = {Path(f).name:OUT/n/f for n,objs in exports.items() for f in objs if f.endswith('Theory.dat')}
files,builtins = {},{}
for name in closure:
    if name == 'min':
        p = TC/'HOL/src/postkernel/Theory.sml'
        assert closure[name] == []
        assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
        builtins[name] = {'source_sha256':sha(p),'heap_sha256':heap}
        continue
    filename = name+'Theory.dat'
    paths = {own[filename]} if filename in own else index.get(filename,set())
    assert len(paths) == 1, (name,paths)
    p = next(iter(paths))
    for ext in ('.dat','.sig','.sml'):
        assert p.with_suffix(ext).is_file()
    for ext in ('.dat','.sig','.sml','.uo','.ui'):
        q = p.with_suffix(ext)
        if q.exists(): files[str(q)] = sha(q)
base = read(OUT/'baseline.json')
sources = dict(base['source_hashes'])
if (OUT/'next-source.json').exists(): sources.update(read(OUT/'next-source.json'))
for name, digest in sources.items():
    data = subprocess.check_output(['git','show','cd9155694c16831373ab695a670794f23282ed62:'+name],cwd=TC/'cakeml')
    assert hashlib.sha256(data).hexdigest() == digest == sha(OUT/'upstream'/name) == sha(TC/'cakeml'/name)
for name,digest in base['protected'].items():
    assert sha(ROOT/name) == digest,name
assert sha(ROOT/'FORGE_MISSION.md') == base['mission_sha256']
native = ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == base['native_sha256']
pins = {'cakeml':'cd9155694c16831373ab695a670794f23282ed62','HOL':'9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for name,pin in pins.items():
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=TC/name).decode().strip() == pin
    assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=TC/name).returncode == 0
prior_packets = {}
for name in ('runtime-premises-20261104','installation-premise-20261104','target-install-bridge-20261105',
             'closure-install-20261105','config-install-20261105','word-applicability-20261105',
             'word-initialization-20261105','word-oracle-20261105','word-oracle-validation-20261105',
             'stack-initialization-checkpoint-20261105','stack-initialization-validation-20261105'):
    p = ROOT/'proposals/refund-executable-feasibility'/name
    manifest = read(p/'manifest.json')
    for f,h in manifest.items(): assert sha(p/f) == h,(name,f)
    prior_packets[name] = {'manifest_sha256':sha(p/'manifest.json'),'members':len(manifest)}
result = {'actual_exit':0, 'recorded_child_exits':expected, 'new_theorems':4,
          'checked_statements':4, 'remaining_antecedents':7, 'identical_exports':a['objects'],
          'closure':closure, 'closure_node_count':len(closure), 'closure_axioms':sorted(axioms),
          'dependency_files':files, 'dependency_file_count':len(files), 'builtin_dependencies':builtins,
          'pinned_source_hashes':sources, 'toolchain_commits':pins, 'tracked_toolchain_diffs':0,
          'protected_files_unchanged':len(base['protected']), 'prior_packets':prior_packets,
          'native_sha256':sha(native), 'mission_sha256':sha(ROOT/'FORGE_MISSION.md'),
          'scope':'Exact initializer oracle independence and published pointer fixed point supply a checked witness; seven source/resource/state conditions remain.',
          'successful_or_physical_initialization':'NOT_ESTABLISHED',
          'independent_full_chain_replay':'NOT RUN', 'new_native_or_hosted_execution':'NOT RUN',
          'end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('dependency_files','closure','pinned_source_hashes','identical_exports')},indent=2))
