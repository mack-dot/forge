# Orchestrator A (proof track) morning report — night shift 2026-11-19

Status line: CURRENT none. M1-B OPEN. Stage 9 deferred. Stage 12 unauthorized. `end_to_end=false`. No protected file changed.
Nothing merged, pushed, signed for release or deployed. Branch `nightshift/A-proof` (local). Written at the time in
`STATE.md`; refreshed when results change. Every HOL result below is a MACHINE-MODEL result on the same machine with stored
(cached) parent theories. It is not a clean replay and not an independent replay.

Run folder: `results/m1b-routeA-20261119/attempt-0001` (copy in the branch:
`proposals/night-shift-20261119/hol-runs/routeA-attempt-0001/`). Command form: `./nightshift-run.sh <case> <cpu> <deps>`
(it calls `go-routeA.sh`, which calls `run_case.py`); each `<case>.go.log` ends with `go exit N`.
Link cases: `results/night-shift-20261119/orch-A/link/run/attempt-0001`, `bash go.sh <CASE>`.

## 1. New proofs (machine-checked tonight; actual exit 0)

| Case | Theory | Main statements | Review |
|---|---|---|---|
| L1-0001, L1imp-0001 | forge_refundRouteA1 | `refund_ffi_contract_on_totalises` (16 theorems) | A7: holds |
| L2-0003 | forge_refundRouteA2 | `refund_ffi_tot_evaluate_agree`; `refund_profile_a_sl_reach`: the stored machine theorem with the all-states FFI premise replaced by the contract at valid calls plus `ffi_calls_ok` | A12: holds; no non-vacuity witness |
| L2b-0003 | forge_refundRouteA2b | `ffi_calls_ok_of_returning_calls`; close instance from the oracle alone (28) | A18: holds |
| L2c-0001 | forge_refundRouteA2c | `refund_profile_a_sl_events`: Route A reduced to the native contract at valid calls plus R6 (29) | A26: holds; R6 plausible, not proved |
| E1-0003, E1neg-0001 (mutant, exit 1) | forge_m1bErasureV2 | `BranchTo_erase_untagged`, `CheckSPAlignment_erase`, `arm8_ok_erase` (18) | A10: holds |
| EF-0001 | forge_m1bErasureFrame | `Next_frame`, `NextStateARM8_frame`, `W_nonvacuous` (69) | A26: holds |
| PF-0004 | forge_refundPrefixFree | `refund_strict_parse_no_strict_prefix`, `refund_strict_parse_complete`, `refund_render_fields_prefix_code` (26) | A13: holds |
| PX-0001 | forge_refundPrefixExact | `refund_strict_parse_exact`, `refund_frame_decision` (9) | A18: holds |
| LO-0006 | forge_refundLOut | `refund_L_OUT`, `refund_L_OUT_prefix`, `refund_profile_a_sl_fd1` (41 printed) | A22: holds; process note below |
| LE-0003, LE-0004 | forge_refundLExitGen, forge_refundLExit | `evaluate_Halt_reg`; `refund_profile_a_sl_halt` (7) | A26: holds |
| Link H1, H2 (+H0, E0, H4) | forge_refundExportedContract | `exported_contract_on_refund_fields`, `exported_contract_exact`: the 3 exported `ensures` clauses are true iff the outputs equal `refund_fields` of the inputs | A17: holds; checker defects noted |
| Link R1, R2, R3, I1 | (U294 theories) | U294 scripts replayed; the stored 2026-11-04 theory imports | A17: holds |
| MF-0001, MF-0002 | forge_refundModelFrame | `refund_model_frame_decision`; `refund_model_frame_meets_exported_contract`: machine model → every behaviour → descriptor-1 bytes → strict parse → value → exported clauses, ONE theorem | A26: holds |
| MG-0001 | forge_refundModelFrameEvents | the same conclusion from the reduced premises (native contract at valid calls + R6) | not yet reviewed |

