# Discovery One: web showcase of the Forge airlock engine

Restored on `main` on the owner's word of 2026-11-20 from commit `3731ab8e` (deleted on 2026-11-20);
it stacks on the HAL demo (`demos/hal_9000/`). Records: `ROADMAP.md` and `unsure.md` U926. Nothing is deployed.

**Simulation: no hardware.** Discovery One, HAL-9000, Dave Bowman, the pod bays and the pressure are fiction.
The engine, its write-ahead log (WAL) and its checks are real processes on the server.

- `web/frontend/`: the page (Next.js static export, Framer Motion, Tailwind). It talks only to the backend.
- `web/backend/`: the FastAPI server. It sends commands to the **Forge airlock engine (Goals 20 and 21, Rust,
  native check, not proved)**, `build/airlock/airlock-engine`, through `sdk/py/forge_airlock.py`.
- HAL is a language-model persona (Anthropic API) when `ANTHROPIC_API_KEY` is set. Without a key there is
  **no model**: preset turns assume a fully fooled model and send the worst-case command.

Labels: the engine is NATIVE CHECK (unproved Rust); this showcase is a FINITE TEST. The CakeML refund binary
and the Goal 19 sink are not in this path. `end_to_end=false`.

## Run both halves locally

Backend (Python 3.10 or later; the virtual environment is `web/backend/.venv`, untracked by `web/.gitignore`):

```sh
python3 bin/forge-airlock build          # once, from the repository root: rustc, writes build/airlock/ (gitignored)
python3 -m venv web/backend/.venv
web/backend/.venv/bin/pip install --require-hashes -r web/backend/requirements.lock
cd web/backend && .venv/bin/python run_server.py         # 127.0.0.1:8787
```

Optional: `export ANTHROPIC_API_KEY=...` before `run_server.py` (only from the environment; see below).
No Node runs in the backend path: the store has money, saga and cosign policies only, and the engine verifies
a cosign signature with `/usr/bin/ssh-keygen -Y verify` (Goal 21). **OpenSSH with LibreSSL verifies the
signature: a system binary, trusted, not proved.** `GET /api/health` reports its SHA-256 and version
(`forge-airlock cosign-info`). The tests run with `PATH=/usr/bin:/bin` (no `node` reachable).

Frontend (its own toolchain: Node 24.3.0 first in PATH; the backend does not use Node):

```sh
cd web/frontend && PATH=/opt/homebrew/bin:$PATH npm ci
PATH=/opt/homebrew/bin:$PATH npm run dev            # http://127.0.0.1:3000 (telemetry of Next.js is disabled)
# another backend: NEXT_PUBLIC_API_BASE=http://127.0.0.1:8787 (the default)
```

Tests of the backend (real engine, no network; the model is a test double):

```sh
cd web/backend/tests && ../.venv/bin/python -m unittest discover -s . -p 'test_*.py'
```

The root `tsconfig.json` includes only `app/`, `ts/`, `interop/`, `tests/`, `bugs/`; the root `package.json`
has no scripts. Neither picks up `web/`.

## HTTP API

Base URL: `http://127.0.0.1:8787`. No cookies. JSON bodies. `POST` needs `Content-Type: application/json`.

| Route | Answer |
| --- | --- |
| `GET /api/health` | `{"ok", "engine": {"sha256", "label"}, "model": {"backend": "anthropic"\|"none", "name"}, "simulation_note", "limits": [...]}` |
| `GET /api/presets` | five `{"id", "title", "prompt"}` (always offered; with a model, a preset turn sends its prompt to the model) |
| `GET /api/telemetry` | the scoreboard (below); the read-back part is at most 1 s old |
| `POST /api/story/vent` | the scripted vent of Bay 3 (1013) against the real engine: `{"engine_request", "engine_answer", "committed", "latency_ms", "pre_state_hash_source", "scoreboard"}` |
| `POST /api/chat` | body `{"message", "session_id"}` or `{"preset_id", "session_id"}`; answer `text/event-stream` |

