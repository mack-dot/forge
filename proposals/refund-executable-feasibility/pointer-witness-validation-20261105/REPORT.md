# Exact refund pointer witness — U311

CURRENT stage: **none**. Active milestone: **M1 — executable behavioral correctness**.
Stage12 remains unauthorized. `end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

The full approved refund R1–R5 integer/Unicode behavior remains the objective.
This packet closes the local pointer-witness validation gap recorded in U308.
It does not establish the complete executable claim. The existing fixed RISC-V
example remains supporting evidence; M2–M4 remain later priorities.

## Checked result

The [unchanged proof source](records/pointer-gc-normalized.sml) builds four claims
in `forge_refundPointerWitness`. A [fresh complete audit](records/expected-limits.sml)
checks their statements, retained premises and dependency/assumption closure.
The [successful import log](records/exact-import-0003/stdout.log) is the executed
record. [COMMANDS.md](COMMANDS.md) preserves exact child commands and exit codes.

| Theorem | Exact scope |
| --- | --- |
| `refund_initializer_oracle_independence` | The exact constructor's syntax-oracle dependence is confined to its compiler-oracle field |
| `refund_pointer_fixed_point` | Published all-clock pointer representation, conditional on causal syntax-prefix agreement |
| `refund_fixed_syntax_pointer_witness` | The representation for the constructed pointer witness and fixed arbitrary syntax oracle |
| `refund_witnessed_single_epoch` | The corresponding conditional word trace has one epoch for every clock |

The generic helper keeps its causal condition:
`forall po po' i. (forall j <= i. po j = po' j) ==> Syn po i = Syn po' i`.
The fixed-syntax instance sets `Syn = (lambda po. syn)`, which proves that
condition. `syn` itself remains arbitrary. The resulting pointer oracle is the
specific published `ptr_eq_fix` construction. An arbitrary substituted pointer
oracle is not justified. This does not narrow the approved source-input domain.

Seven applicability conditions remain: `STD_streams fs`, `wfFS fs`, `wfcl cl`,
canonical stdin, nonempty stack, endian agreement and `data_lang_safe_for_space`.
The space condition refers to that exact constructed pointer witness. Its truth
for a physical execution is **not established**. The complete printed statement,
not this prose summary, controls interpretation.

The constructor may return a synthetic fallback when optional initialization
fails. These claims do not prove the successful initializer branch, physical
memory/register correspondence, resource adequacy or full target installer
exclusion. A one-epoch word trace alone does not discharge U298's target-prefix
condition. Matching modeled fields cannot substitute for runtime applicability.

## Audit repair and preserved failures

The first two composition bundles fail with `Pointer premise shape mismatch`.
The normalization diagnostic exits0. Normalizing the already checked GC equality
before applying it allows the third composition to pass. Endian agreement remains
an explicit condition; no axiom or unproved premise is discarded.

Fresh complete imports1/2 fail on resource-premise equivalence. The first premise
diagnostic fails because `map_index` is undeclared. A new copy uses the standard
list operations and exits0. It reports five matching resource arguments and one
mismatch: argument3, the `get_limits` state. Only that state's `be` field differs
in the diagnostic text. See [the diagnostic](records/premise-diagnostic-indexed/stdout.log)
and [text comparison](records/resource-argument-text-diff.json).

The published `get_limits_def` projects stack/heap limits and configuration
fields; it does not read the state's endian field. The third audit unfolds that
definition and HOL proves equivalence of the complete seven-premise contracts.
The proof source, claim and exported objects do not change during this repair.
This is checked equivalence, not acceptance based on a textual comparison.
The explicit endian and resource premises remain in the theorem.

Composition and complete-premise equivalence each pass on their third proof
attempt. No failing proof exceeds five attempts. U290/U297 stay stopped.
Both diagnostic failures, the two full imports, prior transport errors and two
incidental continuation inspection/preparation errors remain recorded. Script
errors are not successful adversarial controls.

## Actual results

