# Exact refund oracle composition validated — U305

CURRENT stage: **none**. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. M1 and integration EXIT: **NOT_ESTABLISHED**.

The exact compiler oracle equation and future-program label bound now discharge
their premises in the refund word-trace theorem. The combined result retains
11 explicit conditions. It does not establish physical execution or close M1.
The full approved refund R1–R5 integer/Unicode behavior remains the target.

## Checked change and claim boundary

[Final proof source](records/oracle-final.sml) exports three claims in
`forge_refundWordOracle`: `refund_word_oracle_binding`,
`refund_data_oracle_labels`, and `refund_exact_oracle_single_epoch`.
They use the existing exact ARM8 compilation and published CakeML proofs.
No new verifier, machine semantics, axiom, source implementation or executable
was introduced. The exact [printed theorem](records/oracle-0003/stdout.log)
and [expected statements](records/expected-qconv.sml) preserve the full contract.

U303 had 16 antecedents. Selecting the exact oracle and the defined compiler/frame
aliases first left 13. That count reduction instantiated definitions; it did not
prove physical conditions. The corrected composition then discharges the oracle
equality and future-label bound using the two checked lemmas. Eleven remain:

| Group | Required conditions still present |
| --- | --- |
| Source/environment — 4 | Exact canonical request on stdin; `wfcl`; `wfFS`; `STD_streams` |
| Input stack — 1 | Nonempty input stack |
| Memory/store — 1 | `init_store_ok` for the supplied store, memory/domain and buffers |
| Resources — 1 | Exact data program is `data_lang_safe_for_space` for the modeled limits and frame sizes |
| GC/endianness — 2 | Supplied GC function and endian field match the exact configuration |
| Compiler function — 1 | Supplied stack compiler gives the exact data-to-target compiler function |
| Pointer behavior — 1 | All-clock evaluation equation for the supplied pointer representative oracle |

Under these conditions, the exact initialized word program has one
`ptr_eq_trace` epoch at every clock. This excludes successful modeled Install
events in that trace. It does not prove target `InstallApp` exclusion, physical
no-install behavior, resource sufficiency or a complete executable guarantee.
The error-input source branch and physical/runtime correspondence remain separate.

## Executed checks

| Command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Original `oracle-0001` — previously recorded | 0 | Historical 13-premise result preserved in U304 |
| First normalization / diagnostic / corrected proof | 1/0/0 | One retained label premise identified and discharged |
| Corrected proof repeat / byte comparison | 0/0 | Four identical exported files |
| Fresh import attempts 1–3 | 1/1/0 | Two normalization-helper failures preserved; final full contract accepted |
| Substituted compiler information | 1 | Exact oracle statement mismatch |
| Omitted pointer premise | 1 | Required evaluation relation remains an unsolved goal |
| `python3 -B records/readback.py` — recorded raw invocation | 0 | 489 theory nodes; 2424 dependency files; exact input/output identities |
| Native/hosted execution, independent full-chain replay, admission, off-machine restore | NOT RUN | No new result at these boundaries |

The first corrected composition attempt had 12 conditions. Its guard rejected
that result. The diagnostic showed that `o_DEF` expanded the projection inside
the label lemma but not the target premise. Applying the same tuple/list form
without that unrelated expansion discharged the label bound. The original oracle
equation was already discharged. No premise was deleted by an unchecked operation.

The first import accepted the oracle equation, then raised HOL `UNCHANGED` on an
already-normalized term. `TRY_CONV` did not handle that exception. The pinned
[HOL implementation](records/upstream-HOL/src/1/Conv.sml) identifies `QCONV` as
the correct wrapper: it returns a kernel reflexivity theorem for unchanged terms.
The third import passed. The proof source and objects did not change during
these audit-helper corrections. All failures remain. No proof exceeded five
attempts. U290/U297 stay stopped.

The fresh import checks both helper statements after kernel normalization.
It checks the combined conclusion and proves equivalence of all 11 premises.
All three claims have zero explicit hypotheses and no new tagged axioms. The
closure retains the four existing Boolean foundations: `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, `BOOL_CASES_AX`. Cached same-host imports are not independent full-chain
source replay, producer authentication or release admission.

The negative cases test exact claim binding and premise preservation. Their
failures are not physical counterexamples or admission decisions. The source
oracle substitution changes the expected compilation information while keeping
the checked proof fixed. The second control removes exactly the pointer premise
and leaves all ten other conditions intact. It cannot validate the stronger claim.

[COMMANDS.md](COMMANDS.md) records exact child argv, exits, source digests and
local elapsed times. Parent records are historical dependencies, not new runs.
Two incidental source/status lookups used the wrong directory; their records are
preserved separately. They are not proof or security-test results.

## Exact identities and reproducibility

| Item | SHA-256 / commit |
| --- | --- |
| Continuation baseline | `546fd3d9ebe9cc1b198df7b43b5509241d5e0230` |
| Final source | `c140f5bb6ec9e9bb870e575b4cd3322f58d3b84c6901bb7c10c564c544edd335` |
| Final theory data | `59661a42b226b7bb15c5ddbe427d0d7f274ae6e653bde59706844f10a9b156c9` |
| Exact unchanged refund native artifact | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| CakeML | `cd9155694c16831373ab695a670794f23282ed62` |
| HOL | `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` |

[Readback](records/readback.json) binds nine pinned CakeML sources, the inspected
HOL conversion source, 50 protected files, 2164 prior packet members,
mission bytes and the native artifact. Tracked toolchain trees are unchanged.
The U304 checkpoint and its manifest remain unchanged. The final theory has a
new digest; its name alone must not identify a trusted claim.

All HOL runs used the recorded pinned heap and existing CPU limit. They ran
serially. Four exports reproduce byte for byte. Local elapsed times are recorded
observations, not hosted runner costs or a claim of savings. Reproduction needs
the exact toolchain and parents; use new case directories to preserve old runs.

## Next smallest authorized action

Instantiate the remaining compiler function with the published lower-pass
initializers. Use `stack_to_labProof.full_make_init_compile` and the exact
`backend_from_data_tuple_cc` definition. Apply the existing `IMP_init_store_ok`
lemma where its stated conditions hold. Keep any resulting machine-entry,
memory, resource and pointer conditions explicit. Then connect word events
through the remaining passes to U298's target-prefix condition.

Do not infer physical applicability from a defined model state. The U296 runtime
matrix, source interpretation review and complete independent replay remain open.
Other-device archive hashes and restore remain unverified. Effective GitHub
protections were not refreshed. Those operational controls are separate from
mathematical premises.

## Approval boundary

This is a local review packet. Review the exact statements, assumption closure,
artifact binding, failed attempts, controls and reproducibility before protected
adoption. New claim/profile approval, publication, push, merge, dispatch, signing,
admission and deployment retain their authorization limits. No Stage 12, Node,
SPM, cross-run evidence reuse or general infrastructure work is introduced.
M2–M4 remain subsequent milestones. A local commit does not authenticate or
approve this new assurance claim.

## Packaging checks

Copied-record identity, Markdown links and append-only history checks passed
with exit `0`. All 531 raw files match. Full staged whitespace exited `2` on
preserved upstream, generated and raw-log bytes. Authored whitespace exited `0`.
No evidence bytes were normalized. [Diagnostics](records/packaging-check.json)
preserve both results. The tracker and roadmap retain their separate histories.
