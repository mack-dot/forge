from pathlib import Path
import hashlib,json

root=Path('/Users/mackianni/forge');out=Path(__file__).resolve().parent;packet=out.parent
base=root/'proposals/refund-executable-feasibility'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
r=read(out/'INDEPENDENT-READBACK.json')
assert r['status']=='HOL_PARENT_LOAD_ENOENT' and r['HOL_process_exit']==1 and r['candidate_theorem_reached'] is False
baseline=read(base/'native-audit-20261104/records/baseline.json')
for n,h in baseline['protected'].items():assert sha((root/n).read_bytes())==h,n
assert sha((root/'FORGE_MISSION.md').read_bytes())==baseline['mission_sha256']
assert sha((base/'hosted-integrity-run-20261109/records/proposed-proof-workflow.yml').read_bytes())==r['workflow_sha256']
before=read(out/'tracking-before.json');original={n:(root/n).read_bytes() for n in before}
for n,b in original.items():assert len(b)==before[n]['bytes'] and sha(b)==before[n]['sha256'],n
assert b'U340' not in original['unsure.md']
roadmap='''## Frozen retry reaches HOL; parent theory path fails before candidate — U340

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
HOL_PARENT_LOAD_ENOENT. One approved retry executed; candidate theorem NOT_REACHED.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/preflight.py` |0|Exact approval/workflow/driver/manifests/candidate; prior attempt1,no competing runs |
| One rerun_workflow_job call |Tool success|Run42661020831,attempt2,job129430257438; unchanged commitf1e4a080 |
| Hosted sw_vers/sysctl/true/otool |0/0/0/0|Pinned ARM64 image and environment checks pass |
| Exact HOL child / workflow step |1/1|Parent QUse load duplicates .hol/objs; ENOENT; no timeout,exports or candidate invocation |
| Repeat / import / two negative HOL controls |NOT RUN|Stopped on first unexpected result |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/read_streams.py` |0|Full log and three chunked artifacts recovered; hashes match |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/validate_evidence.py` |1 then0|Initial seven-digit timestamp parse failure preserved; corrected interval parser only |
| Guessed source path / corrected source lookup |1/0|Read-only shell glob failure preserved; no extra HOL |

[Report](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/ASSURANCE.md).
Log SHA7fea30873cceeb1b199bfa468ccb4dde56ad2a4f884b95ef902241185c7d7cca.
Required image20261104.0514.1 observed;26196042 input bytes match;1493 before/after
hash checks and private-library gate pass.31s workflow step;provider343000ms,
0 billable ms reported. Actual child CPU/peak RSS unavailable,not inferred.
Bootstrap passes a physical parent theory path to virtual QUse loader,which adds
.hol/objs again. Same convention in U282/U291; static review missed this defect.
No theorem pass or counterexample. Smallest issue:review bootstrap theory paths;
no fix or new attempt made. Single retry authority consumed; no automatic retry.

'''
tracker='''## One frozen retry executes HOL but fails before theorem loading — U340

[Full result](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-proof-retry-20261109/ASSURANCE.md).
Attempt2 got the pinned ARM64 image. Inputs and private runtime checks passed.
First HOL child and workflow step exit1:QUse parent theory path resolves to
.hol/objs/.hol/objs/...Theory.sig and returns ENOENT. Candidate theorem not reached;
no exports,new closure,repeat,import or negative controls. No further attempt.
This is a frozen bootstrap integration defect,not a failed mathematical claim.
Earlier U282/U291 describe the same path convention; readiness review missed it.
Complete log/artifacts preserved. Independent evidence reader initial1/final0;
timestamp-parser failure retained. Three historical integrity controls remain
in-process rejections without separate exits. M1 open; Stage12 unauthorized;
end_to_end=false. Smallest next issue is bootstrap theory-file addressing under
separate review; no theorem,premise,dependency or protected change is justified
by this failure. Native/frame/composition/replay tasks remain separate.

'''
entry='''
## U340 — Approved retry launches HOL; physical parent path is translated twice

- References:U282,U291,U329,U335–U339. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner confirms exactly the single U339 retry,not an extra
  grant. One rerun_workflow_job call was issued; no automatic/further attempt.
- Preflight0 checks terminal attempt1,empty queues,exact approval/workflow/driver,
  manifest hashes and unchanged candidate. Run42661020831 becomes attempt2 with
  one job129430257438 at unchanged commitf1e4a080. No repository write or upload.
  Workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
- After queueing,runner1000000100 assigned. Actual Darwin arm64,UID501,macos15,
  image20261104.0514.1 matches guard. sw_vers/sysctl/true/otool0/0/0/0. mkstemp
  fd4/errno0,read/write match,denied-read EACCES13,64MiB probe and0700 root pass.
- Ten downloads match frozen manifest/part identities,total26196042 bytes.
  Both before/after checks report1493 unchanged inputs; private libpolyml/libgmp
  gate passes. Four saved states loaded; original MiniSat path remains false
  as required by frozen driver. No solver path or dependency changed.
- First HOL child exit1,wall_timeout=false,objects{}. Workflow step exit1.
  Bootstrap QUse.use passes physical pathmodel-0007/.hol/objs/
  forge_refundReadBoundaryTheory.sig. Actual ENOENT path adds .hol/objs again.
  Single-path parent exists in manifest; doubled path absent. stdout reaches
  PHASE basis-theory-load but never cf-library-load or unchanged-source phase.
  Candidate theorem NOT_REACHED. No theorem output,exports or new closure.
- Workflow stops at first unexpected result. Repeat,import,wrong-exception and
  omitted-event controls NOT RUN. No logical counterexample or failed tactic
  result is claimed. HOL ran,but the theorem was not tested or disproved.
- Complete log67204 bytes,SHA7fea30873cceeb1b199bfa468ccb4dde56ad2a4f884b95ef902241185c7d7cca.
  Stream reader0 recovers bootstrap3054B/stdout699B/stderr96851B with exact hashes.
  Independent reader first1:local Python rejects seven fractional timestamp
  digits. Initial source/error preserved. Corrected parser truncates excess
  sub-microsecond digits only for approximate interval; raw data unchanged.
  Final reader0 binds complete event counts,downloads,paths,exits and provider
  state. This validates failure evidence,not a theorem or independent authority.
- Resource capacity7516192768 memory bytes,49431048192 free temp-disk bytes.
  Workflow step31s;approx17.468184s invocation/result log interval includes
  wrapper/log handling. Provider duration343000ms includes wait; billing0 across
  both job IDs,reported count2 cumulative. Actual child CPU/peak RSS unavailable.
  CPU120s/wall150s/maxheap1536MiB/4MiB-file limits retained; no resource timeout.
- Initial read-only source glob exits1; corrected lookup0 finds quse.sml and
  virtual file translation. U282/U291 were read before resolving this issue.
  They record the same physical-versus-virtual theory-path convention. U337/U339
  static review did not catch this bootstrap defect; readiness confidence is
  superseded. No orchestration repair or new execution is authorized or applied.
-50 protected hashes and mission unchanged. Frozen statement quotation SHA
  289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a preserved
  as UNEXECUTED target,not theorem output. Earlier failures remain. Three U335
  integrity controls remain in-process rejections without separate exits.
- Evidence:proposals/refund-executable-feasibility/hosted-proof-retry-20261109/
  REPORT.md,ASSURANCE.md,records and MANIFEST.json. Journal prefix preserved.
  No protected change,Stage12,native/full-chain replay,signing,deployment,Git
  repair or new local commit. Provider/OS/runtime/connector/cached ancestry trust
  limits remain. Input integrity does not establish theorem correctness.
- Smallest next issue:review virtual theory-file addressing for bootstrap parent
  and later import loads. The theorem statement,premises and trusted dependencies
  need no change on current evidence. Any changed orchestration or further
  execution is a separate decision. M1 remains open and theorem unestablished.
'''
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
 b=original[n].decode();i=b.index('## ');(root/n).write_text(b[:i]+s+b[i:])
