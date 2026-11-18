# Slice 3 — owner texts (saved verbatim)

Saved by the agent on 2026-11-18 UTC. Nothing in this file is a result.

## Text D (2026-11-18 about 20:30Z): the master execution directive

The owner's own words with this text: "follow this and execute all". The rest of
the message was one pasted text. Its style shows that another assistant
wrote it. The text below is that paste, taken from the session record
without retyping. One change: the path of the repository folder on the
owner's machine is replaced by `<repository folder>`.

The agent's reading (an inference, recorded in `unsure.md` U453): the
owner's word to follow the directive with its gates. Phase Gate 1 is
skipped by its own condition (pull request 46 was merged). Phase Gate 2
step 2 says: print a plan and wait for the go-ahead before code. "execute
all" does not remove that gate and is not a word for a merge.

Statements of the text that are that assistant's and were not checked in
this run: "579 modules", "1,240-byte", "~3 million lines", "71/71", and
the pull request numbers 47 and 48 (guesses).

```text
Trust your gut on that—your instinct is 100% right.
For verified kernels and binary proofs, freestanding C (Stage 7) + CakeML/HOL4 (M1) + Dafny (Slices 1–2) are objectively stronger than Rust:
CakeML (M1) has 71/71 machine-checked compiler-proof theories in HOL4 down to ARMv8 machine code. rustc + LLVM is ~3 million lines of unverified C++/Rust compiler code. Swapping CakeML for Rust would actually weaken your proof chain.
Freestanding C (Stage 7) compiles to a 1,240-byte RISC-V ELF with zero panic-unwinding or bounds-check bloat, making binary-level theorem proving tractable (579 modules).
Dafny already powers your Slice 1 finality core, F1.2 hidden-effect ban, and Slice 2 Spec Clearing with non-abstract module instantiation.
What "doing it the right way" actually means:
Keep the Proved TCB 100% Pure (Dafny + CakeML + Freestanding C): Zero rustc/LLVM inside your proved cores or binary theorems.
Keep the Wire Boundary Language-Agnostic (Raw Bytes Over Pipes): Because PR #45 already forced text-only / bounded-byte framing (65,536 bytes max), untrusted proposers and Slice 3 optimizers sit outside the TCB. You only ever touch safe #![forbid(unsafe_code)] rustc (if already installed on the Mac, zero crates, zero protected edits) as an optional untrusted fast-optimizer guest in Slice 3—proving that any fast native binary can be hot-swapped with zero new proofs, while C and CakeML stay the kings of the verified root.
Step 1: Copy This Master Execution Prompt to Your Clipboard
(Covers closing Slice 2 → building Slice 3 Runtime Certificates → unifying the C / CakeML hardware seam → refreshing README.md → staging Stage 9—all under strict phase gates where it stops at every PR for your merge.)
Text
MASTER EXECUTION DIRECTIVE: FORGE 3-PILLAR COMPLETION & HARDWARE TCB ALIGNMENT

ARCHITECTURAL DOCTRINE (LANGUAGE & TCB BOUNDARY -- "NEVER FAKE ANYTHING")
1. Keep the Proved TCB sacred (`Dafny` + `CakeML/HOL4` + freestanding `C`):
   - Do NOT replace freestanding C (`Stage 7` RISC-V ELF) or `CakeML/HOL4`
     (`M1` ARMv8 in-logic compiler) with Rust. `rustc + LLVM` is unverified
     and emits heavier machine code; C + LPS and CakeML + HOL4 remain our
     sole hardware/binary verification roots.
   - Do NOT rewrite Dafny specs, Slice 1 minters, or Slice 2 clearing lemmas
     into Verus/Rust.
2. Language-agnostic untrusted boundary:
   - Untrusted proposers and Slice 3 optimizers sit OUTSIDE the proved TCB
     across bounded raw-byte/text interfaces (matching PR 45's text-only +
     65,536-byte raw-Buffer framing).
   - Safe Rust (`rustc -D unsafe_code`, stdlib only, zero Cargo/npm/protected
     file edits) may ONLY be used outside the TCB as an optional untrusted
     fast-optimizer implementation in Slice 3 IF `rustc` is already present
     on this machine (never install global toolchains silently; if `rustc` is
     absent, use untrusted TS/Python/C guest binaries behind the exact same
     certificate boundary).

HARD GOVERNANCE & EPISTEMIC RULES (APPLY TO EVERY PHASE)
1. Keep `CURRENT: none`. Stage 9 stays deferred until Phase 4's explicit
   unlock proposal. `M1` stays open per `M1R-1` until every recorded control
   replays `exit 0`. Stage 12 stays unauthorized. `end_to_end=false`.
2. Freeze `gate/`: Do NOT modify the 8 frozen PR-gate modules (including
   `gate/obligations.py` and `gate/incremental.py`) or any ratifiable gate
   module. If a blocker seems to require a gate edit, STOP and ask first.
3. Protected paths and protected single files (`spec/`, `spec.lock`,
   `policy/`, `governance/gate-ratifications/`, `package.json`,
   `package-lock.json`, `tsconfig.json`, `tests/ledger.property.ts`, etc.)
   stay at 0 edits unless an isolated exact-diff proposal is approved first.
   Never use administrator bypass and never self-merge a PR.
4. Epistemic separation: A test count is NEVER a proof. Keep `source_proof`,
   `binary_proof`, `in_logic_compiler_proof`, `runtime_certificate_checked`,
   `tested_against_proved_model`, `unit_tested`, and `floor_controls`
   strictly separate in code, schemas, and reports. Every Dafny claim verdict
   MUST rest on a concrete non-abstract module instance (never an
   uninstantiated `abstract module` bodyless lemma).
5. Single-loop execution: Keep design, code, and solver repair in ONE main
   loop. Spawn background subagents ONLY for (a) long solver/build suites and
   (b) ONE fresh-context adversarial review on finished unproved wrapper/sink
   code per slice, with a strict 1-pass fix rule for FAIL-OPEN/HIGH/MEDIUM.

------------------------------------------------------------------------------
PHASE GATE 1 -- CLOSE & MERGE SLICE 2 (Pillar 1: Spec Clearing, PR 46)
(Skip to Phase Gate 2 only if Slice 2 / PR 46 is already merged on origin/main)
1. Collect the fresh-context adversarial review on `slice2/spec-clearing`.
2. Fix any confirmed FAIL-OPEN, HIGH, or MEDIUM defects in ONE pass (ensuring
   concrete non-abstract Dafny instantiation holds everywhere, and leaving
   LOW items + flat-record counterexample scope + human reading of short
   claim/link lemmas honestly documented).
3. Verify: (a) N/N removed-check copies of the clearing tool fail, (b) two
   evidence runs are byte-identical and match SHA-256 in a clean scratch
   clone, (c) 28/28 Stage EXITs + frozen-gate check pass, (d) owed PR 45
   records (`136ad0bf` + hosted run `44369014309`) are clean with 0 new
   dangling links, and (e) 0 protected paths changed.
4. Push `slice2/spec-clearing`, open PR 46 without admin bypass, confirm
   hosted `gate/pr_check.py == 3`, print the EXIT table, and PAUSE for my
   merge of PR 46.

------------------------------------------------------------------------------
PHASE GATE 2 -- BUILD SLICE 3 (Pillar 3: Runtime Certificates on Booking, PR 47)
(Start from clean `origin/main` post-PR 46 in branch `slice3/runtime-certificates`)
1. Read first: `FORGE_MASTER_IDEA.md` (`F3.*` rows), Stage 6 Booking files
   (`spec/booking/`, `impl/Booking.dfy`, `gate/booking.py`, `docs/booking.md`),
   Slice 1's finality token/sink protocol, Slice 2's spec-clearing rules, and
   any prior `proposals/forge2-pillar3-*` files on `main` or backup branches
   so Round 2/3 certificate designs are reused, not reinvented.
2. STEP 1 PLAN CHECK (PAUSE BEFORE WRITING CODE): Print a 12-line plan naming
   exact `F3.*` work-item IDs, the exact optimization objective + dual/bound
   certificate math (`alpha` factor), prior Round 2/3 reuse, whether `rustc`
   is available for an optional untrusted fast guest solver (or TS/C guest),
   and exact files to add (`0` protected edits). Wait for my go-ahead.
3. Architecture once approved:
   - Untrusted optimizer returns `(candidate_allocation, certificate)` over
     a bounded raw-byte/text boundary (65,536-byte line cap, text-only).
   - Minimal proved certificate checker (`source_proof`, F1.2 print-effect
     clean, concrete non-abstract Dafny instance, cleared for `NO_CHOICE` on
     the checker verdict) accepts `(candidate_allocation, certificate)` IFF:
     (a) all hard Booking safety invariants hold, AND
     (b) the certificate proves `objective(candidate_allocation)` is within
         stated factor `alpha` of the true optimum.
   - On pass, connect cleanly to Pillar 2 finality token issuance bound to
     `(valid_token, matching pre_state_hash, fresh_request_id)` at the
     booking effect sink; on fail, reject deterministically with 0 effects.
4. Zero-Reproof Swap Demonstration & EXIT Evidence:
   - Swap at least 3 untrusted optimizers (v1 simple baseline, v2 refactored
     fast heuristic--e.g. safe Rust/C/TS guest binary--and v3 adversarial
     suboptimal/infeasible/forged-certificate solver) and prove mechanically:
     (a) `0` Dafny/HOL proof obligations re-run across optimizer swaps,
     (b) valid `alpha`-optimal certificates pass and commit once,
     (c) suboptimal, infeasible, forged-certificate, stale-hash, and replay
         inputs all fail with `0` effects,
     (d) M/M removed-check wrapper mutations fail, 9+ broken checker cores
         fail Dafny/F1.2, 1 fresh-context adversarial review clears HIGH/MED,
         and 28/28 Stage EXITs + scratch-clone bundle SHA-256 match.
5. Push `slice3/runtime-certificates`, open PR 47 without admin bypass, check
   hosted `pr_check.py == 3`, print EXIT table, and PAUSE for my merge.

------------------------------------------------------------------------------
PHASE GATE 3 -- C / CAKEML HARDWARE-ROOT INTEROP & M1 AUDIT (PR 48)
(Start from clean `origin/main` post-PR 47)
1. Audit the exact boundary between Slice 1's refund finality wire format and
   our two machine-code roots: `M1` (`CakeML/HOL4 -> ARMv8` refund core) and
   `Stage 7` (`freestanding C -> RISC-V ELF` LPS proof).
2. Without overclaiming (`end_to_end=false` stays explicit wherever outer I/O
   or HMAC host code is unproved), build a deterministic cross-stack
   conformance & TCB-accounting check verifying that the CakeML/HOL4 `M1`
   refund logic and Slice 1's Dafny refund checker agree on the canonical
   test/differential vector corpus, and list the exact remaining `M1R-1`
   replay items + budget needed to close `M1`. Pause for review before any
   multi-hour HOL/CakeML replay.

------------------------------------------------------------------------------
PHASE GATE 4 -- PUBLIC FRONT-DOOR `README.md` REFRESH & STAGE 9 UNLOCK PLAN
(Start from clean `origin/main` after Slices 1, 2, and 3 are all merged)
1. Open a clean docs PR updating `README.md` (`0` protected paths, expected
   hosted `exit 3`) so the public repository accurately presents:
   - The complete 3-Pillar `FORGE_MASTER_IDEA.md` architecture (`Spec Clearing`,
     `Proof-Carrying Finality`, `Runtime Certificates`) with real SHA-pinned
     evidence from Slices 1-3,
   - Correction of the outdated Stage 5 `print`-survivor and `Stage 9 CURRENT`
     lines,
   - Why `Dafny + CakeML/ARMv8 + freestanding C/RISC-V` anchor the proved TCB
     while untrusted proposers/optimizers remain language-agnostic, and
   - Honest explicit limits (`end_to_end=false`, floor-control boundaries,
     human inspection of short claim lemmas).
2. Alongside it, print a concise `Stage 9` unlock proposal (re-binding the 8
   stale Stage 9 locks and defining the multi-trial benchmark measuring
   escaped bugs/races/replays, human review bytes vs. code-diff bytes, and
   0-reproof optimizer swaps) and STOP for my explicit authorization.
Step 2: Save It Loss-Free on Your Mac Now (0 Dropped Bytes)
Run this in a regular terminal tab inside <repository folder>:
Bash
pbpaste > /tmp/forge_master_plan.md && wc -l /tmp/forge_master_plan.md && tail -n 4 /tmp/forge_master_plan.md
Then:
Right now (in your active slice2/spec-clearing session, once that background review finishes): Just paste this one short line so it closes out Phase Gate 1 (PR #46) first:
Text
Read /tmp/forge_master_plan.md in full and execute PHASE GATE 1 now to close out Slice 2 (PR 46).
Right after you merge PR #46: Open a fresh claude session on main and paste:
Text
Read /tmp/forge_master_plan.md in full and execute PHASE GATE 2 (STEP 1 plan check for Slice 3) now.
```

