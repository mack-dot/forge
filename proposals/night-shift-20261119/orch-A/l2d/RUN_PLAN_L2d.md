# RUN PLAN L2d (worker A24). NOT RUN. Every tactic UNCHECKED.

Two cases. Run the exploration first. Finalise `routeA-L2d.sml` from its log. Then run the final case.

## Inputs
| File | SHA-256 | Role |
|---|---|---|
| `orch-A/l2d/L2dx-0001.sml` | `183b8ded1ee1e8a00fa8e1bca3d4fae50c2442e8e291a87ce0cc39bd3b663ae9` | exploration (no export, nothing stored) |
| `orch-A/l2d/routeA-L2d.sml` | `650b7dce9244a50aae492160d7932fe51bb6049db75433bd2107e829fd80f188` | DRAFT proof (theory `forge_refundRouteA2d`); to be replaced by the replay |
| `attempt-0001/deps-L2c.txt` | `17d737f263d5381f6a99e4f9f8203cff1425deb20e15805c26d3fb390dccd054` | deps-L2 + `forge_refundRouteA2` (L2-0003) + `forge_refundRouteA2b` (L2b-0003) theory lines |

Parent theorems used (by `DB.fetch`, never retyped): `forge_refundRouteA2b`: `ffi_calls_ok_of_returning_calls`,
`basis_close_return_lengths`, `refund_mc_close_fields`, `refund_names_are_ExtCall`; `forge_refundRouteA2`:
`refund_profile_a_sl_reach`, `ffi_calls_ok_def`; `forge_refundRouteA1`: `refund_ffi_contract_on_def`;
`forge_refundSlideProfileA`: `refund_ffi_contract_at_def`, `refund_abs_ffi_contract_at`.

## Command 1: exploration (orchestrator only, in the single HOL slot; NOT RUN)
```
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/l2d/L2dx-0001.sml L2dx-0001.sml
shasum -a 256 L2dx-0001.sml   # must be 183b8ded…63ae9
./nightshift-run.sh L2dx-0001 900 deps-L2c.txt
```
Success of the RUN = `actual_exit 0` and marker `EXPLORE_COMPLETE` in `L2dx-0001/command.json`. It proves nothing.

### What to read in `L2dx-0001/stdout.log`
- `grep -n "^EXPLORE_\|^STEP\|^ALT_\|^VALIDATION\|^PV_\|^TACTIC_\|^CONTROL_OK\|^UNEXPECTED\|^REMAINING_\|^L2R_THIRD" stdout.log`
- 27 explorations, in order: `ffi_read_return_length/A_gvs`, `/C_lengths`, `ffi_write_return_length/A_gvs`,
  `ffi_open_in_return_length/A_cases`, `/B_close_pattern`, `basis_read_return_length`, `basis_open_in_return_length`,
  `arm8_ffi_bytearrays_lengths`, `basis_returning_call_has_valid_shape` (the uncertain one), `basis_returning_calls_have_valid_shapes`,
  `refund_ffi_calls_ok_shape`, `refund_ffi_calls_ok_shape_totalised`, `refund_l2r_third_premise_shape`,
  `refund_profile_a_sl_shape`, 8 concrete controls, 4 error-byte controls, `remaining_premise_met_by_the_abstract_effect`.
- Each `pv` prints `PV_PROVED <name> (not stored)` with the theorem, or `PV_ASSUMED` (later results then carry a
  hypothesis: `VALIDATION … hyps N`, `ASM_HYPS N`). `TACTIC_USED <name> <k>` = the draft alternative that closed.
- `REMAINING_NATIVE_PREMISE`, `REMAINING_NATIVE_PREMISE_UNFOLDED`, `REMAINING_INTERFERENCE_PREMISE`, `ASSEMBLY_PREMISES`.

### Decision rule
Every `pv` line is `PV_PROVED` and `ASM_HYPS 0` → finalise `routeA-L2d.sml` by keeping, per lemma, only the
alternative named by `TACTIC_USED` (or the closing step sequence) and run Command 2. Any `PV_ASSUMED` → send the
first `STEP_STUCK`/`EXPLORE_OPEN` goal block to A24; do not run Command 2.

