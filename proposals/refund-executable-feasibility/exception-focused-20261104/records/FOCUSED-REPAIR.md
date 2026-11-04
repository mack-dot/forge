# Evidence for a changed proof approach

The branch diagnostic returned0 as an inspection. Its final goal still contains
`case do_opapp [refund_main_v; Conv NONE []] of ...`. The assumptions contain
`SOME (env,exp) = do_opapp [refund_main_v; Conv NONE []]` and the exact evaluation
result for `(env,exp)`. Every individual preceding rewrite completed. The full
branch remains unsolved; it is not a semantic counterexample.

Check the orientation issue in one small generic lemma, outside the full refund
theory. The lemma only propagates the given application lookup and evaluation
result through that case expression. Use the existing HOL kernel and definitions.
It introduces no axiom, input restriction or machinery change.

If this lemma passes, use the observed equality explicitly in the existing
declaration branch. This is a separately justified repair of the concrete
residual expression, not another blind attempt with the old tactic sequence.
Retain the five original failures, both successful inspections, and every new
result. Do not call inspection exit0 a theorem result. Do not infer a native
process-status theorem from this source-level exception lemma.
