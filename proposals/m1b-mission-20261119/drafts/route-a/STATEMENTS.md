# Route A statements (worker X7, step C1 preparation)

Status words: DRAFT = HOL script written, NOT RUN. SKELETON = statement and proof plan, no runnable proof.
NOT ATTEMPTED = statement only. STORED = a record shows it with exit 0 (quoted from that record).
Nothing in this file is proved by this step. Variable `Vok` is the predicate called V in the mission drafts
(renamed to avoid any clash with a constant named `V`).

Name map: the owner's `refund_ffi_contract_at_totalise` (B2 draft) = `refund_ffi_contract_on_totalises` (B1 draft and
`routeA-L1.sml`). B2's `contract_clause` and `refund_abs_env_effect` are, in my files, the body of the stored
`refund_ffi_contract_at` and the stored `refund_abs_ffi`. B2's `V (i,ms)` is `Vok i new_bytes ms` (my predicate also sees
the oracle's answer `new_bytes`).

## A. Stored items used (owning theory)

| Constant / theorem | Theory | Record |
|---|---|---|
| `refund_ffi_contract_at`, `refund_ffi_contract_at_def` | forge_refundSlideProfileA | e4-0001 (U409), stdout 63–80 |
| `refund_env_ok_sl`, `refund_env_ok_sl_def` | forge_refundSlideProfileA | e4-0001, 151–156 |
| `refund_abs_ffi_contract_at` (`∀b dm. refund_ffi_contract_at b dm refund_abs_ffi`) | forge_refundSlideProfileA | e4-0001, 207–209 |
| `refund_ffi_contract_at_link_base_is_the_old_contract` | forge_refundSlideProfileA | e4-0001, 81–83 |
| `refund_profile_a_sl` (L2R only) | forge_refundSlideProfileA | e4-0001, 238–265 |
| `refund_abs_ffi`, `refund_abs_ffi_def` | forge_refundEnvModel | env-0005 (U392) |
| `refund_bad_return_ffi`, `refund_bad_return_ffi_def` | forge_refundEnvModel | env-0005 |
| `refund_ffi_witness_state`, `refund_ffi_witness_state_def` | forge_refundEnvModel | env-0005 |
| `refund_ffi_contract`, `refund_ffi_contract_at_witness` | forge_refundEnvModel | env-0005 |
| `refund_mc`, `refund_mc_def` (L2R only) | forge_refundStartupBridge | mc-0001 |
| `arm8_fix_def` (L2R only) | forge_refundStartupClause | startup-0002 |
| `is_arm8_machine_config` (type of the record) | forge_refundStartupClause / backend | — |
| `forge_refundCmlMainStep$arm8_run` (L2R only) | forge_refundCmlMainStep | cml-0012 |
| `evaluate`, `evaluate_def`, `machine_sem`, `machine_sem_def`, `apply_oracle_def`, `encoded_bytes_in_mem`, `read_ffi_bytearray(s)`, `machine_config` record and `machine_config_component_equality`, `interference_ok` | targetSem (pinned CakeML) | targetSemScript.sml |
| `shift_seq`, `shift_seq_def`, `find_index`, `read_bytearray_def` | misc (pinned CakeML) | miscScript.sml 130 |
| `target_state_rel_def` | asmProps (pinned CakeML) | asmPropsScript.sml 57 |
| `arm8_target`, `arm8_target_def`, `arm8_config_def`, `arm8_ok_def` | arm8_target (pinned CakeML) | — |
| `call_FFI`, `ffi_state`, `FFI_return`, `FFI_final`, `ExtCall`, `SharedMem` | ffi (pinned CakeML) | — |
| `basis_ffi` (L2R only) | basis_ffi (pinned CakeML) | — |
| `word_msb`, `w2n`, `n2w` | words (HOL) | — |

New constants (mine): `refund_ffi_contract_on`, `refund_ffi_tot`, `refund_close_call_valid`, `refund_close_abort_model_ffi`
(theory `forge_refundRouteA1`); `ffi_calls_ok` (theory `forge_refundRouteA2`).

## B. Definitions

