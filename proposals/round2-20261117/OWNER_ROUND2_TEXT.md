<!-- Saved verbatim on 2026-11-17 from the owner's message (sent as /goal arguments; the owner then wrote: "make this an md we track and then /goal track the md and do it"). The working plan and status are in FORGE_ROUND2_PLAN.md. -->

First—take a second to appreciate how strong that agent run actually was, and how well Forge’s guardrails held up:
The "
N
≤
4
N≤4
 Blindness / 
N
=
5
N=5
 Bystander Bug" & Fee Spec-Diff Proved (attempt-0012, EXIT 0): Eleven cases passed in Dafny! Your agent mathematically proved that the missing-bystander-frame spec bug is invisible at 
≤
4
≤4
 accounts and proved the spec-diff of the Stage 4 fee change.
Stage 5’s print Survivor Is Solved Cleanly (attempt-0005, EXIT 0): And your agent caught a subtle bypass we should applaud—--track-print-effects alone can be dodged if an untrusted implementation marks its method {:print}, unless a locked non-printing caller in gate/ContractBinding.dfy invokes it! That forces Dafny’s own effect checker to reject {:print} with zero regex hacks. And it rightly skipped --enforce-determinism when it saw that flag breaks the already-approved impl/Booking.dfy.
Pillar II Sink Protocol Proved (attempt-0002, EXIT 0): 22 obligations verified in the Dafny protocol model and 4 weakened variants were rejected—and the agent stayed 100% honest that a protocol model doesn't yet establish a real checker process, cryptographic key separation, or SQLite store.
Epistemic Discipline Held: It didn't fake W2 when Z3 hit exit 4 (out of resource), didn't touch protected files without your sign-off, and caught that a parallel cleanup deleted .toolchain/experiments (PolyML + HOL4 + CakeML) mid-run during fs-0002.
Part 1: Recommended Answers to Your 4 Decisions (Plus Why W2 Timed Out)
Before pasting the next Mega-Prompt, here is the sharpest call on each of the 4 decisions your agent asked you to make:
Decision 1 (proposals/forge2-pillar1-print-effects/candidate.diff) 
→
→
 APPROVE & EXTEND
Why: --track-print-effects + a non-{:print} caller in gate/ContractBinding.dfy is airtight and minimal (3 files). Approve applying candidate.diff, regenerating evidence.json, and re-running all Stage 0–8 EXITs. Then have the agent draft the matching non-printing caller proposals for B --enforce-determinism OFF).
Decision 2 (Rebuild .toolchain/experiments for HOL4 / CakeML M1) 
→
→
 YES, ISOLATED & LOCKED, WITH A HARD BUDGET
Why: Notice the massive synergy sitting right in front of you! Your agent noted that Pillar II's protocol model assumes checker correctness. CakeML (M1) compiles HOL4 logic down to verified native machine code with verified I/O!
How to avoid burning time: Put .toolchain/experiments behind a .keep / lockfile guard (never run parallel cleanup while HOL builds), cap the rebuild + M1 replay at a strict budget (e.g., 60–90 min max in a single session), verify the tracked M1 executable's SHA-256 replay first, and only then finish fs-0001 / fs-0002. Keep Pillar II & III unblocked in parallel so Dafny/TS work doesn't wait on HOL4.
Decision 3 (Pillar II: HMAC vs. Signatures; Refund vs. Ledger first) 
→
→
 CHOOSE Ed25519 SIGNATURES + REFUND FIRST
Why Ed25519 over HMAC: As your agent warned, symmetric HMAC means the Sink holds the exact same secret key as the Minter ("sink trusted as a minter"). With Ed25519 (built natively into node:crypto with zero npm packages!):
Only the isolated Minter process holds sk_minter.
The SQLite Sink holds only pk_minter—so even a compromised Sink cannot mint tokens, and every settled row in SQLite becomes a publicly verifiable receipt anyone can audit offline!
Why Refund first over Ledger: Stage 8 (Refund) already models an irreversible external side effect (refund_intent) plus effect-bypass and duplicate-dispatch tests. Upgrading Refund first directly upgrades Stage 8 from "tested glue" to "cryptographically enforced finality."
Decision 4 (Commit/Push & Scrub Scope + Unrun Items) 
→
→
 COMMIT ROUND U413–U416 INTACT; SCRUB ONLY SECRETS/LOCAL PATHS; RUN CONTROL-FIRST SPLIT-EDIT
