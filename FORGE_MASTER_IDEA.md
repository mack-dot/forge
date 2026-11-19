# Forge master idea — Proof-Carrying Finality and Spec Clearing

Designated by the owner on 2026-11-17: "make this the masteridea please
and lets do this" (U410). This file is the working record of that idea.

It does NOT replace `FORGE_MASTER_MISSION.md` (north star), `AGENTS.md`
or the hard rules in `ROADMAP.md`. It works under them. It is not a
stage. It gives no approval. `end_to_end=false` stays.

Source texts, saved verbatim (from another AI model, pasted by the
owner; their code results and citations are NOT verified):
[mission prompt](proposals/future-directions-20261117/SOURCE_MISSION_PROMPT.md),
[analysis](proposals/future-directions-20261117/SOURCE_ANALYSIS.md).
Corrected claims, costs and limits:
[FUTURE_PLANS.md](proposals/future-directions-20261117/FUTURE_PLANS.md).

## The idea in three parts

1. **Spec clearing (Pillar I).** Before a person approves a spec, a
   checker shows whether the spec leaves any choice to an implementation
   (two-run determinism lemma), rejects ambient effects in checked
   code, shows concrete before/after examples for a spec change, and
   derives obligations from the whole diff against the approved lock.
2. **Proved checker in front of the effect (Pillar II).** Untrusted
   code proposes a transition. A very small program checks it against
   the spec relation and issues a token. The store or the outbound API
   accepts an effect only with a valid token, a matching pre-state hash
   and a fresh request id.
3. **Runtime certificates (Pillar III).** An untrusted optimizer returns
   an answer with a certificate. A small proved check accepts it only if
   the certificate shows the answer is within a stated factor of the
   optimum. The optimizer can change without a new proof.

## Blast-Radius Finality vs. Intent Elicitation (Scope and Honest Limits)

Added on 2026-11-18 from an owner text (text F in the
[Slice 3 owner texts](proposals/forge2-slice3-runtime-certificates/OWNER_TEXTS.md)).
This section states the scope of the idea. It is not a result and it
approves nothing. The actual state of each part is in the table below.

1. **What Forge guarantees: finality of the blast radius.** The claim
   is about an effect boundary that Forge owns: a store or an outbound
   call that accepts an effect only with a token (Pillars II and III).
   At that boundary a small checker decides a structured rule on
   structured data. The classes of rule are:
   - decidable state-machine transitions: the proposal is, or is not, a
     step that the spec relation allows from the stored pre-state;
   - conservation and cap invariants;
   - cross-service reservation protocols;
   - checkable `alpha`-optimality witnesses: an answer with a
     certificate that it is within a stated factor of the optimum.

   The decision does not depend on the code that made the proposal.
   That code can be an AI model that hallucinates. It can be written
   again in another language. It can race with another request, and it
   can retry. An effect outside the rule gets no token, and the
   boundary takes a token only with a matching pre-state hash and a
   fresh request id. The worst effect of wrong upstream code is thus an
   effect that the rule allows. That is the blast radius.

   This is the class of claim, not a list of results. The state today
   (rule 3 keeps the evidence classes apart):
   - Proved by Dafny at source level: the refund checker core against
     the approved refund relation with its cap `amount <= remaining`
     (F2.1); the certificate checker core against a candidate
     specification that is not approved intent (F3.1). The protocol
     model holds under four named assumptions (F2.0).
   - Conservation is a rule of the approved ledger specification
     (`Total` is kept). The checker cores so far are for refund and
     batch booking only.
   - Finite tests, NOT proofs: issuers, sinks, compare-and-swap, races,
     retries, and the exchange of optimizers in three languages (F2.2,
     F2.3, F3.2).
   - NOT STARTED: a reservation protocol across services (F2.5).
   - No compiled checker program is proved. `end_to_end=false` stays.
2. **What Forge does NOT prove: intent from unstructured prose.**
   Example: a customer asks for $10 in free English text. An untrusted
   agent reads the text and proposes $80. The rule is a coarse cap of
   $100. A coarse cap allows $80: the checker issues the token, and
   that is correct for the rule. The checker shows that the effect is
   inside the structured rule. It does not show that the proposal is
   what the customer meant. Outside the claim:
   - reading comprehension of natural language (the step from prose to
     a structured proposal);
   - the user interface and liveness upstream of the boundary (a
     request that never arrives, or arrives late);
   - server code of a third party that Forge does not own (for example
     a payment processor). Its behaviour is an assumption and is stated
     by name.

   A smaller blast radius needs a tighter structured rule (F2.4). It
   does not come from a claim about the prose.
