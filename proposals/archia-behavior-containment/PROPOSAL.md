# Proposed Archia behavior-containment specification (design proposal)

Status: DESIGN PROPOSAL, 2026-11-15. Nothing in this file is an established guarantee.
No theorem in Forge states behavior containment against an authorization policy.
This proposal does not expand M1. M1 stays the refund executable verification. Stage 12 unauthorized. end_to_end=false.

## 1. Purpose

Long-term primary property for Archia: every externally observable effect of an executable complies with an explicit
authorization policy. This file gives a candidate formal statement, separates it from two narrower properties, and maps
existing Forge theorems to the parts that they support.

## 2. Three separate properties

| # | Property | Informal statement |
| --- | --- | --- |
| P1 | Run-time code-installation exclusion | The machine never reaches the installer entry. The executed code is the installed code. |
| P2 | Observable behavior containment | Every machine behavior is in the set that the policy permits. |
| P3 | FFI authorization and confinement | Every interaction with the environment goes through a named, authorized FFI call with authorized arguments, and the FFI code does only what its model says. |

P1 does not imply P2. A program with fixed code can still emit an unauthorized event.
P2, as stated on the model, does not imply P3. P2 speaks about the events of the FFI model. P3 is the claim that the real FFI code and
the processor agree with that model.

## 3. Candidate formal statement of P2 (proposal)

Terms of the CakeML target semantics, as used in Forge:

- A behavior is `Terminate outcome events`, `Diverge trace` or `Fail`.
- An event is one FFI call: name, configuration bytes, argument bytes with result bytes.
- `machine_sem mc ffi ms` is the set of behaviors of machine record `mc` from state `ms` with FFI oracle `ffi`.

Policy: a set `Pol` of permitted finite event lists that is closed under prefix, plus a set `Out` of permitted outcomes.
A policy is a safety property. It does not express liveness, timing or information flow.

`permitted Pol Out b ⇔ (∃o es. b = Terminate o es ∧ o ∈ Out ∧ es ∈ Pol) ∨ (∃tr. b = Diverge tr ∧ every finite prefix of tr is in Pol)`

Containment of executable `X` under entry condition `Entry`, FFI oracle class `F` and policy `(Pol, Out)`:

`∀mc ms ffi. Entry X mc ms ∧ ffi ∈ F ⇒ machine_sem mc ffi ms ⊆ {b | permitted Pol Out b}`

Design choices that need an owner decision before any proof work:

1. Resource limits. CakeML permits early termination with a resource-limit outcome and a prefix of the events. With a prefix-closed
   `Pol` this is contained if `Out` includes that outcome.
2. Oracle class `F`. Forge theorems hold for `basis_ffi ext cl fs` with a well-formed file system. A policy for a general oracle is a
   different, stronger statement.
3. Policy language. An explicit authorization policy needs a concrete syntax (permitted FFI names, argument predicates, file
   descriptors, byte budgets). None is defined.
4. `Entry`. It must be a condition that a deployment can establish or check: loaded image, start-up state, machine record.
5. Whether `Fail` is excluded by the statement (proposed: yes, as above).

## 4. Existing Forge theorems and what they support

All rows are for the refund executable only. All are local results, not independently replayed.
"Conditional" means: under the premises listed in the cited entry.

| Part | Existing theorem | What it gives | What it does not give |
| --- | --- | --- | --- |
| P1 | `refund_u298_exclusion_real`, `refund_mc_u298_exclusion_stdin`, `refund_u298_exclusion_from_entry` (U386, U388, U390) | No `TimeOut` state has its pc at `install_pc`, for every installer handler. Conditional on the installed-state predicate (U390: on a 7-clause residual) and on the input premises | Nothing about events or outcomes. It is not behavior containment |
| P2, outcome | `refund_mc_behavior_stdin_no_handler`, `refund_behavior_from_entry` (U388, U390) | `machine_sem … ⊆ extend_with_resource_limit {Terminate Success io_events}` for some `io_events`, for every text at standard-input offset 0. Conditional as above | `io_events` is existential. No statement restricts which events occur on the rejected-input path |
| P2, events (valid input) | `refund_behavior_valid_request_no_handler` (U387) | For a valid request: the events determine a file system whose standard output is the rendered refund fields (`extract_fs … = SOME (add_stdout …)`) | It is a functional statement for one input class, through the file-system model. It is not a policy over event lists |
| P2, no `Fail` | `refund_source_nonfail_stdin` (U388) | The source program does not `Fail` for every text at offset 0 | Absent input, a file system that is not well-formed, a general oracle: OPEN |
| P2, compiler link | published `compile_correct'` (control re-checked each run); `refund_compile_correct_no_handler` (U386) | Machine behaviors are source behaviors up to resource limits, given the installed state | The installed state for a real process |
| P3, names | `refund_mc_fields` (U388) | The machine record's FFI names are those of the compiled configuration; no shared-memory (`mmio`) entry | A stored enumeration of the names as a policy; per-call argument conditions |
| P3, FFI code | none | — | `ffi_interfer_ok` is OPEN (U390 residual). The C FFI code, the C run-time and system libraries are not modelled |
| `Entry` | `refund_loader_startup`, `refund_installed_from_entry` (U389, U390) | From an assumed image at slide 0 and an assumed entry state: 23 of 30 installed-state clauses | Loader behavior, load slide, path from process entry to `cml_main`, `interference_ok`: OPEN or ASSUMED |

## 5. Gaps between the existing results and P2 for the refund executable

1. No policy object exists. The closest existing statement fixes the outcome and, for valid input, the final standard output.
2. The rejected-input path has no event-level statement. The stored source specification for that path was lifted only to
   "terminates with success".
3. The installed-state predicate is not established for any state (U390 residual, slide, loader, entry state).
4. P3 is open: `ffi_interfer_ok`, and everything outside the model (C run-time, dynamic loader, system libraries, kernel, signals).
5. Input classes outside "text at offset 0", and oracles other than `basis_ffi`, are open.
6. The ARMv8 model is the L3 model. Its relation to Arm's official specification is not imported into Forge.
7. Timing, memory disclosure, and other side channels are outside the behavior semantics. Containment as stated does not cover them.

## 6. Non-claims

- The U298 exclusion theorem does not prove general behavior containment. Its statement stays as it is.
- No Forge theorem is a firewall guarantee for a deployed process.
- This proposal does not define a framework and does not change M1, M2, M3 or M4.

## 7. Possible later work (not started; needs an owner decision)

- After M1 closes: state P2 for the refund executable with a first concrete policy, for example "events only through the FFI names
  of the compiled configuration; outcome `Success`; standard output equals the rendered fields or standard error carries the error".
  Check each part against the stored source specifications before any claim.
- Lift the stored reject-path specification to an event-level statement.
- Decide the policy language and the oracle class.
