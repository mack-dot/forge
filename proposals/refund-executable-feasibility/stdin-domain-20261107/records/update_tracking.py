from pathlib import Path
import hashlib,json,re

ROOT=Path('/Users/mackianni/forge')
WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
link='proposals/refund-executable-feasibility/stdin-domain-20261107'
road=f'''## Software boundary: stdin model domain proved — U327

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner limits the goal to software correctness under explicit ISA,OS and
HOL trust assumptions. No silicon proof is required. No hosted run was added.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Initial runner preflight / first model proof |1/1|Missing physical signature path,then missing constructor fact; preserved |
| Residual diagnostics1–4 |1/1/1/0|Exact residual recovered; no sandbox denial |
| Corrected model / totality extension / repeat / fresh import |0/0/0/0|Four final theorems; four identical exports |
| Wrong status / missing stdin guard |1/1|Intended exact-statement refusals |
| Native errno wrapper; two native children |0;0/0|libc read returns-1/EAGAIN35 versus0/errno0; both executable streams empty |
| Artifact/dependency readback; source pin/diff checks |0;0/0/0|148 theory nodes,876 closure files,2665 inputs;50 protected paths plus mission unchanged |
| Hosted run / ARM8 frame proof / independent21-snapshot replay |NOT RUN|No new external authority; full chain remains open |

[Proof and evidence]({link}/REPORT.md), [assurance matrix]({link}/ASSURANCE.md).
`stdin_ffi_read_total` proves that wfFS,STD_streams and valid stdin buffer guards
force an existing model result with status0. `stdin_ffi_read_status_zero` covers
every returned result. The native C source uses status1 on read errors. The
smallest gap is now the admitted physical stdin relation for such error events.
No no-error assumption,descriptor restriction,event weakening or semantic edit
was introduced. OS exit0 remains distinct from logical Success and FFI events.
[Next precise paired-event check]({link}/NEXT-STEP.md). U310/U315 remain unchanged.

'''
tracker=f'''## Checked stdin model limit under the software boundary — U327

[Proof and actual results]({link}/REPORT.md); [assurance matrix]({link}/ASSURANCE.md).
Four new HOL theorems prove the well-formed stdin lookup facts,read totality and
status0 result under the existing guards. Proof,repeat and fresh import exit0;
two statement mutations exit1. Closure148 nodes,876 files,four existing Boolean
foundations; final theory data SHA3192e34a57ac581727a3ce8c56770e7354242577d35bc4229903fe28020e671d.
Native libc control distinguishes EAGAIN35 from EOF,while the exact executable
exits0 with empty streams in both cases. No child syscall trace or universal
frame proof follows. The native hash remainsb8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.

Smallest unresolved obligation: relate admitted native read-error events to
wfFS/STD_streams and the complete pinned FFI trace. The model forces status0;
the C error path writes1. No stronger no-error assumption or restricted input
domain is approved or inserted. Hardware implementation,documented OS behavior
and HOL/kernel are explicit trust assumptions; silicon proof is outside scope.
Runtime memory,installation/resources,link/loader correspondence and independent
21-snapshot replay remain open. No hosted run,Stage12,signing or protected change.
M1 PARTIAL; end_to_end=false. [Next check]({link}/NEXT-STEP.md).

'''
entry='''
## U327 — Well-formed stdin model forces successful status; native error domain remains open

- References:U262,U286,U310,U315,U316,U320,U326. Parent8a09927. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false. Owner clarifies software-only
  correctness: trust ISA implementation,documented OS behavior,HOL logic/kernel;
  do not verify silicon. No broader software premise is accepted by that trust.
- A new minimal HOL composition reuses U315 and pinned fsFFIProps. It proves
  wf_read_inputs,stdin_read_inputs,stdin_ffi_read_status_zero,stdin_ffi_read_total
  in forge_refundStdinDomainTheory. Under wfFS,STD_streams,length conf8,decoded
  fd0 and buffer capacity,ffi_read has a result and every result has first byte0.
  Totality is explicit; the status claim is not merely conditional on existence.
- First runner preflight1 uses the wrong physical location of the generated
  signature; HOL not launched. First theorem attempt1 stops at the descriptor
  membership subgoal. Three residual inspections fail1:interactive alias g
  absent,explicit Context.t missing,then the same local subgoal unresolved.
  Fourth inspection0 prints the precise assumptions. Existing option distinctness
  and pair injectivity facts close the unchanged claim. Corrected model0;
  totality extension0;repeat0;fresh import0. All failure files remain.
- Final source SHA6791849e3c7f09dea6b09c7bb1f3b9d2bcb0458d1e1ca9352ae6094b7a64507f;
  final theory data SHA3192e34a57ac581727a3ce8c56770e7354242577d35bc4229903fe28020e671d.
  Four exports match across proof/repeat. Four exact imported statements have
  zero hypotheses,zero tagged axioms,only DISK_THM tags. Closure148 theory nodes,
  876 parent files,existing SELECT_AX/INFINITY_AX/ETA_AX/BOOL_CASES_AX only.
  This is local cached-parent assurance,not an independent source replay.
- Wrong-status and missing-fd0-guard controls exit1 at the exact statement check.
  They test claim binding; they are not attempted proofs of false statements.
  Readback0 checks2665 current inputs,50 protected paths and frozen mission.
  Tool/source pin and source-diff checks0/0/0 retain the pinned HOL/CakeML commits.
- The pinned C ffiread sets byte0 to1 after a negative read. Pinned TextIO
  read/read_into raises InvalidFD for that byte. Apple read(2) documents EAGAIN
  and EINTR,so documented OS behavior alone does not imply a no-error transport.
  The archived page is not an exhaustive specification of either execution OS.
- New local libc probe on an empty nonblocking pipe:writer open gives read-1,
  errno35/EAGAIN;writer closed gives read0,errno0.16-byte sentinel unchanged in
  both finite observations. The exact native refund executable then runs on
  each corresponding descriptor; both actual exits0,stdout/stderr empty. Wrapper0.
  The probe precedes the child; it does not trace the child's syscall or prove
  native exception identity,full memory frame,or universal OS behavior.
  Native SHA remainsb8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
  Observer reports local macOS27.0.1 arm64; U326 hosted macOS15.8.2 is distinct.
- Impact: a direct status/event-preserving relation cannot map an admitted
  status1 read into this well-formed standard-stdin model domain. Whether an
  approved physical-state relation admits that case remains unestablished.
  This is not a counterexample to the refund contract or impossibility of every
  assurance route. Do not add no-error assumptions,exclude inputs,or weaken events.
- Next check: one-byte request,fd0,valid buffer and wfFS/STD_streams against
  the physical empty nonblocking pipe case. Inspect the exact approved transport
  domain/refinement premise. Identify an existing justified exclusion or an
  established semantic route covering the error. Otherwise prepare an explicit
  change proposal; do not alter the contract or trusted model without authority.
  A STRB frame theorem alone does not repair this domain mismatch.
- No new hosted execution,SAT retry,ARM8 loader retry,expensive rebuild,signing,
  deployment,swarm or independent21-snapshot replay. Memory/install/resource,
  loader/linking,stdout,complete physical I/O and independent assurance remain
  open. Logical Success,FFI events,native exit0 and OS behavior stay distinct.
- Evidence:proposals/refund-executable-feasibility/stdin-domain-20261107/REPORT.md,
  ASSURANCE.md,NEXT-STEP.md,records and MANIFEST.json. Source lookup/glob/path
  failures and web403 are also recorded. ROADMAP/tracker updated; this journal
  append preserves both distinct histories. No protected change or new axiom.
'''
records=[]
for base in [ROOT,WT]:
    journal=base/'unsure.md'; old=journal.read_bytes()
    assert not re.search(rb'^## U327\b',old,re.M)
    assert re.search(rb'^## U326\b',old,re.M)
    journal.write_bytes(old+entry.encode())
    assert journal.read_bytes()[:len(old)]==old
    record={'base':str(base),'journal_prefix_bytes':len(old),'journal_prefix_sha256':sha(old),
            'journal_after_sha256':sha(journal.read_bytes()),'entry_sha256':sha(entry.encode())}
    for name,addition in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        path=base/name; before=path.read_text()
        pos=before.index('\n## ')
        path.write_text(before[:pos+1]+addition+before[pos+1:])
        record[name]={'before_sha256':sha(before.encode()),'after_sha256':sha(path.read_bytes())}
    records.append(record)
(OUT/'tracking.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
