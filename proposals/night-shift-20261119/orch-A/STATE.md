# Orchestrator A (proof track) state

Updated: 2026-11-19T08:54Z. CURRENT none. M1-B OPEN. `end_to_end=false`.

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
| Link H0, H1, H2 | — | pending | `orch-A/link/run/attempt-0001/linkq.sh q1 H0 H1 H2` started 2026-11-19T08:52Z; logs `<CASE>.go.log` there |

## HOL queue next
Link controls NC1–NC6, PC1, NS1–NS3, H4, NR1, then R1–R3, I1, E0 (`linkq.sh`). LO-0005 (v6). L2b-0002. LE-0001 (needs L-OUT).
Erasure step lift (A11 draft). Re-run of E1-0003 and L2-0003 inside the swap rule (digest comparison).

## Counterexamples tonight (native; reproduced by A; `orch-A/ffi-c-audit/REPORT.md`)
- CE-1: real executable, exit status 0, empty stderr, stdout a 1000-byte strict prefix (non-blocking pipe).
- CE-2: exit 0 with empty stdout (closed stdout or stdin and similar).
- CE-3: `DYLD_INSERT_LIBRARIES` gives a forged complete frame with exit 0 (assumption A-LOADER; existing launchers pass a fixed env).

## Workers now
Running: A3 (L_OUT_v6), A8 (L2b v2), A11 (erasure step lift), A13 (review of PF-0004).
Done: A1, A2 (v3–v5), A4, A5 (v2–v4), A6, A7 (review L1), A9, A10 (review E1), A12 (review L2).
Reports: `orch-A/<task>/REPORT.md`. Answers for B's ledger: `orch-A/FIELDS_FOR_B.md`. Commits: 68b2e67b, f53d46d4 (branch nightshift/A-proof).

## Blockers
- None for the queue. Swap free 1.6 GB at 08:12Z. Poly/ML store stops happened at low swap: re-measure before each run.
