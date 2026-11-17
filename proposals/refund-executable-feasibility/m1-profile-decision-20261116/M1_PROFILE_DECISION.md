# M1 profile decision packet (U402)

Date: 2026-11-16. Decision preparation only. CURRENT none. M1 open.
Stage 12 unauthorized. No profile approved. `end_to_end=false`. Nothing
committed. No proof case ran. No replay ran. This packet approves
nothing and changes no acceptance criterion.

Sources read in this run: `FORGE_MISSION.md` (sections 0, 2, 3, 12, 13);
`m1-exclusion-profile-20261113/PROFILES.md`; `spec/refund/RefundSpec.dfy`;
`unsure.md` entries U258, U262, U295, U327; stored statements and
definitions in the U388–U392 run logs; proof scripts `real-0004.sml`
and `source-0006.sml` (U386); the U401 audit.

## 0. Correction to the U401 audit

The U401 audit said the strongest composed theorem carries the output
equation. That is wrong. Stored statement (`env-0005`):

    refund_behavior_abstract_env:
      refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
      refund_heap_clear h e ∧ envmc.prog_addresses = refund_mem_dm h e ∧
      stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs
      ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧
          ∃io_events. machine_sem (refund_mc 0x1000040D0w
              (refund_abs_env envmc)) (basis_ffi ext cl fs) ms
            ⊆ extend_with_resource_limit {Terminate Success io_events}

`io_events` is not constrained. The output equation exists only in
`refund_behavior_valid_request_no_handler` (U387), which has
`refund_installed_no_handler` as a premise and is not composed with the
entry state. So one more obligation exists (O3 below). The U401 files
carry a correction note.

## 1. Profile A versus Profile B

Definitions: U356 Phase 5 and `PROFILES.md` (U360). Neither is approved.

| # | Assumption | Profile A | Profile B |
| --- | --- | --- | --- |
| 1 | FFI oracle | Published `basis_ffi` | New oracle with a read-error case. No definition exists |
| 2 | OS read errors on an open readable descriptor | ASSUMED absent (named exclusion) | In scope; needs a new contract clause |
| 3 | No other thread, process or signal changes descriptor state | ASSUMED | ASSUMED |
| 4 | `wfcl`, `wfFS`, `STD_streams`, live `numchars` | ASSUMED | ASSUMED, restated |
| 5 | Canonical wire request on standard input | ASSUMED for the producer | Same |
| 6 | Machine state satisfies `installed` | ASSUMED | ASSUMED |
| 7 | Installer exclusion (U298) | Now a conclusion under premises (U386–U392) | Same |
| 8 | Native FFI code meets `ffi_interfer_ok` | ASSUMED, all functions | `ffiread` becomes an obligation |
| 9 | Between-step interference | ASSUMED | ASSUMED |
| 10 | Processor = L3 model; loader gives the stated layout | ASSUMED | ASSUMED |
| 11 | Resource condition | Not assumed; resource-limit prefix allowed | Same |
| 12 | Approved contract | Unchanged | New clause; needs owner approval |
| 13 | HOL kernel, PolyML, published CakeML and L3 | Trusted | Trusted, plus the new oracle |

Against the M1 text (`FORGE_MISSION.md`, "M1 success condition",
section 13):

| M1 requirement | Profile A | Profile B |
| --- | --- | --- |
| Approved nontrivial behavioural specification | Uses the approved contract unchanged | Changes the contract. Section 2 forbids that without approval |
| Exact executable identified | Same in both | Same |
| Checked connection under explicit assumptions | Possible with the existing chain | Every theorem naming `basis_ffi` must be redone |
| Remaining assumptions identified and compatible with the approved profile | Possible after approval. Three assumptions are missing from the profile text (section 7, Q3) | Same gaps, plus a new oracle |
| Independent proof checking; reproducible evidence | NOT RUN in both | NOT RUN in both |
| Negative controls | Exist per packet | Would need new ones |

Does Profile A permit the existing refund executable proof? Yes, as a
level B claim, under: rows 2–6, 8–10, 13; the entry-state premises of
section 3; and the three additions of Q3. It does not give level C.

## 2. Recommendation (not an approval)

Recommend Profile A, amended as in Q3. Grounds in the mission text:

- Section 0: do not make "universal … operating-system correctness
  proofs" a prerequisite of the first slice.
- Section 2: never "modify an approved specification to make an
  implementation pass". Profile B needs a contract change.
- Section 3D item 1: reuse an established verified compilation
  pipeline. Profile A uses the published oracle and theorem unchanged.
- Owner guidance recorded in U327: "trust ISA implementation,
  documented OS behavior, HOL logic/kernel; do not verify silicon".

