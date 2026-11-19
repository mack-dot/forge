# Orchestrator A (proof track) state

Updated: 2026-11-19T11:05Z. CURRENT none. M1-B OPEN. `end_to_end=false`.

## Branch
- `nightshift/A-proof` from `985f5eaf`; worktree
  `/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/A-proof`. No commit yet.
- Partner B agent ID: `a56d4886a49375909`.

## STOP NOTE (11:05Z)
The harness required Orchestrator A to hand back at this time. A's loop STOPS here. Nothing runs for A after this note.
No HOL process of A runs. A holds NO lock.

## HOL slot
- `locks/hol.lock` does NOT exist: A released it at 11:03:33Z for B's fourth heavy window; B held `heavy.lock` at 11:05Z.
- To resume: wait until `locks/heavy.lock` is gone, `mkdir locks/hol.lock` (write `owner`), then in
  `results/m1b-routeA-20261119/attempt-0001`:
  1. `./queue.sh q30 "R6x-0004 1800 deps-R6x.txt"` (EXPLORATION; staged, NOT RUN; SHA-256 8a0fffb4…);
  2. only if its four explorations close: `./queue.sh q31 "R6ffi-0001 3600 deps-R6ffi.txt"` (PROOF; staged, NOT RUN; 3e8e30ec…).
  Sub-files are read by absolute path from `orch-A/r6/round4/` (do not move them).
- Later cases since the table below: EEx-0002 (exploration, exit 0), EE-0001 (exit 0, 101 theorems, `NextStateARM8_erase`,
  reviewed A31), R6x-0003 (exploration, exit 0).

## Replay (section 8): COMPLETE as far as sources exist (read 08:11Z from `phase3/results.json`)
- Counted first runs: 152 AS_RECORDED; 1 EXIT_EQUAL_REASON_DIFFERS (005); 2 EXIT_DIFFERS (130, 142); 3 NOT_RUN_NO_SOURCE.
- 005, 130, 142: first run stopped with Poly/ML `Run out of store - interrupting threads` during parent theory load
  (infrastructure, inconclusive; not a semantic result; cause heap-limit or failed OS allocation UNKNOWN).
  Second runs (stored under `rerun`, the first verdict stays the counted one): 005 AS_RECORDED exit 1 (driver);
  130 AS_RECORDED exit 0 and 142 AS_RECORDED exit 0 (Orchestrator A, `driver3.py rerun`, exit 0 each, 08:09Z–08:11Z).
- 094, 097, 098: sources UNAVAILABLE (0 hits by SHA-256 in 13542 git blobs and 22854 files; `orch-A/replay-debt/`).
- The replay is evidence reproduction on the same machine. It closes no proof obligation.

## Workers
| ID | Task | Evidence dir | State |
|---|---|---|---|
| A1 | replay debt | `orch-A/replay-debt/` | DONE, spot-checked |
| A2 | prefix lemma v2 static review | `orch-A/prefix/` | running |
| A3 | L-OUT, L-EXIT v3 | `orch-A/out-exit/` | DONE (static; v2 L-OUT has 3 blocking tactic defects) |
| A4 | link package | `orch-A/link/` | DONE (static; package ready; digests match) |
| A5 | L2, fficlose, erasure | `orch-A/ffi-erasure/` | DONE (static) |
| A6 | P9a, outcome table, native ledger | `orch-A/resource-native/` | running |
Workers cannot write `REPORT.md` (harness); A saves condensed reports.

## HOL queue (after the replay ends; one job at a time)
1. L1 (running), L1imp. 2. Link: `bash orch-A/link/run/attempt-0001/go.sh <CASE>` H0, H1, H2, controls, H4, NR1, R1–R3, I1.
3. Erasure E1 (`orch-A/ffi-erasure/erasure_v2.sml`). 4. L-OUT v3, then L-EXIT v3 (`orch-A/out-exit/`). 5. L2 v2. 6. Prefix (A2).

