# Inspection-only exception diagnosis

The user requires inspection of all five failures and permits a separately
justified change of approach. U274 remains the record of five failed checks.
No full lemma retry or theorem export is authorized by this diagnostic.

The third source build records only a composite tactic failure. The first two
diagnostics stop at a renaming operation that the third source removed. Thus
neither log identifies the third source's first failing operation. Static
comparison with cfMain.call_main_thm1 cannot establish that location.

Run one trace from the preserved third heap. Use the already-failed source's
prefix, split into named operations. Stop at its first failure or before the
main-call proof branch. Print the exact open goals. Do not replace a tactic,
continue after a failure, save a theorem, change a premise, or rebuild a theory.
Exit 0 means only that the inspection completed. It never means the lemma passed.
Any later proof must first target the isolated obligation under a new recorded
justification. Preserve all five original records and both original heap hashes.
