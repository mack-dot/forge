# Master finish-line directive (Gates F1–F3; Goals 21–23): owner text, stored verbatim

Status: QUEUED, NOT STARTED. Received 2026-11-19. Pre-flight on receipt: FAILED (Goal 20,
`feat/zero-babysitting-sdk`, not merged: its orchestrator was still building; no PR). Per the
directive, work waits. This file is a record, not an authorization for any merge, protected-file
change, or stage promotion. `end_to_end=false`.

## Launcher notes for the briefs (not owner text)

- PR numbers in the directive (65–69) are predictions; the real numbers are used.
- F2a changes protected files (Stage 9 lock, `gate/ratification.py`): an isolated PR that the owner merges; no agent bypass.
- F2b benchmark: print the matrix and PAUSE for the owner's batch-size word before any trial runs.
- F3 paper and README: every number (for example "1.86 MiB", "220 kills", "248 LOC") is re-read from a recorded artifact with its SHA; a number in the directive is not evidence.
- "Weird-but-legal" Z3 queries: Dafny verifies each counterexample before it is shown; solver text alone is never a verdict (the `scripts/spec_clearing.py` rule).
- The back-translator receives only the formal spec AST/JSON, never the user's prompt.

## Owner text

MASTER FINISH-LINE DIRECTIVE: BRIDGE-1 INTENT ENGINE, STAGE 9 BENCHMARK,
FLAGSHIP README, AND REPRODUCIBLE TECHNICAL PAPER ("NEVER FAKE ANYTHING")

PRE-FLIGHT REQUIREMENT
- Check `git status` and `gh pr list`. Verify Goal 20 (`feat/zero-babysitting-sdk`,
  PR 65) is MERGED on `origin/main` before starting Gate F1. If Goal 20 is
  still OPEN or running, STOP immediately and wait.
- Do NOT touch untracked `.toolchain`, `node_modules`, or `results/`.
- Preserve ALL 6 prior evidence bundles byte-identical (`Slice 1`, `Slice 2`,
  `Slice 3`, `M1 Conformance`, `Goal 19 Silicon Sink`, and `Goal 20 SDK`) plus
  all `28/28` Stage EXITs and `check_frozen_pr_gate.py == 0`.
- Keep `end_to_end=false` explicit everywhere. Never mock, estimate, or invent
  a single proof count, latency, or benchmark row.

