# Refund source/model binding: local checked proposal

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
This record supersedes U293's next-action status, while preserving its failures.
The source export now succeeds with a proposed change to the existing frontend.
HOL checks the exported AST's complete result and its relation to both the
existing method model and the `refund_fields` function used by the compiler proof.
The frontend remains unverified. Physical executable correspondence remains open.

## Established link and limits

The exact, unchanged FlatCore source exports to 3,621 bytes. The published
`mlsexp.parse` and `sexp_to_dafny.to_program` functions decode those exact bytes
under HOL evaluation. The proof requires an empty parser remainder. The checked
method has all nine typed inputs, all six typed outputs and all three ensures
clauses. Its empty frame remains explicit; the proof establishes an unchanged
heap. No source contract was removed from the accepted input.

Seven new theorems span three theories. Each theory reproduces four exports byte
for byte. Fresh processes import the exact statements with no explicit hypotheses
or extra tagged axioms. This is same-host rebuild and import, not independent
full-chain replay or independent review. The closure union contains 195 theory
nodes and 964 hashed theory files. The only declared closure axioms are the four
existing HOL Boolean foundations: SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX.
The built-in `min` root and exact heap are recorded separately.

| Theory/theorem | Precisely checked claim |
| --- | --- |
| SourceBinding.source_decode | Exact export bytes parse completely to the bound program |
| SourceBinding.source_signature | Exactly one AssessFlat method; nine typed inputs and six typed outputs; source body and contracts retained |
| SourceBinding.source_full_result | For every typed model input and arbitrary heap/environment, return status, unchanged heap and all six outputs match `eligible` |
| SourceBinding.source_postconditions | The actual three parsed postconditions all evaluate to true in the final state |
| SourceBinding.mapped_operators | Existing Boolean equality implements equivalence; string Eq/Neq implement string equality/inequality |
| SourceRelation.source_model_result | Parsed source method and original constructed method agree on return status, final heap and all six outputs under their explicit initializers |
| CompiledInputBinding.source_compiled_fields | The parsed method's six outputs equal the exact `refund_fields` tuple used by the existing compiler theorem |

Full theory names start with `forge_refund`. Exact statements and proof scripts:
[source proof](records/proof-0004.sml), [model relation](records/relation.sml),
[compiler-input relation](records/bridge.sml). The fresh source import also checks
the exact source-text and initializer definitions, for seven imported statements.

The initializer supplies all nine named, typed locals, six uninitialized output
locals, an arbitrary heap, and the other fields from the published `init_state 0`.
This is a whole method result relation for these initializers. It is not arbitrary
contextual equivalence, equivalence of every internal state, or a physical machine
theorem. The model has mathematical integers and byte strings. The result covers
all such typed inputs, including rejected inputs; it does not narrow the accepted
source specification to a finite test corpus.

U262's existing UTF-8 transport proof remains separate. Connecting its full Dafny
Unicode domain to this frontend and the model representation still needs explicit
justification and independent review. The source proof used Dafny 4.11.0; this
frontend fork declares 4.10.1. The new result does not silently bridge that version
or representation boundary. The C# serializer and source parser are not kernel
verified by these proofs. A correct AST result alone cannot prove that its
unverified producer preserved every source-language meaning.

## Proposed frontend change

[One-file patch](frontend/frontend.patch), [upstream source](frontend/Bake.upstream.cs),
[proposed source](frontend/Bake.proposed.cs). The patch changes only Bake.cs:

- Accept one concrete named leaf module inside an otherwise empty default root.
  Reject extra compiled modules, executable siblings and additional declarations.
  Check module kind, facade/refinement fields, attributes and root includes.
- Map resolved Boolean Iff to the existing Eq constructor.
- Map resolved SeqEq/SeqNeq to Eq/Neq only for two string operands.
- Encode a literal finite empty frame set as the existing empty frame list.
  Nonempty sets still fail. This preserves the empty-frame constraint.