`/api/chat` events, in order:

- model turn: `delta {"text"}` (as the model streams), then `tool {"command": {...}|null, "source": "model", "valid", "not_sent_reason"?}`,
  then `verdict` (only when a command reached the engine) or `local_refusal {"reason", "note"}` (the command was
  refused BEFORE the engine: "not sent to the engine"), then `scoreboard`, then `done {"stop_reason"}`.
- preset turn without a model: `assumed {"note"}`, `tool`, `verdict` (or `local_refusal`), `scoreboard`, `done`.
- `verdict {"engine_request", "engine_answer", "committed", "latency_ms", "pre_state_hash_source", "expected_answer",
  "as_expected", "readback_error"?}`: `engine_request` is the exact request line sent; `engine_answer` the
  engine's exact answer line; `latency_ms` the measured round trip of that one exchange on the serve pipe;
  `expected_answer` the answer prefixes the nominal store should give (for example `REJECTED_POLICY REASON_CAP`);
  `as_expected` false means the engine answered something else (a dead rule, a changed policy, a commit).
  Only verdict classes are verdicts: `COMMITTED`, `REJECTED_POLICY`, `REQUIRE_HUMAN_COSIGN`, `UNKNOWN_KEY`,
  `MALFORMED_REQUEST BAD_SIGNATURE ...` (and `STALE_STATE_HASH`, `DUPLICATE_REQUEST_ID`, `TENANT_ISOLATION_BREACH`).
- `error {"code", "message"}` then `done`: `no_model`, `model_error` (no verdict follows, even if the command text
  had already streamed), `engine_error` (the engine gave no verdict: dead, timeout, a fault, or an answer such as `HELPER_FAILED`,
  `BAD_FRAME` or another `MALFORMED_REQUEST`; it carries `engine_request` and `engine_answer` when there were
  any; it is never counted as a refusal),
  `store_guard` (see "Operator"), `too_long` (more than 2,000 characters).
- Refusals before the stream starts are plain JSON `{"code", "message", "retry_after_s"?}`: HTTP 429
  `rate_limited` (with a `Retry-After` header), 400 `bad_request`, 403 `origin_refused`, 413 `too_large`, 415.

Scoreboard, read back from the store: `vent_commits`, `override_commits` (count of `VENT_ATMOSPHERE` records
on any key except the canary chamber `atmo-test`, and of `MANUAL_OVERRIDE` records, in the engine's `replay`),
`pressure_tenths_kpa`, `bay3_occupancy_fact`, `bay3_vent_quota_fact` (engine `GET` of `atmo-bay3`),
`store_effects`, `store_effects_baseline` (effects after the trusted setup, now 15), `store_effects_guard`.

Reconciliation (the breach decision): the server keeps a LEDGER of every effect it expects: the setup plan with
its epochs, and every request it sent that the engine answered `COMMITTED` (requests whose outcome is unknown
after a failure in flight are kept apart). `replay` must equal that ledger EXACTLY: the same count, and per
effect the same epoch and payload (request id, kind, key, values, cosign flag). Fields: `reconciled`
(`true`, `false`, or `null` when the read-back failed), `unauthorised_count` and `unauthorised_effects` (the
records of every other effect, of ANY kind, `"<epoch> <payload>"`, at most 20 listed),
`missing_committed_count` and `missing_committed` (an answered-COMMITTED request that is not in the WAL),
`unknown_outcome_landed`, `expected_effects`, `canary_ok`, `canary_answer`.

`crew_status` is derived from these only: `ALIVE` when `reconciled` is true, 0 vents, 0 overrides, no refund
on `atmo-bay3`, and remaining = original = 1013; `LOST` otherwise; `UNKNOWN` when the read-back failed (then
the numbers are `null` and `derived_from` says so). A commit of this server's own request (it is in the
ledger) still gives `LOST` through `vent_commits` / `override_commits`.

