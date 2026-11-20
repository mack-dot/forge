# universal_self_repair: propose, dispose, self-repair

A scripted agent, no model. The agent makes the four mistakes of the V1.1 directive. The primitives engine v2
refuses each one with a structured, repairable answer. The agent computes its next proposal from that answer and
the engine accepts it. At the end the demo reads the whole store back and reconciles it exactly.

Labels: **NATIVE CHECK** (the engine `src/primitives_v2` is unproved Rust), **FINITE TEST** (this demo and
`tests/primitives_v2/test_demo.py` show one scenario per run). Nothing here is proved. `end_to_end=false`.

## Run

```sh
/Users/mackianni/.cargo/bin/rustc --edition 2021 -D unsafe_code -C opt-level=3 src/primitives_v2/main.rs -o build/primitives_v2/primitives-engine
python3 examples/universal_self_repair/run_demo.py [--engine build/primitives_v2/primitives-engine] [--json OUT] [--scenario FILE]
python3 examples/universal_self_repair/run_demo.py --canary NAME      # one deliberately broken run: its check must FAIL
python3 examples/universal_self_repair/run_demo.py --self-test        # every canary, one fresh run each
python3 tests/primitives_v2/test_demo.py build/primitives_v2/primitives-engine
```

Python standard library only. The demo talks to the engine only through `sdk/py/forge_primitives.py` (one
`serve` process), plus the engine's own `init` and `replay` commands. Each run makes a fresh store in a new temp
folder and deletes it at the end. Use the production build. The demo never uses the test-seams build.

Exit codes: 0 every check passed; 1 at least one check failed; 2 the engine is missing, is not executable, or
`init` failed (a loud `FATAL` line, no check table, no results file); 3 the engine or the SDK raised a fault during
the run.

## What the screen shows

| Tag | Meaning |
| --- | --- |
| `ENGINE` | the engine's answer line, as received. State hashes are cut to 12 hex on screen; nothing else changes. |
| `agent` | the scripted agent's proposal (theatre). |
| `repair` | the output of the generic repair function (see below). |
| `note` | explanation text. |
| `DEMO CHECK` | a Python check in this script. It is NOT an engine verdict. |
| `CANARY` | a deliberately broken run (only with `--canary`). |

## The mistakes and the repairs

| # | Mistake | Engine answer | Repair (computed from the answer's fields) |
| --- | --- | --- | --- |
| 1 | a burst of `max_ops_per_window + 1` acquires | `RATE_LIMIT_EXCEEDED retry_after_ms=` (when this refusal starts the cooldown, the wait covers the cooldown too) or `COOLDOWN_ACTIVE retry_after_ms=` | sleep `retry_after_ms` in real time, send the rest of the burst |
| 2a | a posting whose credits and debits differ | `CONSERVATION_BREACH debit_total= credit_total=` | cut the larger side by the difference, from the last leg in key order; a leg cut to 0 is dropped |
| 2b | an edge batch where one edge closes a cycle | `DAG_CYCLE_DETECTED edge= cycle_len= index=` | drop exactly edge `index` (it must equal `edge=`) and send the rest of the batch |
| 3 | a document with nested `PHI` (and `SECRET_KEY`) fields to a public sink | `TAINT_EGRESS_BLOCKED json_path= label= more=` | remove exactly the node at `json_path` (steps `.name`, `.~rank`, `[i]`, `@` for JSON inside a string) and send again |
| 4 | "no schedule exists" with a bad Farkas certificate, for a system that IS feasible | `CERT_REJECTED claim=INFEASIBILITY_NOT_PROVED reason=` | withdraw the claim; a scripted brute-force search finds x; a DEMO CHECK confirms `A x >= b, x >= 0`; the agent accepts the job (a registry `claim`, an engine commit) |
| 4b | a TRUE infeasibility claim with a valid certificate | `OK verdict=INFEASIBILITY_PROVED scope=nonneg_integer_x` | none needed; the agent declines that job |

`repair(proposal, code, fields)` in `run_demo.py` is the only source of repaired proposals. It gets the agent's
own last proposal, `Refusal.code` and `Refusal.repair` (the decoded `key=value` fields). It never reads the human
detail text or the answer line. It holds no scenario value. `test_demo.py` runs it on other scenarios (case
`alt_params`: other limits, a cooldown, a debit-side excess, another cycle edge, three taint paths including one
inside a JSON string, another destination, another Farkas system; case `seeded_params`: a scenario generated from a
seed) and checks the repaired proposals against the values the refusal fields imply.

`INFEASIBILITY_PROVED` is the engine's word. It is a native check of the certificate (unproved Rust that mirrors
the Dafny predicate `FarkasCert.Accepts`; see `src/primitives_v2/farkas.rs`). Its scope is non-negative INTEGER x.
The demo does not run Dafny.

