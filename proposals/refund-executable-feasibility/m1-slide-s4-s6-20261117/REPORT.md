# M1 — relocation correctness, steps S4, S5, S6 (U409)

Date: 2026-11-17. One local run, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Profile A NOT approved. Stage 12 unauthorized.
`end_to_end=false`. Nothing committed. Continues U407. Owner instruction:
"continue and dont stop working".

Run directory: `results/refund-slide-s3-local-20261117/attempt-0001`.
Theory `forge_refundSlideProfileA` (`e4-0001`, exit 0 on the first run,
17 theorems, 3 definitions, 542 closure nodes, four `bool` axioms only).

## 1. Verdicts

- **S4: PROVED** (model). The FFI contract and the environment predicate
  at the relocated base.
- **S5: PROVED** (model). The Profile A statement at every permitted
  slide.
- **S6: PROVED.** The instance `sl = 0w` is term-identical to the stored
  U404 theorems. It is derived from the slide theorem, not from the
  stored theorem.

The slide-generic chain S1–S6 of the U404 plan is complete as a model
theorem. Nothing about a real loader, process or environment is proved.

## 2. Exact statements

Definitions:

    refund_ffi_contract_at b dm ffi_i ⇔ (the stored U392 contract body with
       the literal base 0x1000040D0w replaced by b; the only use is
       target_state_rel arm8_target (t1 with pc := b − n2w ((3 + index) * 16)) ms2)

    refund_env_ok_sl sl envmc ⇔
       interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧
       refund_ffi_contract_at (sl + 0x1000040D0w) envmc.prog_addresses envmc.ffi_interfer

S4:

- `refund_ffi_contract_at_link_base_is_the_old_contract`:
  `∀dm f. refund_ffi_contract_at 0x1000040D0w dm f ⇔ refund_ffi_contract dm f`
- `ffi_interfer_ok_iff_contract_sl`:
  `ffi_interfer_ok (sl + 0x1000040D0w) (refund_mc (sl + 0x1000040D0w) envmc) ⇔
   refund_ffi_contract_at (sl + 0x1000040D0w) envmc.prog_addresses envmc.ffi_interfer`
- `refund_env_ok_sl_iff_installed_residual`:
  `∀ms. ms.PC = sl + 0x1000040D0w ⇒
   (refund_installed_rest2 (refund_mc (sl + 0x1000040D0w) envmc) ms ⇔ refund_env_ok_sl sl envmc)`
- `refund_abs_ffi_contract_at`: `∀b dm. refund_ffi_contract_at b dm refund_abs_ffi`
- `refund_abs_env_is_ok_sl`: `refund_env_ok_sl sl (refund_abs_env envmc)`
- `refund_env_ok_sl_at_slide_zero`: `refund_env_ok_sl 0w envmc ⇔ refund_env_ok envmc`

