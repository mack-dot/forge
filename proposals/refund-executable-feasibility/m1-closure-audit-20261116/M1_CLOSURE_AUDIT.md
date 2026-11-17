# M1 closure audit (U401)

Date: 2026-11-16. Audit and plan. CURRENT none. M1 open. Stage 12
unauthorized. No profile approved. `end_to_end=false`. Nothing committed.
No replay was started. This document approves nothing.

Companions: [dependencies](M1_PROOF_DEPENDENCIES.md),
[trusted computing base](M1_TRUSTED_COMPUTING_BASE.md),
[critical path](M1_CRITICAL_PATH.md).

Limits of this audit. Reports U350–U396 were extracted by two read-only
agents, with quotes. I read U397–U401 myself. Records before U345 were
not re-audited. One proof case (`word-0003`) finished before the owner
changed U401 to an audit; its result is recorded as evidence.

## 1. M1 verdict: what is proved

Locally machine-checked, with cached parents, never cleanly or
independently replayed:

- The executable file (SHA256
  `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`)
  contains the compiled code and bitmaps at the stated offsets (U389).
- For the MODEL machine with an ABSTRACT FFI environment, from an
  ASSUMED entry state at `cml_main` at slide 0, with well-formed present
  input: the behaviours are within the resource-limit extension of
  "terminate with success and the specified standard output", and the
  installer entry is never reached (`refund_behavior_abstract_env`,
  `refund_u298_exclusion_abstract_env`, U392).
- For the same model: a run that terminates with success reaches a
  `write` call state with `x1 = 8` and the word-level buffer bound
  (U400, U401).

Not proved: that any real process is in the assumed entry state; that
the real process follows the model; that the model body is the approved
R1–R5 Unicode contract; any clean or independent replay.

M1 is not closed. By the mission text it stays `PARTIAL`.

## 2. The M1 acceptance theorem

Authoritative text (`FORGE_MISSION.md`, "M1 success condition" and
section 13): a specific, nontrivial behavioural claim for an exact
executable, directly or through a sound semantic-preservation chain,
under explicit assumptions; an independent checker validates the proof;
executable and proof dependencies exactly identified; every remaining
correspondence assumption is identified and "compatible with the
approved assurance profile"; reproducible evidence; negative controls.
The status file names the claim: "full approved refund R1–R5
integer/Unicode behavior for the exact native executable".

Level required. The text asks for level B: executable correctness under
explicit assumptions. It does not ask for level C (it excludes
"universal QEMU or operating-system correctness proofs" from the first
slice). It asks for more than level A: the assumptions must be approved,
and the theorem must be about the exact executable's bytes.

Statement that would justify closing M1 (Path A form; not yet proved in
this form):

    For every slide sl, state s, heap bounds h, e, stack stk, command
    line cl, file system fs, text:
      refund_entry_pre_sl sl s h stk e          (image of the file with
                                                 SHA256 b8ed5ec2… mapped
                                                 at slide sl; user mode;
                                                 PC at cml_main)
      ∧ heap and stack premises (aligned, ≥ 8192 bytes, heap clear)
      ∧ stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs
    ⇒ ∃ms. arm8_run 27 s = SOME ms ∧
        machine_sem (refund_mc … (refund_abs_env envmc))
                    (basis_ffi ext cl fs) ms
          ⊆ extend_with_resource_limit {Terminate Success io} ∧
        extract_fs ext (cl,fs) io = SOME (the R1–R5 result on stdout,
                                          or the specified rejection) ∧
        no TimeOut prefix reaches install_pc                (U298)

with: source program `refund_prog`; compiled `code`, `data` from
`refund_alloc_compiled`; ARMv8 scope: L3 model, EL0, the instruction
words in the file; termination: success or a resource-limit prefix, no
termination claim; FFI: the published `basis_ffi` oracle; trusted
assumptions as in the TCB file, with the simulation assumption named;
reproduction: clean replay and one independent replay with all controls.

`end_to_end=true` needs, beyond this theorem: the link from the approved
contract to the result term; an approved profile that accepts the
assumption list; the independent replay; the owner's decision. I do not
set or recommend the flag.

## 3. Exact remaining obligations

Blocking M1 (details in the critical-path file):

