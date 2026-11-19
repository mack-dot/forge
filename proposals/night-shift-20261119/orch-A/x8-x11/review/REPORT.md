# W-x8rev: adversarial review of the constructed-environment argument (condensed by Orchestrator A; by reading; UNCHECKED in HOL)
Verdict: YES — the route makes R6 unnecessary for the REAL-PROCESS claim; R6 stays needed only for a model-internal theorem
about the original C code at all states. Nothing here is machine-checked.
- `envmc` is free in the composed theorem; an environment built from one real run is a legal instance. The k-th FFI event
  uses `ffi_interfer k`; the m-th normal step uses `next_interfer m`. A guarded function (real effect at the observed
  argument, abstract effect elsewhere) is a total HOL function; off the guard the stored `refund_abs_ffi_contract_at` applies.
- Native assumption A-FFI-EFFECT-AT-CALLS (exact): at the k-th observed call with post state r': PC = the call's x30;
  x19–x25, x27, x28 unchanged; every byte of the domain = the pre-state memory with the returned bytes written at the
  array; (added) SP unchanged or 16-aligned. The contract does not ask for x0–x18, x26, x29. Plausible for the present C
  `ffiread`/`ffiwrite` at the run's calls (by reading the disassembly and the model).
- Oracle side: one `numchars` entry per call reproduces the real read/write counts; a real −1 has no model counterpart: the
  relation then does not hold and the theorem concludes NOTHING. DEFECT in the draft (lines 184–187): "safe because the
  parser is strict" does not follow when A-FD1-WRITE fails; bytes written after an unmodelled error are unconstrained. So
  A-FD0-READ and A-FD1-WRITE must be ENFORCED by the launcher (blocking descriptors; a private pipe), not assumed.
- Killed runs: needs `machine_sem_total` (targetPropsScript:1134) and the add-clock lemmas, not "the existence part of M3".
- Processor bits: handled by erasure inside the abstraction; the obligations move into the step clause
  (`NextStateARM8_erase`, run lift, no fault): MISSING. Add "SP preserved or 16-aligned" to the kernel and FFI premises.
- Non-circular form: define the returned bytes as the REAL post-call bytes; define the file-system states by recursion on
  the real call sequence; prove the trace lemma by induction on real events.
- To prove in HOL (MODEL, MISSING): T-ENV (largely tonight's L1: totalisation by a guard), T-TRACE, T-PREFIX, the erasure
  run lift, the decode lemma for x18. Native: A-CPU-ISA, A-PROC-N1..N5, A-X18, A-KERNEL-PRESERVE(+SP), A-SINGLE-THREAD,
  A-ENTRY, A-LOADER, A-FFI-EFFECT-AT-CALLS(+SP), A-FFI-FRAME, A-FD0-READ and A-FD1-WRITE (ENFORCE), A-STDOUT-EMPTY,
  A-OUT-DELIVER.