## Theorem attempts tonight (folder `results/m1b-routeA-20261119/attempt-0001`; wrapper `nightshift-run.sh <case> <cpu> [deps]`; queue `queue.sh`)
Every `<case>.go.log` ends with `go exit N`. Swap rule: PROTOCOL.md as amended ~09:00Z (deviation before that: OWNER_REQUIRED A-1, U485).
| Case | Source SHA-256 | Actual exit | Result |
|---|---|---|---|
| L1-0001 | 9ddf6746… | 0 | 16 theorems; `refund_ffi_contract_on_totalises`. MACHINE-CHECKED (model). Reviewed (A7) |
| L1imp-0001 | 27a565ac… | 0 | IMPORTED_COUNT 9 MISMATCH_COUNT 0 |
| L2-0001 / L2-0002 | 4e1c1542… / 0e638e90… | 1 / 1 | tactic gap / ML type error |
| L2-0003 | 7c93c620… | 0 | 9 theorems; `refund_profile_a_sl_reach`. MACHINE-CHECKED (model). Reviewed (A12): correct; non-vacuity MISSING |
| E1-0001 / E1-0002 | 062a12f4… | 1 / 1 | no theory loaded (setup) / ML static error |
| E1-0003 | 56a87088… | 0 | 18 erasure theorems on single functions. MACHINE-CHECKED (model). Reviewed (A10) |
| E1neg-0001 (mutant) | ab501f93… | 1 | `LEMMA_FAILED BranchTo_erase_untagged`, as required |
| LO-0001 … LO-0004 | 553233ce…, 0c57ad6d…, 4bc9910a…, fcc80fb8… | −24, 1, 1, 1 | CPU limit; ML error; 24 CHECKED; 27 CHECKED. Open: `extract_no_ext_stdout`, `refund_profile_a_sl_fd1`. ONE attempt left (A3 writes v6) |
| PF-0001 … PF-0003 | 820de134…, fa818253…, 74dd468c… | 1, 1, 1 | open lemma `lexPs_cons` |
| PF-0004 | 6dc46143… | 0 | 26 theorems; `refund_strict_parse_no_strict_prefix`, `refund_strict_parse_complete`, `refund_render_fields_prefix_code`. MACHINE-CHECKED (model). Review A13 running |
| L2b-0001 | c2a69ae1… | 1 | `ffi_calls_ok_of_returning_calls` failed; local copy of `ffi_calls_ok`; A8 writes v2 (imported mode) |
| L2b-0002 | ec2b72f6… | 1 | every lemma proved; a control comparison in the script was wrong; no export |
| L2b-0003 | cb6efb52… | 0 | 28 theorems; `ffi_calls_ok_of_returning_calls`; third premise of L2R for the close predicate. Review A18 running |
| LO-0005 | 9db45d73… | 1 | `extract_no_ext_stdout_step` failed; ML parse error. L-OUT NOT proved. See `ATTEMPT_COUNTS.md`. Exploration script: A16 |
| PX-0001 | c4cfd82c… | 0 | 9 theorems; `refund_strict_parse_exact`, `refund_frame_decision`. Review A18 running |
| Link (folder `orch-A/link/run/attempt-0001`) | — | H0 0; H1 0; H2 0; NC1–NC6 1; NS1–NS3 1; PC1 0; E0 0; R1 0; H4 0; NR1 1; R2 0; R3 0; I1 0 | S5 and S6 MACHINE-CHECKED at model level, all controls as planned (H4, NR1, R2, R3, I1: second runs after a wrapper path fix). Review A17 running |

| LOx-0001 (EXPLORATION, no export) | 5ef71604… | 0 | EXPLORE_COMPLETE; all pieces of the two open L-OUT lemmas closed |
| LO-0006 | 64416668… | 0 | 41 CHECKED; `refund_L_OUT`, `refund_L_OUT_prefix`, `refund_profile_a_sl_fd1`. MACHINE-CHECKED (model). Review A22 running |
| LE-0002 / LE-0003 / LE-0004 | 2e2fbb42… / 3bd3cec5… / same | 1 / 0 / 0 | ML parse error; generic `evaluate_Halt_reg` (6 theorems); with L-OUT: `refund_profile_a_sl_halt` (7 theorems) |
| ES-0001 / ES-0002 | 7ed5a4a5… / 7c0c3c51… | 1 / 1 | ML error; many frame/erase lemmas open. A20 prepares an exploration `EFx-0001` |
| E1r-0001 / L2r-0001 (re-runs inside the swap rule) | = E1-0003 / L2-0003 | 0 / 0 | `.dat` byte-equal to the first runs |
| Link NB1 (new control) | 9c55bb3f… | 1 | fails at `exported_ens2_value`, as required; reasons of all controls: `link/run/attempt-0001/control_reasons.txt` |

