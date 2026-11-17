# M1 — A3 as a HOL predicate; slide-0 composition with the output equation (U404)

Date: 2026-11-17. Local run, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Profile A NOT approved. Stage 12 unauthorized.
`end_to_end=false`. Nothing committed. Continues U401–U403.

Run directory: `results/refund-profile-a-local-20261117/attempt-0001`.
Theory: `forge_refundProfileA` (`prof-0002`, exit 0, 8 theorems,
1 definition, one run). Companion:
[A8 review matrix](A8_CONTRACT_REVIEW_MATRIX.md).

## 1. A3 as an exact HOL predicate

    refund_env_ok envmc ⇔
      interference_ok envmc.next_interfer
        (arm8_target.proj envmc.prog_addresses) ∧
      refund_ffi_contract envmc.prog_addresses envmc.ffi_interfer

`envmc` is the environment part of the machine record: `next_interfer`
is what the environment does between instructions; `ffi_interfer` is
the effect of each FFI call on the machine state. `refund_ffi_contract`
is the U392 definition (four indices, return address, callee-saved
registers, memory inside `dm`, result bytes).

- `refund_env_ok_iff_installed_residual`: for `ms.PC = 0x1000040D0w`,
  `refund_installed_rest2 (refund_mc 0x1000040D0w envmc) ms ⇔
  refund_env_ok envmc`. So the predicate is exactly the two clauses that
  U391 left unproved. It is not stronger and not weaker.
- `refund_abs_env_is_ok`: `refund_env_ok (refund_abs_env envmc)`. The
  predicate is satisfiable.
- `pc_changing_environment_is_not_ok`: an environment that changes the
  PC between steps does not satisfy it. The predicate is not trivial.

Limits, stated plainly:

- No theorem shows that a real environment satisfies `refund_env_ok`.
  It is the formal form of assumption A3 (and A4). It stays ASSUMED.
- U393 found by disassembly analysis (not a theorem) that the real
  `fficlose` cannot satisfy the FFI clause at every call state, because
  of its `assert` paths. `refund_ffi_contract` quantifies over every
  state `ms2`. So `refund_env_ok` is probably FALSE for an `ffi_interfer`
  that describes the real C code exactly. A weaker predicate (contract
  only at reachable call states) is not usable with the published
  compiler theorem as it stands. That variant is a missing lemma, not
  an assumption I add.
- One step stays outside HOL in every form: that the physical process
  is described by `targetSem` with some record `envmc`.

## 2. Slide-0 composition: SUCCEEDED

