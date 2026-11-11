# Exact refund exception compiler composition

Continue U286 and local unsigned commit cf91be0c. Keep original statements,
complete event trace, exceptional postcondition and shared heap frame intact.
Inspect imported premises first. Use published CakeML compiler correctness and
the existing U296 precise-behavior helper. No native recompilation is needed.

The source theorem has an outer existential initial heap frame. Preserve that
quantifier outside the final machine behavior. The only intended helper repacks
the existing final-state event projection into an explicit event-list witness.
Kernel existential elimination must discharge its temporary hypotheses; no
unchecked assumption or new axiom is permitted. Keep every physical/resource
premise and separate logical Success from OS exit0.

Each invocation uses a fresh standard heap and checks pinned parent files before
and after. Run serially to avoid overlapping large HOL loads. Preserve every
failure. Stop after five attempts on one failing proof. U290/U297 stay stopped.
The independent readback is separate from proof production but uses the same
host; it must not be described as clean independent full-chain replay.

CURRENT none. M1 open. Stage12 unauthorized. end_to_end=false.
