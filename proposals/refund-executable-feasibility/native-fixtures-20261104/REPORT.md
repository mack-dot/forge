# Kernel-checked refund wire fixtures

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
This packet checks fixture expectations and exact serialized bytes in fresh HOL
processes. No native refund executable has been linked, signed or executed.
U262 and commit73728c2 remain reused. The completed Unicode proof did not rerun.

| Executed operation | Actual exit | Result |
| --- | --- | --- |
| `prepare_batch.py` | 0 |22 frozen cases; no new refund or codec implementation |
| Initial `run_batch.py` (record direct-0001) | 1 |Default-heap library loading fails in intLib/TAUT_PROVE |
| `run_batch.py direct-0002` | 0 |Explicit pinned CakeML heap;88 evaluation theorems;44 wire files |
| First control preparation / dependent dispatch | 1/1 |Wrong string split; then absent script; both preserved |
| Corrected control preparation | 0 |Two expected refusal claims and six malformed inputs prepared |
| `run_batch.py malformed-0002 .../malformed.sml` | 0 |Six exact error results and six exact input-byte equalities |
| Wrong expected amount / swapped expected caller IDs | 1/1 |Required EQT_ELIM refusal before any fixture theorem marker |
| `run_batch.py direct-repeat` | 0 |Same source; all44 typed input/output files byte-identical |
| First / corrected fresh closure inspection | 1/0 |Missing Thm qualifier fixed; failed diagnostic preserved |
| `readback.py` | 0 |Commands, markers, files, dependencies and protected inputs checked |

Commands and their full output are under `records/`. Original raw location:
`results/refund-native-audit-2026-11-04/attempt-0003/`.
The two earlier Holmake EPERM failures remain in attempt0001. They were not
rerun or redirected. The pinned HOL executable documents a direct `run` command.
This experiment uses that interface and its existing evaluator, with explicit
`--holstate=.../cakeml/misc/cakeml-heap`. No build-tool source, permissions,
temporary-path implementation, kernel rule or axiom changed.

## Established fixture evidence

The22 cases retain the frozen explicit expectations from the initial native
audit. Fresh HOL evaluation checks both `refund_fields` and `refund_run_wire`
against those expectations. It then evaluates the published `sexp_to_string`
and result renderer to exact HOL strings. The existing `stringSyntax` and
standard binary I/O operations materialize those strings as files.

Coverage includes all three allowed reasons, zero and maximum accepted amounts,
Unicode scalar boundaries, NUL/escaped caller IDs, both empty IDs, disabled or
closed context, non-candidate response, invalid reasons, over/under bounds and
integers with magnitude2^256. Eight cases authorize a refund. Fourteen produce
the modeled rejection tuple. They are all well-formed protocol requests.

The six additional malformed inputs cover a trailing newline, a second request,
an unclosed expression, an empty stream, missing fields and an invalid integer.
HOL checks each exact `INL` error result. The modeled stdin/stdout error theorem
is separate evidence for no result output on these inputs. A proof-checker
exit1 is not an application process exit1. Native error status remains open.

There are100 newly evaluated theorems:88 for the typed cases and12 for malformed
inputs. The typed repeat performs the same88 evaluations again. The source
batch SHA256 is
`7f73ec356cbb83dbe6fc212c8b9bc1ebd1a671681bb31c21c3151af00a8ede5c`.
`wire-manifest.json` names50 exact files:28 inputs and22 expected outputs.
The44 typed files match the independently saved first and repeated runs.
These are fixture proofs. They do not replace quantified behavioral proofs.

## Dependencies and trust

The pinned HOL executable SHA256 is
`736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd`.
The pinned CakeML heap SHA256 is
`36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`.
The final direct inspection finds229 theory nodes,228 disk-theory file sets,
and36 exported wire-theory tags. The tags have DISK_THM, no explicit hypotheses
and no separately tagged axioms. The closure contains the existing four HOL
foundations:SELECT_AX, INFINITY_AX, ETA_AX and BOOL_CASES_AX.

The audit rehashes the dependency files against the prior I/O snapshot. It does
not replay every imported proof source, authenticate a producer, or establish
independent human review. HOL's kernel, imported proof data and pinned heap,
Poly/ML, host execution, fixture materialization and record transport remain
explicit trust dependencies. The source Unicode theorem remains the evidence
for full-domain UTF-8 representation; Python's fixture codec is not that proof.

All50 frozen protected paths and the mission bytes still match. The original
516530-byte uncertainty-log prefix remains intact. The default-heap load failure,
preparation assertion, missing-script dispatch and first closure diagnostic are
preserved. None counts as an intended negative-control success.

## Next check

Bind the exact compiler byte/data/configuration theorem and generated assembly
to the final native artifact. Run these frozen inputs against that artifact,
capture exact stdout/stderr and process status, and check native reproduction
and mutations. The whole-program error path, installed code/FFI state, finite
resource assumptions, real OS I/O and source/model assurance binding remain
open. U269 permits only the needed local ad hoc signature. No release signing,
deployment, protected adoption or Stage12 is authorized.
