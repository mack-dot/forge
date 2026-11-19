# Route A, L3: the predicate holds at every reachable call of the refund program (per FFI name)

Status: NO script. Every statement below is a CANDIDATE: NOT ATTEMPTED (not written as HOL, not run), unless it is
quoted from a stored record. Stored = a record shows the theorem with exit 0 (local, one machine, cached parents).

What L3 must give, in the form L2R uses:
```
∀ms k. arm8_run 27 s = SOME ms ⇒
  ffi_calls_ok Vok (refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer))
               (basis_ffi ext cl fs) k ms
```
under the other 10 premises of `refund_profile_a_sl` plus the L1 premises. `ffi_calls_ok` checks `Vok` only at calls
that RETURN (`FFI_return`): a call that the oracle refuses (`FFI_final`) ends the run as `Halt (FFI_outcome _)`, which the
stored theorem already excludes. So `Vok` may use any fact that the oracle's success shape gives for free.

Proposed predicate: `Vok i nb ms ⇔ V_read i nb ms ∧ V_write i nb ms ∧ V_close i nb ms ∧ V_open i nb ms`, each of the
form `i = n ⇒ …`. Each part has two layers: (a) ABORT-FREEDOM: the C `assert`s of `basis_ffi.c` hold; (b) PATH
FACTS: the call-state facts that the step theorems of the C path need (frame placement, alignment, image bytes intact),
e.g. the 12-conjunct `write_call_residual` (U401). Layer (b) is needed by the native side (a faithful `f` meets the
on-form contract only under it), not by L1/L2.

All stored call-site results below are at SLIDE 0 (`refund_static` fixes PCs 0x1000040A0w … 0x100004070w). A slide
version of each is MISSING.

## 1. write (index 1, stub PC b − 64; slide 0: 0x100004090w)

C (`basis_ffi.c` 175–189): `assert(clen == 8)`; `n = a[0..1]`, `off = a[2..3]`; `assert(alen >= n + off + 4)` (signed long).

Stored, U400 (`results/refund-write-args-local-20261116/attempt-0001/args-0006/stdout.log` lines 268–285, theory
`forge_refundWriteArgs`), quoted exactly:
```
refund_terminating_run_reaches_valid_write_call
⊢ (is_arm8_machine_config mc0 ∧
   refund_installed_no_handler mc0 ms cbspace data_sp ∧
   stdin_content fs =
   SOME
     (explode
        (sexp_to_string
           (refund_request charge request original remaining enabled opened
              candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧
   STD_streams fs) ∧ refund_static mc0 dm ∧
  machine_sem mc0 (basis_ffi ext cl fs) ms (Terminate Success io') ⇒
  EXISTS write_ok_event io' ∧
  ∃mc1 ffi1 ms1.
    machine_reach mc0 (basis_ffi ext cl fs) ms mc1 ffi1 ms1 ∧
    ms1.PC = 0x100004090w ∧ ms1.REG 1w = 8w ∧
    w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] +
    w22n [ms1.MEM (ms1.REG 2w + 2w); ms1.MEM (ms1.REG 2w + 3w)] + 4 ≤
    w2n (ms1.REG 3w)
```
It says: in a terminating successful run there EXISTS one reachable write call with `x1 = 8` and the bound. The more
general stored lemma is `successful_write_events_have_valid_call_states` (same log, 254–265): EVERY successful write event
(`write_ok_event e ⇔ ∃c x bs. e = IO_event (ExtCall «write») c ((x,0w)::bs)`) of any finite run of a `refund_static`
machine with the basis oracle comes from a reachable call state with `x1 = 8w` and the bound. And U401
`all_successful_trace_gives_valid_call_state_per_write_event` (`forge_refundWriteWord`, word-0003 lines 293–358): the
same for every write event, IF every write event of the trace is successful.

Limit (U400/U401 records): SUCCESSFUL write events only. A failed write event (answer `1w :: …`) leaves the file system
unchanged (`failed_write_event_keeps_fs`, `replay_ignores_failed_write_with_valid_clen`), so the `extract_fs` equation
cannot exclude it. In the model, `ffi_write` with `LENGTH conf ≠ 8` or an out-of-bounds offset RETURNS an error event
(`wrong_clen_write_never_succeeds`, `out_of_bounds_write_never_succeeds`): a silent failure, while the C code aborts.
`¬word_msb x3` is not derived (U401: "NOT derived").

