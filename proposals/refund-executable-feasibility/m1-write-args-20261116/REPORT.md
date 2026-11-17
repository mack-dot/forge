# M1 — refund output non-emptiness and the `write` argument gap (U400)

Date: 2026-11-16. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Stage 12 unauthorized. No profile approved.
`end_to_end=false`. Nothing committed. Continues U397, U398, U399.

Run directory: `results/refund-write-args-local-20261116/attempt-0001`.
Theory: `forge_refundWriteArgs` (`args-0006`, exit 0, 27 theorems,
1 definition). Check: `check-0002` (exit 0).

## 1. Strongest proved theorem

`refund_terminating_run_reaches_valid_write_call`. Premises, exact:

1. premises of `refund_behavior_valid_request_no_handler`
   (`is_arm8_machine_config mc0`, `refund_installed_no_handler mc0 ms
   cbspace data_sp`, valid request on standard input, `wfcl`, `wfFS`,
   `STD_streams`);
2. `refund_static mc0 dm`;
3. `machine_sem mc0 (basis_ffi ext cl fs) ms (Terminate Success io')`.

Conclusion: `EXISTS write_ok_event io'`, and there is a reachable MODEL
state `ms1` with `ms1.PC = 0x100004090w`, `ms1.REG 1w = 8w` and

    w22n [MEM x2; MEM (x2+1)] + w22n [MEM (x2+2); MEM (x2+3)] + 4 ≤ w2n x3

(`x2 = ms1.REG 2w`, `x3 = ms1.REG 3w`). The U399 premise "the rendered
output is not `«»`" is gone. No argument fact is assumed.

`refund_reached_valid_write_call_and_path` joins this state with
`write_call_site_facts` and `cake_ffiwrite_path_returns` (U398).

The theorem is conditional. Premises 1–3 are NOT shown satisfiable
together. No refund execution witness exists.

## 2. Rendered-output non-emptiness: PROVED, all fields

`refund_render_fields_not_empty`: `refund_render_fields flds ≠ «»`.
It holds for every field tuple, so for every valid request.

Proof: `refund_render_fields_roundtrip` (published wire theory) says the
parser reads the rendered string back with no rest.
`parse_IMP_LENGTH_LESS` (basis) says a successful parse consumes at least
one character. No `EVAL` of the serializer. The U399 attempt
(`reach-0005`, CPU limit) unfolded the serializer; that was the wrong
method.

Rendering versus emission. The lemma is about a string. It says nothing
about events. An emitted event follows only through the file-system
specification and a run that terminates with `Success`:
`nonempty_output_needs_successful_write_event`.

## 3. Refund `write`-call reachability: conditional, strengthened

- `write_ok_event e`: a `write` event whose first result byte is 0.
- `ffi_write_return_cases`: a returning `ffi_write` either failed
  silently (result `LUPDATE 1w 0 bytes`, file system unchanged) or had
  `LENGTH c = 8` and `n + off + 4 ≤ LENGTH bytes`, with result byte 0.
- `replay_without_successful_write_keeps_inodes`,
  `nonempty_output_needs_successful_write_event`: non-empty output needs
  a SUCCESSFUL `write` event (U399 had: some `write` event).
- `evaluate_trace_write_events_have_call_states`: every `write` event
  `IO_event (ExtCall «write») c bs` in the appended trace has its own
  reachable state at `PC = 0x100004090w` with
  `read_ffi_bytearrays = (SOME c, SOME ab)`, `bs = ZIP (ab, nb)` and the
  same `call_FFI`.
- `successful_write_events_have_valid_call_states` (basis oracle): every
  successful `write` event has a reachable call state with `x1 = 8` and
  the bound above.

Verdict: a refund run that terminates with `Success` reaches a `write`
call state with `clen = 8` and the buffer bound. Model machine only.
"A run reaches the call" stays conditional on termination.

## 4. Remaining successful-termination assumptions

- Premise 3 is NOT discharged. The published theorem gives
  `machine_sem ⊆ extend_with_resource_limit {Terminate Success io}`. A
  resource-limit stop before any call stays admissible.
- Premise 1 (installed state) and premise 2 (`refund_static`) are
  assumed as in U399.
- No terminating refund run is exhibited. The witness of section 7 is a
  constructed state, not a refund run and not a native execution.

## 5. The missing FFI argument invariant

Trace of the arguments (items a–c are text inspection, NOT proofs):

a. Source: `TextIO.writei fd n i` writes `n`, `i` to `iobuff[0..3]`, then
   `#(write) fd iobuff`. `fd` is a string; `FD fd fdv` gives 8 bytes.
   `write`/`output` call `writei` with `i + n` inside `iobuff`.
b. Source semantics: `call_FFI` records
   `IO_event (ExtCall «write») conf (ZIP (bytes, bytes'))`. The event
   holds the configuration bytes, the array and the result. `clen` and
   the bound ARE in the source trace.
