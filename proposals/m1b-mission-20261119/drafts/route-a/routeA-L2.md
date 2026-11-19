# Route A, L2: the real-effect machine and the totalised machine agree at reachable calls

Status: script `routeA-L2.sml` is a DRAFT (written, not run). Higher risk than L1. Nothing here is proved.

## 1. What `evaluate` does at an FFI entry PC (read from the pinned source)

File: `.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/backend/semantics/targetSemScript.sml`.

- `evaluate mc ffi k ms` (lines 118–218): `k = 0` gives `(TimeOut,ms,ffi)`.
- A normal step (PC in `prog_addresses DIFF set ffi_entry_pcs`, lines 122–137): `ms1 = mc.target.next ms`,
  `(ms2,new_oracle) = apply_oracle mc.next_interfer ms1`, recursion on `mc with next_interfer := new_oracle`.
- `halt_pc` (138–140): `Halt Success` if `get_reg ms mc.ptr_reg = 0w`, else `Halt Resource_limit_hit`.
- `install_pc` (141–148): `install_interfer` applied, recursion.
- An ExtCall FFI entry (204–217): `find_index pc mc.ffi_entry_pcs 0 = SOME ffi_index`; `ALOOKUP mc.mmio_info ffi_index = NONE`;
  `read_ffi_bytearrays mc ms = (SOME bytes, SOME bytes2)`; then `call_FFI ffi (EL ffi_index mc.ffi_names) bytes bytes2`:
  `FFI_final outcome` gives `Halt (FFI_outcome outcome)`; `FFI_return new_ffi new_bytes` gives
  `(ms1,new_oracle) = apply_oracle mc.ffi_interfer (ffi_index,new_bytes,ms)` and recursion on
  `mc with ffi_interfer := new_oracle`, `new_ffi`, `k − 1`, `ms1`.
- `apply_oracle oracle x = (oracle 0 x, shift_seq 1 oracle)` (lines 47–50). So the j-th FFI call uses `ffi_interfer j`.
  `shift_seq k s = λi. s (i + k)` (`misc/miscScript.sml` 130–132).
- `machine_sem` (220–233) is defined only through `evaluate` at every clock `k`.

Consequence: the effect is applied only at `FFI_return` of an ExtCall (and at SharedMem calls, which the refund record
does not have: `mmio_info = []`, all four names are `ExtCall`). The two machines can differ only there.

## 2. The reachability premise (D3, `ffi_calls_ok`)

`ffi_calls_ok P mc ffi k ms` is a copy of the recursion of `evaluate` (same branches, same guards, same record updates):
- it is `T` where `evaluate` stops (`k = 0`, Error branches, `halt_pc`, `FFI_final`, missing arrays);
- it is `F` at a SharedMem call (so the premise excludes SharedMem; for the refund record this branch is never reached);
- at an ExtCall `FFI_return new_ffi new_bytes` it is
  `P ffi_index new_bytes ms ∧ ffi_calls_ok P (mc with ffi_interfer := shift_seq 1 mc.ffi_interfer) new_ffi (k−1) (mc.ffi_interfer 0 (ffi_index,new_bytes,ms))`
  (written with the same `apply_oracle` and `let` as `evaluate`).
In words: "P holds at every FFI call that `evaluate` at clock k reaches AND that returns". It is evaluated in the
machine `mc` given to it. In L2 that machine is the TOTALISED one. So the premise is a property of a machine for which the
stored theorem already holds. It does not mention the real effect at all. This is the non-circular form (U405 note).

Exact text: `routeA-L2.sml`, the `Define` after `MARK D3`. Defined by `Define` with clauses for `0` and `SUC k`
(structural recursion on the clock).

## 3. Statements

L2 (`refund_ffi_tot_evaluate_agree`):
```
∀k mc1 mc2 ffi ms.
  mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer ∧ ffi_calls_ok Vok mc2 ffi k ms ⇒
  evaluate mc1 ffi k ms = evaluate mc2 ffi k ms
```
L2S (`refund_ffi_tot_machine_sem_agree`):
```
∀mc ffi ms.
  (∀k. ffi_calls_ok Vok (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms) ⇒
  machine_sem mc ffi ms = machine_sem (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi ms
```
L2R (`refund_profile_a_sl_reach`): the 11 premises of the stored `refund_profile_a_sl` with `refund_env_ok_sl sl envmc`
replaced by three premises:
```
interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧
refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses Vok envmc.ffi_interfer ∧
(∀ms k. arm8_run 27 s = SOME ms ⇒
   ffi_calls_ok Vok (refund_mc (sl + 0x1000040D0w)
                       (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer))
                (basis_ffi ext cl fs) k ms)
```
and the conclusion of the stored `refund_profile_a_sl`, term for term (checked by `aconv` in the script), for the
REAL-effect record `envmc`. The script builds this statement from the stored term, not by retyping it.

