# M1 exact claim (worker X1, step B1; read-only; nothing here is proved unless a stored record says so)

> CORRECTIONS of 2026-11-19T06:35Z (reports D4 and D11; owner text 15). Read these
> before sections 3 and 4.
> 1. The output-bytes lemma L-OUT as stated in section 3.1, with a free
>    external oracle `ext`, is FALSE (control N-O1 of report D4). The
>    corrected statement fixes `ext := no_ext`; draft
>    `drafts/route-a/L_OUT_DRAFT.sml`, not run.
> 2. "Exit status 0 implies a complete standard output" is NOT a
>    theorem and is false as an implication from the model: `_cml_exit`
>    tests `cbz w0` (32 bits) and the status is 8 bits; the model tests
>    64 bits. Counterexample STATE: x0 = 2^32 at a resource stop gives
>    status 0 and an empty stderr. Its reachability is unknown.
> 3. "A non-zero exit implies a strict prefix" is false: the prefix
>    relation of `extend_with_resource_limit` is not strict; the output
>    can be complete.
> 4. What is true in the model: the bytes on descriptor 1 are a prefix
>    of the result on every behaviour. With the strict-prefix lemma
>    (draft, not run) a strict parse succeeds only on the complete
>    result, whatever the exit status.
> 5. The processor premise `arm8_ok` requires TBI0 = F and SA0 = F;
>    real kernels set both to 1 (report D11). The premise holds only
>    for an erased copy of the real state.

R = `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/` (on `main`).
E4 = `R/final-cases/e4-0001/stdout.log`; E4P = `R/final-cases/e4-0001/proof.sml`.
CK = `.toolchain/experiments/refund-cakeml-20261104/cakeml/`.
BK = branch `origin/backup/forge-local-2026-11-11`, path `proposals/refund-executable-feasibility/`.

Every statement marked CANDIDATE is not proved and has not been run.

## 1. The claim as it is

### 1.1 Stored statements (quoted exactly)

`refund_profile_a_sl` (E4 lines 240–265):
```
⊢ refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
  refund_heap_clear_sl sl h e ∧
  envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
  refund_env_ok_sl sl envmc ∧
  stdin_content fs =
  SOME
    (explode
       (sexp_to_string
          (refund_request charge request original remaining enabled opened
             candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
  ∃ms.
    (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    (∀j ms' ffi'.
       evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) j
         ms = (TimeOut,ms',ffi') ⇒
       (refund_mc (sl + 0x1000040D0w) envmc).target.get_pc ms' ≠
       (refund_mc (sl + 0x1000040D0w) envmc).install_pc) ∧
    ∃io_events.
      machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs)
        ms ⊆ extend_with_resource_limit {Terminate Success io_events} ∧
      extract_fs ext (cl,fs) io_events =
      SOME
        (add_stdout (fastForwardFD fs 0)
           (refund_render_fields
              (refund_fields charge request original remaining enabled opened
                 candidate amount reason)))
```

`refund_profile_a_sl_every_machine_run` (E4 lines 298–331): the same 11 premises, and:
```
  ∃ms.
    (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    (∀b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc)
           (basis_ffi ext cl fs) ms b ⇒
         (∃io.
            b = Terminate Success io ∧
            extract_fs ext (cl,fs) io =
            SOME
              (add_stdout (fastForwardFD fs 0)
                 (refund_render_fields
                    (refund_fields charge request original remaining enabled
                       opened candidate amount reason)))) ∨
         ∃io io'.
           b = Terminate Resource_limit_hit io' ∧ io' ≼ io ∧
           extract_fs ext (cl,fs) io =
           SOME
             (add_stdout (fastForwardFD fs 0)
                (refund_render_fields
                   (refund_fields charge request original remaining enabled
                      opened candidate amount reason)))) ∧
    (∃b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc)
           (basis_ffi ext cl fs) ms b) ∧
    ¬machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs)
      ms Fail
```

`refund_profile_a_sl_abstract_env` (E4 lines 266–294): the premises without `refund_env_ok_sl sl envmc`
(10 conjuncts), and the conclusion of `refund_profile_a_sl` with every `refund_mc (sl + 0x1000040D0w) envmc`
replaced by `refund_mc (sl + 0x1000040D0w) (refund_abs_env envmc)`. It is the instance of
`refund_profile_a_sl` at `refund_abs_env envmc`, with `refund_abs_env_is_ok_sl` (E4 line 212:
`⊢ refund_env_ok_sl sl (refund_abs_env envmc)`) discharging the premise (E4P lines 181–183).

