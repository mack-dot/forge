from pathlib import Path
import hashlib,json,subprocess
ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def logs(case):return (OUT/case/'stdout.log').read_text()+(OUT/case/'stderr.log').read_text()
inputs=read(OUT.parent/'attempt-0009/inputs.json')['input_files']
for p,h in inputs.items():assert sha(p)==h,p
for p,h in read(OUT/'baseline.json')['step_tools'].items():assert sha(p)==h,p
for p,h in read(OUT/'arm8-tool-inputs.json')['files'].items():assert sha(p)==h,p
sources=read(OUT/'source-inspection.json')['files']
for p,rec in sources.items():assert sha(p)==rec['sha256']==sha(OUT/rec['snapshot'])
cases=['inspect-steps','inspect-steps-0002','inspect-arm8-steps','dependency-diagnostic']
records={}
for case in cases:
    rec=read(OUT/case/'command.json')
    assert rec['actual_exit']==1 and not rec['completion_marker'] and not rec['objects'],case
    assert sha(OUT/case/'proof.sml')==rec['source_sha256'],case
    records[case]=rec
assert 'Cannot find file arm8_stepLib.ui' in logs('inspect-steps')
assert 'utilsLib.sml' in logs('inspect-steps-0002')
assert 'arm8_stepLib.sml' in logs('inspect-arm8-steps')
diag=(OUT/'dependency-diagnostic/stdout.log').read_text()
assert 'DIAGNOSTIC_SAT_TERM probe ∨ ¬probe' in diag
assert 'SysErr ("Operation not permitted", SOME EPERM)' in diag
for case in cases:
    assert 'STEP_THEOREM ' not in (OUT/case/'stdout.log').read_text()
static=read(OUT/'static-native/command.json')
assert static['actual_exit']==0 and not static['native_launched']
assert sha(OUT/'static-native/commands.lldb')==static['commands_sha256']
binding=read(OUT/'native-word-binding.json')
assert binding['actual_exit']==0 and binding['all_disassembled_words_matched']==28
for build in binding['builds']:
    path=OUT.parent/'attempt-0004'/build['name']/'refund'
    assert sha(path)==build['executable_sha256']
    data=path.read_bytes()
    fragment=data[binding['ffiread_file_offset']:binding['ffiread_file_offset']+binding['ffiread_bytes']]
    assert hashlib.sha256(fragment).hexdigest()==build['ffiread_sha256']==sha(OUT/'native-ffiread.bin')
    for step in binding['error_path_words']:
        offset=step['file_offset']
        assert data[offset:offset+4]==bytes.fromhex(step['word'])[::-1]
packets={}
for name in ['read-runtime-20261105','exception-compiler-20261105']:
    p=ROOT/'proposals/refund-executable-feasibility'/name
    m=read(p/'MANIFEST.json')['files']
    for rel,h in m.items():assert sha(p/rel)==h,(name,rel)
    packets[name]=len(m)
baseline=read(OUT.parent/'attempt-0001/baseline.json')
for rel,h in baseline['protected'].items():assert sha(ROOT/rel)==h,rel
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
prior=read(OUT.parent/'attempt-0010/tracking-update.json')
for rec in prior['journals']:
    b=Path(rec['path']).read_bytes();n=rec['prefix_bytes'];k=rec['appended_bytes']
    assert hashlib.sha256(b[:n]).hexdigest()==rec['prefix_sha256']
    assert hashlib.sha256(b[n:n+k]).hexdigest()==rec['appended_sha256']
argv=['git','-C',str(TC/'HOL'),'diff','--exit-code','HEAD','--']
r=subprocess.run(argv,capture_output=True,text=True)
assert r.returncode==0
result={'actual_exit':0,'commands':{case:1 for case in cases},
        'static_inspection_exit':0,'prior_goal_turn':'PROGRESS',
        'parent_files_checked':len(inputs),'upstream_source_snapshots':len(sources),
        'prior_packet_members':packets,'new_native_step_theorems':0,
        'native_error_path_words':binding['error_path_words'],
        'native_sha256':binding['builds'][0]['executable_sha256'],
        'native_fragment_sha256':binding['builds'][0]['ffiread_sha256'],
        'toolchain_source_diff':{'argv':argv,'actual_exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr},
        'protected_files_unchanged':len(baseline['protected']),'journal_prefixes_preserved':True,
        'proof_repeat_import_negative_controls':'NOT_RUN: no new instruction theory exported',
        'new_native_execution':'NOT_RUN','independent_full_chain_replay':'NOT_RUN',
        'smallest_open_physical_obligation':'One exact ffiread transition must refine the published model with OS result, full buffer, filesystem relation and FFI state/frame together.',
        'tool_blocker':'Standard HOL SAT_PROVE returns SysErr Operation not permitted (EPERM); exact syscall/path not established. No reroute or dependency changes.',
        'end_to_end':False}
(OUT/'readback.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