The server's own counts: `turns`, `commands_sent`, `model_emitted_commands`, `assumed_commands`,
`scripted_commands`, `engine_refusals`, `refusals_by_code`, `engine_commits_answered`, `unexpected_answers`
(verdicts that differ from `expected_answer`), `local_refusals`, `engine_errors`, `model_errors`,
`last_latency_ms`. Measurements: `engine_rss_kib` and `engine_peak_rss_kib` (`ps -o rss= -p <pid>` every
0.25 s; the peak is over every serve process since start; a shorter peak between samples is not seen),
`engine_uptime_s`, `engine_restarts`.

## How a turn reaches the engine

1. The model's text is scanned by a strict parser (`web/backend/app/parser.py`): the FIRST top-level JSON
   object whose `tool` is `VENT_ATMOSPHERE` (`bay_id`, `amount`) or `MANUAL_OVERRIDE` (`bay_id`, `amount`,
   optional `signature`: only the SHAPE of one SSHSIG token, 256 characters of canonical base64 ending in `==`;
   another shape is refused and not sent). A nested object is not a command. Any other field (tenant, key, request id, hash)
   makes it invalid. `amount` must be the engine's amount syntax (ASCII digits, 0 to 9223372036854775807);
   `bay_id` 0 to 9999. An invalid command is never sent. A reply above 32,768 characters is not scanned.
   The HAL terminal demo has its own parser (`demos/hal_9000/l_client.py`): **the two should be unified later.**
2. The server chooses tenant `crew`, a random request id (`w` + 16 hex), the key `atmo-bay<N>` from the
   validated number, and the pre-state hash from a `GET` under the same lock. A bay other than 3 has no key:
   `GET` answers `UNKNOWN_KEY`, the server sends the zero hash, and the page shows the engine's real answer
   (`UNKNOWN_KEY`).
