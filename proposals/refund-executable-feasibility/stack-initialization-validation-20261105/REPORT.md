# Exact refund stack-initialization validation — U307

CURRENT stage: **none**. Active milestone: **M1 — executable behavioral correctness**.
Stage 12 remains unauthorized. `end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

## Result

The U306 checkpoint now passes its local acceptance checks. A fresh HOL import
checked all four claims and equivalence of the complete eight-condition contract.
A fresh proof run reproduced all four exported files byte for byte. Three controls
refused substituted or unsupported claims for their intended reasons. The original
successful proof source and theorem exports did not change during validation.

The active objective remains the full approved refund R1–R5 integer/Unicode
behavior for the exact executable. This conditional model result closes three
compiler/initializer premises. It does not establish the full executable claim.
See the [mission checklist](../../../FORGE_MISSION_STATUS.md#current-execution-checklist).

| Claim | Established local model fact |
| --- | --- |
| `refund_stack_gc` | The exact modeled initializer supplies the required GC function |
| `refund_stack_store` | Its store, memory domain and buffers satisfy `init_store_ok` |
| `refund_stack_compiler` | Its compiler field matches the exact lower-pass compiler composition |
| `refund_stack_initialized_single_epoch` | Under eight retained conditions, the word trace has one epoch for every clock |

The [successful proof](records/init-0007/proof.sml), [full statements](records/init-0007/stdout.log),
[expected statements](records/expected-map-delete.sml), and [fresh import](records/exact-import-0001/stdout.log)
fix the precise claims. U305's eleven conditions become eight by applying the
three checked helper lemmas. No source input domain, R1–R5 rule, semantic model,
resource requirement or physical assumption was weakened.

## Complete retained contract

The exact lower-pass constructors are fixed in the source. The following eight
conditions remain in the imported combined theorem:

| Condition | Status |
| --- | --- |
| `STD_streams fs` | Required model input premise |
| `wfFS fs` | Required model input premise |
| `wfcl cl` | Required model input premise |
| Exact canonical nine-field refund request in stdin | Required source/input binding |
| Nonempty initialized stack | Required model-state premise |
| Stack-state endian equals the chosen data configuration | Required model-state premise |
| `data_lang_safe_for_space` for the exact data code, limits and stack size | Resource adequacy NOT_ESTABLISHED |
| All-clock pointer-oracle evaluation relation | Still a premise; exact fixed-point specialization NOT RUN |

The imported theorem has no explicit hypotheses or new tagged axioms. The audit
checks all eight premises, not only their count. It proves their complete logical
equivalence after kernel normalization. The three helper statements match under
the stated definitions. The exact conclusion also matches.

**Successful model initialization and physical initialization remain separate.**
The published `make_init_any` supplies a fallback if `make_init_opt` fails. It can
use an empty memory domain and a synthetic stack. Facts about `FST(full_make_init)`
do not alone establish `IS_SOME(SND initial)` or any physical loader relation.
The new control rejects that added conclusion. This is claim-binding refusal,
not a counterexample proving the initialization claim false.

Likewise, one word-trace epoch excludes successful modeled Install events only.
It does not by itself exclude all attempted target InstallApp transitions or
establish [U298's all-prefix condition](../target-install-bridge-20261105/REPORT.md).
The complete physical memory, runtime, FFI, OS and interference relations remain open.

## Executed checks

Exact child argv, CPU limits, heap and imported identities are in each command
record. [COMMANDS.md](COMMANDS.md) lists those records and executed child commands.

| Check | Actual exit(s) | Interpretation |
| --- | --- | --- |
| Historical proof bundles1–7 | 1/1/1/1/1/1/0 | All failures preserved; final four-claim export succeeds |
| Historical bitmap diagnostic | 0 | Preserved diagnostic, not an additional theorem |
| Fresh complete-statement import | 0 | Four claims and all eight premises checked |
| Fresh proof repeat / byte comparison | 0/0 | Four identical exports |
| Substituted compiler | 1 | `Exact statement mismatch: refund_stack_compiler` |
| Unsupported successful-initialization conclusion | 1 | `Exact conclusion mismatch: unsupported_initializer_success` |
| Omitted resource condition | 1 | Premise-equivalence proof leaves `data_lang_safe_for_space` unproved |
| `readback.py` | 0 | Exact results, closure, dependencies, pins and prior evidence checked |
| Independent clean full-chain replay, native/hosted run, signing/admission/restore | NOT RUN | No new result at these boundaries |

Every negative case first passed the complete positive audit. No infrastructure
error is counted as a security rejection. Failed proof attempts do not establish
universal behavioral counterexamples. These are local model/claim controls, not
receipt-authentication tests or an admission decision.

Before the new import, one finite-map deletion token was corrected in a new audit
file. The earlier unexecuted draft remains. No proof changed. One read-only source
lookup used the wrong directory and exited2; the corrected `rg --files` lookup
exited0. The earlier documentation-path and text-diff errors remain preserved.
The compiler and composition proofs each passed on their third actual proof
attempt. No failing proof exceeded five attempts. U290/U297 remain stopped.

## Identity, reproducibility and trust

| Item | Exact identity |
| --- | --- |
| Baseline local commit | `743ed9ccca9c3be05b5465a2582cb65d2f093e85` |
| Successful proof source SHA-256 | `9fc5478364027e06ca8b35185f4ec08f6735c5133876815325b3bd2b2b75fcb6` |
| Theory data SHA-256 | `3d4b6a2e096f81ea8762a4d8ece4f4bea12621cc10a841124597dc8e4b7f1cc6` |
| Expected statement source SHA-256 | `1417d45bab08f19e5291d14fba8030bb5774c4cac761b39b7065ec24b983adbd` |
| Exact unchanged native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| CakeML commit | `cd9155694c16831373ab695a670794f23282ed62` |
| HOL commit | `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` |

The closure has **490 theory nodes** and **2427 hashed dependency files**.
Only the four existing Boolean foundations remain: `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, and `BOOL_CASES_AX`. Same-host cached `DISK_THM` imports still form a
trust boundary. This is not clean independent source replay or authenticated
evidence production. Artifact hashes establish identity, not producer authority.