Negative controls with the required failing result: link NC1–NC6, NS1–NS3, NR1 (second run), NB1 (exit 1 each; reason of each
in `link/run/attempt-0001/control_reasons.txt`), PC1 (exit 0 as planned), E1neg-0001 (exit 1).
Confirmation runs inside the swap rule: E1r-0001, L2r-0001: exit 0, theory `.dat` byte-equal to the first runs.

Failed attempts kept on disk (not hidden): L2-0001, L2-0002, L2b-0001, L2b-0002, E1-0001, E1-0002, PF-0001…0003,
LO-0001…0005, LE-0002, ES-0001, ES-0002; setup errors of link H4, NR1, R2, R3, I1 (`*.setup-error-1.go.log`).
Exploration runs (no export, nothing stored, prove nothing): LOx-0001, EFx-0001.

## 2. New counterexamples and falsified claims

- CE-1 (real executable b8ed5ec2…, reproduced by A): exit status 0, empty stderr, stdout a strict prefix (1000 of 4044
  bytes) when stdout is a non-blocking pipe that fills. CE-2: exit 0 with empty stdout (closed stdout or stdin). So
  "exit status 0 ⇒ complete output" is false for the real process, not only in the model.
- CE-3: `DYLD_INSERT_LIBRARIES` produces a forged complete frame with exit 0 that the strict parser accepts. The launch
  environment is outside every theorem (assumption A-LOADER). Both existing launchers pass a fixed environment.
- The present C FFI differs from the model at more states than U393: it aborts where the model returns an error byte
  (read/write with a configuration length ≠ 8 or a short array; open_in with a short array); it cuts the descriptor to
  32 bits; it really closes descriptors 0–2 (unit comparison 24 of 48 cases equal; TESTED-UNPROVED, worker A23).
- Review A18: with the close predicate alone the contract premise of `refund_profile_a_sl_reach` is false for the real C
  (a read call with a wrong configuration length). No valid-call predicate has all premises proved.