3. **Why spec clearing is aimed at the real bottleneck.** The goal is
   "code that does what I meant". When a checker exists, wrong code
   gets no token. The hard problem that stays is the specification: to
   elicit it and to audit it. Spec clearing gives the person who
   ratifies a spec three things: `NO_CHOICE` (the spec leaves no choice
   to an implementation), `ACCEPTS` (the spec accepts a concrete case,
   so it is not vacuous) and concrete before/after witnesses for a
   change. The aim: the person reviews a short spec and concrete
   examples, not thousands of lines of untrusted code. The size of that
   reduction is not measured (NOT RUN).

   The limit: spec clearing does not show that a spec matches intent.
   A deterministic spec with a wrong premise that no person examined is
   still wrong, and that premise stays with the human ratifier. F1.5
   and F1.6 aim to put more such premises in front of that person as
   concrete cases and explicit questions. They do not move the
   responsibility.

## Rules for this work (alignment with the repository)

1. **No stage numbers.** The source says "Stage 9 is CURRENT" and names
   new Stages 9–11. That is wrong for this repository: Stages 9–11 are
   DONE. CURRENT is none. Stage 12 is unauthorized and this file does
   not authorize it. Work items are the F-numbers below.
2. **Protected paths.** `spec/**`, `spec.lock`, `policy/**`, `gate/**`
   change only by a proposal with an exact diff, approved by the owner
   on its exact bytes. The PR gate's own manifest is wider
   (`gate/incremental.py`: also `toolchain/`, `schemas/`, `.github/`,
   `AGENTS.md`); this work treats all of them as protected. New gate modules, policy rules, schema fields and
   specs are built and checked under `proposals/` first. "Let's do
   this" is not an exact-bytes approval.
3. **Evidence classes stay separate.** `source_proof`, binary proof,
   runtime certificate check, spec determinism proof, bounded check,
   test. A test count is never a proof. A failed proof attempt
   ("could not be proved") is not a proof of falsity; a planted bug
   needs a verified witness.
4. **Established tools only.** Dafny, Rocq and the pinned pipeline
   judge. Scripts dispatch them and compare exit codes. No custom
   solver wrapper decides correctness (hard rule). The "bounded
   blindness" claim must therefore be a Dafny lemma, not a script
   result.
5. **Checker, gate and scenario exits are recorded separately.** A
   negative control passes only when the checker rejects for the
   expected reason.
6. **No commit or push without the owner's explicit word.**
7. **Corrections to the source that bind this work.**
   - Stage 7 proved termination with exit 0 of one 1,240-byte ELF. "Exit
     0 only when the relation holds" for a checker with SHA-256 and HMAC
     is a functional binary proof. That is M1-sized work, not a
     re-run of Stage 7.
   - With an HMAC the sink holds the key and can mint. The sink is
     trusted. Key isolation, the store, and the binding of the pre-state
     hash to the real stored state are assumptions unless proved.
   - A purity rule that rejects `:|` would reject the approved
     `LedgerSpec.Total` (ghost). The rule must apply to compiled code
     only.
   - A certificate with zero gap exists for every instance only for
     special problem shapes (for example interval scheduling). The
     check stays sound for all shapes; it can reject an optimal answer.
   - "0 of 50 attacks settled" is a finite test result.
   - "0.0 s re-verification" is the cost of solver edits only. The
     checker, its integration and the spec still pass the normal gate.

## Work items and actual results

Status words: DONE (command ran, exit recorded), NOT RUN, NOT STARTED
(no file written, no command run, no proof claimed), PROPOSAL
NEEDED (touches a protected path), OPEN.

