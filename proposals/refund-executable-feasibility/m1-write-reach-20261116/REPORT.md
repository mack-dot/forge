# M1 — `write` events and reachable `cake_ffiwrite` call states (U399)

Date: 2026-11-16. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Stage 12 unauthorized. No profile approved.
`end_to_end=false`. Nothing committed. Continues U397, U398.

Run directory: `results/refund-write-reach-local-20261116/attempt-0001`.
Theory: `forge_refundWriteReach` (`reach-0009`, exit 0).

## 1. Verdict

A machine-checked trace-correspondence theorem exists for the MODEL
machine of the published target semantics: a new `write` event in the
trace implies a reachable state at `pc = 0x100004090`. It is connected to
the refund program's file-system specification: a refund run that
TERMINATES with `Success` and non-empty output reaches the call. This is
a conditional result. No refund execution witness is proved. The real
process, the OS `write`, the loader and the PIE slide stay unresolved.

## 2. What a new `write` event is

- `write_event e ⇔ ∃c b. e = IO_event (ExtCall «write») c b`.
- `refund_event e`: an `IO_event (ExtCall n) c b` with `n` in
  `read`, `write`, `close`, `open_in`.
- "New": an element of the list `l` appended to `ffi.io_events` by
  `targetSem$evaluate` (`ffi'.io_events = ffi.io_events ++ l`).

## 3. Event-to-PC implication (proved, model machine)

- `one_step_cases`: under `refund_static mc dm`, one `evaluate` step
  either leaves the FFI state, or is a `machine_step` with the same FFI
  state, or is a `machine_step` that appends exactly one `ExtCall` event
  whose name is one of the four; if the name is `write` then
  `ms.PC = 0x100004090w`.
- `evaluate_trace_events`: for every clock, the appended events are all
  `refund_event`s, and `EXISTS write_event l ⇒` a reachable state
  (`machine_reach`) with `PC = 0x100004090w`.
- `terminating_trace_with_write_event_reaches_write_call`: the same for
  `machine_sem … (Terminate t io)` from an empty trace.

Alternative event-producing paths, excluded by proof: normal steps, halt,
install and error branches append nothing; `SharedMem` calls cannot occur
(`mmio_info = []`, all four names are `ExtCall`); the other three entry
PCs append `read`, `close` or `open_in` events only
(`refund_static_ffi_index`). Converse: `write_call_step_appends_write_event`.

## 4. Output implies a `write` event (proved, file-system model)

- `ffi_read_keeps_inodes`, `ffi_open_in_keeps_inodes`,
  `ffi_close_keeps_inodes`; `replay_without_write_event_keeps_inodes`.
- `add_stdout_changes_inodes`: non-empty added output changes the inode
  table.
- `nonempty_output_needs_write_event`: `extract_fs ext (cl,fs) io = SOME
  (add_stdout (fastForwardFD fs 0) out) ∧ STD_streams fs ∧ EVERY
  refund_event io ∧ out ≠ «» ⇒ EXISTS write_event io`.
- `run_with_output_reaches_write_call`: both parts combined.

## 5. The refund program (conditional)

`refund_terminating_run_reaches_write_call`. Premises, exact:

1. premises of `refund_behavior_valid_request_no_handler`
   (`is_arm8_machine_config mc0`, `refund_installed_no_handler mc0 ms
   cbspace data_sp`, valid request on standard input, `wfcl`, `wfFS`,
   `STD_streams`);
2. `refund_static mc0 dm`;
3. `machine_sem mc0 (basis_ffi ext cl fs) ms (Terminate Success io')`;
4. the rendered output is not `«»`.

Conclusion: `EXISTS write_event io'` and a reachable model state at
`PC = 0x100004090w`.

Limits, stated plainly:

- Premise 3 is NOT discharged. The published theorem also admits a
  resource-limit stop. No terminating refund run is exhibited. So no
  admissible refund execution with a `write` event is proved.
- Premise 4 is NOT discharged. One proof attempt did not terminate
  (`reach-0005`, CPU limit). By inspection the response is an S-expression
  with seven atoms; this is not a proof.