3. The SDK builds the request line and checks every field (its own signature shape check is a
   `LocalRefusal`: "not sent to the engine"). The engine judges the token's content: `MALFORMED_REQUEST
   BAD_SIGNATURE <part>` for a token that is not a valid SSHSIG blob, `REQUIRE_HUMAN_COSIGN COSIGN_INVALID` for
   a well-formed one whose key is not the pinned key (no ssh-keygen runs then) or whose signature does not
   verify. One lock covers each command: `STATE` (guard), `GET`, `REFUND`, then the read-back (`GET`,
   `replay`, reconciliation).
4. One long-lived `forge-airlock serve` process per store. `shell=False` everywhere; every child process gets
   a minimal environment (no `ANTHROPIC_API_KEY`); no user or model string is part of an argv or a path.
5. Fail closed: `EngineDead`, `EngineTimeout`, `EngineFault`, `ProtocolError` during an exchange end the turn
   with `engine_error` and the next exchange starts a fresh `Store`. A serve process found dead BEFORE an
   exchange (for example killed with SIGKILL between two turns) is replaced at once; the turn then gets the
   new process's real answer. A failed read-back after a real answer keeps the answer (`readback_error`).

Trusted setup at start (the same plan as `setup_plan()` of `demos/hal_9000/run_discovery_one.py`; a test
compares the two payload for payload; re-implemented in
`web/backend/app/engine.py` because importing the runner changes `sys.path` and `sys.dont_write_bytecode`, and
its helpers pass the full environment to children): a fresh private folder (mode 0700, under
`FORGE_WEB_STATE_DIR`, default the system temporary folder, outside the worktree); the commander key by
`forge-airlock cosign-keygen` (ssh-keygen; its public token goes to `init --cosign-pubkey`); `init` (genesis
version 3, no `--node`) with `policy_discovery_one.json`, `policy_valves.json`, `policy_o2.json`; the keys opened
as the plan says (`atmo-bay3` with `crew_in_bay=1 vent_quota=0`, 4 pulse lines, 4 valves, 4 O2 tanks, and the
empty test chamber `atmo-test` with quota 1); then the CANARY: one vent of 1 on `atmo-test`, which MUST commit.
A refused canary (for example a policy whose vent rule is gone answers `REJECTED_POLICY NO_RULE`) is not hidden:
`health.ok` is false, `canary_ok` false, and every vent turn then shows `as_expected: false`. No rule reads
`crew_in_bay`: the engine caps a vent by `vent_quota`, which the trusted opener derives from the occupancy
reading.

**Commander key: deleted.** It is made only so that the store pins a real public key, as in the terminal
demo. Nothing in this server signs. After `init` the private key file is removed (an unlink, not a secure
wipe). So no request path can reach it, and `MANUAL_OVERRIDE` cannot commit on this server.

At a clean stop the private folder is deleted, unless `FORGE_WEB_KEEP_STORE=1`, or the last read-back showed
a vent or override commit or did not reconcile (then it is kept for inspection).

## Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | unset | the only source of the key; unset = `model.backend "none"` |
| `HAL_MODEL` | `claude-haiku-5-5` | model id; with a `claude-haiku-*` id, thinking is off; effort `low` |
| `HAL_MAX_TOKENS` | 400 | `max_tokens` per turn |
| `FORGE_WEB_PORT` | 8787 | port; the bind address is always 127.0.0.1 (fixed in `run_server.py`) |
| `FORGE_WEB_REPO_ROOT` | the repository of this file | where `bin/`, `sdk/`, `demos/hal_9000/` are |
| `FORGE_WEB_ENGINE_DIR` | `<repo>/build/airlock` | folder of `airlock-engine` (built if missing and default) |
| `FORGE_WEB_STATE_DIR` | system temp folder | parent of the fresh 0700 store folder |
| `FORGE_WEB_KEEP_STORE` | 0 | 1 keeps the store folder at stop |
| `FORGE_WEB_CORS_ORIGINS` | `http://localhost:3000,http://127.0.0.1:3000` | exact origins; a POST with another `Origin` gets 403 |
| `FORGE_WEB_TRUSTED_PROXY_HEADER` | empty | e.g. `x-forwarded-for`; empty = client IP from the socket |
| `FORGE_WEB_TRUSTED_PROXY_PEERS` | `127.0.0.1,::1` | the header is used only from these peers; the rightmost entry counts |
| `FORGE_WEB_IP_BURST` / `_IP_PER_MIN` | 6 / 6 | token bucket per client IP (every turn and story vent) |
| `FORGE_WEB_SESSION_BURST` / `_SESSION_PER_MIN` | 4 / 4 | token bucket per (IP, session id) |
| `FORGE_WEB_MODEL_TURNS_PER_MIN` / `_PER_DAY` | 20 / 300 | GLOBAL budget of model calls (UTC day) |
| `FORGE_WEB_ENGINE_TURNS_PER_MIN` | 120 | GLOBAL cap of turns without a model (presets, story) |
| `FORGE_WEB_MODEL_CONCURRENCY` | 4 | model calls at the same time (more: 429 at once) |
| `FORGE_WEB_TELEMETRY_PER_S` | 4 | telemetry polls per IP per second |
| `FORGE_WEB_MAX_BODY_BYTES` | 32768 | request body limit (413) |
| `FORGE_WEB_HISTORY_TURNS` / `_HISTORY_CHARS` | 4 / 6000 | per-session history sent to the model |
| `FORGE_WEB_MAX_SESSIONS` | 5000 | sessions kept in memory (oldest dropped) |
| `FORGE_WEB_SSE_TIMEOUT_S` / `_MODEL_TIMEOUT_S` | 60 / 30 | stream deadline / SDK timeout (1 retry) |
| `FORGE_WEB_ENGINE_TIMEOUT_S` | 60 | SDK timeout of one engine exchange |
| `FORGE_WEB_MAX_NEW_EFFECTS` | 20 | store guard: effects allowed above the setup baseline (15); a safety valve, NOT the breach rule |
| `FORGE_WEB_LOG_PROMPTS` | 0 | 1 logs full prompt and reply text (see "Logs") |
| `FORGE_WEB_TELEMETRY_CACHE_S` | 1.0 | read-back cache (0 to 1 s) |
| `FORGE_WEB_RSS_INTERVAL_S` | 0.25 | RSS sampling interval |

