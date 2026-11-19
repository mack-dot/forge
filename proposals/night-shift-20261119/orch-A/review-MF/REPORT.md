# A26 adversarial review of MF-0001/MF-0002, L2c-0001, LE-0004, EF-0001 (condensed by Orchestrator A)
Verdict: no defect in the proofs or the evidence. All five cases MACHINE-CHECKED at MODEL level.
- Integrity HOLDS (every digest recomputed; parents' digests equal the parent cases' own objects; MF-0002 loaded the same
  contract theory that link case H1 produced: SHA-256 of `.sig/.sml` equal; the `.dat` bound by its SHA-1 parent id).
- Harness HOLDS in all cases (ASSUME fallback never stored; tag check over all theorems and definitions; lists empty).
- M3 `refund_model_frame_meets_exported_contract`: constants are the link theory's own (`forge_refundExportedContract`);
  `refund_fields` is `forge_refundCertifiedProg$refund_fields` on both sides; `dafny_heap`, `dafny_env` free; no capture.
- Vacuity: existence of a behaviour is NOT composed into M1/M3 (it follows from CakeML `machine_sem_total`,
  targetPropsScript.sml:1134). The premises are jointly satisfiable in the MODEL (stored
  `refund_profile_a_sl_all_premises_satisfiable_at_0x4000`, theory `forge_refundInputSat`). Reading: "a true statement
  about a model machine; its FFI premise is not met by the real FFI (U393)".
- 13 assumptions stand between M3 and "the real consumer accepts the real stdout ⇒ approved R1–R5": X8 (process refines
  model), the FFI premise (or R6 + contract), `no_ext`, A-FD1-WRITE, A-LOADER/entry state, Python parser = HOL parser
  (TESTED), stdout starts empty, BETA (clause meaning Dafny vs HOL), exporter identity, Dafny LinkedRefund, input encoding
  (stdin = `refund_request` of the nine values the caller means), X16 (the issuer does not use this binary today),
  kernel I/O = oracle (no EPIPE/EAGAIN).
- L2c: the assembly is `refund_profile_a_sl_reach` at `Vok := VokY3` with exactly premise 3 replaced by R6 (pairwise
  `aconv`). R6 is PLAUSIBLE in the model (program = `inputAllFrom NONE` then `print`; every read asks 4096 into 4100;
  writes ≤ 2048 from a 2052 buffer; the model never returns an error byte under `wfFS` and `STD_streams`), NOT proved.
  The native contract at VokY3-valid calls is plausible for the present C code only at those calls (TESTED-UNPROVED).
- LE-0004 holds (statement uses the CmlMainSlide `arm8_run`; vacuous if no clock halts — existence is elsewhere).
  EF-0001 holds; for the stored target the usable form is `NextStateARM8_frame`, plus a separate no-fault fact.

## Addendum by Orchestrator A (10:08Z)
The composition the reviewer listed as missing (M1b ∘ L2c) ran after the review: case `MG-0001`, actual exit 0,
5 theorems: G1 `refund_model_frame_decision_events` (antecedent = that of `refund_profile_a_sl_events` at `no_ext`;
conclusion term-identical to M3's), G2 `refund_model_success_gives_frame_events`. Not yet reviewed by a separate worker.
