# Refund conditional compiled behavior — U291

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
