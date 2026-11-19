# Unproven transitions to `end_to_end=true`, version 2 (Orchestrator A, worker W-gaps, 2026-11-19, read at 16:32Z)

Status: `end_to_end=false`. M1-B OPEN. This file promotes nothing. It does not propose to set `end_to_end`.
It does not replace `END_TO_END_GAPS.md`; that file is unchanged. Everything here is BY READING of the stored files.
W-gaps ran no HOL, no Dafny, no test and no git command. For each tonight case cited as MACHINE-CHECKED, W-gaps saw
`go exit 0` as the last line of its `.go.log`. "Same machine" applies to every HOL result. No result has a clean
replay or an independent-machine replay. "Repro" = the case was reproduced from the branch (`repro/RESULT.json`,
head dae1b93e; same machine; stored older parents).
Track B's claims (issuer, sink, admission) are cited as B's claims. W-gaps did not judge them again.

## 1. Smallest missing refinement boundary

X8 (transition T13): "a real run of image b8ed5ec2…7bb8 that meets the 23 native rows is a run of the totalised
machine model (`targetSem`) from `ms_27`". Its model part is 15 lemmas (ML-01..ML-15), none stored. Its native part
is 23 rows. HOL alone cannot close the native part.

## 2. The chain, from approved requirement to committed effect

Classes: MC = MACHINE-CHECKED; AS = ASSUMPTION (named); TU = TESTED-UNPROVED; EP = ENFORCED-BY-PROTOTYPE (launcher v2:
tested, unverified, not deployed); MI = MISSING. Where sources disagree, the weaker class is used (see §8). A row with mixed parts gets
the class of its weakest part. Row counts: MC 7 (T1, T2a, T5, T6, T7, T8, T8v; T7 UNCONFIRMED tonight; T8 and T8v under
premises or partial), AS 6, TU 1, EP 0 (as a whole row), MI 10.