D1 (DRAFT) `refund_ffi_contract_on b dm Vok ffi_i` ⇔ for all `k index new_bytes ms2 t1 bytes bytes2`: the eight hypotheses of
the stored `refund_ffi_contract_at b dm ffi_i` AND `Vok index new_bytes ms2` imply the four conclusions of the stored
contract. Built in the script from the stored definition term (strip the binders, add one conjunct at the end).
D2 (DRAFT) `refund_ffi_tot Vok f k x = if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x`.
D3 (DRAFT, L2 script) `ffi_calls_ok P mc ffi k ms`: a copy of the recursion of `evaluate` that requires `P ffi_index new_bytes ms`
at every ExtCall `FFI_return`, is `F` at a SharedMem call, and is `T` where `evaluate` stops. See routeA-L2.md §2.
D4 (DRAFT) `refund_close_call_valid i nb ms ⇔ (i = 2 ⇒ ms.REG 1w = 8w ∧ ms.REG 3w ≠ 0w ∧ ¬word_msb (ms.REG 3w))`
(the two `assert`s of `fficlose`, signed `alen`).
D5 (DRAFT) `refund_close_abort_model_ffi k x = if refund_close_call_valid (FST x) (FST (SND x)) (SND (SND x)) then refund_abs_ffi k x
else (SND (SND x)) with PC := 0x1000252A4w` — a stand-in for "does not return" (jump to the slide-0 assertion block). NOT a
model of the C code.

## C. Statements in reading order

| Id | Statement | Status |
|---|---|---|
| H1 | `∀Vok f k index new_bytes ms2. Vok index new_bytes ms2 ⇒ refund_ffi_tot Vok f k (index,new_bytes,ms2) = f k (index,new_bytes,ms2)` | DRAFT |
| H2 | same with `¬Vok …` and `refund_abs_ffi k (index,new_bytes,ms2)` | DRAFT |
| H3 | `∀f. refund_ffi_tot (λi nb ms. T) f = f` | DRAFT |
| H4 | `∀n Vok f. shift_seq n (refund_ffi_tot Vok f) = refund_ffi_tot Vok (shift_seq n f)` (needed by L2) | DRAFT |
| **L1** | `∀b dm Vok f. refund_ffi_contract_on b dm Vok f ⇒ refund_ffi_contract_at b dm (refund_ffi_tot Vok f)` | DRAFT |
| L1C | `interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧ refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses Vok envmc.ffi_interfer ⇒ refund_env_ok_sl sl (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer)` | DRAFT |
| S1 | `∀b dm f. refund_ffi_contract_on b dm (λi nb ms. T) f ⇔ refund_ffi_contract_at b dm f` | DRAFT |
| N1 | `¬(∀b dm Vok f. refund_ffi_contract_on b dm Vok f ⇒ refund_ffi_contract_at b dm f)` (witness `Vok = λi nb ms. F`, `f = refund_bad_return_ffi`, base 0x1000040D0w, the stored witness state at the read stub) | DRAFT |
| N1b | `∀b dm. refund_ffi_contract_at b dm (refund_ffi_tot (λi nb ms. F) refund_bad_return_ffi)` | DRAFT |
| N2a | `∀nb ms. ms.REG 3w = 0w ⇒ ¬refund_close_call_valid 2 nb ms` | DRAFT |
| N2a2 | `¬refund_close_call_valid 2 [] (refund_ffi_witness_state with PC := 0x100004080w)` | DRAFT |
| N2b | `∀dm ffi_i. refund_ffi_contract_at 0x1000040D0w dm ffi_i ⇒ (ffi_i 0 (2,[],refund_ffi_witness_state with PC := 0x100004080w)).PC = 0w` (the stored contract demands a return at the U393 close state: x1 = x3 = 0w, x30 = 0w) | DRAFT |
| N2c | `∀b dm. refund_ffi_contract_on b dm refund_close_call_valid refund_close_abort_model_ffi` | DRAFT |
| N2d | `∀dm. ¬refund_ffi_contract_at 0x1000040D0w dm refund_close_abort_model_ffi` | DRAFT |
| N2e | `∀b dm. refund_ffi_contract_at b dm (refund_ffi_tot refund_close_call_valid refund_close_abort_model_ffi)` | DRAFT |
| — | U394 `zero_alen_reaches_assert_block` (`forge_refundFficloseCompose`, compose-0018): `arm8_user s ∧ s.PC = 0x100004080w ∧ refund_image_mem 0w s.MEM ∧ s.SP_EL0 = b + 32w ∧ aligned 3 b ∧ (frame outside the image) ∧ s.REG 3w = 0w ⇒ ∃s1. arm8_run 6 s = SOME s1 ∧ s1.PC = 0x1000252A4w` | STORED (cited in a comment of N2; not re-proved) |
| **L2** | `∀k mc1 mc2 ffi ms. mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer ∧ ffi_calls_ok Vok mc2 ffi k ms ⇒ evaluate mc1 ffi k ms = evaluate mc2 ffi k ms` | DRAFT (higher risk) |
| L2S | `∀mc ffi ms. (∀k. ffi_calls_ok Vok (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms) ⇒ machine_sem mc ffi ms = machine_sem (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi ms` | DRAFT |
| L2R | the 11 premises of `refund_profile_a_sl` with `refund_env_ok_sl sl envmc` replaced by `interference_ok …`, `refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses Vok envmc.ffi_interfer`, and `∀ms k. arm8_run 27 s = SOME ms ⇒ ffi_calls_ok Vok (refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer)) (basis_ffi ext cl fs) k ms`; conclusion = the stored conclusion, term for term | DRAFT (higher risk) |
| L3-W | `refund_run_write_events_all_succeed` (every write event of every finite run is successful) — routeA-L3.md §1 | NOT ATTEMPTED |
| L3-R1 | `successful_read_call_state_has_valid_arguments` — routeA-L3.md §2 | NOT ATTEMPTED |
| L3-C | `returning_close_call_is_valid` (one step, from the oracle shape) — routeA-L3.md §3 | NOT ATTEMPTED |
| L3-U | `refund_run_has_no_close_or_open_in_call` — routeA-L3.md §3 | NOT ATTEMPTED |
| L3-slide | slide versions of every stored call-site result (all are at slide 0 through `refund_static`) | NOT ATTEMPTED |
| L3 | `∀ms k. arm8_run 27 s = SOME ms ⇒ ffi_calls_ok Vok (totalised record) (basis_ffi ext cl fs) k ms` for a concrete `Vok` | NOT ATTEMPTED (needs L3-W, L3-R1 and its failed-event part, L3-C or L3-U, L3-U for open_in, path layers, L3-slide) |
| L-EXIT | `refund_halt_register` — routeA-L3.md §5 (third conjunct needs a compiler or byte-level fact) | NOT ATTEMPTED |
| L-OUT | `refund_extract_fs_gives_stdout_bytes` + prefix monotonicity — routeA-L3.md §6 | NOT ATTEMPTED |

