from pathlib import Path
import hashlib,json,re

ROOT=Path('/Users/mackianni/forge'); WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
link='proposals/refund-executable-feasibility/read-event-gap-20261107'
road=f'''## Read-error replay obstruction checked; generic proof loader stopped — U328

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
U327 made progress. This turn checks the complete-event consequence and tests
the published generic FFI route without changing any existing theorem or model.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Four-theorem proof / repeat / fresh import |0/0/0|First attempt passes; four identical exports |
| Wrong replay result / omitted error event |1/1|Intended exact-statement refusals |
| Artifact/closure readback |0|217 nodes,1287 closure files,2668 inputs;50 protected paths plus mission match |
| CakeML pin / eight-source diff |0/0|Inspected sources match pinned revision |
| Generic TextIO error candidate |1|load cfLib fails in helperLib/numLib.DECIDE; theorem not reached |
| Generic failure readback |0|No theory export; complete failure retained |
| New native / hosted / independent21-snapshot replay |NOT RUN|No additional external authority or completed chain |

[Proof and limits]({link}/REPORT.md); [assurance matrix]({link}/ASSURANCE.md).
`basis_read_ignores_ext` closes the extension-override route. The new
`stdin_error_complete_trace_rejected` preserves arbitrary prefix/suffix and
complete byte pairs:under the guarded stdin premises,a status1 read event makes
extract_fs return NONE. U310 requires SOME. No event is dropped or premise
weakened. This is a model obstruction,not a demonstrated native counterexample.
The separate generic-FFI candidate retains an explicit transition,buffer,state
and full event append. Its load failed before its theorem. No errno was captured;
the U320 mkstemp cause is not established for this failure. No loader retry.
[Next]({link}/NEXT-STEP.md):prepare exact hosted inputs for unchanged cfLib load
and candidate,then obtain one-run/transfer approval before external execution.

'''
tracker=f'''## Complete read-error event replay obstruction — U328

[Checked results]({link}/REPORT.md); [current assurance matrix]({link}/ASSURANCE.md).
Four new HOL theorems pass proof/repeat/import0/0/0. The basis read ignores ext;
guarded status1 stdin events force complete extract_fs replay to NONE,including
arbitrary valid prefix and arbitrary suffix. U310's SOME replay requirement
therefore cannot be extended to these events by changing ext or deleting bytes.
All original statements,premises and required events remain unchanged.

Source SHA902821b55ffa3991c677640aeba8eec4d901e25cceb3c12a4680b45c24846d19;
theory data SHA60261ea96a993d62c971769d642c9ab1b9dbc558ccd31f41d9e4e3ef00202357.
Four identical exports;217 theory nodes,1287 closure files,four existing Boolean
foundations;2668 inputs and50 protected paths plus mission match. Statement
mutations exit1/1. These are local cached-parent checks,not independent replay.

The frozen protocol and inspected proposals supply no approved no-error stdin
exclusion. A separate generic-FFI TextIO error candidate reaches load cfLib,
then exits1 in helperLib/numLib.DECIDE before the theorem. No errno or proof
residual is captured; no link to the historical EPERM is proved. The route is
stopped. [Next execution requirements]({link}/NEXT-STEP.md):prepare exact inputs
and obtain additional hosted-run/transfer approval. None is currently granted.
No new native run,signing,protected change,Stage12 or independent replay occurred.
M1 remains PARTIAL; end_to_end=false. Hardware verification remains outside scope.

'''
entry='''
## U328 — Complete stdin error-event replay obstruction; generic FFI loader failure preserved

- References:U286,U310,U315,U316,U320,U326,U327. Parent2874d5c. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false. Previous goal turn made progress.
  This turn follows the approved software boundary and preserves all prior claims.
- Locked RefundSpec/protocol/spec.lock identities match. The source contract
  has no POSIX descriptor-availability premise. The inspected protocol does not
  supply a no-error stdin assumption; modeled stdio/runtime correspondence
  documents remain explicitly unadopted. Absence is not approval to exclude errors.
- Published TextIO read_spec only permits InvalidFD when content is unavailable
  or mode is not ReadMode. IOFS retains wfFS; STDIO retains STD_streams.
  basis_ffi_oracle handles read before consulting ext. Eight inspected CakeML
  sources match the pinned cd9155694c16831373ab695a670794f23282ed62 revision.
- New forge_refundReadEventGapTheory exports basis_read_ignores_ext,
  basis_stdin_read_total,stdin_error_event_rejected and
  stdin_error_complete_trace_rejected. The last result preserves an arbitrary
  replayed prefix,complete event byte pairs and arbitrary suffix. If the prefix
  reaches wfFS/STD_streams and the fd0/configuration/capacity guards hold,a read
  event with first returned byte1 forces extract_fs of the entire trace to NONE.
  U310 requires SOME. No ext value repairs the read call under these premises.
- This is a checked obstruction to that direct model/replay route,not a proved
  native counterexample or impossibility of every assurance route. A preceding
  ext call could alter state; the new theorem explicitly requires guards at
  the read state. Their physical applicability remains unestablished.
- Proof/repeat/fresh import exit0/0/0 on first proof attempt. Four generated
  exports match. Four exact imported statements have no hypotheses or tagged
  axioms; only DISK_THM tags. Closure217 theory nodes,1287 parent files; four
  existing Boolean foundation axioms only. Source SHA
  902821b55ffa3991c677640aeba8eec4d901e25cceb3c12a4680b45c24846d19;
  data SHA60261ea96a993d62c971769d642c9ab1b9dbc558ccd31f41d9e4e3ef00202357.
- Wrong-replay-result and omitted-error-event controls exit1/1 at the exact
  statement check. These test claim binding,not native attacks. Readback0 checks
  2668 current inputs,50 protected paths and frozen mission. Source pin/diff0/0.
  Checks use same-host cached parents; independent source replay remains unrun.
- A separate candidate uses published app_ffi/FFI_part to state an explicit
  status1 transition and the unchanged TextIO read function's InvalidFD result.
  It retains the full buffer,oracle state,names and exact event append. It defines
  no new oracle or semantics. Its transition premise is not accepted as trusted;
  physical read/frame correspondence would still be required.
- That candidate exits1 at its first load cfLib,through cfDivLib,cfTacticsLib,
  helperLib and numLib.DECIDE. No theorem is reached and no theory export exists.
  Statement and tactics remain unchecked. Full stderr/source/command are kept;
  failure readback0 confirms them. No errno or syscall location is captured.
  Cause equivalence to U320's mkstemp EPERM is unproved. No same-context retry,
  alternate solver,modified library,permission change or workaround occurred.
  Candidate SHA7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.
- Next smallest execution:prepare exact hosted payload/dependency closure for
  unchanged cfLib load and candidate,using supported U326 saved-state loading
  and private writable paths; obtain one additional run/input-transfer approval
  before external action. No such authority is currently granted. A successful
  load would not prove the candidate. Inspect actual residuals only after it runs.
- No new native execution,hosted job,release signing,Stage12,deployment,swarm,
  proof-machinery/specification change or independent21-snapshot replay.
  Runtime memory,loader/linker,full I/O correspondence and independent assurance
  remain open. Logical Success,full FFI events,native exit and OS effects remain
  distinct. ISA/OS/HOL trust does not discharge these software obligations.
- Evidence:proposals/refund-executable-feasibility/read-event-gap-20261107/REPORT.md,
  ASSURANCE.md,NEXT-STEP.md,COMMANDS.md,records and MANIFEST.json. Incidental
  missing-path/search failures are also preserved. ROADMAP/tracker updated;
  this append retains both distinct uncertainty histories unchanged.
'''
records=[]
for base in [ROOT,WT]:
    path=base/'unsure.md';before=path.read_bytes()
    assert re.search(rb'^## U327\b',before,re.M) and not re.search(rb'^## U328\b',before,re.M)
    path.write_bytes(before+entry.encode())
    assert path.read_bytes()[:len(before)]==before
    row={'base':str(base),'journal_prefix_bytes':len(before),'journal_prefix_sha256':sha(before),
         'journal_after_sha256':sha(path.read_bytes()),'entry_sha256':sha(entry.encode())}
    for name,addition in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        p=base/name;old=p.read_text();pos=old.index('\n## ')
        p.write_text(old[:pos+1]+addition+old[pos+1:])
        row[name]={'before_sha256':sha(old.encode()),'after_sha256':sha(p.read_bytes())}
    records.append(row)
(OUT/'tracking.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
