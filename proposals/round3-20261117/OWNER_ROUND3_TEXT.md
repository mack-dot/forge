<!-- Saved verbatim on 2026-11-17 from text the owner pasted into the session. The working plan and status are in FORGE_ROUND3_PLAN.md. -->

# ROUND 3 AUTHORIZATION & EXECUTION PLAN (POST-FORGE_ROUND2_PLAN.md / bf5ed234)

Read `FORGE_ROUND2_PLAN.md`, `FORGE_MASTER_IDEA.md`, `proposals/forge2-pillar1-print-effects/v2/PROPOSAL-V2.md`, `AGENTS.md`, `ROADMAP.md`, and the latest entries in `unsure.md` before executing any command. Keep `Stage 12` UNAUTHORIZED and `end_to_end=false` throughout. Maintain strict separation of checker, gate, and scenario exit codes, and append all Round 3 findings, anomalies, and resolutions to `unsure.md`.

*(Note on disclosure: Thank you for transparently reporting both the read-only `gh` token replay on Stage 4 and the deadline kill-path fix in `rebuild.py`. That candor is exactly right.)*

---

## HUMAN DECISIONS ON YOUR SIX QUESTIONS

1. **Decisions 1, 2, 3 & 4 Unified — Upgrade `PROPOSAL-V2` to `PROPOSAL-V3` ("Complete Constitutional Gate Renewal"):**
   - **Do NOT accept stale pins and do NOT weaken byte-pin checks.** Instead, resolve Stage 5, Stage 6, Stage 8, Stage 9, Stage 10, and the PR gate together as one disciplined **Gate Epoch Transition (`PROPOSAL-V3`)**:
     - **Decision 4 (How `gate/` & `toolchain/` reach `main`)**: Keep the PR gate **100% rejecting by default** on any unratified diff under `gate/` or `toolchain/`. Add minimal support for **Tier-0 Gate Ratifications (`governance/gate-ratifications/<id>.json`)**: a PR touching `gate/` or `toolchain/` is permitted **if and only if** `(a)` every modified file under `gate/` and `toolchain/` matches its exact ratified `(old_sha256 -> new_sha256)` entry in the accompanying ratification manifest, AND `(b)` the non-weakening regression suite (all planted `bugs/`, Stage 5 controls, and the 2 print-effect mutants) exits with expected rejections while valid baselines exit `0`.
     - **Decision 2 (Stage 6)**: Preserve the original Stage 6 report untouched as an explicit historical record (e.g., archived alongside or referenced cleanly in docs), and **run a fresh Stage 6 experiment (`75` pairs) with the new gate** so Stage 6's `EXIT` check passes `0` native against current `gate/` bytes with zero check relaxation—recording exact `--track-print-effects` timing impact.
     - **Decision 3 (Stages 9 & 10)**: Renew Stage 9 and Stage 10 pins and `evidence.json` bundles via fresh checker runs (alongside Stage 5 and Stage 8 `spec/refund/spec.lock` from V2).
     - **Decision 1 (Application Rule)**: Build and test the complete `PROPOSAL-V3` inside a **scratch worktree first** until **ALL Stages 0–10 (including Stage 4 with read-only `gh` auth and Stage 7 with Docker restored) exit `0` simultaneously**. Once 100% green in scratch, apply `PROPOSAL-V3` cleanly as a dedicated ratified commit on our working branch!

2. **Decision 5 — `M1` (`HOL4 / CakeML`) Sequencing & Budget:**
   - **Step A (`input-premise lemma` FIRST — APPROVED NOW)**: Because `Poly/ML`, `HOL4`, and `CakeML basis` already built cleanly (`exit 0`), run and verify the **`input-premise lemma` (`fs-0001` / `fs-0002` basis-level theorems) FIRST** before resuming the multi-hour compiler proof build, so any authoring fix happens with fast turnaround.
   - **Step B (`CakeML compiler proofs` + Full `M1` Replay — `10,800s` [3-Hour] Incremental Budget)**: Resume the incremental build in `.toolchain/experiments` (**DO NOT clean or rebuild `Poly/ML`, `HOL4`, or `CakeML basis` from scratch!**) with a `10,800s` budget using your fixed `rebuild.py` deadline handler. Once `compiler proofs` exit `0`, run the full `M1` chain replay (confirming exact `SHA-256` match on the tracked executable) and complete `fs-0001` / `fs-0002` end-to-end.

