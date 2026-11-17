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
   on its exact bytes. New gate modules, policy rules, schema fields and
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
| F1.1d | "Bounded blindness": the planted bug is invisible with four accounts or fewer | NOT RUN | — |
| F1.1e | Generate the `Post` predicate from the spec text instead of writing it by hand (`gate/arbitrage.py`) | NOT RUN; PROPOSAL NEEDED for `gate/` | — |
| F1.2 | Reject `print`, `{:extern}` and similar in compiled code; close the Stage 5 `print` survivor | NOT RUN; PROPOSAL NEEDED | — |
| F1.3 | Spec-diff witnesses and receipt for a spec change (test on the no-fee to fee change) | NOT RUN | — |
| F1.4 | Cumulative diff against the lock; split-edit control; compare with `gate/obligations.py` first | NOT RUN; PROPOSAL NEEDED | — |
| F2.0 | Design note: token format, trusted base, exact claim text, reuse of M1 theorems | NOT RUN | — |
| F2.1 | Checker and minter program; binary-level claim | NOT RUN | — |
| F2.2 | Atomic sink with compare-and-swap and unique request id | NOT RUN | — |
| F2.3 | Adversarial test suite (finite) | NOT RUN | — |
| F3.1 | Integer weak-duality check with quality theorem, witnesses and controls | DONE as a diagnostic outside the gate; pinned Dafny exit 0 (46 verified); two controls rejected | [Pillar III report](proposals/forge2-pillar3-dual-certificate/REPORT.md) |
| F3.2 | Solver evolution benchmark; new evidence method `certified_runtime_check` | NOT RUN; PROPOSAL NEEDED for `policy/`, `schemas/` | — |
| F4 | Schemas, three-regime benchmark, documents | NOT RUN | — |

## Order

F1.1 (done) → F3.1 (done) → F1.1d, F1.3 (no protected path) → proposals with
exact diffs for F1.1e, F1.2, F1.4, F3.2 → F2.0 design note → F2 build →
F4. Each step ends with real exits in the item's report and an
`unsure.md` entry.

## Relation to M1

M1 (the refund executable) stays open and is not cancelled. Its model
chain is complete to S6 (U409). Its open items are owner decisions
(profile, contract review), the real FFI boundary, the entry state and
the replays. M1 is the template and the cost measure for the Pillar II
binary claim. If the two compete for time, this file has priority by
the owner's word of 2026-11-17.

## Open decisions for the owner

1. Approve, change or reject each proposal for a protected path when
   it is ready (none is ready yet).
2. Is an optimizing batch-booking component wanted as an approved
   intent (new spec)? Pillar III needs it beyond the diagnostic.
3. Commit and push: done once on your word of 2026-11-17 ("push what we
   have", U412), on the backup branch only. Later commits need your word
   again. `main` is untouched; no pull request.