MISSING statement (failed write events), candidate:
```
refund_run_write_events_all_succeed:   (NOT ATTEMPTED)
  [the 11 premises of refund_profile_a_sl, any record envmc with refund_env_ok_sl sl envmc] ⇒
  ∃ms. arm8_run 27 s = SOME ms ∧
    ∀k r ms' ffi'. evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) k ms = (r,ms',ffi') ⇒
      ∀e. MEM e ffi'.io_events ∧ write_event e ⇒ write_ok_event e
```
With it, U401's conditional lemma gives `x1 = 8w` and the bound at EVERY returning write call. Then
`V_write i nb ms ⇔ (i = 1 ⇒ ms.REG 1w = 8w ∧ w22n [..] + w22n [..] + 4 ≤ w2n (ms.REG 3w) ∧ ¬word_msb (ms.REG 3w))`
at every returning write call needs, in addition, the signed bound (`¬word_msb x3`; the U396 method:
`close_call_alen_below_half` from `refund_mem_dm_below_half`, theory `forge_refundSignedLen`).

How the missing statement could be proved: not from `refund_semantics` (`forge_refundWholeProg`; it fixes only
`extract_fs` of the event list). Two routes:
- (W-a) C-faithful oracle. Define `basis_ffi_c`: the basis oracle, but `write` (and `read`, `close`, `open_in`) answer
  `Oracle_final FFI_failed` whenever the C `assert`s fail. Re-prove the source specification of `refund_main` under the
  stricter FFI part (the CF proofs of `print` / `TextIO.output` call `write` only with the 8-byte `n2w8 fd` and the
  `iobuff` array, so they should go through with the stricter function; not checked). `compile_correct'` is oracle-generic,
  so the stored machine chain re-instantiates. Under `basis_ffi_c`, an invalid write is `FFI_final`, excluded by the
  Success-only conclusion. Then: the `basis_ffi_c` machine and the `basis_ffi` machine answer alike at valid calls, so
  their runs agree (an L2-like oracle lemma). Cost: unknown; it re-opens the CF layer of the basis (large).
- (W-b) An event invariant over the source semantics of the whole program: not feasible by hand (the basis code).

## 2. read (index 0, stub PC b − 48; slide 0: 0x1000040A0w)

C (`basis_ffi.c` 160–173): `assert(clen == 8)`; `n = a[0..1]`; `assert(alen >= n + 4)` (signed long);
`read(fd, &a[4], n)`.