| L2c-0001 | ca624cc5… | 0 | 29 theorems; `refund_profile_a_sl_events` (Route A reduced to R6 + native contract). Reviewed (A26) |
| EFx-0001 (EXPLORATION) / EF-0001 | 68ba8415… / ba8f9150… | 0 / 0 | `Next_frame`, `NextStateARM8_frame`, `W_nonvacuous` (69 stored). Reviewed (A26) |
| MF-0001 / MF-0002 | 30ad1d66… / (ML-only change) | 0 / 0 | composed theorem `refund_model_frame_meets_exported_contract` (13). Reviewed (A26) |
| MG-0001 | 80c190da… | 0 | composed theorem from the R6 premises (5). Reviewed (A27) |
| L2dx-0001 (EXPLORATION) / L2d-0001 | 183b8ded… / f9a25452… | 0 / 0 | oracle-only shape predicate; `refund_profile_a_sl_shape`; `refund_model_frame_decision_shape` (29). Reviewed (A27) |
| R6x-0001 (EXPLORATION) | 5b4a9809… | 0 | cfLib loads; base lemmas close |
| R6base-0001 | a835d58e… | 0 | 11 theorems: `every_clock_events`, `replay_cannot_exclude_error_return_events` (STRONG form), `every_of_three_parts`. Not yet reviewed |
| EEx-0001 (EXPLORATION) | e47689d8… | 0 | erase lemmas of the load/store classes stay OPEN (112–304 goals); bounded stop; see `erasure-step/REPORT.md` |
| R6x-0002 (EXPLORATION) | 1c76b89c… | running | CF steps `writei_V`, `read_into_V` with an event invariant |

## HOL queue next
1. `R6x-0002` (running in `queue.sh q26`). Then A25 (or a fresh worker with `orch-A/r6/`) writes the next R6 proof pieces
   (plan S3–S8 in the A25 report: IOFS_V, writei_V, read_into_V, write side, read side, main, assembly). Multi-day.
2. Erasure load/store class: see blocker in `erasure-step/REPORT.md`.
3. Optional: P9a (`resource-native/P9a_v2.sml`), not run.
The joint report `../MORNING_REPORT.md` exists (addenda 1, 2). Later results: add an addendum there and in `MORNING.md`.

## Counterexamples tonight (native; reproduced by A; `orch-A/ffi-c-audit/REPORT.md`)
- CE-1: real executable, exit status 0, empty stderr, stdout a 1000-byte strict prefix (non-blocking pipe).
- CE-2: exit 0 with empty stdout (closed stdout or stdin and similar).
- CE-3: `DYLD_INSERT_LIBRARIES` gives a forged complete frame with exit 0 (assumption A-LOADER; existing launchers pass a fixed env).

## Workers now
Running: none (A25 and A20 handed back; resume them by agent id or brief fresh workers from `orch-A/r6/` and `erasure-step/v3/`).
Reviews done: L1, E1, L2, PF, link, L2b+PX, LO, MF (+L2c, LE, EF), L2d (+MG): `orch-A/review-*/REPORT.md`.
Commits on nightshift/A-proof up to 0c571a27 (joint report with addenda). unsure U481–U494. Sync: `orch-A/sync.sh`.
B: `orch-B/MORNING.md` FINAL with addendum; B may ask for more heavy windows (release `hol.lock` between cases).

## Blockers
- None for the queue. Swap free 1.6 GB at 08:12Z. Poly/ML store stops happened at low swap: re-measure before each run.

## RESUME NOTE (2026-11-19T11:06:21Z)
A was resumed by a message from B (heavy.lock released 11:05:53Z). A took `locks/hol.lock` again and runs `R6x-0004` (exploration).
The STOP NOTE above describes the state at the first hand-back; this note supersedes its "nothing runs" line while the queue runs.

## PICK (2026-11-19T11:06:34Z) — launcher order item 3
Pick: the FFI premise via R6, narrowest sub-lemma first.
1. `R6ffi-0001`: the two FFI-level specifications with the event invariant (`writei_spec_V`, `read_into_spec_V`). Every
   other R6 lemma rests on them. Run after exploration `R6x-0004` closes.
2. Then the WRITE side only (4 specifications: write, output_aux, output, print): it gives "every write event of `print`
   is a valid descriptor-1 event". Short path; it is the half of R6 that concerns the output bytes.
