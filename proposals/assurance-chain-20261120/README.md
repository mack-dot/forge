# Forge assurance chain: final answer and index (2026-11-20, revised after review)

Read-only investigation of `origin/main` `058eabcb`. `end_to_end=false`. M1-B OPEN. Nothing here is a proof. No HOL, Holmake, Dafny, build or test ran.

## The answer

Question: "What is the shortest technically defensible path to making Forge a system where an independent verifier can establish that an actual, durable execution respected its original authorization specification?"

1. Today no independent verifier can establish it. Receipts are unkeyed assertions of the engine that wrote them. No program checks a durable log against the spec. No stateful spec is approved (Report B, A1.5).
2. Both refund engines check every conjunct of `Eligible` (`RefundSpec.dfy:33-36`) in native code after the binary answers. The checks run on the state read under the lock (`sink.rs:163-171`, `verbs.rs:72-73,177`). The only exceptions are the two flag bits `refundEnabled` and `requestOpen`. A stateful spec that sets those two bits from stored state closes that gap. So the M1 machine-code theorem does not support any safety conclusion. It supports only completeness: the binary does not refuse an eligible request (Report D, D-2 C4).
3. The shortest path is detection, not prevention. V1 is a small verifier, proved in Dafny against a new stateful spec. It folds the existing silicon-sink WAL and checks `Eligible` at each pre-state, the effect and id freshness (theorem D-1). It needs no M1, no Rust proof and no binary proof.
   Still trusted after V1: the meaning of the stateful spec and its approval (MISSING today); Dafny/Z3; the unverified Dafny compiler and its runtime; the file-read extern; H_LOG (the bytes are the full durable state, and every dispatched effect is a record).
4. V2 adds a witness under a second uid. It runs V and then signs the head. This makes "nothing was rewritten or cut after the witness saw it" a checked fact. Still trusted: the witness host, key custody, H_CRYPTO.
5. V3 adds an external anchor. It makes a joint restore of WAL and ratchet, or a fork, detectable. Still trusted: the anchor operator.
6. V4 adds provider reconciliation. It makes "each external effect matches exactly one record" a checked fact. Still trusted: the provider's report, and the drive before the witness first reads a record.
7. What stays out of reach: prevention (a bad transition is found only after it is durable), liveness, hardware behaviour, and who asked for the request (no provenance field).
8. Prevention (D-2) is the longer path. It needs a WAL and crash model plus H_WAL (tests only). M1-R and M1-B matter only for completeness, or for a design where the binary decides alone.
9. Hardware attestation changes no conclusion of D-1. D-1 is a statement that is not yet proved.

## Reports and annexes

| File | Content |
| --- | --- |
| [REPORT_A_CURRENT_STATUS.md](REPORT_A_CURRENT_STATUS.md) | What Forge establishes today, by category; corrected counts |
| [REPORT_B_DEPENDENCY_GRAPH.md](REPORT_B_DEPENDENCY_GRAPH.md) | Edge-by-edge graph with added edges; per-arrow verdicts; three lines (P, R, V) |
| [REPORT_C_BLOCKERS.md](REPORT_C_BLOCKERS.md) | Blockers ranked for the detection path; what each blocks |
| [REPORT_D_MINIMAL_THEOREM.md](REPORT_D_MINIMAL_THEOREM.md) | D-1 (detection, minimal) and D-2 (prevention, longer), with hypotheses per conclusion |
| [REPORT_E_ROADMAP.md](REPORT_E_ROADMAP.md) | Roadmap: detection first; checkable acceptance criteria |
| [REPORT_F_NEXT_IMPLEMENTATION.md](REPORT_F_NEXT_IMPLEMENTATION.md) | V1 specified (not executed); M1-R as the second task |
| [ANNEX_1_SPEC_PROOF_COMPILER.md](ANNEX_1_SPEC_PROOF_COMPILER.md) | Investigator 1 (see corrections below) |
| [ANNEX_2_RUNTIME_DURABLE_RECEIPT.md](ANNEX_2_RUNTIME_DURABLE_RECEIPT.md) | Investigator 2 (see corrections below) |
| [ANNEX_3_HARDWARE_PATH.md](ANNEX_3_HARDWARE_PATH.md) | Investigator 3 |

