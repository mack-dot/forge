# Slice 2 — spec clearing before a person approves a specification (master idea items F1.1 and F1.3, with F1.2)

Date: 2026-11-18. Branch `slice2/spec-clearing` on `main` `136ad0bf`.
No protected file changed. `end_to_end=false`. CURRENT is none. This is
not a stage. Nothing here is gate evidence: no policy lists these claims
and no gate obligation lists these files. The files are NOT committed
and NOT pushed when this report is written.

Task text and the owner's go-ahead: `unsure.md` U449. Scope approved by
the owner: `Post` and the general lemmas stay hand-written in Dafny for
each specification (the Round 3 decision); new are witness candidates
made by the solver; every candidate must be checked concretely.

## 1. What the tool does

`scripts/spec_clearing.py` starts the pinned Dafny, with the gate's
options, on the Dafny files of one subject, and reads exit codes and
per-member results. It decides no proof. It parses no specification.

| Question | Claim (one Dafny lemma) | Claim proved | Claim rejected and a candidate verified | Otherwise |
| --- | --- | --- | --- | --- |
| Does a specification leave a choice of result? | two allowed results for one input are equal | NO_CHOICE | CHOICE | UNDECIDED or LINK_BROKEN |
| Do an old and a new specification allow the same results? | every pair of allowed results agrees | EQUIVALENT | DIVERGES, with the before and the after result | UNDECIDED or LINK_BROKEN |

A rejected lemma is never a result. UNDECIDED and LINK_BROKEN are never
a pass.

## 2. Mechanism and exact scope

**Post and its link to the specification.** For each specification a
predicate `Post` restates the postcondition of the specified method. It
is written with the specification's own predicates, through an import of
the specification module (for example `R.Eligible` of
`spec/refund/RefundSpec.dfy`), so it uses the same symbols. Dafny proves
the forward link: a method that only calls the specified method ensures
`Post`. So every result that the specification allows satisfies `Post`.

**NO_CHOICE.** Dafny proves the two-run lemma: `Post(x, r1)` and
`Post(x, r2)` give `r1 == r2`. With the forward link, the specification
allows at most one result for every input. A `Post` that is too weak
cannot give a false NO_CHOICE: it can only make the lemma fail. A `Post`
that is too strong breaks the forward link. New in this slice: Dafny
also proves that `Post` is exact (`PostIsExact`: a result that satisfies
`Post` is the result that the specified method returns), and one
concrete accepted input.

**CHOICE.** The witness is not a statement about `Post`. It is two
modules that refine the specification itself. For one concrete input the
first returns one result and the second returns another; for every other
input both do what an honest implementation does. Dafny must verify both
refinements and that the two results differ. So the choice is a choice
of the specification.

**EQUIVALENT.** Both sides have a linked `Post`, a two-run lemma and a
satisfiability lemma. Dafny proves `Agree`: for every input, a result
that the old side allows and a result that the new side allows are the
same.

**DIVERGES.** For one concrete input Dafny proves: every result that the
old specification allows is A, every result that the new one allows is
B, both exist, and A differs from B. A and B are the before/after
example.

**Scope.** NO_CHOICE and EQUIVALENT are universal over the typed inputs
of Dafny's model (unbounded integers, finite maps, sequences, strings)
that satisfy the precondition of the specified method, at source level.
NO_CHOICE is a statement for each refinement of the specification taken
alone; the probe adds that no compiled definition is left open. No bounded search is used anywhere. CHOICE and DIVERGES
are one proved concrete point each. Nothing is said about compiled code.
"No choice" does not mean "matches the intent".

**The instance check (a hole found in this work, section 6).** The
clearing modules are abstract Dafny modules. Inside an abstract module
the pinned Dafny accepts a lemma that has no body, and its audit reports
nothing. So no verdict rests on an abstract module alone: for every
module that holds a required member, the tool writes a non-abstract
module that refines it, with the imports bound to real implementations,
and Dafny must verify that file with exit 0 and an empty audit.

**Four more checks, added after the review (section 6).** (1) Every
audit gets every file that the checked files reach through `include`:
Dafny's audit reports only on the files of its command line. (2) The
word `expect` and the attribute `{:options` are refused in all those
files: an `expect` statement makes Dafny assume a condition without a
proof, and neither the verifier nor the audit reports it. (3) The
specification probe: the tool writes a non-abstract refinement of the
specification with nothing added, and the Dafny compiler must report
"has no body" for exactly the specified methods. A specification that
leaves a compiled function open could get NO_CHOICE while two
refinements differ. (4) EQUIVALENT needs a Dafny proof that the mappings
between the inputs and results of the two sides are one-to-one and onto.

