# U380: clock-zero case of the strengthened simulation proved; P3 still not established

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents.

The request for this run arrived truncated (it ends at "Work") and names U376
as the start. Work continued from U379 with the next obligation recorded
there.

## Result

Theory `forge_simZeroCase`, PROVED (`DISK_THM` only, no hypotheses, no tagged
axioms; exact-statement import):

- `install_entry_distinct`:
  `∀p x. x + 2 * ffi_offset < dimword (:α) ⇒ p + n2w x ≠ p − n2w (2 * ffi_offset)`.
- `state_rel_no_install_prefix_zero`:
  `state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ∧ pos_val s1.pc 0 code2 + 2 * ffi_offset < dimword (:α) ⇒ no_install_prefix mc_conf ffi 0 ms1`
  (`α` is the word size of `p`).
- `install_entry_wrap_example`: an 8-bit instance where offset 224 lands on
  the installer entry, so the bound cannot be dropped from the arithmetic
  lemma.

Answer to the open question of U378: the published `state_rel` gives the
target counter as `p + n2w (pos_val s1.pc 0 code2)` and the installer entry as
`p − n2w (2 * ffi_offset)`. It does not bound `pos_val`. So the clock-zero
case needs a layout bound. The published `installed` predicate has one
(`cbspace + LENGTH bytes + ffi_offset * (i + 3) < dimword`), but it is not
part of `state_rel`.

Consequence for the PROPOSED strengthened `compile_correct` (U378): it needs
one more premise, a layout bound of this kind for every lab state on the run
(for example `LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword` with
`pos_val ≤` that length). The statement of U378 is therefore not provable as
written. It is not yet restated; that is the next obligation, before the
per-segment lemmas.

## Failed attempts and corrections

- `zero-0001` exit 1: a failing proof attempt of
  `state_rel_no_install_prefix_zero` (first of at most five). Cause, shown by
  `explore-0005`: the agent's statement typed the bound at a word size that
  was not tied to `p`; the kernel left the goal at a different type variable.
  The statement was corrected (bound at the word type of `p`), not weakened.
  `zero-0002` exit 0.
- `explore-0002` exit −24: a tactic with open proof search ran to the 600 s CPU
  limit. Resource stop, not counted.

## Executed commands

Run directory: `results/refund-p3-clock-zero-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py explore-0001` | 1 | SCRIPT ERROR: undeclared definition name. Not counted |
| `run_case.py explore-0002` | −24 | CPU-limit resource stop; not counted |
| `run_case.py explore-0003` / `0004` / `0005` | 0 / 0 / 0 | Staged; `0005` shows the type defect |
| `run_case.py zero-0001 …` | 1 | Failed proof attempt (statement defect); nothing exported |
| `run_case.py zero-repeat` | 1 | Repeat of the failed source |
| `python3 -I -B run_case.py zero-0002 zero-0002.sml …` | 0 | Three theorems |
| `run_case.py zero-import` | 0 | Three exact statements, 294 closure nodes; the statement without the bound is not the stored one |
| `run_case.py zero-repeat-0002` | 0 | Exports byte-identical |

Source SHA256 `6fded3dfb06a141877cba1eab9e11331dd5e369779a60c43c7a0ee5fb44e7fec`;
theory data `98325415a4c9d4921e6a0ba1fb14cf54c91045f211a32b08bbc936815fccb24d`.
No separate evidence reader was written for this small packet; `MANIFEST.json`
lists every member with its hash. Clean replay: NOT_RUN.

## Status

P3: NOT ESTABLISHED. Target-level installer exclusion: NOT ESTABLISHED. All
six installed-state obligations: OPEN.

Next smallest obligation: restate the strengthened `compile_correct` with the
layout bound, check that the bound is preserved along a lab run, then the
strengthened `asm_step_IMP_evaluate_step`.