- Statement defects found in drafts before any run: the close instance without premises is false (control N2');
  the earlier event predicate admitted a two-byte read array (HOL `ZIP` truncates).
- Tool facts that cost runs: in this HOL a tactic takes a context argument; `simp` left-associates `++`; two constants are
  named `arm8_run`; `gvs` loops on an assumption `… ⇒ var = const`; the link checker `check.py` accepted a setup error as
  "as expected" (found by review; every control's stderr was then read).

## 3. Composed guarantee (proof track part)

Mechanically connected at MODEL level, in one HOL kernel: stored premises of the machine-model theorem for the exact
machine code ⇒ for every behaviour at `no_ext`: termination; if `refund_strict_parse` accepts the descriptor-1 bytes as g,
then g = `refund_fields` of the request, the bytes are exactly its render, and the three exported flat `ensures` clauses
hold on g (`MF-0002`). The same from the reduced premises: native FFI contract at valid calls + R6 (`MG-0001`).
From the exported clauses to the approved R1–R5: Dafny (`LinkedRefund`, B's `ExportedContract ⟺ FlatContract`), joined to
HOL by NAMED ASSUMPTIONS, not by a theorem: BETA-DAFNY-HOL (clause meaning; strings as byte lists), EXPORTER-ID, and the
encode/decode edges (stdin bytes of the nine values; decode of the six outputs).
NOT connected: the real process (X8, X11), the launch environment, the Python consumer's parser (tested only), the
issuer (X16: it calls the compiled Dafny checker, not this binary), the sink (B's track).

## 4. Remaining gaps (proof track)

| Gap | Class | Note |
|---|---|---|
| R6: every FFI event of every run is a valid read/write event | MISSING (model) | program behaviour; feasibility worker A25 |
| Native FFI contract at valid calls | ASSUMPTION (NATIVE) | plausible only at the program's own call shapes; owner item A-3 |
| All-states FFI premise of the older theorems (LO-0006, LE-0004, MF-0002) | FALSE for the real C | use the `_events` forms |
| Real process refines the model (X8); kernel and processor between steps (X11) | ASSUMPTION (NATIVE) | HOL cannot close it |
| Processor bits TBI0/SA0: step lift of the erasure lemmas, lift to `evaluate`, untagged addresses, real bit values | MISSING / UNKNOWN | E1, EF are sub-results |
| Entry state before `cml_main`; `no_ext`; stdout starts empty; A-FD1-WRITE; A-LOADER | ASSUMPTION (NATIVE) | named in `ffi-c-audit`, `resource-native` |
| Halt-value range; real exit path (32-bit test, 8-bit status) | MISSING / not derivable | decide by strict parse only |
| Python `frame.strict_parse` = HOL `refund_strict_parse` | TESTED-UNPROVED | 304,326 inputs, 0 wrong acceptances |
| BETA-DAFNY-HOL; EXPORTER-ID (build folder absent); input/output encoding edges | ASSUMPTION / MISSING | review A17 edges b, c, g, h |
| Conditional space theorem P9a | NOT RUN | draft `resource-native/P9a_v2.sml`; vacuity risk |
| Replay cases 094, 097, 098 | UNAVAILABLE | no source with the recorded digest |
| Clean replay; independent replay | NOT RUN | not started by rule |

## 5. Security (proof track view)

Routes that still let an untrusted implementation or agent pass: (1) the launch environment (CE-3) unless the launcher is
trusted; (2) a consumer that trusts the exit status (CE-1, CE-2); (3) the issuer does not use the M1 binary at all (X16);
(4) the FFI C code and everything outside the two proved slices are unproved native code; (5) admission and enforcement:
see B's report. No credential, key or production data was used by A or its workers. One worker linked a scratch image;
the linker applied its default local ad hoc signature (owner item A-3).

## 6. Reproducibility

- From the repository branch plus the pinned toolchain on this machine: each case = one source `.sml`, one deps list, one
  command; `command.json` records digests of the source, the `hol` binary, the heap, each input `.sig/.sml`; `hashes.json`
  records parent `.dat` files after the run. HOL4 9783a499…, CakeML cd915569…, Poly/ML 5.9.2.
- The ORIGINAL executable rebuilds byte-exactly with the recorded commands (image SHA-256 b8ed5ec2…7bb8; worker run;
  digest re-checked).
- Replay of the 158 recorded cases: 152 AS_RECORDED on the first run; 005, 130, 142 AS_RECORDED on a second run after a
  Poly/ML store stop; 094, 097, 098 UNAVAILABLE.
- Limits: parent theories come from earlier same-machine runs; `inputs_unchanged_after` does not cover parent `.dat` files;
  the heap digest is not in the tool identity file; no second machine.

## 7. Next critical obligation (proof track)

R6 for the totalised machine: `∀ms j. arm8_run 27 s = SOME ms ⇒ EVERY refund_valid_event (SND (SND (evaluate (refund_mc
(sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot VokY3 envmc.ffi_interfer)) (basis_ffi ext cl fs) j
ms))).io_events` (printed in `L2c-0001/stdout.log` lines 402–411). Inputs: theories of cases L1-0001, L2-0003, L2b-0003,
L2c-0001 and the program's source-level theories. Command form: `./nightshift-run.sh R6-0001 <cpu> deps-R6.txt`.
Acceptance: exit 0, EXACT_COMPLETE, no hypotheses or oracles beyond DISK_THM, the statement term-identical to
`REMAINING_PREMISE_R6`, then `MG`-style composition without the R6 premise, and a separate review. With R6 the model
theorem depends on NATIVE assumptions only.

## 8. Owner decisions (see `results/night-shift-20261119/OWNER_REQUIRED.md`)

- A-1: I started ten HOL cases below the protocol's swap limit (the launcher then amended the rule; two results were run
  again inside the rule with byte-equal theories). Keep or restate the rule.
- A-2: I went past my own written stop for the L-OUT proof (the ROADMAP rule holds per lemma). Accept LO-0006 and LE-0004,
  or require a fresh single run.
- A-3: the FFI premise: prove program behaviour for the present executable (L3/R6), or adopt a model-total C FFI
  (unapplied patch ea344ad0…f357; new image digest; records to redo). Includes the ad hoc linker signature disclosure.
