# Orchestrator A (proof track) state

Updated: 2026-11-19T09:12Z. CURRENT none. M1-B OPEN. `end_to_end=false`.

## Branch
- `nightshift/A-proof` from `985f5eaf`; worktree
  `/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/A-proof`. No commit yet.
- Partner B agent ID: `a56d4886a49375909`.

## HOL slot
- `locks/hol.lock` RELEASED by A at 09:10:45Z for B's heavy window (moved to `locks/released/`). B took `heavy.lock` at ~09:12Z
  (`orch-B/heavy/window-1.log`). A starts NO HOL case until B sends its release line and `locks/heavy.lock` is gone.
  Then: `mkdir locks/hol.lock` again, write `owner`, and continue the queue below.

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

## HOL queue next (when the slot is back)
1. `LE-0002` (`L_EXIT_v5`, absent-L-OUT mode: generic halt lemma): `./nightshift-run.sh LE-0002 1200 deps-LO.txt`.
2. `LOx-0001` exploration of the two open L-OUT lemmas (A16 writes it), then one proof run `LO-0006`.
3. Erasure step lift (A11 writes `orch-A/erasure-step/`).
4. Re-run of E1-0003 and L2-0003 inside the swap rule; compare theory digests (OWNER_REQUIRED A-1).

## Counterexamples tonight (native; reproduced by A; `orch-A/ffi-c-audit/REPORT.md`)
- CE-1: real executable, exit status 0, empty stderr, stdout a 1000-byte strict prefix (non-blocking pipe).
- CE-2: exit 0 with empty stdout (closed stdout or stdin and similar).
- CE-3: `DYLD_INSERT_LIBRARIES` gives a forged complete frame with exit 0 (assumption A-LOADER; existing launchers pass a fixed env).

## Workers now
Running: A11 (erasure step lift), A16 (L-OUT exploration script), A17 (review link), A18 (review L2b, PX).
Done: A1, A2, A3 (v3–v6), A4, A5, A6, A7, A8 (v1, v2), A9, A10, A12, A13, A14 (L_EXIT_v5), A15 (prefix exact).
Commits on nightshift/A-proof: 68b2e67b, f53d46d4, 65b1f0a4, 67017dc7. unsure U481–U489. Sync script: `orch-A/sync.sh`.
B: handed back once, resumed; `orch-B/MORNING.md` is INTERIM.

## Blockers
- None for the queue. Swap free 1.6 GB at 08:12Z. Poly/ML store stops happened at low swap: re-measure before each run.