3. Then the read side (about 13 specifications), main, assembly.
Why not the others now: X8 and X11 are NATIVE links (HOL cannot close them; only named assumptions and tests). X16 is on
B's track (issuer). The run-level erasure lift needs an invariant "every next PC stays in the code region" that no stored
theorem gives, and non-vacuity with the bits set is missing: larger and further from a usable statement than R6 step 1.
Rule kept: exploration run first, then one proof run that replays it; each exit-0 theorem gets a separate reviewer.

## CHECKPOINT (2026-11-19T11:12:01Z)
R6x-0004: exit 0 but its shared file failed to compile (non-ASCII in ML strings). R6x-0005 (round5 copies, ML-only fix): exit 0,
all four explorations closed (X9r 4 steps, X8r 4, WRITEI_V_all_branches 29, READ_INTO_V_success_and_zero 13).
RUNNING: `queue.sh q32 "R6ffi-0002 3600 deps-R6ffi.txt"` (PROOF run; sub-files in `orch-A/r6/round5/`).

## CHECKPOINT (2026-11-19T11:15:00Z)
`R6ffi-0002`: actual exit 0, EXACT_COMPLETE, theory `forge_refundR6Ffi`: definitions IOxV, IOFS_V, STDIO_V; theorems
`IOFS_V_FFI_part_hprop`, `IOxV_IMP_IOx`, `writei_spec_V`, `read_into_spec_V`. Pick step 1 DONE. Next: review (A32); write side (A33).

## CHECKPOINT (2026-11-19T11:18:09Z)
`locks/hol.lock` released for B's fifth heavy window (up to 30 minutes). A starts no HOL case until B's release line. Workers: A32 (review R6ffi), A33 (write side).

## CHECKPOINT (2026-11-19T11:19:06Z)
Review A32 of R6ffi-0002: holds; evidence gap (files read with `use` hashed only after the run) recorded; wrapper now hashes them before and after each run.
B holds `heavy.lock` (fifth window, up to 30 minutes from 11:19Z). A33 (write side) works. No HOL case runs.

## CHECKPOINT (2026-11-19T11:36:42Z)
RUNNING: `queue.sh q33 "R6wx-0001 1800 deps-R6w.txt"` (write-side EXPLORATION; files in `orch-A/r6/round6/`). Staged, NOT RUN: `R6w-0001` (proof; `deps-R6w.txt`, 3600).

## CHECKPOINT (2026-11-19T11:39:20Z)
`R6wx-0001` (exploration): exit 0; 13 pieces closed; STUCK: `write_spec_V` step 2, `output_aux_spec_V` step 10, `print_spec_refund` step 1, optional `STD_streams_fd0`. A33 repairs into `orch-A/r6/round7/` (`R6wx-0002`, `R6w-0002`). HOL slot idle, held by A.

## CHECKPOINT (2026-11-19T11:42:35Z)
RUNNING: `queue.sh q34 "R6wx-0002 3600 deps-R6w.txt"` (exploration, round7). Staged, NOT RUN: `R6w-0002` (proof).

## CHECKPOINT (2026-11-19T11:47:21Z)
`R6wx-0002` (exploration, round7): exit 0; 12 of 17 lemmas close as real proofs; OPEN: `write_spec_V` step 8, `output_spec_V` step 2, `print_spec_V` (statement/alpha problem), optional `STD_streams_fd0`. A33 repairs into `orch-A/r6/round8/` (`R6wx-0003`, `R6w-0003`). `R6w-0002` NOT RUN (not to be run). HOL slot idle, held by A.

## CHECKPOINT (2026-11-19T11:50:23Z)
RUNNING: `queue.sh q35 "R6wx-0003 3600 deps-R6w.txt"` (exploration, round8). Staged: `R6w-0003` (proof). A33 context is full: brief a fresh worker for the next round (files `orch-A/r6/round8/`, log `R6wx-0003/stdout.log`).

## CHECKPOINT (2026-11-19T11:57:43Z)
`R6wx-0003`: shared file did not compile (stray backslash). `R6wx-0004` (round9, ML-only fix): exit 0, 16 lemmas close as real proofs, none failed.
RUNNING: `queue.sh q37 "R6w-0004 3600 deps-R6w.txt"` (PROOF, write side; files `orch-A/r6/round9/`).