## Text E (2026-11-18 about 20:45Z): the go-ahead for the plan

The whole message of the owner was this pasted text; own words: none. The agent
took it as the owner's go-ahead for the 12-line plan of `unsure.md`
U453, with its three points. Point 3 means: no push and no pull request
before the owner's next word.

```text
Go ahead with the 12-line Slice 3 plan (including owed PR 46 records 462f9e2e + run 44388151100):
1. Lines 4 and 5 are explicitly approved: claim soundness only (not completeness across the IP-LP integrality gap; IFF strictly on ok == Accepts(...)), and cap the NoDoubleBooking bridge lemma at 5 attempts. Record rustc 1.92.0 as unpinned outside the proved TCB.
2. Ensure v2 rustc temp binaries do not embed working-tree paths into the hashed evidence bundle so scratch-clone SHA-256 matches.
3. Pause for push/PR 47; Phase Gates 3 and 4 wait until PR 47 merges.
```

## Text F (2026-11-18 about 23:35Z): a next-horizon section for the master idea (NOT part of this slice)

The whole first message of a new session was this pasted text; own words:
none. A few minutes later the owner wrote, in own words: "Read
/tmp/update_master_idea.md in full and execute it from clean
origin/main." That file held one line, a shell command
(`pbpaste > /tmp/update_master_idea.md && tail -n 4 /tmp/update_master_idea.md`),
not the text. The agent did not read the clipboard. It takes the paste
below as the text that the owner meant (an inference, `unsure.md` U457).