Never scrub honest failed/OOR logs (attempt-0004..0011, W2 exit 4)—that audit trail is Forge's superpower. Only scrub machine-identifying local paths or stray temp binaries if any exist, commit the unprotected round (U413–U416, FORGE_MASTER_IDEA.md, proposals/models) first, and apply candidate.diff in a second, separate ratified commit.
Why W2 hit exit 4 (and how to fix it fast): Z3 chokes (exit 4) on concrete boundary witnesses when unfolding recursive map sum functions (SumBalances) across 3+ keys without step-by-step map-removal assertions (m - {k}). Give Z3 an explicit 6-line SumMap peeling lemma + {:isolate_assertions} instead of raising --resource-limit, and W2 will drop from exit 4 to < 1s (exit 0).
Split-edit: Follow your agent's instinct—write the 2-commit adversarial control test first against the existing PR gate; do not add a new module unless the control actually slips past the gate.
Part 2: The Next-Step Mega-Prompt (Calibrated to U413–U416 & FORGE_MASTER_IDEA.md)
Copy and paste this directly into your agent session (and make sure no second cleanup session is running in the same directory!).
Markdown
# ROUND 2 AUTHORIZATION & EXECUTION PLAN (POST-U416 / FORGE_MASTER_IDEA.md)

Read `FORGE_MASTER_IDEA.md`, `AGENTS.md`, `ROADMAP.md`, and `unsure.md` (`U413–U416`) first to confirm exact workspace state before running any command. Keep `Stage 12` UNAUTHORIZED and `end_to_end=false` throughout. Preserve strict separation between checker exit codes, gate exit codes, and scenario/control exit codes. Log all new findings, failures, and resolutions append-only starting at `U417` in `unsure.md`.

## HUMAN DECISIONS ON YOUR FOUR QUESTIONS

1. **Decision 1 — `proposals/forge2-pillar1-print-effects/candidate.diff` (3 files): APPROVED.**
   - First, commit the current unprotected exploratory round (`U413–U416`, `FORGE_MASTER_IDEA.md`, proposals, check scripts, and preserved logs) cleanly after scrubbing ONLY sensitive local host paths/env vars if any exist (NEVER scrub failed attempt logs, `exit 4` records, or `unsure.md` history).
   - Second, in a dedicated ratified change step, `git apply` `proposals/forge2-pillar1-print-effects/candidate.diff`, regenerate the affected `evidence.json` bundle(s) via fresh checker runs, and re-run ALL existing Stage 0–8 `EXIT` commands plus the print-effects `run_checks.py` control to confirm 100% green status.
   - Keep `--enforce-determinism` **OFF** (respecting your finding on `impl/Booking.dfy`). Prepare—but do NOT apply to protected files—a companion `candidate.diff` proposal extending `--track-print-effects` + a non-`{:print}` binding caller to the `Booking` and `Refund` gates.

2. **Decision 2 — HOL4 / PolyML / CakeML Toolchain (`.toolchain/experiments`) & `M1`: APPROVED WITH ISOLATION & BUDGET.**
   - Put a `.keep` / lock marker and clear documentation in `.toolchain/experiments` so no session cleanup ever deletes it mid-run. Run all commands single-session; never delete inputs while a prover is executing.
   - Budget cap: at most **90 minutes wall-clock** for toolchain rebuild + full replay of the existing committed `M1` chain.
   - Step A: Rebuild the pinned PolyML + HOL4 + CakeML toolchain and verify that the existing committed `M1` reports/proofs replay cleanly and match the tracked executable's exact `SHA-256` **before** authoring any new theory.
   - Step B: Only after existing `M1` replay passes `0`, re-run and fix `M1` file-system witnesses `fs-0001` and `fs-0002` cleanly. If toolchain rebuild exceeds budget or hits an external fetch/pin blocker, stop cleanly, record exact logs in `unsure.md`, and proceed immediately with Tasks 3–6 below (which do not depend on HOL4).