------------------------------------------------------------------------------
GATE F1 -- BRIDGE-1 INTENT ENGINE: BOUNDARY TABLES, Z3 SPEC RED-TEAMING, AND
BLIND BACK-TRANSLATION (Goal 21 -> PR 66)
Branch: `feat/intent-clearing-v2` from clean `origin/main` (post-Goal 20)
Touch `0` protected or frozen paths:
1. Upgrade Spec Clearing (`scripts/intent_clearing.py` + CLI subcommand in
   `bin/forge-airlock check-intent`, leaving `scripts/spec_clearing.py` intact
   so Slice 2's bundle stays byte-identical):
   - Exhaustive Branch-Boundary Table: For candidate policies/specs, use
     Dafny/Z3 witness extraction to generate and verify concrete input/output
     examples across each logical branch and threshold boundary (`cap - 1`,
     `cap`, `cap + 1`, reason sub-caps, cosign edge) so humans inspect a
     complete concrete truth table instead of a single `ACCEPTS` witness.
   - Z3 "Weird-But-Legal" Property Queries: Given sanity queries (e.g., "can
     `amount > shipping_paid` when `item_returned == false`?", "can `payout >
     captured`?"), query the solver; if satisfiable, verify the concrete
     counterexample in Dafny and print a plain-English warning question.
   - Blind Structural Restater / Back-Translator: Deterministically (or via an
     isolated zero-prompt reader that receives ONLY the formal spec AST/JSON,
     never the user's prompt) emit a plain-English bullet summary of every
     permitted branch, cap, and exclusion for side-by-side human comparison.
2. Build `scripts/exit_goal21_intent.py`:
   - Prove it catches planted "deterministic-but-wrong-intent" specs (e.g.,
     swapped VIP flag, coarse `$100` cap allowing `$80` on shipping, inverted
     boundary `<` vs `<=`) while passing clean specs.
   - `>= 15` mutated copies of `intent_clearing.py` fail for their named
     reason; 2 runs produce byte-identical SHA-256 bundles; 1 fresh-context
     adversarial review; clean scratch-clone check (`28/28` Stage EXITs + all
     6 prior bundles unchanged).
3. Push, open PR without admin bypass, check hosted `pr_check.py == 3`, print
   EXIT table + PR URL, and PAUSE for my squash-merge.

------------------------------------------------------------------------------
GATE F2 -- STAGE 9 CLEAN UNLOCK, SIGNED PROVENANCE & EMPIRICAL BENCHMARK
(Goal 22 -> PR 67 Lock + PR 68 Results)
Start from clean `origin/main` (post-Gate F1 merge):
1. Step F2a (Isolated Protected Lock Proposal -- PAUSE FOR MY MERGE):
   - Prepare the minimal exact-diff Stage 9 lock update (re-binding the stale
     digests and `gate/ratification.py` once now that feature gates are done).
   - Open this isolated lock PR, verify expected hosted gate status, and PAUSE
     for my review and merge before running Stage 9.
2. Step F2b (Deterministic Stage 9 Closeout + Checkpointed Benchmark Plan):
   - After my merge of the lock PR, run the hosted cryptographic signing run
     and all 6 deterministic Stage 9 EXIT cases (closing the last 2 dead Stage
     9 links so 100% of Markdown files in the repo have `0` broken links).
   - Before running multi-agent trials, print the exact checkpointed,
     resumable (`--resume`) Stage 9 benchmark matrix for Section 7 of our
     paper--proposing a right-sized, high-signal batch (e.g. 36-72 runs across
     Unit-Test Baseline vs. Reviewer Baseline vs. Forge Airlock measuring
     escaped boundary bugs/races/replays, human review bytes vs. code-diff
     bytes, and `0`-reproof solver swaps) and PAUSE for my batch-size word so
     subscription limits are respected.
   - Execute the approved batch, verify deterministic artifact integrity, open
     PR without admin bypass, and PAUSE for my merge.

------------------------------------------------------------------------------
GATE F3 -- FLAGSHIP `README.md`, SOSP-STYLE `FORGE_PAPER.md`, AND ONE-COMMAND
CLEAN-CLONE ARTIFACT RUNNER (Goal 23 -> PR 69)
Branch: `docs/paper-and-flagship-release` from clean `origin/main` (post-F2)
1. Build `scripts/reproduce_paper.py`:
   - From a fresh scratch clone, runs all Stage EXITs (including Stage 9),
     `check_frozen_pr_gate.py`, full-repo Markdown link check (`0` broken
     links across 100% of files), and verifies byte-identical SHA-256 digests
     across Slices 1-3, M1 Conformance, Goal 19 Silicon Sink, Goal 20 SDK, and
     Goal 21 Intent Clearing--printing one unified verification receipt table.
2. Write `docs/FORGE_PAPER.md` (10-12 page systems/security paper structure,
   clean Markdown + LaTeX math ready to export to PDF):
   - Sections: (1) Intro & Speed-vs-Safety Deadlock, (2) Threat Model,
     `Committed(e) ==>` Target & 45-Link Assurance Graph (`MACHINE-CHECKED` /
     `ASSUMPTION` / `TESTED-UNPROVED` / `MISSING`), (3) Bridge 1 & Pillar I:
     Spec Clearing, Non-Abstract Soundness Trap & Intent Red-Teaming, (4)
     Pillar II & Native Silicon Sink (`248` LOC `#![forbid(unsafe_code)]` Rust
     + `CakeML ARM64`, `1.86 MiB` RSS under 10 GiB flood, `F_FULLFSYNC`, `220`
     kills), (5) Pillar III: Weak LP Duality Runtime Certificates (`TS` /
     `Rust` / `Python` sandbox swaps, `0` solver runs, integrality-gap
     soundness), (6) Zero-Babysitting 5-Layer SDK & Unbreakable Store, (7)
     Stage 9 Empirical Evaluation, (8) Related Work (`Cedar`, `PACE`,
     `KedgeFlow`, `CakeML`, `Vericoding`) & Explicit Limits (`end_to_end=false`).
   - Cite ONLY verified repository numbers and exact commit/bundle SHAs.
3. Polish top-level `README.md`:
   - Lead with a 60-second **3-Line Python/TypeScript Quickstart**, the
     5-Layer Stack, the `1.86 MiB` Native Silicon Sink, Bridge 1 vs. Bridge 2
     honesty, link to `docs/FORGE_PAPER.md`, and the one-command
     `python3 scripts/reproduce_paper.py` challenge.
4. Run `reproduce_paper.py` + link check (`0` broken links repo-wide), push,
   open PR without admin bypass, and PAUSE for my final release merge.
