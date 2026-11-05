# Refund entry-layout checkpoint — U290

CURRENT stage: **none**. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. Integration EXIT: **NOT_ESTABLISHED**.

## Decision

The proposed entry-layout proof has no accepted export. Five positive attempts
return exit 1. Stop this proof path at the repository's five-attempt limit.
The final failure is an unresolved application of an existing lemma. It does
not establish that the executable has an incorrect layout. Do not infer a
passing proof from partial saved-theorem messages.

The original compiler behavior job remains live at the saved checkpoint.
Do not restart or duplicate runner 47209 / Holmake 47239. The next active action
is to collect its terminal result, inspect the exact theorem and premises, then
run binding controls and reproduction if it succeeds. The separate source
initialization work retains its ownership. This document does not report a new
result for that work.

## Exact scope and identity

The target is the existing refund executable, SHA256
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
This check does not rebuild, sign or execute it. The M1 claim remains the approved
refund R1–R5 decision/intent behavior over the full integer and Unicode domain.
Finite observations do not restrict or establish that full-domain claim.

The proposed theorem checks existing `targetSem.start_pc_ok` for one candidate
model configuration. It uses the saved entry PC `4300243152`, exact file symbols,
and three projected half-open address intervals:

| Field | Value | Classification and limit |
| --- | --- | --- |
| Entry PC | 4300243152 | OBSERVED in the saved capture |
| Image relocation | 5259264 | DERIVED from PC minus file `cake_main`; uniform relocation ASSUMED |
| read/write/close/open_in PCs | 4300243104 / 4300243088 / 4300243072 / 4300243056 | DERIVED; not individually observed in this capture |
| Halt / install PC | 4300243136 / 4300243120 | DERIVED under the same relocation assumption |
| Code and code-buffer range | [4300243152, 4300374016) | Candidate model domain from recorded scalar bounds |
| Heap and stack range | [496542679040, 497079549952) | Recorded allocation bounds; full model relation NOT_ESTABLISHED |
| Bitmap range | [4300406808, 4300427056) | OBSERVED bounds; exact payload identity checked previously |
| Shared addresses | Empty set | Proposed model projection; no complete physical-state claim |
| Complete installed state | Not established | Memory relation, frames and physical control state remain open |

Other machine-configuration fields remain arbitrary in the proposed statement.
The statement does not prove a loader, a memory-frame relation, ARM hardware
semantics, universal FFI behavior or physical process termination.

## Executed commands and failures

All full attempts use `python3 -B results/refund-entry-model-2026-11-04/run.py CASE`.
Each `records/CASE/command.json` stores the exact HOL argv, working directory,
source hash, heap hash, monotonic duration and numeric exit.

| CASE or command | Actual exit | Actual result |
| --- | --- | --- |
| prepare.py; `/usr/bin/nm -n` exact executable | 0;0 | Record exact symbols and derive candidate addresses |
| positive | 1 | HOL string-list type differs from required mlstring-list type |
| positive-0002 | 1 | EVAL does not unfold exported `ffis` constant |
| ffi-definition | 0 | Diagnostic prints exact encoded definition; no layout proof |
| positive-0003 | 1 | Explicit definition leaves four `cv_snd` reductions |
| positive-0004 | 1 | Compiled names proved; Q.INST argument has wrong ML type |
| positive-0005 | 1 | Compiled names proved; `observed_mmio_index` lemma application remains unresolved |
| checkpoint.py | 0 | Twelve capture members, fifty protected paths, mission, native and recovery-bundle identities checked |
| Git bundle create / verify / clone / rev-parse / fsck | 0/0/0/0/0 | Local recovery of commit f39849d; 12865 tracked file/symlink contents match |
| Wrong FFI slot / halt in domain | NOT RUN | Prepared exact negative cases; positive export is absent |
| Layout reproduction / fresh import / closure audit | NOT RUN | No accepted layout theory to reproduce or import |
| Original compiler behavior proof | IN_PROGRESS | No terminal command.json at checkpoint |
| Hosted refund metrics | NOT RUN | No runtime or cost improvement claim |

Final source SHA256:
`5af4bfb81b709deebce5d9f1fda3a284d0ae0b8f16e7b83eb88301fa17f35bf8`.
Pinned CakeML heap SHA256:
`36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`.
All five failed attempts have empty complete-object inventories.
The original required theorem statements were retained through tactic and type
corrections. No new axiom, semantic definition or theorem weakening was introduced.

The final residual still contains free `ffis` in the antecedent of the intended
specialized lemma. The required concrete conclusion is unchanged. A future
attempt must first explain this exact specialization failure and respect the
five-attempt boundary. No sixth full attempt ran.

## Established evidence retained

U289's four captured FFI equations remain checked, reproduced and imported.
Their positive/repeat/import exits are historical 0/0/0; altered data and wrong
write-descriptor checks reject with 1/1. See the separate
[FFI report](../ffi-model-conformance-20261104/REPORT.md).
No FFI proof or native execution is rerun by this checkpoint.

The entry observation has twelve members that match the committed U283 manifest.
All fifty protected files and the mission hash are unchanged. Exact command
records are in `records/checkpoint.json` and `records/compiler-input-readback.json`.
The original compiler log has completed backendProofTheory but has no terminal
whole compiler-behavior result at this snapshot.

## Recovery and independent backup

The local bundle `/Users/mackianni/forge-backups/forge-ffi-conformance-2026-11-04.bundle`
has SHA256 `6200c9c80872ed4200a5e6620e0ef92b61b23cdf1eb516155bfd805c1493e03d`.
It restores commit `f39849d74e0bbb9604b7453eb3f5ec9ece62c914` locally.
This bundle predates the present entry-layout checkpoint and does not contain the
whole toolchain cache or all raw archives. It is not evidence of an independent copy.

The owner reports a backup on another device. Exact required archive hashes and
a restore from that independent copy remain **NOT VERIFIED**. Preserve that
distinction. Confirm the selected required archive and manifest hashes on that
device, verify their contents, and record a restore from that copy. No remote
backup access, upload or independent restore occurred here.

## Remaining claim and approval boundaries

Still open: complete source/model binding over the approved input domain;
applicable installed state and memory frames; physical ARM control state;
universal runtime/FFI/OS and interference relations; resource sufficiency and
native exit; clean independent full-chain replay and claim/profile review;
new authenticated provenance and independent admission; exact off-machine restore.
Historical signatures do not authorize this new refund claim.

Local evidence and unsigned documentation commits are authorized. Protected
adoption, publication/push, merge, dispatch, signing, admission and deployment
retain their separate boundaries. No new approval follows from this report.
No Node, SPM, new stage, policy change or unrelated infrastructure is added.

Use [FORGE_MISSION_STATUS.md](../../../FORGE_MISSION_STATUS.md) as the current
action tracker. Use ROADMAP.md for actual results and append-only unsure.md for
uncertainty. Preserve this checkpoint and its failures when later work changes
the status.