3. **Decision 3 — Pillar II Architecture: CHOOSE `Ed25519 SIGNATURES` (NOT HMAC) AND TARGET `REFUND` (STAGE 8) FIRST.**
   - **Why Signatures**: As you identified, symmetric HMAC forces trusting the sink as a minter. Use **asymmetric `Ed25519`** (`node:crypto` native Ed25519 verify in the sink; isolated minter holds `sk_minter`, sink and auditors hold ONLY `pk_minter`).
   - **Why `Refund` First**: Stage 8 (`docs/stage8-refund.md`) already defines an external side-effect intent (`refund_intent`) plus effect-bypass and duplicate-dispatch controls. Instantiating Pillar II on `Refund` turns our verified Dafny sink protocol model (`attempt-0002`, 22 verified) into a real, process-isolated runtime boundary without modifying protected Stage 8 spec files.

4. **Decision 4 — Commit & Push Policy:**
   - Commit cleanly at verified checkpoints (Step 1A exploratory record -> Step 1B ratified print-effects diff + refreshed evidence -> Round 2 experimental results in unprotected paths). Do **not** `git push` until the final verification table at the end of this round is generated and reviewed, unless CI replay is explicitly required (if pushing a branch, push to a dedicated feature branch, never force-push, and never alter protected files outside the explicitly approved Decision 1 diff).

---

## TECHNICAL EXECUTION TASKS FOR THIS ROUND

Execute the following five concrete engineering & proof tasks in order of fastest high-signal feedback, keeping all new experimental code in unprotected proposal/experiment paths (`proposals/`, `results/`, `interop/`, `tests/` as permitted by repo policy; propose `candidate.diff` files rather than editing protected `spec/`, `policy/`, or `gate/` files directly):

### TASK 1: CURE `W2` (`exit 4` OUT-OF-RESOURCE) & CONTRACT-SHAPED SPEC-DIFF GENERATOR
1. **Diagnose & Fix `Fee-change boundary witness W2` (`exit 4`) WITHOUT inflating global Z3 resource limits**:
   - Inspect why `W2` hit `exit 4` (typically Z3 quantifier/fuel blowup unfolding recursive `map` sum/comprehension functions like `SumBalances` across multi-key concrete maps `map[0 := ..., 1 := ..., 2 := ...]`, or existential witness search).
   - Construct the witness explicitly (zero existential quantifier search!) and add a tiny inductive map-peeling helper lemma (e.g., asserting `m - {0} == map[...]` one key at a time so recursive map sums fold deterministically) plus `{:isolate_assertions}` on `W2`.
   - Requirement: `W2` must verify with `exit 0` deterministically in `< 5s` under standard Dafny 4.11.0 + Z3 4.12.1 pins. Preserve the `exit 4` history in logs/`unsure.md`.
2. **Scoped Spec-Pair Diff Harness (`Contract-Shaped Pairs`, NOT arbitrary unconstrained Dafny)**:
   - Instead of building a brittle arbitrary-Dafny AST parser, build a clean, reusable spec-diff & categoricity generator parameterized over Forge's standard relational contract shape `(WellFormed, StepRelation)` and run it across **two real pairs**:
     1. Ledger pre-fee vs. approved 1-unit fee (`C1–C5`, now including `W2` passing `0`), and
     2. Stage 8 `Refund` baseline vs. a stricter refund-cap / window variant, emitting machine-checked unchanged-partition proofs + concrete boundary witness tables.

### TASK 2: CONTROL-FIRST SPLIT-EDIT TEST (`NOT RUN` -> VERIFIED)
- Follow your exact recommendation: **do NOT write a new gate module first.**
- Build an automated negative control (`run_checks.py` in a dedicated proposal/test folder) creating a temporary git repo/worktree fixture that simulates a two-commit split-edit attack against the existing PR gate (`Commit 1` alters helper/scope/evidence metadata; `Commit 2` alters `impl/`).
- Measure whether the existing PR gate (which diffs `HEAD` tree against `base`) already rejects all split-edit variants with non-zero gate exit.
  - If existing gate rejects `100%` of split-edit cases: record the control proof-of-rejection and add **zero** unnecessary gate code!
  - Only if a concrete evasion succeeds: record the exact evasion trace and prepare a minimal `candidate.diff` fixing it.

