# Orchestrator A (proof track) state

Updated: 2026-11-19T08:34Z. CURRENT none. M1-B OPEN. `end_to_end=false`.

## Branch
- `nightshift/A-proof` from `985f5eaf`; worktree
  `/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/A-proof`. No commit yet.
- Partner B agent ID: `a56d4886a49375909`.

## HOL slot
- `locks/hol.lock` held by Orchestrator A since 08:09Z. The pre-existing replay driver ended 08:08:54Z (`phase3/ALL_DONE`).
- RAN 08:12Z (exit 0): `L1-0001` in `results/m1b-routeA-20261119/attempt-0001` (`FORGE_CPU_SECONDS=600 ./go-routeA.sh
  L1-0001 L1-0001.sml deps-L1.txt`; log `L1-0001.go.log`). Source SHA-256 `9ddf6746…8830`.

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

## Theorem attempts tonight (folder `results/m1b-routeA-20261119/attempt-0001`; wrapper `nightshift-run.sh <case> <cpu> [deps]`)
| Case | Source SHA-256 | Command | Actual exit | Result |
|---|---|---|---|---|
| L1-0001 | 9ddf6746… | `FORGE_CPU_SECONDS=600 ./go-routeA.sh L1-0001 L1-0001.sml deps-L1.txt` | 0 | EXACT_COMPLETE; 16 CHECKED; 6 CONTROL_OK; 4 bool axioms. MACHINE-CHECKED (same machine). Reviewed (A7): holds |
| L1imp-0001 | 27a565ac… | `./nightshift-run.sh L1imp-0001 600 deps-L1imp.txt` | 0 | IMPORTED_COUNT 9 MISMATCH_COUNT 0 |
| L2-0001 | 4e1c1542… | `./nightshift-run.sh L2-0001 1600 deps-L2.txt` | 1 | LEMMA_FAILED `refund_ffi_tot_evaluate_agree` (tactic gap at the ExtCall leaves). Attempt 1 of 5. `L2-0002.sml` (0e638e90…) staged |
| LO-0001 | 553233ce… | `./nightshift-run.sh LO-0001 900 deps-LO.txt` | −24 (CPU limit) | stopped after `STD_streams_facts`; attempt 1 of 5; A3 repairs (v4) |
| PF-0001 | 820de134… | `./nightshift-run.sh PF-0001 600 deps-L1.txt` | pending | |
| E1-0001 | 062a12f4… | `./nightshift-run.sh E1-0001 600` | pending | |

## Counterexamples tonight (native; reproduced by A; `orch-A/ffi-c-audit/REPORT.md`)
- CE-1: real executable, exit status 0, empty stderr, stdout a 1000-byte strict prefix (non-blocking pipe).
- CE-2: exit 0 with empty stdout (closed stdout or stdin and similar).
- CE-3: `DYLD_INSERT_LIBRARIES` gives a forged complete frame with exit 0 (assumption A-LOADER; existing launchers pass a fixed env).

## Workers now
A3 (resumed: L_OUT_v4), A8 (ffi_calls_ok lemma draft, `orch-A/ffi-calls-ok/`). Done: A1, A2, A4, A5 (+v3), A6, A7, A9.

## Blockers
- None for the queue. Swap free 1.6 GB at 08:12Z. Poly/ML store stops happened at low swap: re-measure before each run.