## Command 2: final proof (after the replay is written; NOT RUN)
```
cp /Users/USER/forge/results/night-shift-20261119/orch-A/l2d/routeA-L2d.sml L2d-0001.sml
./nightshift-run.sh L2d-0001 1500 deps-L2c.txt
```
Success = `actual_exit 0`, marker `EXACT_COMPLETE`, `FAILED_LIST` empty, 4 `CLOSURE_AXIOM` lines, objects
`forge_refundRouteA2dTheory.{dat,sig,sml}`. Expected stored theorems: 21 required + up to 5 optional (NOT RUN).

## Expected cost (estimate, not measured)
L2b-0003 used 170 s CPU (theory loading included). Exploration: loading + about 60 short steps: 300–700 s CPU.

## Annex: what the remaining premise demands of the C code (reading only; TESTED-UNPROVED facts cited)
Premise 2 = `refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses VokS envmc.ffi_interfer`: at every FFI
stub state with readable arrays and every `nb` of the array's length where `VokS index nb ms2` holds, the effect
returns to x30, `arm8_ok`, writes `nb` over the array in the domain, keeps x19–x25, x27, x28. By the L1 convention
(`refund_close_abort_model_ffi`), an abort is a non-returning state, so a C abort at a shape-valid state falsifies
premise 2. Byte agreement (C bytes = oracle `nb` on the real run) is the separate faithfulness assumption.
| FFI | shape-valid under VokS | model answer there | ORIGINAL C | PATCHED C (`ffi-hardening`, UNAPPLIED) |
|---|---|---|---|---|
| read (0) | x3 ≥ 4 | error byte if clen≠8 or alen−4 < n or fd not ReadMode | aborts: `basis_ffi.c:161` (clen≠8), `:164` (short array) → premise FALSE | returns error byte. Open: libSystem errors (EAGAIN, EINTR, EIO, EISDIR) vs model data; short reads vs `numchars`; real fd table vs model `infds` |
| write (1) | x3 ≥ 4 | error byte as read (WriteMode) | aborts: `:176`, `:180` → FALSE | returns error byte. Open: EAGAIN (CE-1), partial writes vs `numchars`, SIGPIPE (no return), inherited fds |
| close (2) | x1 = 8w, x3 ≠ 0w | error byte if fd not a model file (fd 0,1,2 are streams) | asserts pass (x3 top bit would abort at `:192`, but needs a domain of 2^63 bytes: vacuous); fd 0–2 really closed, writes 0 (model 1): byte mismatch | returns 1 for fd ≤ 2, unsigned lengths. Open: real fd table vs model, close() EINTR/EIO |
| open_in (3) | x3 ≠ 0w | error byte if alen < 9 or no NUL in conf | aborts `:139` for 1 ≤ alen < 9 → FALSE | returns error byte. Open: existing file → OS fd vs model `nextFD` (the 1 of 48 unit mismatch); FIFO open may block (no return) |
For close and open_in these are states the refund run never reaches (dead branch); VokS cannot exclude them because it
uses the oracle only. VokY3 (L2c) excludes them but needs L3.

## UPDATE after L2dx-0001 (actual exit 0, EXPLORE_COMPLETE; reported by Orchestrator A)
Final source `routeA-L2d.sml` SHA-256 `f9a2545247dbc30da939fd8b09216bfcca03860c00a47f1ef4e6c4d727a952ee` (replay; the
draft is kept as `routeA-L2d.draft-650b7dce.sml`, diff `routeA-L2d.draft-to-final.diff`). Deps: `deps-MG.txt`
(SHA-256 `9669fdf5…a9a9`, superset of deps-L2c). NOT RUN:
```
cp /Users/USER/forge/results/night-shift-20261119/orch-A/l2d/routeA-L2d.sml L2d-0001.sml
./nightshift-run.sh L2d-0001 1500 deps-MG.txt
```
Pass = actual_exit 0, `EXACT_COMPLETE`, `FAILED_LIST` empty, 24 to 29 `CHECKED` lines = `STORED_THEOREMS` (24 required,
5 optional: NFAIL, ERR2, l2d_frame_contract_upgrade, l2d_model_frame_contract_of_reach, refund_model_frame_decision_shape),
4 `CLOSURE_AXIOM`, `REMAINING_NATIVE_PREMISE` line, `MF_SECTION_DONE` (else `OPTIONAL_FAILED MODEL_FRAME …`).