## Method and limits

- Base: worktree of `origin/main` `058eabcb`. I used three investigator annexes, one hostile review, and then my own re-checks with cheap commands: `git ls-files`, `git ls-tree`, `git grep`, `git merge-base`, `shasum -a 256`, `wc -l`, `python3` over JSON, `grep`/`sed` over sources. "Re-checked" in a report means that I ran the command.
- A MACHINE_CHECKED status rests on a committed run record named per edge. None of these runs was repeated here.
- Only the six status words of the mission are used. A check by an unproved script is TESTED_ONLY.
- Statements in Report D are TARGETS. None of them is proved. Sizes are estimates, and each one names its basis.

## Corrections to the annexes (the annex files are not edited; these lines replace them)

- Annex 1 F5:
  - "no … oracle tag" is wrong. Each stored theorem in the 56 tracked `.dat` files has the oracle field `DISK_THM`: 874 + 140 entries, matched by a regex on the tag field.
  - The scripts' tag check allows only `DISK_THM` and no axioms (`…/final-cases/e4-0001.sml:17-19`). That check is the real evidence. 0 files contain `MK_THM` or `cheat`.
  - `*Script.sml`: 10 files, 5 names, 6 distinct contents (not "4 distinct").
  - The ".sml distinct" count is 194 for non-generated files by SHA-256, and 229 for all files.
- Annex 1 E10, line 163 and line 222:
  - LO-0006, MF-0002, PF-0004 and PX-0001 have a same-machine reproduction from committed sources on stored older parents (`proposals/night-shift-20261119/orch-A/repro/RESULT.json`). It is not clean.
  - 10 cases of the 71-theory replay ran in "direct mode", without the tool identity check (`summary.json` notes; `arm8-tool-identity.json` note).
  - "Size: days" is not shown.
- Annex 2: the airlock has 2,283 lines (9 files), not 1,989.
- Annex 2, line 36: rustc 1.92.0 is enforced only by `scripts/exit_silicon_sink.py:49,213-215`. The hosted airlock CI runs on `macos-15` with the runner's rustc and enforces no pin (`airlock-ci.yml:34,76`).
- Annex 2, lines 286-287: "re-execution under the same trust" holds when a verifier re-runs the binary or the engine. It does not hold for a verifier that evaluates the spec predicate itself. That case is D-1.
- Annex 2, E7b/E8: still valid. But the refinement link it proposes serves prevention (D-2), not the detection path.

## Review dispositions