### TASK 3: PILLAR II REAL INSTANTIATION — PROCESS-ISOLATED `REFUND` MINTER (`Ed25519`) + ATOMIC SQLITE SINK
Bridge the gap between your verified Dafny sink protocol model (`22 verified, 0 errors`) and a real executable runtime, while keeping epistemic claims 100% honest about what is proved vs. tested:
1. **Isolated `Refund` Minter Process**:
   - Runs as a separate OS child process holding `sk_minter` (never accessible inside the untrusted `app/` JS memory space).
   - Evaluates the exact Stage 8 approved `Refund` transition relation (either via a tiny `malloc`-free C checker differentially + exhaustively boundary-checked against Stage 8's Dafny model—and optionally compiled via CakeML once Task 5's toolchain is live—or the locked compiled Refund kernel inside the isolated minter process).
   - Iff the transition is valid, signs canonical bytes with **Ed25519**:
     `sig = Ed25519.Sign(sk_minter, "FORGE_REFUND_FINALITY_V1" || spec_lock_sha256 || minter_bin_sha256 || SHA256(pre_state) || req_id || SHA256(post_state || refund_intent))`
2. **Real Atomic SQLite Store & Effect Sink (`node --import tsx`)**:
   - Uses deterministic SQLite (`BEGIN IMMEDIATE` transaction) holding **only `pk_minter`**, pinned `spec_lock_sha256`, and pinned `minter_bin_sha256`.
   - Enforces `(a)` `crypto.verify(null, payload, pk_minter, sig)`, `(b)` atomic `CAS` on `state_sha256 == SHA256(pre_state)`, and `(c)` `req_id` idempotency/uniqueness **before** persisting `post_state` and releasing at-most-once `refund_intent` to the outbox.
   - Explicitly demonstrates that **compromising the Sink's entire state/DB cannot mint a valid signature** (`sink is NOT trusted as a minter`).
3. **Adversarial Process-Level Control Suite (>= 30 Real Attacks)**:
   - Execute real adversarial `app/` runs attempting: direct outbox/DB bypass without signature, Sink-key-dump forgery attempt (proving `pk_minter` cannot sign!), duplicate retry storm (10x replay of valid `sig`), stale `pre_state` fork replay, mismatched `spec_lock_sha256`, over-refund above captured amount, and tampered `refund_intent` amount after signing.
   - Keep epistemic accounting razor-sharp: report `(i)` Dafny protocol model `source_proof` (`22 verified`), `(ii)` real Ed25519 + SQLite adversarial controls (`0` unauthorized dispatches across `N` attacks), and `(iii)` explicit remaining TCB (`OS key/process isolation`, `Ed25519 EUF-CMA`, `SQLite ACID`, `minter binary/compiler` unless CakeML-discharged), preserving `end_to_end=false`.