Definitions the premise P7 unfolds to (E4 lines 63–80 and 151–156):
```
refund_env_ok_sl sl envmc ⇔
    interference_ok envmc.next_interfer
      (arm8_target.proj envmc.prog_addresses) ∧
    refund_ffi_contract_at (sl + 0x1000040D0w) envmc.prog_addresses
      envmc.ffi_interfer

refund_ffi_contract_at b dm ffi_i ⇔
    ∀k index new_bytes ms2 t1 bytes bytes2.
      index < 4 ∧ t1.mem_domain = dm ∧
      read_bytearray (ms2.REG 0w) (w2n (ms2.REG 1w))
        (λa. if a ∈ dm then SOME (ms2.MEM a) else NONE) = SOME bytes ∧
      read_bytearray (ms2.REG 2w) (w2n (ms2.REG 3w))
        (λa. if a ∈ dm then SOME (ms2.MEM a) else NONE) = SOME bytes2 ∧
      LENGTH new_bytes = LENGTH bytes2 ∧
      target_state_rel arm8_target (t1 with pc := b − n2w ((3 + index) * 16))
        ms2 ∧ aligned 2 (t1.regs 30) ⇒
      arm8_ok (ffi_i k (index,new_bytes,ms2)) ∧
      (ffi_i k (index,new_bytes,ms2)).PC = t1.regs 30 ∧
      (∀a. a ∈ dm ⇒
           (ffi_i k (index,new_bytes,ms2)).MEM a =
           asm_write_bytearray (t1.regs 2) new_bytes t1.mem a) ∧
      ∀r. MEM r [19; 20; 21; 22; 23; 24; 25; 27; 28] ⇒
          (ffi_i k (index,new_bytes,ms2)).REG (n2w r) = t1.regs r
```
FFI index order (E4P line 83): 0 = `read`, 1 = `write`, 2 = `close`, 3 = `open_in`. Stub PC = `b − 16(3+index)`:
read `b−48`, write `b−64`, close `b−80`, open_in `b−96`. `b−32` is `cake_install`, `b−16` is `cake_exit` = `halt_pc`
(layout from `CK/compiler/backend/arm8/export_arm8Script.sml` lines 82–115: stubs in reverse name order, then
`cake_install`, `cake_exit`, `cake_main`; my reading, not a stored theorem).

Closure (E4 lines 410–416): 17 stored theorems, 542 theory nodes, axioms only `SELECT_AX`, `INFINITY_AX`,
`ETA_AX`, `BOOL_CASES_AX`. Replayed with exit 0 and equal exports on rebuilt tools, same machine (M1R-1).

### 1.2 Every assumption, explicit

Where: PREMISE (P1–P11 of the ledger `reports/I3-I4b-premise-ledger.md`), DEFINITION (built into a constant
of the statement), CONCLUSION-SHAPE, or NOWHERE (needed for any claim about the real process; not in HOL).
Decisions: `proposals/m1-owner-review-20261119/OWNER_DECISIONS.md` text 1 (Q1–Q6), Profile A rows of
`REVIEW_PACKET.md` §2, assumptions A1–A10 of `BK/m1-profile-a-statement-20261116/M1_PROFILE_A_RESTRICTED.md`.

