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

Status words: DONE (command ran, exit recorded), NOT RUN, PROPOSAL
NEEDED (touches a protected path), OPEN.

| Item | What | Status | Record |
| --- | --- | --- | --- |
| F1.1 | Two-run determinism lemma for the approved Ledger, Booking and Refund specs | DONE as a diagnostic outside the gate; pinned Dafny exit 0 for all three | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md) |
| F1.1c | Planted no-frame ledger spec: two verified implementations with different results on five accounts; determinism lemma rejected; Trojan rejected by the approved spec | DONE (control) | same |
| F1.1d | "Bounded blindness": the planted bug is invisible with four accounts or fewer | DONE (control): Dafny lemma, exit 0 | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md) §5.1 |
| F1.1e | Generate the `Post` predicate from the spec text instead of writing it by hand (`gate/arbitrage.py`) | NOT RUN; PROPOSAL NEEDED for `gate/` | — |
| F1.2 | Reject `print` in compiled code; close the Stage 5 `print` survivor | APPLIED on `main` (see the end of this cell). History: Owner approved the three-file diff; it regresses Stages 5, 6, 8 and was reverted (U419). Version 2 (six protected files) passes Stages 1, 2, 3, 5, 8 in a scratch worktree; Stage 6 `report` cannot pass after any gate change. Booking and refund need no extra caller (U423). Round 3: version 3 adds a gate ratification rule (trusted-side record, exact digests, controls with the ratified gate); in a scratch worktree Stages 1–5 and 8 exit 0 (24 cases) and 18 PR-gate controls show 0 evasions; NOT APPLIED because Stage 9 needs a hosted signing run that is not approved (U432). Round 4: three independent reviews of the ratification rule; the last one found 0 fail-opens and 0 HIGH or MEDIUM accidental defects, and one MEDIUM limit that needs an owner-written record (four more modules of the PR-gate process stay ratifiable). Final commits on `main`'s lineage: rule `801777ea`, record `26410d46`, print effects `f54e2507`. Control sets: 22 cases on `main`'s gate and 26 on the local gate, 0 evasions. The hosted gate answered REJECTED for pull request 39 (rule and record), as expected; the owner merged it on 2026-11-18 (`main` = `96d2ec77`). The print-effects change itself was built again on the new `main` (`ccb4e5e2`, records `59189040`) and merged on the owner's word on 2026-11-18 as `d026e109`; the hosted gate had matched record 0001 and run 8 of 8 floor controls as expected (result UNSUPPORTED, because some files are inputs of no obligation). DONE at the gate level: Stage 5 mutation counts now show `effect_rejected` 1 and `survived` 1 (before: `survived` 2). Not shown: a hosted VERIFIED result for a ratified change (U433, U436, U437, U441, R4C-1) | [version 3 report](proposals/forge2-pillar1-print-effects/v3/REPORT-V3.md), [bootstrap checklist](proposals/forge2-pillar1-print-effects/v3/BOOTSTRAP_CHECKLIST.md) |
| F1.3 | Spec-diff witnesses and receipt for a spec change | DONE as diagnostics for two pairs: fee change (all six witnesses proved; W2 with isolated assertions, U418) and approved refund spec versus a capped variant (eight witnesses). General lemmas hand-written; generator for arbitrary pairs NOT built (owner scope decision in Round 3: not wanted). Round 3: shared audit skeleton proved once, three specs as instances; W2 split costs 1.1 M resource units instead of 6.3 M (U430) | [Pillar I report](proposals/forge2-pillar1-spec-determinism/REPORT.md) §5.2, §6 |
| F1.4 | Cumulative diff against the approved base; split-edit control | DONE as a control: unchanged `gate/incremental.py`, 16 cases, 0 evasions (U422). No new gate module. Round 3: the same attack classes against the proposed ratification gate, 18 cases, 0 evasions (U432) | [analysis and control](proposals/forge2-pillar1-anchor-diff/ANALYSIS.md) |
| F2.0 | Design note: token format, trusted base, exact claim text, reuse of M1 theorems | DONE as a design note plus a protocol MODEL: pinned Dafny exit 0 (22 verified) under four named assumptions; four weakened variants rejected. No program, key or store is proved | [design note](proposals/forge2-pillar2-finality-protocol/DESIGN.md) |
| F2.1 | Checker and minter program | RESEARCH TEST: `minter.ts`, a separate process with an Ed25519 key, signs only what the Dafny-generated refund kernel authorizes (U420). No binary-level claim. Round 3: minter version 2 takes its decision from `RefundMinterCore.Decide`, proved in Dafny against the approved refund spec (7 verified; two wrong cores rejected); the wrapper stays unproved (U428). Slice 1 (2026-11-18): the checker core `impl/RefundFinality.dfy` is PROVED at source level against the approved refund relation (claims P1 to P4: safety, exact acceptance, no intent on refusal, token binding; pinned Dafny with the gate options, exit 0, 10 verified; nine wrong cores rejected, two of them for a print effect). The issuer process signs only the result of the compiled core. NOT proved: the compiled program, the issuer code, the hash in the token. The claim text is not approved intent and the result is not gate evidence (U444) | [refund finality report](proposals/forge2-pillar2-refund-finality/REPORT.md), [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F2.2 | Atomic sink with compare-and-swap and unique request id | RESEARCH TEST: `sink.ts` on SQLite, holds only the public key; not proved. Slice 1: `ts/refund-finality/sink.ts` takes the canonical text of a token only; signature, pinned ids, state hash and request id; one transaction. Dispatcher with a ledger and one run at a time. NOT proved. One fresh-context review found 1 in-process fail-open, 1 HIGH and 2 MEDIUM defects; repaired in one pass (U445). A later narrow check of the four repairs: 0 fail-open, 0 HIGH, 1 MEDIUM (one very long line ended the issuer process), 1 LOW (U447). Both repaired in a last pass that had no review (U448). Pull request 45; hosted gate exit 3 UNSUPPORTED for its first head, as expected | same, [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F2.3 | Adversarial test suite (finite) | DONE (finite): suite exit 0 twice; 38 of 38 attacks as expected; 0 unauthorized settlements; 4 of 4 database-tamper cases detected by audit, not prevented. Round 3: a dispatcher checks signature, chain and its own ledger before each effect; 12 raw-database cases, 0 unauthorized effects; limit: selection among signed claims if the minter signs twice per state (U428). Slice 1: suite of 115 rows, exit 0; 48 rejection attempts with 0 effects; races and dispatcher overlap with a common start time; ten copies with one check removed all make the suite fail. Finite (U445, U448) | same, [Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md) |
| F3.1 | Integer weak-duality check with quality theorem, witnesses and controls | DONE as a diagnostic outside the gate; pinned Dafny exit 0 (46 verified); two controls rejected | [Pillar III report](proposals/forge2-pillar3-dual-certificate/REPORT.md) |
| F3.2 | Solver evolution benchmark; new evidence method `certified_runtime_check` | BENCHMARK DONE (finite): 25 solver functions, 2,300 checks, 0 accepted overbookings, 0 Dafny runs per version (U421). The evidence method is NOT proposed yet (needs `policy/`, `schemas/` proposal and an approved batch-booking intent). Round 3: the 25 solvers through a minter whose decision is the proved checker; 1,227 signed receipts, 0 overbookings, 0 non-optimal at gap 0; 299 optimal proposals refused at gap 0 (U431) | [finality report](proposals/forge2-pillar3-dual-certificate/finality/REPORT.md) |
| F4 | Schemas, three-regime benchmark, documents | NOT RUN | — |

## Order

F1.1, F3.1, F1.1d, F1.3 (done as diagnostics) → proposals with
exact diffs for F1.1e, F1.2, F1.4, F3.2 → F2.0 design note → F2 build →
F4. Each step ends with real exits in the item's report and an
`unsure.md` entry.

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
binary claim. If the two compete for time, this file has priority by
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