| # | Transition | Class | Evidence or gap |
|---|---|---|---|
| T1 | Approved R1–R5 ⇐ flat contract (Dafny `LinkedRefund`) | MC (Dafny; B's claim) | B's records; review-link (a) agrees |
| T2a | Predicate generated from export bytes 58154ddf… ⇔ `FlatContract` | MC (Dafny `ExportBridge`, 1823; B's claim) | B MORNING §1 row 8 |
| T2b | The reader that produces that predicate reads the export bytes right | AS (A-READER; trusted Python reader) | review-link (b): TESTED-UNPROVED; 15 semantic mutants break it (B) |
| T3 | Dafny meaning of the 3 clauses = HOL `evaluate_exps` meaning | AS (BETA) | no artefact relates the two semantics |
| T4 | Dafny source → export bytes (exporter fidelity) | AS (A-EXPORTER; record only) | build folder absent; review-link (b) |
| T4i | Input encoding: stdin bytes = `refund_request` of the nine values the caller means | MI | review-link (g); review-MF list. NOT in the old list |
| T5 | Exported clauses hold exactly on HOL `refund_fields` | MC: link cases H1, H2 (`go exit 0` seen in `link/run/attempt-0001`) | 11 controls; checker defects A, B (review-link). H1/H2 not in the repro list; `contract-0001` repro: relation to H1/H2 UNCONFIRMED |
| T6 | `refund_fields`/render = the compiled program's source behaviour | MC: U294 replay (S5: R1, R3 `go exit 0` seen) | earlier M1 chain |
| T7 | Source → ARM64 code slices (CakeML compiler correctness, exact bytes) | MC (earlier M1 chain; same-machine replay 71 of 71, M1R-1) | go.logs of that chain NOT seen by W-gaps: UNCONFIRMED tonight |
| T8 | Model machine run → behaviour → descriptor-1 bytes → strict parse → exported clauses | MC under premises: MF-0002 (M3), MG-0001, L2d-0001, MT-0001, LO-0006, LE-0004, PX-0001, PF-0004 | all `go exit 0` seen; all except MT-0001 repro. MT-0001: model level only (review-MT). Premises: T9–T13 |
| T8v | Premises of T8 are jointly satisfiable | MC for the shape antecedent only: NV-0003 (`go exit 0`) | review-NV: no stored witness for MT1; no witness that a run ends in Success with a strict frame |
| T9 | FFI premise (old route): contract at shape-valid calls, or R6 | MI | Off the shortest path since the X8 route (§1); kept as the route to an all-states claim. R6 parts: R6ffi-0002, R6w-0004, R6r-0004 (`go exit 0` each); R6base-0001. R6 OPEN (review-R6w (a)–(e), review-R6r). A-3 |
| T10 | Entry state: the real process at `cml_main` meets M3's P1–P5; bounds | MI (parts: N16 AS; ML-10 MISSING) | dyld, C start-up, allocation are outside the proved slices |
| T11 | Processor bits TBI0, TBI1, SA0; EL0; E0E | MI (parts: N02, N03, N04 AS; ML-05, ML-07, ML-08, ML-09 MISSING) | one-step erasure MC: EE-0001, E1-0003 (`go exit 0`; repro). Run lift MISSING |
| T12 | Descriptors: fd 0 = fresh blocking pipe with exactly req; fd 1 fresh, empty, drained | MI (parts: N09, N11, N20, N21 EP; ML-04 MISSING) | launcher v2; CE-2 class closed by test (AC1-b, AC1-c) |
| T12k | Kernel read/write results = model oracle (`no_ext`; no EPIPE/EAGAIN; N10, N12, N13) | AS | not observable after the run; T6 perturbation test NOT RUN |
| T13 | X8: real process refines the totalised model (15 ML lemmas, 23 N rows) | MI | §2.1, §2.2 |
| T14o | Bytes the consumer reads = descriptor-1 bytes of the process | AS (parts: N22 read-to-EOF EP; no libSystem exit flush to fd 1 AS, F-15) | CONTROL_MATRIX_v2 §2 |
| T14a | `frame.strict_parse` = `refund_strict_parse` restricted to non-negative amount and count | TU | C's differential: 200,000 mutated frames, 0 bad (C's run; hand transcription of HOL); `consumer_attack.py` 304,326 inputs (author's run, review-PF) |
| T14b | The program prints non-negative amount and count only | MI | TRUE by reading (`nonneg/ANALYSIS.txt`). HOL case NN-0001: `.go.log` exists, started 16:28:57Z, a `hol` process runs, last line `USED_FILES_PRE …`, no `go exit` line at 16:32Z: RUNNING, no result |
| T15 | Launch environment: no injected loader code; fixed env; pinned image | AS (parts: N15 child env EP; L1, L2, L7 EP; N16, N17 AS) | launcher interpreter: OPEN (AC2-n2, n3, n4/n5, NEW-12; consumer duty). Owner A-5 |
| T16 | Native result → issuer decision (edge X16) | MI in the deployed path (B's claim) | issuer calls the compiled Dafny checker; bridge drafts x-bridge2/x-bridge3 TU (B); B-6 |
| T17 | Issuer → token → sink → committed state (TypeScript, SQLite, admission) | MI for deployed code (B: "MISSING: any proof about deployed code") | Dafny models MC (B); deployed `sink.ts` has a proved decision defect (B §2.1); hardened branch TU (B add. 24) |
| T18 | Trust base: HOL kernel, Dafny/Z3, CakeML pinned tools; clean and independent replay | MI (parts: tools AS; clean and independent-machine replay MISSING) | none run |

### 2.1 T13 model part: X8 v3 lemmas (status at 16:32Z)

PROVED = stored theorem, `go exit 0` seen. ECNS = EXPLORATION-CLOSED-NOT-STORED.

| ML | Name | Status | Note |
|---|---|---|---|
| ML-01 | T-ENV-NEXT (`interference_ok (next_R X)`) | MISSING | rests on `interference_ok_arm8_iff` (earlier session; no go.log seen) |
| ML-02 | T-ENV-FFI (FFI_FACTS ⇒ `refund_ffi_contract_on … Vok_R F_R`) | MISSING | |
| ML-03 | T-ENV (instantiation of `refund_env_ok_sl_of_contract_on`) | MISSING | base PROVED in L1-0001 (repro) |
| ML-04 | T-FS (`wfFS`, `STD_streams`, stdin = req) | MISSING | rests on `liveFS` (LIBRARY) |
| ML-05 | L-GHOST (fields outside OBS/RD unread at EL0, no exception) | MISSING | by reading only (D1, D2); FALSE without the EL premise |
| ML-06 | L-X18-DECODE | MISSING | test T5 PASS (TU) |
| ML-07 | L-SP-NOWRITE | MISSING | test T5: 0 uses (TU) |
| ML-08 | L-UNTAGGED-RUN (entry + run) | MISSING | U2, U3, U4 PROVED in EE-0001 (slide-0 forms only) |
| ML-09 | L-ERASE-RUN | MISSING | `NextStateARM8_erase` PROVED (EE-0001); `arm8_ok_erase`, `erase_fields` PROVED (E1-0003) |
| ML-10 | T-ENTRY27 | MISSING | S2 `refund_entry_run_sl` has no go.log line (D6) |
| ML-11 | T-TRACE | MISSING (refund instance). Generic core ECNS | TRx-0003 (exploration, `go exit 0`): 37 of 41 closed, incl. `evaluate_follows_trace`, `trace_io`. Nothing stored. Proof driver TR1-0001 queued, no go.log. Name map ML-11 ↔ generic lemmas: UNCONFIRMED (v3 D10) |
| ML-12 | T-KILLED-PREFIX | MISSING | nearest generic lemma `trace_terminate` NOT closed in TRx-0003 (step 1); `prefix_of_halt` closed (ECNS). Map UNCONFIRMED |
| ML-13 | T-INFLIGHT | MISSING | |
| ML-14 | T-X8-COMPOSE | MISSING | inputs PROVED: MF-0002, LE-0004, LO-0006, PX-0001 |
| ML-15 | L-NO-CLOSE-OPEN (would replace N23) | MISSING | source reading says unreached (v3 §1.9); not proved |
| ST-1 | (optional) MT1 `refund_model_frame_totalised` | PROVED (MT-0001) | model level; no stored non-vacuity witness for it |
| ST-2 | (optional) non-vacuity | NV-0001 NOT RUN; NV-0003 PROVED for the shape antecedent only | does not cover MT1 |

Counts ML-01..ML-15: PROVED 0; ECNS 0 complete (1 partial: generic core of ML-11); MISSING 15.
`trace_fail` (generic) also NOT closed. HOL definitions REAL_RUN, PREM, STDOUT, END, EV_i, rstate: MISSING.

### 2.2 T13 native part: 23 rows (class under launcher v2; falsifier from X8 v3)

| N | Name | Class | Falsifier |
|---|---|---|---|
| N01 | A-CPU-ISA (L3 step = hardware step, every reached word) | AS | single-step differential T3 with one OBS difference |
| N02 | A-PROC-N1 (EL0, AArch64, E0E = 0, no pending exception) | AS | big-endian load result; N01 mismatch |
| N03 | A-F0-REAL (5 bits constant and = sr) | AS | alignment fault in one run, not another |
| N04 | A-PROC-N2-SP | AS | recorded SP mod 16 ≠ 0 |
| N05 | A-KERNEL-PRESERVE(+SP) | AS | T6 stdout difference; register or dm change across preemption |
| N06 | A-SINGLE-THREAD | AS | thread count > 1 (C9: threads = 1, one run, C) |
| N07 | A-FFI-EFFECT-AT-CALLS(+SP) | AS | T4 inequality |
| N08 | A-FFI-FRAME | AS | T4 checksum; T2 layout |
| N09 | A-FD0-SETUP | EP | launcher record |
| N10 | A-FD0-SEM | AS | T4 on reads |
| N11 | A-FD1-SETUP | EP | launcher record; CE-1, T08 |
| N12 | A-FD1-SEM | AS | T4 on writes; stray stdout byte |
| N13 | A-FD1-PARTIAL | AS (v2 REFUSES killed runs) | cut run whose stdout tail is not a prefix |
| N14 | A-SIG-DFL | EP (child) | record of SIG_IGN or a handler |
| N15 | A-LOADER | EP (child env empty); interpreter OPEN | CE-3 |
| N16 | A-ENTRY | AS (partly bound by L2, L7, V6) | T2 values outside the bounds; F-14 measurement env UNSURE |
| N17 | A-IMG-STABLE | AS (CDHash checked once) | slice digest at exit ≠ file |
| N18 | A-NO-SHARED | AS | dm checksum change with one thread |
| N19 | A-NO-DEBUGGER | AS (task exception ports reset, V1) | attach record |
| N20 | A-ENTRY-STDIN | EP | launcher log ≠ req |
| N21 | A-STDOUT-EMPTY | EP | launcher record |
| N22 | A-OUT-DELIVER | AS (read-to-EOF part EP; exit-flush part assumed) | byte total ≠ sum of nw |
| N23 | A-NO-CLOSE-OPEN | AS (or ML-15) | call trace with close or open_in |

Counts: AS 17, EP 6. (X8 v3 counts 16 + 7; W-gaps puts N22 in AS, see §8.)

## 3. Attack classes on the launch path

All rows below: TESTED-UNPROVED. Matrix: `launch/CONTROL_MATRIX_v2.md`.

| Class | Premise | Control | Test, who ran it | State | Residual OPEN rows |
|---|---|---|---|---|---|
| AC-1 truncated or empty stdout with exit 0; closed or non-blocking descriptors (CE-1, CE-2) | N09, N11, N20, N21, N22; decision rule | L4 fresh blocking pipes; L9 drain to EOF; D5–D7 strict frame; V0/V2 own `wait4` | `old/test_ac1.py`, `test_v2_findings.py`, `test_mutants_v2.py`: author, exit 0; A re-ran (`recheck-A`, `recheck-A2`, exit 0); C ran 24 lifecycle conformance tests on v2, exit 0 twice (bash test child, not the refund program) | CLOSED-BY-ENFORCED-CONTROL (tested) for AC1-a..f, NEW-1 in-process route | AC1-a: launcher's own EAGAIN write path not exercised; NEW-1 caller-exec route NO-FAILING-SIDE |
| AC-2 code injected at load; launcher integrity (CE-3) | N15, N16, N17 | L4 empty env; L1, L2 pinned image; L7 CDHash at check; close_fds | `old/test_ac2.py`, `test_mutants_v2.py`: author, exit 0; A re-ran. C's real-program injection attack: NOT RUN (C-1) | CLOSED-BY-ENFORCED-CONTROL for AC2-a, b, h–l, o; AC2-m by construction (no race test) | AC2-n2, AC2-n3 (forged line ACCEPTED via `DEVELOPER_DIR`), AC2-n4/n5 (consumer duty), NEW-12, T-2, T-3, T-4; AC2-g OWNER-OPTION (hardened runtime) |
| AC-3 hostile launch state; FFI misreport | N07, N09–N14, N19 | L4, `_child_setup`, V1, V6 | `old/test_ac3.py`, `test_v2_findings.py`, `test_mutants_v2.py`: author, exit 0; A re-ran | CLOSED-BY-ENFORCED-CONTROL for AC3-a, AC3-d, NEW-8; AC3-i CLOSED; AC3-b, c, e EXCLUDED-BY-CONSTRUCTION (positive only); AC3-g NO-FAILING-SIDE | AC3-j (C misreport at unreached states: R6 / A-3; NOT RUN), AC3-k (same-uid kill; NOT RUN), NEW-11 (SIGKILL cleanup), DATA rlimit not fixed, umask inherited |

## 4. "Never weaken" ledger (statements made weaker or narrower tonight)

| Item | Before | After | Why |
|---|---|---|---|
| X8 W1 | "stdout empty or strict prefix" for runs that violate A-FD1-WRITE | removed; X8 concludes nothing when a premise fails (C6) | did not follow (C-PREM-01 #4) |
| X8 W2 | STDOUT = concatenation of reached writes, every run | equality only for runs that end after H; cut runs: prefix of `fd1_written` of an extension | killed writes can leave bytes in the pipe (C-PREM-01 #3) |
| X8 W3–W6 | — | W3 adds a MISSING lemma (ML-12); W4 drops "same idea as CakeML"; W5 A-X18 becomes model lemma ML-06; W6 splits fd rows into SETUP (EP) and SEM (AS) | v1 corrections |
| X8 v3 V1–V3 | — | V1 N10/N12 admit n = 0 (weaker premise); V2 N03 narrowed to 5 bits (moves work to ML-05); V3 N23 added (PREM stronger; v2 silently lost runs) | review of v2 |
| T14 | "consumer parser = HOL `refund_strict_parse`" | FALSE as identity; split into (a) restricted identity and (b) non-negativity | C-PREM-02: `frame.py` refuses negative integers |
| MT-0001 | "composed theorem for the real effect" | MODEL level only; `interference_ok` and `contract_on` for a constructed environment NOT proved; MT2 only for Terminate Success | review-MT |
| NV-0003 | "joint non-vacuity witness" | shape antecedent only, abstract environment; NV2 weak; no witness for MT1 or MG-0001; no Success-with-frame witness | review-NV |
| R6r-0004 | "read-side bottom layer" | only `refillBuffer_with_read` and its wrapper; does not reach `io_events` | review-R6r |
| L2d wording | "premise false for the present C" | no `envmc` that describes the original C meets it (all stub states); not "the real run misbehaves" | review-L2d |
| Launcher matrix | AC2-m, AC2-n4/n5, AC2-c/d, AC2-e, AC3-b/c/e/g, AC3-i, AC2-a, AC1-a, AC3-a CLOSED | narrowed or OPEN (F-04..F-10) | review_launcher.txt |
| Old boundary | T9 is the smallest boundary | X8 (T13); R6 off the shortest path | END_TO_END_GAPS.md update 1 (by reading) |

## 5. NOT RUN or failed, kept (separate from results)

| Case or test | Actual | Reason |
|---|---|---|
| R6ffi-0002 repro | exit −15, no marker | watchdog after a system sleep; original run `go exit 0` stands; repro DIFFERS |
| R6w-0004 repro | NOT RUN | — |
| R6r-0004, MT-0001, NV-0003, H1, H2 repro | not in the repro list | single same-machine run |
| NN-0001 (T14b) | RUNNING at 16:32Z, no exit line | started 16:28:57Z in q44 |
| TR1-0001, TRx-0004, R6t-0004, TR2-0001 | NOT RUN (no go.log) | queued q44 or staged |
| TRx-0001, TRx-0002, NVx-0002 | exit 1 each | ML static error; toy control definition; statement construction. No proof step ran |
| R6rx-0003, R6r-0003, R6tx-0002, R6t-0002, NVx-0001, NV-0001, TR-0001 | NOT RUN | superseded (watchdog `Thread` names) |
| TRx-0003 required lemmas `trace_terminate`, `trace_fail` | not closed (step 1) | exploration only |
| R6tx-0003 `IOFS_V_init` | failed at step 3 (exploration) | repaired list; R6tx-0004 18 of 18 closed (exploration only) |
| MG-0001 repro, first try | Poly/ML "Run out of store" | infrastructure; second try reproduced |
| Old suite `test_positive_and_mutants` vs launcher v2 | exit 1 | stale mutants MUT-2, MUT-4 (bypass removed); replaced by `test_mutants_v2.py` |
| T6 perturbation differential under launcher | NOT RUN | owner approval needed |
| C's native launch-path attack (injected code, real program, FFI C) | NOT RUN | classifier stop (C-1) |
| AC3-j, AC3-k | NOT RUN | — |
| Clean replay; independent-machine replay of the HOL chain | NOT RUN | — |
| E1-0003, L2-0003 | exit 0, started below the swap rule | re-runs E1r-0001, L2r-0001 `go exit 0`, `.dat` byte-equal (A-1) |

## 6. Owner decisions that gate a transition

| Item | Decision | Transitions |
|---|---|---|
| A-1 | swap rule for HOL starts | evidence rule for T8, T11 (results re-run and equal) |
| A-2 | accept LO-0006 (bent stop) and LE-0004 | T8, ML-14 |
| A-3 | C FFI patch (model-total `basis_ffi.c`, new image digest) or R6 | T9, AC3-j; would change N07/N10/N12 and every record bound to b8ed5ec2… |
| A-4 | push permission (resolved for 6903135a) | none (evidence availability) |
| A-5.1 | adopt launcher as the only launch path + invocation rule | T12, T14o, T15; rows N09, N11, N14, N15, N20, N21; AC-1..AC-3 |
| A-5.2 | hardened runtime (re-sign; new pin) | T15 (AC2-g, AC2-n2) |
| C-1 | who runs independent attacks with the real program | AC-1..AC-3; T12, T15 |
| (new, implied) | accept the 17 AS native rows as the trust base, each with its falsifier | T10, T11, T12k, T13, T14o, T15 |
| (new, implied) | accept BETA, A-EXPORTER, A-READER as named assumptions, or order artefacts | T2b, T3, T4 |
| B-6, B-18 | issuer bridge; issuer store mode | T16 |
| B-1, B-2, B-8, B-10, B-12, B-13, B-14, B-15, B-16 | sink, minter, anchor, policy, suite | T17 (B's items) |
| B-3, B-5, B-7, B-11, B-17 | admission and gate | outside this chain (admission of code); B's items |

## 7. Shortest path to close the boundary of §1 (sizes are ESTIMATES)

| Step | Item | Size (estimate) | Blocked by |
|---|---|---|---|
| 1 | HOL definitions REAL_RUN, PREM, STDOUT, END, EV_i, rstate | medium | nothing; their form decides which N rows are expressible (D13) |
| 2 | Store the generic trace theory (TR1-0001), then close `trace_terminate`, `trace_fail` | small | single HOL slot |
| 3 | ML-01..ML-04 (environment and file-system instantiations) | small each | step 1 |
| 4 | ML-06, ML-07 (decode facts over the code slice) | medium | a decoder lemma over 130,436 bytes |
| 5 | ML-05 L-GHOST (all instruction classes of the subset) | large | D1, D2 |
| 6 | ML-08 slide forms, ML-09 run lift, ML-10 entry 27 steps | medium each | steps 4, 5; S2 has no go.log |
| 7 | ML-11 refund instance; ML-12; ML-13 | large; medium; medium | steps 2, 3, 6 |
| 8 | ML-15, or owner accepts N23 | large (program behaviour) or owner word | R6-like work |
| 9 | ML-14 compose; one non-vacuity witness for the composed premises | medium | steps 3–8 |
| 10 | Separate adversarial review of steps 1–9 | medium | step 9 |
| 11 | Owner: accept 17 AS rows; adopt launcher (A-5) for the 6 EP rows; independent attack run (C-1) | owner | §6 |

After the boundary, `end_to_end` still needs (not on this path): T14a (verified or HOL-extracted parser), T14b
(NN-0001 result and review), T2b, T3, T4, T4i, T16, T17, T18, and the owner's word. None holds today.

## 8. Disagreements between sources (weaker side taken)

1. T2: old list "MC, reader fidelity ARGUED" vs review-link "ASSUMPTION (TESTED-UNPROVED)": split into T2a MC (B) and T2b AS.
2. N22: X8 v3 "ENFORCED-BY-LAUNCHER" vs CONTROL_MATRIX_v2 "ENFORCED + ASSUMPTION (F-15)": AS.
3. X8 v3 "launcher NOT implemented" vs launcher_v2.py prototype exists: EP (prototype; not deployed).
4. CONTROL_MATRIX_v2 "independent attack run: none, every row" vs FINDINGS_FROM_C: C ran 24 lifecycle tests on v2 (exit 0); stale for lifecycle rows only.
5. Old T9 "FFI layer and write side proved" vs repro: R6ffi-0002 repro failed (−15), R6w-0004 repro NOT RUN.
6. Brief: NN-0001 "NOT RUN unless `go exit 0`" vs disk: go.log exists, run in progress: no result either way.
7. Input encoding (T4i) and output decoding are MISSING in review-link (g, h); the old list has no row for them.
8. ML-11/ML-12 ↔ generic trace lemma names: not mapped by any source (v3 D10): UNCONFIRMED.

## Update (2026-11-19T17:06:33Z) by Orchestrator A, after W-gaps wrote this file
- T14 part b: now MACHINE-CHECKED at model level: NN-0002 (actual exit 0; theory forge_refundNonNeg; reviewed: holds with
  limits). T14 part a stays UNPROVEN (residual R1 to R3 in `review-NN/REPORT.md`).
- X8 trace core: TR1-0001 and TR2-0001 are PROVED (actual exit 0; reviewed): `evaluate_follows_trace`, `trace_io`,
  `trace_terminate`, `trace_fail`, guard facts. They are generic: no arm8 or refund content. That a real trace satisfies
  `trace_ok` (the content of ML-11) stays MISSING.
- Plan R6: R6r-0004 and R6t-0004 PROVED (reviewed); the main V-spec and the state facts stay MISSING.
- NV-0003 PROVED: joint witness for the premises of the shape theorem, model level only.
- Reproduction: R6ffi-0002 and R6w-0004 run again now (result in `repro/RESULT.json` when done).

## Update (2026-11-19T17:12:10Z): leads from the red team's last reading audit (static; not checked by A)
- In the OLD file END_TO_END_GAPS.md, lines 52-56, 74, 77 and 18 are too strong (kernel read/write results cannot be
  enforced by a launcher; launcher version 1 has the SIGCHLD defect). Read this v2 file in their place.
- Two words-only items to add to the native rows: "abort writes nothing to descriptor 1" and "the program installs no
  signal handler" (static evidence only: no sigaction import in the image).
