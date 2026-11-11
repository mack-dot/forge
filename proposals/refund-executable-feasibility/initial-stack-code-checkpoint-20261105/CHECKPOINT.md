# Exact initial stack-code proof: incomplete checkpoint

CURRENT stage: **none**. Stage12 remains unauthorized. Active milestone: M1.
M1 requires the full approved refund R1–R5 integer/Unicode behavior for the exact
native executable. `end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

The [U313 validation](../initialization-static-validation-20261105/REPORT.md)
remains the latest completed initialization result. Its 15 conditions remain.
This checkpoint preserves an incomplete attempt to discharge the initial stack
`good_code` condition. It does not establish a 14-condition initializer theorem.
No new HOL, native or hosted execution ran during this Markdown tracking step.

## Actual recorded results

| Recorded command/check | Actual exit | Result |
| --- | --- | --- |
| `code-0001` HOL bundle | 1 | Word allocation conventions saved; label theorem leaves goals |
| `code-0002` HOL bundle | 1 | Three helpers saved; arithmetic tactic construction fails at `DECIDE` |
| `code-0003` HOL bundle | 1 | Three helpers saved; combined proof fails at `FIRST_ASSUM` |
| `checkpoint.py` byte audit | 1 | Incorrect comparison between distinct historical checkouts |
| Correction preparation / premature script invocation | 1 / 2 | Missing local cache file; corrected script not yet created |
| `checkpoint-complete.py` byte audit | 0 | 96 raw files preserved; prior packet and input identities checked |
| New complete import, closure audit, reproducibility and negative controls | NOT RUN | No completed new theory exists to validate |
| Independent full-chain replay, native/hosted run, admission, other-device restore | NOT RUN | Separate assurance requirements remain open |

[COMMANDS.md](COMMANDS.md) gives the exact recorded child commands, working
directories, exit codes and local durations. The original command records and
logs are copied without edits under [records/](records/).
The three failed bundles have no completion marker and no new theory exports.
Partial in-process helper results are not independently imported or adopted.

## What the partial proof establishes, and what it does not

The second and third logs record three in-process helper proofs:

| Helper | Intended relation checked before the later bundle failure |
| --- | --- |
| `refund_word_postalloc` | Exact compiled word program satisfies allocation/register conventions |
| `refund_word_labels` | Exact word labels are distinct, above reserved stub labels and internally valid |
| `refund_stack_lowering` | Exact stack program equals the published word-to-stack compilation result |

The first label proof left the `n > 6` versus `6 < n` form unresolved. The second
source uses the published `GREATER_DEF`; that helper then completes. Its later
numeric decision calls fail during tactic construction. The third source adds
explicit natural-number types. The next failure is inside `stack_good_from_word`
at `Tactical.FIRST_ASSUM`. The recorded error does not identify which `drule`
failed. A hidden word-type mismatch is a hypothesis, not an established cause.

The proposed `refund_initial_stack_good` and `refund_initialization_code` are
not reached. The proposed reduction from 15 to 14 premises is **NOT_ESTABLISHED**.
The [latest source](records/code-numeric.sml) and all earlier variants remain.
The [expected-contract audit](records/expected.sml) and three negative scripts
are drafts only. Their expected outcomes are not actual test results.

The label proof completes on its second attempt. The generic composition has
one executed failing proof attempt after the separate numeric-construction
failure. Preserve these counts. Do not exceed five attempts per failing proof.
U290 and U297 remain stopped; this checkpoint does not reopen either route.

## Smallest next executable check

1. Print the typed goal, assumptions and specialized theorem at each `drule`
   boundary in a new diagnostic copy. Identify the exact failed match.
   The published backend source explicitly warns that `asm_config` no longer
   determines the word type of `data_to_word.compile`; this is a relevant clue,
   not proof of the present failure's cause.
2. Change only the demonstrated mismatch. Preserve exact compiler identity,
   reserved-label bounds and all physical/resource premises. Keep prior failures.
3. If the complete theory exports, run the prepared complete-statement and
   14-premise audit. Audit its assumption/dependency closure. Repeat the proof
   and compare exported bytes. Run substitution, duplicate-label and missing-
   memory controls. Each control must pass the positive audit and reject for
   the intended reason. A script error is not a security rejection.
4. Continue to saved-register/memory applicability and lower-pass transitions.
   Establish U298's condition for every formal target TimeOut prefix. Final
   output equality and finite observations do not establish that condition.

## Retained conditions and separate blockers

The validated initializer retains: `memory_assumption`; link-register exclusion
from saved registers; saved-register preservation by I/O and calls; alignment
of memory and shared-memory domains; initial-stack `good_code`; three saved-
register memberships; and five register-name equalities. Its semantics equality
also requires stack non-failure. These 15 premises are not the complete M1
assumption count. Source, pointer, resources, FFI and OS conditions remain.

Physical applicability, the complete target-prefix relation, independent full-
chain checking/review, and new authenticated provenance/admission remain open.
The fixed RISC-V ELF work is supporting evidence; it does not replace the refund
behavioral claim. The separate U310 exception/FFI work and its history stay intact.

The owner reports a backup on another device. Exact required archive hashes and
a restore from that independent copy remain unverified. Current effective GitHub
protections were not queried in this tracking step. No new operational success
is inferred from historical reports.

Local proposals, safe checks and unsigned commits remain authorized. Protected
adoption, publication/push, merge, dispatch, signing, admission and deployment
retain their exact approval boundaries. No Stage12, policy/specification change,
new verifier/semantics/axiom, Node integration or SPM work is introduced.

## Exact identities and evidence integrity

| Identity | SHA-256 or commit |
| --- | --- |
| Baseline documentation commit | `05a6596db5c147739c74b42d3df0c7fb38bd60b1` |
| CakeML source commit | `cd9155694c16831373ab695a670794f23282ed62` |
| HOL source commit | `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` |
| Latest incomplete source | `f3e2be7884bd6ee005de790179859e1858bad7e8862901e59c3709be7c8acb11` |
| Existing native artifact | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Prior U313 manifest | `2a90d498eadab7a921ab4d3532c992aeef9587eaa072763410a6eb90a9d48907` |

[Checkpoint readback](records/checkpoint.json) verifies 18 pinned sources against
the recorded CakeML commit, all 208 prior U313 members in both local copies and
Git, imported parent bytes, proof sources/logs, mission identity and native bytes.
It verifies 50 workspace protected paths against the workspace baseline. The
46 tracked protected worktree paths match the documentation baseline commit.
The check preserves the different checkout identities; it does not normalize
them or change protected files.

The first audit wrongly required both checkouts to match the workspace hashes.
The first correction also tried to read a workspace-only cache file from the
worktree. These audit failures are [preserved](records/checkpoint-preparation-failures.json).
The corrected audit checks each checkout against its own prior identity. This
is a byte-preservation check, not fresh mathematical verification or authenticity.

Local recorded proof durations are 71.38255620797281, 78.40941337498953 and
74.95361033300287 seconds. Hosted runner-minutes and speedup measurements:
**NOT RUN**. Failed proof bundles supply no performance-improvement claim.

## Tracking checks

Documentation/history/link checks exited `0`. Each uncertainty log retains
its exact original prefix, including the separate workspace U310 history.
Full staged whitespace check: `2`. Authored-file check: `0`.
Preserved raw source/log formatting is not rewritten. See the
[documentation](records/documentation-check.json) and
[whitespace](records/whitespace-check.json) records.