## Final checks

| Check | What it compares | Canary that must make it FAIL |
| --- | --- | --- |
| `mistakes_refused` | the first answer of each mistake is the expected refusal code | `no_mistake` |
| `repairs_accepted` | every task ends in an engine success within 6 turns | `bad_schedule` (also) |
| `true_infeasibility_proved` | the engine answered `INFEASIBILITY_PROVED` for the true claim | `weak_true_cert` |
| `schedule_satisfies_system` | DEMO CHECK: `A x >= b, x >= 0` for the submitted schedule | `bad_schedule` |
| `records_equal_commit_answers` | (seq, request id, primitive, op, tenant, keys, effect) of every `C` record in `replay` equals that of every `COMMITTED` answer; the counts are equal | `extra_record`, `dropped_answer` |
| `refusal_records_equal_durable_refusals` | every `R` record equals a durable refusal answer | `dropped_refusal` |
| `every_record_explained` | `STATE seq` = last record; every record after genesis is exactly one answer | `extra_*` (also) |
| `balances_equal_ledger` | `GET` balance of each account = the ledger built from `COMMITTED` effects | `balance_tamper` |
| `total_supply_constant` | sum of balances = opening supply; engine `ledger_total = ledger_issued`, `destroyed = 0` | `balance_tamper` (also) |
| `edges_equal_ledger` | edges folded from `replay` = edges from the answers; `GET` nodes and edges counts | `extra_edge` |
| `registry_equal_ledger` | registry names from `replay` = names from the answers; `GET claims=` | `extra_claim` |
| `rate_equal_ledger` | `GET ops= volume= rejections=` = the values computed from the answers at the `GET` answer's `now_ms` | `extra_acquire` |
| `hashes_equal_last_answer` | `GET` state hash of each key = the record hash of the last answer that named it | `extra_*` (also) |
| `zero_secret_bytes_in_sink` | the sink file holds no secret and no 8-byte piece of one | `secret_in_sink` |
| `zero_secret_bytes_in_engine_output` | every engine answer line (with the refusal detail texts) and the `replay` output hold no secret and no 8-byte piece of one | `secret_in_answer` (a `GET` of a key that holds the secret: `OK key=` echoes the caller's own key; engine refusals name `key_index`, never the key) |
| `blocked_documents_never_in_sink` | every sink entry is the exact bytes of an `ALLOW` answer (SHA-256 and length); no blocked document is in the sink | `blocked_doc_in_sink` |

"0 bad writes" means: every record in the store is explained by one engine answer that the demo received, and the
store state equals the ledger the demo kept from those answers alone. The secrets are random per run (`Zq` + 22
letters and digits). Case `canary_coverage` of `test_demo.py` checks that every check FAILED under at least one
canary.

`--json OUT` writes a results file. Everything outside the key `measured` is the same in two runs (case
`determinism`); `measured` holds times, waits, latencies, `now_ms` values, state hashes and the check evidence.

## Limits

- Scripted agent, no model. The demo shows that the refusals carry enough structure for a mechanical repair. It
  does not show how a language model behaves.
- rate_window limits a key; the key and tenant must be bound by a trusted wrapper outside the engine. The demo
  agent names its own key and tenant; a fresh key, or another tenant name (not authenticated), has its own empty
  window and no cooldown (PROTOCOL.md sections 9 and 15; review finding M2).
- The engine trusts the host clock. The rate wait is real time; on a loaded machine a stall longer than
  `window_ms` during the burst would let the burst through, and then `mistakes_refused` FAILS (it is not hidden).
- The schedule of mistake 4 is checked by the demo in Python (`DEMO CHECK`), not by the engine. The engine has no
  feasibility check; a Farkas refusal never says "feasible". The scripted solver is a brute force over at most 3
  variables with values up to 40.
- The taint repair follows the engine's path grammar. Rank steps (`.~i`) sort keys by their UTF-8 bytes; that equals
  the engine's raw byte order for ASCII keys (the scenarios use ASCII keys only). Removing the `value` of a label
  carrier leaves a malformed carrier (`MALFORMED_CARRIER`), which this repair function does not handle.
- `taint_egress` checks labels and names, not values (PROTOCOL.md section 12.7). The leak checks here search for
  the demo's own secrets only.
- The reconciliation reads the store through the engine (`replay`, `GET`, `STATE`). A process that can write the
  store folder could rewrite it consistently (PROTOCOL.md section 15); the demo, the store and the engine share one
  OS user.
- Timings are measured on a shared, loaded machine and are indicative only.
