from pathlib import Path
import hashlib,json

root=Path('/Users/mackianni/forge')
out=Path(__file__).resolve().parent
packet=out.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
result=read(out/'INSPECTION.json')
assert result['actual_exit']==0 and result['retry_dispatched'] is False
before=read(out/'tracking-before.json')
original={n:(root/n).read_bytes() for n in before}
for n,b in original.items():assert len(b)==before[n]['bytes'] and sha(b)==before[n]['sha256']
assert b'U339' not in original['unsure.md']
roadmap='''## Scheduling inspected; one unchanged retry awaits approval — U339

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The theorem remains unestablished,not disproved. No retry or HOL execution.

| EXIT command/action | Actual exit/result | Result |
| --- | --- | --- |
| Run/jobs/repository/queued/in-progress/pending approvals/frozen workflow reads |Tool success|Same cancelled job,no runner/steps; no currently queued/running work or pending approvals |
| Workflow settings metadata / public run page |400 / cache miss|Preserved; exact cancellation reason and account restrictions still unknown |
| `python3 -B proposals/refund-executable-feasibility/proof-retry-review-20261109/records/inspect_retry.py` |0|Exact frozen workflow/candidate and one-call retry scope; no proof/input audit repeated |
| Retry / HOL / repeat / import / negative controls |NOT RUN|Separate owner authorization required |

[Inspection](proposals/refund-executable-feasibility/proof-retry-review-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-retry-review-20261109/ASSURANCE.md),
[exact retry approval](proposals/refund-executable-feasibility/proof-retry-review-20261109/APPROVAL.md).
Concurrency group forge-m1-macos-environment-preflight,cancel-in-progress:false;
macos-15,15min,permissions{},no environment gate or dependent jobs. Current empty
queues do not establish historical absence of contention.404 BlobNotFound is
not a cancellation explanation. No settings change or proof modification.
Prepared one rerun of job129312292711 at existing commitf1e4a080,expected attempt2,
with unchanged image guard,inputs and controls. No dispatch or further retry grant.

'''
tracker='''## One frozen proof retry prepared; approval required — U339

[Scheduling inspection](proposals/refund-executable-feasibility/proof-retry-review-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-retry-review-20261109/ASSURANCE.md),
[one-call retry request](proposals/refund-executable-feasibility/proof-retry-review-20261109/APPROVAL.md).
Fresh metadata retains cancelled job,no runner,no steps. Current queues and
pending approvals empty. Exact cancellation cause and account/workflow settings
remain unavailable. Workflow/candidate binding and retry preparation exit0.
No proof edits,evidence re-audit or execution. The candidate remains ready for
the unchanged job,subject to allocation and pinned-image guard. One specific-job
rerun is prepared and unauthorized. The404 log response is not causal evidence.
M1 proof remains unestablished,not disproved. M1 open; Stage12 unauthorized;
end_to_end=false. Native correspondence,composition and replay remain separate.

'''
entry='''
## U339 — Scheduling metadata inspected; unchanged single-job retry awaits approval

- References:U335–U338. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner requests scheduling inspection and a bounded retry
  proposal,with separate authorization before dispatch. No execution authorized.
- Fresh run/jobs metadata confirms run42661020831 failure,attempt1; sole job
  129312292711 cancelled,runner_id0,runner_name empty,steps[],labelmacos-15.
  No HOL process,statement,closure or mathematical failure exists for this job.
- Workflow at exact commitf1e4a080 remains SHA256
  1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
  Concurrency groupforge-m1-macos-environment-preflight,cancel-in-progress:false.
  One job,no needs/dependents,no environment approval binding,permissions{},
  15-minute cap. Public mack-dot/forge condition; repo public,not archived/disabled.
- Current repository-wide queued and in-progress lists empty; run pending-
  deployments empty. This does not prove historical absence of concurrency
  contention or rule out provider/account restrictions. No such cause asserted.
- Workflow settings endpoint returns connector400; cancellation annotation
  endpoint's prior400 not retried. Public run-page fallback cache miss. Exact
  cancellation cause,workflow enabled state and account Actions policy unknown.
  The prior404 BlobNotFound only records an unavailable log blob,not its cause.
  No log retry,settings change,alternate runner or hosted diagnostic occurred.
- inspect_retry.py exits0. Same workflow and candidate bytes checked; candidate
  SHA7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.
  No proof development or repeated1493-member integrity audit. U335/U336 evidence
  reused. Previous three integrity controls remain in-process rejections without
  separate exits. New proof/control exits remain NOT RUN.
- Prepared exactly one rerun_workflow_job call for mack-dot/forge job129312292711,
  expected attempt2 at original commitf1e4a080. Official GitHub documentation
  states reruns retain original SHA/ref and initial actor's privileges. No job
  dependents here. No publication,workflow/input change,debug logging or further
  automatic retry. Caller Actions write permission required; no permission change.
- Existing15-minute job,ARM64/image20261104.0514.1 guard,CPU120s/wall150s/
  maxheap1536MiB/4MiB-file child limits and conditional five cases unchanged.
  Allocation remains uncertain. Recheck status/attempt and conflicts before the
  one authorized call. On refused or ambiguous trigger,preserve and inspect
  read-only; no second request or alternate execution route.
- Evidence:proposals/refund-executable-feasibility/proof-retry-review-20261109/
  REPORT.md,ASSURANCE.md,APPROVAL.md,records and MANIFEST.json. Root tracking
  updated; old uncertainty prefix preserved. Prior proof/evidence files unmodified.
- Impact:correctness assessment unchanged. Proof unestablished,not disproved.
  Next check:owner's separate approval of exact retry,then one request and full
  result readback. Native memory/frame,composition and full-chain replay remain
  separate. No Stage12,signing,deployment or local Git repair/commit.
'''
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
    b=original[n].decode();i=b.index('## ');(root/n).write_text(b[:i]+s+b[i:])
with (root/'unsure.md').open('ab') as f:f.write(entry.encode())
assert (root/'unsure.md').read_bytes()==original['unsure.md']+entry.encode()
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
    assert (root/n).read_text().replace(s,'',1)==original[n].decode()
write(out/'tracking-after.json',{n:{'before':before[n],'after_sha256':sha((root/n).read_bytes())} for n in before})
write(out/'command-results.json',{'argv':['python3','-B',str(out/'inspect_retry.py')],'actual_exit':0,'retry_dispatched':False,'HOL_executed':False,'end_to_end':False})
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file() and p!=packet/'MANIFEST.json'}
write(packet/'MANIFEST.json',{'files':files,'authorization':'NOT_GRANTED','retry_dispatched':False,'HOL_executed':False,'end_to_end':False})
for n,h in files.items():assert sha((packet/n).read_bytes())==h,n
print(json.dumps({'packet_members':len(files),'journal_prefix_preserved':True,'retry_dispatched':False,'HOL_executed':False,'end_to_end':False}))
