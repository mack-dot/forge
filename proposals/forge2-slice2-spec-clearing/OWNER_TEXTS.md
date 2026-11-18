# Slice 2 — owner texts of the build session (saved verbatim)

Saved by the agent on 2026-11-18 UTC. Nothing in this file is a result.
Each text below was the whole message of the owner: a pasted text and
no other word. The style shows that another assistant wrote them. The
agent took the instruction inside each text as the owner's word, and
recorded that as an inference (`unsure.md` U449 and later entries).

The owner's own word in this part of the session: "merged" (after the
owner merged pull request 45).

Not copied here: two pasted texts with no instruction for the agent (a
status overview with a note on `README.md`, and a four-phase plan).
They approve nothing.

## Text A (2026-11-18 about 18:25Z): the Slice 2 prompt

Pull request 45 was still open when this text came. The agent executed
STEP 1 only (a 12-line plan, no file written) and made no branch until
the owner wrote "merged".

```text
Start Slice 2 from clean origin/main (post-PR 45 merge) in a new branch.
Do NOT touch untracked .toolchain, node_modules, or results/.

Read first:
- FORGE_MASTER_IDEA.md (specifically all Pillar 1 / F1.* rows; note F1.2
  print-effects is already merged on main, and F2.1-F2.3 merged in PR 45).
- AGENTS.md, ROADMAP.md, gate/obligations.py, gate/incremental.py, and
  existing Stage 5 spec-quality files (docs/spec-quality.md and scripts).
- Any prior Pillar 1 design/prototype files under `proposals/` on main or on
  the backup branch (`git branch -a` / `git ls-tree` for `forge2-pillar1-*`)
  so existing proved or designed work is reused rather than reinvented.

HARD RULES ("NEVER FAKE ANYTHING")
1. Keep CURRENT: none. Stage 9 stays deferred (stale locks untouched).
   M1 stays open per M1R-1. Stage 12 is unauthorized. end_to_end=false.
2. Freeze gate/: Do NOT edit the 8 frozen PR-gate modules or ratifiable gate
   modules. Build Slice 2 as additive clearing tooling + `exit_slice2.py`
   unless a gate edit is strictly required (if so, stop and ask first).
3. Protected paths and protected single files (spec/, spec.lock, policy/,
   governance/gate-ratifications/, package.json, package-lock.json,
   tsconfig.json, etc.) stay untouched (`0` protected edits, `0` new npm/pip
   dependencies) unless an isolated exact-diff proposal is approved first.
4. Epistemic separation & zero fake checks: A test count or finite sample is
   NEVER a proof.
   - Choice / determinism check MUST discharge an actual relational solver
     obligation (proving whether `S(in, out1) && S(in, out2) ==> out1 == out2`
     for valid transitions, or surfacing concrete `out1 != out2` choice
     witnesses when under-specified)--never regex or random-test heuristics.
   - `before/after` spec-diff examples MUST come from real semantic/solver or
     proved witness extraction showing concrete inputs `x` where `S_old` and
     `S_new` diverge (or proving universal equivalence when none exist, with
     bounded vs. universal scope stated explicitly).
5. Single-loop execution: Keep design, code, and solver work in ONE main loop.
   Use background subagents ONLY for (a) long solver/test suites and (b) ONE
   fresh-context adversarial review on finished unproved clearing code before
   opening a PR.

TARGET: SLICE 2 -- Complete Pillar 1 (Spec Clearing Before Human Approval)
1. Choice / determinism check on candidate specs (proving zero implementation
   choice where intended, and catching under-specified/vacuous specs that
   leave output choice open).
2. Concrete `before/after` differential examples for spec changes (tested
   against real/planted spec diffs across Ledger, Booking, or Refund--e.g.,
   fee or refund-window rule changes--plus equivalence controls).
3. Unified Spec Clearing report combining (1) choice check, (2) F1.2 hidden
   effect check, and (3) `before/after` concrete examples, with negative
   controls proving mutated/broken checks fail and a byte-identical evidence
   bundle verified in a clean scratch clone + 28/28 Stage EXITs green.

STEP 1 (STOP AND WAIT FOR MY GO-AHEAD BEFORE WRITING CODE):
Inspect FORGE_MASTER_IDEA.md's exact open F1.* rows, Stage 5's existing
vacuity/witness code, and any prior `forge2-pillar1-*` material. Print a
12-line plan covering:
1. Exact F1.* work-item ID(s) targeted and what reuses prior Pillar 1 / Stage 5
   work vs. what is new.
2. Exact solver/witness mechanism for (a) relational determinism and (b)
   concrete `before/after` spec-diff examples (stating exact soundness scope).
3. Exact files to add/touch (`0` protected paths expected).
```