The original two-module example path stays available. The unchanged published
example exports identical bytes before and after this patch. Its named-module
version now exports those same bytes. Six separate unsupported-form controls fail
with exit 1 and no export. These controls support this proposal; they are not a
universal proof that every unsupported source construct fails closed. Upstream's
warning about incomplete feature checking remains relevant.

The upstream checkout is unchanged. The experimental worktree has one tracked
source modification and six untracked dependency lock files. The latter match
the prior captured locks. Build commands used RestoreLockedMode=true. The existing
NuGet signature-verification limitation remains: no authenticated package-producer
claim follows from these local hashes. No accepted toolchain was replaced.

## Actual execution results

Every exact argv, working directory and observed duration is in
[COMMANDS.md](COMMANDS.md). Raw experiment:
`results/refund-source-binding-2026-11-04/attempt-0002/`.
These are local executions. Prior U293 and U291 results remain prior executions.

| Executed check | Actual exit | Result |
| --- | --- | --- |
| Frontend builds 1 / 2 / 3 | 0 / 0 / 0 | Incremental proposal builds |
| Exact-source exports 1 / 2 / 3 | 1 / 1 / 0 | SeqNeq limit; empty-frame limit; complete export |
| Exact-source export repeat | 0 | Identical bytes in a separate CLI process |
| Upstream / named example | 0 / 0 | Both match the prior upstream export |
| Six unsupported-form exports | 1 each | Intended module/frame/type refusal; no export |
| Source HOL attempts 1 / 2 / 3 / 4 | 1 / 1 / 1 / 0 | API error; syntax error; missing computation registration; five checked theorems |
| Source proof repeat / fresh exact import | 0 / 0 | Four equal exports; seven exact statements imported |
| Model relation / repeat / import | 0 / 0 / 0 | One exact relation; four equal exports |
| Compiler-input relation / repeat / import | 0 / 0 / 0 | One exact relation; four equal exports |
| Five adversarial HOL cases | 1 each | Intended binding or theorem refusal; no complete export |
| Identity and outcome readback | 0 | Closure, artifacts, prior packet manifests and 50 protected paths match |
| Native or hosted refund execution | NOT RUN | No new runtime or hosted claim |
| Complete independent replay, signing, admission | NOT RUN | Local imported objects do not establish these links |

The first three positive HOL failures are retained. Attempt 1 passed the pair
returned by `dest_inr` where a term was needed. Attempt 2 had a missing closing
list bracket. Attempt 3 left new definitions opaque to computation. Attempt 4
registered those definitions with the existing HOL computation library. No axiom,
new semantics or replacement proof checker was introduced. U290's separate
entry-layout route stays stopped at five attempts.

| Adversarial input | Actual export / HOL exit | Checked rejection reason |
| --- | --- | --- |
| Accepted amount changed to amount + 1 | 0 / 1 | source_full_result leaves `amount + 1 = amount` |
| Output charge/request fields swapped | 0 / 1 | source_full_result leaves `request = charge` and its converse |
| First two formal input identities swapped | 0 / 1 | source_signature fails; residual false |
| Ensures clauses removed in a separate fixture | 0 / 1 | source_postconditions fails; residual false |
| Extra bytes after the exact export | Not applicable / 1 | Explicit `Trailing export bytes` refusal |

These are intended proof/binding refusals. Export success alone never counts as
verification. They are not release-admission tests or universal counterexample
theorems. The original FlatCore and its contracts remain unchanged.

## Exact identities

