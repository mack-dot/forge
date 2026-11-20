# Goal 20, `forge-airlock`: the one fresh-context adversarial review

One reviewer with a fresh context read commit `7812e8a1`. It got the code and the owner's brief. It did not get
the builder's conclusions. It ran its tests in a separate scratch folder and changed no file. It did not start
Dafny. This file records its findings in short form and what was done for each one. `end_to_end=false`.

Counts: 2 FAIL-OPEN, 1 HIGH, 3 MEDIUM, 3 LOW, 2 NOTE.

## Findings

| No. | Severity | Finding (reviewer's result) |
| --- | --- | --- |
| 1 | FAIL-OPEN | A process that can start the engine can give it its own helper folder (`serve --helpers`). A one-line fake `cosign.cjs` that prints `VALID` let a GOODWILL refund of 9000 commit with a junk signature after the private key file was deleted. The documents said less than this, and one sentence ("the launcher pins the helpers") was false. |
| 2 | HIGH | The genesis record had no nonce. Two stores with the same store id, policy and public key had the same state hashes, and one cosign signature committed on both. The sentence "two stores never give the same state hashes" was false. |
| 3 | FAIL-OPEN (SDK) | `read_scoped` / `readScoped` returned the caller's live objects, not the bytes that the engine checked. A row replaced during the wait, an object with `toJSON`, a getter, a `dict` subclass and a change from another thread each gave `OK` with a row of another tenant. |
| 4 | MEDIUM | `init` accepted a small-order Ed25519 public key (`01` and 31 zero bytes). `node:crypto` accepts one fixed signature for every message under that key. |
| 5 | MEDIUM | A lease was bound only to a request id. A policy rejection on an unrelated key with the same request id closed the lease and hid a `DROPPED_OBLIGATION`. Open and close cycles on one id wrote records without a bound. |
| 6 | MEDIUM | The money caps rest on `original` and the facts that the opener of a key chooses, and the tenant is a field that nothing authenticates. No document said that the opener is trusted. |
| 7 | LOW | A read of more than 100000 rows put the SDK out of step with the engine until the timeout (fail closed). |
| 8 | LOW | A sparse array in the TypeScript `readScoped` made the call wait until the timeout (fail closed). |
| 9 | LOW | Some changed copies had a failure text that does not name the removed check (H02; five copies share "system-call order of init"; three share "system-call order of a commit"; M20 "list:"). |
| 10 | NOTE | The read airlock checks only the top-level `tenant_id` of a row. A nested row of another tenant passes. |
| 11 | NOTE | FNV-1a-128 collisions can be computed. The compare-and-swap is a concurrency control, not a boundary against an attacker. No realistic exploit seen. |

## Attacks that did not work in the reviewer's tests

- Read airlock in the engine: duplicate key, `\u0000` in the tenant, other letter case, an array as tenant, trailing
  bytes, 0x85 and U+2028 after the object, nesting deeper than 64, a row that is not an object: all refused.
- Request grammar: leading zero, trailing space, double space, amount 2^63, NUL, CR: all refused.
- WAL recovery: a damaged length field (EPOCH_REGRESSION, no cut), 20 garbage bytes at the end (cut), a ratchet
  one entry short (written again).
- By reading only: cosign with a wrong key, other tenant, other request, moved state, altered action; SDK answer
  matching; the saga pair rule; the binding of `c` to the remaining capacity.

## Areas the reviewer did not cover

`diff-policy` with Dafny; the evidence bundle and the full EXIT script; the demo end to end; `fuzz.py`;
`build_checker.py`; the interposer and kill-point tests; races during `init`; the CakeML wire with ids such as
`True`; deeper TypeScript pipelining after errors; the Stage EXIT and frozen-gate regressions.

## What was done (one repair pass)

| No. | Result | Repair, or the stated limit |
| --- | --- | --- |
| 1 | REPAIRED in code; limit STATED | The two helpers are compiled into the engine (`include_str!`); `serve --helpers` is a usage error. `init --node` pins the SHA-256 of the Node binary in the genesis record; `serve` checks it before the first helper call of a process. The engine pins the refund binary. Stand-in helpers and binaries work only in the `kill_points` build. Limit that no code removes: every rule holds only against a caller that reaches the store through the engine. A process that can write the store folder, or run its own engine on it, can ignore every check. The documents now say that "the agent cannot self-cosign" needs both the private key out of the agent's reach and an agent that cannot write the store folder or run another engine. A file swapped after its hash check is not detected. |
| 2 | REPAIRED | `init` puts 16 random bytes in the genesis record. The cosign message (now version 2, six lines) binds the genesis hash. Two stores with the same id, policy and key now have different hashes, and a signature for one is refused on the other. |
| 3 | REPAIRED | Both SDKs serialize each row once, send those lines, and return parsed copies of exactly those lines. |
| 4 | REPAIRED | `init` and `cosign.cjs verify` refuse the 14 small-order or non-canonical key encodings and every y >= p; `verify` also refuses such an R in a signature. |
| 5 | REPAIRED | A lease is bound to (request id, tenant, key). One lease per request id, ever. Only a terminal verdict for the same id on the same tenant and key closes it. `leases --all` shows which verdict closed a lease. |
| 6 | STATED | `PROTOCOL.md`, the quickstart and the demo say that the opener of a key is trusted for `original`, the facts and the tenant, and that the tenant field is not authenticated. No code change. |
| 7 | REPAIRED | The SDKs refuse more than 100000 rows before they send anything. |
| 8 | REPAIRED; no separate test | The TypeScript SDK reads rows by index and refuses holes. The changed copy without this guard is NOT killed alone: the serializer refuses an undefined entry with the same answer. It is in the `not_killed` list of the bundle. |
| 9 | REPAIRED | Each changed copy has a failure text that names its removed check. The EXIT script refuses two copies in one case with the same text; one exception is listed with its reason. |
| 10 | STATED | The documents say that only the top-level `tenant_id` is checked. |
| 11 | STATED | The documents say that FNV-1a-128 is a concurrency control, not a boundary against an attacker. |

Each repair of findings 1 to 5 and 7 has at least one changed copy in the EXIT script that removes it (group R).
No second review of the repairs ran: the directive asks for one review. The repairs are therefore the builders'
own work, checked by the suites and the changed copies only.