## Logs

One JSON line per event on stderr. A prompt and a reply appear only as a SHA-256 prefix and a length; IPs and
session ids as salted per-process hashes. `FORGE_WEB_LOG_PROMPTS=1` adds the full text: visitors type
anything (personal data, abuse), so use it only for a short local debugging session, never on a public
server. Exceptions are logged by class name only; a redaction filter replaces the API key in every line.

## Operator: a breach, and the store guard

The breach rule is the reconciliation (above). On this server every expected request is refused, so the WAL
should stay at the 15 setup effects. When `reconciled` is false, or `vent_commits` / `override_commits` is not
0, or `missing_committed_count` is not 0: stop the server (the folder is then kept); inspect it with
`python3 bin/forge-airlock replay <store>` and `get <store> crew atmo-bay3`; compare with
`unauthorised_effects`; keep the folder as evidence; find who wrote the effect (another `serve` on the folder?
another engine build? write access to the folder? an opener?); then start again, which makes a fresh store.
The store guard is only a valve against WAL growth: when the store holds more than baseline +
`FORGE_WEB_MAX_NEW_EFFECTS` effects, every new command gets `store_guard`.

## Threat model (plain words)

What the engine checks, for every request that reaches the store THROUGH it: the request grammar, that the
key exists and belongs to the tenant, that the request id is fresh, that the pre-state hash is the present
one (compare-and-swap), and the policy: `VENT_ATMOSPHERE` only within the `vent_quota` fact (0 while the
crew is in the bay), `MANUAL_OVERRIDE` only with a valid SSHSIG Ed25519 signature by the pinned commander key, checked natively
for form and key, then verified by `/usr/bin/ssh-keygen` (trusted, not pinned by hash: the engine checks only
its path, owner and mode; an OS update can change it; `cosign-info` shows what ran).

What the server must protect, because the engine cannot:

- **the store folder**: any process that can write it can append records itself (the CRC and FNV chain
  authenticate nothing); any process that can start its own engine build on it can ignore every check;
- **the commander key**: deleted here; in a real setup it lives with another OS user, a hardware key or
  another machine;
- **the engine binary and `/usr/bin/ssh-keygen`**: nothing pins the engine itself; whoever starts it chooses
  it; the system ssh-keygen is a trusted assumption;
- **the opener**: the occupancy fact is written once by the trusted setup step; the engine does not read a
  sensor, and opens are not authorised (any caller of the engine could open a NEW key).

A full compromise of this server process (`src/airlock/PROTOCOL.md` section 11) means: the attacker is the
same OS user as the store folder and the engine, so every rule above can be bypassed by writing the folder
or running another engine. It also means the API key is exposed. The engine's rules protect against a
caller that holds only the HTTP API (and so only the model's command channel), not against a caller that
runs code on this server. A real deployment runs `serve` under another OS user that owns the folder, gives
the web process only the pipe, and keeps the key in a secret store with a spend limit.

## Deployment: what is NOT done

- Nothing is deployed. The server binds 127.0.0.1 only. No TLS, no reverse proxy, no process supervisor,
  no separate OS user for `serve`, no container. Rate-limit counters live in one process (a restart resets
  them, including the daily budget; more than one process would need a shared store).
- The engine has been built and tested on macOS arm64 only. A Linux build was NOT RUN (only the
  `aarch64-apple-darwin` Rust target is installed here). The engine's durability uses `F_FULLFSYNC` (a macOS
  call); its behaviour on Linux is not checked.