| Check | Actual exit(s) | Result |
| --- | --- | --- |
| Historical composition bundles1/2/3 | 1/1/0 | Four final claims, seven conditions |
| Historical normalization diagnostic | 0 | Diagnostic only |
| Premise diagnostic, original/corrected | 1/0 | Corrected run isolates resource argument3 |
| Full-contract imports1/2/3 | 1/1/0 | Third import checks complete contract and closure |
| Proof repeat / byte comparison | 0/0 | Four byte-identical exports |
| Substituted pointer / omitted causal prefix / omitted space | 1/1/1 | Intended refusals after complete positive audits |
| `readback-validation.py` | 0 | Exact bytes, closure, pins and protected paths checked |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Full assurance chain remains open |

The three controls reject a statement with an arbitrary pointer, a statement
with the causal prefix condition removed, and premise equivalence with the
resource condition removed. The first two fail exact statement binding. The
third leaves `data_lang_safe_for_space` unproved. These are claim/premise controls,
not physical counterexamples or release-admission decisions. Each first completes
the unchanged positive audit. See [controls-readback.json](records/controls-readback.json).

All four claims have zero explicit hypotheses and no new tagged axioms. The
closure contains 491 theory nodes and 2430 hashed dependency files.
The four existing Boolean foundations remain: `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, `BOOL_CASES_AX`. These are same-host checks with cached `DISK_THM`
parents. They are not an independent clean full-chain replay or authenticated
production. [readback-validation.json](records/readback-validation.json) records
the measured closure and exact identities. The old unexecuted readback draft
remains unchanged; the new script includes all real failures and completed cases.

## Identity and local measurements

| Item | Exact value |
| --- | --- |
| Baseline local commit | `a431f1714f360e2abc31157acd500f49df409583` |
| Proof source SHA-256 | `99e35d5937ac492740bd9a5c674c6fba7adf5ba2e0773db2d5a50978dac9b71f` |
| Theory data SHA-256 | `2ee72b9c06e787835dd0ecde5b7a2fb17e1adf70323ad2f2a6b2e318b463d320` |
| Native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Fresh successful import wall seconds | 89.78375841700472 |
| Repeat wall seconds | 87.96290237500216 |
| Hosted runner-minutes and performance comparison | NOT RUN |

Seven pinned sources, 50 protected paths and 4393 members of prior
packets match. The U308 checkpoint stays unchanged. Both tracked toolchain trees,
mission bytes and native identity match. Local durations are observations, not
hosted costs or performance savings. No new native execution occurred.

## Smallest next assurance link

Specialize the existing `full_make_init_semantics` relation for this exact
constructor. Its conclusion includes `opt <> NONE` and conditional stack/lab
semantics equality. Preserve and justify its code/oracle, memory layout,
alignment, saved-register, register-name and configuration premises. Reuse the
published `oracle_stack_good_code`, exact compilation theorem and configuration
facts. Do not infer successful initialization from the fallback constructor.

Then inspect the lower-pass evaluator relations needed to connect the word trace
to [U298's exact target-prefix condition](../target-install-bridge-20261105/REPORT.md).
Final-output semantics equality alone must not be relabeled as equality of every
intermediate transition. All attempted installer entries, including failed ones,
must be covered by the required prefix statement. This application remains open.

Physical state, FFI/OS and resource applicability, source review, independent
full-chain checking and new authenticated provenance/admission remain open.
The owner reports another-device backup; exact archive hashes and a restore on
that copy remain unverified. Effective GitHub protections were not refreshed.
Operational blockers remain separate from the mathematical gaps.

Local preparation, checks and unsigned commits remain authorized. Protected
adoption, publication/push, merge, dispatch, signing, admission and deployment
retain their exact authorization and independent-review boundaries. This packet
grants none. No new stage, verifier, framework, semantics, axiom, Node integration,
SPM work or acceptance policy is introduced. `end_to_end=false` remains required.

## Packet and tracking checks

The packet-copy and documentation/history/link checks exited `0`. All 836 raw
files match. Each uncertainty log retains its exact previous prefix; the separate
U310 update in the shared workspace remains intact. See
[package-readback.json](records/package-readback.json) and
[documentation-check.json](records/documentation-check.json).
The full staged whitespace check exited `2` on preserved raw/generated/upstream
bytes. The listed authored-file check exited `0`. See
[whitespace-check.json](records/whitespace-check.json). No proof record was edited
to remove whitespace. These tracking checks do not establish the open physical,
independent-replay or admission requirements.