## CHECKPOINT (2026-11-19T12:00:24Z)
`R6w-0004`: actual exit 0, EXACT_COMPLETE, theory `forge_refundR6Write`, 16 theorems + definition `write_event_ok`: `write_spec_V`, `output_aux_spec_V`, `output_spec_V`, `output_STDIO_spec_V`, `print_spec_V`, `print_spec_refund`. `USED_FILES_UNCHANGED true`. Pick step 2 (write side) DONE.
Next: review (A34); read side (A35, files to `orch-A/r6/round10/`).

## CHECKPOINT (2026-11-19T12:04:02Z)
Review A34 of R6w-0004: holds (report `orch-A/review-R6w/REPORT.md`). A35 (read side) works. HOL slot idle, held by A.

## CHECKPOINT (2026-11-19T12:04:35Z)
Workers running: A35 (read side → `orch-A/r6/round10/`), A36 (initial heap and event link → `orch-A/r6/round11/`). HOL slot idle, held by A. Next HOL cases: their explorations (`R6rx-0001`, `R6tx-0001`), then proof runs.

## CHECKPOINT (2026-11-19T12:05:40Z)
`locks/hol.lock` released for B's window 7 (about 6 minutes). A starts no HOL case until B's release line.

## CHECKPOINT (2026-11-19T12:11:44Z)
B released heavy.lock at 12:11:13Z (window 7: v6 draft sink 0 divergences; v5 halts in two modes). A holds `locks/hol.lock` again; slot idle until A35/A36 deliver.

## CHECKPOINT (2026-11-19T12:15:25Z)
Disk incident on B's side (volume full about 12:10Z–12:25Z). A's files and branch checked: intact; 81 GiB free. CHECK the files of A35 (`round10`) and A36 (`round11`) for truncation (digests in their reports; bracket balance) before any run.

## CHECKPOINT (2026-11-19T12:24:42Z)
A35 delivered the read-side bottom layer (`orch-A/r6/round10/`; digests equal its report; ASCII; no stray backslash). RUNNING: `queue.sh q38 "R6rx-0001 3600 deps-R6r.txt"` (EXPLORATION). Staged: `R6r-0001` (PROOF).

## CHECKPOINT (2026-11-19T12:27:42Z)
A36 delivered the initial-heap and event-link layer (`orch-A/r6/round11/`; digests equal its report; ASCII). Staged, NOT RUN: `R6tx-0001` (exploration), `R6t-0001` (proof); deps `deps-R6t.txt`. B asked for window 8 (2 minutes) at the next gap: after `R6rx-0001` ends.

