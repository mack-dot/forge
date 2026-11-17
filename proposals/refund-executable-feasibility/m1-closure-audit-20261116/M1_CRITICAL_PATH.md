# M1 critical path (U401 audit)

Date: 2026-11-16. Plan only. Nothing here is authorized, run or approved.
No percentage and no timeline: the evidence supports neither.

## 1. Outstanding obligations

Difficulty: S (one narrow theory), M (several theories, known method),
L (new method or large proof), D (owner decision, not a proof).

| # | Obligation | Current evidence | Missing theorem or action | Depends on | Diff. | Blocks M1? |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Approved assurance profile | Profiles A, B compared (U360). None approved | Owner decision | — | D | YES (mission 3, success condition) |
| 2 | Approved contract R1–R5 to the HOL model; Unicode transfer | Last record: open. NOT re-audited | Re-audit; representation relation; Unicode-domain transfer or an approved scope change | — | M–L | YES |
| 3 | Slide | Image lemmas for every slide; composed theorems at slide 0 | Slide-generic start-up, installed-state and behaviour theorems | U388–U392 | M | YES (premise probably false) |
| 4 | One acceptance statement | `refund_behavior_abstract_env`, `refund_u298_exclusion_abstract_env` | One theorem with all premises listed; joint satisfiability witness | 2, 3 | S | YES |
| 5 | Compiler-premise ledger | `compile_correct'` instance | Show where `backend_config_ok`, `mc_init_ok`, `opt_eval_config_wf` are discharged | — | S | YES (audit gap) |
| 6 | Clean replay of the CakeML-dependent chain | NOT RUN | Clean rebuild from pinned sources | 4 | M (cost) | YES |
| 7 | Independent replay | NOT RUN | Second environment; authorization and budget | 6 | M (cost) | YES ("independent checker") |
| 8 | Absent input, general `ffi` | OPEN | Theorem, or a named exclusion in the profile | 1 | S | Only if the profile includes them |
| 9 | Successful termination | Not proved; resource-limit prefix allowed | None for M1. A `is_safe_for_space` proof for a stronger claim | — | L | NO |
| 10 | Numeric-to-word `write` bound | PROVED (U401, one run) | Exact-statement import | — | S | NO |
| 11 | `write`-event invariant (every event successful) | Not derivable from the exported specification (U401) | CF specification of `TextIO.writei` that keeps the events | — | L | NO under A |
| 12 | 12 residual `write` call-state conjuncts | Listed exactly (U401) | Memory-layout invariant of compiled code at FFI calls | 3 | L | NO under A |
| 13 | `read`, `open_in` paths | NOT RUN | Same method as `write` | 12 | M each | NO under A |
| 14 | `close` reachability | Probably unreachable; not proved | Unreachability theorem, or keep the obligation | — | M | NO under A |
| 15 | External FFI conformance | `*_call_rel` assumed | Model of `libSystem` calls; oracle conformance in HOL | 12, 13 | L | NO under A |
| 16 | Loaded image, dyld binding, process entry, C run-time | Assumed (`refund_entry_pre`) | Models that do not exist | 3 | L | NO under A |
| 17 | Real machine and model correspondence | Assumed | Research | all | L | NO for level B |
| 18 | Native execution | NOT RUN | Run the binary on fixtures (evidence, not proof) | — | S | NO, but it would test premise 3 |

## 2. Path A — minimal defensible M1 (level B)

Boundary: the model machine with the abstract FFI environment (U392).
Everything below it is one named simulation assumption.

Milestones, in order:

- **A0 (owner).** Decide the profile. Decide whether the M1 claim is the
  full R1–R5 Unicode contract or a stated narrower claim. A narrower
  claim is a specification change and needs explicit approval.
- **A1.** Re-audit obligation 2 from the pre-U345 records. Output: the
  exact list of missing links between the approved contract and
  `refund_fields`. Blocks closure if a link cannot be proved and no
  scope change is approved.
- **A2.** Slide-generic chain. Statements: `refund_entry_pre_sl sl s h stk e
  ⇒ …` for start-up; installed state at `0x1000040D0w + sl`; behaviour and
  exclusion for every `sl`. Risk: absolute addresses in the 27 start-up
  steps (adrp/add pairs are PC-relative; to be checked per word).
  Control: a wrong slide in the image predicate must fail.
- **A3.** Acceptance theorem as one statement (see the audit, section 2).
  Joint satisfiability of all premises by a constructed state, labelled
  as constructed. Controls: wrong hash, changed code word, wrong input,
  missing premise.
- **A4.** Compiler-premise ledger (obligation 5).
- **A5.** Clean replay in a fresh environment on this host. Needs the
  CakeML build; disk and memory first (U352: deficit 13.3 GiB then).
- **A6.** Independent replay. Separate authorization and budget.
- **A7.** Evidence packet for M1 with `end_to_end` unchanged until the
  owner decides.

Conditions that block Path A: no profile; contract link not provable;
slide-generic proof fails; a clean replay disagrees; premises not
jointly satisfiable.

## 3. Path B — stronger deployed-machine guarantee (level C direction)

All of Path A, then, as additional research (not original M1 text):

- **B1.** Memory-layout invariant at FFI calls. One invariant should
  discharge most of the 12 residual `write` conjuncts and the same
  conjuncts for `close`, `read`, `open_in`.
- **B2.** `read` and `open_in` paths; `close` unreachability.
- **B3.** Event-keeping CF specifications; `write`-event invariant.
- **B4.** A weakened `ffi_interfer_ok` (per reachable call) and a variant
  of the compiler theorem that uses it. This replaces the abstract FFI
  by the real C paths plus `*_call_rel`.
- **B5.** Contracts for `libSystem` calls; oracle conformance in HOL.
- **B6.** Process entry: dyld binding, `_main`, C run-time to `cml_main`.
- **B7.** Processor-state and scheduler assumptions (`SCTLR_EL1`,
  signals, other threads).
- **B8.** Native runs as tests of the premises. Attestation only as
  identity evidence.

Risks: B4 changes a published proof. B5–B7 need models that do not
exist. A full level C proof is not reachable with established tools for
macOS; B ends in a smaller assumption set, not in zero assumptions.

## 4. Independent verification strategy

Completed: local runs with input hashes per case (`command.json`);
exact-statement imports per packet; closure node and axiom lists; clean
replay of two ARM8 theorems (U360). Nothing else.

Proposed (NOT RUN):

1. Pins: HOL `9783a499…`, CakeML `cd915569…` (current checkouts under
   `.toolchain/experiments/refund-cakeml-20261104`), PolyML version,
   executable SHA256 `b8ed5ec2…7bb8`.
2. Clean build of HOL and the CakeML theories needed, from the pins.
3. Build the Forge theories in dependency order from their `.sml`
   sources only. No cached `.dat` files.
4. Compare theorem statements by a checker written separately from the
   proof scripts. Compare closure and axiom lists.
5. Run every negative control. A control that passes is a failure.
6. Re-derive the two file slices and the hash with a second tool.
7. Record peak memory and disk. Local cases used 2.4–3.4 GiB resident
   each; the CakeML build is far larger (not measured here).
8. Different machine and operator for the independent run.

## 5. Next action

A0 and A1. The profile decision and the contract re-audit decide what
theorem M1 is. Proof work before them risks proving the wrong statement.
The highest-value proof task after them is A2 (slide-generic chain).

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