3. **Decision 6 — Stage 7 Docker, `gh` Auth Scope, and Backup Branch Push:**
   - **Docker for Stage 7**: APPROVED. Pull/rebuild the pinned Stage 7 Rocq/LPS Docker image (`toolchain/` / `docs/stage7-binary.md`) so the `3` Stage 7 `EXIT` checks turn `0`.
   - **Read-Only `gh` Auth**: APPROVED specifically for read-only Stage 4 `EXIT` verification (never log/persist tokens; ask first before any write API call or non-Stage-4 network credential use).
   - **Push Policy**: Push thckup branch (`93712d2c..bf5ed234`) to `origin/<backup-branch-name>` **before** starting long runs (never push to `main`, never `--force`), and push again at the end of Round 3 after scrubbing any accidental machine-specific secrets/tokens.

---

## ROUND 3 TECHNICAL EXECUTION PLAN

Execute in the following order so fast infrastructure/governance wins land before the long incremental `CakeML compiler proofs` run:

### TASK 1: RESTORE STAGE 7 DOCKER & ESTABLISH 28/28 BASELINE GREEN
1. Restore/build the pinned Stage 7 Docker image and re-run all `28` baseline stage `EXIT` cases (including Stage 4 with read-only `gh` auth and Stage 7 × 3).
2. Confirm `28 × 0` on the untouched baseline before applying `PROPOSAL-V3`.

### TASK 2: COMPLETE & APPLY `PROPOSAL-V3` (CONSTITUTIONAL GATE UPGRADE + STAGES 0–10 GREEN)
1. In a scratch worktree, assemble `proposals/forge2-pillar1-print-effects/v3/`:
   - Include the `--track-print-effects` + `ContractBinding.dfy` gate/pin changes,
   - Add the minimal **Tier-0 Gate Ratification** check (`governance/gate-ratifications/`) to the PR gate,
   - Re-run the fresh Stage 6 benchmark under the new gate (archiving the original Epoch-1 report cleanly), and
   - Regenerate fresh, reproducible pins/evidence for Stages 5, 8 (`spec/refund/spec.lock`), 9, and 10.
2. Extend `Split-edit run_control.py` from `local profile only` to **also test the PR-gate profile**:
   - Verify `(a)` unratified `gate/` or `toolchain/` edits exit `1`, `(b)` split-edit attacks across PR commits exit `1`, `(c)` tampered ratification digests exit `1`, and `(d)` ratified `PROPOSAL-V3` exits `0`.
3. Once **every Stage 0–10 `EXIT` check + PR-gate control exits `0`** in the scratch worktree, apply `PROPOSAL-V3` cleanly to the branch and re-verify on the branch.

