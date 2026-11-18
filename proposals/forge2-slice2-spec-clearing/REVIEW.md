# Slice 2 — the one fresh-context adversarial review of the clearing tool

Date: 2026-11-18. One background agent with no context of the build
session. It could read the repository and run probes in a scratch
folder. It changed no repository file. Its target was the first
complete version of `scripts/spec_clearing.py`, `scripts/exit_slice2.py`,
`clearing/subjects.json`, the templates and the new Dafny files (nine
controls at that time; evidence record `134579e3…`).

Section 1 is the reviewer's final text, saved by the build agent. Two
path prefixes are replaced: the scratch folder is `<scratch>/`, and
paths inside the repository are relative. Nothing else is changed. The
line numbers are those of the reviewed version. Section 2 is what the
build agent did with each finding, by the owner's rule (text C in
`OWNER_TEXTS.md`): repair confirmed FAIL-OPEN, HIGH and MEDIUM findings
in one pass; leave LOW items and the two stated limits. No second
review ran. A review that finds nothing more is not a proof.

## 1. The reviewer's report (verbatim, paths replaced)

```text
# Adversarial review of Slice 2 "spec clearing": findings

I changed no repository file. All fixtures are under `<scratch>/review-slice2/` (below: `S/`). Each fixture ran through the REAL `clear_spec` / `clear_pair` / `instance_check` of `scripts/spec_clearing.py`, with a `Tool` whose work folder is in scratch and absolute fixture paths. Re-run: `python3 -B S/batchN.py [name]` from the repository root. Records: `S/fx/<name>/record.json` and `S/fx/<name>/work/`.

No shipped verdict (the 9 subjects) was shown false. Six root causes let the tool print a pass verdict that is not proved. The author's closure of the abstract-module hole holds for the cases it targets (see "probes that found nothing"), but the next hole of the same kind is F1.

## FALSE-VERDICT findings (all reproduced)

**F1. The audit covers only the files on its command line. Included files are never audited.**
- Where: `scripts/spec_clearing.py:93` (audit gets only `files`), `:364` (proof files are only `include`d), `:372` (only the generated instance file is checked), `:416` (only the claim files).
- Direct check (`S/t0/`): `dafny audit Main.dfy` gives "0 findings", exit 0, when the included `Helper.dfy` holds `lemma {:axiom} Anything() ensures false` in a non-abstract module. `dafny audit Main.dfy Helper.dfy` gives 1 finding, exit 2.
- Fixtures (batch1/2/3). Each claim file uses the WEAK Post of the control `RefundWeakPostBase.dfy` over the approved refund specification (the tool's own control gives UNDECIDED for it). The two-run lemma calls a helper that proves `false`:
  - `V1IncludedAxiom`: included file, `module HelperConcreteV1 { lemma {:axiom} Anything() ensures false }`, used by `import H = ...`. Observed: `VERDICT=NO_CHOICE claim(audit=0,checker=0) proof(passed=True,audit=0,checker=0)`.
  - `V1cIncludedAssumeAxiom`: helper body is `assume {:axiom} false;`. Observed: NO_CHOICE.
  - `V4bIncludedEmptyType`: included `module RangesV4b { type Index = x: int | 0 <= x < 0 witness *  ghost function First(): Index }`; proof is `var i: Ranges.Index := Ranges.First();`. No `axiom` or `assume` word, no Dafny warning. Observed: NO_CHOICE.
  - `V23NestedInBase`: the abstract base (included file, instantiated by the tool, as in the shipped layout) holds a nested non-abstract `module Inner` with `assume {:axiom} false`. Observed: NO_CHOICE. The instance does not make the audit report a nested module.
- Why wrong: Dafny proved nothing; the lemma rests on an assumption. The header text "an audit equal to the empty baseline" and the assumption line in `exit_slice2.py:88-89` are true only for the generated file and the claim files.
- Shipped subjects: I ran one `dafny audit` with ALL real input files on the command line (clearing/ without controls, reused packet files, tests, impl, spec): exit 0, 0 findings. So no shipped verdict depends on this hole today. Files that the tool itself never audits: `impl/*.dfy`, `clearing/planted/*Impls.dfy`, `LedgerNoFeeImpl.dfy`, `NoFrameImpls.dfy` helper content, every base file that is only included.
- No control covers it: `control-axiom-lemma` and `control-assume` are both caught at the claim-file audit (claim audit exit 2 in `build/slice2/evidence/attempt-0001/evidence.json`).

**F2. `expect` in a forward link is accepted by verify, by the audit, and by the instance.**
- Where: no check in `spec_clearing.py`; the forward links and `PostIsExact` are methods, so `expect` is legal there.
- Fixture `V8Expect` (batch1): Post is `decision == R.Rejected && plan == []` (false for the approved refund specification). Forward link: `decision, plan := R.Assess(context, response); expect decision == R.Rejected && plan == [];`. Everything is in the claim file, on the audit command line.
- Observed: `VERDICT=NO_CHOICE claim(audit=0,checker=0) proof(passed=True,audit=0,checker=0)`.
- Why wrong: the link "every result of the specified method satisfies Post" is not proved; the method halts instead. With the same trick a specification with a real choice gets NO_CHOICE.

**F3. NO_CHOICE is false when the specification leaves a definition to the refinement.**
- Where: the argument "forward link + two-run lemma" (`SCOPE['NO_CHOICE']`, `spec_clearing.py:50`). The lemma is proved for each fixed refinement, not across refinements.
- Fixture `P1ParamSpec` (batch4): copy of `RefundSpec` with one bodyless `function Limit(): int` used in `Eligible`. The claim files are the shipped `RefundDeterminism.dfy` and `RefundExact.dfy` texts over that module (exact Post, forward link, two-run lemma, `PostIsExact`). Honest shape, no trick.
- Observed: `tool verdict: NO_CHOICE | proof passed True audit 0 checker 0`. Then the tool's own CHOICE-style check on two refinements (`Limit` is 100 and 10; input `ChargeContext("ch_1","rq_1",100,60,true,true), Candidate(40,"duplicate_charge")`; one authorizes, one rejects): `passed True audit 0 checker 0`.
- Why wrong: by the tool's own definition of CHOICE, this specification leaves a choice. The same gap applies to bodyless predicates, constants, opaque types and abstract imports of a specification.
- Shipped subjects: I read the three approved specifications. Every function and predicate has a body. `BookingSpec` has one abstract import (`Accounting : LedgerSpec`), and all functions of `LedgerSpec` have bodies. So the three NO_CHOICE verdicts are not affected.

**F4. EQUIVALENT is relative to hand-written input and result mappings. No lemma shows that they are onto or one-to-one.**
- Where: `clearing/pairs/RefundRewrite.dfy:13-45` (`CtxN`, `RespN`, `DecN`, `PlanN`), `RefundRewriteAgree.dfy:11-14`, `SCOPE['EQUIVALENT']` (`spec_clearing.py:54`).
- Fixture `P2VipMapping` (batch6): new specification = `RefundSpec` plus one input field `vip: bool`; `Eligible` also needs `!context.vip`. Base file = shipped `RefundRewrite.dfy` text with `CtxN` setting `vip` to `false`. Agree file = shipped text. All seven required members are named as in `refund-rewrite`.
- Observed: `tool verdict: EQUIVALENT | proof passed True`. A witness then verifies (`passed True audit 0 checker 0`): old authorizes `Authorized(40,"duplicate_charge")`, new rejects the same charge and proposal with `vip=true`.
- Why wrong: "for every typed input ... the two specifications allow the same result" is false; inputs of the new specification outside the image of `CtxN` are not covered. A new field is the usual shape of a real specification change.
- Shipped `refund-rewrite`: by reading, the four mappings are bijections (same constructors and fields). That is a manual check, not a Dafny proof.

**F5. The result cache ignores file content; a duplicate subject id gives a stale pass.**
- Where: `spec_clearing.py:86-88,108` (key is the path tuple), `:360` and `:428` (generated file name comes from the subject id), `exit_slice2.py:146` (set comparison, duplicates pass).
- Fixture `L1DuplicateId` (batch3, batch5): one `Tool`; first the shipped `refund` subject; then a second subject with the same id, whose file defines module `RefundDeterminism` with the weak Post and a lemma WITHOUT a body (the author's closed hole).
- Observed: `first (honest) -> NO_CHOICE`; `second (...) -> NO_CHOICE proof passed: True audit 0`; only 4 Dafny checks ran (no instance check for the second). The second subject alone in a fresh `Tool`: `LINK_BROKEN proof audit 2`. Through `exit_slice2.run_subjects` with the list patched in memory: it returned without `Failed`, `[('refund','NO_CHOICE','ACCEPTS'), ('refund','NO_CHOICE','ACCEPTS')]`.
- Why wrong: the instance file was rewritten, never checked, and the first result was reused. `main()` of `spec_clearing.py` stops at the first id, so only the EXIT script is exposed.

**F6. A verdict follows the member NAME only. Nothing ties `spec`, `old`, `new`, the candidate block or the member to a statement.** (This is also the answer to item 5.)
- Where: `spec_clearing.py:414-438`; `:430` only tests `member in proof['members']`.
- Reproduced with EXISTING repository files and one wrong subject entry each:
  - `L2LooseForwardLinkAsClaim`: claim member `RefundLooseBase.AssessThenPost (correctness)` (the forward link). Observed: `NO_CHOICE` for the planted loose specification, which the shipped run reports as CHOICE.
  - `L3CapWrongMember`: claim member `SpecDiffRefundCap.UnchangedOutsideTheCap (correctness)` (a real lemma with a restricting `requires`). Observed: `EQUIVALENT` for the cap pair, which the shipped run reports as DIVERGES.
  - `L4ChoiceWrongSpecLabel`: subject `control-post-too-weak` (label `spec/refund/RefundSpec.dfy`) with the supplied candidate block of `refund-loose`. Observed: `CHOICE` with example `Authorized(40,...)` / `Authorized(39,...)`, labelled as the approved refund specification.
- Also silent (read, not run): a subject without the forward-link member or without `PostIsExact` still gets NO_CHOICE; a claim lemma with `requires false` passes.
- How likely a person misses it: high. `subjects.json` has 834 lines; member names differ by one word; the report shows only title, verdict and example. The EXIT script checks verdict strings, not which members were required.

## MEDIUM

- **M1.** `SCOPE['NO_CHOICE']` (`spec_clearing.py:50`) says "for every typed input". For ledger and booking the lemma and the forward link have `requires WellFormed(state)` (the method's precondition). The verdict holds only for inputs that satisfy the precondition. The report prints the wider text.
- **M2.** `exit_slice2.py:271-273` writes `'result': 'passed'` with fixed text for Q1 to Q5. Q1 says "Its Post predicate is exact". No expectation checks that `PostIsExact` or the forward link is in `proof.members` (`choice()`, lines 154-163, compares verdict and acceptance strings only).
- **M3.** Report column "Example (verified by Dafny)" (`exit_slice2.py:286,299`). For `ledger-noframe` and `ledger-fee` the example is free text from `subjects.json` (`spec_clearing.py:390`); Dafny never sees it. I compared both texts with their lemmas by reading: they match today.
- **M4.** Exactness and "both specifications allow a result" need an implementation to exist. `PostIsExact` is vacuous at an input where the method specification allows no result. The tool gets existence only from the bound implementation, whose file it never audits (see F1). Direct audit: 0 findings today.

## LOW

- `spec_clearing.py:272`: `response['kind']` of supplied values goes into the witness text without a check; also `source`, `spec_module`, `base_module` (`:308,:326`). Subject list only; solver values are checked by regular expressions.
- `ledger-noframe`: Dafny proves a lemma about the functions `HonestBalances` / `TrojanBalances`, not one statement about the two `Apply` results. The difference follows from the two added `ensures`. Sound by reading.
- Hidden-effect case: the two print fixtures run only through `gate/gate.py`. The refund and booking gates are only shown to accept. Only the print effect is exercised.

## Probes that found nothing

- `V2`: `import H = <abstract helper>` with a bodyless lemma: instance rejected ("a compiled module is not allowed to import an abstract module").
- `V3`: nested `abstract module` with a bodyless lemma: instance rejected.
- `V4`, `V7`: empty type plus bodyless ghost function, trait with bodyless lemma, inside the claim module: instance audit reports them.
- `V4c`: the same in a non-abstract module of the claim file: claim audit exit 2.
- `V5` `{:only}`, `V6` `{:verify false}`: audit finding and warning, exit 2.
- `V22a/b` `{:verify false}` on a class or module: Dafny still verifies and rejects the member.
- `V9` `decreases *` with an endless loop: claim audit exit 2.
- `V12a/b/c`: `{:axiom}` lemma, `assume {:axiom}`, bodyless lemma in an abstract base in an INCLUDED file that the tool instantiates: instance audit exit 2. `V24` (class in that base): same.
- `V20` ghost constant of an empty type, `V21` bodyless method with `ensures false`: instance rejected.
- `V1b` plain `assume false` in an included file: Dafny warning, exit 2.
- Counterexample text cannot inject Dafny text (read only).
- Every file that a subject names, with includes, is in the pinned lists of `exit_slice2.py` (script check).
- No `expect`, `{:axiom}`, `assume`, `witness *`, `{:verify`, `{:only}`, `decreases *`, `{:extern}` in code lines of the real inputs.

## Controls and expectations that cannot fail

- `exit_slice2.py:162-163` and `:177`: a NO_CHOICE or EQUIVALENT verdict already implies a passed proof.
- `:193`: UNDECIDED and LINK_BROKEN already imply no example.
- `:159`, `:174` with an empty source set.
- `:146` and `:195`: set comparison; a duplicate id passes.
- `control-axiom-lemma`, `control-assume`, `control-post-too-strong`, `control-member-missing` all stop at the claim-file check. None exercises the instance check; only `control-lemma-without-body` does. No control has an assumption in an included file, an `expect`, a member missing from the proof instance only, or a duplicate id.

## Not checked

- I did not run `exit_slice2.py --case ...`; I read the existing records in `build/slice2/evidence/attempt-0001/`.
- I did not read `ROADMAP.md` or `unsure.md`.
- Gates, `ts/`, the soundness of Dafny, Boogie and Z3 (out of scope).
- Injective result mappings (`DecN`, `PlanN`) were not attacked with a fixture; only the input mapping was (F4).
- Other statements that halt or weaken a method proof beyond `expect` and `decreases *` were not searched fully.
- `proposals/forge2-slice2-spec-clearing/run_regression.py` and its records.

## Counts

FALSE-VERDICT: 6 (F1, F2, F3, F4 need only a claim or support file of the wrong kind; F5 and F6 need a wrong subject list). HIGH: 0. MEDIUM: 4. LOW: 3.
```

## 2. What the build agent did with each finding

The repairs are in the working tree. They were NOT reviewed by a second
reviewer.

| Finding | Action | Control that now stops it, for its own reason |
| --- | --- | --- |
| F1 audit sees only command-line files | REPAIRED. Every check audits every file that the checked files reach through `include`. The reader of `include` lines fails closed | `control-axiom-in-included-file`: verify of the claim file exits 0; the audit of the included file reports the axiom |
| F2 `expect` in a forward link | REPAIRED by a refusal: the word `expect` (and the attribute `{:options`) is refused in every reached file. Other statements that could weaken a method proof were NOT searched further (as the reviewer says) | `control-forward-link-halts`: verify and audit pass; only the refused word stops it |
| F3 a specification that leaves a definition open | PARTLY REPAIRED. New specification probe: the tool writes a non-abstract refinement of the specification with nothing added, and the Dafny compiler must report "has no body" for exactly the specified methods. This detects a COMPILED function, predicate or method without a body (the reviewer's fixture). NOT detected: a ghost function or predicate without a body, a constant without a value, an opaque type. The verdict text of NO_CHOICE now says "each refinement taken alone" and names what is not checked | `control-specification-leaves-a-definition-open`: claim and instance pass; the probe reports `Limit` |
| F4 mappings not shown one-to-one and onto | REPAIRED for the shipped pair: `RefundRewrite.MappingsAreOneToOneAndOnto` (inverse functions, proved by Dafny). The tool gives EQUIVALENT only if the subject names mapping members and they are among the passed members. The reviewer's fixture with a new field was NOT rebuilt as a control | `control-equivalence-without-mapping-proof`: claim and instance pass; no mapping proof is named |
| F5 result cache | REPAIRED: the cache is removed. The EXIT script refuses a subject id that is there twice | — (a duplicate id is refused by a plain comparison of lists) |
| F6 a verdict follows the member name | NOT REPAIRED in the tool: this is the stated limit "a person reads the short claim lemmas and the subject list". NARROWED for the shipped subjects: `scripts/exit_slice2.py` now pins, for every shipped subject, the claim member, the proof members (forward link, two-run lemma, exactness, mapping proof) and the witness members; a wrong entry in the subject list makes the EXIT case fail. A new subject is not protected by this | — |
| M1 scope text and preconditions | REPAIRED: the text says "that satisfies the precondition of the specified method" |  — |
| M2 "Post is exact" without a check | REPAIRED by the pinned members | — |
| M3 "verified by Dafny" for a hand description | REPAIRED: each example says whether the tool wrote its values into the verified witness, or whether it is a description by hand of a hand-written verified witness | — |
| M4 implementation files not audited | REPAIRED with F1 | — |
| LOW (3) | NO code change | — |

Not done, and open: a check that a claim lemma states the right claim
(F6); a proof of NO_CHOICE across two refinements, which would close F3
for ghost definitions too; a search for further statements of the kind
of F2.

Removed-check copies after the repairs (one-off):
`records/removed-check-copies.json`.
