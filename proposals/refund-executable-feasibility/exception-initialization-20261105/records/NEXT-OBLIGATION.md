# Next source-to-target exception experiment — NOT RUN

Use the accepted `forge_refundRejectBasisTheory.refund_error_initialized_semantics`
from concrete-0001, data
`3c358b38b4617b8b29349fb90200c639150a582a8da6aad2c78bee092e7a8f28`.
Use the existing exact `refund_arm8_compiled` theorem. Do not compile again.

1. Prove a small logical projection into the existing compiler theorem's
   `sem_satisfies (...)(λb. ∃io. b = Terminate Success io ∧ P io)` form.
   Let P retain the exact final-state event equation, Fail_exn witness,
   initial/final heap frames, RTC call_FFI_rel and extract_fs equation.
   Do not replace P with only output bytes or a trivial termination claim.
2. Apply the published compiler correctness rule and the checked generic
   `precise_sem_satisfies_IMP_Terminate` composition from U296. Inspect the
   instantiated conclusion and every premise before saving it.
3. Preserve installed-code identity, ARM8 configuration, FFI, read_limits,
   memory and safe-for-space conditions. If resource adequacy is absent, retain
   the compiler's permitted Resource_limit_hit prefixes. Do not claim complete
   events for such prefixes. Any precise theorem must state its space premise.
4. Repeat and import the unchanged accepted statement. Control a changed
   executable/program identity, an omitted space premise and a shortened trace.

This is a conditional logical bridge, not a discharge of physical runtime
premises. U300's exact word-state space/non-error and lower-pass event bridge
remain separate. Do not retry the stopped U290/U297 strategies. A complete
physical C/POSIX/ARM8/OS relation and independent clean replay are still needed.
Keep logical Success separate from OS exit0. Keep end_to_end=false.