with (root/'unsure.md').open('ab') as f:f.write(entry.encode())
assert (root/'unsure.md').read_bytes()==original['unsure.md']+entry.encode()
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
 assert (root/n).read_text().replace(s,'',1)==original[n].decode()
write(out/'PRESERVATION.json',{'protected_paths':50,'mission_matches':True,'frozen_workflow_matches':True,'journal_prefix_preserved':True,'end_to_end':False})
write(out/'tracking-after.json',{n:{'before':before[n],'after_sha256':sha((root/n).read_bytes())} for n in before})
write(out/'command-results.json',{'commands':[
 {'argv':['python3','-B',str(out/'preflight.py')],'actual_exit':0},
 {'argv':['python3','-I','-B',str(out/'read_streams.py')],'actual_exit':0},
 {'argv':['python3','-I','-B',str(out/'validate_evidence.py')],'actual_exit':1,'source':'validate_evidence_initial.py'},
 {'argv':['python3','-I','-B',str(out/'validate_evidence.py')],'actual_exit':0,'source':'validate_evidence.py'}],
 'hosted_HOL_process_exit':1,'hosted_step_exit':1,'candidate_theorem_reached':False,'end_to_end':False})
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file() and p!=packet/'MANIFEST.json'}
write(packet/'MANIFEST.json',{'files':files,'status':'HOL_PARENT_LOAD_ENOENT','retry_calls':1,'HOL_process_executed':True,'candidate_theorem_reached':False,'end_to_end':False})
for n,h in files.items():assert sha((packet/n).read_bytes())==h,n
print(json.dumps({'packet_members':len(files),'protected_paths':50,'journal_prefix_preserved':True,'HOL_process_exit':1,'candidate_theorem_reached':False,'end_to_end':False}))