**Candidates.** `solver`: the tool runs Dafny with
`--extract-counterexample` on the rejected claim and reads values from
the printed text. Dafny warns that this text can be invalid. `supplied`:
values or a witness file named in the subject. A candidate of either
kind is a guess. It counts only when Dafny verifies the witness made
from it. The reading of counterexample text is plain text matching; it
can lose a candidate, it cannot make a verdict.

## 3. Results

The unified report, written by the EXIT script from the evidence
record: [records/CLEARING_REPORT.md](records/CLEARING_REPORT.md).

| Subject | Verdict | Acceptance | Verified examples from |
| --- | --- | --- | --- |
| approved ledger specification | NO_CHOICE | ACCEPTS | — |
| approved booking specification | NO_CHOICE | ACCEPTS | — |
| approved refund specification | NO_CHOICE | ACCEPTS | — |
| PLANTED loose refund specification (amount up to the proposed one) | CHOICE | — | solver; supplied |
| PLANTED ledger specification without the frame clause | CHOICE | — | supplied |
| PLANTED vacuous ledger specification | NO_CHOICE | VACUOUS (proved: it accepts nothing) | — |

| Pair | Verdict | Verified examples from |
| --- | --- | --- |
| approved refund specification against a PLANTED cap of half the original charge | DIVERGES | solver; supplied |
| approved refund specification against a PLANTED rewritten variant | EQUIVALENT | — |
| ledger specification before the fee change (commit `c909a640`) against the approved one (a REAL approved change) | DIVERGES | supplied |

The vacuous planted specification shows why a determinism check alone
is not enough: it leaves no choice and accepts nothing. The report gives
acceptance apart.

Solver-made examples hold the numbers that the solver chose (for
example an original charge of 9223372036854775664). They are valid and
proved; they are not chosen to be easy to read. The supplied examples
are small boundary cases (51 of 100).

Hidden effects (item F1.2, reused as it is on `main`): the ledger,
refund and booking gates accept their implementations with
`--track-print-effects` (exit 0 each); the two planted printing
implementations are rejected (gate exit 1 each; checker exit 2 each,
every error is the print-effect error).

## 4. Actual exits

| Check | Actual exit | Result |
| --- | --- | --- |
| `scripts/exit_slice2.py --case choice`, attempts 1 and 2 | 0; 0 | six subjects with the verdicts of section 3; attempt 2 is the code after the review |
| `scripts/exit_slice2.py --case diff`, attempts 1 and 2 | 0; 0 | three pairs with the verdicts of section 3 |
| `scripts/exit_slice2.py --case effects`, attempt 1 | 0 | three gates exit 0; two printing implementations: gate exit 1, checker exit 2 |
| `scripts/exit_slice2.py --case controls`: attempt 1 (9 controls, before the review); attempt 2 (13 controls) | 0; 0 | every control gets its non-pass verdict |
| controls case against copies of the tool with one check removed (one-off): 7 before the review; 11 after | non-zero for 7 of 7; for 11 of 11 | the controls can fail |
| `scripts/exit_slice2.py --case evidence`: attempt 1 (before the review); attempt 2 (final) | 0; 0 | two runs byte-identical each; bundles `134579e3…` (replaced) and `2721a293023baf230ecb944ea3ad2a3c02d7be6d82f128f10d07cc2b0f91854e` |
| scratch clone of `136ad0bf` plus the files of this slice (`run_regression.py`): 28 Stage EXIT cases (Stages 1, 2, 3, 4, 5, 6, 8, 11) | 0 each | 28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, this report; for all 84 Markdown files outside `results/` | 0; 0, 0, 0; 1 | the 2 older Stage 9 links without a target; none new |
| the same clone: `scripts/exit_slice1.py --case evidence` | 0 | Slice 1 bundle `c7f2f41c…`, as on `main` |
| the same clone: `scripts/exit_slice2.py --case evidence` | 0 | bundle SHA-256 equal to the working tree's (`2721a293…`) |
| Stage 7; Stage 9; Stage 10; hosted gate | NOT RUN | Docker time; deferred; no EXIT script on `main`; no pull request when this report was written (expected exit 3) |