### TASK 3: TIGHTEN PILLAR II & PILLAR I TECHNICAL EDGES (HONESTY-PRESERVING UPGRADES)
Address the two sharp limitations you identified in `FORGE_ROUND2_PLAN.md` without inflating epistemic claims:
1. **Pillar II Outbound Dispatcher Gate + Verified Minter Decision Core**:
   - You noted: *"A compromised database is detected by the public-key audit (4 of 4 cases), not prevented. Nothing about the minter or sink code is proved."*
   - **Upgrade A (Preventing Unauthorized Outbound Refunds Under Raw DB Tampering)**: Put `Ed25519.verify(pk_minter, ...)` + an append-only outbound idempotency check directly inside the **Outbound Refund Dispatcher stub** right before external side-effect emission. Add 4 new attacks where an adversary directly mutates raw SQLite rows on disk *before* the outbox flushes—prove that **0 unauthorized external refunds fire** (prevented at dispatch, not merely detected post-hoc!).
   - **Upgrade B (Proving the Minter's Pure Decision Core)**: Instead of duplicating unverified handwritten Refund rules inside the isolated minter, compile/invoke the **actual `source_proof`-verified Dafny Refund decision function** (or prove a tiny pure Refund check core in Dafny/HOL4) inside the isolated `sk_minter` process, reducing the minter TCB strictly to `(Dafny codegen + ~30-line Ed25519 signing wrapper + OS process isolation)`. Document exact proved vs. unproved components in `evidence` / report.
2. **Pillar I Parameterized Dafny Relational Audit Skeleton**:
   - Where clean and concise, factor shared relational spec-audit boilerplate into a reusable Dafny abstract module / trait (`RelationalContractAudit.dfy`) imported by the `Ledger`, `Refund`, and `Booking` spec pairs, and check if 2–3 explicit map-key assertions drop `W2` smoothly below `300k` resource units when idle.

### TASK 4: PILLAR III INTEGRATION — WIRE `BookingDualCert` INTO AN END-TO-END SIGNED FINALITY PATH
- Connect Pillar III (`BookingDualCert.dfy`, `46 verified`) + Pillar II (`Ed25519` Finality Sink):
  - Have the isolated minter invoke the compiled, `source_proof`-verified `BookingDualCert` checker (`CheckCertifiedAllocation`) on `(A, c, w, x, y, z, alpha_bps)` proposed by the 25 untrusted TypeScript solvers, minting an `Ed25519` finality signature **iff** `CheckCertifiedAllocation == true`!
  - Run an integrated suite showing: untrusted TS solver evolves `25` times -> `0` Dafny re-runs -> suboptimal/overbooked proposals fail to mint `Ed25519` signatures -> certified optimal (`alpha_bps == 0`) allocations commit to SQLite with publicly verifiable `Ed25519` receipts proving **both capacity safety AND global integer revenue optimality**!

### TASK 5: `M1` BASIS `input-premise lemma` FIRST, THEN INCREMENTAL COMPILER PROOFS (`10,800s`)
1. Run and verify the `input-premise lemma` against the already-rebuilt `HOL4 + CakeML basis` (`exit 0`).
2. Resume the incremental `CakeML compiler proofs` build (`rebuild.py 10800`), complete the full `M1` chain replay (verifying exact `SHA-256` of the tracked executable), and execute `fs-0001` and `fs-0002` cleanly to completion.
3. *(Optional bonus if `M1` finishes within budget)*: Prove the pure ~20-line Stage 8 `Refund` decision predicate inside HOL4 (`RefundMinterCoreScript.sml`), creating a direct concrete bridge between `M1` (HOL4/CakeML) and Pillar II!

---

## REQUIRED FINAL OUTPUT REPORT
Update `FORGE_ROUND3_PLAN.md` (or `FORGE_MASTER_IDEA.md`) and `unsure.md`, push the updated backup branch to `origin`, and print the complete `EXIT` verification table (`EXIT command/check` | `Checker exit` | `Gate exit` | `Scenario/Actual exit` | `Result & exact scope`) covering:
1. All `28` Stage 0–8 `EXIT` checks + renewed Stages 9 & 10 `EXIT` checks **with `PROPOSAL-V3` applied on the branch**,
2. PR-gate profile controls (unratified `gate/` edit rejected, split-edit rejected, ratified `PROPOSAL-V3` accepted),
3. Pillar I (`attempt-0014+`, `W2`, spec pairs),
4. Pillar II (`Ed25519` Refund Minter + verified decision core + Outbound Dispatcher prevention under raw SQLite tampering),
5. Pillar III + II integrated (`BookingDualCert` + `Ed25519` signed finality across 25 solver evolutions with `0` Dafny rebuilds),
6. `M1` `input-premise lemma`, incremental `CakeML compiler proofs`, `M1` executable `SHA-256` replay, and `fs-0001` / `fs-0002`.