- `forge-airlock build` also copies the pinned CakeML refund binary (a macOS arm64 Mach-O file). This
  showcase does not need it: no key uses the `canonical-refund` profile.
- The backend needs no Node. It needs `/usr/bin/ssh-keygen` (OpenSSH; measured here OpenSSH_10.3p1 with
  LibreSSL 3.3.6). A Linux host has another OpenSSH build: the engine accepts only the exact answers it
  knows, so another text gives `HELPER_FAILED` (fail closed). NOT RUN on Linux.
- The reconciliation detects effects; it does not prevent them. Its ledger lives in the server's memory: a
  restart of the server starts a fresh store, so there is nothing to carry over.
- `requirements.lock` holds SHA-256 hashes of the macOS arm64, CPython 3.10 wheels (two packages are
  platform wheels): regenerate it for another platform.

## Phrases of the directive that the facts do not support

| Directive | True wording used |
| --- | --- |
| "a real, native Rust/CakeML binary" | the Forge airlock engine (Goals 20 and 21, Rust, native check, not proved); no CakeML code decides here; OpenSSH verifies a cosign |
| `subprocess.run(["./airlock-engine", "serve", "--policy", "policy.json"], input=action_bytes)` | one long-lived `forge-airlock serve <store>` process (no `--node`) through `sdk/py/forge_airlock.py`; policies are pinned at `init`, not given to `serve` |
| "writes the proposed action to a temporary JSON string" | the SDK builds one request line from server-chosen fields and the validated tool, bay and amount |
| `{"llm_text", "airlock_verdict": "BLOCKED...", "latency_ms": 1.2}` | a stream of `delta`, `tool`, `verdict` (the engine's exact answer line, for example `REJECTED_POLICY REASON_CAP`) with the measured `latency_ms` |
| "Zero Shell Injection" | `shell=False`, argv lists, no user or model string in an argv or a path (a property of this code, checked by reading it, not a proof) |
| "Dave Bowman: ALIVE" as a counter | `crew_status`, derived from the reconciliation of the WAL with the ledger and the Bay 3 read-back; it can show `LOST` |
| "Attacks Blocked" | `engine_refusals` and `refusals_by_code`, counted from the engine's answers |
| "CPU/RAM/Blocks" | measured engine RSS and peak RSS; no CPU figure |
| "venting Pod Bay 3", "overriding safety protocols" | refund requests with reason `VENT_ATMOSPHERE` / `MANUAL_OVERRIDE` on the money key `atmo-bay3` of a simulation |
| `INVARIANT BREACH` (Act 2 overlay) | the page shows the engine's answer line from `POST /api/story/vent` |

## Tests (what they cover)

`web/backend/tests/`: `test_parser.py` (the parser table: prose, two objects, fences, malformed, unknown tool,
nested, extra fields, duplicate keys, huge / negative / float / string / non-ASCII amounts, a 1 MiB reply,
deep nesting); `test_engine.py` (real engine: vent refused and read-back unchanged; the other answers; a
SIGKILL between turns recovers by restart with 0 commits; a death during the exchange gives `EngineError`;
the setup plan equals the runner's `setup_plan()`; no `--node` on serve; `HELPER_FAILED` is an
`EngineError`; a death in flight keeps the request as outcome-unknown; controls: occupancy 0 (the same vent
commits, `LOST`, the guard then refuses), a second client with its own `serve` writes an O2 draw, a new key and
a valve move (`reconciled` false, 3 unauthorised records shown, `LOST` with 0 vents), and a policy without the
vent rule (canary `REJECTED_POLICY NO_RULE`, the turn `as_expected` false)); `test_api.py` (model test double: streamed deltas, a command, no
command, an API error mid-stream gives `error` and no verdict; presets; rate limits; global budgets; CORS;
body size; headers; no cookies; proxy header; then a search of every response and log line for the fake key);
`test_server.py` (real uvicorn: 50 concurrent preset turns give 50 refusals and 0 commits; SIGKILL between
turns over HTTP).
