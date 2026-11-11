# Basis event replay and concrete initialization

The preceding goal turn made progress (U284). This run starts a new separate
obligation, using the checked exception semantics theory without recompiling it.
Prove the exact extraction lemma in U284 NEXT-OBLIGATION.md. Then compose it
without dropping the exception or complete trace. Inspect every failure before
correction; preserve all attempts. Do not modify upstream theories, protected
specification or proof machinery. Keep end_to_end=false. Five failed checks on
the same obligation require stopping unless a separately justified change is
authorized. Fresh direct HOL uses the same pinned toolchain and permissions.