The readback checks 11 pinned source snapshots, 50 protected files,
3162 prior packet members, mission bytes and unchanged toolchain tracked trees.
U306's checkpoint and all earlier evidence remain unchanged. Raw results remain
at `results/refund-stack-initialization-2026-11-05/attempt-0001/`.

Local elapsed durations are recorded in command JSON. Hosted runner-minutes,
performance savings and fresh native/hosted behavior are **NOT RUN**. The faster
repeat duration alone does not establish a performance improvement.

## Smallest next work and authorization

The existing `ptr_eq_fix_thm` can supply a pointer witness only after its prefix
and constructor-oracle independence conditions are established. The backend's
published proof shows that route; no new semantics or verifier is needed.
Next, specialize those existing congruence lemmas to this exact constructor and
apply the fixed-point theorem without dropping a premise. Preserve the remaining
source, resource and state conditions. This specialization is **NOT RUN** here.

Then use the published `full_make_init_semantics` conditions to justify successful
initialization before lower-pass event composition. That theorem retains memory,
register, code, alignment and oracle requirements. The current result does not
discharge them. [Pinned-source inspection](records/next-link-inspection.json)
records the exact next obligations. No stopped proof route is reopened.

Source interpretation review, independent full-chain checking, physical
correspondence and a newly approved/authenticated claim and admission profile
remain open. The owner reports a backup on another device. Exact archive hashes
and a restore test there remain unverified. Effective GitHub protections were
not refreshed in this run.

Local experiments, proposals and unsigned commits remain authorized. Protected
adoption, publication, push, merge, dispatch, signing, admission and deployment
retain their existing approval limits. Stage12 remains unauthorized. M2–M4,
Node integration, SPM and general infrastructure remain outside this work.

## Packet validation

Documentation history, local links and captured-byte validation exited `0`.
Both existing histories and each uncertainty log's exact old prefix remain.
See [documentation-check.json](records/documentation-check.json). The full staged
whitespace check exited `2` on exact raw/generated/upstream files. The authored
check exited `0`; those evidence bytes were not rewritten. See
[whitespace-check.json](records/whitespace-check.json).
