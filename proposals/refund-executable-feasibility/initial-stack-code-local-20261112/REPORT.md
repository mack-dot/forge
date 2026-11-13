# U347: initial stack `good_code` proved; initializer has 14 premises

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
This packet completes the stopped U314 proof under the owner's approval of the
local M1 actions (see U345). No hosted action, native execution, publication
or protected edit occurred.

## Result

The exported theory `forge_refundInitialStackCode` holds five checked theorems:

| Theorem | Statement |
| --- | --- |
| `refund_word_postalloc` | The exact compiled word program satisfies the allocation and register conventions |
| `refund_word_labels` | The exact word labels are distinct, above the reserved stub labels and internally valid |
| `refund_stack_lowering` | The exact stack program equals the published word-to-stack compilation result |
| `refund_initial_stack_good` | `good_code` holds for the exact initial stack program |
| `refund_initialization_code` | 14 conditions imply initializer success and the conditional stack/lab semantics equality |

U313's validated claim had 15 conditions. This result discharges the initial
stack `good_code` condition. The other 14 conditions are unchanged and open:
`memory_assumption`; link register not in `save_regs`; two `save_regs`
conditions on `target_io_regs` and `target_cc_regs`; alignment of `dm` and
`sdm`; three `find_name ... ∈ save_regs` conditions; five `find_name ... =`
register-mapping conditions. Physical applicability is not established.

## Diagnosis of the U314 failure

U314 recorded a `FIRST_ASSUM` failure and named a hidden word-type mismatch
as a hypothesis. The prescribed typed-goal diagnostic gives the actual causes:

1. The statement has no type variables. The word-type hypothesis is false.
2. `drule specialized_convs` passes. `drule specialized_labels` fails. The
   published theorem's antecedent holds a `let labs = extract_labels p in ...`
   form. The goal's assumption has the expanded form. The two do not match.
3. After that repair, the `EVERY (λn. 5 ≤ n)` sub-proof fails: `metis_tac` had
   no arithmetic facts for the two stub labels 5 and 6. The last step also
   fails, because `fs` rewrites the bound with the label-list equation.

## Actual results

All commands ran in `results/refund-initial-stack-code-local-20261112/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_stack_case.py diagnose-0001 diagnose-0001.sml` | 0 | Typed states. `drule-labels` is the failing step. No type variables. No theorem. |
| `python3 -I -B run_stack_case.py diagnose-0002 diagnose-0002.sml` | 0 | `LET_THM` expansion makes `drule-labels` pass. `bound` and `final` fail. No theorem. |
| `python3 -I -B run_stack_case.py diagnose-0003 diagnose-0003.sml` | 0 | Goal manager proves the lemma. Rest of script gives `REMAINING_ANTECEDENTS 14` in-process. Nothing exported. |
| `python3 -I -B run_stack_case.py code-0004 code-local-0004.sml` | 0 | Five `CHECKED` theorems; `REMAINING_ANTECEDENTS 14`; `RUNTIME_PROOF_COMPLETE`; four exports. |
| `python3 -I -B run_stack_case.py repeat code-local-0004.sml` | 0 | Same markers; four exports byte-identical to `code-0004`. |
| `python3 -I -B run_stack_case.py audit expected.sml code-0004 forge_refundInitialStackCode` | 0 | Prepared U314 audit. Five exact statements; 14-premise contract; theorem count 5; `TRACE_IMPORT_COMPLETE`; 484 closure nodes; four Boolean axioms. |
| `... wrong-lowering wrong-lowering.sml code-0004 forge_refundInitialStackCode` | 1 | After the positive audit: `Exact statement mismatch: refund_stack_lowering`. |
| `... duplicate-label duplicate-label.sml code-0004 forge_refundInitialStackCode` | 1 | After the positive audit: `prove` of `good_code` for two entries with label 5 ends with `unsolved goals`. |
| `... missing-memory missing-memory.sml code-0004 forge_refundInitialStackCode` | 1 | After the positive audit: `prove` of the claim without `memory_assumption` ends with `unsolved goals`. |
| `python3 -I -B validate_stack_evidence.py` | 0 | Separate reader binds hashes, exits and markers of the six cases. |
| Reader control: copy with an acceptance marker added to one control stream | 1 | Reader rejects the altered copy. |
| Lower-pass transitions (U298); physical premises; independent replay | NOT RUN | Separate obligations. |

The three diagnostics exit 0 because the scripts end with a normal exit. They
are not proof passes. No control printed `UNEXPECTED_CONTROL_ACCEPTANCE`.
A control that ends with `unsolved goals` shows that the prepared tactic does
not prove the altered claim. It is not a proof that the altered claim is false.
The reader's first draft required a source line number for each control
exception. That criterion was wrong for helper and library raise sites. It
was replaced by the marker-order criterion before the reader's first run.

## Candidate change