Read-error exclusion. Is it still valid? Evidence: under `wfFS`,
`STD_streams`, the model read on standard input always returns status 0
(`stdin_ffi_read_status_zero`, U327). So inside the model the exclusion
costs nothing. Is it authorized? No. Real read errors (`EIO`, `EINTR`)
are documented OS behaviour, so the U327 trust statement does not cover
their absence. The approved contract has no clause for them (U328). The
exclusion needs explicit approval as part of the profile (Q2).

FFI path results U393–U401 under Profile A: supporting evidence, not
obligations (row 8 is ASSUMED). One caution stays: the literal
`ffi_interfer_ok` is probably false for the real C code (U393 analysis,
not a theorem). The profile should state row 8 as a simulation
assumption instead (Q3).

## 3. Candidate acceptance theorems

### 3.1 Slide-zero premises in the strongest existing theorem

From the stored definitions:

- `refund_entry_pre s h stk e`: `s.PC = 0x100004000w`; data slots at
  `0x10002C000w`, `0x10002C008w`, `0x10002C010w`; the 40 header bytes at
  `h` outside `[0x100000000, 0x100030F30)`; `refund_image_mem 0w s.MEM`;
  EL0; no exception; `¬E0E`, `¬SA0`, `¬TBI0`, `¬TBI1`.
- `refund_heap_clear h e`: heap outside `[0x100000000, 0x100030F30)`.
- `refund_mem_dm h e`: `refund_code_dm` is `[0x1000040D0, 0x100024000)`;
  the bitmap domain is absolute.
- Conclusion: `ms.PC = 0x1000040D0w`; record `refund_mc 0x1000040D0w …`.
- `refund_end_state`: five header words with absolute values
  (`0x10002C018`, `0x100030F30`, `0x100030F30`, `0x100023E54`,
  `0x100024000`).

Already slide-generic: `refund_image_mem sl m` and the three image
lemmas (U389).

### 3.2 Minimum slide-generic theorem

Replace every absolute address `A` above by `A + sl`, for a free
`sl : word64` with `aligned 14 sl` (16 KiB pages; to be confirmed) and
no wrap-around of the image range:

    refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧
    8192w ≤₊ e − h ∧ refund_heap_clear_sl sl h e ∧
    envmc.prog_addresses = refund_mem_dm_sl sl h e ∧ <input premises>
    ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w + sl ∧ …

It needs: the 27 start-up steps with PC-relative address arithmetic
(not checked word by word here); `refund_mc (0x1000040D0w + sl)`; the
installed-state clauses with shifted domains. The compiled CakeML code
is addressed through `cbspace` and the start PC, which favours this. It
is NOT RUN and may fail on an absolute address.

### 3.3 Candidate theorem, Profile A

