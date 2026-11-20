# Report F: the single next engineering task (specification only; not executed)

## Task
V1: an evidence package and a Dafny-proved spec-recheck verifier over the existing silicon-sink WAL (`src/silicon_sink/sink.rs`, unchanged).

## Why this task (Reports B, C, D)
- It is the only task that produces a third-party-checkable statement about an actual durable execution, without M1, without a Rust proof, and without new hardware (D-1).
- The engines recheck every conjunct of `Eligible` natively after the binary answers, except the two flag bits (Report D, section 0). So M1-R does not strengthen any safety conclusion. It only makes a machine-code theorem checkable, and that theorem supports only completeness (D-2 C4).
- The repository already holds most of the proof pattern: `ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial` (156 verified) folds stored rows and re-evaluates the approved `Eligible` on the replayed state.
- Main limits:
  - V1 is relative to an UNAPPROVED stateful spec until V1-S.
  - V1 rests on H_LOG until V2–V4.
  - V1 detects; it does not prevent.

## Relevant files
- Sink format and behaviour: `src/silicon_sink/sink.rs` (record format :7-11; `encode` :64-74; `scan` :82-100; `open_ledger` :106-126, with the tail cut at :119-121 and EPOCH_REGRESSION at :118; `commit` :162-188; COMMITTED line :187; `replay` :241-244).
- Tests and corpora:
  - `tests/silicon_sink/test_silicon_crash.py`: its own format transcription, `REASONS` :42, `reference_eligible` :346-348.
  - `scripts/exit_silicon_sink.py`: `SUITE_CASES` :54, `MUTANTS` :63, rustc check :49,213-215.
  - `proposals/forge2-native-silicon-sink/records/evidence.json`.
- Spec: `spec/refund/RefundSpec.dfy` (`90a21c71…`, protected, unchanged); draft `proposals/m1b-mission-20261119/proofs/sink-core/SPEC_STATE_PROPOSAL_U8.txt`.
- Proofs to reuse:
  - `impl/finality-core/ShellCoreV5.dfy`: `AuthorizesX` :37, `AuthorizesXIs` :44, `FoldSnoc` :88, `FoldResume` :95, `MoneyInd` :227, `ReplayRowsAuthorized` :266, `AuditV5SoundRelativeToSuppliedInitial` :317, `AuditV5CompleteForHonestCommits` :452, refusal lemmas :482-548.
  - `proposals/m1b-mission-20261119/proofs/sink-core/inputs/sink/SinkCore.dfy`: `EncInjective` :69, `ChainPrefix` :303, `ChainSum` :321, `ZeroAmountRepeats` :390.
  - `proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy`: `CommitKeepsDistinctIds` :163, `InvMeaning` :244.
  - `clearing/RefundExact.dfy`: `AcceptsAndRejects` :25, the non-vacuity pattern.
  - `impl/RefundFinality.dfy`: `ContextOf` :23. Its rule 3 sets `requestOpen = true`; V1 replaces it by `ContextAt`.
- Format and verdict precedent: `tests/mcp_proxy/verify_independent.py` (349 lines; stdlib only; shares no code with the engine; `VERIFIED …` exit 0, `FAILED at=<i> <reason>` exit 1, usage exit 2).
- Tools: `toolchain/pins.json` (Dafny 4.11.0, Z3, Node 24.3.0, Python); gate Dafny options in `gate/backends/dafny.py`.
- Placement rule: do not put a new file under `clearing/`; it changes the Slice 2 bundle (owner rule).

## Design (fixed by this specification)
- Inputs: `ledger.wal`, `ledger.epoch`, and optionally a dispatch transcript and a trust-root file. V reads the bytes directly. V never calls the sink's `state` or `replay`: those run `open_ledger`, which may cut a tail or refuse.
- Modules:
  - `StatefulSpec.dfy`: N2' of Report D s.1. It imports `RefundSpec` unchanged and is marked UNAPPROVED.
  - `RecordFormat.dfy`: F, with `Decode`/`Encode`, CRC-32, FNV-1a-128.
  - `Verifier.dfy`: the fold, as a method with a loop.
  - `Proofs.dfy`: the lemmas.
  - A small extern for file reading, the only trusted code outside Dafny's semantics.
- Verdicts and exit codes (proposed):

| Verdict | Exit | Meaning |
| --- | --- | --- |
| ACCEPT | 0 | D-1 holds; any torn tail is reported as TORN |
| VIOLATION i why | 1 | a well-framed record (CRC, chain and epoch valid) is not a `CommitStep` |
| USAGE | 2 | wrong arguments |
| MALFORMED i why | 3 | CRC failure before the last record, chain break, epoch gap or repeat, bad genesis, bad id padding |
| ROLLBACK | 4 | ratchet floor above the head, or the head does not extend the signed/anchored head |
| DISPATCH_MISMATCH j | 5 | a transcript line names an absent epoch, an epoch twice, or a wrong fnv or frame |