## CHECKPOINT (2026-11-19T12:50:46Z) — A's error, corrected
At about 12:50:30Z A removed `locks/hol.lock` although `R6rx-0001` was STILL RUNNING (A's wait loop had ended by its own time limit, not by the case end; A did not check). A restored the lock at 12:50:37Z. No `heavy.lock` appeared; A had not sent B the release line; B's scripts also refuse while a HOL process runs. RULE: before removing hol.lock run `pgrep -f bin/hol` and require 0.
`R6rx-0001` still runs (limit 3600 CPU s). Partial: 6 lemmas close; `refillBuffer_with_read_spec_V` fails at step 2.

## CHECKPOINT (2026-11-19T13:04:48Z)
`R6rx-0001` hung in one step (the step time limit did not interrupt it); A stopped its own HOL child with SIGTERM after 39 minutes: `actual_exit` -15, no EXPLORE_COMPLETE; exploration only, nothing lost. `hol.lock` released at 13:04:54Z after a pgrep check that cannot match the checking shell (pattern `HOL/bin/[h]ol run`) for B's window 8. Staged: `R6tx-0001`; A37 delivered `orch-A/r6/round12/` (`R6rx-0002`, `R6r-0002`).

## STOP NOTE 2 (2026-11-19T13:05:20Z)
The harness required Orchestrator A to hand back again. A's loop STOPS here. HOL processes of A: 0. A holds NO lock
(`hol.lock` released 13:04:54Z for B's window 8; B may hold `heavy.lock`).
To resume: wait until `locks/heavy.lock` is gone; check `pgrep -f 'HOL/bin/[h]ol run'` = nothing; `mkdir locks/hol.lock`
(write `owner`); then in `results/m1b-routeA-20261119/attempt-0001`, one at a time:
1. `./queue.sh q39 "R6tx-0001 1800 deps-R6t.txt"` (EXPLORATION: initial heap and event link; files `orch-A/r6/round11/`);
   only if every required lemma shows TRY_HELPER_CLOSED: `./queue.sh q40 "R6t-0001 1800 deps-R6t.txt"` (PROOF).
2. `./queue.sh q41 "R6rx-0002 3600 deps-R6r.txt"` (EXPLORATION: read side bottom layer; `orch-A/r6/round12/`); a step may
   hang past its time limit (R6rx-0001 did): watch the log; stop the own HOL child if it does not move for 10 minutes;
   only if all required lemmas close: `./queue.sh q42 "R6r-0002 3600 deps-R6r.txt"` (PROOF).
3. Then the upper read-side specifications, the main-program specification under STDIO_V, the assembly to R6, the machine
   transfer (lists in the A35, A36, A37 reports quoted in STATE checkpoints and in `orch-A/r6/round1*/RUN_PLAN*.md`).
Each exit-0 theorem: a separate reviewer; unsure entry; ROADMAP row; joint report addendum.

## CHECKPOINT (2026-11-19T14:14:39Z) — BATTERY POWER
Launcher message 14:14Z: the machine is on battery. Measured now: Now drawing from 'Battery Power'.
A starts NO HOL case until AC power returns (the wrapper and queue also refuse on battery). HOL processes of A: 0; queues: 0.
A holds no lock. The four staged cases of STOP NOTE 2 stay NOT RUN. Lightweight work only.

## CHECKPOINT (2026-11-19T14:15:56Z)
Launcher order on battery: two lightweight workers only: W-pre (static pre-flight of staged R6tx/R6t/R6rx/R6r scripts and deps; evidence `orch-A/r6/preflight/`) and W-x8 (statements for X8/X11 with exact premises; evidence `orch-A/x8-x11/`). No HOL. When AC returns: q39 first.

## CHECKPOINT (2026-11-19T14:16:04Z)
AC power is back (pmset). No heavy.lock. A took `hol.lock`; RUNNING: `queue.sh q39 "R6tx-0001 1800 deps-R6t.txt"` (EXPLORATION). Workers: W-pre (pre-flight), W-x8 (X8/X11 statements). The proof runs wait for W-pre.

## CHECKPOINT (2026-11-19T14:18:05Z) — DIRECTIVE-2
Read `DIRECTIVE-2.md` and the PHASE 2 AMENDMENT. A = HOL and proof-to-executable chain. Tasks: staged queue (q39 running); exact statements/premises/logs; smallest missing refinement boundary (W-x8 drafts X8/X11); independent reproduction from the branch (W-repro prepares; runs only when A gives it the slot); list of unproven transitions to end_to_end=true (A writes `orch-A/END_TO_END_GAPS.md`). Push allowed: `git push origin nightshift/A-proof:nightshift/A-proof` only. Orchestrator C (red team) = agent a4f587cb1a34235e8: its messages are findings to check.

## CHECKPOINT (2026-11-19T14:18:35Z)
Push attempt `git push origin nightshift/A-proof:nightshift/A-proof`: DENIED by the permission classifier; NOT pushed; recorded as OWNER_REQUIRED A-4; no workaround tried. Workers: W-pre, W-x8, W-repro (prepares only). q39 running.

## CHECKPOINT (2026-11-19T14:25:05Z)
`R6tx-0001` (exploration) hung at `parts_ok_basis_ffi` step 2 for more than 6 minutes (the step time limit did not interrupt; same pattern as R6rx-0001); A stopped its own HOL child (SIGTERM): no EXPLORE_COMPLETE; nothing lost. Open: find the non-interruptible tactic in `orch-A/r6/round11/r6t_steps.sml` (parts_ok tail) and split it.
NEXT: the HOL slot goes to worker W-repro (reproduction from the branch, 18 cases, `orch-A/repro/run/repro.sh`). `hol.lock` stays held by A for it.

## CHECKPOINT (2026-11-19T14:25:41Z)
Wrote `orch-A/END_TO_END_GAPS.md` (17 transitions; smallest missing boundary = T9, the FFI premise). W-repro has the HOL slot (running `repro.sh`). W-pre and W-x8 work.