c. Where the facts stop: `cfHeapsBase$IO` is
   `SEP_EXISTS events. one (FFI_part s u ns events) * …`. The CF
   specifications (`writei_spec`) speak about `IOFS fs` only.
   `whole_prog_spec_semantics_prog` exports `∃io_events` with
   `extract_fs … io_events = SOME fs'` only. `extract_fs` ignores a
   failed `write` (`replay_ignores_wrong_clen_write_event`, U399).
d. Compiler: the published `compile_correct'` statement relates the same
   trace. It needs no change.
e. Machine (proved here): the event's `conf` and array are the bytes at
   `x0`/`x1` and `x2`/`x3`
   (`write_call_arrays_are_the_register_arguments`,
   `evaluate_trace_write_events_have_call_states`).

What is now derived without that information: the facts for SUCCESSFUL
events, from the result byte in the event and the oracle.

Smallest missing invariant (source level, event level):

    every write event of a refund run has result byte 0
    (EVERY (λe. write_event e ⇒ write_ok_event e) io)

for the traces of `semantics_prog … refund_prog`, including prefixes.
With it, `successful_write_events_have_valid_call_states` gives `x1 = 8`
and the bound at EVERY returning `write` call state. It needs a CF-level
argument that keeps the events (`writei` raises `InvalidFD` on result
byte 1). NOT RUN. Not introduced as an assumption.

Not obtainable from any trace: alignment of `c` and `a`, stack placement
and the separation conjuncts. They need a memory-layout invariant of the
compiled code at FFI calls.

Form gap: the bound is proved in numeric form (`w22n` on memory bytes).
`ffiwrite_call_pre` states it as a 64-bit word inequality on
byte-reversed halfword loads. The equivalence is NOT machine-checked.
`x1 = 8` matches the conjunct exactly. So of the 19 conjuncts, 2 are
discharged at the reached state (`PC`, `x1 = 8`); the bound is
discharged only up to that bridge; 16 stay premises.

## 6. Controls

- Empty output: `empty_string_is_not_a_complete_sexp`;
  `empty_trace_has_no_successful_write_and_keeps_fs`.
- Incorrectly sized buffers: `wrong_clen_write_never_succeeds`;
  `out_of_bounds_write_never_succeeds`;
  `wrong_clen_register_gives_no_successful_write` (`x1 ≠ 8` at the call
  state gives no result byte 0).
- Invalid argument representations: `short_array_write_is_rejected`
  (fewer than 4 bytes: oracle `NONE`);
  `write_call_with_unreadable_arrays_is_an_error`;
  `failed_write_event_is_not_successful` (failed, `read` and empty-array
  events are not `write_ok_event`s).
- Vacuity: `constructed_successful_write_call_state` (constructed model
  machine, constructed file system, basis oracle; the call returns
  result byte 0). It shows the premises of
  `successful_write_call_state_has_valid_arguments` are satisfiable. It
  is NOT a refund execution and NOT a native execution.
- Scope (`check-0002`): the non-empty-output premise is gone from the
  U400 refund theorems and still present in the U399 theorem; no
  unconditional reachable state; `clen = 8` only as a conclusion under
  the basis oracle; argument facts only under `write_ok_event`;
  `ffiwrite_call_pre` and `write_call_rel` only as premises; no
  source-semantics constant; no alignment statement.
- Preserved: four U399 statements re-imported exact;
  `cake_ffiwrite_path_returns` premise unchanged;
  `forge_compileCorrectControl` and `forge_refundWriteReach` in the
  closure (536 nodes; axioms only the four of `bool`). The full
  172-statement import was NOT re-run.
- Exploration runs used placeholder theorems after a failed lemma; the
  tag check rejected every dependent result. `args-0006` used none.

## 7. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `args-0001`–`0005` | 1 each | authoring; nothing exported |
| `args-0006` | 0 | `forge_refundWriteArgs` |
| `check-0001` | 1 | defect in a control of the check script (wrong expected count); not a theorem defect |
| `check-0002` | 0 | witness; 14 exact statements; 8 scope controls |
| Repeats; full import; bound bridge; source event invariant | NOT RUN | |

Failures: authoring as listed. Tool: none. Memory: none (swap 8.7 of
10.2 GiB used). Logical: none found in stored statements (all read after
exit 0).

## 8. Next smallest proof obligation

Bridge lemma: the numeric bound of section 1 implies the word-form
bound conjunct of `ffiwrite_call_pre` (one bit-vector lemma, ARMv8
context, no new assumption). After that: the source-level event
invariant of section 5.

Unchanged and explicit: `write_call_rel`, the OS `write`, the loader,
slide 0, `¬SCTLR_EL1.A`, the model-to-real-process link.