1. Profile approval (owner).
2. Approved contract to HOL model, including the Unicode transfer.
3. Slide: composed theorems hold at slide 0 only; the binary is PIE.
4. One acceptance statement with jointly satisfiable premises.
5. Compiler-premise ledger for three published premises.
6. Clean replay. 7. Independent replay.

Not blocking M1 under Profile A, open for a stronger claim: termination;
`write`-event invariant; 12 residual `write` call-state conjuncts;
`read`, `open_in`; `close` reachability; external FFI conformance;
loader, dyld, C run-time; real machine correspondence.

## 4. Trusted computing base

See the TCB file. For a Path A claim: HOL4 and PolyML; published CakeML
definitions and the `basis_ffi` oracle; the L3 model; one simulation
assumption that contains the loader, dyld, C run-time, `basis_ffi.c`,
`libSystem`, kernel and processor; input premises; the U389 file reader.

## 5. Critical path

A0 owner decisions → A1 contract re-audit → A2 slide-generic chain →
A3 acceptance statement and satisfiability → A4 premise ledger →
A5 clean replay → A6 independent replay → A7 packet.

## 6. Alternative path

Path B replaces parts of the simulation assumption by proofs: memory
layout at FFI calls, the four C paths, event-keeping specifications, a
per-call `ffi_interfer_ok`, `libSystem` contracts, process entry. This
is research beyond the M1 text. It does not end with zero assumptions.

## 7. Risks to the guarantee

- Slide 0 is probably false for a real PIE process (U389; not measured).
  Until A2, the theorem may apply to no real run.
- The literal `ffi_interfer_ok` is probably false for the real C code
  (U393 analysis, not a theorem). Use the simulation form.
- The model body may not be the approved contract (obligation 2).
- Premises are not shown jointly satisfiable (U392).
- All results are single-machine, cached-parent. Three exit-0 defects
  were found only by reading statements (U393, U398). An independent
  replay may find more.
- Read errors on an open descriptor are outside the claim (Profile A).
- U399–U401 `write` theorems need `Terminate Success`, which is not
  proved.

## 8. Next action

Owner: decide the profile and confirm the M1 claim text (A0). In
parallel, authorize the contract re-audit (A1); it is read-only. First
proof task after that: the slide-generic chain (A2).

## 9. U401 proof evidence recorded before the audit

`results/refund-write-word-local-20261116/attempt-0001`: `word-0001`,
`word-0002` exit 1 (authoring); `word-0003` exit 0,
`forge_refundWriteWord`, 19 theorems, 536 closure nodes, four `bool`
axioms. Main results: `write_bound_numeric_iff_word` (no overflow: the
sum is below 2^18; unsigned comparison); `write_call_pre_from_residual`
and its converse (7 of 19 conjuncts discharged: `PC`, `x1 = 8`, the
bound, and four that hold by the choice of `b`, `c`, `a`, `g`; 12
residual); `refund_terminating_run_write_path_under_residual`;
`valid_write_to_open_fd_succeeds`;
`replay_ignores_failed_write_with_valid_clen` (the exported
specification cannot imply "every `write` event is successful");
`failed_write_call_keeps_the_file_system`; controls for overflow, sign
of `x3`, violated bound, failed events. `¬word_msb x3` is NOT derived
(`numeric_bound_does_not_give_sign_of_x3`). Source inspection (not a
proof): `writei` retries on a zero count and raises `InvalidFD` on
result byte 1; `refund_main` has no handler. No source-level invariant
was proved. NOT RUN: exact-statement import, repeat.

## Correction (U402, 2026-11-16)

Two statements of this U401 file are corrected by
[the U402 packet](../m1-profile-decision-20261116/M1_PROFILE_DECISION.md):

1. `refund_behavior_abstract_env` does NOT carry the output (`extract_fs`)
   equation. Its `io_events` is unconstrained. The output equation is
   only in `refund_behavior_valid_request_no_handler` (U387), not
   composed with the entry state. This is a further blocking obligation.
2. `backend_config_ok`, `mc_init_ok` and `opt_eval_config_wf` are
   discharged inside the U386 proof scripts from published theorems.
   The "NOT FOUND" gap is resolved by location; a clean replay is still
   needed.

The original text above is left unchanged.
