"""Preserve the completed conditional compiler and resource-binding evidence."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path('/Users/mackianni/forge');WT=Path('/private/tmp/forge-readiness-docs-20261103')
OUT=Path(__file__).resolve().parent
RES=ROOT/'results/refund-resource-binding-2026-11-04'
BUILDS=ROOT/'results/refund-arm8-compile-2026-11-04/attempt-0001'
REL=Path('proposals/refund-executable-feasibility/compiled-behavior-20261104')
RREL=Path('proposals/refund-executable-feasibility/resource-binding-20261104')
read=lambda p:json.loads(p.read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
b=read(OUT/'readback.json');r=read(RES/'readback.json')
assert b['actual_exit']==r['actual_exit']==0
assert b['closure_node_count']==481 and b['dependency_file_count']==2400
assert r['closure_node_count']==338 and r['dependency_file_count']==1683
before={(base,name):(base/name).read_bytes() for base in [ROOT,WT]
        for name in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']}
assert all(b'## U291 ' not in data for (base,name),data in before.items() if name=='unsure.md')
baseline={str(base):{name:{'bytes':len(before[base,name]),'sha256':sha(before[base,name])}
                    for name in ['ROADMAP.md','FORGE_MISSION_STATUS.md','unsure.md']} for base in [ROOT,WT]}
(OUT/'tracking-baseline.json').write_text(json.dumps(baseline,indent=2)+'\n')
for base in [ROOT,WT]:
 assert not (base/REL).exists() and not (base/RREL).exists()

behavior_report='''# Refund conditional compiled behavior — U291

CURRENT stage: **none**. M1 remains open. Stage 12 is unauthorized.
Model compiler link: **PROVED under the stated premises**.
Executable assurance: **PARTIALLY_ESTABLISHED**. Integration EXIT:
**NOT_ESTABLISHED**. `end_to_end=false`.

## Result and exact claim

The original compiler behavior invocation has completed with exit 0. A fresh
rebuild also returns 0. All six exported files are byte-identical. Fresh HOL
import confirms the exact required statement, zero explicit theorem hypotheses,
zero tagged axioms and only DISK_THM import tags. The logical preconditions below
remain part of the statement; zero explicit hypotheses does not remove them.

`forge_refundArm8ProofTheory.refund_compiled_behavior` states:

```text
is_arm8_machine_config mc ∧
installed code cbspace data data_sp info.lab_conf.ffi_names
  (heap_regs arm8_backend_config.stack_conf.reg_names) mc
  info.lab_conf.shmem_extra ms ∧
stdin_content fs = SOME (explode (sexp_to_string
  (refund_request charge request original remaining enabled opened
    candidate amount reason))) ∧
wfcl cl ∧ wfFS fs ∧ STD_streams fs
==>
?io_events.
  machine_sem mc (basis_ffi ext cl fs) ms SUBSET
    extend_with_resource_limit {Terminate Success io_events} ∧
  extract_fs ext (cl,fs) io_events = SOME
    (add_stdout (fastForwardFD fs 0)
      (refund_render_fields
        (refund_fields charge request original remaining enabled opened
          candidate amount reason)))
```

The exact parseable HOL statement, with qualified constants, is in
`records/audit/expected.sml`. The theorem covers every typed model request across
all nine fields, including accepted and rejected decisions. Model integers and
byte strings remain unbounded. These are nine parameters, not nine test cases.
It requires the complete six-field response. It does not execute a bank payment.

`code`, `data` and `info` are the constants from the exact checked compilation.
The theorem composes the prior whole-program semantics with the existing CakeML
compiler and ARM correctness theorems. It adds no axiom or new machine semantics.

`extend_with_resource_limit` explicitly permits a resource-limit termination
with a prefix of the specified I/O. Therefore this theorem alone does **not**
guarantee complete output or normal termination for every request. The approved
full integer/Unicode claim has not been weakened to fit the observed allocation.

## Executed acceptance matrix

All commands below actually ran. Their complete argv, working directories,
input hashes, raw logs and numeric exits are preserved in `records/`.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run_behavior.py 0001 repeat` | 0 | Original compiler behavior theorem and required dependencies finish |
| `run_behavior.py 0002 repeat` | 0 | Same source; all six exports byte-identical |
| Behavior `run.py import` | 1 | Archive layout incompatible with HOL virtual path; theorem comparison not reached |
| Behavior `run.py import-0002` | 0 | Same six artifacts in isolated standard layout; exact full claim matches |
| Behavior `run.py substituted-code` | 1 | An extra code byte in the claim is refused at exact-statement binding |
| Behavior `run.py changed-result` | 1 | Output amount+1 with unchanged input is refused at exact-statement binding |
| Behavior `readback.py` | 0 |481-node closure,2400 dependency files,6 compiled inputs,50 protected paths and artifact identities |
| Resource positive initial / corrected | 1/0 | Conjunction rendering error retained; exact model resource binding proved |
| Resource repeat / fresh import | 0/0 | Four identical exports; all three exact statements checked |
| Resource wrong limit / stale pointer | 1/1 | Both required equations reduce to F in HOL; no complete export |
| Resource `readback.py` | 0 |338-node closure,1683 files, exact capture/input binding |

The compiler substitution cases test reuse of a proof for a different claim.
They are not native executions or behavioral counterexamples. Both import the
same intact proof and fail with `Exact compiler behavior statement mismatch`.
The initial import failure is a loader error and is not counted as a successful
security rejection. No original evidence file was altered to repair its layout.

The resource cases are new checks of the published `read_limits` premise.
They do not retry U290's failed `start_pc_ok` proof. That proof remains stopped
at five failed attempts. Its negative cases and replay remain NOT RUN.

## Identity and trusted base

| Artifact | SHA256 |
| --- | --- |
| Behavioral proof source | `7cb940489138a6f81eb5b169e5397df7217170a84267e9565600273f36ff40ca` |
| Behavioral theory data | `86bb80b8c32788f6c7703339a4116546615a885054d1341938d449183250aead` |
| Prior exact compiler theory data | `30076203f55c9f0fa85dec0ebcb62d5ee41961b46055727fe26c9299e55dd78a` |
| Exact native file, unchanged | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Saved loaded code,130436 bytes | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
| Saved loaded bitmap,20248 bytes | `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76` |

CakeML remains pinned to `cd9155694c16831373ab695a670794f23282ed62`;
HOL to `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
The closure retains `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX` and
`bool.BOOL_CASES_AX`. No new axiom is introduced. Kernel/logic, Poly/ML, loader,
host and cached imported proof-data trust remain. Fresh same-host reconstruction
and import are not independent complete-chain replay or producer authentication.
The initial compiler run rebuilds many upstream dependencies. It does not claim
a clean rebuild of every dependency from an independent source or host.

No native process was executed in this turn. Saved observations remain finite
observations. Identity checks do not prove physical instruction or OS semantics.

## Resource result and missing assurance links

[Resource-binding proof and controls](../resource-binding-20261104/REPORT.md)
establish the model limit pair `(33554384,16777216)` when target registers1/2/3
have the recorded values. The quantities are stack words and heap words under
the published calculation. This does not establish `is_safe_for_space`.

| Required link | Current evidence | Exact remaining condition |
| --- | --- | --- |
| Approved refund R1–R5 source behavior | Prior source and UTF-8 transport proofs retained | Complete binding of the exact source/Unicode representation to this model and external I/O |
| Whole modeled program to compiled behavior | PROVED here under explicit premises | Resource-limit alternatives remain; no unconditional complete-output claim |
| Exact loaded code and finite FFI equations | U283 observations and U289 model equations retained | Applicable complete installed state, memory frames and universal runtime correspondence |
| Entry layout | NOT_ESTABLISHED; U290 attempts1–5 exit1 | Unresolved lemma application; five-attempt boundary remains |
| Model resource limits | PROVED conditionally for recorded pointers | Full-domain `is_safe_for_space` for all pointer oracles and compatible real allocation |
| Physical ARM/OS/FFI/interference/exit | NOT_ESTABLISHED | Actual control state, justified environment relation, progress and process-exit semantics |
| Independent verification and authority | Local rebuild/import only | Clean full-chain replay, exact claim/profile review, authenticated new provenance and admission |
| Independent recovery | Owner reports another-device copy | Exact required archive hashes and restore from that copy remain unverified |

The full model theorem does not itself close the Dafny Unicode/native assurance
chain. Existing UTF-8 source results remain valid within their original scope.
No input restriction or unsupported success is introduced.

## Smallest next authorized action and approval packet

Audit the exact binding between U262's UTF-8 transport byte-level method,
U267's unchanged generated-method relation, and this theorem's serialized
input and output clauses. Retain all nine inputs and all six outputs. Use the
existing published source/model tools. A new binding experiment has NOT RUN.
Keep the separate malformed-input initialization work under its existing owner.

Do not restart the completed compiler jobs. Preserve U290's entry-layout stop.
Any new approach to that stopped obligation must respect the repository's
five-attempt boundary. Complete installed-state, runtime and resource proofs
remain necessary; human approval cannot replace missing mathematical evidence.

The standalone review packet consists of the behavioral source and six identical
exports, exact claim in `expected.sml`,481-node closure, substitution controls,
and the separately bounded resource result. Independent review must assess the
precise conditional claim and every assumption before protected adoption.
Any stronger native claim requires its own justified complete assurance profile.
Publication, push, merge, workflow dispatch, signing, admission and deployment
retain their separate authorization boundaries. None ran here. Stage12 remains
unauthorized. Historical Stage9 signatures do not authorize this new claim.

## Measurements and verdict

Original compiler invocation:9397.899061417003 local wall seconds, including
dependency work. Own-theory rebuild:112.63485225001932 seconds. These scopes are
different and do not establish a speedup. Hosted refund wall time and runner
minutes are **NOT RUN**. No cost or performance improvement is claimed.

The model compilation link is established under its stated conditions. The
complete executable assurance chain and integration EXIT remain unestablished.
Preserve `end_to_end=false`; M1–M4 remain the active full mission.
'''
resource_report='''# Refund model resource-limit binding

CURRENT stage:none; M1 open; Stage12 unauthorized; `end_to_end=false`.
This result proves the exact published resource-limit calculation under recorded
register-equality premises. It does not prove that the full program fits.

`forge_refundResourceBindingTheory.recorded_config` proves that the compiler
maps abstract heap registers2/3/4 to target registers1/2/3. For every register
allocation oracle, the configuration supplies maximum heap cap9007199254740991.

`recorded_limits` proves the existing `get_stack_heap_limit` equation:

```text
get_stack_heap_limit 9007199254740991
  (496542679040w,496811114496w,497079549952w:word64)
= (33554384,16777216)
```

`recorded_read_limits` retains three explicit register-equality premises and
concludes that `read_limits arm8_config (set_oracle arm8_backend_config oracle)
mc ms` equals this pair. The published calculation accounts for its48-word
store area and two heap semispaces. These are model stack/heap word counts.
They do not prove the native allocation is sufficient for unbounded input.

The pointer values come from U283's saved capture, whose readback SHA256 is
`65d4d7575d530a025aa8cfb2425e4884b9bdca0562a94bf312a6dccb88a49862`.
Its file identity matches the committed capture manifest. Mapping the physical
state to `mc.target.get_reg` still requires the concrete/model state relation.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run.py positive` | 1 | Python rendering consumed conjunction backslashes; parse failure preserved |
| `run.py positive-0002` | 0 | Three exact model theorems proved |
| `run.py repeat` | 0 | Same source; four exports identical |
| `run.py wrong-limit-0002` | 1 | Claimed heap limit+1 reduces to F |
| `run.py stale-midpoint-0002` | 1 | Midpoint+16 with stale result reduces to F |
| `import_audit.py` | 0 | Three exact statements; zero explicit hypotheses/tagged axioms; DISK_THM only |
| `readback.py` | 0 |338 closure nodes,1683 files,50 protected paths and exact capture/source binding |

Each negative case preserves the valid configuration check, then fails at
`recorded_limits`. Neither creates a complete export. The negative changes are
checked byte for byte against the positive source. No native mutant executes.

Proof source SHA256:
`8cfa0077f484ab557609c82b1908ab8f6cd464fa9aa7eac1f3db17dc5193d792`.
Theory data SHA256:
`40d07eeab9189f9e2bcc02f071454c2c927ef91ffd5734c66f1e1a380edf65a6`.
The four prior HOL foundation axioms remain visible. All seven inspected
upstream source files match the pinned CakeML Git objects. The exact expected
terms, commands, logs, file identities and closure are in `records/`.

This is a same-host reconstruction and fresh import with cached parent data.
It does not authenticate a producer or independently replay all upstream source.
No new semantics, axiom, verifier, protected policy or native artifact is added.
This obligation is separate from U290's stopped entry-layout proof.

The required stronger compiler theorem retains
`forall po. is_safe_for_space ... (stack_limit,heap_limit)`.
That condition is **NOT_ESTABLISHED** for the full refund input domain. Complete
installation, physical ARM state, FFI/OS, interference and native exit remain
open. No assumption is accepted by this result and no claim is admitted.
'''

def copy_tree_files(source,target):
 for f in sorted(source.rglob('*')):
  if f.is_file():
   d=target/f.relative_to(source);d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,d)

packet=ROOT/REL;packet.mkdir(parents=True)
copy_tree_files(OUT,packet/'records/audit')
for case in ['behavior-0001','behavior-0002']:
 copy_tree_files(BUILDS/case,packet/'records'/case)
for name in ['run_behavior.py','forge_refundArm8ProofScript.sml']:
 shutil.copyfile(BUILDS/name,packet/'records'/name)
(packet/'REPORT.md').write_text(behavior_report)
rp=ROOT/RREL;rp.mkdir(parents=True);copy_tree_files(RES,rp/'records');(rp/'REPORT.md').write_text(resource_report)
for rel in [REL,RREL]:
 p=ROOT/rel
 man={str(f.relative_to(p)):sha(f.read_bytes()) for f in sorted(p.rglob('*')) if f.is_file()}
 (p/'MANIFEST.json').write_text(json.dumps(man,indent=2)+'\n')
 shutil.copytree(p,WT/rel)

link=str(REL/'REPORT.md')
status=f'''## Current executable-proof checkpoint — U291

[Exact conditional compiler theorem, controls and remaining premises]({link}).
The original compiler job is **FINISHED, exit0**. Its rebuild returns0 and all
six exports match. Fresh exact-statement import returns0 after one preserved
loader-layout failure1. Substituted code and changed output claims are refused1/1.
The audit records481 closure nodes and2400 dependency files.

The theorem covers all nine typed model input fields and the complete six-field
refund response. It retains installation, machine and filesystem premises, plus
resource-limit I/O prefixes. It does not prove full native output or termination.
The separate resource-binding proof passes0, repeat0, import0; wrong limit and
stale pointer reject1/1. Resource sufficiency remains open.

| Priority | Next action | Required completion evidence |
| --- | --- | --- |
| 1 | Bind the full Unicode/source/model input-output chain | Exact U262 transport method to U267 original-method relation and U291 serialization; all nine inputs and six outputs; no domain restriction |
| 2 | Establish applicable concrete entry/runtime/resource conditions | Installed state, frames, ARM control state, FFI/OS/interference, sufficient resources and native exit; U290 remains stopped at five attempts |
| 3 | Independently replay and review the complete assurance claim | Clean full-chain replay, exact assumption/profile review and independent approval |
| 4 | Bind new provenance/admission and verify independent recovery | Authorized exact artifact/evidence chain; other-device archive hashes and restore |

Do not poll or restart completed compiler jobs47209/47239. Separate malformed-input
source work retains its owner. M1 remains open; M2–M4 stay later priorities.
End-to-end and integration EXIT remain NOT_ESTABLISHED; end_to_end=false.
Hosted refund measurements NOT RUN. No protected adoption, publication, merge,
dispatch, signing, admission, deployment or Stage12 occurred.

'''
roadmap=f'''## Conditional compiler behavior established — 2026-11-04 (U291)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run_behavior.py 0001 repeat` / `0002 repeat` | 0/0 | Original job finished; six exports reproduce exactly |
| Behavior import / corrected isolated-layout import | 1/0 | Initial loader failure retained; exact full conditional claim checked |
| Substituted code / changed result bindings | 1/1 | Exact-statement mismatch; no native counterexample claim |
| Behavior readback.py | 0 |481-node closure,2400 files, exact artifacts and50 protected paths |
| Resource positive initial/corrected/repeat/import | 1/0/0/0 | Initial rendering error retained; three exact statements and four equal exports |
| Wrong resource limit / stale midpoint | 1/1 | Intended false equations; residual F |
| Resource readback.py | 0 |338-node closure,1683 files, exact captured pointer inputs |

[Actual theorem, commands, hashes, assumptions and approval packet]({link}).
The compiled model behavior permits resource-limit I/O prefixes. Full input-domain
Unicode/source/model binding, applicable installed state, physical runtime and
resource sufficiency, native exit, independent replay/review and new admission
remain open. Exact other-device restore remains unverified. Compiler jobs are
terminal; do not restart them. U290's entry-layout proof stays stopped at five
attempts. No new stage or protected adoption. Integration EXIT NOT_ESTABLISHED.

'''
entry=f'''

## U291 — Conditional refund compiler behavior and recorded resource binding checked

- References: U262,U267,U271,U275,U277,U283,U284,U289,U290. CURRENT none;
  M1 open; Stage12 unauthorized; end_to_end=false. Prior turn made progress by
  preserving exact entry-layout failures and committing950bde8. This turn closes
  the conditional model compilation link. U286 and U288 remain separate work.
- Original compiler behavior process completes0 after9397.899061417003 local
  wall seconds. Same-source rebuild0 takes112.63485225001932 seconds. All six
  exports match byte for byte. Different dependency scopes prevent a speedup
  claim. Original runner47209/Holmake47239 are terminal; no further polling.
- refund_compiled_behavior covers all nine typed model fields and full rendered
  six-field output. Its premises retain is_arm8_machine_config, installed code,
  canonical stdin, wfcl,wfFS and STD_streams. It concludes machine behaviors lie
  in extend_with_resource_limit of the specified source success trace. It permits
  resource-limit prefixes. It does not guarantee complete output/normal native
  termination. No input-domain restriction, new axiom or semantics was introduced.
- Source7cb940489138a6f81eb5b169e5397df7217170a84267e9565600273f36ff40ca;
  data86bb80b8c32788f6c7703339a4116546615a885054d1341938d449183250aead.
  Exact native remains b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8.
  Saved loaded code/bitmap and six prior compilation artifacts remain identical.
- Fresh import first fails1 before theorem comparison: virtual-path loader
  appends .hol/objs to the archived objects directory. Isolated standard-layout
  copies of the same six files give import0. The exact qualified statement has
  zero explicit hypotheses/tagged axioms and DISK_THM only. Preconditions remain
  in its conclusion. Closure481 nodes/2400 files retains four prior bool axioms.
  Local rebuild/import is not clean independent full-chain replay or provenance.
- Substituted code (extra leading0 byte) and changed output amount+1 each return1
  for Exact compiler behavior statement mismatch. Input serialization stays
  unchanged in the latter case. These are proof/claim binding controls, not
  native behavioral counterexamples. Readback0 checks exact intended mutations,
  successful imports, every identity and50 unchanged protected paths.
- Separate resource proof: first syntax/rendering attempt1; corrected positive0,
  same-source repeat0, fresh import0. Three statements bind the published register
  names and read_limits to recorded pointers. Four exports match. Model stack/
  heap limits are33554384/16777216 words under explicit register-equality premises.
  Source8cfa0077f484ab557609c82b1908ab8f6cd464fa9aa7eac1f3db17dc5193d792;
  data40d07eeab9189f9e2bcc02f071454c2c927ef91ffd5734c66f1e1a380edf65a6.
  Claimed heap limit+1 and stale result after midpoint+16 both fail1 at
  recorded_limits with residual F and no complete export. Readback0 checks
  338 closure nodes/1683 files and the committed capture identity. No physical
  state relation or is_safe_for_space proof follows from these numeric limits.
- Packets:{link} and {RREL/'REPORT.md'}.
  All failures remain. U290 is not retried: its five-attempt boundary remains.
  Separate source initial-heap check was observed with exit0, but its final
  composition/replay remains owned by the source task; no new whole-chain claim.
- Highest remaining assurance gaps: exact full Unicode/source/model binding;
  applicable installed state and frames; physical ARM/FFI/OS/interference;
  full-domain resource sufficiency and native exit. Independent complete-chain
  replay/review, new authenticated provenance/admission and exact off-machine
  archive hashes/restore remain open. No assumption is promoted to fact.
- Next authorized check: audit U262's exact byte-level transport method against
  U267's unchanged method relation and U291 input/output clauses, retaining all
  nine inputs and six outputs. New experiment NOT RUN. No native run/rebuild,
  signing, protected adoption, publication, merge, dispatch, admission, deployment
  or Stage12 occurred. Hosted measurements NOT RUN. Integration NOT_ESTABLISHED.
'''
for (base,name),original in before.items():assert (base/name).read_bytes()==original,str(base/name)
for base in [ROOT,WT]:
 for name,section in [('ROADMAP.md',roadmap),('FORGE_MISSION_STATUS.md',status)]:
  old=before[base,name].decode();i=old.index('\n## ')
  (base/name).write_text(old[:i]+'\n\n'+section+old[i:])
 with (base/'unsure.md').open('ab') as f:f.write(entry.encode())
 assert (base/'unsure.md').read_bytes().startswith(before[base,'unsure.md'])
print(json.dumps({'actual_exit':0,'journal_id':'U291','packets':[str(REL),str(RREL)],'end_to_end':False}))