Not proved in this form. Parts marked [have] exist at slide 0.

    ∀sl s h stk e envmc ext cl fs text.
      refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧
      8192w ≤₊ e − h ∧ refund_heap_clear_sl sl h e ∧
      envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
      stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs
    ⇒ ∃ms mc. mc = refund_mc (0x1000040D0w + sl) (refund_abs_env envmc) ∧
        arm8_run 27 s = SOME ms ∧                                  [have]
        (∀j ms' ffi'. evaluate mc (basis_ffi ext cl fs) j ms =
             (TimeOut,ms',ffi') ⇒ get_pc ms' ≠ mc.install_pc) ∧    [have]
        ∃io. machine_sem mc (basis_ffi ext cl fs) ms
               ⊆ extend_with_resource_limit {Terminate Success io} ∧ [have]
             extract_fs ext (cl,fs) io =
               SOME (refund_stdout_result fs text)                [missing]

where `refund_stdout_result fs text` is: for a parsable canonical
request, `add_stdout (fastForwardFD fs 0) (refund_render_fields
(refund_fields …))`; for other present input, the specified rejection
(U388 `refund_reject_semantics`). Its exact form must be taken from the
U388 source theorems; I did not read their statements in this run.

Outside the theorem, named in the profile: the link from
`refund_fields` to `RefundSpec.Assess` R1–R5 (section 4, O1); the
simulation assumption; the L3 model; the file reader of U389.

### 3.4 Candidate theorem, Profile B

Same shape, with `basis_ffi` replaced by a new oracle `forge_ffi` that
allows status 1 on a readable descriptor, and a third behaviour case:

    … ⊆ extend_with_resource_limit
          {Terminate Success io_ok; Terminate Success io_read_error}

with a specification of `io_read_error`. No such oracle, contract
clause or theorem exists. I cannot write this statement exactly without
inventing a specification; that needs owner approval first.

## 4. Outstanding proof obligations (Profile A)

| # | Obligation | Evidence today | Blocks M1 |
| --- | --- | --- | --- |
| O1 | Contract link R1–R5 Unicode to `refund_fields` | Dafny side: `RefundUtf8Transport.Equivalent`, `Boundary.dfy`, no input precondition (U262, U295). HOL side: seven theorems, `refund_fields` projected result, wire round trips (U295). Gap (U295): "Dafny and HOL semantics are not connected by a verified inter-kernel translation. Their mathematical Boolean/integer/sequence/byte identification remains an explicit review requirement." U258: manual AST to approved source "not established" | Yes, unless the profile accepts the cross-tool identification as a reviewed assumption (Q4) |
| O2 | Slide-generic chain (3.2) | Image lemmas only | Yes |
| O3 | Output equation in the composed theorem (section 0) | `refund_behavior_valid_request_no_handler` (U387), `refund_accept_semantics`, `refund_reject_semantics` (U388) not composed with U392 | Yes |
| O4 | One acceptance statement; joint satisfiability of its premises | `refund_entry_and_heap_premises_satisfiable` (U390) covers entry and heap only | Yes |
| O5 | Clean replay of the CakeML-dependent chain | NOT RUN | Yes |
| O6 | Independent replay | NOT RUN | Yes |
| O7 | Absent standard input | OPEN (U388) | Only if the profile includes it (Q5) |

Resolved by location in this run (U401 gap 5): `backend_config_ok` and
`mc_init_ok` are discharged inside the U386 proofs from the published
`arm8_backend_config_ok` and `arm8_init_ok` (`real-0004.sml` lines
90–91, `source-0006.sml` lines 58–59); `opt_eval_config_wf` by its
definition (`source-0006.sml` line 61). The final U386 theorems do not
have them as premises, and the kernel checked those theorems. Required
evidence for M1: these scripts pass in the clean replay (O5). I did not
re-run them.

Not obligations under Profile A: U393–U401 FFI paths; the 12 residual
`write` conjuncts; `read`, `open_in`; `close` reachability; termination;
the `write`-event invariant.

## 5. Shortest dependency-ordered sequence

1. Owner answers Q1–Q5 (section 7).
2. O3: compose the output equation at slide 0. Small; it uses stored
   theorems only. It fixes the exact conclusion before generalizing.
3. O2: slide-generic start-up, domains, installed state, then the
   composed theorem of step 2 for every `sl`.
4. O4: the single statement, with a constructed joint witness labelled
   as constructed, and controls (wrong hash, changed code word, wrong
   slide, missing premise).
5. O1: as decided in Q4.
6. O5 clean replay. 7. O6 independent replay (separate authorization).

Steps 2–4 need no new method. Step 3 carries the main technical risk.

Smallest proof task once a profile is approved: step 2.

## 6. Required independent replay evidence

NOT RUN. Proposed content:

- Pins: PolyML 5.9.2 `4557554077078decce4ce5f90da00a713cfc32e4`, HOL
  `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, CakeML
  `cd9155694c16831373ab695a670794f23282ed62` (U258); Dafny 4.11 and the
  UTF-8 library commit of U262 for the contract side.
- Executable SHA256
  `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
- Build from sources only: no cached `.dat`, no Forge heap.
- Statement comparison by a checker written apart from the proof
  scripts; closure and axiom lists (expected: the four `bool` axioms).
- All negative controls must fail as recorded.
- Second derivation of the two file slices and offsets.
- Different machine and operator. Recorded peak memory and disk.
- The Dafny proofs of O1 re-verified with the pinned Dafny.

## 7. Questions that need explicit human authorization

- **Q1.** Approve Profile A, Profile B, or neither?
- **Q2.** If A: approve the named exclusion "no OS read error on an open
  readable descriptor" as part of the M1 claim?
- **Q3.** If A: approve these additions to the profile text, which U360
  does not list? (a) Entry-state assumption: the loader and C run-time
  reach `cml_main` with the image mapped at some slide and the heap
  premises. (b) Row 8 restated as one simulation assumption (the real
  process refines the model machine with the abstract FFI environment)
  instead of the literal `ffi_interfer_ok`. (c) The U389 file reader
  and offset tool as trusted.
- **Q4.** Contract link: must the Dafny-to-HOL identification be a
  machine-checked translation before M1 closes, or may it be a named,
  independently reviewed assumption? The mission allows identified
  correspondence assumptions "compatible with the approved assurance
  profile"; it also forbids counting a weaker theorem as the approved
  contract. This is the owner's call.
- **Q5.** Absent standard input: in the claim (then O7 is an
  obligation) or a named exclusion?
- **Q6.** Budget and authorization for the clean replay and for the
  independent replay.

Until Q1 is answered, no proof step changes the M1 status.