`refund_profile_a_slide0` (stored statement, read after exit 0):

    refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
    refund_heap_clear h e ∧ envmc.prog_addresses = refund_mem_dm h e ∧
    refund_env_ok envmc ∧
    stdin_content fs = SOME (explode (sexp_to_string (refund_request
      charge request original remaining enabled opened candidate amount
      reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs
    ⇒ ∃ms.
        (arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w) ∧
        (∀j ms' ffi'. evaluate M (basis_ffi ext cl fs) j ms =
             (TimeOut,ms',ffi') ⇒ M.target.get_pc ms' ≠ M.install_pc) ∧
        ∃io_events.
          machine_sem M (basis_ffi ext cl fs) ms ⊆
            extend_with_resource_limit {Terminate Success io_events} ∧
          extract_fs ext (cl,fs) io_events =
            SOME (add_stdout (fastForwardFD fs 0)
              (refund_render_fields (refund_fields charge request
                 original remaining enabled opened candidate amount
                 reason)))
    with M = refund_mc 0x1000040D0w envmc

Proof: `refund_installed_from_entry_reduced` (U391), the predicate
equivalence, `refund_mc_is_arm8` (U388),
`refund_u298_exclusion_valid_request` and
`refund_behavior_valid_request_no_handler` (U387). Instantiation and
modus ponens only. The instantiation `cbspace := 428`, `data_sp := 0`
type-checked. No new assumption. This form is stronger than the U403
plan: it holds for every environment record that satisfies the
predicate, not only for the abstract one.

`refund_profile_a_slide0_abstract_env`: the instance with
`refund_abs_env envmc`; it has no environment premise.

## 3. Does the output equation belong to the machine execution?

Yes, for the model machine. Evidence:

- Structural checks in the run (6 `CONTROL_OK`): one `io_events` is
  bound for both the inclusion and the `extract_fs` equation; the
  `machine_sem` term is for `M`, the basis oracle and the state `ms`
  that `arm8_run 27 s` reaches; the output term is syntactically the
  U387 term; no premise mentions `extract_fs`, `machine_sem` or
  `refund_installed_no_handler`; the statement has no source-semantics
  constant.
- `refund_profile_a_slide0_every_machine_run`, same premises:
  - every behaviour `b` of `machine_sem M (basis_ffi ext cl fs) ms` is
    `Terminate Success io` with the output equation for that `io`, or
    `Terminate Resource_limit_hit io'` with `io' ≼ io` and the equation
    for `io`;
  - a behaviour exists (`machine_sem_total`, published);
  - `Fail` is not a behaviour.

So the equation is not about an unrelated source execution: it holds
for the event list of every terminating run of this machine from this
state. A resource-limit run has only a prefix of such a list; its own
output is not specified.

Scope. "Machine" means the model machine `targetSem` with record `M`.
The entry state, the environment predicate and the input premises are
assumptions. No real run is described.

## 4. Assumptions of the composed theorem

1. `refund_entry_pre s h stk e` (EL0; no exception; four control bits;
   `PC = 0x100004000w`; three data slots; header bytes outside the
   image; `refund_image_mem 0w s.MEM`). ASSUMED. Slide 0.
2. `aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e`. ASSUMED.
3. `envmc.prog_addresses = refund_mem_dm h e`. ASSUMED.
4. `refund_env_ok envmc`. ASSUMED (section 1).
5. Canonical nine-field request on standard input; `wfcl`, `wfFS`,
   `STD_streams`. ASSUMED. Absent and malformed input are outside.
6. Oracle `basis_ffi` (read-error exclusion as an environmental
   precondition).

Joint satisfiability of 1–5: NOT shown. U390 shows 1–2 satisfiable;
`refund_abs_env_is_ok` shows 4 satisfiable. A witness for all five
together (it needs a concrete well-formed file system) was not built.

## 5. Smallest remaining premise

`refund_image_mem 0w s.MEM` inside premise 1, with the absolute
addresses of premises 1–3. The file is PIE. U389 judged slide 0
probably false for a real process (not measured). This is the premise
to remove next. The others are profile assumptions by design.

## 6. Slide-generic proof: prepared, NOT RUN

Static evidence (`records/cml_main-disassembly.txt`; `otool`, the
binary was not executed; tool output, not a proof): the 27 start-up
words are 11 `adrp`/`add` pairs, two `ldr`, five `str` (all
register-relative) and one `b`. No word loads an absolute address.

Consequence for the statement. `adrp` uses the page of the PC. The
values shift by exactly `sl` only if `sl` is a multiple of 4096. So the
premise is `aligned 12 sl`, not the `aligned 3 sl` of U403. Real slides
are page multiples (general knowledge; not measured here).

Statement T_A: `refund_profile_a_slide0` with a free `sl : word64`,
premises `aligned 12 sl` and `w2n sl + 0x100030F30 < 2 ** 64`, and each
absolute address `A` replaced by `A + sl`.

Steps (each one theory; contexts as in U388–U392):

- **S1** (ARMv8 context). `cml_main_run_sl`: from `PC = 0x100004000w +
  sl` with `refund_image_mem sl`, 27 steps reach `0x1000040D0w + sl`;
  registers and the five header words are the slide-0 values plus `sl`.
  The step theorems are per instruction word and do not fix the PC.
  Lemma needed: `aligned 12 sl ⇒ page (A + sl) = page A + sl`.
- **S2.** `refund_code_dm_sl`, bitmap domain, `refund_mem_dm_sl`,
  `refund_heap_clear_sl`; disjointness and no-wrap lemmas.
- **S3.** `refund_end_state_sl`; the 23 clauses of U390 and the 5 of
  U391 at `refund_mc (0x1000040D0w + sl) envmc`. `refund_mc` already
  takes its base as a parameter.
- **S4.** `ffi_interfer_ok_iff_contract` at the shifted base. The
  contract's stub addresses become `0x1000040D0w + sl − n2w ((3 +
  index) * 16)`; so `refund_env_ok` gets `sl` as a parameter.
- **S5.** `refund_installed_from_entry_reduced_sl`, then T_A by the
  composition of section 2 (the U387 theorems do not mention the slide).
- **S6.** Regression: T_A at `sl = 0w` gives `refund_profile_a_slide0`.

Controls: different slides for code and bitmaps; a slide that wraps;
`sl` not a page multiple (S1 must fail or need the premise); a changed
code word.

Risks: S3 repeats 28 clause proofs; some may use numeric facts about
the concrete addresses (alignment, ordering) that need `sl` lemmas. S4
changes a definition that later theorems (U393–U401) name; those stay
at slide 0 unless redone.

## 7. Controls and closure

- Predicate: satisfiable; not trivial; equivalent to the U391 residual.
- Composition: 6 structural controls (section 3); tag check on all 8
  theorems and the definition; 0 failed lemmas in `prof-0002`.
- Closure: 535 nodes; axioms only `bool.SELECT_AX`, `INFINITY_AX`,
  `ETA_AX`, `BOOL_CASES_AX`; `forge_compileCorrectControl` in the
  closure.
- Preserved: U387, U388, U391, U392 theorems are used as stored; none
  was restated. The R1–R5 specification file was not touched.
- NOT RUN: a separate exact-statement import script; a repeat; the
  joint satisfiability witness.

## 8. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `prof-0001` | 1 | authoring (one tactic); nothing exported |
| `prof-0002` | 0 | `forge_refundProfileA` |
| `otool` static disassembly | 0 | read-only; not a proof |
| Repeat; import script; joint witness; S1–S6; A8 review; clean replay; independent replay | NOT RUN | |

Failures: authoring as listed. Tool: none. Memory: none (swap 11.2 of
12.3 GiB used before the run). Logical: none found in stored statements.

## 9. Next step

S1 and S2 of the slide-generic proof. Before that, or in parallel: the
owner's review of U403 questions R1–R5 and of the A8 matrix.
