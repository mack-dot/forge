from pathlib import Path
import hashlib, json

root=Path('/Users/mackianni/forge')
out=Path(__file__).resolve().parent
packet=out.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
result=read(out/'TERMINAL-READBACK.json')
assert result['status']=='HOSTED_RUNNER_NOT_ASSIGNED' and result['proof_actual_exit'] is None
assert result['HOL_executed'] is False and result['retry_authorized'] is False
before=read(out/'tracking-before.json')
original={name:(root/name).read_bytes() for name in before}
for name,data in original.items():
    assert len(data)==before[name]['bytes'] and sha(data)==before[name]['sha256'],name
assert b'U338' not in original['unsure.md']
roadmap='''## Authorized frozen proof attempt ends without a runner — U338

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
HOSTED_RUNNER_NOT_ASSIGNED. One authorized job triggered; no HOL execution.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -B -` frozen-scope/branch/trigger preflight |0|Exact approved workflow and prior evidence; other12 workflows do not trigger |
| `python3 -I -B -` pre-trigger remote workflow/commit check |0|Sole changed workflow; exact approved16385 bytes and Git blob |
| Tree/commit creation and lease-checked branch update |Tool success|One trigger,commitf1e4a080; no force or retry |
| Hosted run / sole job |failure / cancelled|Run42661020831,job129312292711,attempt1; runner_id0,no steps |
| Environment / proof / repeat / import / two negative controls |NOT RUN|No actual OS exits,theorem output or dependency closure |
| Full log / optional check-run reason reads |404 / 400 tool errors|BlobNotFound; unsupported reason endpoint; both preserved |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/validate_terminal.py` |0|Separate terminal evidence binding; validates failure report,not proof |

[Report](proposals/refund-executable-feasibility/hosted-proof-run-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-proof-run-20261109/ASSURANCE.md).
Provider duration902000ms,0 billable MACOS ms; actual proof CPU/RSS unavailable.
Workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
Pinned image guard never reached. Exact scheduler cause UNKNOWN; no allocation
was recorded. Three prior integrity mutations remain in-process rejections
without separate exits.217 prior packet members and50 protected paths unchanged.
Smallest issue:assigned macOS ARM64 runner that passes frozen image guard.
The one-job authority is consumed; another attempt requires separate approval.
No native/frame/composition/replay work,Stage12,signing or deployment occurred.

'''
tracker='''## Authorized proof attempt stopped before runner allocation — U338

[Terminal evidence](proposals/refund-executable-feasibility/hosted-proof-run-20261109/REPORT.md),
[assurance matrix](proposals/refund-executable-feasibility/hosted-proof-run-20261109/ASSURANCE.md).
The exact frozen workflow was published and triggered once. Run42661020831
ended failure; sole job129312292711 ended cancelled,with runner_id0 and no steps.
No proof,repeat,import or negative HOL control ran. No process exits,theorem
statements,exports or closure are available. Full job-log read returned404;
provider reports902000ms elapsed and0 billable MACOS ms. Cause beyond the lack
of runner assignment is unknown. Separate evidence reader0 confirms this report.
U335/U336 transfer integrity remains TESTED. Three integrity mutation controls
retain in-process rejections without separate OS exits.217 prior packet files
and50 protected hashes remain unchanged. No proof statement or dependency changed.
Next:an assigned runner passing the unchanged image guard,with separate approval
for any new attempt. No retry remains authorized. Native correspondence,
composition and full-chain replay stay separate. M1 open; Stage12 unauthorized;
end_to_end=false.

'''
entry='''
## U338 — Authorized frozen HOL attempt cancelled without an assigned runner

- References:U329,U335–U337. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner authorized one frozen hosted proof job and conditional
  repeat/import/two controls,with stop on first unexpected result. No retry scope.
- Local frozen-scope preflight exits0. Exact approved workflow/driver/manifest
  packet hashes and parent8ad9de1 match. All12 other workflow identities and
  trigger definitions checked; none triggers on this branch push.
- Remote workflow/commit readback exits0 before branch update. New commit
  f1e4a080fd4c33aa1072c93fe4757e16805ab484 has only modified path
  .github/workflows/m1-macos-preflight.yml.16385 bytes,SHA256
  1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1;
  Git blobc6bdbde3f8612de474d1423216efce545c813f25. Parent lease checked,
  no force. Final branch read matches. No source upload or protected change.
- One run42661020831,attempt1,one job129312292711. Successive job reads remain
  queued until terminal cancellation. Run conclusion failure; job conclusion
  cancelled. Full job API:runner_id0,runner_name empty,steps[]. One run at head.
  These are provider conclusions,not OS process exit codes. No retry occurred.
- No environment/input-download/HOL command executed. Pinned ARM64/image
  20261104.0514.1 guard was not reached; no image observation or substitution.
  Proof/repeat/import/negative controls NOT RUN. Actual process exits,theorem
  statements,export hashes and dependency closures are unavailable,not passes.
- Full log request returns404 BlobNotFound. Optional check-run reason read
  returns connector400 unsupported endpoint. Raw responses preserved. Artifact
  list empty. Local stream reader not run because no hosted log exists.
- Provider reports902000ms run duration,0 billable MACOS ms,one job. No actual
  proof CPU or peak RSS exists. API started_at equals creation but no runner or
  steps are recorded; that timestamp is not evidence of execution. The interval
  resembles the15-minute limit,but precise scheduler cause remains UNKNOWN.
  No account,capacity,billing,image-availability or external-cancellation cause
  is established. The observed issue is absent runner assignment.
- Separate validate_terminal.py exits0,imports no producer checker,and binds
  frozen workflow/blob,parent/change list,current head,one run/job/attempt,
  terminal conclusions,timing,no artifacts and log failure. This validates the
  environmental-failure report,not a theorem. Same provider/agent trust remains.
- All217 manifest-listed U333–U337 packet members,50 protected files and mission
  match. No old uncertainty bytes,proof premises,dependencies or failures changed.
  Three prior integrity controls remain in-process ValueError rejections with
  no separate exits; enclosing checker exit0 only. New HOL controls have no exits.
- Evidence:proposals/refund-executable-feasibility/hosted-proof-run-20261109/
  REPORT.md,ASSURANCE.md,records and MANIFEST.json. Queued checkpoint preserved
  and superseded by TERMINAL-READBACK.json. No local Git repair/commit claimed.
- Impact:one authorized attempt ended unsuccessfully before mathematical work.
  Original generic TextIO.read obligation remains unchanged and untested here.
  Next check:runner allocation and unchanged pinned-image guard,only under
  separate approval for another attempt. No retry remains authorized. Native
  memory/frame,whole-program composition and21-snapshot replay stay separate.
'''
for name,addition in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
    data=original[name].decode();index=data.index('## ')
    (root/name).write_text(data[:index]+addition+data[index:])
