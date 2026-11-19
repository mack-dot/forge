# Step D1: static pre-flight review of the Route A L1 script (Y1, Opus; reading only; no HOL)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y1 pre-flight review of Route A lemma L1 (link X7). Static reading only. No HOL was run.

**Result: I found no concrete defect, so I wrote no `routeA-L1-v2.sml`.** Attempt 1 will probably pass. My confidence that attempt 1 ends with exit 0, `EXACT_COMPLETE` and no `LEMMA_FAILED` is about 80%. My confidence that the L1 lemma itself proves is about 90%. These are guesses.

### Findings
1. **Names and types match the stored theories.** I checked e4-0001 (source, `.sig` and the printed `DEFINITION` lines) and env-0005 (source and `.sig`).
   - These exist: `refund_ffi_contract_at_def` (`∀b dm ffi_i`, 7 bound variables in the order k index new_bytes ms2 t1 bytes bytes2, 7 hypotheses), `refund_env_ok_sl_def`, `refund_abs_ffi_contract_at`, `refund_ffi_contract_at_link_base_is_the_old_contract`.
   - These also exist: `refund_abs_ffi_def`, `refund_bad_return_ffi_def`, `refund_ffi_witness_state_def`, and `refund_ffi_contract_at_witness`. That last theorem is in EnvModel and is stated over `refund_ffi_contract`, which is why N1 rewrites with R0 first.
   - `shift_seq_def` is in miscTheory (`misc/miscScript.sml` line 130). `target_state_rel_def` is in asmProps.
   - The `ffi_interfer` type agrees with `Vty` and `f`. In `basis_ffi.c` lines 191–197, the close call is index 2 and its checks are `alen>=1` on x3 and `clen==8` on x1. `refund_close_call_valid` matches this.
2. **Tactics, read against the HOL source:**
   - `Cases_on `Vok index new_bytes ms2``: the term is not free in the goal or the assumptions, so it is classified "Alien". `BasicProvers.sml` lines 318 and 313 then call `ASM_CASES_TAC`. The positive case comes first, with `Vok …` and then `¬Vok …` as the newest assumption. `first_assum (… MATCH_MP TOT_T/TOT_F …)` will find it. This is low risk.
   - `>>` and `>-` have the same precedence and associate to the left (`Overlay.sml` line 18). Every `>-` chain still applies to the right subgoals.
   - N1's second half and N2b copy the stored `wrong_return_address_ffi_rejected` and `slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000` tactics. Both of those passed. N2b differs only in `(3+2)*16`, which I checked: 0x…D0 − 80 = 0x…080.
   - The remaining risk is in a few `simp` closures: SHIFT (`FUN_EQ_THM` applied twice), the word-literal decisions in N2d and N2a2, and the `EVAL_TAC` in N2b. Each is low to medium.
3. **Run plan:**
   - All 125 deps paths name `<dir>/<Thy>.sig`, but the files live in `<dir>/.hol/objs/`. This is not a defect: `run_case.py` maps the name to `.hol/objs`, and imp4-0001 had exit 0 with this file.
   - CPU: imp4 took 100 s of CPU, so the 600 s limit has ample margin. imp4 peak memory was about 3.2 GB.
   - The script writes only through `export_theory`, after `chDir` to the case folder (`FORGE_P3_OUT`). The process starts in the shared CakeML experiment folder, as earlier runs did.
   - Minor points: `inputs_unchanged_after` does not hash the parent `.dat` files. The `markers` field cannot record `UNEXPECTED_CONTROL_ACCEPTANCE …` because that line has a suffix, so read it from the `grep` in `go-routeA.sh`. If the guard refuses, `go-routeA.sh` still runs its JSON reader and `hash_parents.py`, which only gives harmless errors. The import script shadows the ML value `T` with a string; this is harmless here.
4. **Controls and vacuity:**
   - N1 is real but trivial. With `Vok = F` the on-form holds vacuously, and `refund_bad_return_ffi` fails the stored contract. So totalisation is needed.
   - N2 tests what it claims. The close predicate rejects the U393 state, and the stand-in jumps to 0x1000252A4. It meets the on-form (N2c) and fails the stored contract (N2d). It is a stand-in, not a model of the C code.
   - L1 is not vacuous as an implication. The on-form is strictly weaker (N1, N2d) and a non-trivial model meets it (N2c). `TOT_T` proves that the totalised function equals `f` on every valid call.
   - But L1 alone says nothing about `f` when `Vok` is weak: `Vok = F` meets the on-form for any `f`. The content sits entirely in L2 (the two machines agree) and L3 (`Vok` holds at every reachable call). Only fficlose has a validity predicate here. The read, write and open_in checks are L3's job.

### Exact statement of L1 as it stands
`refund_ffi_contract_on_totalises`:
`∀b dm Vok f. refund_ffi_contract_on b dm Vok f ⇒ refund_ffi_contract_at b dm (refund_ffi_tot Vok f)`

- `refund_ffi_contract_on` is the body of the stored `refund_ffi_contract_at`, with one more hypothesis `Vok index new_bytes ms2`. The conclusions are the same.
- `refund_ffi_tot Vok f k x` = `if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x`.

### Files written
- `<session scratch folder>/m1b/Y1/L1-fallback-tactics.sml` (DRAFT, NOT RUN). It holds tactic-only alternatives for L1, S1/N1, SHIFT, L1C, N2b, N2d and N2a2. Use one only after a matching `LEMMA_FAILED`. No statement changes.

### Commands run (all read-only)
`cat`, `ls`, `grep`, `sed`, `diff` and `shasum` on the drafts, stored records and HOL sources: exit 0. One `grep --include` call failed with a zsh glob error and changed nothing. The existence check on the deps paths reported all 125 as MISSING by design (the `.hol/objs` mapping). The SHA-256 of `routeA-L1.sml` is `9ddf6746…8830`, the same as the C1a report.

### Not determined
- Whether `simp` decides the word literals `0w = 8w` and `0x1000252A4w = 0w`. I base this on the stored NF1 precedent only.
- Whether the non-fatal text check prints `TEXT_CHECK_OK`.

| step | status | evidence or blocker |
|---|---|---|
| (1) names and types | done, no mismatch | e4-0001.sml and stdout lines 41–83 and 208; env-0005.sml lines 117–172; `.sig` files |
| (2) tactics | done, low risk | BasicProvers.sml lines 125–145 and 294–325; Overlay.sml line 18; stored WIT, NF1 and G2 tactics |
| (3) run plan | done, minor notes only | run_case.py; imp4-0001 `command.json` (exit 0, 100 s CPU) |
| (4) controls and vacuity | done | N1 trivial but valid; N2 valid; L1's content depends on L2 and L3 |
| (5) v2 script | not written | no concrete defect; fallback alternatives written instead |

| link id | proposed class | evidence |
|---|---|---|
| X7 (L1) | MISSING | draft only, not run; this review is a reading, not evidence |