| Artifact | SHA256, unless identified as a commit |
| --- | --- |
| Frontend upstream commit | `6eb1ed63544a2e22c151db9b575f4308b8f329b0` |
| Frontend upstream tree | `ab2b12b545d8b6e725c47ac067f8c07705a47bd6` |
| Original FlatCore | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` |
| Proposed frontend patch | `df88831bcc41bb19b3148aed5f69332cde0e626e33d21538da8ef4f4dbf04a6a` |
| Proposed Bake.cs | `565edacde7b6612eab0d916ed4d642245e1533a61da261993ca6bc1242a6232b` |
| Built proposed DafnyDriver.dll | `55d26351d36b660ac6b1ea6eac7515cc4b15bc9a5f139f375a1a9e6f90455acb` |
| Exact exported AST text | `58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d` |
| Source proof script | `a79edc4b607d40963661882fc926f71914724c742f96865832417111a4416d07` |
| SourceBindingTheory.dat | `6f30ff5d62bf416b9c837eb2184bdd3ee1b1cac30e34e5fc9f8b72b667d812f3` |
| SourceRelationTheory.dat | `19cd87a38e5fdca3bc6055225a3d878524337fc4f3ece864a0d5814d9f2f54dd` |
| CompiledInputBindingTheory.dat | `937d10bbb0aa62379be980788114847c7efd90c13b2baa1e9fa90271c0472519` |
| HOL/CakeML heap | `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247` |
| Unchanged native refund | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

Full file identities, closure and recorded exits are in
[readback.json](records/readback.json). CakeML commit:
`cd9155694c16831373ab695a670794f23282ed62`; HOL commit:
`9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
SDK 8.0.111 / runtime 8.0.11 / osx-arm64; existing Z3 4.12.1.
The source-built driver's version display is 0.0.0.0; use exact identities above.

Proof, relation and compiler-input rebuild times were respectively
166.523684417 / 206.032492958, 7.718894084 / 2.789895958, and
7.067698459 / 7.450822708 seconds. Exact unrounded observations are in the ledger.
Concurrent load differs. These are not comparable cold/warm benchmarks and support
no speedup claim. Hosted time, billed runner-minutes and cache reuse are NOT RUN.
The nondeterministic process sample remains in the raw experiment only; it is not
a reproducible proof artifact. It was not deleted or used as correctness evidence.

## Remaining assurance links and next action

| Required link | Status and exact gap |
| --- | --- |
| Approved refund contract to source transport | Prior U262 evidence retained; no specification change |
| Exact source text to exported AST | OBSERVED deterministic export; unverified frontend and source-language version boundary remain |
| Exported AST to method result | PROVED under the stated typed model initializer |
| Result to existing compiled function | PROVED for all six fields; same `refund_fields` as U291 |
| Full Unicode representation relation | Prior transport proof exists; exact frontend/model/native composition still NOT_ESTABLISHED |
| Compiled model behavior | Prior U291 conditional theorem; resource-limit prefixes remain allowed |
| Applicable concrete installed state | NOT_ESTABLISHED; code/data identity alone does not prove frames, permissions or complete ARM control state |
| Runtime and exit semantics | FFI, OS, interference, resource sufficiency and physical termination remain explicit assumptions or missing obligations |
| Independent assurance authority | Full-chain independent replay/review, approved claim/profile and authenticated new evidence/admission remain open |
| Exact independent-device recovery | Owner reported a backup; required archive digests and restore from that copy remain NOT VERIFIED |

The smallest next local check is to inspect and bind the exact representation
relation between U262's UTF-8 source transport and the published byte-string model.
Reuse the existing library theorems. Preserve full integer/Unicode inputs and all
six outputs. Do not infer this relation from the ASCII literals in this example.
Prepare its precise claim and use the existing kernels; no new decoder or semantics.
Do not retry U290's stopped route or restart completed compiler jobs.

The separate frontend review packet is ready: one exact patch, retained source,
six locks, exact export, seven theorems, all positive and negative logs, and full
identity records. Independent review must address module selection, empty frames,
operator meaning, version compatibility, unsupported-feature behavior and package
provenance. Approval must name this exact patch and its intended trust scope before
any protected adoption. Neither hashes nor this report authenticate the producer.

Local documentation and unsigned commits are authorized. Publication, push, merge,
workflow dispatch, signing, accepted profile/policy changes, admission and deployment
retain their separate authorization requirements. No such action occurred here.
No protected file changed. Remote branch protections and PR state were not refreshed;
prior exports remain historical. Keep the proof-report upload repair separate.

Verdict: the new AST/result links are **PARTIALLY_ESTABLISHED** within the overall
assurance chain. M1 and integration EXIT remain **NOT_ESTABLISHED**.
`end_to_end=false`. No Stage12, Node integration, SPM change or cross-run trust change.