Regression record: [records/regression.json](records/regression.json)
(path-free). The Slice 2 files were committed in the scratch clone only,
so that the revision-based checks could see them. After that run only
document files changed; the frozen-gate check and the link checks ran
again on the final documents (`records/links-final.json`).

The final bundle is [records/evidence.json](records/evidence.json). It
holds no time and no absolute path. It names its own class:
`gate_accepted: false`, `policy: null`, method `source_proof` for the
five claims Q1 to Q5. It holds the text of every instance, probe and
witness file that the tool wrote.

## 5. Controls

Thirteen broken clearing inputs, each with the verdict that it must get
(`scripts/exit_slice2.py --case controls`). For the controls marked *
the EXIT script also checks that the control is stopped by its own
check and by nothing before it:

| Control | Verdict | What it shows |
| --- | --- | --- |
| `Post` with a clause that the specification does not have | LINK_BROKEN | a too-strong `Post` breaks the forward link |
| `Post` weaker than the approved refund specification | UNDECIDED | the solver gives two amounts; Dafny rejects the witness, because the approved specification allows only one |
| two-run lemma "proved" by a lemma with NO BODY * | LINK_BROKEN | plain `verify` and `audit` of the file both pass; only the instance reports it |
| two-run lemma "proved" by an `{:axiom}` lemma | LINK_BROKEN | only the audit reports it |
| two-run lemma "proved" by `assume false` | LINK_BROKEN | — |
| the named claim member does not exist | LINK_BROKEN | a file that verifies is not enough |
| supplied choice candidate that the specification does not allow | UNDECIDED | Dafny rejects the refinement |
| supplied before/after example with a wrong `after` | UNDECIDED | Dafny rejects the witness |
| rejected `agree` claim with no candidate | UNDECIDED | a rejection alone is no verdict |
| `{:axiom}` lemma in an INCLUDED file (review F1) * | LINK_BROKEN | `verify` passes; only the audit of the included file reports it |
| forward link that halts at run time in place of a proof (review F2) * | LINK_BROKEN | `verify` and `audit` pass; only the refused word stops it |
| specification with a function that has no body (review F3) * | LINK_BROKEN | claim and instance pass; the probe names the open function |
| rewritten pair with no mapping proof named (review F4) * | LINK_BROKEN | claim and instance pass; EQUIVALENT is refused |

That the controls can fail: eleven copies of the tool with one check
removed each (one-off, scratch tree). The controls case ended with a
non-zero exit for all eleven, each at the control of the removed check:
[records/removed-check-copies.json](records/removed-check-copies.json).
(Before the review: seven copies, seven non-zero exits.)

## 6. Defects found during the work

| # | Found by | Defect | Evidence | Repair |
| --- | --- | --- | --- | --- |
| 1 | build agent, own test | FALSE VERDICT in the first tool: in an abstract module a lemma with NO BODY is accepted by `dafny verify` and `dafny audit`; a two-run lemma "proved" by it gave NO_CHOICE | fixture: verify exit 0, audit 0 findings; a non-abstract instance: audit 1 finding, verify exit 2 | the instance check |
| 2 | review F1 | The audit reports only on the files of its command line; an assumption in an included file gave NO_CHOICE | reviewer's fixtures (4 kinds) | audit of every reached file |
| 3 | review F2 | `expect` in a forward link: no proof, no report; a false `Post` gave NO_CHOICE | reviewer's fixture | the word is refused |
| 4 | review F3 | A specification with a function that has no body gave NO_CHOICE; two refinements differ | reviewer's fixture | specification probe (compiled declarations only; see limit 2) |
| 5 | review F4 | EQUIVALENT did not need a proof that the mappings between the sides are one-to-one and onto; a new input field was not covered | reviewer's fixture | mapping proof required; proved for the shipped pair |
| 6 | review F5 | The result cache did not look at file content; a subject id used twice reused an old pass | reviewer's fixture | cache removed; duplicate ids refused |
| 7 | review F6 | A verdict follows the member NAME in the subject list: one wrong name gave NO_CHOICE for the planted loose specification | reviewer's fixtures with existing files | NOT repaired in the tool (limit 1); the EXIT script now pins the members of the shipped subjects |
| 8 | review M1, M2, M3 | Scope text wider than the lemmas (preconditions); "Post is exact" not checked by the EXIT script; "verified by Dafny" over a description by hand | reading | text corrected; members pinned; examples labelled |

