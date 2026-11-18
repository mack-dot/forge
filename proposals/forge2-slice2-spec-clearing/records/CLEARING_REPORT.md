# Spec clearing report (Slice 2)

Written by `scripts/exit_slice2.py` from its evidence record. Not gate evidence. `end_to_end=false`.
Pinned Dafny `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2`, gate options with `--track-print-effects`.

## 1. Choice left to an implementation

| Subject | Verdict | Acceptance | Example |
| --- | --- | --- | --- |
| approved ledger specification | NO_CHOICE | ACCEPTS | — |
| approved booking specification | NO_CHOICE | ACCEPTS | — |
| approved refund specification | NO_CHOICE | ACCEPTS | — |
| PLANTED refund specification that lets the amount be anything up to the proposed one (fixture) | CHOICE | NOT_SHOWN | solver (values in the verified witness): input `ChargeContext("c", "r", 9223372036854775664, 9223372036854775344, true, true), Candidate(9223372036854766330, "duplicate_charge")`; result one `Authorized(2411, "duplicate_charge")`; result two `Authorized(1641, "duplicate_charge")`<br>supplied (values in the verified witness): input `ChargeContext("ch_1", "rq_1", 100, 60, true, true), Candidate(40, "duplicate_charge")`; result one `Authorized(40, "duplicate_charge")`; result two `Authorized(39, "duplicate_charge")` |
| PLANTED ledger specification without the frame clause (three balance equations, nothing about other accounts) (fixture) | CHOICE | NOT_SHOWN | supplied (description of a hand-written verified witness): input `balances {0:1, 1:2, 2:2, 3:4, 4:0}, request 7: account 3 sends 3 to account 1`; result one `balances {0:2, 1:5, 2:2, 3:0, 4:0}`; result two `balances {0:2, 1:5, 2:0, 3:0, 4:2}` |
| PLANTED ledger specification whose two validity predicates are `false` (the Stage 5 vacuous fixture) (fixture) | NO_CHOICE | VACUOUS | — |

## 2. Hidden effects (F1.2)

| Check | Gate exit | Checker exit | Result |
| --- | --- | --- | --- |
| `python3 gate/gate.py --impl impl/Ledger.dfy --evidence <work>/ledger.json` | 0 | — | ACCEPTED: C1 C2 C3 C4 C5; backend=dafny; tier=critical; end_to_end=false |
| `python3 gate/refund.py --tier critical --evidence <work>/refund.json` | 0 | — | ACCEPTED: R1 R2 R3 R4 R5; source_proof; end_to_end=false |
| `python3 gate/booking.py --evidence <work>/booking.json --work <work>/booking-work` | 0 | — | ACCEPTED: B1 B2 B3 B4; source_proof; end_to_end=false |
| `python3 gate/gate.py --impl bugs/print_effect.dfy --evidence <work>/print-bug-1.json` | 1 | 2 | to use a print statement, the enclosing method must be marked with {:print} |
| `python3 gate/gate.py --impl bugs/print_effect_marked.dfy --evidence <work>/print-bug-2.json` | 1 | 2 | to call a method with print effects, the enclosing method must be marked with {:print} |

## 3. Before and after a specification change

| Pair | Verdict | Example |
| --- | --- | --- |
| approved refund specification against a PLANTED variant with a cap of half the original charge | DIVERGES | solver (values in the verified witness): input `ChargeContext("c", "r", 9223372036854771465, 4611686018427386293, true, true), Candidate(4611686018427385733, "duplicate_charge")`; before `Authorized(4611686018427385733, "duplicate_charge")`; after `Rejected`<br>supplied (values in the verified witness): input `ChargeContext("ch_1", "rq_1", 100, 100, true, true), Candidate(51, "duplicate_charge")`; before `Authorized(51, "duplicate_charge")`; after `Rejected` |
| approved refund specification against a PLANTED variant with the same rules in other words | EQUIVALENT | — |
| ledger specification before the fee change (commit c909a640) against the approved one: a REAL approved change | DIVERGES | supplied (description of a hand-written verified witness): input `balances {0:0, 1:5, 2:0}, request 7: account 1 sends 5 to account 2`; before `Ok, balances {0:0, 1:0, 2:5}`; after `Rejected, balances {0:0, 1:5, 2:0}` |

