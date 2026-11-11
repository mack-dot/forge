from pathlib import Path
import hashlib,json,re
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-native-audit-review-20261104')
OUT=Path(__file__).resolve().parent
def digest(b):return hashlib.sha256(b).hexdigest()
baseline=json.loads((OUT/'tracking-baseline.json').read_text());uid=baseline['entry']
assert json.loads((OUT/'goal-status.json').read_text())['goal_status']=='blocked'
assert json.loads((OUT/'audit.json').read_text())['blocked_audit']['threshold_satisfied']
for p,rec in baseline['files'].items():assert digest(Path(p).read_bytes())==rec['sha256'],p
assert uid=='U'+str(1+max(int(n) for b in [ROOT,WT] for n in re.findall(r'^## U(\d+)\b',(b/'unsure.md').read_text(),re.M)))
link='proposals/refund-executable-feasibility/runtime-blocked-audit-20261105/REPORT.md'
entry=f'''
## {uid} — Full M1 goal marked blocked after three-turn prerequisite audit

- References:U310,U314,U315,U316. CURRENT none; M1 open; Stage12 unauthorized;
  end_to_end=false. Parent local commit6ce40d4663e17499b6157f9b83d669e44b0208a6.
  Goal service confirms status blocked for the unchanged full U310 objective.
  This is not completion or a weaker success criterion. Receipt:records/goal-status.json.
- Previous goal turn classification:PROGRESS. U316 bound exact native words and
  diagnosed a standard HOL dependency restriction. U315 also made proof/native
  progress. The repeated blocker is the missing validated independent execution
  context and source/bootstrap provenance, present in U315,U316 and this audit.
  The SAT EPERM itself is not counted as three separate goal-turn failures.
- Completion audit checks all six requested requirements. Model inspection,
  conditional source/compiler results,finite native controls and byte identities
  are established at their recorded scopes. The complete physical read/frame
  relation,environment/resource applicability and independent full-chain replay
  remain NOT_ESTABLISHED. No safe authorized route to those results is available
  here without new context/input or an external-state change. No live proof or
  observer handle is being awaited; prior handles returned terminal exits.
- audit.py exits0:487 prior packet members,21 original/source snapshot pairs,
  accepted U310/U315 theory data,both exact native files,50 protected paths,
  frozen mission and existing journal prefixes match. Git HEAD/status/protected
  diff each exit0. Scoped inventory contains55 replay/environment evidence paths;
  it identifies no validated replacement context. This is not an assertion about
  all possible external infrastructure. No new runtime/proof evidence is created.
- U316's standard SAT_PROVE query retains historical exit1 and exact error
  SysErr ("Operation not permitted", SOME EPERM). The denied syscall/path stays
  unknown. No new SAT,debugger,Holmake,Docker,native,signature or replay command
  ran. No solver/temp-path/sandbox/evaluator workaround or protected change.
- Smallest unresolved proof: one complete real ffiread call must agree with the
  published model in OS result,full buffer,filesystem effects,valid return state
  and complete FFI frame. Logical Success,modeled FFI events,OS exit0 and physical
  execution remain distinct. No specification,input domain,error predicate,event
  trace,heap relation,runtime premise or resource premise was weakened.
- Unblock condition: explicitly authorized working proof/observer context plus
  reviewer-controlled clean replay environment and verified source/bootstrap
  provenance. First run the unchanged SAT dependency diagnostic there; identify
  any denied syscall/path before changes. If it passes, inspect exact instruction
  premises before composition. Execute U310's21-snapshot plan only after its
  prerequisites pass. Producer heaps/caches are not independent proof inputs.
- U310 data6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f;
  U315 data32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050;
  nativeb8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
  Prior486/147-node closures and four Boolean foundations remain; no fresh
  kernel replay is claimed by this readback. Full assumption matrices remain.
- Evidence:{link} and records/. ROADMAP,mission tracker and assurance matrix
  reflect the blocked audit. Separate U314 work and U290/U297 stopped routes
  are unchanged. All failures and distinct histories remain. No new stage,
  release signing,deployment,admission,push,publication,merge or hosted action.
  Full M1/integration EXIT NOT_ESTABLISHED; goal blocked; end_to_end=false.
'''
road=f'''## Full runtime goal blocked after prerequisite audit — {uid}

CURRENT none; M1 open; goal blocked; Stage12 unauthorized; end_to_end=false.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `attempt-0012/audit.py` |0|487 packet members,21 snapshots,accepted data,native files and50 protected paths match |
| Worktree HEAD / status / protected diff |0/0/0|Clean parent6ce40d46 before tracking updates |
| Scoped replay/environment inventory |0|No validated replacement context identified |
| New proof,SAT,debugger,native,signature,replay commands |NOT RUN|Stopped routes are not retried |

[Full requirement audit,three-turn blocker and exact next check]({link}).
The goal service confirms blocked. U315 and U316 made real progress, but the
validated independent execution/provenance prerequisite remains absent for the
third consecutive goal turn. Current available proof/observer routes cannot
close the physical correspondence. This does not count the SAT error as three
separate failures. No live job is being awaited. Full success is not established.
Smallest obligation: one ffiread call's OS result,complete buffer,filesystem effects,
return state and FFI frame must match the unchanged published model together.
Resume only with an authorized working proof/observer context and validated
independent replay prerequisites. First run the unchanged SAT diagnostic there.
No specification,premise,trace or input-domain change. Stage12 stays unauthorized.

'''
tracker=f'''## Blocked — runtime correspondence and independent context ({uid})

[Requirement-by-requirement assurance and unblock condition]({link}).
The full U310 goal is marked blocked after the three-turn audit. M1 remains open;
no success criterion is reduced. U315's model proof and U316's byte evidence remain.

| Item | Actual status / next action |
| --- | --- |
| Completion audit |NOT_ACHIEVED; physical relation and independent replay incomplete |
| Goal status |blocked; confirmed by goal service |
| Fresh identity/preservation audit |0;487 packet members,21 snapshots,50 protected paths match |
| Smallest mathematical obligation |One ffiread call: OS result,buffer,filesystem,return state and full FFI frame |
| Required external change |Authorized working proof/observer context and independent clean replay provenance |
| First check after that change |Unchanged standard SAT diagnostic; identify any denied syscall/path |
| New proof/native/replay execution |NOT RUN; no same-context retry |
| Verdict |M1/integration NOT_ESTABLISHED; end_to_end=false; Stage12 unauthorized |

U315/U316 were progress turns. The common independent-execution prerequisite
remains open on this third turn; the SAT error itself is not counted three times.
Existing proof assumptions and complete input/event/error contracts remain.
Separate U314 work and U290/U297 stopped routes are unchanged. Resume this goal
after its context prerequisites change; no protected change or signing is authorized.

'''
records=[]
for base in [ROOT,WT]:
    p=base/'unsure.md';b=p.read_bytes();added=entry.encode();assert not re.search(rb'^## '+uid.encode()+rb'\b',b,re.M)
    with p.open('ab') as f:f.write(added)
    assert p.read_bytes()==b+added
    records.append({'path':str(p),'prefix_bytes':len(b),'prefix_sha256':digest(b),'appended_bytes':len(added),'appended_sha256':digest(added)})
    for name,section in [('ROADMAP.md',road),('FORGE_MISSION_STATUS.md',tracker)]:
        p=base/name;b=p.read_bytes();assert digest(b)==baseline['files'][str(p)]['sha256'];i=b.index(b'\n## ')+1;p.write_bytes(b[:i]+section.encode()+b[i:])
(OUT/'tracking-update.json').write_text(json.dumps({'actual_exit':0,'entry':uid,'goal_status':'blocked','journals':records,'append_only':True,'end_to_end':False},indent=2)+'\n')
p=ROOT/'proposals/refund-executable-feasibility/runtime-blocked-audit-20261105/REPORT.md';s=p.read_text();s=s.replace('# Forge M1 completion and blocked audit','# Forge M1 completion and blocked audit — '+uid,1);s=s.replace('Audit verdict: **BLOCKED; full objective NOT_ACHIEVED**.','Audit verdict: **BLOCKED; full objective NOT_ACHIEVED**.\nGoal service status: **blocked**, confirmed in [goal-status.json](records/goal-status.json).');p.write_text(s)
print(json.dumps({'actual_exit':0,'entry':uid,'goal_status':'blocked','append_only':True,'end_to_end':False}))
