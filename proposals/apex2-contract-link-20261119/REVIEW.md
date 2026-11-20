# APEX-2: the one fresh-context adversarial review, and the repairs

One reviewer: a separate worker of the same model family on the same
machine, with a new context. It got the files and the statements, not the
author's conclusions. It was read-only. It ran Dafny on scratch copies
(9 mutants, each refused) and Python checks. It did not run HOL. The
repairs below were made in one pass. They were NOT reviewed again.

Findings: 1 FAIL-OPEN, 1 HIGH, 7 MEDIUM, 4 LOW, 3 NOTE.

| # | Severity | Finding | State |
| --- | --- | --- | --- |
| 1 | FAIL-OPEN | `check_link.py --skip-pins` without `--dafny` printed PASS and exit 0 after it checked nothing; with `--dafny` it printed a plain PASS for any override | REPAIRED: `--skip-pins` is CONTROL MODE, exit 3, never PASS |
| 2 | HIGH | no required-key set: a `PINS.json` without the `FlatCore.dfy` key let `--flatcore other.dfy` reach PASS | REPAIRED: 14 required keys; a missing key is exit 1 |
| 3 | MEDIUM | without `--dafny` the check still said PASS with exit 0 | REPAIRED: exit 5, "PARTIAL … not a pass" |
| 4 | MEDIUM | the recorded HOL logs were not pinned and not required to be complete; the check only shows file = log of the same printer | PARTLY REPAIRED: both logs pinned and must hold `FLAT_CONTRACT_COMPLETE`. The limit is STATED (README section 4): the check does not check the printer |
| 5 | MEDIUM | `HolSlice.dfy` was never verified by the check | REPAIRED: option `--slice` with a pinned count; `HolSlice.dfy`, `SliceTheorem.dfy`, `LinkedRefund.dfy` pinned |
| 6 | MEDIUM | Dafny and HOL values are the same only on byte strings; A6 quantifies over all strings; no lemma stated the restricted form | REPAIRED: `ByteInputs`, `A6hbIffA6b` in `HolSlice.dfy`; README section 4 part 3 |
| 7 | MEDIUM | printer controls showed only a hash difference, not a Dafny refusal | REPAIRED in `eval_controls.py`: a printer control counts only when Dafny also refuses it with a postcondition error |
| 8 | MEDIUM | a Dafny control counted on any text with "HolLink.dfy" (an include error would count) | REPAIRED: requires "a postcondition could not be proved" in `HolLink.dfy` and no error elsewhere |
| 9 | MEDIUM | the Holmake port and the stored night-shift theory have the same name `forge_refundExportedContract`; which one loads depends on the path | STATED: the Holmake build loads the port; `RA-FLAT.sml` loads the stored one (it is in the parent list of L2d-0001). `forge_refundFlatContract` does not depend on either. The nine common statements are equal text |
| 10 | LOW | "every UTF-8 sequence" in a comment was misleading: the map is byte = character code | REPAIRED (comment; README) |
| 11 | LOW | the character whitelist of the printer covered the body, not the parameters | REPAIRED |
| 12 | LOW | a missing `PINS.json` gave a traceback; a pin key could leave the repository | REPAIRED |
| 13 | LOW | `check_link.py` finds the repository root only in the `proposals/<package>` layout | STATED |
| 14 | NOTE | `flat_plain_def` was not printed as a statement in the log | REPAIRED: `codes_def` and `flat_plain_def` are printed |
| 15 | NOTE | a consistent double swap of the two ids (inputs and outputs) verifies; it is harmless and undetectable | STATED (README section 4) |
| 16 | NOTE | the comment "A7" of `SliceTheorem.dfy` (link through the export semantics) is now old | STATED; that file is not changed (it is pinned by other records) |

Missing controls named by the reviewer, added: input-side id swap (HN9,
DN12), output-side swap in the link file (DN13), MaxMoney − 1 on the
export (XN5) and on the generated file (DN9), guard conjuncts on the
generated file (DN10, DN11), `FlatPlain := true / false` (DN14, DN15).
NOT added: a control on `SliceTheorem.FlatContract`; Route A controls.

The reviewer's answer on the trust path: the exporter, the HOL S-expression
parser and the Python export reader are off the path of "`refund_fields`
meets the `FlatCore.dfy` contract" (FC1, the printer, D1, D2). They stay
only in FC3, which that path does not need. The build of R1 loads the
stored export theory, and its final statement does not mention it.

The reviewer's list of what must not be called machine-checked:
`dafny_of_term` and the generated file as a rendering of `flat_plain_def`;
`check_link.py`; the identification of values between the two tools; any
"HOL ⇒ A6" claim for all strings.