## 4. Controls: broken clearing inputs

| Control | Verdict |
| --- | --- |
| CONTROL: Post has a clause that the approved refund specification does not have | LINK_BROKEN |
| CONTROL: Post is weaker than the approved refund specification; the solver's two amounts are not both allowed | UNDECIDED |
| CONTROL: the two-run lemma is "proved" by a call of a lemma with NO BODY (accepted by verify and audit of the abstract module alone) | LINK_BROKEN |
| CONTROL: the two-run lemma is "proved" by a call of an {:axiom} lemma with no body (no warning from verify) | LINK_BROKEN |
| CONTROL: the two-run lemma is "proved" by `assume false` | LINK_BROKEN |
| CONTROL: the named claim member does not exist in the files (every file verifies) | LINK_BROKEN |
| CONTROL: a supplied choice candidate for the planted loose specification whose second amount is ABOVE the proposed one | UNDECIDED |
| CONTROL: a supplied before/after example for the cap pair with a wrong `after` (50 of 100 is at the cap; the variant still authorizes it) | UNDECIDED |
| CONTROL: the cap pair with no candidate at all: a rejected `agree` claim alone must not become a verdict | UNDECIDED |
| CONTROL (review F1): the two-run lemma is "proved" by an {:axiom} lemma of ANOTHER, included file; an audit of the claim file alone reports nothing | LINK_BROKEN |
| CONTROL (review F2): the forward link checks a false Post at run time and halts, in place of a proof; verify and audit report nothing | LINK_BROKEN |
| CONTROL (review F3): an honest Post and two-run lemma for a specification with a function that has NO BODY; two refinements can differ | LINK_BROKEN |
| CONTROL (review F4): the rewritten pair, with no proof named that the mappings between the two sides are one-to-one and onto | LINK_BROKEN |

## 5. What a verdict means

- **NO_CHOICE.** Universal: for every typed input in the Dafny model that satisfies the precondition of the specified method (unbounded integers, finite maps, sequences and strings), each refinement of the specification allows at most one result, and the specification leaves no compiled function, predicate or method without a body except the specified method. Source level. No bounded search. Not checked: ghost definitions without a body, constants without a value, opaque types.
- **CHOICE.** One concrete input, proved: two modules that the pinned Dafny accepts as refinements of the specification return different results for it. Nothing is said about other inputs.
- **EQUIVALENT.** Universal: for every typed input in the Dafny model, the two specifications allow the same result. Inputs and results of the two sides are matched by mappings that Dafny proves to be one-to-one and onto (the mapping members named in the subject). Source level. No bounded search.
- **DIVERGES.** One concrete input, proved: every result that the old specification allows and every result that the new one allows are the two stated results, and they differ. Nothing is said about other inputs.
- **UNDECIDED.** No statement. The claim was not proved and no candidate was verified.
- **LINK_BROKEN.** No statement. A clearing input itself did not pass (a link from Post to the specification, an instance, the audit of a reached file, a refused word, the specification probe, or a mapping proof).

## 6. Assumptions

- Dafny mathematical integers, finite maps, sequences and strings; source level only. No statement about compiled code, a running program or a deployed artifact.
- "No choice" and "equivalent" are statements about results (next state, outcome; decision, plan). They do not show that a specification matches the intent of a person.
- Post is written by hand for each specification, with that specification's own predicates. The forward link (every result of the specified method satisfies Post) and, where the two-run lemma holds, exactness are proved by Dafny.
- Every verdict rests on a non-abstract instance that the tool writes, checked with an empty Dafny audit of every file that it reaches: an abstract module alone accepts a lemma without a body, and the audit reports only on the files of its command line.
- NO_CHOICE is a statement for each refinement of a specification taken alone. The compiler probe shows that the specification leaves no compiled function, predicate or method without a body except the specified method. A ghost definition without a body, a constant without a value or an opaque type in a specification is NOT detected.
- The tool does not check that a hand-written claim lemma states the right claim or that a forward link calls the specified method. This script pins the member names of the shipped subjects; a person must read the lemma texts.
- A concrete example is one point. It does not describe the whole region where two specifications differ.
- Planted variants are fixtures. They are not approved specifications and not proposed changes.
