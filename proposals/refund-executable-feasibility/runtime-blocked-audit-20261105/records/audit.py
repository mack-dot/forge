from pathlib import Path
import hashlib,json,subprocess,re
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
packets={}
for name in ['exception-compiler-20261105','read-runtime-20261105','native-error-instructions-20261105']:
    p=ROOT/'proposals/refund-executable-feasibility'/name
    m=read(p/'MANIFEST.json')['files']
    for rel,h in m.items():assert sha(p/rel)==h,(name,rel)
    packets[name]=len(m)
old=OUT.parent/'attempt-0009'
prep=read(old/'replay-preparation.json')
for name,item in prep['source_files'].items():
    assert sha(item['original_path'])==item['sha256']==sha(old/item['snapshot']),name
assert len(prep['source_files'])==21
readback310=read(old/'readback.json');readback315=read(OUT.parent/'attempt-0010/readback.json')
assert sha(old/'proof-0001/.hol/objs/forge_refundRejectCompiledTheory.dat')==readback310['data_sha256']
assert sha(OUT.parent/'attempt-0010/model-0007/.hol/objs/forge_refundReadBoundaryTheory.dat')==readback315['data_sha256']
assert readback310['closure_nodes']==486 and readback315['closure_nodes']==147
expected_axioms={'bool.SELECT_AX','bool.INFINITY_AX','bool.ETA_AX','bool.BOOL_CASES_AX'}
assert set(readback310['foundation_axioms'])==expected_axioms==set(readback315['foundation_axioms'])
native={}
for name in ['native-build-0001','native-repeat-0001']:
    p=OUT.parent/'attempt-0004'/name/'refund'
    native[name]=sha(p)
    assert native[name]=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
fail=OUT.parent/'attempt-0011/dependency-diagnostic'
assert read(fail/'command.json')['actual_exit']==1
assert 'SysErr ("Operation not permitted", SOME EPERM)' in (fail/'stdout.log').read_text()
preflight=read(OUT.parent/'attempt-0010/replay-preflight.json')
assert preflight['reviewer_controlled_clean_environment']=='NOT_ESTABLISHED'
assert preflight['independent_source_acquisition_and_bootstrap_provenance']=='NOT_ESTABLISHED'
assert preflight['independent_full_chain_replay']=='NOT_RUN' and preflight['replay_gate']=='NO_GO'
latest=read(OUT.parent/'attempt-0011/readback.json')
assert latest['new_native_step_theorems']==0 and latest['independent_full_chain_replay']=='NOT_RUN'
baseline=read(OUT.parent/'attempt-0001/baseline.json')
for rel,h in baseline['protected'].items():assert sha(ROOT/rel)==h,rel
assert sha(ROOT/'FORGE_MISSION.md')==baseline['mission_sha256']
for rec in read(OUT.parent/'attempt-0011/tracking-update.json')['journals']:
    b=Path(rec['path']).read_bytes();n=rec['prefix_bytes'];k=rec['appended_bytes']
    assert hashlib.sha256(b[:n]).hexdigest()==rec['prefix_sha256']
    assert hashlib.sha256(b[n:n+k]).hexdigest()==rec['appended_sha256']
commands=[]
for args in [['rev-parse','HEAD'],['status','--porcelain'],['diff','--exit-code','HEAD','--','spec','spec.lock','policy','gate','FORGE_MISSION.md']]:
    argv=['git','-C',str(WT)]+args;r=subprocess.run(argv,capture_output=True,text=True)
    commands.append({'argv':argv,'actual_exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
    assert r.returncode==0
    if args[0]=='rev-parse':assert r.stdout.strip()=='6ce40d4663e17499b6157f9b83d669e44b0208a6'
    else:assert not r.stdout
turns=[
    {'turn':'Original goal turn, U315','classification':'PROGRESS','common_blocker':'No validated reviewer-controlled clean execution environment or independent bootstrap/source provenance; replay NOT RUN.'},
    {'turn':'First continuation, U316','classification':'PROGRESS','common_blocker':'Same independent execution/provenance prerequisite remains unavailable. Alternate existing instruction-proof infrastructure fails before any instruction theorem; standard SAT diagnostic reports EPERM.'},
    {'turn':'Current continuation','classification':'Completion and blocked audit; no new proof progress','common_blocker':'Same independent execution/provenance prerequisite remains unvalidated. No new authorized context or successful dependency/observer run has been supplied or found in the inspected mission/replay evidence.'}]
result={'actual_exit':0,'parent_commit':'6ce40d4663e17499b6157f9b83d669e44b0208a6',
        'previous_goal_turn_classification':'PROGRESS','prior_packet_members':packets,
        'prior_packet_members_total':sum(packets.values()),'source_snapshots_match':21,
        'native_sha256':native,'protected_files_unchanged':len(baseline['protected']),
        'prior_journal_prefixes_preserved':True,'git_commands':commands,
        'accepted_theory_data_sha256':{'U310':readback310['data_sha256'],'U315':readback315['data_sha256']},
        'prior_closure_counts':{'U310':486,'U315':147},'foundation_axioms':sorted(expected_axioms),
        'scope':'Fresh identity and requirement audit of retained evidence; no new proof, native execution, signature verification, or independent replay.',
        'completion_audit':'NOT_ACHIEVED','blocked_audit':{'consecutive_goal_turns':turns,'threshold_satisfied':True,
          'same_condition':'Required independent execution context and provenance are not validated. No authorized available path can complete the physical correspondence/replay here.',
          'important_distinction':'The SAT EPERM itself was observed in U316 only; it is not counted as three independent failures or attributed to an unobserved syscall.',
          'no_verified_wait':'All our prior proof/observer command handles returned terminal exit codes. No live handle is being awaited.',
          'meaningful_local_progress_available':False,'external_change_required':True},
        'required_next_context':'An explicitly authorized working proof/observer context plus a reviewer-controlled clean replay environment with verified source/bootstrap provenance. Do not use producer caches as independent inputs.',
        'smallest_open_proof':'One exact ffiread call must match the published model in OS result, complete buffer, filesystem effects, valid return state and full FFI frame.',
        'new_SAT_debugger_native_or_replay_execution':'NOT_RUN','end_to_end':False}
(OUT/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
paths=[b/n for b in [ROOT,WT] for n in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']]
uid='U'+str(1+max(int(n) for b in [ROOT,WT] for n in re.findall(r'^## U(\d+)\b',(b/'unsure.md').read_text(),re.M)))
(OUT/'tracking-baseline.json').write_text(json.dumps({'entry':uid,'files':{str(p):{'sha256':sha(p),'bytes':p.stat().st_size} for p in paths},'end_to_end':False},indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['actual_exit','prior_packet_members','source_snapshots_match','protected_files_unchanged','completion_audit','blocked_audit','end_to_end']},indent=2))
