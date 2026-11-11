# Refund oracle checkpoint — U304

CURRENT stage: **none**. Active milestone: **M1**. Stage 12 is unauthorized.
`end_to_end=false`. M1 and integration EXIT: **NOT_ESTABLISHED**.

This is a partial evidence checkpoint for the [mission tracker](../../../FORGE_MISSION_STATUS.md#current-execution-checklist).
The goal remains the full approved refund R1–R5 integer/Unicode behavior for
the exact executable. The fixed RISC-V example remains supporting evidence.

## Latest observed result

The existing `oracle-0001` HOL run finished with actual exit `0` and its completion
marker. This documentation step read back that completed result. It did not
launch another proof run. The run exported three claims:

- `refund_word_oracle_binding`: the exact compilation's data/word oracle equation.
- `refund_data_oracle_labels`: the reserved-label bound for future data programs.
- `refund_exact_oracle_single_epoch`: a conditional composition with the selected
  oracle, compiler aliases and frame expression.

The combined claim still contains **13 antecedents**, including the oracle
equation and future-label bound. The first two exported lemmas have not yet
removed those conditions from the combined statement. The count changed from
U303's 16 after instantiation and simplification. It does not establish that
three physical assumptions were proved. Exact claim validation remains pending.

The [source](records/oracle-0001/proof.sml), [full printed claims](records/oracle-0001/stdout.log),
[child command and exit](records/oracle-0001/command.json), and
[byte-identity readback](records/checkpoint-readback.json) preserve the result.
Hashes bind these local bytes. They do not authenticate the producer.

## Execution record

| Check | Actual exit / status | Meaning |
| --- | --- | --- |
| Completed HOL `oracle-0001` | 0 | Three claims exported; 13 antecedents remain |
| Documentation checkpoint readback | 0 | U303's 535 members match in both copies; four exports and 28 imported files match recorded hashes |
| Oracle repeat and byte-identical reproduction | NOT RUN | Required before accepting the new checkpoint as reproduced |
| Fresh exact-statement import and full premise audit | NOT RUN | Required for the combined claim |
| New oracle substitution / omitted-premise controls | NOT RUN | No adversarial success claimed |
| Independent full-chain replay, native/hosted execution, admission | NOT RUN | No new assurance at these boundaries |

The recorded local duration is `84.69368404199486` seconds. It is not a hosted
runner measurement or a performance comparison. The captured command record
includes the exact child argv, heap digest, CPU limit and imported identities.

Exact prior launch, from `/Users/mackianni/forge`:

```sh
python3 -B results/refund-word-oracle-2026-11-05/attempt-0001/run_composed.py \
  oracle-0001 results/refund-word-oracle-2026-11-05/attempt-0001/oracle.sml \
  space-parent:forge_installSpaceBarrier trace-parent:forge_spaceInstallTrace \
  word-parent:forge_compilerWordTrace data-parent:forge_refundDataBehavior \
  refund-parent:forge_refundWordPremises init-parent:forge_refundWordInitialization \
  epoch-parent:forge_refundInitializedEpoch
```

That case directory already exists. Preserve it. A later repeat must use a new
case name. The raw directory retains all parent objects and pinned sources;
this checkpoint captures the result and dispatcher, not a standalone full replay
environment. U303 contains the preceding checked proof packet.

## Next completion criteria

- [ ] Normalize and apply the exact oracle equality and label lemma to the
  combined theorem. Use the existing checked ARM8 width fact and tuple/list
  equalities. Keep all remaining compiler, input, memory, space and pointer
  conditions explicit. Do not weaken the theorem to obtain a smaller count.
- [ ] Check the complete expected statement and every remaining premise in a
  fresh HOL import. Audit the dependency and assumption closure.
- [ ] Repeat the proof. Compare exported bytes. Reject a substituted oracle
  and a claim with a required premise removed for their intended reasons.
- [ ] Only then advance the combined oracle-binding checklist item. Continue
  through lower compiler passes toward U298's target-prefix condition.

No physical initialization, resource sufficiency, target event correspondence,
or OS/FFI relation follows from this checkpoint alone. U290/U297 remain stopped.
Independent source interpretation review, complete replay, authenticated new
claims and independent admission remain open. Other-device archive hashes and
restore are unverified. Effective GitHub protections were not refreshed here.

## Exact identities and authority

| Item | SHA-256 / commit |
| --- | --- |
| Baseline local commit | `14adbc4b91a3c594444e1e7a840e51a8a38ed2f6` |
| Proof source | `9d6675cb5cc7470021d4ccd0574b272aee34c6a8855883e86fd9cfc0d2208419` |
| New theory data | `f071e42cd31449a117260be34117f36eb15c5e9c53ff2b16c9d5dbcb3a2a1f51` |
| Exact refund native artifact | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| U303 manifest | `c115fd24cf7f6918fbd30c3d3f5322c669595705b82614982118c9ddaa2ba75e` |

This is local tracking and evidence preservation. It grants no authority for
protected adoption, publication, push, merge, dispatch, signing, admission or
deployment. M2–M4 remain subsequent milestones. No Stage 12, Node, SPM or
general infrastructure work is introduced.

## Documentation checks

The tracking-step history, linked-file and authored-whitespace check exited `0`.
It preserved the old roadmap sections and each uncertainty log's complete byte
prefix. Workspace and Git worktree histories remain distinct. See the
[check record](records/documentation-check.json). This is documentation validation,
not an additional theorem check.

The full staged whitespace check exited `2` on the captured HOL-generated
`.sig` and `.sml` files. Their exact bytes are preserved. The authored-document
check exited `0`. [Full diagnostics](records/full-staged-whitespace.json) remain
separate from proof results.