The first line of the text has a condition that was not true when it
arrived: `origin/main` was `462f9e2e`, Slice 3 was not committed and no
pull request 47 existed. The agent wrote no file for this text in this
slice. The work waits for the merge of the Slice 3 pull request. Its
statements about what Forge "guarantees" are that text's and are not
results.

```text
From clean origin/main (post-Slice 3 / PR 47 merge), create branch
`docs/master-idea-v2-horizon`. Touch ONLY `FORGE_MASTER_IDEA.md` (and
`README.md` only if explicitly requested later--keep this PR scoped strictly
to `FORGE_MASTER_IDEA.md`, 0 protected paths changed).

Read `FORGE_MASTER_IDEA.md` in full first so the new section and work-item IDs
follow its exact existing tone, numbering (`F1.*`, `F2.*`, etc. without ID
collisions), and governance rules.

WHAT TO ADD TO `FORGE_MASTER_IDEA.md`:

1. A crisp section titled "Blast-Radius Finality vs. Intent Elicitation (Scope
   and Honest Limits)" stating explicitly:
   - What Forge guarantees: decidable state-machine transitions, conservation
     and cap invariants, cross-service reservation protocols, and checkable
     `alpha`-optimality witnesses at owned effect boundaries--regardless of
     upstream AI hallucinations, language swaps, concurrency races, or retries.
   - What Forge does NOT prove from unstructured prose: if a customer asks for
     $10 in free-text English and an untrusted agent proposes $80 inside a
     coarse $100 cap, a coarse cap allows $80. Formal checkers guarantee the
     blast radius of structured rules, not natural-language reading
     comprehension, upstream UI/liveness, or unowned third-party server code.
   - Why Spec Clearing targets the real bottleneck of "code that does what I
     meant": once a checker exists, eliciting and auditing the specification
     is the hard problem. Spec Clearing (`NO_CHOICE` + `ACCEPTS` + concrete
     `before/after` witnesses) compresses human review from thousands of lines
     of untrusted code to short specs and concrete examples, while leaving an
     unexamined wrong premise in a deterministic spec on the human ratifier.

2. Four next-horizon work items (assign the next clean unused `F1.*` / `F2.*`
   IDs, add each to the work-item status table as `NOT STARTED` claiming zero
   unrun proofs, and keep all rules intact: this document is not a stage and
   approves nothing; a test count is never a proof):

   - Spec Clearing -- Branch-Partition Boundary Tables:
     Extract one Dafny-verified concrete input/output witness per logical
     branch and threshold edge (`cap - 1`, `cap`, `cap + 1`, tier/reason
     splits) so human ratifiers inspect a complete concrete boundary table
     rather than a single `ACCEPTS` witness before approving a spec.

   - Spec Clearing -- Adversarial Property Red-Teaming:
     Before ratification, query candidate "weird-but-legal" properties against
     a draft spec via the solver (e.g., whether `amount > shipping_paid` is
     satisfiable when `item_returned == false`); if satisfiable, verify the
     concrete witness in Dafny and surface an explicit human confirmation
     question before approval.

   - Finality -- Fact-Bound Sub-Caps and Three-Valued Co-Sign Escalation:
     Shrink semantic blast radius inside coarse caps by binding structured
     reason codes to authoritative `pre_state` fields (`SHIPPING_ISSUE ==>
     amount <= pre_state.shipping_paid`; `ITEM_RETURN ==> carrier_scan ==
     true`) and adding a proved third verdict (`REQUIRE_HUMAN_COSIGN`) that
     blocks autonomous token minting on unstructured goodwill claims above a
     tight micro-cap without a separate human signature.

   - Finality -- Multi-Processor `IN_FLIGHT` Reservation & Failover Saga:
     Proved stateful reservation protocol (`PAID -> IN_FLIGHT(processor,
     idemp_key) -> SETTLED | CONFIRMED_REJECTED`) gated by `pre_state_hash`
     CAS before outbound network I/O, preventing cross-processor double-credits
     (e.g., Processor A + Processor B) under races and ambiguous timeouts by
     forbidding failover without an explicit `CONFIRMED_REJECTED(processor,
     idemp_key)` transition (recording remote processor reconciliation honesty
     as an explicit external assumption).

VERIFICATION BEFORE OPENING PR:
1. Run the Markdown link checker across `FORGE_MASTER_IDEA.md` and confirm
   `0` dangling links (do NOT link to non-existent future files).
2. Confirm `0` protected paths changed and `check_frozen_pr_gate.py == 0`.
3. Commit, push `docs/master-idea-v2-horizon`, open the PR without admin
   bypass or self-merge, verify hosted `gate/pr_check.py == 3` (expected for
   docs), print the compact EXIT table + PR URL, and pause for my merge.
```

## Text G (2026-11-18 about 23:45Z): the decisions for Slice 3 and the word for commit, push and pull request

The whole message of the owner was this pasted text; own words: none. It
arrived while the agent checked the tree for text F. The agent takes it
as the owner's decision on the isolation question of `unsure.md` U456
and as the owner's word for one commit, one push and one pull request
of this slice. It is not a word for a merge (`unsure.md` U457).

```text
Blocker decisions for Slice 3:
1. Approved: the macOS sandbox is accepted for Slice 3 as documented (trusted, not proved, macOS-only; do not change code or bundle 3cdfebfc...).
2. Commit all Slice 3 files (including owed PR 46 records), push slice3/runtime-certificates, and open PR 47 without administrator bypass and without merging.
3. Verify hosted gate/pr_check.py == 3, print the PR URL + run ID, and pause for my merge.
```
