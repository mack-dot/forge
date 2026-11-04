# Refund modeled I/O contract

CURRENT stage: none. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. Parent documentation commit: `a5e974b5`.
This proposal is local and unadopted. It does not establish native execution.

## Checked behavior

The proposed `refund_main` reads stdin with the published TextIO implementation,
calls the checked strict wire dispatcher, and prints its returned string.
The source build proves two application contracts:

| Theorem | Premises and result |
| --- | --- |
| `refund_main_valid` | If modeled stdin contains `text` and the strict wire function returns `INR output`, the call returns unit and appends exactly `output` to modeled stdout after consuming stdin |
| `refund_main_error` | If modeled stdin contains `text` and the wire function returns `INL err`, the call raises `Fail err`; modeled stdout stays unchanged and stdin is consumed |

The seven prior wire theorems bind every valid serialized request to the
complete six-field refund result. They preserve decoding failures and reject
malformed or trailing input. The full approved request domain is not narrowed.
Model strings remain byte strings and integers remain mathematical integers.
The complete Unicode/source/native binding remains open. Refund intent is a
returned field, not a bank operation.

These are CF application contracts for the proposed implementation. The original
generated method and old wrapper remain unchanged. Whole-program initialization,
an exact compiler result and concrete runtime correspondence are separate links.
The new whole-program build is recorded separately in the raw experiment. No
whole-program result is claimed by this packet.

## Real checks

Commands ran from `/Users/mackianni/forge`. `OUT` denotes
`results/refund-stdio-composition-2026-11-04/attempt-0001`.

| Command or child check | Actual exit | Result |
| --- | --- | --- |
| `run_diagnostic.py diagnostic-0005/0006/0007/0008` | 1/1/0/0 | Saved-goal diagnostics; no theory export |
| `run_stdio.py stdio-0004` | 0 | Both modeled I/O contracts checked |
| Swapped response IDs | 1 | Required refusal at `refund_render_fields_roundtrip` |
| Trailing-input error changed to success | 1 | Required refusal at `refund_run_wire_decode_error` |
| Suppressed dispatcher exception | 1 | Required refusal at `refund_dispatch_error` |
| `run_wire_controls.py` / wire repeat child | 0/0 | All reasons checked; six identical wire exports |
| Suppressed stdout write | 1 | Required refusal at `refund_main_valid` |
| Stdin replaced by a named file | 1 | Required refusal at `refund_main_valid` |
| `run_stdio_controls.py` / I/O repeat child | 0/0 | Both reasons checked; six identical I/O exports |
| `readback_io.py` | 0 | Exact records, five refusal reasons and 30 frozen inputs checked |
| `run_closure_io.py` | 0 | Fresh import and closure inspection |
| `dependency_io_snapshot.py` | 0 | 229 theory file sets plus kernel/heap identities recorded |
| Closure readback | 0 | 230 nodes; 39 exported theorem tags with zero hypotheses; four foundation axioms |

Each runner is invoked with `python3 -B "$OUT/<runner>" <arguments>`.
Exact argv, working directories, source snapshots, logs, exit codes and object
hashes are in `records/`. All negative builds lacked an accepted theory export.
Their exit 1 values are checker failures, not refund process exit statuses.

Earlier I/O attempts 1–3 remain preserved in the previous wire packet. This
fourth full attempt changes only proof tactics. It unfolds the existing option
representation instead of supplying an incompatible typed witness, then uses
published computation tactics to discharge constructor matching obligations.
No program behavior, specification, semantics or axiom changed for that repair.
Diagnostics 5–8 remain preserved, including failed tactic steps and post-proof
goal-inspection errors. Diagnostic success alone did not authorize a proof claim;
the complete source build and repeat provide the accepted local result.

## Exact identities and trust limits

- I/O source SHA256:
  `6f7aa17a5c671d83c94d2726932a7757083e30ee5508cce64f667f43138e0a68`.
- I/O theory data SHA256:
  `8971cd15449d1edbd0836aaba9f7339cd3a3da01268103cccd317d4df8054255`.
- Wire source SHA256:
  `417b69d41a58da1ab3831e25cc3cf4ec6db7c0fcafd8af50be0caf9fd2306fb9`.
- Wire theory data SHA256:
  `17482ed974f856688298b957aee8d5155b5d56e2a104bbe3ec2a02056a690ae1`.

The pinned CakeML and HOL tracked sources and the original wrapper are unchanged.
The closure retains `SELECT_AX`, `INFINITY_AX`, `ETA_AX` and `BOOL_CASES_AX`.
Imported `DISK_THM` objects remain an explicit trust boundary. This inspection
does not replay every upstream source or constitute independent human review.
A digest identifies bytes; it does not authenticate their producer.

Published source semantics uses `Terminate Success` for outcomes that are not
timeouts, type errors or separately classified FFI failures. It is not a POSIX
exit-code theorem. In particular, a modeled exception does not establish a
nonzero native exit. Native controls must record actual status, stdout and stderr.

The separate [native audit follow-up](../native-audit-followup-20261104/REPORT.md)
is preserved from local commit `3c5bb8ca822d2078e85c2f2533f1191b62efd8f9`.
Its thread owns the reported local ad-hoc signing authorization and eventual
native linking/controls. This proof work remains unsigned. The approval does
not authorize release signing, publication, deployment or protected adoption.

## Next required link

Use the published whole-program bridge to bind this exact program to initialized
library state and its main entry point. Require a substituted entry point to
fail and require positive reproduction. Then use the existing in-logic arm8
compiler and retain every resource, installation, FFI and runtime premise.
Do not infer physical execution or full Unicode correspondence from modeled I/O.

Native refund execution, hosted refund measurements and new admission are
NOT RUN. Exact claim/profile review and independent-copy archive hash/restore
remain open. GitHub was not refreshed for these local checks. No acceptance
policy or branch setting changed. M1 and integration EXIT remain NOT_ESTABLISHED;
M2–M4 remain subsequent work. No performance improvement is claimed.
