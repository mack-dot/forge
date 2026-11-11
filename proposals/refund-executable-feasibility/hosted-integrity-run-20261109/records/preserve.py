from pathlib import Path
import hashlib,json,shutil
root=Path('/Users/mackianni/forge');review=Path('/private/tmp/forge-native-audit-review-20261104')
out=Path(__file__).resolve().parent
rel=Path('proposals/refund-executable-feasibility/hosted-integrity-run-20261109');packet=root/rel
sha=lambda b:hashlib.sha256(b).hexdigest()
write_json=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
assert not packet.exists() and not (review/rel).exists()
result=json.loads((out/'INDEPENDENT-READBACK.json').read_text())
assert result['status']=='TRANSFER_INTEGRITY_ESTABLISHED' and result['actual_checker_exit']==0
baseline_path=root/'proposals/refund-executable-feasibility/native-audit-20261104/records/baseline.json'
baseline=json.loads(baseline_path.read_text())
for name,digest in baseline['protected'].items():assert sha((root/name).read_bytes())==digest,name
assert sha((root/'FORGE_MISSION.md').read_bytes())==baseline['mission_sha256']
previous=[]
for base in [root,review]:
 for name in ['integrity-preflight-20261108','integrity-preflight-20261109']:
  p=base/'proposals/refund-executable-feasibility'/name
  m=json.loads((p/'MANIFEST.json').read_text())
  for n,h in m['files'].items():assert sha((p/n).read_bytes())==h,str(p/n)
  previous.append({'path':str(p),'members':len(m['files']),'manifest_sha256':sha((p/'MANIFEST.json').read_bytes())})
write_json(out/'PRESERVATION.json',{'actual_exit':0,'root_protected_paths':50,'mission_matches':True,
 'baseline_sha256':sha(baseline_path.read_bytes()),'prior_packets':previous,
 'local_git_commit':'NOT_RUN: U333 metadata failure not repaired or retried',
 'remote_commit':'fca212c45ccce9f27ffdf2d51ccf9ee96bce7162','end_to_end':False})