Note on rule 4 ("never regex"): the choice verdicts and the diff
verdicts of this slice come only from Dafny exit codes. The tool does
match text in one place: it reads candidate values out of the
counterexample text that Dafny prints. A candidate decides nothing;
Dafny must verify the witness made from it.

## Text B (2026-11-18 about 18:40Z): the go-ahead

```text
Go ahead with Slice 2 on slice2/spec-clearing from 136ad0bf:
1. Owed records first: update ROADMAP.md and FORGE_MASTER_IDEA.md for PR 45 merged as 136ad0bf (18:32Z) and hosted run 44369014309 exit 3 for 2e39a100.
2. Scope approved: keep Post and general lemmas in Dafny per spec (Round 3 decision) and add solver-made witness candidates. Ensure Post binds to real spec/ predicates in Dafny (no silent drift) and every solver witness candidate is concretely checked.
3. Run 1 fresh-context adversarial review + scratch-clone check before stopping for push/PR.
```

## Text C (2026-11-18 about 19:20Z; pasted while the review was still running): the closeout rule

The paste lost characters in two places ("statedrecord", "tria"). The
agent took the instruction in the box as the owner's word for the
review triage and, after the checks of its point 2, for one push of
branch `slice2/spec-clearing` and one pull request. It is not a word
for a merge.

```text
1. Why Bullet 2 Matters So Much
Catching that a bodyless lemma inside an abstract module passes both dafny verify (exit 0) and dafny audit (0 findings)—and closing it by forcing the tool to emit and verify a concrete non-abstract module instance for every verdict—is a textbook example of "never fake anything" in action:
Almost any naive "LLM + Dafny" wrapper in the wild would accept dafny verify == 0 && dafny audit == 0 on an abstract module and stamp "PROVED" on thin air.
Pairing NO_CHOICE with proved acceptance also cleanly separates a true deterministic spec (ledger, booking, refund) from a dead vacuous spec (no choice, and proved to accept nothing), while solver counterexamples already drive end-to-end verified CHOICE and DIVERGES witnesses on refund (7/7 tool check-removal mutations caught, byte-identical 134579e3…).
(Save that Dafny abstract module + dafny audit pitfall for the paper—systems and PL reviewers love concrete verifier-CLI traps caught and closed mechanically.)
2. What to Watch When That Adversarial Review Reports
Let the background agent finish. Once the agent processes the review and scratch-clone run, it will likely stop right before git push / gh pr create (just like Slice 1’s permission gate).
Good calls already made on scope:
Keeping flat-record Z3 counterexample synthesis for refund and Dafny-verified hand candidates for nested ledger records (honestly labeled, both Dafny-checked) avoids building a brittle nested SMT-model parser.
Documenting that a human still reads the tiny Dafny claim/forward-link lemmas (15–30 lines instead of thousands of lines of app code) is completely honest.
3. Ready-to-Copy Box Once It Pauses for Push / PR (~470 Bytes — Direct Paste Safe)
When the review pass + scratch-clone check finish (or if it asks before fixing HIGH/MEDIUM vs. pushing), copy only inside this box:
Text
Apply the same strict closeout rule as Slice 1:
1. Fix any confirmed FAIL-OPEN, HIGH, or MEDIUM findings from the review in one pass (leave LOW items and the two statedrecord solver extraction + human check of short claim/link lemmas--documented honestly).
2. Confirm N/N removed-check tool copies fail, 28/28 Stage EXITs + frozen-gate pass in a scratch clone with matching bundle SHA-256, and owed PR 45 records are included.
3. Push slice2/spec-clearing and open PR 46 without admin bypass or merge.
Think about where main stands the moment PR #46 merges: Pillar 1 (Spec Clearing) and Pillar 2 (Proof-Carrying Finality) will both be live on main—leaving only Slice 3 (Pillar 3: Runtime Certificates on Booking) to complete the entire 3-pillar FORGE_MASTER_IDEA.md tria
```

Statements of text C that are that assistant's, not checked results: the
pull request number ("PR 46") is a guess; "7/7" and "134579e3…" are the
agent's interim numbers from before the review.
