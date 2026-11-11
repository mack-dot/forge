# Request consumption in Stage 9 (audit; no change proposed)

## Four separate events

| Event | Where | Effect |
| --- | --- | --- |
| One-time authorization consumption | `release.py --admit` or `observe.py --case accepted`: `BEGIN IMMEDIATE`, `pending()`, …, `UPDATE requests SET state='consumed'`, `COMMIT` | The request can never be admitted again |
| Signature and binding verification | `release.verify()` (Cosign, statement, evidence, receipt, package, `repository_identity`, `run_identity`, `approved_lineage`), inside the same transaction, before the `UPDATE` | Any failure rolls back; the request stays `pending` |
| Deployment observation | `observe.observe()` after the `COMMIT`: container create/start, inspect, read as UID 1000, inspect, checks | Writes `observation.json` |
| Final release acceptance | `observe.py` result `observed_deployed_file_identity` (EXIT `deployed-identity` passes only with it) | The only success record |

## Failure-state table (tested on copies: `results/stage9/v36-consumption-0001`)

| Failure point | Request after | Release accepted | Same request reusable | Tested |
| --- | --- | --- | --- | --- |
| Request already consumed | consumed | no (`STALE_OR_CONSUMED_REQUEST`) | no | yes, `release.py --admit` and `observe.py accepted` |
| Verification fails | pending (rollback) | no | yes | yes (`REQUEST_IMPLEMENTATION`) |
| Process killed before `COMMIT` | pending | no | yes | yes (`os._exit` after `UPDATE`) |
| Second admission during the first | pending until the first commits | no (writer locked out) | — | yes (`database is locked`) |
| `COMMIT` done, container create/start fails | consumed | no (`result: rejected`) | no | by code reading |
| Observation fails (unreadable, mismatch, mount, isolation, race) | consumed | no | no | only the "unreadable" case after a real admission (EXIT `deployed-identity` attempt 0001, U164); the other observation failures were tested without admission (`v36-deploy-0001`) |
| Process killed after `COMMIT` | consumed | no | no | by the independent reviewer on its own database copy: retry gets `STALE_OR_CONSUMED_REQUEST` |
| Process killed after the container starts | consumed | no | no | not tested; the container keeps running (cleanup needed) |
| `result.json` cannot be written after `COMMIT` | consumed | no (reported as rejected) | no | not tested |
| Observation passes | consumed | yes, once | duplicate refused | EXIT gate `duplicate-admission` expects `STALE_OR_CONSUMED_REQUEST` |

No tested failed or interrupted operation admitted a request twice or recorded an accepted
release. Consumption is a single committed row change under `BEGIN IMMEDIATE`, after `pending()`
read the row in the same transaction. `release.py` also guards the `UPDATE` with `state='pending'`
and checks the row count; `observe.py` does not, and relies on `pending()` under the same lock.
Acceptance needs a later successful observation. These tests support fail-closed behaviour for the
cases listed; they are not a proof for every crash or concurrency interleaving (for example, a
concurrent gate fails after SQLite's 5 s busy timeout instead of waiting).

## Assessment

The behaviour is intentionally fail-closed: the authorization is spent before any container
starts, so a deployment can never run under a request that could still be admitted elsewhere.
The cost is recovery: any failure after the `COMMIT` (Docker error, observation failure)
spends the request. A new request needs a new R1 (its run name carries the challenge) and, for
the full EXIT set, a new R2: 7 more permanent Rekor entries per retry.

Not changed here. Moving consumption after the observation would need the write lock held
across Docker operations, or a new intermediate state (for example `deploying`), and a new
argument for why that cannot admit twice. That is a design change for separate approval.