## D. What Route A will and will NOT establish (exact)

Even if L1, L2 (with L2S and L2R) and L3 all run with exit 0, Route A establishes only this: the HOL4 kernel has checked
that the CakeML target-semantics machine holding the exact code bytes of `refund_file` (the stored chain, premises P1–P6
and P8–P11 unchanged) behaves as the stored `refund_profile_a_sl` says — never fails, never reaches the installer, and every
behaviour is `Terminate Success io` whose replay on the file-system model appends `refund_render_fields (refund_fields …)`
to the stdout inode, or a `Resource_limit_hit` prefix of such a run — for EVERY FFI effect `f` that meets the stored call
contract at the calls where a named predicate `Vok` holds, where `Vok` is shown to hold at every FFI call that the
machine reaches. That is "verified machine-model behaviour under a reachable-call FFI premise that a faithful model of the
C code could satisfy". The premise `refund_ffi_contract_on … Vok f` stays a PREMISE: no HOL theorem says that the real
`basis_ffi.c` functions, libSystem `read`/`write`/`close`/`exit`, the macOS kernel, dyld, or the processor behave as
any such `f`; the U394/U397/U398 path theorems cover only parts of the C code, and only under the assumed relations
`close_call_rel` / `write_call_rel`. Route A also does NOT establish: the entry state (Q3a), `interference_ok` for the real
system (Q1 row 9), that the kernel accepted exactly the model's bytes, the process exit status (L-EXIT native half),
resource safety, or any property of a run of the physical executable. It is NOT "verified native execution". Its FFI
simulation relation is a conditional premise, not a proven fact.