- Order of checks per record: framing (CRC, epoch, pre-hash, id padding), then the spec (`CommitStep`). A record that passes framing and fails the spec is a VIOLATION, also when it is the last record. The sink, by contrast, cuts it or refuses with EPOCH_REGRESSION (`sink.rs:118-121`).
- Compilation: two Dafny targets (JS with pinned Node 24.3.0, and Python with the pinned Python). Both must give equal verdicts on every corpus file.

## Missing lemmas (stated precisely)
- L1 `EncodeDecode`: `∀x: Rec. ValidRec(x) ⇒ Decode(Encode(x)) = Some(x) ∧ |Encode(x)| = 64`. `DecodeEncode`: `∀b: bytes[64]. Decode(b) = Some(x) ⇒ Encode(x) = b`. This includes the NUL-padded id, little-endian u64, kind byte and CRC field.
- L2 `FoldSound`: the loop invariant `states[k] = Fold(recs[..k])`, plus `V = ACCEPT(n, σ) ⇒` the D-1 conclusion (Report D s.2). Adapt `FoldSnoc`/`FoldResume`/`ReplayRowsAuthorized`.
- L3 `AtMostOnce`: `History(g, steps, states) ⇒ ∀i<j. steps[i].id ≠ steps[j].id`. It follows from `requestOpen` in `Eligible` and the monotone `settled`; reuse the `CommitKeepsDistinctIds` pattern.
- L4 `Conservation`: `History ⇒ Σ amounts = original − last.remaining ∧ 0 ≤ last.remaining`. Adapt `MoneyInd`/`ChainSum`.
- L5 `TailClass`: V returns ACCEPT only if the tail is `Torn`. A 64-byte tail with a valid CRC never yields ACCEPT unless it is a valid `CommitStep` record.
- L6 `NonVacuity`: a concrete W with genesis + 2 refunds is accepted; a concrete well-framed W with `amount > remaining` gives VIOLATION. This follows the `AcceptsAndRejects` pattern.
- L7 `Completeness` (desired): every W of the D-1 shape is accepted. If it is not proved, it is TESTED_ONLY through the differential test.
- L8 `DispatchMatch`: if a transcript is given, ACCEPT implies the D-1 transcript clause.

## Required tests (each with its expected verdict and exit code)
1. A real WAL made by the unchanged sink and the real binary, with genesis + ≥ 2 refunds: ACCEPT, 0.
2. Zero-amount refunds with fresh ids: ACCEPT, 0. This documents `ZeroAmountRepeats`.
3. A torn tail (< 64 bytes, and 64 bytes with a bad CRC): ACCEPT with TORN, 0. The same plus a transcript that names that epoch: DISPATCH_MISMATCH, 5.
4. A well-framed record with `amount > remaining`, in the middle and at the end: VIOLATION, 1, in both places.
5. A well-framed duplicate request id, in the middle and at the end: VIOLATION, 1.
6. Kind byte not in `'1'..'3'` (well-framed): VIOLATION, 1.
7. Bad CRC before the last record: MALFORMED, 3. Chain (pre-hash) break: 3. Epoch gap or repeat: 3. No genesis, or genesis original > MaxMoney: 3. Non-zero id padding or a non-canonical id byte: 3.
8. Ratchet floor above the head: ROLLBACK, 4.
9. Transcript naming an absent epoch, an epoch twice, or a wrong frame: DISPATCH_MISMATCH, 5.
10. Planted engine bugs, detected from the log alone:
    - Two changed copies of `sink.rs`, built in a scratch folder: (a) without the check at `:171`, (b) without the check at `:167`. Each runs with a stub "binary" that echoes the expected frame.
    - Each copy commits a disallowed refund and prints COMMITTED. V on the WAL bytes gives VIOLATION, exit 1.
    - Control: the unchanged sink, restarted on that WAL, gives EPOCH_REGRESSION (exit 15) and never reports a spec violation. The run records this as a finding.
11. Differential:
    - The test harness (test code only, not `sink.rs`) keeps every ledger folder of the 13 suite cases and of the 49 mutant runs.
    - Every WAL that the unchanged sink's `state` accepts without a cut: V gives ACCEPT with the same (epoch, tail, remaining).
    - Every WAL: V's verdict agrees with `reference_eligible` (`test_silicon_crash.py:346`) on each well-framed record.
    - Any disagreement is a finding. Exit 0 means 0 disagreements.
12. Target diversity: the JS and Python builds give equal verdicts on all files of tests 1–11.
13. Audit controls: a copy of `Proofs.dfy` with an added `{:axiom}` lemma `ensures false` makes the audit script exit 1. A copy of `Verifier.dfy` without the amount check fails `dafny verify` (exit ≠ 0).