None of the nine shipped verdicts was shown false by the review. The
repairs 2 to 8 were made in one pass after the one review. No second
review ran. Full text and disposition: [REVIEW.md](REVIEW.md).

## 7. Reuse and new work; changes against the 12-line plan

Reused, unchanged, from `proposals/forge2-pillar1-spec-determinism/`:
the `Post` predicates, forward links and two-run lemmas of the three
approved specifications; the fee-change and refund-cap pair files and
their witnesses; the planted no-frame specification with its two
implementations. Reused from Stage 5 and Stage 6: the success witnesses.
Reused from item F1.2: the gate option and the planted printing
implementations.

New: `scripts/spec_clearing.py`, `scripts/exit_slice2.py`,
`clearing/subjects.json`, two witness templates, the exactness files
(`clearing/*Exact.dfy`), the planted loose, rewritten and vacuous
variants with their clearing files, the `Agree` claim files, the old
ledger implementation as a fixture, nine controls.

Changes against the plan that the owner approved:

1. Plan line 4 named a refinement that takes any `Post` result with
   `:|`. Not used. Exactness is proved by a call of the specified method
   and the two-run lemma. A choice is shown by two refinements of the
   specification, which is a stronger witness than one about `Post`.
2. Added: the instance check (section 2). It was not in the plan.
3. Plan line 9 named the Stage 5 vacuous specification as "success
   witness fails". Stronger now: Dafny proves that it accepts nothing.

## 8. Limits

1. The claim lemmas, the `Post` predicates and the forward links are
   hand-written Dafny, per specification. The tool checks that Dafny
   proves them and that the named members exist. It does NOT check that
   a claim lemma states the right claim, or that a forward link calls
   the specified method. The review showed that ONE wrong member name in
   the subject list gives a false verdict (finding F6). For the shipped
   subjects the EXIT script pins the member names. For a new subject a
   person must read the lemma texts and the subject entry.
2. NO_CHOICE is proved for each refinement of a specification taken
   alone. The specification probe detects a compiled function, predicate
   or method without a body. It does NOT detect a ghost function or
   predicate without a body, a constant without a value or an opaque
   type. Such a specification could get NO_CHOICE while two refinements
   differ. The reviewer read the three approved specifications: every
   function and predicate has a body. A proof across two refinements
   would close this; it is not built.
3. The word `expect` is refused, but other statements that weaken a
   method proof without a report were not searched further.
4. No parser and no generator for arbitrary specifications (the Round 3
   decision; item F1.1e is not done). A new specification needs a new
   `Post` file and, for a choice or divergence witness, a template.
5. The reader of counterexample text handles flat records only (the
   refund shape). For the two ledger subjects the candidates are
   supplied by hand; Dafny checks them the same way.
6. A CHOICE or DIVERGES verdict is one point. The tool does not describe
   the whole region of a choice or of a change. The older general
   lemmas of the fee change and the refund cap do, by hand.
7. UNDECIDED is a real outcome: if Dafny cannot prove a true claim
   within the resource limit, or no candidate verifies, the tool says
   UNDECIDED.
8. The hidden-effect check is the gate's check of implementations. A
   specification has no effects to check. Only the print effect is
   exercised by a planted fixture.
9. One machine, one platform (macOS arm64). The hosted gate is expected
   to answer exit 3 (UNSUPPORTED) for these files: no obligation lists
   them. NOT RUN: no pull request exists.
10. The scripts are not proved. One fresh-context review (section 6);
    its repairs were not reviewed again. Three LOW findings of the
    review have no code change (`REVIEW.md`).

## 9. Open decisions for the owner

1. Commit, push and pull request (the agent stops before them).
2. Whether the tool should write the forward link and the claim
   statement itself (limit 1), from a declared method signature.
3. Whether spec clearing becomes a gate step (a proposal for `gate/`).

## 10. Reproduce

```text
python3 scripts/exit_slice2.py --case choice
python3 scripts/exit_slice2.py --case diff
python3 scripts/exit_slice2.py --case effects
python3 scripts/exit_slice2.py --case controls
python3 scripts/exit_slice2.py --case evidence
python3 scripts/spec_clearing.py refund-cap build/slice2/one-subject     # one subject
python3 proposals/forge2-slice2-spec-clearing/run_regression.py <new-clone-folder> <record.json>
```
