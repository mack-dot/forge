# U338 assurance matrix

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| Previously transferred1475+18 inputs | TESTED, retained | U335/U336 evidence unchanged. No download occurred in this attempt. |
| Three previous integrity mutation controls | TESTED, retained | In-process ValueError rejections; no separate process exit codes. Enclosing integrity checker exit0 only. |
| Exact approved workflow publication | TESTED | Frozen SHA1af894a0…; remote byte/blob identity,parent and sole changed path checked before one lease-checked trigger. |
| One authorized job only | TESTED | Run42661020831,attempt1,one job129312292711,one run at headf1e4a080. No retry. |
| Terminal provider outcome | OBSERVED | Run failure; job cancelled; runner_id0,empty runner name,no steps. These are not OS exit codes. |
| Pinned image and environment execution | NOT_ESTABLISHED | No assigned runner. Image guard and resource probes did not execute. No substitution. |
| HOL theorem/repeat/import | NOT RUN | No actual exits,theorem statement,exports or dependency closure. No theorem pass or counterexample. |
| Two negative HOL controls | NOT RUN | No actual child exits. Expected1/1 are not observations. |
| Resource usage | PARTIALLY_OBSERVED | Provider902000ms elapsed,0 billable MACOS ms. Actual proof CPU/peak RSS unavailable. |
| Raw logs | UNAVAILABLE | Job-log request404 BlobNotFound preserved. No decoded log or invented log hash. |
| Precise scheduler cause | UNKNOWN | No runner assignment observed. Check-run reason route rejected by connector400. |
| Separate terminal evidence reader | TESTED | validate_terminal.py0; independent code from producer,not independent administrative control. |
| Protected paths and prior evidence | TESTED | 50 protected hashes,mission and217 U333–U337 packet members match. |
| Provider/control plane,connector,hash implementation | ASSUMED | Provider metadata and data transport remain trusted; no new formal assurance. |
| Native memory/frame,whole-program composition,21-snapshot replay | NOT_ESTABLISHED | Separate tasks,not attempted. |
| M1 full software correctness | NOT_ESTABLISHED | M1 open; end_to_end=false. |

Next boundary:an assigned runner that passes the frozen image guard,under
separate authorization for any additional attempt. No new proof scope proposed.
