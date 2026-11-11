# Refund initialization checkpoint — U312

CURRENT stage: **none**. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. M1/integration EXIT: **NOT_ESTABLISHED**.

The objective remains the full approved refund R1–R5 integer/Unicode behavior
for the exact executable. The fixed RISC-V example supplies supporting evidence.
M2 admission, M3 reuse and M4 usability remain later priorities.

## Current result

The recovered `success-0002` HOL process exited `0`. It exported three conditional
model claims. It proves that the exact modeled initializer succeeds when its
17 remaining conditions hold. It also gives stack/lab semantics equality when
the stack semantics does not fail. It does not prove physical applicability.

This is a checkpoint awaiting complete local validation. The latest completed
pointer/word-trace validation remains [U311](../pointer-witness-validation-20261105/REPORT.md).
The Markdown tracking step read terminal records and checked bytes. It did not
run a new proof, native process, hosted job or release operation.

| Claim in `forge_refundSuccessfulInitialization` | Scope |
| --- | --- |
| `refund_lab_code` | Exact compiled lab code equals the published stack-to-lab compilation of the exact refund stack program |
| `refund_lab_oracle` | Exact lab oracle is the published compiler transform of the corresponding stack oracle |
| `refund_initialization_sufficient` | The 17 conditions imply `SND initial <> NONE` and conditional stack/lab semantics equality |

The [source](records/success-stackname.sml) uses the existing
`backendProof.full_make_init_semantics2` theorem. Exact code/oracle identities
and the word-width, minimum-register and stack-allocation arithmetic checks are
discharged. No theorem, specification, machine semantics or axiom is changed.
The [printed statement](records/success-0002/stdout.log) controls interpretation.

## Remaining initialization conditions

The count is the 17 top-level antecedents printed by the successful HOL run.
The variables below are those in its exact statement; physical values have not
been supplied or proved to satisfy these conditions.

| No. | Retained condition | Status |
| --- | --- | --- |
| 1 | Published `memory_assumption` for the exact bitmaps, `data_sp` and constructed lab state | NOT_ESTABLISHED for physical state |
| 2 | Target link register is outside `save_regs` | Retained premise |
| 3 | Saved registers are preserved by `target_io_regs` | Retained premise |
| 4 | Saved registers are preserved by `target_cc_regs` | Retained premise |
| 5 | Every address in memory domain `dm` has `w2n x MOD 8 = 0` | Retained premise |
| 6 | Every address in shared-memory domain `sdm` has the same alignment | Retained premise |
| 7 | Exact initial stack program satisfies published `good_code` | Retained compiler premise |
| 8 | Every future stack-oracle program satisfies `good_code` | Retained compiler premise |
| 9 | Mapped register `stk` belongs to `save_regs` | Retained premise |
| 10 | Mapped register `3 + stk - 2` belongs to `save_regs` | Retained premise |
| 11 | Mapped register `4 + stk - 2` belongs to `save_regs` | Retained premise |
| 12 | Mapped register4 equals `mc.len2_reg` | Retained premise |
| 13 | Mapped register3 equals `mc.ptr2_reg` | Retained premise |
| 14 | Mapped register2 equals `mc.len_reg` | Retained premise |
| 15 | Mapped register1 equals `mc.ptr_reg` | Retained premise |
| 16 | Mapped register0 equals the target link register | Retained premise |
| 17 | The configured register-name map permutes all register names | Retained configuration premise |

`memory_assumption` is a separating memory-layout relation. It includes pointer
register contents, exact bitmap storage, code-buffer fields, aligned regions,
region bounds and available data/heap words. Matching selected constructor fields
does not establish it. The theorem's success conclusion rules out the synthetic
fallback only under these retained conditions.

The semantics conclusion also retains stack non-failure. Final semantics equality
does not establish [U298's every-prefix installer exclusion](../target-install-bridge-20261105/REPORT.md).
Resources, source interpretation, FFI/OS and physical execution correspondence
remain separate open requirements of the full refund claim.

## Actual commands and failures

| Check | Actual exit | Result |
| --- | --- | --- |
| `inspect-0001` | 0 | Printed published initializer premises; diagnostic only |
| `success-0001` | 1 | Type error before the new proof; loaded byte-code constant captured `code` |
| `success-0002` | 0 | Renamed free variable to `stack_prg`; three claims and 17 antecedents |
| First / corrected checkpoint byte readback | 1 / 0 | Corrected reader includes stderr; original failure preserved |
| Fresh full-contract import / closure audit / repeat / new controls | NOT RUN | Pending validation |
| Independent full-chain replay, native/hosted run, admission, restore | NOT RUN | Complete assurance remains open |

[COMMANDS.md](COMMANDS.md) gives exact executed commands, numeric exits and logs.
The first proof attempt changed no semantics: its tuple used `code`, which
resolved to the already loaded byte-code constant. Renaming the intended free
stack-program variable fixes that type error. The first attempt remains intact.
The initial missing-filename inspection error is also preserved. None of these
script errors counts as an adversarial rejection. U290/U297 remain stopped.

The source checks that the three results have no explicit hypotheses or new
tagged axioms. A fresh full-statement and dependency-closure audit is still
required. The cached parent theories are not an independent full-chain replay.
No successful negative control or reproducible rebuild is claimed for U312.

## Exact identities

| Item | Value |
| --- | --- |
| Baseline local commit | `edd406a059cb9d50bc54d5fe351820ea06cacf95` |
| Proof source SHA-256 | `f23025a1323792e064f44d42725beaa16ba987057d7df6bf6d638cba881a452a` |
| Theory data SHA-256 | `267cc49251967655092dcc2c250fbbcbc985dc0d6465a4a878b9173146798f3b` |
| Existing native artifact SHA-256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Successful local proof wall seconds | `89.81102383302641` |
| Hosted runner-minutes / performance comparison | NOT RUN |

[Readback](records/checkpoint-readback.json) confirms four export files, 11 pinned
source files, 50 protected paths, mission/native identity, and 843 prior U311
packet members in each copy. The native hash identifies an existing artifact;
this new conditional theorem alone does not certify its physical behavior.
Local timing is an observation, not evidence of hosted cost or savings.

## Next executable work and approval boundary

1. Discharge available static configuration and code conditions with existing
   compiler theorems. Preserve every physical memory/register/environment premise.
2. Check all three complete statements and remaining premises in a fresh import.
   Audit dependency closure. Rebuild and compare exact export bytes.
3. Test omitted memory/layout conditions and substituted code/oracle identities.
   Require intended rejection after the unchanged positive check succeeds.
4. Connect lower-pass execution to the full target-prefix condition. Do not infer
   transition correspondence from final-output equality.

Physical applicability, independent review/replay and new authenticated
provenance/admission remain open. The owner reports a backup on another device;
exact archive hashes and a restore from that copy remain unverified. Effective
GitHub protections were not refreshed by this tracking step.

Local checks, proposals and unsigned commits remain authorized. Protected
adoption, publication/push, merge, dispatch, signing, admission and deployment
retain their exact approval boundaries. This checkpoint grants no new authority.
No new stage, infrastructure, Node integration or SPM work is introduced.

## Tracking integrity

Documentation/link and packet-byte checks exited `0`. All 43 raw files match.
Both uncertainty logs retain their complete previous prefixes, including the
separate workspace U310 record. [Readback](records/documentation-check.json).
The full staged whitespace check exited `2` on preserved generated proof bytes;
the authored-file check exited `0`. [Exact record](records/whitespace-check.json).
Those raw files are not edited to change a formatting result. This tracking
validation does not discharge any pending proof or operational requirement.