packet.mkdir(parents=True)
(packet/'REPORT.md').write_text('''# U335: TRANSFER_INTEGRITY_ESTABLISHED

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
One authorized Ubuntu integrity job completed. No HOL,native refund process,
release signing,deployment,protected change or21-snapshot replay ran.

## Exact execution and evidence

- [Run42624212334](https://github.com/mack-dot/forge/actions/runs/42624212334),
  attempt1,one job129183679727,completed/success. Exactly one run at this head.
- Workflow commitfca212c45ccce9f27ffdf2d51ccf9ee96bce7162,only added path
  .github/workflows/m1-input-integrity.yml. Parent8ad9de1e538edd48a2084796510e784913eaef8b.
- Workflow13735 bytes,SHA256
  b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9.
  Driver SHA256c3bd8078dda3ef400a16cb09bed0397b765db15d9e791f1518b420816435fe99.
- Raw commit identity was reconstructed and checked before the trigger branch
  was created. Remote workflow bytes match the local candidate exactly.
- Complete decoded job log455127 UTF-8 bytes,SHA256
  b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
  Connector-decoded text is preserved,including its BOM; raw HTTP encoding is
  provider/tool trust. Complete log records,not a lone success marker,were checked.

| Command/check | Actual exit/result |
| --- | --- |
| Final integrity preparation / shell syntax |0 / 0 |
| Local candidate check including requested mutations |0;1493 local fixture files |
| Remote workflow/commit readback before trigger |0 |
| Hosted Python integrity process |0; shell records FORGE_INTEGRITY_EXIT=0 |
| Hosted changed-commit/manifest/part controls |3 expected ValueError rejections; no separate process exits |
| Separate evidence reader |0; all expected records match |
| Future proof workflow syntax/preparation |0; no proof invocation |
| Protected/mission/prior-packet preservation |0 |

The job downloaded26196042 payload bytes plus36303 commit/tree metadata bytes.
It checked ten package files,two archive hashes,all1475 addon files and18 reused
base files,including sizes,modes and SHA256 values. Six tree identities bind the
files to the exact source commits. The separate local evidence reader imports
no producer checker and compares every emitted member digest with the frozen
manifests. It also checks all file identities,commits,download URLs/counts/bytes,
mutation reasons,the unchanged quotation,complete result,exit and provider status.

| Input | Commit | Manifest SHA256 |
| --- | --- | --- |
|Addon|21c4bdf958627e6a24e8dee9a45d90568b3e3c20|6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105|
|Base|ac05eaf972b8c98784466ae063fca505aaaf25f4|6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7|

Candidate SHA2567e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.
Exact theorem quotation SHA256
289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a.
No theorem statement,premise,event requirement or pinned proof input changed.

## Authority and resource scope

The owner explicitly authorized one Ubuntu integrity job and requested mutation
controls and actual resource records. U333's unsafe redirect behavior was not
used. The final checker retains U334's reviewed refusal and adds only the three
requested in-process mutations and exit/resource records. This is a new13735-byte
workflow,not a claim to have executed the old11609-byte artifact. Both prior
packets remain unchanged. No additional source payload or external host was added.

One job,5-minute limit,permissions{},no secrets referenced,no privileged command,
install,checkout action or transferred-code execution. All13 inherited workflow
identities and trigger definitions were checked; none triggers on this branch.
The run log reports the provider's implicit Metadata:read token capability.
The script neither reads nor transmits a token. The only new public file is the
reviewed integrity workflow. No automatic follow-on or rerun is included.

Actual host:Linux x86_64,Ubuntu image20261101.360.1,Python3.12.3,UID1001.
Python SHA256e50d468e8b0adfb05733f5b87b3cff34829c4a8c1aea50c865aa8bdfe4bb150f.
The byte checker needs no ARM64 execution; it did not execute the macOS payload.
Actual checker wall9.004512771 seconds; user CPU1.68537 seconds,system CPU0.050339
seconds; peak RSS48684 KiB. Limits remained180 wall seconds,90 CPU seconds,
1GiB address space,32MiB/file and zero core dumps. GitHub reports run duration
16000ms and0 billable Ubuntu milliseconds for this one job.

## Preserved failures and limits

An initial read-only lookup used the wrong branch name and returned404. The
correct branch read succeeded. The generic connector rejected a later full-job
metadata endpoint with400; the supported job-summary API,complete log,run status
and timing endpoint supplied the required records. Both failures are preserved.
No failed hosted run or hidden retry occurred. Local Git metadata remains
unrepaired; no new local preservation commit is claimed. The remote workflow
commit identity is separately checked and does not depend on that metadata.

This establishes tested transfer integrity under GitHub control-plane/runner,
OS,Python/hash/TLS and connector trust. It is separate hosted execution,not
independent administrative control,proof of isolation from the provider,or a
formal theorem. Logical Success,modeled FFI events,native process exit and physical
OS effects remain distinct. The checker exit0 is none of those refund claims.

## Next separately authorized action

[PROOF-RUN-APPROVAL.md](PROOF-RUN-APPROVAL.md) prepares one bounded macOS job for
the unchanged TextIO.read error candidate,conditional repeat,fresh import and
two negative controls. Input transfer is complete; no new payload upload is
proposed. The proposal binds the verified addon commit and applies the same
redirect refusal to transport only. All other driver code is byte-identical.
The frozen original,the bound-only version and exact orchestration diff remain.
No proof workflow was published or executed. Native memory/frame,lifetimes,
whole-program composition and independent21-snapshot replay remain separate.
''')
(packet/'ASSURANCE.md').write_text('''# U335 assurance matrix

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and trust limit |
| --- | --- | --- |
| Exact published source/package bytes | TESTED |TRANSFER_INTEGRITY_ESTABLISHED; run42624212334; checker exit0;26196042 payload bytes. |
| All1475+18 pinned files and original quotation | TESTED |1493 member records match frozen manifests; unchanged quotation289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a. |
| Both source commit/tree/blob bindings | TESTED |21c4bdf/ac05eaf; raw commit hashes,six trees,ten blobs and archive/member hashes checked. Unsigned identity,not a signing claim. |
| Three integrity mutation controls | TESTED |Expected ValueError reasons for changed commit,manifest and part; no separate child exit invented. |
| Exact checker workflow and observed exit | TESTED |Commitfca212c; SHA256b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9; full log and shell exit0. |
| Separate evidence readback | TESTED |readback.py exits0; no producer checker import; same agent,not independent administrative control. |
| Resource limits and observed use | TESTED |9.0045s checker wall,48684KiB peak RSS;16s provider duration; one job,0 billable Ubuntu ms reported. |
| GitHub runner/control plane,OS,Python/hash/TLS,connector | ASSUMED |Provider execution and decoded-log authenticity remain trust. This is not a kernel proof of the hashing program or host isolation. |
| Frozen TextIO.read theorem and dependency closure | NOT_ESTABLISHED |No HOL run. Candidate7e36c486 and full premises preserved. Separate bounded proposal prepared only. |
| Native memory/frame and whole-program correspondence | NOT_ESTABLISHED |No new native or semantic proof evidence. Full runtime/resource/initialization premises remain. |
| Independent21-snapshot replay | NOT_ESTABLISHED |Separate and unrun. |
| ARM64 ISA implementation,documented OS behavior,HOL/kernel | ASSUMED |Existing owner-approved software boundary; no silicon work or new axiom. |
| Full specification-to-native software correctness | NOT_ESTABLISHED |M1 remains open; end_to_end=false. Prior conditional source/compiler proofs retain their recorded scope. |

GO:transfer-integrity milestone. NO-GO:hosted HOL execution without separate
authorization. U333/U334 packets,failures and separate journal prefixes remain.
''')
(packet/'PROOF-RUN-APPROVAL.md').write_text('''# Separate proposal: one hosted TextIO.read proof job

NOT AUTHORIZED. The current owner instruction explicitly forbids the hosted
HOL proof. This file prepares a later decision; it grants no execution authority.
The approved Ubuntu integrity run is complete and consumed its one-job scope.

Proposed action:replace only .github/workflows/m1-macos-preflight.yml on
proposal/m1-macos-preflight-20261106 in public mack-dot/forge. Expected branch
head8ad9de1e538edd48a2084796510e784913eaef8b. Recheck before any future publication.
One branch update triggers one job. No rerun,merge or automatic follow-on.
No new proof input upload:reuse21c4bdf958627e6a24e8dee9a45d90568b3e3c20 and
ac05eaf972b8c98784466ae063fca505aaaf25f4,whose full bytes passed U335 readback.

Exact proposed workflow:[records/proposed-proof-workflow.yml](records/proposed-proof-workflow.yml),
16385 bytes,SHA2561af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
Driver SHA2562667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8.
Only two changes from the U329 template:bind the verified addon commit and
refuse redirects before following them. All other driver code is byte-identical.
The frozen template,bound-only version and exact diff are preserved. Neither
the candidate,its theorem premises,nor any pinned toolchain/parent bytes changed.
Python/YAML/shell syntax checks exit0; these are not proof checks.

Sole shell command:/usr/bin/python3 -I -B - with the embedded driver,through
bash --noprofile --norc -euo pipefail {0}. Token permissions:{}; no secret,
checkout action,install,sudo,security-setting change,signing or deployment.
Reads existing public immutable inputs; creates private0700 temporary paths.
Records complete streams,actual child exits,input hashes and theory artifacts.

One standard macos-15 ARM64 job,15-minute cap; image must equal20261104.0514.1.
Fail if unavailable or environment/identity checks fail. No image substitution
or assumption change is authorized. Each HOL child:CPU120s,wall150s,maxheap1536MiB,
output-file cap4MiB. At most five serial children:unchanged candidate,conditional
identical repeat,fresh import,wrong-exception control,omitted-event control.
Stop at first unexpected result. Preserve failures; never weaken the statement.

The driver checks architecture,OS,resources,mkstemp,read/write,process,memory
and denied-read controls. It uses the existing public loadHierarchy/path APIs.
The frozen MiniSat binding remains unchanged; the existing HOL fallback is
permitted as previously recorded. This cached-parent experiment does not prove
independent full-chain provenance. Provider isolation and OS behavior remain trust.

Purpose:check read_error_generic or expose its exact residual. Even a passing
theorem will not close native C/memory/frame/lifetime or refund_main composition.
No native refund run,21-snapshot replay,Stage12,release signing or deployment.
Logical Success,modeled FFI events and OS exit remain distinct. end_to_end=false.
''')
roadmap='''## Hosted transfer integrity established; HOL remains unauthorized — U335

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
TRANSFER_INTEGRITY_ESTABLISHED for the exact frozen published inputs.

| Executed action/check | Actual exit/result | Result |
| --- | --- | --- |
| Checker preparation / local candidate / pre-trigger readback |0 / 0 / 0|Reviewed same one-job scope; no proof inputs changed |
| Hosted integrity process |0|Run42624212334,job129183679727,attempt1; exactly one job |
| Hosted integrity mutations |3 expected rejections|In-process ValueError controls; no separate OS exit |
| Separate full evidence readback |0|1475+18 members,ten files,two commits and unchanged quotation |
| Next proof proposal syntax / preservation |0 / 0|Unpublished; no HOL execution |
| Initial wrong-branch / optional full-job metadata read |404 / 400 tool errors|Both preserved; supported evidence routes succeed |
| HOL / native refund /21-snapshot replay |NOT RUN|Separate authorization and obligations remain |

[Report](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/REPORT.md),
[assurance](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/ASSURANCE.md),
[separate proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md).
Downloaded26196042 payload bytes plus36303 metadata bytes. Workflow commitfca212c;
log SHAb22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
Checker9.0045s wall,48684KiB peak RSS; provider16s,0 billable Ubuntu ms reported.
The approved checker retains the redirect fix and adds requested mutations and
exit/resource records. U333/U334 preserved. This is tested transfer integrity,
not the TextIO.read theorem or native correctness. No new local Git commit.

'''
tracker='''## TRANSFER_INTEGRITY_ESTABLISHED; next proof requires approval — U335

[Actual run and readback](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/REPORT.md),
[assurance matrix](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/ASSURANCE.md).
One authorized Ubuntu job succeeds with observed process exit0. All1493 member
hashes,ten package files,two source commits and original quotation match. Three
requested mutations are rejected. Separate evidence reader0; no marker-only claim.
This closes the remote-byte blocker under the recorded provider/runtime trust.
It does not prove TextIO.read,native memory/frame,or whole-program correspondence.
The [separate proof proposal](proposals/refund-executable-feasibility/hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
is prepared and unrun. Hosted HOL remains expressly unauthorized. Independent
21-snapshot replay remains separate. M1 open; Stage12 unauthorized; end_to_end=false.
Prior failures and U333/U334 packets remain. No local Git repair or new commit.

'''
entry='''
## U335 — Authorized hosted readback establishes exact transfer integrity

- References:U329,U332–U334. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Owner explicitly authorized one5-minute Ubuntu integrity
  job,permissions{},no secrets/privilege/proof,and requested mutation controls.
- Used U334's redirect refusal plus requested in-process mutations and actual
  exit/resource records. Final13735-byte workflow SHA256
  b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9.
  Original U333/U334 artifacts remain. No pinned proof input or theorem changed.
- Final preparation/local fixture validation0/0. All13 inherited workflow
  identities/triggers match; none triggers on the new branch. Remote commit
  fca212c45ccce9f27ffdf2d51ccf9ee96bce7162 adds only the integrity workflow.
  Pre-trigger byte/commit readback0; source parent8ad9de1. No local Git needed.
- One run42624212334,attempt1,job129183679727 succeeds. Complete log records
  actual checker process exit0. All1475 addon and18 base files match,along
  with ten package files,two archives,six tree bindings and both source commits.
  Download26196042 payload bytes and36303 metadata bytes. Source commits remain
  21c4bdf958627e6a24e8dee9a45d90568b3e3c20 andac05eaf972b8c98784466ae063fca505aaaf25f4.
- Three hosted in-process controls reject changed commit/manifest/part with
  exact ValueError reasons. These are not three OS child exits. The checker
  process alone exits0. No transferred program,HOL or native refund was run.
- Complete decoded log455127 UTF-8 bytes,SHA256
  b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187.
  Separate evidence reader exits0 and compares all expected records against
  frozen manifests,without importing producer checker code. Same agent and
  provider trust remain; no independent administrative control claim.
- Candidate SHA7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6;
  original quotation SHA289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a.
  TRANSFER_INTEGRITY_ESTABLISHED is TESTED byte integrity,not a HOL theorem.
- Actual Linux x86_64,Ubuntu image20261101.360.1,Python3.12.3,UID1001.
  Checker wall9.004512771s,user CPU1.68537s,system CPU0.050339s,peak RSS48684KiB.
  Provider duration16000ms,one job,0 billable Ubuntu ms. Token log shows implicit
  Metadata:read; workflow permissions{} and no token/secret use remain.
- Read-only wrong-branch lookup404 and unsupported optional full-job metadata
  endpoint400 are preserved. Correct branch,job-summary,full logs and timing
  reads succeed. No hosted failure,retry,Git repair or extra job. Root50 protected
  hashes and mission match; both copies of U333/U334 packets remain unchanged.
- Next proof proposal is local only. It binds verified addon commit and applies
  redirect refusal to transport; all other U329 driver code byte-identical.
  Proposed workflow SHA1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1;
  syntax/preparation0. Exact original,bound-only version and diff retained.
  Current owner explicitly forbids HOL execution; separate approval is required.
- Evidence:proposals/refund-executable-feasibility/hosted-integrity-run-20261109/
  REPORT.md,ASSURANCE.md,PROOF-RUN-APPROVAL.md,records and MANIFEST.json.
  Tracker/ROADMAP updated; both journal prefixes preserved. No new local commit.
- Smallest remaining formal step:run the unchanged generic TextIO.read error
  candidate in the bounded separately authorized macOS context. Native memory/
  frame/lifetime,whole-program composition and21-snapshot replay remain separate.
  Logical Success,FFI events,native OS exit and physical effects stay distinct.
'''
tracking=[]
for base in [root,review]:
 before={name:(base/name).read_bytes() for name in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']}
 assert all(b'U335' not in b for b in before.values())
 with (base/'unsure.md').open('ab') as f:f.write(entry.encode())
 for name,text in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',tracker)]:
  data=before[name].decode();i=data.index('## ');(base/name).write_text(data[:i]+text+data[i:])
 row={'root':str(base),'files':{}}
 for name,b in before.items():
  after=(base/name).read_bytes()
  if name=='unsure.md':assert after.startswith(b)
  row['files'][name]={'before_bytes':len(b),'before_sha256':sha(b),'after_sha256':sha(after)}
 tracking.append(row)
write_json(out/'tracking.json',tracking)
shutil.copytree(out,packet/'records',ignore=shutil.ignore_patterns('local-candidate-check','__pycache__','*.pyc'))
files={str(p.relative_to(packet)):sha(p.read_bytes()) for p in sorted(packet.rglob('*')) if p.is_file()}
write_json(packet/'MANIFEST.json',{'files':files,'status':'TRANSFER_INTEGRITY_ESTABLISHED',
 'hosted_runs':1,'HOL_executed':False,'local_commit':'NOT_RUN','end_to_end':False})
shutil.copytree(packet,review/rel)
print(json.dumps({'actual_exit':0,'packet_members':len(files),'manifest_sha256':sha((packet/'MANIFEST.json').read_bytes()),
 'journal_prefixes_preserved':2,'protected_paths':50,'status':'TRANSFER_INTEGRITY_ESTABLISHED','end_to_end':False}))
