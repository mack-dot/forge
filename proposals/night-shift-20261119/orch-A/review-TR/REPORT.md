# Review of TR1-0001, TR2-0001, R6t-0004 (condensed by A, 2026-11-19T17:03:57Z); full text `trace/review_TR1_R6t.txt`
All three: HOLDS WITH LIMITS. Exit 0, EXACT_COMPLETE, stderr empty, digests re-computed, used files unchanged, tags
DISK_THM only, 4 bool axioms, no hypothesis.
- TR1-0001 (forge_machineTrace; 71 theorems = 37 lemmas + datatype and definition theorems): `trace_ok` demands agreement
  under the projection P only, not equality of states. `evaluate_follows_trace` holds at clock LENGTH tr + k. Install,
  SharedMem and FFI_final are excluded by `trace_ok` conjuncts (so they are obligations). Index convention = X8 v3.
- TR2-0001 (forge_machineTracePrefix): `trace_terminate`: constructed machine Terminate t io ==> after-trace machine
  Terminate t io and `st.io_events ++ trace_events` is a prefix of io; only premise `trace_ok`. A toy control shows the
  premise cannot be dropped.
- R6t-0004 (forge_refundR6Top; 18 theorems): the conclusion reaches the source-semantics io_events (Terminate Success io
  and EVERY Inv io). Hypotheses that remain: the main V-spec (POSTv only), declaration lookup, the state facts (ffi =
  basis_ffi; refs with LENGTH bs2 = 2052), wfFS and STD_streams. No machine-level fact.
Defects (no soundness break): the trace theory has two unneeded parents from the preload (comment says otherwise); two
latent paths where an optional parse failure becomes T / drops controls (not realised in this run); controls use a toy
machine with P = identity only.
NOT given: any arm8 or refund content; a proof that a non-toy trace satisfies `trace_ok` (this is the real content of
X8 lemma ML-11: fully open; needs ML-05..ML-10 and native rows N10/N12); R6: the main V-spec and state facts.
Simplification found for X8: ML-02 needs no LEAST construction: take Vok := everything-valid, g := refund_abs_ffi,
G := the contract conclusion; glue lemmas GL-1..GL-7 named in the review; X8 v3 sections 1.4, 1.6 need a rewrite.
