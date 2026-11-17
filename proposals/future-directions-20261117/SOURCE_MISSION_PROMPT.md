<!-- Saved verbatim on 2026-11-17 from text the owner pasted into the session (U410). Source: another AI model. NOT a Forge mission, stage or approval. Its statements about repository state are NOT verified; see ALIGNMENT.md. -->

# ROLE & MISSION: FORGE 2.0 — THE "ATOMIC PROOF-CARRYING FINALITY" RESEARCH JUMP

You are a Principal Formal Methods Architect, Cryptographic Systems Engineer, and Empirical PL/Systems Researcher working inside the `mack-dot/forge` repository.

Forge's foundational thesis is:
> **"LLMs propose, checkers dispose. Humans approve intent (specs), not code."**

Stages 0–8 of Forge are complete and Stage 9 is CURRENT. Up to Stage 8, Forge has progressed along a disciplined linear trajectory:
- **Stages 0–4**: Sequential `Ledger` (`C1–C5`) proved in Dafny 4.11.0 + Z3 4.12.1 (`spec/LedgerSpec.dfy`, `impl/Ledger.dfy`), handwritten TypeScript differential checks (`tested_against_proved_model`), incremental obligation caching, and GitHub PR spec ratification (`spec.lock`, `proposals/`, `governance/ratifications/`).
- **Stage 5**: Spec non-vacuity witnesses, generated claim explanations (`docs/claims.md`), and mutation testing (`8/10` valid audit-clean mutants killed; `2` survived: an algebraic rewrite and an unconstrained `print` statement).
- **Stage 6**: `Booking` contract (`B1–B4`, `gate/booking.py`) and 75-pair Dafny reuse benchmark (`269.713s` cold -> `175.828s` native reuse).
- **Stage 7**: Independently checked machine-code termination proof (exit status `0`) of a 1,240-byte compiled C RISC-V binary (`gcd-selftest.elf`) across 579 Rocq modules under the pinned LPS model (`examples/binary/`, `docs/stage7-binary.md`, `assumption-audit.json`).
- **Stage 8**: Universal `source_proof` of the `Refund` decision boundary, paired with finite integration testing (`9,000` generated cases, `68` fixtures, and controls for effect bypass and duplicate dispatch; `docs/stage8-refund.md`).