with (root/'unsure.md').open('ab') as f:f.write(entry.encode())
assert (root/'unsure.md').read_bytes()==original['unsure.md']+entry.encode()
for name,addition in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
    assert (root/name).read_text().replace(addition,'',1)==original[name].decode()
write(out/'tracking-after.json',{name:{'before':before[name],'after_sha256':sha((root/name).read_bytes())} for name in before})
write(out/'command-results.json',{'commands':[
    {'argv':['python3','-B','-'],'purpose':'Frozen-scope,branch,trigger and preservation preflight','actual_exit':0,'result':'PREFLIGHT.json'},
    {'argv':['python3','-I','-B','-'],'purpose':'Remote commit and workflow pre-trigger readback','actual_exit':0,'result':'PRE-TRIGGER.json'},
    {'argv':['python3','-I','-B',str(out/'validate_terminal.py')],'purpose':'Terminal failure evidence validation','actual_exit':0,'result':'TERMINAL-READBACK.json'}],
    'hosted_process_exits':None,'HOL_executed':False,'end_to_end':False})
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file() and p!=packet/'MANIFEST.json'}
write(packet/'MANIFEST.json',{'files':files,'status':result['status'],'hosted_runs':1,'HOL_executed':False,'retry_authorized':False,'end_to_end':False})
for name,digest in files.items():assert sha((packet/name).read_bytes())==digest
print(json.dumps({'packet_members':len(files),'journal_prefix_preserved':True,'status':result['status'],'HOL_executed':False,'end_to_end':False}))