| Item | What | Status | Record |
| --- | --- | --- | --- |
| F1.1 | Two-run determinism lemma for the approved Ledger, Booking and Refund specs | DONE as a diagnostic outside the gate; pinned Dafny exit 0 for all three. Slice 2 (2026-11-18): a clearing tool (`scripts/spec_clearing.py`, dispatch only) with an EXIT script and an evidence record gives NO_CHOICE for the three approved specifications, with an exact `Post`, a proved acceptance, a non-abstract instance and a probe of the specification; CHOICE for two planted specifications (one witness made from the solver's counterexample and verified); the planted vacuous specification is proved to accept nothing. Found in this work: inside an abstract module the pinned Dafny accepts a lemma with no body, and its audit reports only on the files of its command line; the earlier "exit 0, audit 0 findings" for these abstract modules did not exclude that. Not gate evidence. Limits: a person must read the hand-written claim lemmas; ghost definitions without a body in a specification are not detected (U450, U451). Merged by the owner as `462f9e2e` (pull request 46; hosted gate exit 3, UNSUPPORTED, as expected; U453) | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md), [Slice 2 report](proposals/forge2-slice2-spec-clearing/REPORT.md) |
| F1.1c | Planted no-frame ledger spec: two verified implementations with different results on five accounts; determinism lemma rejected; Trojan rejected by the approved spec | DONE (control) | same |
| F1.1d | "Bounded blindness": the planted bug is invisible with four accounts or fewer | DONE (control): Dafny lemma, exit 0 | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md) §5.1 |
| F1.1e | Generate the `Post` predicate from the spec text instead of writing it by hand (`gate/arbitrage.py`) | NOT RUN; PROPOSAL NEEDED for `gate/` | — |
| F1.2 | Reject `print` in compiled code; close the Stage 5 `print` survivor | APPLIED on `main` (see the end of this cell). History: Owner approved the three-file diff; it regresses Stages 5, 6, 8 and was reverted (U419). Version 2 (six protected files) passes Stages 1, 2, 3, 5, 8 in a scratch worktree; Stage 6 `report` cannot pass after any gate change. Booking and refund need no extra caller (U423). Round 3: version 3 adds a gate ratification rule (trusted-side record, exact digests, controls with the ratified gate); in a scratch worktree Stages 1–5 and 8 exit 0 (24 cases) and 18 PR-gate controls show 0 evasions; NOT APPLIED because Stage 9 needs a hosted signing run that is not approved (U432). Round 4: three independent reviews of the ratification rule; the last one found 0 fail-opens and 0 HIGH or MEDIUM accidental defects, and one MEDIUM limit that needs an owner-written record (four more modules of the PR-gate process stay ratifiable). Final commits on `main`'s lineage: rule `801777ea`, record `26410d46`, print effects `f54e2507`. Control sets: 22 cases on `main`'s gate and 26 on the local gate, 0 evasions. The hosted gate answered REJECTED for pull request 39 (rule and record), as expected; the owner merged it on 2026-11-18 (`main` = `96d2ec77`). The print-effects change itself was built again on the new `main` (`ccb4e5e2`, records `59189040`) and merged on the owner's word on 2026-11-18 as `d026e109`; the hosted gate had matched record 0001 and run 8 of 8 floor controls as expected (result UNSUPPORTED, because some files are inputs of no obligation). DONE at the gate level: Stage 5 mutation counts now show `effect_rejected` 1 and `survived` 1 (before: `survived` 2). Not shown: a hosted VERIFIED result for a ratified change (U433, U436, U437, U441, R4C-1) | [version 3 report](proposals/forge2-pillar1-print-effects/v3/REPORT-V3.md), [bootstrap checklist](proposals/forge2-pillar1-print-effects/v3/BOOTSTRAP_CHECKLIST.md) |
| F1.3 | Spec-diff witnesses and receipt for a spec change | DONE as diagnostics for two pairs: fee change (all six witnesses proved; W2 with isolated assertions, U418) and approved refund spec versus a capped variant (eight witnesses). General lemmas hand-written; generator for arbitrary pairs NOT built (owner scope decision in Round 3: not wanted). Round 3: shared audit skeleton proved once, three specs as instances; W2 split costs 1.1 M resource units instead of 6.3 M (U430). Slice 2: the same tool gives EQUIVALENT for a planted rewritten refund variant (universal, with a proof that the mappings between the two sides are one-to-one and onto) and DIVERGES with a before/after example for the planted refund cap (example made from the solver's counterexample and verified) and for the real fee change (example supplied by hand, verified). One example is one point; the general lemmas stay hand-written (U450, U451). Merged by the owner as `462f9e2e` (pull request 46; U453) | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md) §5.2, §6, [Slice 2 report](proposals/forge2-slice2-spec-clearing/REPORT.md) |
| F1.4 | Cumulative diff against the approved base; split-edit control | DONE as a control: unchanged `gate/incremental.py`, 16 cases, 0 evasions (U422). No new gate module. Round 3: the same attack classes against the proposed ratification gate, 18 cases, 0 evasions (U432) | [analysis and control](proposals/forge2-pillar1-anchor-diff/ANALYSIS.md) |
| F1.5 | Spec clearing, branch-partition boundary tables: one Dafny-verified concrete input/output witness for each logical branch and each threshold edge of a spec (`cap - 1`, `cap`, `cap + 1`; tier and reason splits), so that a ratifier reads a complete concrete boundary table before approval and not one `ACCEPTS` witness | NOT STARTED: no file, no command, no proof claimed. Limits to keep when it starts: a solver value is a candidate until Dafny verifies it as a witness (rule 4); "complete" must itself be a proved claim that the listed branches cover the spec, or the table is a set of examples only | — |
| F1.6 | Spec clearing, adversarial property red-teaming: before ratification, ask the solver whether candidate "weird but legal" properties are satisfiable under a draft spec (example: `amount > shipping_paid` with `item_returned == false`); if one is, verify the concrete witness in Dafny and put an explicit confirmation question to the person before approval | NOT STARTED: no file, no command, no proof claimed. Limits to keep when it starts: the list of candidate properties is finite; a query that fails or runs out of time is not a proof that the property cannot hold (rule 3); the answer to each question stays with the ratifier | — |
| F2.0 | Design note: token format, trusted base, exact claim text, reuse of M1 theorems | DONE as a design note plus a protocol MODEL: pinned Dafny exit 0 (22 verified) under four named assumptions; four weakened variants rejected. No program, key or store is proved | [design note](proposals/forge2-pillar2-finality-protocol/DESIGN.md) |
| F2.1 | Checker and minter program | RESEARCH TEST: `minter.ts`, a separate process with an Ed25519 key, signs only what the Dafny-generated refund kernel authorizes (U420). No binary-level claim. Round 3: minter version 2 takes its decision from `RefundMinterCore.Decide`, proved in Dafny against the approved refund spec (7 verified; two wrong cores rejected); the wrapper stays unproved (U428). Slice 1 (2026-11-18): the checker core `impl/RefundFinality.dfy` is PROVED at source level against the approved refund relation (claims P1 to P4: safety, exact acceptance, no intent on refusal, token binding; pinned Dafny with the gate options, exit 0, 10 verified; nine wrong cores rejected, two of them for a print effect). The issuer process signs only the result of the compiled core. NOT proved: the compiled program, the issuer code, the hash in the token. The claim text is not approved intent and the result is not gate evidence (U444). On `main` as `136ad0bf` (pull request 45, U449) | [refund finality report](proposals/forge2-pillar2-refund-finality/REPORT.md), [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F2.2 | Atomic sink with compare-and-swap and unique request id | RESEARCH TEST: `sink.ts` on SQLite, holds only the public key; not proved. Slice 1: `ts/refund-finality/sink.ts` takes the canonical text of a token only; signature, pinned ids, state hash and request id; one transaction. Dispatcher with a ledger and one run at a time. NOT proved. One fresh-context review found 1 in-process fail-open, 1 HIGH and 2 MEDIUM defects; repaired in one pass (U445). A later narrow check of the four repairs: 0 fail-open, 0 HIGH, 1 MEDIUM (one very long line ended the issuer process), 1 LOW (U447). Both repaired in a last pass that had no review (U448). On `main` since 2026-11-18: the owner merged pull request 45 as `136ad0bf`; hosted gate exit 3 UNSUPPORTED for both heads (`9af026df`, `2e39a100`), as expected (U449) | same, [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F2.3 | Adversarial test suite (finite) | DONE (finite): suite exit 0 twice; 38 of 38 attacks as expected; 0 unauthorized settlements; 4 of 4 database-tamper cases detected by audit, not prevented. Round 3: a dispatcher checks signature, chain and its own ledger before each effect; 12 raw-database cases, 0 unauthorized effects; limit: selection among signed claims if the minter signs twice per state (U428). Slice 1: suite of 115 rows, exit 0; 48 rejection attempts with 0 effects; races and dispatcher overlap with a common start time; ten copies with one check removed all make the suite fail. Finite (U445, U448). On `main` as `136ad0bf` (U449) | same, [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F2.4 | Finality, fact-bound sub-caps and a three-valued verdict: bind structured reason codes to authoritative fields of the pre-state (`SHIPPING_ISSUE ==> amount <= pre_state.shipping_paid`; `ITEM_RETURN ==> carrier_scan == true`) to make the blast radius inside a coarse cap smaller; add a proved third verdict `REQUIRE_HUMAN_COSIGN`, so that no token is minted autonomously for an unstructured goodwill claim above a tight micro-cap without a separate human signature | NOT STARTED: no file, no command, no proof claimed. PROPOSAL NEEDED when it starts: the approved refund spec has two verdicts, three reason strings and no field for shipping or a carrier scan, so these rules change `spec/`. The truth of a pre-state field (for example a carrier scan) is an assumption about its source | — |
| F2.5 | Finality, multi-processor `IN_FLIGHT` reservation and failover saga: a proved stateful reservation protocol (`PAID -> IN_FLIGHT(processor, idemp_key) -> SETTLED`, or `-> CONFIRMED_REJECTED`) with a compare-and-swap on `pre_state_hash` before outbound network I/O; aim: no double credit across processors (processor A and processor B) under races and ambiguous timeouts, because failover is forbidden without an explicit `CONFIRMED_REJECTED(processor, idemp_key)` transition | NOT STARTED: no file, no command, no proof claimed. External assumption, to be stated by name: the remote processor answers reconciliation honestly (its server code is not owned). A safety rule, not liveness: a request can stay `IN_FLIGHT` while a processor gives no answer. No approved spec for it exists; PROPOSAL NEEDED if it is to become approved intent | — |
| F2.6 | Cross-stack conformance of the refund decision: the M1 executable (CakeML to ARM64) against the Slice 1 checker (Dafny to JavaScript) on one vector corpus | DONE as a FINITE TEST (Wave Gate 1, 2026-11-19): `scripts/exit_m1_conformance.py`. 2,466 typed vectors (HOL-written fixtures, bounds at their value and one below and above, hostile texts and integers, a fixed pseudo-random mix): the M1 stdout bytes equal the rendering of the compiled `Refund.Assess` result for every vector; the compiled `RefundFinality.Check` issues a token for the honest transition exactly when M1 authorizes and refuses 24,039 tampered transitions; the issuer process agrees inside its text limits; 192 changed wire inputs gave no result that the base request does not have. 0 findings. Controls: 57 planted faults and empty-side cases found or refused; 25 wrong Dafny cores reported; the pinned Dafny does not prove the 16 wrong decisions. One fresh-context review: 0 fail-open on the present inputs, 3 MEDIUM (a pass was possible with an empty fixture file; three wrong checker cores passed; sub-conditions without a planted fault), repaired in one pass, not reviewed again. NOT a proof, NOT a compiler proof of the JavaScript, no result of M1: M1 stays open and `end_to_end=false`. Observed: the M1 reader takes `040`, `+40` and `"40"` as 40; the Dafny JavaScript runtime fails for a text of 50,000 code points (U459, U460, U461) | [conformance report](proposals/forge2-m1-conformance/REPORT.md) |
| F3.1 | Integer weak-duality check with quality theorem, witnesses and controls | DONE as a diagnostic outside the gate; pinned Dafny exit 0 (46 verified); two controls rejected. Slice 3 (2026-11-18): the check is now the contract of a CANDIDATE specification (not approved, not under `spec/`); a checker core refines it, so Dafny proves the core against that contract; claim lemmas for safety, for quality within the stated gap against every feasible allocation, for the exact decision and for the token fields; NO_CHOICE through the Slice 2 clearing tool; one bridge lemma to the approved `NoDoubleBooking` predicate for one batch shape (proved at the second of at most five attempts); 21 wrong cores refused, each for its own reason. Sound, NOT complete (owner text E). Not gate evidence (U454, U455). On `main` as `b121bbdd` (pull request 47, U458) | [Pillar III report](proposals/forge2-pillar3-dual-certificate/REPORT.md), [Slice 3 report](proposals/forge2-slice3-runtime-certificates/REPORT.md) |
| F3.2 | Solver evolution benchmark; new evidence method `certified_runtime_check` | BENCHMARK DONE (finite): 25 solver functions, 2,300 checks, 0 accepted overbookings, 0 Dafny runs per version (U421). The evidence method is NOT proposed yet (needs `policy/`, `schemas/` proposal and an approved batch-booking intent). Round 3: the 25 solvers through a minter whose decision is the proved checker; 1,227 signed receipts, 0 overbookings, 0 non-optimal at gap 0; 299 optimal proposals refused at gap 0 (U431). Slice 3: three untrusted optimizers (TypeScript, safe Rust built by an unpinned `rustc`, a Python adversary with 16 modes) run as separate processes behind one line and are exchanged against the SAME compiled core: the proof inputs and the compiled module keep their bytes; 84 allocations committed, each for a token; 0 tokens for the adversary; 0 effects without a commit; issuer and sink with 104 control rows; 26 of 26 copies with one check removed fail (finite runs, not proofs). The one review found 2 HIGH defects, both repaired: an optimizer process could write the sink's database behind the sink (now it runs under the macOS sandbox tool, which is trusted and not proved), and the adversary runs passed with no adversary. The repairs were not reviewed again. The owner accepted the sandbox tool for this slice as documented: trusted, not proved, one platform (U457). Merged by the owner as `b121bbdd` (pull request 47; hosted gate exit 3, UNSUPPORTED, as expected; U458). The evidence method in `policy/` and `schemas/` is still NOT proposed; batch booking is still not an approved intent (U454, U455, U456) | [finality report](proposals/forge2-pillar3-dual-certificate/finality/REPORT.md), [Slice 3 report](proposals/forge2-slice3-runtime-certificates/REPORT.md) |
| F4 | Schemas, three-regime benchmark, documents | NOT RUN | — |

## Order

F1.1, F3.1, F1.1d, F1.3 (done as diagnostics) → proposals with
exact diffs for F1.1e, F1.2, F1.4, F3.2 → F2.0 design note → F2 build →
F4. Each step ends with real exits in the item's report and an
`unsure.md` entry.

Next horizon (added 2026-11-18): F1.5, F1.6, F2.4, F2.5. All four are
NOT STARTED. This file sets no order for them and does not start them.
The section and the four rows came to `main` with pull request 48
(merged by the owner as `d3d1980f`; hosted gate exit 3; U458).

## Round 2 (owner decisions of 2026-11-17)

Plan and live status: [FORGE_ROUND2_PLAN.md](FORGE_ROUND2_PLAN.md).
Decisions: print-effects diff approved; HOL rebuild within 90 minutes;
Ed25519 and Refund first for Pillar II; commit at checkpoints, no push
before the final table.

## Round 3 (owner texts of 2026-11-17)

Plan and live status: [FORGE_ROUND3_PLAN.md](FORGE_ROUND3_PLAN.md).
Order set by the owner: gate change (version 3) first, then Pillar II
and III, then M1. Version 3 is built and measured, not applied.

## Relation to M1

M1 (the refund executable) stays open and is not cancelled. Its model
chain is complete to S6 (U409). Its open items are owner decisions
(profile, contract review), the real FFI boundary, the entry state and
the replays. M1 is the template and the cost measure for the Pillar II
binary claim. Since Wave Gate 1 the M1 executable and the Slice 1
checker are compared on a finite corpus (row F2.6): a test, not a link
in a proof. The replay steps that are not run and their time are in
section 9 of the [conformance report](proposals/forge2-m1-conformance/REPORT.md). If the two compete for time, this file has priority by
the owner's word of 2026-11-17.

## Open decisions for the owner

1. Approve, change or reject each proposal for a protected path when
   it is ready. Ready now: [print effects](proposals/forge2-pillar1-print-effects/PROPOSAL.md)
   (`candidate.diff`, three files).
2. Is an optimizing batch-booking component wanted as an approved
   intent (new spec)? Pillar III needs it beyond the diagnostic.
3. Commit and push: done once on your word of 2026-11-17 ("push what we
   have", U412), on the backup branch only. Later commits need your word
   again. `main` is untouched; no pull request.
