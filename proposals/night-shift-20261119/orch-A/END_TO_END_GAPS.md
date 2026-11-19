# Exact list of unproven transitions to `end_to_end=true` (proof-to-executable chain; Orchestrator A; 2026-11-19T14:25:41Z)

Status: `end_to_end=false`. M1-B OPEN. This file promotes nothing. It lists every transition between the approved
specification and the real executable's effect that is NOT a machine-checked theorem today, with its class and the
smallest next step. "MC" = machine-checked tonight or earlier (model level, same machine). Track B's list for the issuer,
sink and admission side is in `orch-B/MORNING.md` and its ledger; the rows T14–T17 below only name the joints.

## Chain and state of each transition

| # | Transition | State | Evidence or gap |
|---|---|---|---|
| T1 | Approved R1–R5 ⇐ flat contract (Dafny `LinkedRefund`) | MC (Dafny) | B's records |
| T2 | Flat contract ⇔ predicate generated from the export bytes 58154ddf… | MC (Dafny `ExportBridge`), reader fidelity ARGUED | B |
| T3 | Dafny meaning of the 3 exported clauses = HOL `evaluate_exps` meaning (strings as bytes, integers, 8 operators) | **UNPROVEN** (ASSUMPTION BETA) | no artefact relates the two semantics |
| T4 | Dafny source → export bytes (exporter fidelity) | **UNPROVEN** (record only; build folder absent) | review A17 edge b |
| T5 | Exported clauses hold exactly on HOL `refund_fields` | MC (H1, H2; 11 controls) | `exported_contract_exact` |
| T6 | `refund_fields`/render = the compiled CakeML program's source behaviour | MC (earlier M1 chain; U294 replayed tonight) | stored theories |
| T7 | Source → ARM64 machine code slices (CakeML compiler correctness, exact bytes) | MC (earlier M1 chain; same-machine replay 71 of 71) | not re-proved tonight; no clean replay |
| T8 | Machine model run → every behaviour → descriptor-1 bytes → strict parse → value → exported clauses | MC (`MF-0002`, `MG-0001`, `L2d-0001`) UNDER PREMISES T9–T12 | one HOL theorem |
| T9 | FFI premise of T8 | **UNPROVEN**. Form (i): contract at shape-valid calls (L2d) — no environment that describes the present C code meets it. Form (ii): contract at the program's own call shapes + R6 (every FFI event of every run is a valid read/write). R6: FFI layer and write side proved (`R6ffi-0002`, `R6w-0004`); read side, main program, initial heap, event link, machine transfer OPEN | owner item A-3; `orch-A/r6/` |
| T10 | Entry state: the real process at the first instruction of `cml_main` satisfies `refund_entry_pre_sl`, heap/stack/domain premises; `interference_ok` | **UNPROVEN** (NATIVE) | dyld, C start-up, allocation are outside the proved slices |
| T11 | Processor state bits (TBI0, TBI1, SA0 clear in `arm8_ok`) | **UNPROVEN**. One-step erasure proved (`EE-0001`); run-level lift, untagged-PC invariant, non-vacuity with bits set, real bit values OPEN | review A31 N1–N5 |
| T12 | `no_ext` oracle; stdin content = the request bytes; `wfFS`, `STD_streams`; stdout initially empty | **UNPROVEN** (launcher/NATIVE) | named in review A26. `STD_streams`/`wfFS` are the premises that the counterexample class CE-2 violates (closed or wrong-mode stdin/stdout: exit 0 with empty stdout): a launcher must hand the process open descriptors 0 (readable) and 1 (writable, blocking) — red-team note C, 14:3xZ |
| T13 | X8/X11: the real process (processor, kernel, C FFI results) refines `targetSem` for this machine configuration | **UNPROVEN** (NATIVE; not provable in HOL without a processor and kernel model) | CE-1, CE-2 show where the real FFI leaves the model; statements in work (`orch-A/x8-x11/`) |
| T14 | The bytes the consumer reads = descriptor-1 bytes of the process; the consumer's parser = HOL `refund_strict_parse` | **UNPROVEN** (TESTED: 304,326 inputs) | Python parser not verified |
| T15 | Launch environment (no injected loader code; fixed env) | **UNPROVEN** (CE-3; ASSUMPTION A-LOADER; both launchers pass a fixed env) | |
| T16 | Native result → issuer decision (edge X16) | **MISSING in the deployed path** (the issuer calls the compiled Dafny checker); a dual-check design is proved at model level by B (Bridge2), draft | B |
| T17 | Issuer → token → sink → committed state; deployed TypeScript, SQLite, admission | Dafny models MC; deployed code TESTED or has known defects | B |

## Smallest missing refinement boundary (owner directive 2, item 3)

Between "proved properties" and "the actual executable" the smallest boundary that is still a MODEL-level proof obligation
is **T9 (the FFI premise)**: everything else on the HOL side of T8 is proved, and T9 is the only premise of T8 that speaks
about code inside the executable's own C object. Two exact ways to close it are recorded (R6 for the present executable;
or the model-total C FFI, owner item A-3). After T9, the remaining boundary is NATIVE (T10–T13, T15): it cannot be closed
by HOL alone; it needs named assumptions with tests, or a different trusted base (a verified kernel and processor model
do not exist here).

## What would have to be true to set `end_to_end=true` (not a proposal to set it)

1. T9 closed by a checked theorem plus a separate review. 2. T3 and T4 replaced by a checked artefact or accepted by the
owner as named assumptions. 3. T10–T13, T15 accepted by the owner as the trust base, each with its test. 4. T14 closed
(a verified parser, or the consumer uses the HOL-extracted parser). 5. T16 and T17 on the deployed path (B). 6. A clean
replay and an independent-machine replay of the whole HOL chain. 7. The owner's word. None of 1–7 holds today.

## Non-vacuity (red-team note C)
The premise sets of `refund_model_frame_decision_shape` and `…_events` are not shown jointly satisfiable by ONE stored
theorem (parts exist: `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` for the older premise set;
`remaining_premise_met_by_the_abstract_effect` for the shape contract). A single witness theorem is in work (worker W-nv).

## Update: the smallest boundary, restated after the X8 draft and its review (by reading; not machine-checked)
The FFI premise T9 does NOT need R6 for the real-process claim. Reason: the composed theorem holds for every environment;
tonight's L1 turns ANY interferer into one that meets the all-states contract by a guard (`refund_ffi_tot Vok f`). With
`Vok` := "an argument observed in the real run", the model theorem speaks about the totalised machine, and the real run
is a run of that machine if the real FFI effect meets the contract AT THE CALLS IT MAKES (native assumption
A-FFI-EFFECT-AT-CALLS) and the kernel's read/write results are the model oracle's (A-FD0-READ, A-FD1-WRITE: to be ENFORCED
by the launcher). So the smallest missing refinement boundary is now ONE statement, X8 (T13), with a model part
(HOL lemmas: the composed theorem for the totalised machine — worker W-mt; the trace lemma T-TRACE; the killed-run
prefix lemma; the erasure run lift; a decode lemma for x18) and a native part (the named assumptions).
R6 (and the model-total C patch, owner item A-3) remain the way to a statement about the C code at ALL states;
they are no longer on the shortest path.