## 4. The proof (as written)

L2: induction on the clock `k` (`Induct`), with `mc1, mc2, ffi, ms` universally quantified in the induction statement,
because `evaluate` changes the record (shifted oracles) and the state at each step.
- `k = 0`: both sides are `(TimeOut,ms,ffi)` (`evaluate_def`).
- `SUC k`: substitute `mc2`; unfold `evaluate_def` once on both sides and `ffi_calls_ok` once on the premise; simplify with
  `apply_oracle_def` (record field access on `mc1 with ffi_interfer := …` reduces to `mc1`'s fields, so every guard is the
  same on both sides); split every `if` (`IF_CASES_TAC`) and every `case` (`TOP_CASE_TAC`), as the stored
  `targetProps.evaluate_add_clock` proof does (targetPropsScript.sml 1059–1076). Leaves:
  - stop branches: both sides are the same triple;
  - normal and install steps: apply the induction hypothesis to the updated records (the `next_interfer` /
    `install_interfer` update commutes with the `ffi_interfer` update; `srw_ss` record normalisation, with
    `machine_config_component_equality` as fallback);
  - ExtCall `FFI_return`: the premise gives `Vok ffi_index new_bytes ms`; L1's `refund_ffi_tot_valid` turns the
    totalised effect at that call into `mc1.ffi_interfer 0 (…)`, so both successor states are equal; L1's
    `refund_ffi_tot_shift_seq` turns `shift_seq 1 (refund_ffi_tot Vok g)` into `refund_ffi_tot Vok (shift_seq 1 g)`, so the
    successor records are again in the L2 relation; apply the induction hypothesis;
  - SharedMem: the premise is `F`.
L2S: from L2 at every clock; `FUN_EQ_THM`, case split on the behaviour, `machine_sem_def`.
L2R: instantiate the stored `refund_profile_a_sl` at `envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer`;
its premise `refund_env_ok_sl` comes from L1's corollary `refund_env_ok_sl_of_contract_on`; then
`refund_mc b (envmc with ffi_interfer := g) = refund_mc b envmc with ffi_interfer := g` (`refund_mc_def`, `arm8_fix_def`),
L2 at every clock for the exclusion conjunct, and the machine_sem equality for the behaviour conjunct.

Stored lemmas that help (pinned `targetPropsScript.sml`): `evaluate_add_clock` (1059, the case-split pattern),
`evaluate_io_events_mono` (1078), `machine_sem_total` (1134), `machine_sem_unique` (1163). From the M1 chain:
`machine_step_evaluate`, `call_FFI_return_appends_one_event` (forge_refundWriteReach), `machine_reach_n_evaluate`
(forge_refundCallSite) — not used by the draft; they are the tools for L3.

## 5. Risks (my reading, not checked)

1. `simp` after the double unfolding may not leave the `if` and `case` structure that `IF_CASES_TAC` / `TOP_CASE_TAC`
   expect, or may rewrite the premise into a different shape. The `SHOW L2-leaf` lines show each leaf goal.
2. Record normal forms: the leaf equality `mc2' = mc1' with ffi_interfer := …` relies on `srw_ss` canonical record
   updates; the fallback is `machine_config_component_equality`.
3. `Define` may choose a different name or need a termination proof if it does not see the structural recursion
   (it should: the clock is `0` / `SUC k` and every recursive call is on `k`).
4. L2R: `RULE_ASSUM_TAC (REWRITE_RULE [FLD])` must turn the `.target` / `.install_pc` of the totalised record into those of
   `envmc`; the final `asm_rewrite_tac` must use the clock-wise `evaluate` equality under the binder.
If a leaf fails, the next attempt should change tactics only; the three statements must not change without a record.

## 6. What L2 does NOT give

It does not show that `ffi_calls_ok Vok …` holds for the refund program (that is L3). It does not relate any real
process to `evaluate`. With L1 and L2, the stored theorem holds for every record whose effect meets the on-form contract
at the calls where `Vok` holds and the calls the totalised machine reaches satisfy `Vok`. That is still a statement about
a model machine.