## Expected evidence artifacts
A tracked folder, for example `proposals/v1-recheck-verifier/`, containing:
- the four Dafny files and the extern;
- `dafny verify` and `dafny audit` logs with exit codes;
- SHA-256 values of the compiled outputs;
- `corpus/MANIFEST.json` (SHA-256 of each WAL and its source);
- `records/verdicts.json` (file → verdict, exit, for both targets);
- `records/negative-controls.json`;
- `records/differential.json`;
- `REPORT.md` with statuses in the six words.

A driver `scripts/exit_v1_verifier.py` with cases `build`, `verify`, `negative`, `planted`, `differential`, `evidence`. In the precedent of the EXIT scripts, `evidence` runs all cases twice in fresh folders and requires byte-identical bundles.

## Definition of done (checkable)
1. `dafny verify` (pinned 4.11.0, options of `gate/backends/dafny.py`) gives exit 0 on all V1 modules. The verified count is recorded.
2. `dafny audit` lists no `{:axiom}`, no `assume`, no `{:verify false}`. The only `{:extern}` is the named file-read shim. Control 13 exits 1.
3. A script compares the text of `D1_RecheckSound` in the tracked file with Report D s.2 (normalised whitespace, SHA-256): exit 0.
4. `spec/refund/RefundSpec.dfy` still hashes to `90a21c71…`. No protected path changed. N2' and F carry the label UNAPPROVED.
5. Tests 1–13 give the listed verdicts and exit codes. Planted bugs (test 10): 2 of 2 detected. Differential (test 11): 0 disagreements. Target diversity (test 12): 0 differences.
6. `scripts/exit_v1_verifier.py --case evidence` gives exit 0 with two byte-identical bundles.
7. `ROADMAP.md` and `unsure.md` record actual exit codes apart from expected ones, with `end_to_end=false` and M1-B OPEN.
8. The report states the remaining trust: H_SPEC' (unapproved), H_VTOOLS, H_LOG.1–4.

Out of scope: approval of N2' and F (owner, V1-S); V2–V5; any change to `sink.rs` or to a protected file; any HOL work.

## Size (estimate; not measured)
1 to 3 weeks of focused work. The basis:
- `SinkCore.dfy` (412 lines) and `ShellCoreV5.dfy` (615 lines) were each written and verified within one night-shift wave.
- `verify_independent.py` (349 lines) is a comparable format checker.
- The suite and mutant harness exist.

Not inventoried:
- Dafny 4.11.0's file-read support and Python-target behaviour on this machine.
- The cost of bit-level CRC-32/FNV-128 in Dafny.
- The harness change that keeps ledger folders.

## Second task: M1-R (reproducible M1), corrected facts
Goal: rebuild the M1 chain and its top layer from a clean clone, on one machine (P1). A second operator follows later (P2).

Facts (re-checked):
- Phase 1: 71 theories replayed on one machine, 2026-11-18. 4 of 15 recorded ARMv8 tool files differ after the tool rebuild. 10 cases ran in "direct mode" without the identity check (`records/arm8-tool-identity.json` note; `summary.json` notes).
- Phase 2: 24 theories replayed on the same machine. `forge_refundInputSat` is in the phase-1 rows (row 73).
- Top layer: LOut, ModelFrame, RouteAFlat and FlatContract have 0 hits in `plan*.json`/`summary*.json`.
  - LO-0006, MF-0002, PF-0004 and PX-0001 have only a same-machine reproduction on stored older parents (`orch-A/repro/RESULT.json`).
  - R1 has RA-FLAT-0001/0002; FC1 has Holmake 0001/0002.
  - The case scripts are tracked on `main`.
  - Their parents are loaded from 34 `results/…` folder names (`RA-FLAT-0002/command.json`, my regex; the reviewer counted 33). None is tracked.
  - The backup branch `c003a982` holds the phase-1 sources (259/259 per `CLEAN_REPLAY_PLAN.md:30`). It does not hold the top-layer scripts (`git ls-tree` grep: only an `InputSat` theory export, which is also on `main`).
- Pins: Poly/ML `4557554…`, HOL `9783a49…`, CakeML `cd91556…` (`CLEAN_REPLAY_PLAN.md:33-35`). Only commit hashes are recorded; there is no tarball digest.

Steps:
1. Inventory (P0).
2. Restore list and tracked sources, including the top layer and its parents.
3. Tool tree from the pins.
4. A single driver.
5. Statement-identity and tag checks: `thm_to_string` hashes, and the oracle field = `DISK_THM` only, as in `e4-0001.sml:17-19`.
6. Negative controls: a planted `cheat`, a changed statement, a one-byte binary change, a wrong tool pin, an untracked source. Each one gives a non-zero exit.

Size: not shown. The inventory comes first. The plan's own recorded budget covers phase 1 + 2 only.

What M1-R gives: outsiders can check the machine-code theorem, which is the path to M1-B and to D-2 C4. What it does not give: any strengthening of D-1.

## Method note
No HOL, Holmake, Dafny, build or test ran. Statuses come from committed records and source text. Base `058eabcb`, 2026-11-20.
