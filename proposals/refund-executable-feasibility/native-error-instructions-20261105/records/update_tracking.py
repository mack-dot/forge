from pathlib import Path
import hashlib,json,re
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def digest(b):return hashlib.sha256(b).hexdigest()
baseline=json.loads((OUT/'tracking-baseline.json').read_text());uid=baseline['entry']
for p,rec in baseline['files'].items():assert digest(Path(p).read_bytes())==rec['sha256'],p
assert uid=='U'+str(1+max(int(n) for b in [ROOT,WT] for n in re.findall(r'^## U(\d+)\b',(b/'unsure.md').read_text(),re.M)))
link='proposals/refund-executable-feasibility/native-error-instructions-20261105/REPORT.md'
entry=f'''
## {uid} — Exact native error words bound; standard ARM8 proof dependency returns EPERM

- References:U272,U275,U276,U283,U286,U290,U296,U297,U301,U310,U314,U315.
  CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Parent local
  commit2e4315138a6984268d4ad1297748337af3adcec3. Previous goal turn made progress;
  this continuation adds exact instruction identities and a minimal dependency
  failure. No new native instruction theorem or full-chain result is established.
- Pinned LLDB static disassembly and section listing exit0. No native process
  launch. All28 words in the112-byte ffiread disassembly match both exact files.
  Separate raw-word readback0 checks every word again against file bytes, not
  merely the producer's count. Fragment starts at file offset151920 and hashes
  ec5f3b8045a2d7038e8645acd7bd72a001bddc75ab24b7fd913c4d36cc163bf4.
- Exact post-read error words:37f800c0,52800028,39000268,a9417bfd,a8c24ff4,d65f03c0.
  Standard disassembly identifies branch,status write,register/stack restore and
  return. No custom instruction decoder or semantics was written. These words
  identify a proposed six-step proof, not a checked state transition or frame.
- First relative arm8_stepLib load exits1 at missing ui search path. Absolute
  load exits1 in unchanged utilsLib/numLib.DECIDE. The published existing ARM8
  heap gets past utilsLib but exits1 in arm8_stepLib/numLib.DECIDE. All three
  invocations stop before any requested instruction theorem or export. No fourth
  library-load attempt. Original tools,heaps,sources and failures remain intact.
- A separate standard HOL dependency diagnostic, without loading stepLib again,
  calls HolSatLib.SAT_PROVE on probe OR NOT probe. It exits1 with exact error:
  SysErr ("Operation not permitted", SOME EPERM). DECIDE/TAUT/SAT source inspection
  supports the dependency-chain explanation, but does not prove that every old
  DECIDE failure had this cause. The denied syscall/path remains NOT_ESTABLISHED;
  process creation versus temporary-file access is not distinguished.
- Stop this proof-tool route. No alternate solver,temp path,helper process,
  sandbox change,evaluator patch or permission bypass. This is an OS-reported
  EPERM, not an automatic approval-review rejection. Library failures are not
  accepted negative controls. New proof/repeat/import/control/closure checks
  are NOT RUN because no instruction theory exists. U315 remains the checked
  read/error model result; no source contract, event trace or premise changed.
- First artifact reader exits1 because it searches stdout for a stderr loader
  message. Corrected readback_0002.py exits0 and checks both retained streams.
  It verifies2659 prior parent bindings,ten source snapshots,270 U315 members,
  134 U310 members,additional tool/heap identities,both native files,50 protected
  paths,frozen mission and existing journal prefixes. First reader and log remain.
- HOL revision9783a49979c94c401ff8c0e51b2eefae7ea95ae3 has a clean tracked diff.
  Existing ARM8 heap787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9;
  L3 heap9a59e119969c4a180d1eaa19104f92237054ca5e81fe3298e5ad9843b440052c.
  Local identities do not establish independent source/bootstrap provenance.
  Native remains b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
- Smallest physical obligation stays the complete single-call ffiread relation:
  OS result,full buffer,filesystem effect,valid return state and FFI frame together.
  A future six-instruction theorem would cover only the post-syscall error return
  under explicit machine/code/stack/separation/return premises. It would not
  establish the syscall,whole prologue,physical ISA or complete FFI refinement.
- Next smallest tool check: run the unchanged standard dependency diagnostic in
  an explicitly authorized context that permits its underlying operation. Identify
  the failed syscall/path there before proposing changes. Do not retry the same
  blocked context. If it passes, inspect full exact instruction premises before
  composing, then require fresh statement/closure/repeat/control and byte audits.
- Evidence:{link},ASSURANCE.md,COMMANDS.md and records/.
  Independent21-snapshot replay remains NOT RUN: clean environment and provenance
  prerequisites are unvalidated. No debugger launch,native execution,recompilation
  or signature command ran here. Prior signatures/controls are reused only through
  unchanged identities. All physical/source/resource/installer/linker/loader/OS
  gaps remain. U290/U297 stopped routes and separate U314 work are untouched.
- No protected change,new stage,release signing,admission,deployment,push,merge,
  publication or hosted action. M1 and integration EXIT NOT_ESTABLISHED.
'''
road=f'''## Native error-instruction boundary and tool restriction — {uid}

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Pinned LLDB static inspection / byte binding / raw-word readback | 0/0/0 |28 words match both existing native files; no launch |
| Relative / absolute / published-ARM8-heap library loads | 1/1/1 | Missing search path,then two DECIDE failures; no instruction theorem |
| Separate standard HOL SAT dependency diagnostic |1|SysErr Operation not permitted (EPERM) |
| Artifact reader first/corrected |1/0|stderr reader corrected; all failures retained |
| New instruction proof,repeat,import,controls |NOT RUN|No theory exported |
| New native execution,signing,independent full-chain replay |NOT RUN|Environment/provenance prerequisites remain open |

[Exact words,commands,tool error and assurance limits]({link}).
The six post-read error instructions are now bound to exact executable bytes.
Their state/frame theorem remains NOT_ESTABLISHED. The standard SAT_PROVE query
for probe OR NOT probe fails with EPERM. The denied syscall/path is unknown;
do not change solver,temp path or permissions to reroute it. Stop this proof-tool
route until an authorized context permits the operation. No machinery was edited.
2659 prior bindings,ten sources,404 prior packet members and50 protected paths
match. U315's accepted model theorems remain unchanged. Physical ffiread/OS/frame,
installation,resource and independent-replay gaps remain. Next: validate the
unchanged dependency diagnostic in an authorized working context, then inspect
the exact six instruction premises. No new stage or protected/remote action.

'''
tracker=f'''## Resume here — native error words bound; instruction tool blocked ({uid})

[Exact checkpoint and assurance matrix]({link}).
The existing native artifact's28 ffiread words match; no new instruction theorem
was produced. U315 remains the accepted read/error model proof.

| Item | Actual result / next action |
| --- | --- |
| Static disassembly / byte binding / raw-word readback |0/0/0; both native files unchanged |
| Instruction-library loads |1/1/1; stopped before a step theorem |
| Standard SAT dependency query |1; SysErr Operation not permitted (EPERM) |
| Evidence reader first/corrected |1/0; prior proofs,tool sources and protections match |
| **Next tool check** | Same SAT_PROVE diagnostic in an explicitly authorized working context; identify denied syscall/path |
| **Smallest open physical link** | One complete ffiread transition: OS result,buffer,filesystem,state and frame |
| New proof/repeat/import/controls |NOT RUN; no instruction export |
| Independent replay |NOT RUN; independent clean context and bootstrap provenance unvalidated |
| Verdict |M1 NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized |

Do not retry the same blocked context or patch proof machinery. A future six-step
model proof would still need syscall,entry/prologue and physical applicability.
All U310 premises and complete event/error/heap requirements remain. Earlier
evidence,separate U314 work and U290/U297 stopped routes remain intact.

'''
records=[]
for base in [ROOT,WT]:
    p=base/'unsure.md';b=p.read_bytes();added=entry.encode();assert not re.search(rb'^## '+uid.encode()+rb'\b',b,re.M)
    with p.open('ab') as f:f.write(added)
    assert p.read_bytes()==b+added
    records.append({'path':str(p),'prefix_bytes':len(b),'prefix_sha256':digest(b),'appended_bytes':len(added),'appended_sha256':digest(added)})
    for name,text in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        p=base/name;b=p.read_bytes();assert digest(b)==baseline['files'][str(p)]['sha256'];i=b.index(b'\n## ')+1;p.write_bytes(b[:i]+text.encode()+b[i:])
(OUT/'tracking-update.json').write_text(json.dumps({'actual_exit':0,'entry':uid,'journals':records,'append_only':True,'end_to_end':False},indent=2)+'\n')
p=ROOT/'proposals/refund-executable-feasibility/native-error-instructions-20261105/REPORT.md';s=p.read_text();p.write_text(s.replace('# Exact native error instructions; proof dependency blocked','# Exact native error instructions; proof dependency blocked — '+uid,1))
print(json.dumps({'actual_exit':0,'entry':uid,'append_only':True,'end_to_end':False}))
