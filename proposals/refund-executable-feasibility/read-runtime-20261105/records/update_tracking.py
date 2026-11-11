from pathlib import Path
import hashlib,json,re
ROOT=Path('/Users/mackianni/forge')
WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def digest(b): return hashlib.sha256(b).hexdigest()
baseline=json.loads((OUT/'tracking-baseline.json').read_text())
uid=baseline['unique_entry']
for name,rec in baseline['files'].items():
    assert digest(Path(name).read_bytes())==rec['sha256'],name
assert uid=='U'+str(1+max(int(n) for base in [ROOT,WT] for n in re.findall(r'^## U(\d+)\b',(base/'unsure.md').read_text(),re.M)))
link='proposals/refund-executable-feasibility/read-runtime-20261105/REPORT.md'
entry=f'''
## {uid} — Published read/error frame checked; physical syscall relation remains open

- References:U262,U275,U276,U283,U286,U289,U290,U291,U294,U295,U296,U297,U301,
  U310,U313,U314. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
  Parent local commit dde26bed545bb1f5fc87efe0410ddcace239e531. This goal turn
  makes new proof/audit progress; it does not establish the full native chain.
- forge_refundReadBoundary proves read_ready,ffi_read_ready,ffi_read_ready_status
  and ffi_read_unavailable from unchanged published fsFFI definitions. Ready
  descriptor/inode/choice-head conditions force status0. Modeled read=NONE with
  length guards gives status1, unchanged remaining buffer and unchanged fs.
  No original specification, theorem, event/error/heap predicate or domain changed.
- Model bundles0001–0006 exit1/1/1/1/1/1; diagnostic0; bundle0007/repeat/import0/0/0.
  First two failures are parser collisions. Status proof failures expose an
  unreduced assumption, constructor substitution, then HD(cons); existing list
  equations close it on its fourth actual proof attempt. Error-frame proof passes
  on its second attempt with LUPDATE_def. No failing proof exceeds five attempts.
  All failed sources, logs, partial in-process claims and exact residuals remain.
- Fresh import checks all four complete statements, zero explicit hypotheses/new
  tagged axioms. Four exports repeat byte for byte. Closure147 nodes/870 parent
  files retains only SELECT_AX,INFINITY_AX,ETA_AX,BOOL_CASES_AX. All2659 U310
  parent bindings match. HOL logic/kernel,PolyML,host,loader and cached DISK_THM
  provenance remain trusted. This is not independent clean full-chain replay.
- Wrong-ready-status1 and changed-error-frame1 first pass all four positive
  audits, then refuse the exact altered statement. These are claim-binding
  controls, not physical counterexamples or new proof axioms.
- Native controls run twice: eight cases each; wrapper exits0/0. Valid regular
  input and ready nonblocking input produce exact64-byte output with exit0.
  Empty EOF,malformed input,closed stdin,write-only stdin and empty nonblocking
  pipe each produce empty stdout/stderr and exit0. A stdout pipe without readers
  terminates with signal status-13 (SIGPIPE); stdout is not captured in that case.
  Complete two-run observation records match. No internal errno/FFI byte is
  observed or inferred. Logical Success, modeled events and OS status stay distinct.
- Pinned LLDB static disassembly succeeds but its Python command fails: exit1,
  no scripting support. Command-only directory-input and known-valid launches
  both exit1 at no-such-process before a breakpoint. No native status or frame
  capture is established. Stop this launch path until an identified environment
  change. No debugger substitution, permission bypass or executable change.
- Smallest physical gap: connect one exact ffiread call's OS result, complete
  buffer, filesystem update, valid return state and full ffi_interfer_ok frame to
  the published model. IO_fs does not represent nonblocking flags,errno or signals.
  The C negative branch writes status1 but that alone proves no syscall buffer or
  offset frame. fsFFI itself notes its unchanged-offset error-model limitation.
  Published CakeML I/O work keeps C/OS implementation in the trusted base; no
  checked exact C-object/Darwin refinement is available in the inspected chain.
- Correct U310 report prose: is_arm8_machine_config fixes only target and
  pointer/length/saved-register mapping. Entry,memory,FFI and installer conditions
  reside under installed/good_init_state. U310's exact theorem and packet remain
  unchanged. The new assurance matrix preserves all eight premise groups plus
  successful-source,resource,linker,loader,interference and OS trust conditions.
- Artifact readback0 verifies2727 historical chain files,311 standard-checksum
  members,134 U310 members,100 U296 members and50 unchanged protected paths.
  Both existing signatures verify0/0; no signing or recompilation ran. Frozen
  mission unchanged. Native remains b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
- Replay preflight0 verifies21 original/snapshot pairs and all three pinned source
  revisions with clean tracked diffs. Independent environment and bootstrap/source
  provenance are NOT_ESTABLISHED; replay gate NO_GO, execution NOT RUN. U301's
  Docker socket denial and old Holmake refusal have no demonstrated environment
  change and were not retried or bypassed. Copying producer caches is not replay.
- Accepted source2ebad35c506b95ab9a3f209341777514fbd75e679fb0f673e91d32553845fa7a;
  data32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050.
  Evidence:{link},ASSURANCE.md,COMMANDS.md,NEXT-CHECK.md and records/.
- Next experiment: after an authorized observer launch is actually restored,
  capture before/after one empty nonblocking-pipe read, including return register,
  descriptor flags,complete buffer and saved-state frame. Compare with the exact
  checked model; preserve any mismatch. This finite experiment cannot replace a
  universal concrete refinement. No new environmental assumption is adopted.
- Separate U313/U314 initializer work and distinct workspace/worktree histories
  remain intact; U290/U297 stopped routes stay stopped. Independent full-chain
  assurance,physical/source/resource applicability,admission and operational
  backup/protection evidence remain open. No Stage12,protected change,release
  signing,deployment,push,publication,merge or hosted execution. M1 EXIT NOT_ESTABLISHED.
'''
road=f'''## Read/error boundary audited — {uid}

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Model bundles0001–0006; status diagnostic | 1/1/1/1/1/1;0 | Parser and residual-goal failures preserved |
| Model0007 / repeat / complete import | 0/0/0 | Four exact theorems; four identical exports |
| Wrong ready status / changed error frame | 1/1 | Intended refusals after positive audits |
| Native runners, first/repeat | 0/0 |16 processes:14 normal exit0; two SIGPIPE(-13) |
| LLDB script check / directory launch / valid launch | 1/1/1 | No new native FFI/frame capture |
| Standard checksum / signature checks / readback | 0/0/0/0 | Exact existing artifacts and protections match |
| Replay preflight / independent full-chain replay | 0 / NOT RUN |21 snapshots match; environment/provenance gate NO_GO |

[Exact claims, assurance matrix, failures and next experiment]({link}).
The ready-read and complete error-buffer model statements are proved. Actual
ffiread syscall/offset/buffer behavior and its universal return-state frame remain
NOT_ESTABLISHED. Logical Success does not imply OS exit0. No model or original
theorem changes. is_arm8_machine_config fixes static target/register mapping;
installed/good_init_state contain the runtime premises. This corrects U310 prose.
147 closure nodes/870 files; four existing Boolean foundations;2659 parent bindings
and50 protected paths match. Independent clean replay lacks validated environment
and bootstrap provenance. No denied operation was retried. Next: restore a working
authorized observer context, then capture one exact error read; retain the need
for universal refinement. Separate U314 initialization work remains open.
No stage transition, protected change, recompilation, signing or deployment.

'''
tracker=f'''## Resume here — read/error boundary and physical gap ({uid})

[Exact report and assurance matrix]({link}).
Four published-model read/error lemmas pass fresh exact import and reproduction.
The full approved refund domain, complete event trace and all U310 premises remain.

| Item | Actual result / next action |
| --- | --- |
| Proof / repeat / import | 0/0/0;147 nodes,870 closure files,four Boolean foundations |
| Altered status / error frame | 1/1; intended exact-statement refusals |
| Native controls | Two matching eight-case runs; exit0 for seven cases, SIGPIPE(-13) for closed stdout |
| Artifact/signature/readback checks |0; both unchanged builds, prior chain and50 protected paths match |
| **Smallest open physical link** | One exact ffiread transition: OS result,full buffer,filesystem effect and complete FFI frame |
| Next observation | After an authorized observer can launch, capture one empty nonblocking-pipe read before/after |
| Independent replay |21 snapshots match; clean environment/bootstrap provenance not validated; NOT RUN |
| Parallel existing proof boundary | U314 initial stack-code proof remains open; this checkpoint does not discharge it |
| Verdict | M1 NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized |

Both debugger launch controls failed before a breakpoint. Do not retry without
an identified environment change. Finite observations do not prove universal
FFI/runtime correspondence. All source/resource/memory/installer/linker/loader/OS
conditions remain explicit. No protected change, signing or deployment occurred.

'''
records=[]
for base in [ROOT,WT]:
    journal=base/'unsure.md';before=journal.read_bytes();assert not re.search(rb'^## '+uid.encode()+rb'\b',before,re.M)
    added=entry.encode()
    with journal.open('ab') as f:f.write(added)
    assert journal.read_bytes()==before+added
    records.append({'path':str(journal),'prefix_bytes':len(before),'prefix_sha256':digest(before),'appended_bytes':len(added),'appended_sha256':digest(added),'after_sha256':digest(before+added)})
    for name,section in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        p=base/name;b=p.read_bytes();assert digest(b)==baseline['files'][str(p)]['sha256']
        pos=b.index(b'\n## ')+1
        p.write_bytes(b[:pos]+section.encode()+b[pos:])
(OUT/'tracking-update.json').write_text(json.dumps({'actual_exit':0,'entry':uid,'append_only':True,'journals':records,'end_to_end':False},indent=2)+'\n')
report=ROOT/'proposals/refund-executable-feasibility/read-runtime-20261105/REPORT.md'
s=report.read_text();report.write_text(s.replace('# Refund read boundary and runtime audit','# Refund read boundary and runtime audit — '+uid,1))
print(json.dumps({'actual_exit':0,'entry':uid,'append_only':True,'end_to_end':False}))