S5, `refund_profile_a_sl` (stored statement, read after exit 0):

    refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
    refund_heap_clear_sl sl h e ∧ envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
    refund_env_ok_sl sl envmc ∧
    stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request
       original remaining enabled opened candidate amount reason))) ∧
    wfcl cl ∧ wfFS fs ∧ STD_streams fs
    ⇒ ∃ms.
        (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
        (∀j ms' ffi'. evaluate M (basis_ffi ext cl fs) j ms = (TimeOut,ms',ffi') ⇒
             M.target.get_pc ms' ≠ M.install_pc) ∧
        ∃io_events.
          machine_sem M (basis_ffi ext cl fs) ms ⊆
            extend_with_resource_limit {Terminate Success io_events} ∧
          extract_fs ext (cl,fs) io_events =
            SOME (add_stdout (fastForwardFD fs 0)
              (refund_render_fields (refund_fields charge request original
                 remaining enabled opened candidate amount reason)))
    with M = refund_mc (sl + 0x1000040D0w) envmc

Also stored: `refund_profile_a_sl_abstract_env` (no environment premise);
`refund_profile_a_sl_every_machine_run` (every behaviour of that machine
from that state is `Terminate Success io` with the output equation, or a
resource-limit prefix of such a run; a behaviour exists; `Fail` is not a
behaviour).

S6: `slide_zero_instance_is_refund_profile_a_slide0` and
`slide_zero_instance_is_refund_profile_a_slide0_every_machine_run`. The
run checks `aconv` against the stored U404 statements
(`CONTROL_OK the slide-0 instances are term-identical …`).

## 3. Assumptions (all explicit premises; none proved for a real system)

1. `refund_entry_pre_sl sl s h stk e` (includes `slide_ok sl` and
   `refund_image_mem sl s.MEM`). FULLY ASSUMED.
2. Heap premises and `refund_heap_clear_sl sl h e`. ASSUMED.
3. `envmc.prog_addresses = refund_mem_dm_sl sl h e`. ASSUMED.
4. `refund_env_ok_sl sl envmc`. ASSUMED. It is exactly the two residual
   installed-state clauses. U393 (disassembly analysis, not a theorem)
   indicates it is probably FALSE for an `ffi_interfer` that describes
   the real C code at every state.
5. Canonical request on standard input; `wfcl`, `wfFS`, `STD_streams`.
   ASSUMED. Oracle `basis_ffi`.

## 4. Satisfiability

`refund_profile_a_sl_machine_premises_satisfiable_at_0x4000`:
`∃s h stk e envmc.` premises 1–4 at `sl = 0x4000w` (constructed model
state; abstract environment). Not a native witness. Not evidence about
macOS.

NOT shown: premise 5 (a concrete well-formed file system). Premise 5
shares no variable with premises 1–4, so joint satisfiability reduces to
`∃fs cl. wfcl cl ∧ wfFS fs ∧ STD_streams fs ∧ stdin_content fs = SOME inp`.
That lemma needs `live_numchars` of a concrete lazy list. It is the
exact missing lemma. Not run (disk).

## 5. Negative controls (all passed)

- `pc_changing_environment_is_not_ok_sl`.
- Base sensitivity: `stub_guard_ffi_satisfies_contract_at_its_base`
  (`∀b dm. refund_ffi_contract_at b dm (refund_stub_guard_ffi b)`) and
  `slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000`
  (`∀dm. ¬refund_ffi_contract_at 0x1000080D0w dm (refund_stub_guard_ffi 0x1000040D0w)`).
  An FFI effect that is correct only from the slide-0 stubs does not
  satisfy the contract at slide `0x4000`. Environment evidence for one
  slide does not transfer to another.
- Seven structural checks on the stored slide statement (output term is
  the U387 term; one `io_events`; machine term; premises; no source
  constant; abstract instance; same premise count as U404).
- `compile_correct'` loaded with a clean tag.

## 6. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `e4-0001` | 0 | S4, S5, S6; first run |
| `imp4-0001` (added later the same day, U411) | 0 | 15 stored statements match; the two slide theorems equal the stored U404 statements with five substitutions; 0 mismatches; 3 checker controls |
| Repeat of `e4-0001`; file-system witness; clean replay; independent replay | NOT RUN | disk |

Failures: none in this step. Uncertainty: one run only; statements read
from the log after exit 0, not re-imported by a separate script.

## 7. M1 blockers after S6

Profile approval (U403 R1–R5, U402 Q1–Q6); A8 review (18 rows NOT
REVIEWED); `refund_env_ok_sl` for a real environment (refinement L1–L3
of U405 not run); the entry state and the loader; the file-system
witness; repeats and import check for U409; clean and independent
replay.

## 8. Added later on 2026-11-17 (U413): file-system witness attempts; local HOL context removed

- `fs-0001`: exit 1, authoring. `LREPEAT_one_unfold` and
  `always_eventually_LREPEAT_one` passed inside the run; two tactics
  failed (`LFINITE_not_LREPEAT_one`, `sat_fs_STD_streams`). Nothing
  exported.
- `fs-0002`: exit 1, TOOL. The run lost its inputs while it ran
  (`ENOENT` on a parent theory file and on the runner's preload file).
  No proof result.
- Cause: another session of the owner removed old untracked folders
  under `results/` and the folder `.toolchain/experiments` at about
  11:40 local time, on the owner's choice (message from that session;
  I verified the folders are absent). That removed the pinned PolyML,
  HOL and CakeML build and every local parent theory of the M1 chain
  (U345–U405). Today's folder
  `results/refund-slide-s3-local-20261117` remains.
- Effect: no local HOL run is possible now. A new run needs the
  toolchain rebuilt and the whole parent chain regenerated. That is a
  full replay; it was never authorized.
- Not lost: every statement, script, log and hash in the committed
  packets; the executable (tracked copy
  `proposals/refund-executable-feasibility/native-execution-20261104/records/native-build-0001/refund`,
  SHA-256 `b8ed5ec2…7bb8`, checked after the cleanup).
- The input-premise witness stays NOT shown. The exact missing lemma is
  unchanged (section 4).