- Premise 1 (installed state) and premise 2 are assumed as before.
- Source-level existence of a `write` event is NOT proved: the replay
  lemma needs the event names, which the source theorem does not give
  for a general `ext`.

## 6. Source-level versus machine-level

All reachability here is in the model machine of `targetSem`, derived
from its `evaluate` definition and from the trace that the published
compiler theorem relates to the source. No statement about source-level
reachability is made, and none is used. The link from the model machine
to the real ARMv8 process is NOT proved.

## 7. `clen = 8`, buffer bound, separations (not derivable)

- At the reached state: `write_call_site_facts` gives readable arrays,
  `4 ≤ LENGTH abytes`, `4 ≤ w2n x3` (in
  `refund_reached_write_call_facts_and_path`).
- `ffi_write_wrong_clen_is_a_silent_failure`: with `LENGTH c ≠ 8` the
  oracle returns the error result and leaves the file system unchanged.
- `replay_ignores_wrong_clen_write_event`: such an event can be inserted
  anywhere in a trace without changing `extract_fs`. So the exported
  file-system specification cannot imply `clen = 8`.
- Buffer bound and separations: no theorem relates them to the trace.
- Smallest missing lemma: an event-level specification of the program
  ("every `write` event has an 8-byte configuration and
  `n + off + 4 ≤ LENGTH bytes`"), from the CF specification of
  `TextIO.output`, carried through `compile_correct'`. Separations need a
  memory-layout invariant of the compiled code at FFI calls. Neither is
  introduced as an assumption.

## 8. Composition with `cake_ffiwrite_path_returns`

`refund_reached_write_call_facts_and_path`: under the premises of
section 5 and `0x100004090w ∉ dm`, there is a reachable `ms1` at the
call with the facts of section 7, and for all `dm' b c a g`:
`ffiwrite_call_pre dm' ms1 b c a g ⇒` the U398 conclusion (23 steps to
the external call; under `write_call_rel` and `¬SCTLR_EL1.A`, return in
6 or 10 steps). Only the PC conjunct of `ffiwrite_call_pre` is
discharged by reachability. The other 18 conjuncts, `write_call_rel`,
the OS implementation, the loader and slide 0 stay explicit assumptions.

## 9. Controls

- Absent events: `no_step_no_event`; `¬EXISTS write_event []`.
- Unrelated events: `other_events_are_not_write_events`;
  `replay_without_write_event_keeps_inodes`.
- Unreachable calls: no theorem asserts a reachable call state
  unconditionally; in the trace theorem the call state is under
  `EXISTS write_event` only (structural check).
- Vacuous implications: `constructed_model_run_has_write_event` (a
  constructed model machine, oracle and state; one step; NOT a refund
  execution, NOT a real execution) shows the premises of the trace
  theorem are satisfiable. The refund theorem's premises are NOT shown
  satisfiable (section 5).
- Scope: `ffiwrite_call_pre` and `write_call_rel` occur only as premises;
  no theorem concludes `clen = 8`; no source-semantics constant occurs.
- Exploration runs used placeholder theorems after a failed lemma; the
  tag check rejected every dependent result and nothing was exported.
  `reach-0009` used none (0 occurrences; all 27 theorems tag-checked).

Preserved: `cake_ffiwrite_path_returns` loaded with its premise unchanged;
`forge_compileCorrectControl` is in the closure (535 nodes; axioms only
the four of `bool`). The full 172-statement import was NOT re-run.

## 10. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `reach-0001`–`0004`, `0006`–`0008` | 1 each | authoring; nothing exported |
| `reach-0005` | −24 | CPU limit (optional non-emptiness proof) |
| `reach-0009` | 0 | `forge_refundWriteReach` |
| `check-0001` | 0 | constructed witness; 10 exact statements; controls |
| Repeats; full import; non-emptiness; terminating refund run | NOT RUN / NOT ESTABLISHED | swap 10.6 of 11.3 GiB |

Failures: authoring as listed. Tool: none. Memory: none. Logical: none.

## 11. Smallest next step

Discharge premise 4: prove the rendered response is not `«»` (a lemma
about `sexp_to_string` on `Expr`). After that, the smallest missing
simulation lemma for the arguments is the event-level specification of
section 7.