| Group | Item | Where | Owner decision |
|---|---|---|---|
| FFI | Oracle `basis_ffi ext cl fs` (= `basis_ffi_oracle ext`, `CK/basis/basis_ffiScript.sml` 19–99; read/write/close/open_in answered by `fsFFI` without `ext`) | DEFINITION | Q1 (Profile A row 1, A9) |
| FFI | Model `write` (`fsFFIScript.sml` 214–230, 333–348): writes `MIN n (LHD numchars)` bytes; NO error outcome on a valid write descriptor; error only if the do-block fails | DEFINITION | Q1. Real `write` errors (`EPIPE`, `ENOSPC`, `EINTR`, `EIO`) are covered by NO decision (Q2 covers reads only) |
| FFI | Model `read` (`fsFFIScript.sml` 187–197, 307–323): `MIN n (MIN (len−off) (SUC strm))` bytes, no error on fd 0 | DEFINITION | Q1, Q2 (read errors excluded) |
| FFI | `ffi_interfer` all-states contract `refund_ffi_contract_at` | PREMISE P7 conjunct 2 | Q3b accepts ONE named simulation assumption. The literal all-states contract is NOT that assumption and is probably false for the real C code (U393, U409; analysis, not a theorem). Not approved in this form |
| FFI | Callee-saved set x19–x25, x27, x28; x26, x18, x31 excluded (avoid_regs `[18; 26; 31]`, E4 line 93, E4P line 81) | inside P7 | Q3b |
| FFI | libSystem/kernel call relations (`close_call_rel` U394, `write_call_rel` U397/U398) | NOWHERE in the final theorem (side theorems only) | Q3b (inside A3) |
| FFI | OS conformance: the kernel answers exactly as `basis_ffi` for some `fs` (stdin content, `numchars` = real partial counts) | NOWHERE | Q3b (A3, "NOT formalized"), Q2 |
| FFI | The C stack and libSystem writes stay outside `prog_addresses` | NOWHERE (U393 obligation) | Q3b implicitly; not stated |
| FFI | `SCTLR_EL1.A` clear on return (needed for the real `ffiwrite` success path, U398) | NOWHERE in the final closure | none |
| FFI | `install_interfer` | free field of `envmc`; installer exclusion is a CONCLUSION | none needed |
| Loader | dyld, `_main`, `cml_init_memory` (malloc of heap+stack), `cml_init_eval`, then `cml_main` (`CK/basis/basis_ffi.c` 883–890) reach a state with `refund_entry_pre_sl` | NOWHERE; P1 assumes the result | Q3a |
| Loader | `slide_ok sl` (aligned 12, no wrap) | inside P1 | Q3a. Whether real macOS slides meet it: not determined |
| Loader | Real `argv` equals the model `cl`; `wfcl cl` | P9; the equality is NOWHERE | Q1 row 4 (wfcl); equality: Q3b/A3 |
| Memory | Domain `prog_addresses = refund_mem_dm_sl sl h e` (code ∪ heap ∪ bitmaps) | PREMISE P6 (a model choice) | Q3a (A2) |
| Memory | Heap/stack slots, `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h`, `refund_heap_clear_sl` | P1–P5 | Q3a |
| Memory | Image bytes `refund_image_mem sl s.MEM`: only `TAKE 163840 refund_file` and `TAKE 20248 (DROP 180248 refund_file)` | inside P1 | Q3c (conditional; second independent extraction NOT DONE) |
| Memory | `refund_file` = the bytes of `b8ed5ec2…7bb8` (ML BinIO reader; SHA round trip outside HOL) | DEFINITION | Q3c |
| Memory | `__DATA`/GOT binds, `__LINKEDIT`, dyld shared cache, `libSystem` bytes | NOWHERE (V report M1) | none |
| Processor | L3 ARMv8 next-state (`arm8_run`, `arm8_target.next`) | DEFINITION | Q1 row 10 (A5) |
| Processor | EL0, no exception, `¬E0E`, `¬SA0`, `¬TBI0`, `¬TBI1` | inside P1 | Q3a |
| Processor | `interference_ok envmc.next_interfer (arm8_target.proj …)`: nothing changes PSTATE, SCTLR_EL1, TCR_EL1, exception, REG, PC, bytes in dm between steps (U392 `interference_ok_arm8_iff`) | PREMISE P7 conjunct 1 | Q1 row 9 (A4). Q3b does not cover it |
| Resource | `extend_with_resource_limit`: a Resource_limit_hit stop with a prefix of events is allowed | CONCLUSION-SHAPE; no resource premise | Q5 ("do not claim resource safety"), A10 |
| Resource | Clock: `machine_sem` is over all clocks `k`; no time bound; Diverge excluded by the conclusion | CONCLUSION-SHAPE | none needed |
| Input | `stdin_content fs = SOME (explode (sexp_to_string (refund_request …)))` | P8 | Q1 row 5, Q5 (absent stdin excluded) |
| Input | `wfFS fs` (incl. `liveFS`: live `numchars`) | P10 | Q1 row 4 |
| Input | `STD_streams fs` (fd 0 ReadMode stdin, fd 1/2 WriteMode at end of their inodes) | P11 | Q1 row 4 |
| Input | `ext` free (universal) | — | none needed |
| Output | `extract_fs ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out)`: replaying the model event list on the fs MODEL gives the initial fs with stdin fast-forwarded and `out` appended to the stdout inode. On Success this also fixes stderr and other inodes as unchanged IN THE MODEL | CONCLUSION | — |
| Output | It does NOT say: which bytes a real `write(2)` passed to the kernel; anything about real partial or failed writes (only the model `numchars` split); the process exit status; flushing; that `stdout_of io` (bytes of this run's successful fd-1 writes) equals `out` (the initial stdout inode content is arbitrary; that equality is a missing lemma) | NOWHERE | Text 3 point 3 asks for it; no decision covers it |
| Exit | Model: at `halt_pc`, `x0 = 0w` gives `Halt Success`, else `Halt Resource_limit_hit` (`CK/compiler/backend/semantics/targetSemScript.sml` 145–147). Real: `cake_exit: b cml_exit` → `exit(arg)` with `int arg` = low 32 bits of x0; status = low 8 bits (`basis_ffi.c` 721–742). The compiler uses x0 ∈ {0, 1, 2} (`stack_removeScript.sml` 57, 330–331; `stack_allocScript.sml` 469, 507: my reading, no theorem) | NOWHERE | none |
| Exit | `cml_exit` may print to stderr when `STDERR_MEM_EXHAUST` is defined; build flags not determined | NOWHERE | none |

## 2. Two labels

**(a) Verified machine-model behaviour.** Exact sentence: *The HOL4 kernel has checked (closure axioms: the four
of `bool`) that for every slide `sl` with `slide_ok sl`, every L3 ARMv8 state `s` satisfying `refund_entry_pre_sl sl s h
stk e` (the two slices of `refund_file` mapped at `sl`, EL0 flags, heap slots) with the heap premises, every
machine-configuration record `envmc` with `prog_addresses = refund_mem_dm_sl sl h e` that satisfies
`refund_env_ok_sl sl envmc`, and every `basis_ffi` file-system model `fs` with `wfFS`, `STD_streams` and standard-input
content equal to the canonical text of the nine fields, the CakeML target-semantics machine `refund_mc (sl +
0x1000040D0w) envmc`, started in the state that 27 L3 steps reach from `s`, has a behaviour, never fails, never
reaches the installer entry, and each of its behaviours is either `Terminate Success io` whose replay on the
file-system model appends `refund_render_fields (refund_fields …)` to the stdout inode and fast-forwards stdin, or
`Terminate Resource_limit_hit io'` where `io'` is a prefix of such an `io`.* It is a statement about a mathematical
machine. Its only real-world input is the byte content of `refund_file`.

**(b) Verified native execution.** A theorem whose conclusion is about runs of the real process: *for every run of
the file `b8ed5ec2…7bb8` as a macOS arm64 process, under named environmental assumptions E, if the process exits
then (exit status 0 and the bytes the kernel accepted on fd 1 equal the rendering) or (exit status ≠ 0 and those bytes
are a prefix of it).* It needs the relation of §3 between the process and the model, either proved from E or taken as
a named premise. With the relation only as a premise, the honest label is "machine-model behaviour plus a named
native-simulation assumption" (that is M1-A wording at most; the owner's text 2 phrase "exact machine-code
behavior" is (a)). Label (b) is reached by NO record.

### 2.1 Sentences on `main` (`8e772b55`) that read as (b), with corrections

1. `README.md:102`: "For one refund program, HOL4 model theorems connect the exact ARM64 code to the decision
   definition under explicit premises". Problem: the link from the real process to the model is not one of the
   premises; it has no HOL statement. Correct: "For one refund program, HOL4 theorems show that a machine model
   holding the exact ARM64 code bytes, under explicit premises, produces output equal to the decision definition.
   Nothing formal links the real process to that model: that link is an informal assumption (A3), and the FFI premise
   of the theorem is probably false for the real C code (U393)."
2. `proposals/m1-owner-review-20261119/REVIEW_PACKET.md:20–22`: "One refund decision program was written in the Dafny
   subset that CakeML reads, compiled by the proved CakeML compiler to ARM64 code". Wrong provenance (V finding H4).
   The working tree has a correction; `main` does not. Correct: as the working-tree text (HOL functions → CakeML
   translator → proved compiler).
3. `REVIEW_PACKET.md:22–24`: "HOL4 theorems connect that exact code, in a machine model and under explicit premises, to
   the output `refund_render_fields (refund_fields …)`." Correct: add "The real executable is linked to that model
   only by an assumption with no HOL statement; the theorem's FFI premise `refund_env_ok_sl` is probably false for the
   real C code."
4. `REVIEW_PACKET.md:29–31`: "The executable already exists and runs. Closing M1 builds no new binary. It turns 'a
   program with a proof chain that has open ends' into 'a program with a stated, approved and replayed claim'."
   Correct: "… into 'a machine-model theorem about the program's code bytes, with an approved list of assumptions,
   replayed'. A claim about the running executable needs the native-simulation relation, which is not stated in HOL."
5. `REVIEW_PACKET.md:46` row 6: "the machine state satisfies `installed`". Stale: `installed` is derived; the
   assumption is `refund_entry_pre_sl` plus P2–P7. Correct: "the state at `cml_main` satisfies `refund_entry_pre_sl`
   and the heap and domain premises".
6. `proposals/forge2-m1-conformance/REPORT.md:126`: "The M1 theorems cover canonical inputs." Correct: "The M1 model
   theorems speak of the model machine with canonical standard input; they say nothing formal about any run of the
   physical executable."
7. `REPORT.md:217–220`: "The M1 side is the physical executable on this Mac. Its link to the HOL definition is: the M1
   model theorems (open premises), the 22 HOL-written fixtures that it reproduces, and nothing else from this test."
   Correct: "… Its link to the HOL definition is: the 22 HOL-written fixtures that it reproduces (a finite test). The M1
   model theorems are about a model machine; they reach the physical executable only through an informal
   simulation assumption."
8. `REPORT.md:258`: "the CakeML basis C code `basis_ffi.c`, `libSystem`, the kernel: one simulation assumption
   (Profile A, NOT approved)". Correct: "… one simulation assumption (Q3b, accepted 2026-11-19) with no HOL statement.
   The theorem itself assumes `refund_env_ok_sl`, an all-states FFI contract that the real C code probably does not
   meet (U393)."
9. `REPORT.md:259`: "S-expression reader, part of the proved program". Correct: "S-expression reader, part of the
   program; proved in the model only for the canonical text (premise P8)."
10. `FORGE_MASTER_IDEA.md`: no sentence found that claims (b). Line 179 ("the M1 stdout bytes equal the rendering …")
    is labelled a finite test. `README.md:8` ("Each accepted artifact carries evidence that is tied to its exact
    bytes") is a general overstatement (V finding L6), not M1-specific.

## 3. The missing relation

### 3.0 Why the stored contract cannot be met by the real C code

**Smallest counterexample (U393 finding; U394 step theorem `zero_alen_reaches_assert_block`).** Index 2 (`close`).
Call state `ms2` at PC `b − 80` with `x1 = 0w` (clen 0) and `x3 = 0w` (alen 0), `aligned 2 (t1.regs 30)`,
`target_state_rel` holding. Both `read_bytearray` calls read 0 bytes, so they give `SOME []` for every domain: `bytes =
bytes2 = []`, and `new_bytes = []` meets `LENGTH new_bytes = LENGTH bytes2`. The contract then demands: `arm8_ok`,
PC = x30, memory in dm unchanged (`asm_write_bytearray x2 [] t1.mem = t1.mem`), x19–x25, x27, x28 kept. Real
`fficlose` (`basis_ffi.c` 191–197): `assert(alen >= 1)` fails first; `__assert_rtn` → `abort()`; it never returns.
Machine level (U394): from the entry, 6 steps reach 0x1000252A4, a call into the unmodelled assertion block.
So `ffi_interfer := (faithful model of the real fficlose)` falsifies `refund_ffi_contract_at`. Same class: `write`
with `x1 ≠ 8` (`assert(clen == 8)`), `read` with `x1 ≠ 8`, `open_in` with `alen < 9`.

**Second class (my analysis, not in U393).** The contract quantifies over every `new_bytes` of the right length. A model
of the C function as a function of the machine state alone writes its own result bytes, so it fails the contract
whenever `new_bytes` differs. A faithful model must take the OS answer from `new_bytes` (the oracle's answer), and the
native assumption must say that the real kernel answered what the oracle says. This is the OS-conformance part of A3.

### 3.1 Option A: the conditional form (CANDIDATE, not proved, not run)

Observation type for one real run (supplied from outside HOL; a trace of the four FFI calls, the exit status and the
bytes the kernel accepted on fd 1):
```
Datatype:
  ncall = <| nidx : num ; nconf : word8 list ; nbefore : word8 list ; nafter : word8 list |>
End
Datatype:
  nrun = <| ncalls : ncall list ; nexit : num option ; nstdout : word8 list |>
End
(* nexit = NONE: the process did not exit (signal, kill, no observation) *)

Definition ncall_event_def:
  ncall_event c = IO_event (EL c.nidx [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»])
                           c.nconf (ZIP (c.nbefore, c.nafter))
End

(* bytes this run appended through successful fd-1 write events *)
Definition stdout_of_def:
  stdout_of [] = [] ∧
  stdout_of (IO_event (ExtCall n) conf bs :: rest) =
    (if n = «write» ∧ w82n conf = 1 ∧ LENGTH conf = 8 ∧ LENGTH bs ≥ 4 ∧ SND (HD bs) = 0w then
       let pre = MAP FST bs; nw = w22n [SND (EL 1 bs); SND (EL 2 bs)];
           off = w22n [EL 2 pre; EL 3 pre] in TAKE nw (DROP (4 + off) pre)
     else []) ++ stdout_of rest ∧
  stdout_of (_ :: rest) = stdout_of rest
End

Definition native_matches_def:
  native_matches (Terminate Success io) p ⇔
      MAP ncall_event p.ncalls = io ∧ p.nexit = SOME 0 ∧ p.nstdout = stdout_of io ∧
  native_matches (Terminate Resource_limit_hit io) p ⇔
      MAP ncall_event p.ncalls = io ∧ (∃c. p.nexit = SOME c ∧ c ≠ 0) ∧ p.nstdout = stdout_of io ∧
  native_matches _ p ⇔ F
End

Definition native_refines_def:
  native_refines sl envmc (cl, fs) s p ⇔
    ∀ms. arm8_run 27 s = SOME ms ⇒
      ∃b ext. machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) ms b ∧
              native_matches b p
End
```
CANDIDATE theorem (Option A):
```
refund_native_conditional:
  [the 11 premises of refund_profile_a_sl, with envmc and fs] ∧
  native_refines sl envmc (cl, fs) s p ⇒
    (p.nexit = SOME 0 ∧ p.nstdout = MAP (n2w ∘ ORD) (refund_render_fields (refund_fields …))) ∨
    (∃c. p.nexit = SOME c ∧ c ≠ 0 ∧ p.nstdout ≼ MAP (n2w ∘ ORD) (refund_render_fields (refund_fields …)))
```
It follows from `refund_profile_a_sl_every_machine_run` plus two MISSING lemmas:
(L-OUT) `extract_fs ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ∧ STD_streams fs ⇒ stdout_of io =
MAP (n2w ∘ ORD) out` (plus prefix monotonicity of `stdout_of`); (L-EXIT) real exit status = `w2n x0 MOD 256` and
`x0 ∈ {0w,1w,2w}` at `halt_pc` (without it, `x0 = 256w` would be Resource_limit_hit in the model and exit status 0 in the
process; the compiler uses only 0, 1, 2 by my reading, no theorem). In `native_matches`, the exit clauses are
themselves the native half of L-EXIT.

What the relation must contain to be TRUE of real runs (the content of A3, per FFI name):
- **write (index 1)**: reachable (source inspection U397; model theorem U399/U400 for a terminating run). At reachable
  successful events: `x1 = 8` (conf = fd 1 in 8 bytes) and `n + off + 4 ≤ w2n x3` (U400
  `refund_terminating_run_reaches_valid_write_call`, model only). Real path: stub → `ffiwrite` (23 steps) →
  `write(fd, &a[4+off], n)` → 6 or 10 steps back (U397, U398 under `write_call_rel`, `¬SCTLR_EL1.A`). The kernel must
  accept exactly `TAKE nw` of the buffer, and `nw` must equal the model's `MIN n (LHD numchars)` for the chosen `fs`.
  A real error (`nw < 0`) must be either absent or mapped to the model's failed event; the model has no failed write on
  fd 1 when `STD_streams` holds, so a real write error is OUTSIDE any true relation (no owner decision covers it).
- **read (index 0)**: reachable (`inputAllFrom` on stdin). Needs `x1 = 8`, conf = fd 0, `alen ≥ n + 4`. Call-site
  arguments for read are NOT established in the M1 chain (not found). Real errors excluded by Q2.
- **close (index 2)**, **open_in (index 3)**: not reachable by source inspection (U396; `refund_main` uses
  `inputAllFrom None` and `print`). No formal unreachability proof. The relation must then say "no such call".
- **entry**: dyld → `main` → `cml_init_memory` → `cml_init_eval` → `cml_main` gives a state satisfying
  `refund_entry_pre_sl sl s h stk e` with `h = cml_heap`, `e = cml_stackend` (Q3a).
- **exit**: `cake_exit: b cml_exit` → `exit((int)x0)`; nothing between halt and exit changes the stdout bytes.
- **between FFI calls**: each instruction executes as L3 at EL0; nothing observable changes (`interference_ok`).
- **memory**: libSystem and the C stack touch nothing in `prog_addresses` except the result array.

### 3.2 Option B: the weakened premise (CANDIDATE replacement for `refund_env_ok_sl`)

```
Definition refund_ffi_contract_on_def:
  refund_ffi_contract_on b dm (V : num -> word8 list -> arm8_state -> bool) ffi_i ⇔
    ∀k index new_bytes ms2 t1 bytes bytes2.
      [the eight hypotheses of refund_ffi_contract_at b dm ffi_i] ∧ V index new_bytes ms2 ⇒
      [the four conclusions of refund_ffi_contract_at b dm ffi_i]
End
Definition refund_ffi_tot_def:
  refund_ffi_tot V f k (index, new_bytes, ms) =
    if V index new_bytes ms then f k (index, new_bytes, ms) else refund_abs_ffi k (index, new_bytes, ms)
End
Definition refund_env_ok_reach_def:
  refund_env_ok_reach sl envmc V cl fs ms ⇔
    interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧
    refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses V envmc.ffi_interfer ∧
    (* V holds at every FFI call state reachable in the TOTALISED machine, with the oracle's new_bytes *)
    refund_calls_valid V (refund_mc (sl + 0x1000040D0w)
                            (envmc with ffi_interfer := refund_ffi_tot V envmc.ffi_interfer))
                         (basis_ffi ext cl fs) ms
End
```
A faithful model `f` of the real C code (stub + C path + an assumed libSystem call relation, taking the OS answer from
`new_bytes`) can satisfy conjunct 2 with `V` = "index ∈ {0,1}, `x1 = 8w`, length bounds, and `new_bytes` of the oracle's
shape". Conjunct 3 is a property of the model (provable in HOL; U405 L3), not of the real code.

What must change in the stored proof (U405 L1–L3; `compile_correct'` and the stored lemmas stay unchanged):
- Consumers of the all-states form: `ffi_interfer_ok_iff_contract_sl` and `refund_env_ok_sl_iff_installed_residual`
  (E4 lines 146–167) → `refund_installed_rest2` → `refund_installed_no_handler` → `refund_behavior_valid_request_no_handler`
  and `refund_u298_exclusion_valid_request` (U387; both through `installed`, which contains `ffi_interfer_ok`, a
  premise of `backendProof.compile_correct'`). They are applied UNCHANGED to the totalised record.
- New: L1 `refund_ffi_contract_on b dm V f ⇒ refund_ffi_contract_at b dm (refund_ffi_tot V f)` (§5);
  L2 clock-wise agreement `evaluate` (real-effect record) = `evaluate` (totalised record) when every reachable call
  satisfies V (reachability taken in the totalised machine, so not circular; U405 soundness note);
  L3 V at reachable calls per name (write: 12 residual conjuncts and the failed-write event invariant open, U400/U401;
  read: not started; close/open_in: unreachability not proved);
  the faithful `f` per reachable name (write: U397/U398 path theorems; read: not started).
- Then `refund_profile_a_sl` for the real-effect record follows from the stored theorem at the totalised record + L2.

## 4. What the candidate theorem would still NOT say

Even with Option A proved from Option B: nothing about the physical processor (L3 is a model; errata, caches, Device
memory, `SCTLR_EL1.A` at run time), the macOS kernel (scheduling, signals, `write`/`read` semantics, errors other than
those excluded), dyld (mapping, slide, GOT binds of `close`/`write`/`read`), `libSystem` (`write`, `read`, `close`,
`exit`, `abort`, `malloc`), the C run-time before `cml_main`, the `__DATA`/`__LINKEDIT` bytes, the code signature, or
anything the caller does with the bytes. The relation `native_refines` stays an assumption about those parts; only its
consequence is proved.

## 5. Next independently checkable proof obligation (CANDIDATE; NOT RUN)

One statement (U405 L1 at the relocated base; same proof pattern as the stored `stub_guard_ffi_satisfies_contract_at_its_base`,
E4P lines 144–150):
```
Theorem refund_ffi_contract_on_totalises:
  ∀b dm V f. refund_ffi_contract_on b dm V f ⇒ refund_ffi_contract_at b dm (refund_ffi_tot V f)
```
with the two definitions of §3.2, and the corollary
```
Theorem refund_env_ok_sl_of_contract_on:
  interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧
  refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses V envmc.ffi_interfer ⇒
  refund_env_ok_sl sl (envmc with ffi_interfer := refund_ffi_tot V envmc.ffi_interfer)
```
- Parents: `forge_refundSlideProfileA` (`refund_ffi_contract_at_def`, `refund_env_ok_sl_def`, `refund_abs_ffi_contract_at`)
  and `forge_refundEnvModel` (`refund_abs_ffi_def`, `refund_bad_return_ffi_def`, `refund_ffi_witness_state_def`,
  `arm8_target_state_rel_facts`). Existing heaps; expected minutes.
- Positive sanity: `refund_ffi_contract_on b dm (λi nb ms. T) f ⇔ refund_ffi_contract_at b dm f`.
- Negative control (must be PROVED as a negation; the run fails if it is not): the totalisation is needed:
  `¬(∀b dm V f. refund_ffi_contract_on b dm V f ⇒ refund_ffi_contract_at b dm f)`, witnessed by
  `V = (λi nb ms. F)`, `f = refund_bad_return_ffi`, `b = 0x1000040D0w`, the state
  `refund_ffi_witness_state with PC := 0x1000040A0w` (the tactic of `slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000`).
- Counterexample control: with `V_close i nb ms ⇔ (i = 2 ⇒ ms.REG 1w = 8w ∧ ms.REG 3w ≠ 0w)`, the §3.0 state is
  excluded: `¬V_close 2 [] (ms with REG := (λr. if r = 3w ∨ r = 1w then 0w else ms.REG r))`.
- Checks: tag check (DISK_THM only), closure axioms = four of `bool`, exact-statement print.
Honest scope: L1 alone moves nothing about the real process. It makes the stored chain usable with a premise that a
model of the real C code can meet. L2 is the next and larger step.

## 6. Effort (unit = 65 recorded M1 entries, U345–U409)

L1 + controls: 1 entry. L2 (generic agreement, induction on the clock): 3–8. L3 write (12 conjuncts, failed-write
invariant, source-level event invariant): 10–25. read path and call-site facts (as U397–U400 for write): 6–12. Formal
non-reachability of close/open_in: 2–6. L-OUT: 2–4. L-EXIT (x0 ∈ {0,1,2} at `halt_pc`, not exported by
`compile_correct'`): 3–15. Total about 27–71 entries = 0.4–1.1 units; with my uncertainty, 0.3–2 units. This reaches
Option A with `native_refines` still an ASSUMPTION; label (b) is not reachable by HOL work alone.

## 7. Not determined

Read call-site arguments in the stored chain (not found); the `iobuff` size; whether macOS slides satisfy `slide_ok`;
`STDERR_MEM_EXHAUST`/`DEBUG_FFI` build flags of the linked `basis_ffi.o`; whether the real C stack lies outside
`refund_mem_dm_sl`; whether `x0 ∈ {0,1,2}` at every halt of the compiled code; whether the 128 KiB witness heap is
enough for Success (H1).

## 8. Links for the top-level graph (claim-statement area)

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| approved contract (R1–R5, Dafny) | HOL functions (`eligible_def`, `refund_fields`) | none (18-row matrix A8, NOT REVIEWED) | TESTED-UNPROVED | Wave Gate 1, `proposals/forge2-m1-conformance/REPORT.md` (2,466 vectors, compiled Dafny vs executable) | machine-checked correspondence (Q4); outside step B1 |
| HOL functions | CakeML code | translator certificate theorems (`translate eligible_def; translate refund_fields_def`, forge_refundCertifiedProg / forge_refundWireProg) | MACHINE-CHECKED | HOL4 kernel; M1R-1 replay (95 theories, equal exports); V report H4 | clean and independent replay |
| CakeML code | machine code bytes in the model | `backendProof.compile_correct'` instance (C32 source-0006, C34 real-0004) | MACHINE-CHECKED | HOL4; `R/summary.json` C32, C34 exit 0, `R/comparison.json` equal | clean and independent replay |
| file `b8ed5ec2…` | `refund_file` / `refund_image_mem` | `refund_file` defined from BinIO bytes; SHA round trip outside HOL; offsets from Python | ASSUMPTION | Q3c (conditional; second extraction NOT DONE) | second independent extraction; in-HOL Mach-O check |
| machine model at `cml_main` | machine-model output | `refund_profile_a_sl`, `refund_profile_a_sl_every_machine_run` | MACHINE-CHECKED | HOL4; E4 lines 240–331; M1R-1 | replays; premise P7 replaced (Option B) |
| real C FFI code | premise `refund_env_ok_sl` | `refund_ffi_contract_at` (all call states) | ASSUMPTION | not approved in this form (Q3b approves one simulation assumption, not this predicate); U393/U409: probably false | Option B + L1–L3 (§3.2, §5) |
| native process (dyld, crt, `main`) | entry state `refund_entry_pre_sl` | none in HOL | ASSUMPTION | Q3a | loader model; not planned |
| native process | machine model (`native_refines`, A3) | none | MISSING | `M1_PROFILE_A_RESTRICTED.md` A3 "NOT formalized" | write it as a named HOL premise (§3.1); then prove what can be proved (Option B) |
| physical processor / OS between steps | L3 + `interference_ok` | `interference_ok` (P7 conj 1); L3 definitions | ASSUMPTION | Q1 rows 9, 10 | none in scope |
| libSystem/kernel calls | `basis_ffi` oracle answers | none (`close_call_rel`, `write_call_rel` only in side theorems) | ASSUMPTION | Q3b, Q2 (read errors); write errors: not approved | none in scope |
| model events `io` | stdout bytes of this run | none (L-OUT) | MISSING | — | prove L-OUT (§3.1) |
| model `Halt` outcome | process exit status | none (L-EXIT) | MISSING | — | prove x0 ∈ {0,1,2} at `halt_pc`; native half stays ASSUMPTION |
| native process | output bytes observed | 22 HOL fixtures + 2,466 vectors equal | TESTED-UNPROVED | Wave Gate 1 (R-STDOUT, conformance run exit 0) | the links above |
| output bytes | caller/sink | none (no consumer; V finding H1) | MISSING | — | B-step for the output frame (Text 3 point 3) |

First MISSING link in this area (nearest the approved contract): **native process → machine model** (`native_refines` / A3).
