# Pass criteria per case (worker A4, 2026-11-19). NOT RUN

Nothing below has run. Each line is an EXPECTED result, not an observed one.
`check.py <ID> <case>` applies these rules to a finished case and prints
`VERDICT <ID> <case> PASS|FAIL|UNDECIDED`. `go.sh` calls it after each case.

General rules (all cases):

- Read the exit from `<case>/command.json` field `actual_exit`. Do NOT use the
  runner exit alone: `run_case.py` maps a signal (for example SIGXCPU, −24) to
  exit 1 (`run_case.py` last line). `actual_exit < 0` or `wall_timeout = true`
  is UNDECIDED (run again or record as undecided). It is never a rejection.
- `inputs_unchanged_after` must be `true`.
- Runner exit 3 = the resource guard refused. Nothing ran. Not a result.
- `go.sh` exit 5 = swap above 85 %; exit 6 = an input digest differs; exit 7 =
  H1 objects missing. Nothing ran.
- Marker lines are exact whole lines in `stdout.log`.

| ID | Case folder | Pass when (all must hold) |
| --- | --- | --- |
| H0 | `probe-0001` | `actual_exit` 0; marker `EXACT_COMPLETE` |
| H0p | `probe-0002` | only if H0 failed on `load`: `actual_exit` 0; `EXACT_COMPLETE`. Then use `LOADPATH=1` for R1–I1 |
| R1 | `u294-hol` | `actual_exit` 0; `SOURCE_BINDING_COMPLETE`; exactly 5 `CHECKED` records (header line plus its indented lines), each byte-equal to `recorded/hol-0004.stdout.log`; `.hol/objs/forge_refundSourceBindingTheory.dat` exists. Info only: its SHA-1 vs `2677fe6830467fd05c52227378bef67ac05dd931` |
| R2 | `u294-rel` | `actual_exit` 0; `SOURCE_RELATION_COMPLETE`; the `CHECKED source_model_result` record byte-equal to `recorded/relation-0001.stdout.log` |
| R3 | `u294-bridge` | `actual_exit` 0; `SOURCE_BRIDGE_COMPLETE`; the `CHECKED source_compiled_fields` record byte-equal to `recorded/bridge-0001.stdout.log` |
| I1 | `u294-import` | `actual_exit` 0; `SOURCE_IMPORT_COMPLETE`; the 7 `IMPORTED … EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES DISK_THM` lines byte-equal to `recorded/import-0001.stdout.log` lines 1–7; `CLOSURE_AXIOM` set = {`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`}. Info only: `CLOSURE_NODE` lines vs recorded |
| H1 | `contract-0001` | `actual_exit` 0; `EXPORTED_CONTRACT_COMPLETE`; exactly 9 `FORGE_THEOREM` lines in this order: `exported_contract_decode`, `exported_contract_shape`, `exported_ens1_value`, `exported_ens2_value`, `exported_ens3_value`, `exported_contract_value`, `exported_contract_on_refund_fields`, `exported_contract_exact`, `exported_contract_witnesses`; after each: `FORGE_ORACLES DISK_THM`, `FORGE_AXIOMS ` (empty), `FORGE_HYPOTHESES 0`; objects `.hol/objs/forge_refundExportedContractTheory.{dat,sig,sml}`. Then a person reads `FORGE_STATEMENT exported_contract_on_refund_fields` and `…_exact` against `STATEMENTS.md` section 3 |
| H2 | `contract-repeat` | as H1; and the 9 `FORGE_STATEMENT` records byte-equal to H1 |
| NC1 | `ctl-NC1` | `actual_exit` > 0; no `EXPORTED_CONTRACT_COMPLETE`; no `FORGE_THEOREM`; last `FORGE_BEGIN` = `exported_ens1_value` |
| NC2 | `ctl-NC2` | as NC1, last `FORGE_BEGIN` = `exported_ens2_value` |
| NC3 | `ctl-NC3` | as NC1, last `FORGE_BEGIN` = `exported_ens3_value` |
| NC4 | `ctl-NC4` | `actual_exit` > 0; no `FORGE_BEGIN` at all (ML refusal before C1) |
| NC5 | `ctl-NC5` | as NC1, last `FORGE_BEGIN` = `exported_ens1_value` |
| NC6 | `ctl-NC6` | `actual_exit` > 0; no `FORGE_BEGIN` at all. The message may be `Trailing export bytes` or a `dest_inr` error; both count |
| PC1 | `ctl-PC1` | EXPECTED PASS: as H1 (exit 0, marker, 9 theorems). If PC1 fails: STOP (the theorems depend on the body) |
| NS1 | `ctl-NS1` | `actual_exit` > 0; no marker; no `FORGE_THEOREM`; last `FORGE_BEGIN` = `exported_contract_on_refund_fields` |
| NS2 | `ctl-NS2` | as NS1 |
| NS3 | `ctl-NS3` | as NS1 |
| H4 | `render-0001` | `actual_exit` 0; `EXPORTED_RENDER_COMPLETE`; line `FORGE_THEOREM exported_contract_on_rendered_output`; objects `.hol/objs/forge_refundExportedRenderTheory.{dat,sig,sml}` (the script itself refuses hypotheses, axiom tags and tags other than `DISK_THM`) |
| NR1 | `ctl-NR1` | `actual_exit` > 0; no `EXPORTED_RENDER_COMPLETE`; no `FORGE_THEOREM` line |
| E0 | `eligible-link-0001` | optional. `actual_exit` 0; line `ELIGIBLE_LINK_COMPLETE` in `stdout.log` (NOT in `markers`: the runner does not list it); 5 `FORGE_THEOREM` lines (`eligible_link_decode`, `…_shape`, `…_guard_value`, `…_matches_compiled_guard`, `…_operators`), each with `DISK_THM`, empty axioms, 0 hypotheses |
| E0r | `eligible-link-repeat` | as E0; 5 `FORGE_STATEMENT` records byte-equal to E0 |

Decision rules (from `RUN_PLAN.md` section 4, unchanged):

- S5 "replayed 2026-11-19, same machine" only if R1, R2, R3 all PASS. I1 alone
  shows only "the stored theory loads".
- S6 MISSING → MACHINE-CHECKED (same machine, one run plus repeat) only if H1,
  H2 PASS and every H3 control is as listed. Any NC/NS PASS (accepted) voids
  the positive result. PC1 FAIL: stop.
- If R1 to R3 fail only on the byte comparison, `check.py` prints whether the
  records are equal after whitespace normalisation. That indicates a
  pretty-printer difference. It is not a pass by the plan's rule; record it.
