# Restricted Profile A: candidate statement for review (U403)

Date: 2026-11-16. For owner review. CURRENT none. M1 open. Stage 12
unauthorized. No profile approved. `end_to_end=false`. Nothing committed.
No proof case ran. No replay ran. This document approves nothing.

Base text: Profile A of U356 Phase 5 and `PROFILES.md` (U360). Stored
statements read for this document: `refund_installed_abstract_env`
(U392), `refund_mc_is_arm8` (U388),
`refund_behavior_valid_request_no_handler` (U387), the definitions of
`refund_entry_pre`, `refund_image_mem`, `refund_heap_clear`,
`refund_mem_dm` (U389, U390).

## 1. The candidate claim

Level: executable correctness under explicit assumptions (level B of
U401). It is a theorem about a model machine, plus named assumptions
that connect the model to a real run. It makes no statement about macOS,
the loader, `libSystem`, the kernel or the processor.

Claim, in words. For the file with SHA256
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`: if a
run starts from the entry state of A2 with a canonical refund request on
standard input, and the environment meets A1–A9, then the run either
stops at a resource limit after a prefix of the specified events, or it
terminates with success and standard output equal to the rendered
six-field result of `refund_fields` on that request. The installer
entry is never reached.

Not claimed: termination; behaviour on absent or malformed input;
behaviour after an OS read error; anything about a run that does not
meet A1–A9; authorization of the output; end-to-end verification.

## 2. Assumptions, separately enumerated

Class: C = clarifies the U360 Profile A text. X = changes it (new,
replaced or re-formed). Every X item needs explicit approval as a
change, not as a clarification.

| # | Assumption | Formal form | U360 row | Class |
| --- | --- | --- | --- | --- |
| A1 | **Read-error exclusion.** Environmental precondition of the run: during this run, no `read` on an open readable descriptor returns an OS error (`EIO`, `EINTR`, `EAGAIN`, `EFAULT`). It is a condition on the run. It is NOT a property of macOS and is never to be cited as one. A run in which such an error occurs is outside the claim | Implied by the oracle `basis_ffi` under `wfFS`, `STD_streams` (`stdin_ffi_read_status_zero`, U327) | 1, 2 | C (wording made stricter) |
| A2 | **Entry state.** At `cml_main`: EL0, no exception, `¬E0E`, `¬SA0`, `¬TBI0`, `¬TBI1`; the file image mapped at one slide; the three data slots hold `h`, `stk`, `e`; `aligned 3 h`, `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h`; heap and 40 header bytes outside the image; `prog_addresses` equals code, heap and bitmap domains | `refund_entry_pre`, `refund_heap_clear`, `envmc.prog_addresses = refund_mem_dm h e` (slide 0 today) | 6 (was: state satisfies `installed`), 10 | X: replaces row 6. `installed` is now derived (for the abstract record) from this smaller assumption. The loader, dyld, `_main` and the C run-time are inside it, unproved |
| A3 | **FFI simulation.** The real process, from the A2 state, is simulated by the model machine `refund_mc … (refund_abs_env envmc)`: each real FFI call (stub, C function, `libSystem`, kernel) has the effect of the abstract FFI step with the `basis_ffi` oracle result | NOT formalized. No HOL statement exists | 8 (was: `basis_ffi.c` meets `ffi_interfer_ok`) | X: re-formed. The U360 row was a formal predicate that is probably false for the real C code (U393 analysis, not a theorem). A3 is informal |
| A4 | **Step interference.** Between instructions nothing changes the projected state (no signal handler, other thread or kernel action visible to the program) | Identity `next_interfer` in `refund_abs_env` | 3, 9 | C |
| A5 | **Processor.** The processor executes the instruction words of the file as the L3 ARMv8 model at EL0 | Model choice | 10 | C |
| A6 | **Trusted file reader.** The HOL constant `refund_file` is the byte content of the executable. It comes from an ML reader with a SHA256 round-trip check; segment offsets come from a Python tool | `refund_file` definition (U389) | none ("code bytes OBSERVED equal") | X: new trusted component |
| A7 | **Input domain.** Standard input is present and holds exactly the canonical nine-field request `sexp_to_string (refund_request charge request original remaining enabled opened candidate amount reason)`, for any values of the nine fields. `wfcl cl`, `wfFS fs`, `STD_streams fs`. Absent input and malformed text are OUTSIDE the candidate claim | Premises of U387 | 4, 5 | C. Note: all nine-field values are in the domain, so ineligible requests (rejections R3) are covered. Malformed-text theorems exist (U388) and are not used |
| A8 | **Contract identification: REVIEWED, not machine-checked.** `refund_fields` in HOL and `RefundSpec.Assess` (R1–R5) in Dafny are each proved against a byte-list interface (U262, U295). The identification of Dafny and HOL booleans, integers, sequences and bytes, and of the two interface texts, rests on human review. No inter-tool translation is verified | None | none | X: new assumption. A named reviewer other than the proof author is needed (question R2) |
| A9 | **Proof base.** HOL4 kernel, PolyML, published CakeML and L3 definitions, the published `basis_ffi` oracle | — | 13 | C |
| A10 | **Resource condition.** Not assumed. The conclusion allows a resource-limit prefix | — | 11 | C |

U360 row 7 (installer exclusion) is no longer an assumption. It is a
conclusion of the theorem. U360 row 12 (contract unchanged) holds.

Changes to the original profile, in one list: A2 (replaces row 6),
A3 (re-forms row 8, informal), A6 (new), A8 (new). The rest clarify.

Check against the M1 criteria ("no stronger claim"): the claim is
conditional; assumptions are explicit; it concerns one exact file; it
does not claim termination, deployed-machine correctness or end-to-end
verification. A8 is the point where the claim could exceed the
criteria: section 3C says "do not count a theorem that proves a weaker
property as satisfying the approved contract". With A8 the M1 claim is
"R1–R5 as identified by review", and must be worded so.

## 3. The formal statement

### 3.1 Slide 0 (composition of stored theorems; NOT RUN)

    T_A0:
      refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
      refund_heap_clear h e ∧ envmc.prog_addresses = refund_mem_dm h e ∧
      stdin_content fs = SOME (explode (sexp_to_string (refund_request
        charge request original remaining enabled opened candidate
        amount reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs
      ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧
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
      where M = refund_mc 0x1000040D0w (refund_abs_env envmc)

### 3.2 Minimal composition for T_A0

Three stored theorems, modus ponens only. No new lemma. No assumption
about the output: the output equation is the conclusion of step 3 as
stored.

1. `refund_installed_abstract_env` (U392): the six entry premises give
   `ms` with `arm8_run 27 s = SOME ms`, `ms.PC = 0x1000040D0w` and
   `refund_installed_no_handler M ms 428 0`.
2. `refund_mc_is_arm8` (U388): `is_arm8_machine_config (refund_mc base0
   envmc)`, instantiated with `base0 := 0x1000040D0w`,
   `envmc := refund_abs_env envmc`.
3. `refund_behavior_valid_request_no_handler` (U387) with `mc0 := M`,
   `cbspace := 428`, `data_sp := 0`: gives the `machine_sem` inclusion
   and the `extract_fs` equation, unchanged.
4. Exclusion conjunct: `refund_u298_exclusion_valid_request` (U387)
   with the same instantiation, under the same `ms`.

Points to check when it runs (not assumed here): both conjuncts must
share one `ms` (take `ms` from step 1 once); the variable types of
`cbspace`, `data_sp` in U387 must accept `428`, `0`; the stored `M` in
U392 must be syntactically the instance of `mc0`. If any check fails,
report it; do not adjust the statement.

Controls for T_A0: drop the input premise (must fail); replace the
output term by a different field tuple (must fail); replace
`refund_abs_env envmc` by `envmc` (must fail: no installed theorem);
exact-statement import; tag check; premises jointly satisfiable by a
constructed state, labelled as constructed.

### 3.3 Slide-generic statement T_A (required for a PIE file; NOT RUN)

T_A is T_A0 with one extra universally quantified `sl : word64`, the
premises `aligned 3 sl` and "the image range does not wrap"
(`w2n sl + 0x100030F30 < 2 ** 64`), and every absolute address `A`
replaced by `A + sl`: in `refund_entry_pre` (PC, three data slots,
separation range, `refund_image_mem sl`), `refund_heap_clear`,
`refund_mem_dm`, `ms.PC`, and `M = refund_mc (0x1000040D0w + sl) …`.
The page alignment of real slides is not used; `aligned 3 sl` is the
weaker premise. Whether the proofs need more is not known.

## 4. Required PIE slide proof

Have: `refund_image_mem sl m` and three image lemmas for every `sl`
(U389); `refund_mc base0 envmc` is already parametric in its base.
Evidence that favours feasibility, not a proof: the file has no rebase
fixups and no fixups in `__TEXT` or the bitmaps (U389, by inspection).

Needed, in order:

- **S1.** `cml_main_run_sl`: 27 steps from `PC = 0x100004000w + sl`;
  the five header words become their slide-0 values plus `sl`. Risk: a
  word that loads an absolute address would break it. Each of the 27
  words must be checked.
- **S2.** Shifted domains: `refund_code_dm_sl`, bitmap domain,
  `refund_mem_dm_sl`, `refund_heap_clear_sl`; disjointness lemmas.
- **S3.** `refund_end_state_sl` and the 23 + 5 installed-state clauses
  at the shifted record (U390, U391 proofs re-done with `sl`).
- **S4.** The two environment clauses for `refund_abs_env` at the
  shifted record (U392).
- **S5.** `refund_installed_abstract_env_sl`, then T_A by the
  composition of 3.2.
- **S6.** Regression: T_A at `sl = 0w` implies T_A0.

Controls: different slides for code and bitmaps (must fail); a slide
that wraps the image range (must fail); a misaligned slide (must fail
or be shown harmless); changed code word (must fail).

Not part of the slide proof, still inside A2: that the real loader
maps the file at one slide and that dyld and the C run-time reach
`cml_main` with the A2 state.

## 5. Remaining replay requirements

All NOT RUN. None may start before review and authorization.

1. Clean replay on this host, from sources only: PolyML 5.9.2
   `4557554077078decce4ce5f90da00a713cfc32e4`, HOL `9783a499…95ae3`,
   CakeML `cd915569…2ed62`; every Forge theory in the closure of T_A,
   in dependency order; no cached `.dat`; no Forge heap. This also
   re-checks the U386 discharge of `backend_config_ok`, `mc_init_ok`,
   `opt_eval_config_wf`.
2. Statement comparison by a checker written apart from the proof
   scripts. Closure and axiom list (expected: four `bool` axioms).
3. All negative controls, each failing as recorded.
4. Second derivation of the file slices, offsets and hash (for A6).
5. Dafny side of A8 re-verified with pinned Dafny 4.11 and the U262
   library commit.
6. Independent replay: items 1–5 on a different machine by a different
   operator. Needs separate authorization and a budget.
7. Resource record: peak memory and disk per step. Local cases here
   used 2.4–3.4 GiB resident; the full CakeML build was not measured.

## 6. Questions for the review

- **R1.** Approve, amend or reject the four changes A2, A3, A6, A8?
- **R2.** A8: who is the reviewer, and what record of the review counts?
- **R3.** A3 is informal. Is an informal simulation assumption
  acceptable for M1, or must it be stated in HOL first?
- **R4.** A7: confirm "canonical nine-field request only".
- **R5.** May T_A0 (slide 0) be run before the profile decision, as a
  composition check that changes no status? Until told so, it stays
  NOT RUN.
