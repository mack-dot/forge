from pathlib import Path
import hashlib, json

root=Path('/Users/mackianni/forge')
p=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
before=json.loads((p/'tracking-before.json').read_text())
original={n:(root/n).read_bytes() for n in before}
for n,b in original.items():assert len(b)==before[n]['bytes'] and sha(b)==before[n]['sha256']
roadmap='''## Frozen hosted proof proposal reviewed; execution not authorized — U337

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Owner recommends a separate proof-run decision and explicitly grants no execution.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 -I -B proposals/refund-executable-feasibility/proof-approval-review-20261109/review.py` |0|Exact workflow,driver,1493-entry manifests,candidate/import/control hashes and prior evidence match |
| `/bin/bash --noprofile --norc -n proposals/refund-executable-feasibility/hosted-integrity-run-20261109/records/proposed-proof-shell.sh` |0|Syntax only |
| Hosted proof / repeat / import / two proof controls |NOT RUN|Expected exits0/0/0/1/1 are not observed exits |
| Native correspondence / full-chain replay |NOT RUN|Later obligations,not authorized here |

[Exact review](proposals/refund-executable-feasibility/proof-approval-review-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/proof-approval-review-20261109/ASSURANCE.md).
Frozen workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
One15-minute macOS job,permissions{},at most five serial HOL children; each
CPU120s,wall150s,maxheap1536MiB,4MiB/file. Image availability/resource adequacy
remain untested; mismatch fails closed. No blocking static mismatch found.
Three prior hosted integrity controls remain in-process ValueError rejections,
with no separate OS exits. U335/U336 transfer result retained. No hosted action,
protected/input edit,publication,signing or deployment. Next:separate explicit
approval of the unchanged proposal; branch and trigger recheck before publication.

'''
tracker='''## Frozen proof approval scope reviewed; no execution authority — U337

[Review and exact scope](proposals/refund-executable-feasibility/proof-approval-review-20261109/REPORT.md),
[assurance update](proposals/refund-executable-feasibility/proof-approval-review-20261109/ASSURANCE.md).
Static identity/manifest/source review0 and shell syntax0. No HOL or hosted run.
Recommendation only:separate approval of the unchanged one-job proof proposal.
The three integrity controls retain in-process rejections without separate exits.
The two proposed HOL controls remain unrun; expected exits are not actual results.
After validated theorem evidence,native memory/frame and whole-program composition
remain necessary,then independent full-chain replay. No authority is inferred for
those steps. M1 open; Stage12 unauthorized; end_to_end=false.

'''
entry='''
## U337 — Frozen proof-run scope inspected; owner withholds execution authority

- References:U329,U335,U336. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner recommends a separate approval after manifest review,
  explicitly authorizes no additional execution,and requests the control distinction.
- Read exact approval,complete workflow/driver,two frozen manifests and candidate/
  import/two control sources. review.py exits0; shell syntax child exits0. No
  proposed driver import,proof,hosted action,publication,signing or native run.
- Workflow16385 bytes,SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1;
  driver2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8.
  Both exact manifest hashes and1493 distinct entries match. Candidate/import
  quotation289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a
  and all four reviewed source identities match. No premise or event changed.
- One15-minute macos-15 job,required ARM64/image20261104.0514.1,permissions{}.
  Up to five serial HOL children:proof,repeat,import,wrong-exception,omitted-event.
  Each CPU120s,wall150s,maxheap1536MiB,4MiB/file,zero core dumps. Expected
  exits0/0/0/1/1 are proposal requirements only; actual exits remain NOT RUN.
- Three previous hosted integrity mutations remain expected in-process ValueError
  rejections with no separate process exit codes. Only the surrounding integrity
  checker has observed exit0. Assurance matrix records this distinction explicitly.
- No blocking static mismatch found. Recommendation applies only to a separate
  approval decision. Image availability and resource adequacy remain unknown;
  fail-closed guards remain. Per-child limits do not establish aggregate capacity
  or completion within the900s job budget. Cached ancestry/provider trust remain.
- Previous U335/U336 packet hashes,50 protected paths and mission match. No old
  packet or uncertainty entry changed; no local Git repair or commit claimed.
  Evidence:proposals/refund-executable-feasibility/proof-approval-review-20261109/
  REPORT.md,ASSURANCE.md,REVIEW.json,command records and MANIFEST.json.
- Next check:separate explicit authorization for the exact frozen proposal;
  recheck branch head and inherited triggers before any publication. If proof
  and evidence checks pass,native memory/frame correspondence and whole-program
  composition remain,then independent full-chain replay. No automatic authority
  or M1 completion follows from a passing generic TextIO.read theorem.
'''
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
 b=original[n].decode();i=b.index('## ');(root/n).write_text(b[:i]+s+b[i:])
with (root/'unsure.md').open('ab') as f:f.write(entry.encode())
assert (root/'unsure.md').read_bytes()==original['unsure.md']+entry.encode()
for n,s in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
 assert (root/n).read_text().replace(s,'',1)==original[n].decode()
(p/'commands.json').write_text(json.dumps({'review_command':['python3','-I','-B',str(p/'review.py')],'actual_exit':0,'syntax_child_record':'shell-command.json','hosted_proof':'NOT_RUN','end_to_end':False},indent=2)+'\n')
(p/'tracking-after.json').write_text(json.dumps({n:{'before':before[n],'after_sha256':sha((root/n).read_bytes())} for n in before},indent=2)+'\n')
files={str(f.relative_to(p)):sha(f.read_bytes()) for f in sorted(p.rglob('*')) if f.is_file() and f.name!='MANIFEST.json'}
(p/'MANIFEST.json').write_text(json.dumps({'files':files,'approval_granted':False,'HOL_executed':False,'end_to_end':False},indent=2)+'\n')
for n,digest in files.items():assert sha((p/n).read_bytes())==digest
print(json.dumps({'packet_files':len(files),'journal_prefix_preserved':True,'approval_granted':False,'end_to_end':False}))
