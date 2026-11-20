# Goal 21 (Gate F1), intent clearing: the one fresh-context adversarial review

One reviewer with no context of the build read the code (not the builder's conclusions) and ran 7
`check-intent` runs against it. The directive asks for one review. The repairs below were made in one
pass. NO second review ran. `end_to_end=false`.

Counts: 1 FAIL-OPEN, 0 HIGH, 2 MEDIUM, 7 LOW, 3 NOTE.

| # | Severity | Finding | State |
|---|---|---|---|
| F1 | FAIL-OPEN | A query with reason ids that the specification does not name: every such id became the one class OTHER, and `!=` on such an id was dropped. `reason == FOO && reason != FOO` and `reason == FOO && reason == BAR` got a WARNING with a "verified" witness. Dafny had verified the rewritten atoms, not the question. It could not give exit 0; it gave a false warning. | REPAIRED: such a query gets the atom `0 == 1` and the answer `NO`, with a note. Re-run of the reviewer's input: both `NO`. |
| F2 | MEDIUM | The table printed `OTHER` for an unnamed reason; a specification can name a reason `OTHER`. Two rows looked like one input with two verdicts. | REPAIRED: the label is `(unnamed)`, which no id can spell. |
| F3 | MEDIUM | Changed copy C04 named the reason `LINK_BROKEN: Probe.dfy: refused=`, a text that every broken link prints. Its description said "refused word"; the kill came from the audit. | REPAIRED: the reason is the observed line `refused=None audit_exit=2`; C06, C12 and C15 also name the exact observed line. |
| F4 | LOW | The evidence case passed when the tracked record was absent. | REPAIRED: it fails; `--write-record` writes the record. |
| F5 | LOW | The bundle did not bind the imported code (`spec_clearing.py`, `diff_policy.py`, `policy_model.py`, `gate/common.py`, `gate/backends/dafny.py`, the audit baseline). | REPAIRED: all six are subject files. |
| F6 | LOW | No changed copy removed five guards. | PARTLY REPAIRED: two copies added and killed (C19: the `!Allowed` half of a row lemma; C20: a row shown without a passed lemma). NOT covered by a changed copy: the check that every row named by Coverage is verified; the member-presence test of `link_ok`; "empty needs both lemmas" (the lemma without defaults alone is enough for soundness). |
| F7 | LOW | A specification named `expect` or a reason named `include` gave LINK_BROKEN (fail closed, but a valid input could not be cleared). | REPAIRED: the header comment of the model leaves the ids out in that case. |
| F8 | LOW | `--request` text was printed raw; a line `RESULT: CLEAN (exit 0)` or an escape byte could appear in the output. | REPAIRED: a request with a character that is not printable is refused; every line is printed behind `\| `. |
| F9 | LOW | The restater said "every amount is covered by at least one rule (facts permitting)" when the only rule can never match. | REPAIRED in words only: the bullet now says that it reads amount intervals of rules of any verdict and that a rule whose facts can never hold still counts. The table's DEAD RULE warning shows such a rule. |
| F10 | LOW | The EXIT script counted the line `RESULT: PASS` as a case. | REPAIRED. |
| F11 | NOTE | The restater child could read its script path and its work folder name. | REPAIRED: the child gets its source with `-c`, the folder `/`, an empty environment. |
| F12 | NOTE | The loader accepted `"max_reason_total_fact": null`. | REPAIRED: refused. |
| F13 | NOTE | Run time has no bound: 385 cells took 138 s and 29 Dafny starts in the reviewer's run. | STATED ONLY (DESIGN.md, section 12). |

What the reviewer tried and did not break (the reviewer's report, not checked again by the builder):
no path to exit 0 without every cell decided, the seal proved and every query proved `NO`; row lemmas pin
all 7 verdicts; the readability defaults cannot turn a satisfiable query into `NO`; a vacuous model is
LINK_BROKEN; ids reach Dafny only inside one comment; edge values at the maximum amount; two runs
byte-identical; no absolute path in the output.

The builder re-ran these after the repairs: the reviewer's F1 input (both answers `NO`); both suites; the
changed copies; the planted pairs; the dispatcher case. The actual exit codes are in
[REPORT.md](REPORT.md).
