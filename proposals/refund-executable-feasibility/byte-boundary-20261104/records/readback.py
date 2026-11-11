"""Audit recorded outcomes, source preservation and exact artifact identity."""
from pathlib import Path
import csv, hashlib, json, re
ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
HT = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
assert not (OUT / 'readback.json').exists()
expected = {'dafny-0001':4, 'dafny-0002':0, 'dafny-repeat':0, 'frontend-verify':0,
            'dafny-lossy':4, 'dafny-swapped':4, 'dafny-audit':0,
            'hol-0001':1, 'hol-0002':1, 'hol-0003':0, 'hol-repeat':0,
            'hol-lossy':1, 'hol-swapped':1, 'hol-import':1, 'hol-import-0002':0}
records = {name: read(OUT / name / 'command.json') for name in expected}
log = lambda n: (OUT / n / 'stdout.log').read_text() + (OUT / n / 'stderr.log').read_text()
for name, code in expected.items():
    r = records[name]
    assert r['actual_exit'] == code and r['end_to_end'] is False, name
    for p,digest in r.get('inputs',{}).items():
        assert sha(OUT / name / 'inputs' / p) == digest, (name,p)
    if 'source_sha256' in r:
        assert sha(OUT / name / 'audit.sml') == r['source_sha256']
    for p,digest in r.get('objects',{}).items():
        assert sha(OUT / name / p) == digest, (name,p)

base = read(OUT / 'baseline.json')
for p,digest in base['source_files'].items():
    assert sha(OUT/'inputs'/p) == digest
    assert sha(ROOT/'proposals/refund-executable-feasibility/unicode-20261104'/p) == digest
positive = records['dafny-0002']
csv_outcomes = None
for case in ['dafny-0002','dafny-repeat','frontend-verify']:
    assert records[case]['inputs'] == positive['inputs']
    assert '1458 verified, 0 errors' in log(case)
    rows = list(csv.DictReader((OUT/case/'inputs/verification.csv').open()))
    assert len(rows)==1458 and all(x['TestResult.Outcome']=='Passed' for x in rows)
    outcomes=sorted((x['TestResult.DisplayName'],x['TestResult.Outcome']) for x in rows)
    if csv_outcomes is None: csv_outcomes=outcomes
    else: assert outcomes == csv_outcomes
driver=ROOT/'.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll'
assert sha(driver)==records['frontend-verify']['driver_sha256']=='55d26351d36b660ac6b1ea6eac7515cc4b15bc9a5f139f375a1a9e6f90455acb'
assert '0 findings' in log('dafny-audit')
for name in ['dafny-lossy','dafny-swapped']:
    assert 'Error:' in log(name) and 'postcondition' in log(name)
    assert 'out of resource' not in log(name).lower()
    assert 'parse errors' not in log(name).lower()
assert 'Codes(s)[i] == s[i] as int' in log('dafny-lossy')
assert 'var qb := Codes(U.Encoded(context.requestId))' in log('dafny-swapped')
for name,reason in [('hol-lossy','byte_roundtrip'),('hol-swapped','byte_fields_result')]:
    assert f'Failed to prove theorem "{reason}"' in log(name)
    assert 'BYTE_BOUNDARY_COMPLETE' not in log(name) and not records[name]['objects']
assert 'CHR (h MOD 128)' in log('hol-lossy')
assert 'cb = qb' in log('hol-swapped')
assert 'Exact statement mismatch: byte_string_def' in log('hol-import')
assert records['hol-0003']['objects']==records['hol-repeat']['objects']
assert len(records['hol-0003']['objects'])==4
assert records['hol-0003']['source_sha256']==records['hol-repeat']['source_sha256']==sha(OUT/'byte-proof.sml')
for name in ['hol-0003','hol-repeat']:
    assert records[name]['bridge_complete'] and 'BYTE_BOUNDARY_COMPLETE' in log(name)
text=log('hol-import-0002')
assert records['hol-import-0002']['import_complete']
assert len(re.findall(r'^IMPORTED .* EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0$',text,re.M))==9
closure={n:ps.split(',') if ps else [] for n,ps in re.findall(r'^CLOSURE_NODE ([^:]+):(.*)$',text,re.M)}
assert all(p in closure for ps in closure.values() for p in ps)
axioms=set(re.findall(r'^CLOSURE_AXIOM (.*)$',text,re.M))
assert axioms=={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
index={}
for p in HT.rglob('*Theory.dat'):index.setdefault(p.name,set()).add(p.resolve())
own={'forge_refundByteBoundary':OUT/'hol-0003/.hol/objs/forge_refundByteBoundaryTheory.dat',
     'forge_refundSourceBinding':ROOT/'results/refund-source-binding-2026-11-04/attempt-0002/hol-0004/.hol/objs/forge_refundSourceBindingTheory.dat'}
files={};builtins={}
for name in closure:
    if name=='min':
        assert closure[name]==[]
        p=HT/'HOL/src/postkernel/Theory.sml'
        assert 'The "min" theory is already installed; it has no parents.' in p.read_text()
        builtins[name]={'source_sha256':sha(p),'heap_sha256':sha(HT/'cakeml/misc/cakeml-heap')}
        continue
    candidates={own[name]} if name in own else index.get(name+'Theory.dat',set())
    assert len(candidates)==1,(name,[str(p) for p in candidates])
    p=next(iter(candidates))
    for ext in ['.dat','.sig','.sml']:assert p.with_suffix(ext).exists()
    for ext in ['.dat','.sig','.sml','.uo','.ui']:
        f=p.with_suffix(ext)
        if f.exists():files[str(f)]=sha(f)
protected=read(ROOT/'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name,digest in protected['protected'].items():assert sha(ROOT/name)==digest,name
assert sha(ROOT/'FORGE_MISSION.md')==protected['mission_sha256']
native=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native)=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
packets={}
for name in ['source-model-binding-20261104','compiled-behavior-20261104','resource-binding-20261104']:
    p=ROOT/'proposals/refund-executable-feasibility'/name;m=read(p/'manifest.json')
    for f,d in m.items():assert sha(p/f)==d
    packets[name]=len(m)
result={'actual_exit':0,'recorded_exits':expected,'source_files_unchanged':len(base['source_files']),
        'positive_inputs':positive['inputs'],'boundary_sha256':sha(OUT/'inputs/Boundary.dfy'),
        'dafny_assertion_batches':1458,'identical_symbol_outcomes':True,
        'frontend_driver_sha256':sha(driver),'HOL_proof_sha256':sha(OUT/'byte-proof.sml'),
        'identical_exports':records['hol-0003']['objects'],'closure':closure,'closure_node_count':len(closure),
        'closure_axioms':sorted(axioms),'dependency_files':files,'dependency_file_count':len(files),
        'builtin_dependencies':builtins,'protected_files_unchanged':len(protected['protected']),
        'native_sha256':sha(native),'prior_packet_members':packets,
        'scope':'Shared byte-list interface locally checked in Dafny and HOL; no verified inter-kernel translation, runtime proof or authentication inferred.',
        'end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['closure','dependency_files','positive_inputs','identical_exports']},indent=2))