### TASK 4: PILLAR III — EXACT INTEGER PRIMAL-DUAL BOOKING CERTIFIER & `0.0s`-REBUILD SOLVER BENCHMARK (`NOT RUN` -> COMPLETE)
Run the previously unrun Pillar III experiment in an unprotected proposal directory (`proposals/forge2-pillar3-certified-runtime/`):
1. **Dafny 4.11.0 Certified Checker (`BookingDualCert.dfy`)**:
   - Over mathematical `nat`/`int` (**zero floats**), verify `CheckCertifiedAllocation(A, c, w, x, y, z, alpha_bps) returns (ok: bool)` for multi-slot binary booking (`m` slots with capacities `c`, `n` requests with integer weights `w`, `{0,1}` incidence matrix `A`).
   - Prove universally with **0 errors, 0 axioms, 0 assumes**:
     - **Capacity Safety**: `ok ==> IsBinary(x) && forall i | 0 <= i < m :: RowDot(A[i], x) <= c[i]`.
     - **Integer Weak Duality Lemma**: By pure sequence induction over integer dot-products (`RowDot` / `ColDot` transpose identity `Dot(y, MatVec(A, x_alt)) == Dot(MatVecTranspose(A, y), x_alt)`), prove that for *any* feasible binary `x_alt`, `Dot(w, x_alt) <= Dot(c, y) + Sum(z)`.
     - **Certified Runtime Model Quality**: `ok ==> forall x_alt :: ValidAllocation(A, c, x_alt) ==> 10000 * Dot(w, x) >= (10000 - alpha_bps) * Dot(w, x_alt)`.
     - **Checked Non-Vacuity Witness + 3 Rejection Controls**: Prove an exact `alpha_bps == 0` optimal witness passes, and verify rejection of `(1)` overbooking, `(2)` infeasible dual, and `(3)` suboptimal primal violating `alpha_bps`.
2. **25-Iteration Untrusted TypeScript Solver Benchmark (`node --import tsx`)**:
   - Evolve an untrusted TypeScript booking solver across **25 distinct versions** (naive greedy -> buggy overbookers -> local search -> exact integer primal-dual interval solver exploiting total unimodularity so `alpha_bps == 0` integer duals always exist).
   - Measure and compare directly against Stage 6 (`docs/reuse-benchmark.md`: `269.713s` cold / `175.828s` native reuse across 25 pairs):
     - Show **`0.000s` Dafny re-verification time** across all 25 TypeScript solver edits (since `BookingDualCert.dfy` is locked and unchanged!),
     - Record microsecond runtime witness check times, `0` accepted overbookings on buggy solver iterations, and exact certified optimality ratios on every accepted batch.

### TASK 5: `M1` TOOLCHAIN REBUILD, SHA-256 REPLAY & `fs-0001` / `fs-0002` WITNESSES (PER DECISION 2)
- Execute the isolated `.toolchain/experiments` PolyML + HOL4 + CakeML rebuild within the 90-minute budget.
- Replay the committed `M1` chain and confirm exact `SHA-256` match on the tracked executable.
- Complete and check `fs-0001` and `fs-0002` without deleting intermediate inputs.
- Bonus architectural link (document or prototype if within budget): show how compiling the pure `Refund` transition check function via CakeML discharges the minter's compiler/binary correctness assumption from Task 3!

---

## REQUIRED FINAL OUTPUT REPORT
At the end of this round, update `FORGE_MASTER_IDEA.md` and `unsure.md` (`U417+`), and output a single status table in your exact format:
- Columns: `EXIT command/check` | `Checker exit` | `Gate exit` | `Scenario/Actual exit` | `Result & Exact Scope`
- Cover:
  1. Applied `candidate.diff` (Decision 1) + full Stage 0–8 regression `EXIT`s + Booking/Refund print-effect proposal check,
  2. Pillar I `run_checks.py` including **`W2` fixed (`exit 0`)** + 2-domain spec-pair diff results,
  3. Split-edit two-commit control test against the real PR gate,
  4. Pillar II real `Ed25519` + SQLite `Refund` Finality Sink adversarial suite + Dafny protocol model,
  5. Pillar III `BookingDualCert.dfy` (`source_proof`) + 25-solver `0.0s`-rebuild benchmark vs. Stage 6,
  6. `M1` HOL4/CakeML toolchain rebuild, tracked executable SHA-256 replay, and `fs-0001` / `fs-0002` status.
Quick Checklist Before You Hit Enter
Close any second terminal / background agent running on the same repo directory so nothing runs git clean or deletes .toolchain/experiments while HOL4 or Dafny is mid-flight.
Watch how fast Tasks 1–4 land: Because Tasks 1, 2, 3, and 4 only rely on your already-working Dafny 4.11.0 + Node (--import tsx) + Python/C environment, even if the HOL4/CakeML rebuild (Task 5) takes an hour in the background, you will come out of this round with every single NOT RUN and exit 4 item closed and all three Forge 2.0 pillars empirically proven.