[code-local-0004.sml](records/code-local-0004.sml), SHA256
`7d24953dea9a70a51db26a4ee7c6b858d692a9a5cd84fecf5a86544ff5871c6f`.
[Diff against U314's code-numeric.sml](records/candidate.diff)
(`f3e2be7884bd6ee005de790179859e1858bad7e8862901e59c3709be7c8acb11`):

1. `specialized_labels`: `LET_THM` added to the `SIMP_RULE` list.
2. The bound fact is stated pointwise, `∀k. MEM k (MAP FST stack_prg) ⇒ 5 ≤ k`,
   and proved with `fs`, `rw`, `res_tac`. The label-list equation is then
   removed from the assumptions.
3. Final step: `fs [EVERY_MEM,FORALL_PROD,MEM_MAP,PULL_EXISTS] >> rw[] >> res_tac >> fs[]`.

All six quoted goal statements are byte-identical to U314's source. The
script's own tag check is unchanged: no hypotheses, no tagged axioms,
`DISK_THM` only. No axiom, `cheat` or new oracle.

Prepared U314 inputs, byte-identical and bound by the U314 manifest:
`expected.sml` `edea761f3a3f69c30bb86df1388dfda08fe2e286291cb353ebcc549ed6c851ba`,
`wrong-lowering.sml` `482e2170427445eaa0d8b9c2a046d26bfe378ec801d869659798977c12421d09`,
`duplicate-label.sml` `a43e328befa89012271eeb8584cf7ec486380a2214ff453977cefea64b37f43a`,
`missing-memory.sml` `293fab448fa44054d8b388bfe323955f4745ab73c435a4ae31feab125f27e5e4`.

## Identities and resources

HOL revision `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`; CakeML commit
`cd9155694c16831373ab695a670794f23282ed62`; CakeML heap SHA256
`36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`. The argv
prefix, cwd and two parent theories (U312, U313 exports) come from U314's
recorded `code-0003/command.json`. All checked inputs match before and after
every case. Limits per child: CPU 600 s, wall 900 s, zero core dumps. U314
used a CPU limit of 3600 s; the lower limit was sufficient. No timeout.

| Case | Wall s | Child CPU s (user + system) | Max RSS bytes |
| --- | --- | --- | --- |
| code-0004 | 178.994 | 171.611 + 69.160 | 2369142784 |
| repeat | 294.713 | 186.487 + 98.659 | 2440232960 |
| audit | 289.670 | 208.081 + 131.364 | 2119974912 |
| wrong-lowering | 94.152 | 100.519 + 22.653 | 2182905856 |
| duplicate-label | 85.273 | 87.725 + 24.634 | 2311618560 |
| missing-memory | 94.014 | 111.087 + 21.650 | 2529067008 |

The repeat and the audit ran at the same time; their wall times include that.

Exports of `code-0004` and `repeat`:

- `.hol/objs/forge_refundInitialStackCodeTheory.dat` `76a5b0379933b2c30ece7a004dd0ab61aed9f68d650d95615d425b04b3980aed`
- `.hol/objs/forge_refundInitialStackCodeTheory.sig` `feefe3a3e97896fb9174940b02de6af9f1f95916f1577c994bddc9e100cad0e4`
- `.hol/objs/forge_refundInitialStackCodeTheory.sml` `d2691bfb479729ce460a03e9d2472b38fb31b05be3611dd1aa1b9d11f10f49d0`
- `.hol/docs/forge_refundInitialStackCodeTheory.html` `e66e8a04e7a90587d0a3d1c9b0cad7b70372e76398dd51475c6bc8f8306eedd4`

## Assurance

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Five theorems, exact prepared statements | LOCALLY_VALIDATED | Proof, repeat and fresh audit exit 0. Same machine, cached parents and saved states. |
| Initializer reduced from 15 to 14 conditions | LOCALLY_VALIDATED | Prepared 14-premise contract check passes. |
| Reproducible export | TESTED | Two runs give four byte-identical files. |
| Three prepared controls | TESTED | Each passes the positive audit, then rejects. |
| Dependency closure | TESTED locally | 484 theory nodes, four standard Boolean axioms. No fresh kernel replay of the parents. |
| The 14 remaining conditions for the physical process | NOT_ESTABLISHED | Explicit premises. |
| Lower-pass transitions and U298 target-prefix condition | NOT_ESTABLISHED | Not attempted here. |
| Independent replay; M1 | NOT_ESTABLISHED | Separate obligations. |

## Limits

Same machine and same agent for production and readback. Parent theories and
saved states are cached producer artifacts. The reader checks bytes, exits and
markers only and must run at the results path. Attempt count for the generic
composition: U314 recorded one failing proof attempt after a separate numeric
construction failure; this packet adds three diagnostics and one passing
proof. No failing `prove`/`store_thm` attempt was added.

## Next check

Justify the lower-pass transitions and establish U298's condition for every
formal target `TimeOut` prefix. Then assess the 14 remaining conditions and
the entry, memory, resource, FFI and OS rows of the
[runtime matrix](../runtime-premises-20261104/CORRESPONDENCE.md).
