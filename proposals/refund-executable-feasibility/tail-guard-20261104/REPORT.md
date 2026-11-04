# Refund guard and actual prefix binding

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
The actual wrapper continuation now has a checked rejection theorem. The
unchanged guard-removal mutation is refused. This closes a conditional guard
obligation from U264. It does not establish whole-program or native correctness.

## Exact established boundary

`refund_tail_expr` is extracted from the actual `refund_main_v` declaration.
The proof uses the published CakeML `evaluate` semantics. For every nonempty
remainder, arbitrary modeled reference store and FFI state, it raises
`Fail "refund: trailing input"` and preserves those stores, under its explicit
environment and clock32 entry conditions. The checked rejection branch contains
no refund call or output operation.

The entry supplement checks the actual application of `refund_main` to unit.
Its body has the exact `openStdIn → inputSexp → inputAll → guard` prefix.
It constructs the resulting namespace after those calls return their values,
including the recursive binding, argument, temporary, stream, parsed value and
remainder. The required equality function, remainder and `Fail` constructor
lookups hold in that namespace. The guard theorem then applies to it.

This is conditional on the prefix calls returning those values. It does not
prove their stream/heap contract, establish that actual stdin reaches this
state, guarantee physical termination, or establish the empty-remainder path.
Clock32 is a model evaluation budget, not an elapsed-time bound. The theorem
does not restrict the approved refund input domain.

## Commands and actual results

Raw directory: `results/refund-tail-guard-2026-11-04/attempt-0001/`.
Run the Python dispatchers there with `python3 -B`. Each attempt records exact
child argv, working directory, input hashes, exit code and local wall time.
Use a new attempt name when reproducing. Do not overwrite prior evidence.

| Executed command/check | Actual exit | Result |
| --- | ---: | --- |
| Initial declaration inspection | 1 | Wrong theory qualifier for an existing error predicate; preserved |
| Exact equality/error lookup inspection | 0 | Actual closure and constructor identified |
| `run.py 0001` / `run.py 0002` | 1/1 | Manual interruption of broad namespace/expression expansion; child signal2 each |
| `run.py 0003` | 1 | Wrong `getOpClass_def` theory qualifier; no theorem accepted |
| `run.py 0004` | 0 | Guard theorem checked using existing semantic rules and namespace conversions |
| `run_controls.py` | 0 | All four required child outcomes matched |
| Mutant parent / unchanged guard proof | 0/1 | Old partial proof still exports; new guard theorem fails |
| Original parent restored / guard repeat | 0/0 | Parent restored exactly; six guard exports reproduced |
| `run_entry.py entry-0001` | 1 | Manual interruption in large closure expansion; no complete entry theory accepted |
| `run_entry.py entry-0002` | 0 | General call lemma, actual prefix, namespace and rejection relation checked |
| `run_entry_controls.py` | 0 | Substitution1 and repeat0 matched required outcomes |
| Replaced actual remainder binding with empty string | 1 | Fails `refund_actual_prefix_lookups`; unsolved `rest = ""` |
| Entry repeat | 0 | Six byte-identical exports |
| `run_gap.py cf-gap` / `run_gap.py cf-gap-repeat` | 0/0 | Raw CF match-value premise is impossible; six identical exports |
| Fresh HOL theorem/closure inspection | 0 |231 imported theory nodes; eight own theorems; zero own hypotheses |
| Record/source/postflight validation | 0 | Intended failure reasons, repeats and30 unchanged protected inputs checked |

The original guard-removal source is unchanged: only `if rest = "" then`
became `if true then`. Its original U264 exit0 remains preserved. The new
theorem refuses that source at `refund_tail_rejects`; no accepted guard theory
is exported. This is a formal-check refusal, not a native runtime experiment.
The new remainder-substitution control exercises the additional entry binding.
Neither required negative outcome was changed to match an observation.

## Identities and trust

Unchanged wrapper source SHA256:
`44ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22`.
Guard source SHA256:
`e64a19a8ea3f63fc4c6a4f1c1d045bdc630756866cc16940c8c80ff57189aad2`.
Guard theory data SHA256:
`4e94b435a244814c62fe87730a1fdea5b716e31fc1b21c7165d5f3a7df4c244d`.
Entry source SHA256:
`669b13bbb65cd7004bf6bab437d955f09c6cafccfdd8ffd3e40b3e0b2797d9ff`.
Entry theory data SHA256:
`4bbd481738df083a0fd905b7ded5a6dc8508b51c44222f612b84d7f8ed06844e`.
CF applicability source SHA256:
`aef2ded5f125be31c99abad57e51769dee271d2ee260302941f5336d89ec04db`.
Its theory data SHA256:
`1212f1830466a2756de7fe9de19e175d7153c3cc29acbd2de1a135e26afb54da`.

CakeML remains at `cd9155694c16831373ab695a670794f23282ed62`; HOL4 remains at
`9783a49979c94c401ff8c0e51b2eefae7ea95ae3`. The tracked trees are unchanged.
The closure contains the existing `SELECT_AX`, `INFINITY_AX`, `ETA_AX` and
`BOOL_CASES_AX` foundation axioms. No new axiom or checker was introduced.
Imported `DISK_THM` remains explicit. Source replay and digest checks do not
make arbitrary imported data self-authenticating. There is no new independent
human review or newly authorized provenance/admission claim.

Exact sources, logs, failed attempts, commands, exports, closure statements
and the pinned upstream applicability sources are in this packet. Saved proof
heaps and all parent exports remain in the raw directory. No history was deleted.
Earlier packets remain unchanged. The local dispatchers still use the recorded
workspace/tool paths; a clean independent developer reproduction is not claimed.

## Checked method-proof obstacle

The first match discriminant is extracted from the exact generated method.
The kernel proves `exp2v env refund_raw_discriminant = NONE` for every
environment. Thus the `cf_match` premise requiring `SOME v` cannot hold for
that raw expression. This is a proof-rule applicability finding, not a refund
behavioral violation. Fixing the earlier Boolean allocation tactic alone would
not finish the direct CF proof. The four failed raw-method attempts remain.
Do not spend the fifth attempt repeating that route without addressing this fact.

The pinned `cfNormaliseLib` can produce a value-form candidate, but its source
explicitly states that normalization is unverified. Its API returns syntax,
not a semantic-preservation theorem. The old `full_normalise_correct` text is
inside a commented implementation. It is not an available proved bridge.
Normalization has **NOT RUN**, and the actual wrapper/method is unchanged.

The next local experiment may use that existing normalizer only as an untrusted
candidate transformation. It must independently prove the full refund result
for the exact produced method and a checked observable-result relation to the
original method. Keep all integers, Unicode representations, reasons, rejected
cases and caller identities. A normalizer output or a successful CF setup is
not acceptance. Do not transfer the old theorem by assumption.

## Remaining chain

Method behavior in the library heap/frame, prefix stream execution, accepted
output, source/model representation binding and native compilation remain open.
Then exact installed bytes, compiler/resource premises, FFI, assembler, linker,
loader and host conditions must be bound. Physical input delivery and EOF must
be explicit if the eventual executable reads an entire stream.

Native refund execution, hosted measurements, new signing and admission are
**NOT RUN**. Independent claim/profile approval and exact off-machine archive
hash/restore verification remain separate. The owner's report of another-device
backup is retained. GitHub controls were not refreshed in this iteration.
No publication, merge, workflow dispatch, deployment or Stage12 action occurred.

Verdict: **PARTIALLY_ESTABLISHED** for the local conditional guard/prefix chain;
**NOT_ESTABLISHED** for M1 and the complete executable claim. `end_to_end=false`.