| # | Verified? Evidence (my commands) | Action |
| --- | --- | --- |
| 1 | Yes. `FINAL_STATEMENTS.txt:1996-2062`: PF-0004 `refund_render_fields_prefix_code`, `refund_strict_parse_no_strict_prefix`; PX-0001 `refund_frame_decision`, `refund_strict_parse_exact`. The `.dat` files are tracked. Same-machine repro in `orch-A/repro/RESULT.json` | B: A6.8 split into A6.8a (MACHINE_CHECKED) and A6.8b (Rust `frame()` text, TESTED_ONLY). E: E2 reduced to that one piece |
| 2 | Yes. `.github/workflows/airlock-ci.yml:76` `runs-on: macos-15` | A s.3 corrected |
| 3 | Partly. CI: `airlock-ci.yml:34` "no version pin is enforced"; `toolchain/pins.json` has no rustc. But `exit_silicon_sink.py:49,213-215` refuses any rustc other than 1.92.0 | A s.3 and B A4.5 say both |
| 4 | Yes. `wc -l src/airlock/*.rs` = 2,283 (9 files) | A s.1 corrected |
| 5 | Partly. LOut, ModelFrame, RouteAFlat and FlatContract have 0 hits in `plan*.json`/`summary*.json`. RA-FLAT-0002 loads parents from 34 `results/…` names (my regex), 0 tracked. The backup branch has none of these scripts. BUT: InputSat is replayed (`summary.json` row 73). LO/MF/PF/PX have a same-machine repro. R1 has RA-FLAT-0001/0002. FC1 has Holmake 0001/0002. Case scripts (`LO-0006.sml`) are tracked | "No replay of any kind" replaced by "no clean replay, no restore list, parents untracked". F: inventory is the first step of M1-R; no duration given |
| 6 | Yes, with a limit. `sink.rs:163,167,168,171`, `verbs.rs:72-73,173,177` against `RefundSpec.dfy:27-36`. Not rechecked: the flag bits (`sink.rs:133` spelling only; `verbs.rs:174` constant `True`) | D restructured into D-1 and D-2. D-2 gives the hypotheses per conclusion; M1 supports only C4 |
| 7 | Yes. `RefundSpec.dfy:38` stateless `Assess`; `FinalityProtocol.dfy:1`; `DESIGN.md:281` "NEW intent". Draft found: `proofs/sink-core/SPEC_STATE_PROPOSAL_U8.txt` ("NOT approved") | B: edge A1.5 MISSING. D: new spec text listed |
| 8 | Yes (logic). `machine_sem` and `basis_ffi` have no Dafny image | D-2: H_BRIDGE named, with a consistency control; all-HOL variant compared |
| 9 | Yes. `sink.rs:92` (`l.ids.insert` in the condition; `break`) | D-2 C2 restated over dispatched effects across crash histories; W bound to the trace |
| 10 | Yes. `sink.rs:192` (binary) before `:166` (`open_ledger`). The airlock locks first (`store.rs:142`). It affects safety only if the native checks are removed (the CAS at `:168` refuses a stale request) | D-2b gives the needed change. The `refundEnabled` choice is recorded as a spec decision |
| 11 | Partly. `policy/refund.yaml` holds proof tiers (claims → methods), not reasons. The reasons come from `RefundSpec.dfy:24` | B: A1.6 (TESTED_ONLY), A1.7 `m.canonical` (MISSING), A9.6–A9.9 added |
| 12 | Yes. `FinalityProtocol.dfy:9-13` A1–A4 | A and D list A2/A4; D gives the instantiation for an unauthenticated sink |
| 13 | Yes, and more. `results/ops-readiness` is untracked. U225 (`unsure.md:5615`): CI FAILURE overall; receipt "recovered from … job-log chunks". Booking candidate `46e5aa42` is not an ancestor of `main`; `impl/Booking.dfy` differs by one line | B A2.2 downgraded to MACHINE_CHECKED (ledger) or "candidate only" (booking) |
| 14 | Yes. `refund_file` comes from an ML `BinIO` read. `forge_refundImage` `.dat` exists only on the backup branch | B A5.1 → ASSUMED (H_READ) |
| 15 | Yes, and more. 32 of 56 `.dat` contain "oracle". Every theorem's oracle field is `DISK_THM` | A s.2: the tag-field result and the script check are stated |
| 16 | Yes. Flags at `sink.rs:133`; ratchet filter/max at `:114-115`; "does not hash the binary" at `:14` | Line numbers fixed |
| 17 | Method issue. 229 distinct by SHA-256 overall; 194 distinct among non-`*Theory.sml` | Both counts given, with methods |
| 18 | Yes. `arm8-tool-identity.json` note; 4 of 15 differ; 10 rows "direct mode" | A, B, F state it |
| 19 | Yes | E rewritten: P1 has no second operator; mechanical audit for E5; N set; H0 has no dependencies |
| 20 | Yes | "Days" and "smaller than a Rust proof" removed; every size names its basis |