## THE STRATEGIC PROBLEM & THE RESEARCH JUMP
Stages 5–8 exposed four structural bottlenecks blocking a 100x leap into real-world autonomous software engineering:
1. **The Spec-Review & Arbitrage Bottleneck**: Reading `.dfy` diffs is harder for humans than reading TypeScript, while finite mutation testing and bounded checks misic relational loopholes (e.g., missing bystander frame conditions that are algebraically invisible at `N <= 4` accounts under `C1` fund conservation, yet enable bystander balance theft at `N >= 5`; or unmodeled ambient I/O like Stage 5's `print` survivor).
2. **The `end_to_end=false` Scissors (Stage 7 vs. Stage 8)**: Proving whole applications in RISC-V Rocq/LPS (579 modules for 1,240 bytes) is too heavy for rapid iteration, yet proving only a pure source core (Stage 8) leaves TypeScript/Node glue with *ambient authority*—requiring 9,000 finite tests just to check effect bypass and duplicate dispatch, while leaving the Dafny-to-JS compiler unproved.
3. **Static Verification's Complexity & Re-Verification Ceiling**: When an untrusted LLM iteratively optimizes complex combinatorial/heuristic logic (e.g., multi-resource revenue-maximizing booking), static `source_proof` over the solver times out in Z3 or incurs ~176s rebuild penalties (`docs/reuse-benchmark.md`), and README currently states *"Model quality remains unmeasured."*
4. **Multi-Commit Split-Edit Governance Evasion**: Patch gates that inspect per-commit obligations rather than cumulative diffs against the ratified `spec.lock` anchor risk split-edit policy downgrade across commits.

### YOUR OBJECTIVE
Execute a **regime jump ("Forge 2.0: Proof-Carrying Finality & Categorical Spec Clearing")** that unifies Forge's previously separate verticals (Stages 5, 6, 7, and 8) into a single, cryptographically and mathematically coupled **Compile-Time + Commit-Time Clearinghouse** built on three pillars:
- **Pillar I (`gate/arbitrage.py` & `gate/anchor_diff.py`)**: Unbounded 2-Safety **Categorical Spec Completeness Proofs** (`SpecIsCategorical`), **AST Capability Purity**, **Semantic-Diff Boundary Witness Tables** (so humans ratify concrete boundary behavior + proved blast radius instead of raw Dafny), and **Cumulative Anchor Diff Enforcement**.
- **Pillar II (`interop/finality_minter/` & `app/finality_sink.ts`)**: Fuse Stage 7 (binary verification) with Stage 8 (application effect boundary) by moving settlement authority out of ambient TypeScript and into a **tiny (<4 KB), `malloc`-free, bounded-loop Certifier + HMAC-SHA256 Finality Minter** checked at the binary/C level, paired with an **Atomic SQLite CAS + Nonce Finality Sink** that makes effect bypass, transpiler corruption, and duplicate dispatch cryptographically/atomically unreachable.
- **Pillar III (`spec/BookingDualCert.dfy` & `gate/certified_runtime.py`)**: Introduce a distinct **`certified_runtime_check`** evidence class using **Exact Integer Primal-Dual Witnesses** (Weak Duality over mathematical integers, zero floats) on combinatorial multi-slot `Booking`. Prove *both* universal capacity safety (`B1`) *and* exact per-transaction **Model Quality (`B5`: `Revenue(x) >= (1 - alpha) * OPT`)**, enabling untrusted LLM agents to rewrite TypeScript heuristic/optimization solvers with **`0.0s` Dafny/Rocq re-verification latency**.

---

## NON-NEGOTIABLE EPISTEMIC & REPOSITORY INVARIANTS
Before writing any code, internalize and obey Forge's strict epistemic discipline:
1. **Read First**: Inspect `AGENTS.md`, `VISION.md`, `ROADMAP.md`, `README.md`, `unsure.md`, `spec.lock`, `schemas/`, `policy/`, `gate/`, `docs/stage7-binary.md`, and `docs/stage8-refund.md` before proposing edits.
2. **Never Inflate Claims**:
   - Keep `source_proof`, `binary_proof` (or LPS binary theorem), `certified_runtime_check`, `spec_categorical_proof`, `bounded_model_checked`, `tested_against_proved_model`, and `unit_tested` **strictly distinct** in schemas, policies, and prose.
   - **NEVER** promote finite tests or red-team survival counts to universal proofs.
   - **NEVER** flip `end_to_end=true` unconditionally! Hardware, OS process/key isolation, SQLite engine internals, and Rocq/Dafny kernels remain in the Trusted Computing Base (TCB). Record exact `finality_assurance` sub-properties, explicit cryptographic assumptions (e.g., `HMAC-SHA256 EUF-CMA`, `OS key isolation`), and full `tcb` arrays.
3. **Fresh Checker Replay**: Imported `evidence.json` bundles MUST be validated against fresh, deterministic checker executions tied to exact SHA-256 bytes of specs, implementations, binaries, and tool versions. Static JSON alone establishes nothing.
4. **Strict Exit-Code & Failure Separation**:
   - Keep **checker exit codes**, **gate exit codes**, and **scenario/control harness exit codes** explicitly separated in all JSON records and docs (a negative-control scenario exits `0` *only* because it observed and verified the required non-zero gate/checker rejection for the *right* reason!).
   - Keep invalid programs and AST/audit rejections separate from spec-proof kills (preserving Stage 5's reporting discipline).
   - Never delete or hide failed runs, Z3 timeouts, or tool friction—log uncertainties, discoveries, and corrections **append-only** in `unsure.md`.
5. **Runtime & Toolchain Pins**:
   - Use pinned toolchain versions from `toolchain/` (Dafny `4.11.0`, bundled Z3 `4.12.1`, pinned Rocq/LPS toolchain). Do not substitute arbitrary unpinned versions to fake a pass.
   - Invoke TypeScript entrypoints using `node --import tsx ...` (never bare `tsx` CLI, respecting the recorded socket failure).
   - Preserve 100% pass status of all existing Stages 0–8 `EXIT` commands.

---

## PHASED EXECUTION BLUEPRINT

Execute this work methodically across **Phases 0 through 4**. Do not skip negative controls or fresh replay checks at the end of each phase.

### PHASE 0: REPOSITORY AUDIT & ARCHITECTURE ALIGNMENT
1. Read `AGENTS.md`, `ROADMAP.md`, `VISION.md`, `unsure.md`, `schemas/*`, `policy/*`, `gate/*`, `spec/*`, `impl/*`, `examples/binary/*`, `docs/stage7-binary.md`, and `docs/stage8-refund.md`.
2. Run existing baseline checks (`gate/gate.py`, `gate/booking.py`, Stage 8 controls, and Stage 7 verification replay if toolchain is present locally) to confirm a clean starting state.
3. Append an entry to `unsure.md` documenting the exact starting state, local toolchain availability, and hypotheses to be falsified/tested across Phases 1–4.

---

### PHASE 1: PILLAR I — CATEGORICAL SPEC ARBITRAGE, CAPABILITY PURITY & CUMULATIVE ANCHOR GATE

#### 1.1 Unbounded 2-Safety Spec Completeness (`gate/arbitrage.py`)
Build `gate/arbitrage.py` to mathematically audit specification completeness and ambiguity using Dafny 4.11.0 + Z3 4.12.1:
- **Relational Determinism / Categorical Completeness Check (`spec_categorical_proof`)**:
  For each target contract (`Ledger`, `Booking`, `Refund`), auto-generate (or verify a dedicated relational module importing the exact locked spec from `spec/`) a 2-safety lemma over **unbounded** mathematical integers and finite maps:
  ```dafny
  lemma SpecIsCategorical(s: State, req: Request, s1: State, out1: Outcome, s2: State, out2: Outcome)
    requires WellFormed(s)
    requires SpecRelation(s, req, s1, out1)
    requires SpecRelation(s, req, s2, out2)
    ensures s1 == s2 && out1 == out2
  ```
  *(Note: Where state maps use Dafny `map<K,V>` extensional equality, supply minimal extensionality triggers `assert s1.balances == s2.balances;` only in the proof body—never weaken `SpecRelation` or add axioms!)*
- **Planted Negative Control — The "$N=5$ Bystander Heist" (`bugs/SpecBystanderArbitrage.dfy`)**:
  Create a relational Ledger specification variant that enforces **all five English claims `C1–C5`** (`C1`: sum of balances conserved; `C2`: all balances `>= 0`; `C3`: identical accepted retry is no-op `Ok`; `C4`: fresh valid transfer debits `src` by `amt+1`, credits `dst` by `amt`, credits `0` by `1`; `C5`: invalid requests return `Rejected` with unchanged maps) **but omits the explicit bystander frame on `C4` (`forall k :: k !in {0, src, dst} ==> bal'[k] == bal[k]`)**.
  - Prove/demonstrate two facts in an automated control script:
    1. **Bounded Blindness at `N <= 4`**: Show via bounded solver/property check that for any universe of `<= 4` accounts (`{0, src, dst, 1_bystander}`), `C1` (sum conservation) + `C4` algebraically pins the single bystander, so `0` arbitrage witnesses exist!
    2. **Unbounded Discovery & Short-Seller Exploit at `N = 5`**: Show that `gate/arbitrage.py` rejects `SpecBystanderArbitrage.dfy` (`SpecIsCategorical` fails!), and have a Short-Seller extractor emit a concrete `N = 5` witness + a `Spec`-passing Trojan implementation (`bugs/LedgerBystanderTrojan.dfy`) that passes `C1–C5` while draining bystander Account `2` into confederate Account `4` during a valid transfer from `3 -> 1`!

#### 1.2 AST / Ambient Capability Purity Gate (Closing Stage 5's `print` Survivor)
- Extend `gate/gate.py` (or a dedicated `gate/purity.py` module invoked by the gate) to enforce deterministic, zero-ambient-authority purity on pure model/spec implementations:
  - Reject `print` statements, `{:extern}` attributes, file/network intrinsics, non-deterministic iterators (`:|` assign-such-that without uniqueness proof), and `{:axiom}` / `assume` statements.
- Re-run against Stage 5's surviving `print` mutant (`docs/spec-quality.md`). Confirm and record that it is deterministically caught as an **`audit_capability_rejection`** (kept strictly separate in metrics from `spec_proof_kill`!).

#### 1.3 Counterexample-Driven Semantic-Diff Ratification (`proposals/` Generator)
- Add `--semantic-diff --old-spec <path> --new-spec <path>` to `gate/arbitrage.py`:
  - Formulate the relational cross-version query between `Spec_old` and `Spec_new` (test it directly on the historical Stage 4 no-fee -> 1-unit-fee transition from `proposals/fees.md`!).
  - Emit a machine-checked Markdown/JSON **Ratification Receipt** containing:
    1. **Proved Invariant Preservation**: Which global safety claims (`C1`, `C2`, `C3`) hold across both versions.
    2. **Proved Unchanged Partition**: Predicates under which `Spec_old(s, req) == Spec_new(s, req)` universally (zero unintended blast radius).
    3. **Minimal Concrete Boundary Witnesses**: Concrete JSON `(pre_state, request) -> {old_outcome, new_outcome}` examples on the exact behavioral decision boundary (e.g., `balance == amount` vs. `balance == amount + 1`, `sender == 0`), allowing a human to ratify intent from concrete trajectories without reading Dafny syntax.

#### 1.4 Cumulative Anchor Diff Gate (`gate/anchor_diff.py`)
- Build `gate/anchor_diff.py` so policy obligations are derived from the **cumulative diff against the authenticated `spec.lock` / ratified baseline**, not merely the latest incremental commit.
- Include a negative control (`tests/test_split_edit_evasion.py`) simulating a two-commit split-edit attack (Commit 1 edits helper/policy scope; Commit 2 edits implementation) and verify the gate fails closed.

---

### PHASE 2: PILLAR II — BINARY-PROVED FINALITY MINTER (FUSING STAGE 7 + STAGE 8)

Close the runtime effect-bypass, transpiler-trust, and duplicate-dispatch gaps on `Ledger` and `Refund` **without** trusting TypeScript, Node.js, or Dafny's JavaScript backend.

#### 2.1 The Minimal Certifier + Capability Minter (`interop/finality_minter/`)
1. Write a self-contained, `malloc`-free, recursion-free, bounded-loop C99 micro-kernel (`interop/finality_minter/certifier.c`):
   - Implements exact fixed-width 64-bit overflow-checked transition verification ` verify_ledger_or_refund_transition(...)` matching the locked `Ledger` (`C1–C5`) and `Refund` (Stage 8) transition relations over canonical binary-serialized `(pre_state, request, candidate_post_state, effect_intent)`.
   - Implements constant-structure `SHA-256` and `RFC 2104 HMAC-SHA256` (~120 lines of auditable C, zero external OpenSSL/libc heap dependencies).
   - Reads secret sink key `K_sink` from an isolated file descriptor / environment channel inaccessible to untrusted TypeScript glue.
   - **Iff** `verify_transition(...) == 1`, emits a single-use **Finality Settlement Token**:
     ```
     tau = HMAC_SHA256(
       K_sink,
       "FORGE_FINALITY_V1" || spec_lock_sha256 || certifier_artifact_sha256
       || SHA256(canonical_pre_state) || canonical_req_id
       || SHA256(canonical_post_state || canonical_effect_intent)
     )
     ```
   - Otherwise returns non-zero status and emits **zero** token bytes.
2. **Binary / Mechanized Assurance Binding (Connecting Stage 7)**:
   - Compile `certifier.c` (or its pure self-test/transition core following `examples/binary/`'s exact LPS conventions) to a deterministic static `riscv64` ELF (`certifier.elf`) alongside the host executable/Wasm sandbox used by local Node integration.
   - If the local Rocq + LPS toolchain from Stage 7 is installed, prove under the pinned LPS model that `certifier.elf` terminates on all valid bounded inputs and exits `0` **only** when the checked transition relation holds; generate `evidence.json`, a valid-entry non-vacuity witness, `assumption-audit.json`, and an unbound-certificate negative control matching `docs/stage7-binary.md`.
   - *(Fallback rule if Rocq/LPS is CI-only on this host: verify CBMC/Dafny-C equivalence locally, wire the exact Rocq/LPS proof script and CI workflow matching Stage 7, and record exact host vs. CI verification scope honestly in `unsure.md` and `evidence.json`—NEVER fake a local LPS run!)*

#### 2.2 Atomic SQLite WAL Finality Sink (`app/finality_sink.ts`)
Build a minimal (~100-line)Trusted Finality Sink wrapping SQLite (using Node's built-in `node:sqlite` or repository-approved deterministic persistence) + outbound Refund dispatcher stub:
- Stores `(state_blob, state_sha256)` and `settled_requests(req_id PRIMARY KEY, request_sha256, effect_sha256, tau_hex)`.
- Accepts `commitTransition(pre_state, req, post_state, effect_intent, tau)` from untrusted `app/` code **if and only if** inside a single `IMMEDIATE` atomic transaction:
  1. `HMAC_SHA256` verification of `tau` under `K_sink`, `spec_lock_sha256`, and `certifier_artifact_sha256` succeeds in constant time (`crypto.timingSafeEqual`),
  2. Current persisted `state_sha256 == SHA256(canonical_pre_state)` (atomic Compare-And-Swap), and
  3. `req_id` is fresh (or, for idempotent retry `C3`, matches prior `request_sha256` and returns cached `Ok` **without** re-emitting outbound effects!).
- Only after commit succeeds does the outbox release at-most-once `effect_intent`.

#### 2.3 Adversarial Red-Team Suite (`tests/redteam_finality/`)
Build an automated adversarial harness (`node --import tsx tests/redteam_finality/run_attacks.ts`) where an untrusted adversary has **arbitrary control** over the TypeScript proposal/application layer (`ts/`, `app/`), and executes **at least 50 concrete attack cases** across 6 classes:
1. **Direct Effect Bypass**: Calling the Refund/Ledger commit sink directly without invoking the certifier.
2. **Duplicate Dispatch / Retry Storm**: Replaying a legitimately minted `(post_state, effect_intent, tau)` 10 times concurrently/sequentially, or mutating arguments under an old `req_id`.
3. **Transpiler / JS IEEE-754 Precision Corruption**: Injecting `Number.MAX_SAFE_INTEGER + 2` rounding drift or mutated JS map prototypes into `candidate_post_state`.
4. **Cross-Spec Replay**: Replaying a valid `tau` minted under an older `spec_lock_sha256`.
5. **State Fork / TOCTOU**: Replaying a valid `tau` against a stale `pre_state` after another transaction advanced `state_sha256`.
6. **Spec-Violating Proposals**: Fee theft, negative balance, over-refund above original capture, and `$N=5$` bystander balance tampering.
- **Required Outcome**: `0 / 50` unauthorized state commits or duplicate outbound effects settle; `100%` of valid, spec-compliant sequences settle cleanly. Record full machine-readable results while explicitly keeping `end_to_end=false` and documenting exact `finality_assurance` + `tcb` boundaries.

---

### PHASE 3: PILLAR III — ZERO-LATENCY EVOLUTION & RUNTIME MODEL QUALITY (`certified_runtime_check`)

Shatter the *"Model quality remains unmeasured"* and *"175.8s Dafny rebuild per edit"* walls by upgrading Stage 6's `Booking` domain (`gate/booking.py`) with **Exact Integer Primal-Dual Witness Verification**.

#### 3.1 Proved Integer Weak-Duality & Capacity Certifier (`spec/BookingDualCert.dfy` & `impl/BookingDualChecker.dfy`)
Formulate combinatorial multi-slot booking over **mathematical integers** (`int` / `nat`, **zero floating-point arithmetic**):
- Given `m` resource/time slots with capacities `c: seq<nat>`, `n` booking requests with positive integer values `w: seq<nat>`, and binary slot-usage incidence matrix `A: seq<seq<nat>>` (`m x n`, entries in `{0,1}`):
- An untrusted optimizer/ML heuristic proposes:
  - Primal assignment `x: seq<nat>` (`|x| == n`),
  - Integer LP dual witness `y: seq<nat>` (`|y| == m`), `z: seq<nat>` (`|z| == n`),
  - Allowed optimality gap in basis points `alpha_bps: nat` (`0 <= alpha_bps <= 10000`; `0` = 100% exact global optimum).
- Prove in Dafny 4.11.0 (`source_proof`, zero axioms/assumptions!) a concise, fast checker `VerifyCertifiedBooking(A, c, w, x, y, z, alpha_bps) returns (ok: bool)` establishing **five universal claims**:
  - **B1_Cap (Universal Capacity Safety)**: `ok ==> IsBinary(x) && forall i | 0 <= i < m :: RowDot(A[i], x) <= c[i]` (zero overbooking).
  - **B2_Dual (Dual Feasibility)**: `ok ==> forall j | 0 <= j < n :: ColDot(A, y, j) + z[j] >= w[j]`.
  - **B3_WeakDuality (Universal Upper Bound Theorem)**: Prove by pure integer algebra (induction over sequences, **no LP solver trust required!**) that for **ANY** valid binary assignment `x_alt` satisfying `forall i :: RowDot(A[i], x_alt) <= c[i]`,
    `Dot(w, x_alt) <= Dot(c, y) + Sum(z)`.
  - **B4_ExactOrBoundedOptimality (Certified Runtime Model Quality!)**:
    `ok ==> forall x_alt :: ValidAllocation(A, c, x_alt) ==> 10000 * Dot(w, x) >= (10000 - alpha_bps) * Dot(w, x_alt)`.
    *(Specifically, when `alpha_bps == 0`, `x` is **mathematically proved globally revenue-optimal across all `2^n` possible subsets**!)*
  - **B5_NonVacuity**: Include a checked execution witness lemma demonstrating `VerifyCertifiedBooking(...) == true` with `alpha_bps == 0` on a non-trivial multi-slot conflicting booking instance, plus negative-control rejections for `(i)` capacity violation, `(ii)` invalid dual witness, and `(iii)` suboptimal primal failing the `alpha_bps` threshold.

#### 3.2 Zero-Verifier-Latency Agentic Solver Benchmark (`ts/booking_optimizer.ts` & `gate/certified_runtime.py`)
1. Build `gate/certified_runtime.py` to bind `BookingDualCert.dfy` (`source_proof` on the checker) + the Finality Minter to untrusted solver iterations in `ts/booking_optimizer.ts` under the new `"certified_runtime_check"` policy rule.
2. Implement an automated **25-Iteration Solver Evolution Benchmark** (`scripts/run_zero_latency_benchmark.py`) simulating an AI coding agent evolving `ts/booking_optimizer.ts` across 25 commits without touching `.dfy` files:
   - Iterations 1–5: Naive greedy heuristics (evaluated with `alpha_bps = 2000` [>=80% OPT] vs `alpha_bps = 0`—watch suboptimal instances get deterministically caught or bounded!).
   - Iterations 6–10: Deliberately buggy/hallucinated edits (off-by-one overbooking, negative duals, corrupted objective)—confirm 100% runtime rejection at the certifier gate before commit.
   - Iterations 11–25: Exact Primal-Dual / Network-Flow / Integer-Dual Interval Solvers (since interval booking matrices have the consecutive-ones property and are Totally Unimodular, exact integer `(x*, y*, z*)` witnesses with `alpha_bps == 0` **always exist**!).
3. **Measure & Compare Directly Against Stage 6 (`docs/reuse-benchmark.md`)**:
   - Record wall-clock Dafny/Z3 re-verification time per solver edit (`0.000s` checker rebuild when `BookingDualChecker.dfy` is unchanged, plus sub-millisecond runtime witness verification per batch!) vs. Stage 6's `269.713s` cold / `175.828s` native-reuse Dafny verification across 25 pairs!

---

### PHASE 4: SCHEMAS, PRODUCTIVITY BENCHMARK, ROADMAP & PAPER-GRADE ARTIFACTS

1. **Backward-Compatible Schema & Policy Evolution (`schemas/` & `policy/`)**:
   - Extend `schemas/evidence.schema.json` and policy validators to support:
     - Evidence methods `"spec_categorical_proof"` and `"certified_runtime_check"` (strictly separated from static `"source_proof"` of a generator).
     - Optional structured `"finality_assurance"` object recording `certifier_artifact_sha256`, `spec_lock_sha256`, `compiler_gap_status`, `effect_bypass_resistance`, `duplicate_dispatch_resistance`, `certified_optimality_alpha_bps`, and explicit `tcb` array—while keeping top-level `end_to_end: false` honest and intact!
   - Ensure all existing `evidence.json` and `results/stage*/**/*.json` files still validate cleanly.

2. **Controlled Productivity & Autonomy-Pricing Evaluation (`docs/stage9-clearinghouse-benchmark.md` & `results/stage9/`)**:
   Run a reproducible, apples-to-apples benchmark across 3 change classes (*Buggy Agent Patch*, *Routine Algorithm/Optimization Upgrade*, *Business-Rule Spec Change*) under 3 governance regimes:
   - **Regime A (Status Quo CI)**: Unit tests + simulated human line-by-line code review burden (LOC diff size, escaped planted bugs).
   - **Regime B (Forge Classic — Stages 0–8)**: Static per-edit `source_proof` + raw `.dfy` human review + 9,000-case finite glue integration suite.
   - **Regime C (Forge 2.0 Clearinghouse)**: Categorical spec check + concrete semantic-diff table + binary-minted Finality Sink + `0.0s`-rebuild Primal-Dual runtime witnesses.
   Record exact wall-clock checker times, human review surface (lines of code/Dafny vs. concrete boundary rows), escaped semantic/bystander/bypass defects, and reproduction commands in `results/stage9/summary.json`.

3. **Documentation, `ROADMAP.md`, and `unsure.md` Hygiene**:
   - Write crisp, audit-grade technical records:
     - `docs/stage9-spec-arbitrage.md` (covering `SpecIsCategorical`, the `$N=5$` Bystander Heist theorem/witness, Stage 5 `print` closure, semantic-diff receipts, and split-edit anchor defense).
     - `docs/stage10-finality-sinks.md` (covering the C/binary Finality Minter, HMAC capability protocol, SQLite CAS/nonce sink, 50-attack red-team matrix, and exact TCB/assumption audit).
     - `docs/stage11-certified-runtime.md` (covering `BookingDualCert.dfy`, exact integer Weak Duality, runtime model-quality certification, and the `175.8s -> 0.0s` evolution benchmark).
   - Update `ROADMAP.md` and `README.md` with exact `EXIT 1 / EXIT 2 / EXIT 3` commands and measured numbers, preserving Forge's sober, zero-hype, falsifiable tone.
   - Append every limitation, TCB boundary, local vs. CI environment difference, and newly surfaced research question to `unsure.md`.

---

## DEFINITION OF DONE (REQUIRED FINAL VERIFICATION PASS)

Before declaring completion, run a clean, end-to-end fresh verification sweep and report a structured summary table showing **Command**, **Checker Exit**, **Gate Exit**, **Scenario Exit**, and **Artifact Digest**:
1. All legacy Stages 0–8 `EXIT` checks still pass with fresh checker replay.
2. **Pillar I EXITs**:
   - `SpecIsCategorical` passes on locked `Ledger` and `Refund` specs.
   - `SpecBystanderArbitrage.dfy` passes `N <= 4` bounded checks, fails `SpecIsCategorical`, and produces the concrete `N = 5` Charlie-to-Mallory heist witness.
   - Stage 5's `print` mutant is deterministically rejected by the AST capability gate; split-edit evasion is rejected by `anchor_diff.py`.
3. **Pillar II EXITs**:
   - `certifier` passes compilation, deterministic self-test / binary proof checks, and negative unbound-certificate controls.
   - Red-team harness runs all `>= 50` bypass, replay, precision, and state-fork attacks via `node --import tsx` with **`0` unauthorized settlements** and **`100%` valid sequence completion**.
4. **Pillar III EXITs**:
   - `BookingDualCert.dfy` + `BookingDualChecker.dfy` pass fresh Dafny `4.11.0` `source_proof` (including Weak Duality optimality and non-vacuity witnesses) and reject planted capacity/dual/suboptimality bugs.
   - 25-iteration solver evolution benchmark completes with `0.0s` Dafny rebuild cost on unchanged checker specs and 100% runtime safety + certified `(1 - alpha)` model quality.

Begin now with **Phase 0**: inspect the repository files, verify local toolchains, log your initial audit to `unsure.md`, and execute Phase 1 through Phase 4 systematically.
