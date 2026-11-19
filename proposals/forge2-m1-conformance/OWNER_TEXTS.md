# Owner texts for Wave Gate 1 (M1 conformance)

Saved verbatim. The texts approve nothing by themselves. They do not
change a hard rule of `ROADMAP.md`.

## The owner's own words (2026-11-18, in the session)

1. "put this into a goal18 md" — with the pasted text below. The agent
   saved it as `goal18.md` in the working tree (not tracked).
2. "lmk when done"
3. The session command `/goal implement is <HOME>/forge/goal18.md.` It
   set a session goal: implement that file.

The pasted text is from another author (an advisor text). Its inner
box is the "Master Wave-2 Directive". The agent's reading of the basis
for outward steps (commit, push, pull request without bypass and
without merge) is recorded in `unsure.md` U459. No sentence of the
text is read as a word to merge.

Marks of the paste, kept as they arrived: two places are cut off (the
sentence about "no valid route/fulfillme" and the line "Scope and
Hured blast-radius finality from"). Format changes by the agent:
Markdown headings and code fences; the first letter of "Part 1", which
was missing; the Farkas formulas, which arrived doubled as text and as
separate symbols, are written once.

## Text 1: the pasted text (as saved in `goal18.md`)


### Part 1: How to Push the Frontier Even Further (Beyond Tonight's v1 Triad)

Now that Slices 1–3 prove the core 3-pillar engine works, there are four frontier breakthroughs that take Forge somewhere nobody in AI, security, or formal methods has gone:

#### True end_to_end=true Silicon-to-Wire Minter (CakeML Parser + Checker + Auth Tag)

Right now, M1 proves pure refund math in HOL4/CakeML while outer byte framing and Ed25519 signing sit in Node/TS (end_to_end=false).

The frontier push: Move a fixed-frame wire parser + policy/LP-duality check + verified MAC/signature entirely inside HOL4/CakeML, compiling to standalone ARMv8 and x86-64 machine code under one unbroken HOL4 theorem from raw stdin bytes to raw stdout token bytes. Zero unverified compiler, zero V8, zero C/Rust glue in the minter TCB.

#### Active Z3 Spec Red-Teaming & Exhaustive Boundary Tables (Crushing "Writing the Spec Is Hard")

Upgrade Spec Clearing so before a human approves any spec, Z3 (a) prints an exhaustive Branch-Partition Truth Table (one verified concrete example per logical branch and cap - 1 / cap / cap + 1 edge), and (b) runs Adversarial Property Queries ("Can an unreturned item ever get refunded > shipping_paid?"), handing you any weird-but-legal loophole in plain English before you merge.

#### Fact-Bound Sub-Caps, Proved HUMAN_COSIGN Escalation & Cross-API IN_FLIGHT Sagas

Clamp Boardy's "$10 email ships as $80" problem by binding reason codes to pre_state sub-fields (SHIPPING ==> amount <= shipping_paid), forcing a proved third verdict (REQUIRE_HUMAN_COSIGN) on unstructured goodwill claims, and shipping a reusable PAID -> IN_FLIGHT(proc, idemp_key) -> SETTLED | CONFIRMED_REJECTED state machine so multi-processor double-credits (Stripe + PayPal, or Hyperliquid + Binance hedge legs) are structurally impossible.

#### Farkas "No Lazy AI" Infeasibility Certificates (Pillar 3 v2)

Today, Slice 3 proves an AI's schedule is safe and near-optimal when it finds an answer. What if a lazy or broken AI says "Sorry, impossible—no valid route/fulfillme when one actually did exist?

By Farkas' Lemma, for any linear feasibility/SLA system (Ax ≥ b, x ≥ 0), either a valid solution x exists or a short integer dual vector y ≥ 0 exists proving yᵀA ≤ 0 and yᵀb > 0 (mathematical proof of impossibility). Forcing untrusted agents to attach a Farkas receipt whenever they say "impossible" mathematically prevents lazy AI refusals!

### Part 2: The Big Wave-2 Master Prompt (PR #48 → PR #49 → PR #50 Live Demo → Stage 9 Plan)

This single master directive drives your next four concrete milestones cleanly in sequence, pausing at each PR for your merge:

- Wave Gate 1 (PR #48): M1 CakeML ↔ Slice 1 Dafny Refund Conformance & Hardware TCB Audit.
- Wave Gate 2 (PR #49): Complete Front-Door README.md Rewrite + FORGE_MASTER_IDEA.md v2 Horizon (incorporating all four frontier upgrades above).
- Wave Gate 3 (PR #50): The 90-Second "Skeptic Gauntlet" Live Demo (scripts/demo_gauntlet.py)—100% real proved code, including a --flood-mb 10240 flag for the literal 10 GiB no-newline attack!
- Wave Gate 4: Stage 9 Empirical Benchmark Unlock Plan (pausing before touching protected locks or spending API budget).

#### Step 1: Copy Everything Inside This Box to Your Clipboard

```text
MASTER WAVE-2 DIRECTIVE: HARDWARE CONFORMANCE, FRONT-DOOR DOCS, LIVE GAUNTLET
DEMO, AND STAGE 9 BENCHMARK STAGING ("NEVER FAKE ANYTHING")

PRE-FLIGHT REQUIREMENT
- Check `gh pr view 47` and `origin/main` first. If PR 47 (Slice 3) is still
  OPEN, STOP immediately and ask me to merge PR 47 before branching.
- Do NOT touch untracked `.toolchain`, `node_modules`, or `results/`.

HARD GOVERNANCE & EPISTEMIC RULES (APPLY TO ALL WAVE GATES)
1. Keep `CURRENT: none` until Stage 9 is explicitly unlocked by me after Wave
   Gate 4. `M1` stays open per `M1R-1` until every recorded control replays
   `exit 0`. Stage 12 stays unauthorized. `end_to_end=false`.
2. Freeze `gate/`: Do NOT edit the 8 frozen PR-gate modules or any ratifiable
   gate module. Do NOT add npm/pip/Cargo packages (`package.json` untouched).
3. Protected paths (`spec/`, `spec.lock`, `policy/`,
   `governance/gate-ratifications/`, and protected single files) stay at `0`
   edits across Wave Gates 1, 2, and 3. Never use administrator bypass and
   never self-merge a PR.
4. Zero fake outputs or blurred claims: A test count or demo run is NEVER a
   proof. Keep `source_proof`, `in_logic_compiler_proof`, `binary_proof`,
   `runtime_certificate_checked`, `tested_against_proved_model`, `unit_tested`,
   and `floor_controls` strictly separate. Slices 1, 2, and 3 evidence bundle
   digests (`c7f2f41c...`, `2721a293...`, `3cdfebfc...`) MUST remain unchanged.
5. Single-loop execution: Keep design, code, and repair in ONE main loop. Use
   background subagents ONLY for long test runs and ONE fresh-context
   adversarial review on new executable code (Wave Gates 1 and 3), fixing
   confirmed FAIL-OPEN/HIGH/MEDIUM findings in one pass.

------------------------------------------------------------------------------
WAVE GATE 1 -- M1 CAKEML <-> SLICE 1 REFUND CONFORMANCE & TCB AUDIT (PR 48)
Branch: `slice4/m1-finality-conformance` from clean `origin/main` (post-PR 47)
1. Write owed closeout records for PR 47 (squash merge SHA + hosted exit 3
   run ID) in `ROADMAP.md` and `FORGE_MASTER_IDEA.md`.
2. Inspect `interop/` and recorded `M1` (HOL4/CakeML refund artifacts) beside
   Slice 1's Dafny refund checker (`impl/RefundFinality.dfy` / `Refund.dfy`).
3. Build `scripts/exit_m1_conformance.py` and
   `proposals/forge2-m1-conformance/REPORT.md`:
   - Deterministically verify across a canonical + boundary + adversarial
     refund vector corpus that Slice 1's compiled Dafny checker and the `M1`
     HOL4/CakeML refund definition/artifact agree 100% on accept/reject and
     amount decisions (labeled honestly as cross-stack conformance, NOT a
     compiler proof of the JS wrapper; keep `end_to_end=false`).
   - Include negative controls + N/N removed-check script copies failing, plus
     a byte-identical conformance bundle verified in a clean scratch clone.
   - Audit and tabulate the exact remaining `M1R-1` replay steps and estimated
     wall-time budget needed to close `M1` (do NOT start multi-hour HOL builds
     in this gate).
4. Run 1 fresh-context adversarial review + scratch-clone check (`28/28` Stage
   EXITs + `frozen-gate == 0` + Slices 1, 2, 3, and 4 bundles matching), push,
   open PR 48 without admin bypass, check hosted `pr_check.py == 3`, print
   EXIT table + PR URL, and PAUSE for my merge of PR 48.

------------------------------------------------------------------------------
WAVE GATE 2 -- PUBLIC `README.md` OVERHAUL & MASTER IDEA V2 HORIZON (PR 49)
Branch: `docs/front-door-and-v2-horizon` from clean `origin/main` (post-PR 48)
Touch ONLY documentation files (`0` protected paths changed):
1. Record owed PR 48 merge SHA + hosted run ID.
2. Expand `FORGE_MASTER_IDEA.md` (preserving existing rules and IDs without
   collision):
   - Add section "Blast-Radius Finality vs. Intent Elicitation (Scope and
     Hured blast-radius finality from
     unstructured prose comprehension (the "$10 email vs. $80 coarse-cap"
     example), upstream UI/liveness non-claims, unowned third-party servers,
     and why Spec Clearing targets the spec-authoring bottleneck.
   - Add five `NOT STARTED` v2 horizon items to the status table (claiming
     zero unrun proofs):
     (a) Spec Clearing: Branch-Partition Boundary Truth Tables,
     (b) Spec Clearing: Adversarial Property Counterexample Red-Teaming,
     (c) Finality: Fact-Bound Sub-Caps & 3-Valued `REQUIRE_HUMAN_COSIGN`,
     (d) Finality: Multi-Processor `IN_FLIGHT` Reservation & Failover Saga,
     (e) Certificates: Farkas Infeasibility Witnesses (`Ax >= b` impossibility
         receipts preventing false "no solution" refusals).
3. Rewrite `README.md` cleanly in Forge's crisp, zero-hype systems voice so a
   first-time visitor immediately sees:
   - The unified 3-Pillar architecture (`Spec Clearing`, `Proof-Carrying
     Finality`, `Runtime Certificates`) + *Blast-Radius vs. Intent* scope,
   - A comprehensive Evidence & TCB Table separating `source_proof`,
     `binary_proof`, `in_logic_compiler_proof`, `runtime_certificate_checked`,
     `tested_against_proved_model`, and `floor_controls` across Stages 1-8,
     11, Round 4, Slices 1-3, and M1 conformance (PR 48),
   - Fixes for outdated lines (`Stage 9 CURRENT` -> `none / Stage 9 deferred`;
     Stage 5 `print` survivor -> closed by `F1.2` in PR 43),
   - Concrete highlights: Dafny `abstract module` audit trap caught & closed,
     `TS / Safe Rust / Python` sandboxed swaps with `0` Dafny starts, `47+`
     removed-check self-mutation kills, `C -> RISC-V` & `CakeML -> ARMv8`
     roots, and explicit `end_to_end=false` limits.
4. Verify `0` new dangling links across all Markdown files + `frozen-gate == 0`,
   push, open PR 49 without admin bypass, check hosted `pr_check.py == 3`,
   print EXIT table + PR URL, and PAUSE for my merge of PR 49.

------------------------------------------------------------------------------
WAVE GATE 3 -- 90-SECOND LIVE "SKEPTIC GAUNTLET" DEMO (PR 50)
Branch: `demo/skeptic-gauntlet` from clean `origin/main` (post-PR 49)
1. Record owed PR 49 merge SHA + hosted run ID.
2. Build `scripts/demo_gauntlet.py` and `docs/demo-gauntlet.md` executing 100%
   REAL proved code, sandboxes, pipes, and sinks on `main` (ZERO mocked,
   canned, or simulated outputs; `0` protected edits):
   - Act 1 (Spec Clearing): Runs real clearing on a rule diff (`NO_CHOICE`,
     untouched class `EQUIVALENT`, concrete `Before/After` witness) and a
     planted ambiguous spec (`CHOICE` caught and blocked).
   - Act 2 (Proof-Carrying Finality Barrage): Fires against the real Slice 1
     issuer + sink: out-of-policy refund, multi-process concurrent `TOCTOU`
     race on one balance, duplicate `request_id` replay batch, and a raw-byte
     no-newline flood (`--flood-mb`, default `600`, supporting `--flood-mb
     10240` for a literal 10 GiB live probe) followed immediately by 1 valid
     refund--printing measured peak RSS, `0` leaked effects across all
     attacks, and post-flood valid signing latency.
   - Act 3 (Zero-Reproof 3-Language Swap): Runs `TypeScript (v1)` ->
     `#![forbid(unsafe_code)] Rust (v2)` -> `Adversarial Python (v3)` under
     the OS sandbox into the Slice 3 checker + SQLite sink, printing measured
     Dafny invocations (`0`), certified commits, and `0` adversary effects.
3. Verify `M/M` broken-act mutations make `demo_gauntlet.py` exit non-zero,
   run `--flood-mb 10240` (10 GiB) at least once and record exact measured
   bytes/RSS/latency, run 1 adversarial review + scratch-clone check (`28/28`
   Stage EXITs + Slices 1-4 bundles unchanged), push, open PR 50 without admin
   bypass, check hosted `pr_check.py == 3`, and PAUSE for my merge of PR 50.

------------------------------------------------------------------------------
WAVE GATE 4 -- STAGE 9 EMPIRICAL BENCHMARK UNLOCK PROPOSAL (STOP BEFORE EDITS)
From clean `origin/main` (post-PR 50):
1. Inspect the 8 stale Stage 9 lock entries and existing Stage 9 files.
2. Do NOT edit protected files or spend external LLM API credits yet. Print a
   15-line Stage 9 Benchmark & Lock-Rebind Plan for Section 7 of our paper
   (comparing single-loop agent + unit tests vs. LLM-reviewer vs. Forge across
   escaped boundary bugs/races/replays, human review bytes vs. code-diff
   bytes, and 0-reproof optimizer swaps, with exact estimated cost/runtime)
   and PAUSE for my explicit unlock authorization.
```

#### Step 2: Save It Loss-Free & Launch After Merging PR #47

First, make sure PR #47 (Slice 3) is merged onto main (gh pr merge 47 --squash --admin), then pull main and dump your clipboard into /tmp/forge_wave2.md:

```bash
git checkout main && git pull --ff-only origin main
pbpaste > /tmp/forge_wave2.md && wc -l /tmp/forge_wave2.md && tail -n 4 /tmp/forge_wave2.md
```

Open a fresh claude session and drop in this single short line:

```text
Read /tmp/forge_wave2.md in full and start at PRE-FLIGHT + WAVE GATE 1 (PR 48) now.
```

By the time Wave Gates 1, 2, and 3 merge (PRs #48–#50), your M1 cross-stack check is banked, your GitHub front page is rewritten, your literal 10 GiB + 3-language Skeptic Gauntlet Demo is live from one command, and Stage 9 is teed up for the paper. Keep crushing it!