Stored (what exists):
- U348 `ffiread_error_return`: the 6-step error suffix of `_ffiread` on the exact bytes (B2 report, §2.2; "Not covered: the
  ffiread prologue and call ... the read system call; the success path").
- Source/CF level, `forge_refundGenericReadError` (`results/refund-generic-read-local-20261112/attempt-0001/repeat/stdout.log`
  82–97), quoted:
```
read_error_generic
⊢ FD fd fdv ∧ NUM n nv ∧ n < 256² ∧ MAX n 2048 ≤ LENGTH rest ∧
  MEM «read» ns ∧ ¬MEM «» ns ∧
  u «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) s =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) s') ⇒
  app p TextIO_read_v [fdv; nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) * one (FFI_part s u ns events))
    (POSTe e.
       &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
       one
         (FFI_part s' u ns
            (events ++
             [IO_event (ExtCall «read») (n2w8 fd)
                (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))
```
  It shows the SOURCE call shape of `TextIO.read` (conf = `n2w8 fd`, 8 bytes; array `iobuff` with `MAX n 2048 ≤ LENGTH rest`,
  so `alen ≥ n + 4`), for the error answer only. Also `basis_read_error_oracle` (`refund-ffi-oracle-local-20261112`).
- Model oracle (`basis/fsFFIScript.sml`, `ffi_read_def`): fewer than 4 array bytes gives `NONE` (FFI_final); wrong `clen`
  or `n > LENGTH tll` gives an ERROR EVENT (`FFIreturn (LUPDATE 1w 0 bytes) fs`) — a silent failure, while the C aborts.

MISSING: every machine-level read call-site fact (`x1 = 8w`, conf = fd 0 in bytes 4..7 with bytes 0..3 zero,
`alen ≥ n + 4`, `¬word_msb x3`), the `_ffiread` prologue and success path, `read_call_rel`, and the number of read calls.

Smallest first theorem (candidate, NOT ATTEMPTED; the read analogue of the stored U400 step
`successful_write_call_state_has_valid_arguments`, same proof method: `write_call_arrays_are_the_register_arguments`,
which is generic in the FFI name, plus a new `ffi_read_return_cases`):
```
successful_read_call_state_has_valid_arguments:
  refund_static mc1 dm ∧ ffi1.oracle = basis_ffi_oracle ext ∧
  read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) ∧
  call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 (0w::rest) ⇒
  ms1.REG 1w = 8w ∧
  w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] + 4 ≤ w2n (ms1.REG 3w)
```
It is one step, about successful read events. Failed read events have the same gap as write (§1, routes W-a / W-b).
Owner decision Q2 excludes real read errors (EIO, EINTR); it does not make model error events impossible.

## 3. close (index 2, stub PC b − 80; slide 0: 0x100004080w)

C (`basis_ffi.c` 191–197): `assert(alen >= 1)`; `assert(clen == 8)`.

Statement asked for: "no close call is reached for a canonical request". Candidate (NOT ATTEMPTED):
```
refund_run_has_no_close_or_open_in_call:
  [the 11 premises of refund_profile_a_sl] ⇒
  ∃ms. arm8_run 27 s = SOME ms ∧
    ∀k r ms' ffi'. evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) k ms = (r,ms',ffi') ⇒
      EVERY (λe. ∃c b. e = IO_event (ExtCall «read») c b ∨ e = IO_event (ExtCall «write») c b) ffi'.io_events
```
(A returning call appends exactly one event: stored `call_FFI_return_appends_one_event`, `forge_refundWriteReach`. A
refused call is `FFI_final` and is excluded by the stored conclusion. So this event statement is equivalent to "no close or
open_in call is reached".)

No stored theorem fixes the event list. `refund_semantics` (`forge_refundWholeProg`, T08 log 347–366) fixes only
`extract_fs ext (cl,fs) io_events = SOME (add_stdout (fastForwardFD fs 0) (refund_render_fields …))`. That equation CANNOT
exclude close/open_in events: a failed `close` (bad fd) or failed `open_in` (missing file) leaves the file system unchanged
(`ffi_close_def`, `ffi_open_in_def`: error answer, same `fs`), and an `open_in` followed by a `close` of the new fd restores
`infds`. So unreachability needs route W-a (a source specification under an FFI part whose names are only `read` and
`write`, or under the C-faithful oracle) or W-b. Source inspection (U396: `refund_main` uses `inputAllFrom None` and `print`)
is not a proof.

Observation (my reading; for the predicate, close may NOT need unreachability): `ffi_close` returns `FFIreturn` only when
`LENGTH bytes ≥ 1 ∧ LENGTH conf = 8` (stored `ffi_close_accepts_only_valid_lengths`, U394 compose-0018), and
`read_ffi_bytearrays` gives `LENGTH c = w2n x1`, `LENGTH ab = w2n x3` (stored `write_call_arrays_are_the_register_arguments`,
generic in the name). So at every RETURNING close call `x1 = 8w ∧ x3 ≠ 0w`, in one step, without reachability; the stored
U395 `close_call_site_arguments` and U396 `close_call_site_signed_alen` (with `addresses_below_half`) give the same at
reachable calls. Hence the abort-freedom layer of `refund_close_call_valid` (defined in `routeA-L1.sml`) holds at every
call that `ffi_calls_ok` checks, given a signed-bound lemma. The path layer (frame, alignment, image bytes; the
`fficlose_call_pre` conjuncts of U394/U395) still needs reachability facts. Candidate (NOT ATTEMPTED):
```
returning_close_call_is_valid:
  refund_static mc dm ∧ ffi.oracle = basis_ffi_oracle ext ∧ ms.PC = 0x100004080w ∧
  read_ffi_bytearrays mc ms = (SOME c, SOME ab) ∧ call_FFI ffi (ExtCall «close») c ab = FFI_return ffi' nb ∧
  addresses_below_half dm ⇒ refund_close_call_valid 2 nb ms
```
(`addresses_below_half` is the stored predicate of `forge_refundSignedLen`, signed-0006. Its stored source
`refund_mem_dm_below_half` needs `e ≤₊ 0x8000000000000000w`, a NEW premise: the M1 heap premises admit a heap end above
2^63, stored `heap_premises_admit_huge_heap`. The same premise is needed for `¬word_msb x3` at write and read calls.)

## 4. open_in (index 3, stub PC b − 96; slide 0: 0x100004070w)

C (`basis_ffi.c` 138–147): `assert(9 <= alen)`; `open((const char *) c, O_RDONLY)` (reads `c` as a C string; no `clen`
check). Model `ffi_open_in`: `9 ≤ LENGTH bytes` for success; `1 ≤ LENGTH bytes < 9` gives an ERROR EVENT; 0 bytes gives
`NONE`. So, unlike close, the oracle shape does NOT give the C condition at returning calls (`alen ∈ [1,8]` returns in the
model, aborts in C). Needs the unreachability statement of §3 (or a source-level argument fact, route W-a).

## 5. Exit path

Model (`targetSemScript.sml` 138–140): at `halt_pc` (= b − 16 = `cake_exit`), `get_reg ms mc.ptr_reg = 0w` gives
`Halt Success`, else `Halt Resource_limit_hit`; `ptr_reg = 0` for the refund record (stored
`refund_mc_register_fields_sl`). Native (`basis_ffi.c` 721–742): `cake_exit: b cml_exit`; `cml_exit(int arg)` calls
`exit(arg)` (and may print to stderr if built with `STDERR_MEM_EXHAUST` or `DEBUG_FFI`; build flags not determined).
POSIX exit status = `arg & 0xFF` = the low 8 bits of x0.

L-EXIT (model half), candidate, NOT ATTEMPTED:
```
refund_halt_register:
  [the 11 premises of refund_profile_a_sl] ⇒
  ∃ms. arm8_run 27 s = SOME ms ∧
    ∀k t ms' ffi'. evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) k ms = (Halt t,ms',ffi') ⇒
      ms'.PC = sl + 0x1000040C0w ∧
      (t = Success ⇔ ms'.REG 0w = 0w) ∧
      (t ≠ Success ⇒ ms'.REG 0w = 1w ∨ ms'.REG 0w = 2w)
```
The first two conjuncts follow from `evaluate_def` (a `Halt` arises only at `halt_pc` or at `FFI_final`, and the stored
conclusion excludes `FFI_outcome`). The third is NOT exported by `compile_correct'` (it speaks of behaviours, not of x0).
It needs either a compiler-level invariant (the `stack_remove` / `stack_alloc` halt code sets x0 to 1 or 2; my reading of
`stack_removeScript.sml` 57, 330–331 and `stack_allocScript.sml` 469, 507, no theorem) or a byte-level enumeration of every
path into `halt_pc` in the 32,609-word code (indirect branches make this hard). Without it, `x0 = 256w` would be
`Resource_limit_hit` in the model and exit status 0 in the process.
L-EXIT (native half): `exit status = w2n ((7 >< 0) x0)` at `cml_exit`; this stays an ASSUMPTION (libSystem `exit`).

## 6. Output bytes

L-OUT, candidate, NOT ATTEMPTED. With `stdout_of` as defined in `drafts/M1_EXACT_CLAIM.md` §3.1 (the concatenation of the
bytes written by the SUCCESSFUL write events whose conf decodes to fd 1: `TAKE nw (DROP (4 + off) pre)`):
```
refund_extract_fs_gives_stdout_bytes:
  extract_fs ext (cl,fs) io = SOME (add_stdout (fastForwardFD fs 0) out) ∧ STD_streams fs ∧ wfFS fs ∧
  EVERY refund_event io ⇒
  stdout_of io = MAP (n2w ∘ ORD) (explode out)
```
plus `io' ≼ io ⇒ stdout_of io' ≼ stdout_of io` (prefix monotonicity, for the Resource_limit_hit case).
Proof idea: induction over `io` with `extract_fs_with_numchars_def` and the stored `extract_fs_with_numchars_APPEND`
(`basis/basis_ffiScript.sml` 164); invariant: the stdout inode content = initial content ++ `stdout_of` of the prefix;
`STD_streams_def` (`fsFFIPropsScript.sml` 1310–1316) makes fd 1 the only descriptor of the `stdout` inode, so writes to other
fds do not touch it; reads, closes and opens do not change inode contents (stored `ffi_read_keeps_inodes`,
`ffi_close_keeps_inodes`, `ffi_open_in_keeps_inodes`, `forge_refundWriteReach`); the `add_stdout` side needs the
`add_stdo`/`up_stdo` definitions (`TextIOProofScript.sml` 257–261 and nearby). Risk: `add_stdout` is defined with a
Hilbert choice of the initial content (`stdo`), so the lemma must first show the initial stdout content is the one the
choice picks (there are stored `stdo` lemmas in `TextIOProof`; not checked).
Even when proved, L-OUT is about the MODEL event list. That the kernel accepted exactly these bytes stays part of the
native assumption (`write_call_rel` says nothing about output, U398).
