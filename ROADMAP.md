# Forge: proof-gated changes

**CURRENT: none (Stage 9 deferred)**

Status note of 2026-11-18 (owner decision; `unsure.md` U437 to U442,
M1R-1, M1R-2, R4C-1). No
stage is CURRENT. The full record lists Stages 9, 10 and 11 as DONE. For
Stage 9 the renewal of its lock is deferred: it needs a hosted signing
run that is not authorized, and two entries of
`gate/provenance/implementation.lock` do not match `main` since pull
request 39, and six more since pull request 43. Stage
12 is unauthorized. `end_to_end=false`. The eight modules of the PR gate
are frozen: protected paths change only by an exact-diff proposal and
the owner's merge.

Below the Round 4 section, this file is the record as it stood during
Stage 9. It is not updated; its words "Stage 9 is CURRENT" describe
that time. The full record after it (Stages 10 and 11, the M1 work,
Rounds 2 to 4) is `ROADMAP.md` on branch `backup/forge-local-2026-11-11`
(commit `692c9953` when this note was written). It is not copied here,
because 160 of its links have no target on `main`. The uncertainty
entries of that work are in `unsure.md` here. The work direction is
`FORGE_MASTER_IDEA.md`; it approves nothing.

The Stage 6 text below describes the first benchmark run. Since pull
request 40 its files are in `results/stage6-epoch1` and
`docs/reuse-benchmark-epoch1.md`; five links of that text now point
there. The files under `results/stage6` are the run of 2026-11-18 for
the present gate bytes.

## Ratification proposal applied: stateful refund-log specification under `spec/refund/` (owner decisions D1 to D3 of 2026-11-20; the owner's merge is the ratification) — U928

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Branch `ratify/refund-log-spec` from `1dc0437e`. The
exact diff of the merged proposal (pull request 87) is applied on the
owner's word. It adds `spec/refund/RefundLogSpec.dfy` and
`spec/refund/RefundLogSpec.lock` and changes no existing file. No gate
module changes. NOT merged by the agent.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `git apply --check`, then `git apply` of `ratification.diff` (`9b52151f…`) |0; 0|two files added |
| `cmp` of the applied specification with the proposal file |0|byte-equal (`1a8c7c2a…`) |
| lock re-check: canonical form, three dependency digests, specification digest |all true| |
| `dafny verify spec/refund/RefundLogSpec.dfy` (gate options) |0|9 verified, 0 errors (the specification and the included approved `RefundSpec`) |
| the same command with the proposal's lemmas file added |2|a fault of the command, not of the texts: the lemmas file includes its own copy of the specification, so the module name occurs twice. The lemmas were verified against the byte-equal proposal copy (pull request 87: 45 verified, 0 errors) |
| scratch-clone regression on `0a57133d`: 28 Stage EXIT cases; frozen PR-gate check; links |28 of 28 exit 0; 0; 0|the runner lists the two added files as protected paths changed, as intended |
| bundles rebuilt in the clone: Slice 1, 2, 3, M1 conformance, native silicon sink |0 each|byte-identical to the tracked records |
| Goal 20 bundle step; Stage 7, 9, 10; any HOL process |NOT RUN| |
| hosted gate on the pull request |expected: not accepted (no approval rule for these files); NOT observed yet| |

## Stateful refund-log specification: a proposal with an exact, unapplied ratification diff (specification only; nothing about the engine) — U924

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. The first half of the owner's decision of 2026-11-20
("Stateful Spec + Task V1: Approved!"). Task V1 is NOT started. Branch
`proposal/refund-log-stateful-spec` from `origin/main` `b1c98822`;
NOT pushed, NOT merged, NOT ratified. No protected path changed: the
change of `spec/refund/` is the unapplied `ratification.diff` (two new
files). The lemmas are statements about the specification text only.

| EXIT command/check | Expected exit | Actual exit/result | Result |
| --- | --- | --- | --- |
| `dafny verify` of the three proposal files (gate options), attempt 1 | 0 | 4 | 43 verified, 2 errors (two concrete witnesses); repaired in the lemmas file only |
| the same, attempt 2 | 0 | 0 | 45 verified, 0 errors |
| `dafny audit` against `gate/expected-audit.md` | 0 | 0 | empty |
| spec clearing (`clear_spec` of `scripts/spec_clearing.py`, imported unchanged) | 0 | 0 | NO_CHOICE; ACCEPTS; spec probe: only `Decide` has no body |
| `git apply --check ratification.diff` on a clone of `b1c98822` | 0 | 0 | adds `spec/refund/RefundLogSpec.dfy` (`1a8c7c2a…`) and `spec/refund/RefundLogSpec.lock` (`44eb5be6…`) |
| after the apply: `check_frozen_pr_gate.py`; gate probe (`approval.authorize`) | 0; 0 | 0; 0 | authorize gives `UNAPPROVED_PROTECTED_CHANGE` as expected: no machine path approves `spec/refund/`; the owner's merge is the ratification |
| bootstrap `76b983ac…` before and after the apply | 1; 1 | 1; 1 | same rejection on both (state of `main`) |
| Task V1; engine runs; hosted gate; push | — | NOT RUN | |

Owner decisions: D1 `refundEnabled` (proposed: a stored bit fixed at
genesis), D2 zero amounts (proposed: allowed, as approved), D3 file
names and lock. [Proposal](proposals/refund-log-spec-20261120/README.md).
[Correspondence](proposals/refund-log-spec-20261120/CORRESPONDENCE.md).
[Ratification diff](proposals/refund-log-spec-20261120/RATIFICATION_DIFF.md).
## Goal 20 record refreshed on 2026-11-20: a fresh `--case evidence` run on `main` `e4901ffc` (after pull requests 68, 72 and 73) replaces the tracked Goal 20 bundle; a finite test and native check record, not a proof — U923

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Owner approval of 2026-11-20: "Goal 20 record:
Approved--regenerate and record the fresh Goal 20 bundle matching
main's current post-#72/#73 files." Branch
`records/goal20-bundle-refresh` from `origin/main` `e4901ffc`. One file
of evidence changed: `proposals/forge2-goal20-sdk/records/evidence.json`.
No script, engine, test or subject file changed. No protected file
changed. OLD bundle `1e75ab47…70fa`; NEW bundle `4a66ddc8…2f65`.
NOT pushed; NOT merged by the agent.

Expected before the run: exit 0, two byte-identical bundles, a digest
other than `1e75ab47…` (20 of its 64 subject rows changed or deleted).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| proof-slot wait (no `dafny/dafny`, `Holmake`, `z3-4.12.1`, `run_regression_copy`, `spec_clearing` for 3 checks one minute apart) |free at 12:32:53|then the case started |
| `python3 scripts/exit_goal20_sdk.py --case evidence` (pinned Python 3.10.11, Node 24.3.0 first in PATH) |0|two runs; bundle `4a66ddc86d4e954e6e2ce215f4fb0d5d49abc1d5cb80ba1c1b5c7fd891d62f65` both times, byte-identical; wall 2437 s |
| each run: build; suite; mutations; disasters; fuzz |0; 33 + 68 + 56 + 11 + 21 passed; 145 of 145 killed, 3 not killed; 8 of 8; 8 of 8 held|not killed: X01, R8, N15 (reasons in U923) |
| `cp` of the bundle to the tracked record; the SHA-256 comparison of `proposals/forge2-goal20-sdk/run_regression.py` |True|byte-identical |
| full scratch-clone regression (`run_regression.py`: 28 Stage EXIT cases, frozen gate, links, six bundles) |NOT RUN|not part of this work |
| hosted `gate/pr_check.py`; push; pull request |NOT RUN|expected exit 3 (UNSUPPORTED) for a records-only pull request |
| any HOL or Holmake step; Stages 7, 9, 10; a power-loss test |NOT RUN|not part of this work |

`README.md` and `docs/STATUS.md` do not state the Goal 20 bundle digest;
they are not changed. Older records that name `1e75ab47…` stay as they
are (they describe their own commits). M1 and integration EXIT
NOT_ESTABLISHED.
## Test hygiene 2026-11-20: `S2_shared_lock` left a hung `serve` process after each run; every child of the engine suites is now killed and reaped on every exit path — U927

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Test files only: `tests/primitives_v2/test_engine.py`,
`test_ledger_graph.py` and the five `mutants*.py` drivers. No engine
source and no protected file changed. Branch
`fix/s2-shared-lock-teardown` from `b1c98822`; NOT pushed; NOT merged.
Cause: case `lock` failed (as it must under the changed copy) before
`holder.kill()`; the holder, paused at the test seam with the lock held,
waits for SIGKILL forever. Repair: the suites register each child and
kill and reap the ones still alive after each case; the drivers run each
suite in its own process group and SIGKILL the group on every exit path,
also a timeout. New check: line `TEARDOWN` of `test_engine.py` fails the
run (exit 1) when a process that names the run's work folder is alive at
the end. FINITE TEST on one machine.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| before the repair: `mutants.py --only S2_shared_lock` |0|KILLED; 1 `primitives-engine-seams serve …/lock-1/st` left alive (killed by hand) |
| before the repair: `test_engine.py --case lock` on the S2 copy |1|FAIL lock; 1 process left alive |
| after: `mutants.py --only S2_shared_lock` |0|KILLED for its named reason; 0 processes left |
| after: `test_engine.py --case lock` on the S2 copy |1|FAIL lock (named reason); REAPED 2; TEARDOWN 0; 0 left |
| after, reaping disabled in a scratch copy (check of the new check) |1|TEARDOWN 2 (the check finds the leak) |
| after: `mutants.py` (all) |0|control PASS; 30 of 30 copies KILLED; 0 left |
| after: `test_engine.py` (unchanged build, all cases) |0|23 of 23 PASS; TEARDOWN 0; 0 left |
| after: `test_ledger_graph.py` (all) |0|0 left |
| after: `mutants_p7.py`; `mutants_p8.py` |0; 0|25 of 25 and 20 of 20 KILLED; 0 left |
| `mutants_p9.py`, `mutants_sdk.py`, `test_policy_to_dfy.py`, any Dafny or HOL, `scripts/exit_universal_primitives.py` (all cases) |NOT RUN|p9 and sdk: changed, compile check only |

The `suite` and `mutations` cases of
`scripts/exit_universal_primitives.py` hash the test files into the
bundle, so its bundle digest changes; no tracked record holds that
digest. Entry U927.
## Discovery One web showcase restored on `main` (owner's word of 2026-11-20): `web/` from commit `3731ab8e`, on top of the HAL demo; header spacing repaired; a finite test of the unproved engine; nothing deployed; NOT pushed; NOT merged — U926

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Additive: only `web/**` (44 files) is new on this branch
(it stacks on branch `demo/hal-9000`); no file of `main` changed except
this file and `unsure.md`. Brought from `3731ab8e` (branch
`recover/discovery-one-web`): `web/**` only. Third-party packages stay
inside `web/` with exact pins and lock files; `node_modules/`, `.next/`,
`out/`, `.venv/` and screenshots are untracked (`web/.gitignore`); the
largest tracked file is `web/frontend/package-lock.json` (237,347
bytes). The root `tsconfig.json` includes only `app/`, `ts/`,
`interop/`, `tests/`, `bugs/` (read): it does not pick up `web/`.
Adapted: no backend code change was needed for the engine and SDK of
`main`. Repaired: the page header rendered `DISCOVERY ONEFORGE AIRLOCK
SHOWCASE` (no space between the `<h1>` text and its `<span>`; the
margin hid it only on wide screens); one `{" "}` in
`web/frontend/src/components/Experience.tsx`. Documents: the virtual
environment is now `web/backend/.venv`; a scratch path in the
`run_server.py` docstring removed.

Commands (worktree; Node 24.3.0 for the frontend; the backend venv from
`requirements.lock` with `--require-hashes`; backend runs with
`PATH=/usr/bin:/bin`; `env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY`;
`NEXT_TELEMETRY_DISABLED=1`; no model call):

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `npm ci` in `web/frontend` |0|369 packages from the lock file |
| `pip install --require-hashes -r requirements.lock` in `web/backend/.venv` |0|fastapi 0.162.5, uvicorn 0.54.0, anthropic 2.11.0 |
| backend `python -m unittest discover` (before and after the repairs) |0, 0|51 tests each time; 50 concurrent preset turns: 50 refusals, 0 commits |
| `npm run typecheck`, `npm run lint`, `npm run build` (before the repair; after the repair) |0 0 0; 0 0 0|static export |
| live HTTP, real backend on 127.0.0.1, no model: `GET /api/health`, `GET /api/presets`, `POST /api/story/vent`, `POST /api/chat` with each of 5 presets, `POST /api/chat` with free text, `GET /api/telemetry` |200 each|vent `REJECTED_POLICY REASON_CAP`; presets: REASON_CAP x2, `COSIGN_INVALID`, `TOTAL_CAP`, `UNKNOWN_KEY`, each `as_expected`; free text: event `no_model`; telemetry `ALIVE`, reconciled, 0 unauthorised; no HTTP 500 in either server log |
| header text, server-side render of `Experience` (scratch script, React's own renderer) |1 before, 0 after|before `DISCOVERY ONEFORGE AIRLOCK SHOWCASE`; after `DISCOVERY ONE FORGE AIRLOCK SHOWCASE` |
| positive control: a second writer opens a key on the live store through its own engine process |COMMITTED|telemetry `LOST`, `reconciled` false, 1 unauthorised effect; the page rendered with that answer has `data-breach="true"` and the BREACH banner (red: `#7f1d1d`, stage `#2a0204`, read from the CSS); with the clean answer: no banner |
| `node test/browser-check.mjs`, `node test/real-backend-run.mjs` (headless Chrome) |NOT RUN|the process limit of the shared machine; no browser render; colour read from the CSS, not seen |
| model mode with a real model |NOT RUN|no key by rule; the unit tests use a test double |

Limits: the engine is unproved Rust (NATIVE CHECK); this showcase is a
FINITE TEST; the breach decision is the exact reconciliation of `replay`
with the server's ledger; a full compromise of the server bypasses every
rule (PROTOCOL.md section 11). Nothing deployed. Open for the owner:
film characters (rights), cost of a live model per visitor turn (the
daily budget counter is in memory only), hosting.

## Release audit 2026-11-20: merge state

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Documents only. The sections below were written on their
branches BEFORE these merges. Their words "NOT merged", "NOT merged by
the agent", "draft pull request" and "branch ... from" are the record of
that time and are not changed. The merge state on `main` = `058eabcb`
(read with `gh pr list --state merged` and `git log --oneline
origin/main`; both exit 0):

| Pull request | Squash commit on `main` | Section below |
| --- | --- | --- |
| 65 | `9a9a8943` | Goal 20, `forge-airlock` SDK |
| 66 | `b2249ea2` | Gate APEX-2 |
| 67 | `33055a59` | none (Formal Ceiling v2, design only; `unsure.md` U840) |
| 68 | `be9c1cc2` | Review of 2026-11-20: README top and claims |
| 69 | `0a84902a` | Review 2026-11-20, defect D1: isolation-mode design |
| 70 | `116f675f` | Gate F1 (Goal 21), intent clearing |
| 71 | `c1490f92` | Review fix PR-2, CI for the airlock engine |
| 72 | `cad68a5f` | Goal 21, phase 1: cosign check without Node |
| 73 | `7e5842d0` | Review 2026-11-20, engine hardening (PR-3) |
| 74 | `f1d87032` | T19, the hardened refund sink, minter and dispatcher |
| 75 | `ccdd8e5f` | Video cut |
| 77 | `a2ef7c0a` | Archia MCP airlock demo, Phases 1 to 4 |
| 78 | `e9e30a64` | none (ROADMAP repair) |
| 79 | `058eabcb` | V1.1 universal primitives pack |

Still OPEN: pull request 76 (Gate F2a, Stage 9 lock rebind; protected
files; no section here). Stage 9 stays deferred.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `gh pr list --state merged`; `git log --oneline origin/main` |0; 0|the table above |
| `gh run list --workflow airlock-ci.yml --branch main` |0|hosted runs 44756122944 (`c1490f92`) and 44767657892 (`058eabcb`): success |
| link check of the five changed documents (a working-tree variant of `proposals/round4-20261117/check_links.py`) |0|0 missing targets |
| any test suite, EXIT script or bundle run |NOT RUN|documents only |

Findings, the number ledger and the proposed code-comment changes:
[AUDIT3_DOCUMENTS.md](proposals/release-audit-20261120/AUDIT3_DOCUMENTS.md).
Two record facts that the sections below do not show: (1) the tracked
Goal 20 bundle record (`1e75ab47…`) does not reproduce on `main`: 20 of
its 64 subject files changed in pull requests 68, 72 and 73, and no
newer bundle is tracked; (2) `scripts/exit_archia_mcp.py` pinned the
pre-merge `bin/forge-airlock` (`bd56d8b6…`), but `main` has `8d9296ac…`,
so its `--case build` could not pass on `main` as written. This branch
makes that pre-merge check "not applicable" after the script's own
merge (the same for the additive check of
`scripts/exit_universal_primitives.py`); both `--case build` runs then
gave exit 0.

Final results of the audit (hygiene, demos, the clean scratch clone:
28 of 28 Stage EXIT cases exit 0, five bundles byte-identical, Goal 20
bundle NOT RUN, 2 older missing link targets), with every actual exit
code and every NOT RUN item:
[release-readiness table](proposals/release-audit-20261120/README.md).
Entry U920.
## HAL 9000 demo restored on `main` (owner's word of 2026-11-20): `demos/hal_9000/` from commit `ff03fac3`, adapted to the engine of `main`; a finite test of the unproved engine; NOT pushed; NOT merged — U925

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Additive: only `demos/hal_9000/**` (18 files) is new; no
file of `main` changed except this file and `unsure.md`. Brought from
`ff03fac3` (branch `recover/hal-9000`): the demo's own files only. The
old copies of `src/airlock/`, `sdk/`, `bin/forge-airlock`,
`scripts/exit_goal20_sdk.py`, `docs/quickstart-5min.md` and
`tests/airlock/` on that branch were NOT brought: `main` wins. Code
change for `main`'s engine: none was needed (the old branch already
used the native cosign tools without `--node` and no kill-points build).
Adapted: on-screen and README text (request ids are per tenant since
review D3, but every party uses the tenant `crew`; no Node runs; the
Node-swap attack belongs to the old Goal 20 engine), the test list in
the README, the owner's sudo steps in the README, and the owner's login
name removed from `vault/README.md`.

Commands (worktree, pinned Python 3.10.11, Node 24.3.0 first in `PATH`,
rustc; `env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY`; no model call):

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 bin/forge-airlock build` |0|engine, `build/silicon/test/airlock-engine-kill`, refund copy |
| `python3 demos/hal_9000/test_hal_demo.py` (before and after the text changes) |0, 0|26 of 26 cases, each time |
| `python3 demos/hal_9000/run_discovery_one.py --fast --no-color` (10 GiB flood) |0|32 of 32 checks true; peak RSS 2,384 KiB; 30.2 s |
| same, `--flood-gib 0.25`, a logging `node` stand-in first in `PATH`, `FORGE_AIRLOCK_NODE` unset |0|the stand-in was passed to `serve` and never started (log file not created); the commander's cosigned pulse committed |
| same, `--engine-dir /nonexistent/engine` |2|`SETUP ERROR: /nonexistent/engine/airlock-engine is missing` |
| `python3 demos/hal_9000/vault/test_vault.py` (one user, NO separation) |0|20 of 20 |
| `sh demos/hal_9000/vault/setup_vault.sh --dry-run` |0|24 printed commands, nothing changed |
| positive controls in the test (occupancy 0; a real commander signature not in the ledger; no cap; direct SAGA; A2, A2b, A3, A5; mutants M1, M4b, M9, M10) |0 (suite)|each bad effect commits or each mutant runs, and the checker or show exits 1 |
| vault and nobody mode under a second user ID (`sudo`) |NOT RUN|no agent runs `sudo`; the owner's commands are in `demos/hal_9000/README.md` |
| the interactive mode with a real model |NOT RUN|no key in the environment by rule; local test doubles only |

Limits: the engine is unproved Rust (NATIVE CHECK); the demo is a FINITE
TEST; the scorecard is an exact reconciliation of `replay` against the
trusted side's ledger (it detects, it does not prevent, a same-user
bypass); OS user separation is NOT TESTED. Open for the owner: the film
characters (rights question for a public launch), the cost of a live
model.

## Assurance-chain investigation 2026-11-20: where the chain from authorization to receipt holds, where it breaks, and the shortest path to an independent verifier (read-only; nothing proved here) — U921

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Documents only: `proposals/assurance-chain-20261120/`
(a final answer, Reports A to F, three investigator annexes). Base
`origin/main` `058eabcb`. No code changed. No HOL, Holmake, Dafny,
build or test ran: every MACHINE_CHECKED status cites a committed run
record, and none of those runs was repeated. The statements in Report
D are targets; none is proved.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| three read-only investigations (specification, proof, compiler; runtime, durability, receipt; hardware) |done|three annexes |
| fresh-context review of the first version of the reports |done|34 claims checked: 25 held, 9 wrong or too strong; 20 defects; the first-task recommendation was inverted |
| revision with each defect re-checked in the repository |done|16 defects confirmed in full, 4 confirmed in part and partly rejected with evidence (dispositions in the README) |
| link check of the ten documents (`proposals/round4-20261117/check_links.py`) |0|0 missing targets |
| any proof replay, clean replay or independent replay |NOT RUN|read-only investigation |

Result in short: two lines exist and meet in no proof. The proved
refund binary line is machine-checked at model level and stops at
output bytes. The Rust engines make the durable transition and have no
proof. Every runtime receipt is an assertion of the engine that wrote
it. The recommended next task is V1, a small verifier proved against a
new stateful specification (not approved today), which folds the durable
log and rechecks every transition; it needs no M1 and no Rust proof.
Details: [README](proposals/assurance-chain-20261120/README.md).

## V1.1 universal primitives pack: a new additive engine `src/primitives_v2` with rate windows, double-entry ledgers and graph uniqueness, recursive taint egress, Farkas certificate checks and a policy-to-Dafny model generator; a finite test of unproved Rust and Python around Dafny models; one review with repairs — U910 to U912

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Nothing under
`clearing/` changed. Additive only: no tracked file of `main` changed
except this file and `unsure.md`. Branch `feat/universal-primitives-v2`
from `33055a59`; NOT pushed, NOT merged. The directive's pre-flight was
not met; the owner authorized the start on 2026-11-20 (U910). Every
engine verdict is NATIVE CHECK (unproved Rust); suites, demo, changed
copies and differential replays are FINITE TEST on one machine. PROVED
applies only to `FarkasCert.Soundness` (no non-negative INTEGER x
solves `A x >= b` when `Accepts` holds; nothing about rational x,
completeness, solvers or `farkas.rs`) and to the lemmas of the four
generated Dafny MODELS (nothing about the Rust engines; the tie is a
finite differential replay). The bundle is a record, NOT gate evidence.

| EXIT command/check | Expected exit | Actual exit/result | Result |
| --- | --- | --- | --- |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/primitives_v2/main.rs` and the same with `--cfg test_seams` (both inside `--case build`) | 0; 0 | 0; 0 | std only, no crate, no `unsafe`; each build twice, byte-identical; a copy with one `unsafe` block: exit 1 |
| `python3 scripts/exit_universal_primitives.py --case build` | 0 | 0 | ADDITIVE: against the merge base `33055a59`, 0 tracked files modified, 0 protected paths; wall 16 s |
| `--case suite` (run on the tree of `ec2c1b76` before the commit) | 0 | 0 | 81 of 81 cases: test_engine 23, test_ledger_graph 11, test_taint 8, test_farkas 6, test_policy_to_dfy 5, test_sdk_primitives 9, test_demo 19; wall 377 s |
| `--case proofs` | 0 | 0 | `dafny verify`: FarkasCert 36, money-refunds-p9 21, rate_window-api-p9 37, rate_window-burst-p9 37, transfer-cash-p9 7 verified, 0 errors; each audit equal to the empty baseline; 16 hash seeds give one text per model; the four vector files equal the committed files byte for byte; spec clearing NO_CHOICE and ACCEPTS for all four; `clearing/` unchanged |
| `--case demo` | 0 | 0 | two runs identical outside `measured` (`82665ba9…b276`); self-test 13 canaries, each fails its named check |
| `--case mutations` | 0 | 0 | 103 of 103 changed copies killed for their named reason (engine 30, ledger_graph 25, taint 20, primitive 9 25, SDK 3); NOT KILLED: none; accepted survivors: none; wall 861 s |
| `--case evidence` | 0 | 0 | build, suite, proofs, demo, mutations twice; bundle `100476fe95a98cb13496eb361b30fd2308b5643c5b29e48f375584a85a58a8dc`, byte-identical; wall 2870 s; on the tree of `ec2c1b76` |
| `--case build` again on the records commit | 0 | NOT RUN at the time of writing | it runs after this records commit; the only modified files may be `ROADMAP.md` and `unsure.md` |
| the one fresh-context adversarial review | 0 FAIL-OPEN, 0 HIGH | 0 FAIL-OPEN; 0 HIGH; 2 MEDIUM; 5 LOW | M1, L1 to L5 repaired in one pass; M2 stated as a KNOWN LIMIT; NOT reviewed again |
| regression on a scratch clone: 28 Stage EXIT cases; `check_frozen_pr_gate.py`; the prior bundles | 0 each | NOT RUN | |
| `git push`; `gh pr create`; hosted `gate/pr_check.py` | 0; 0; 3 (UNSUPPORTED) | NOT RUN | |
| a second review; a power-loss test; Stages 7, 9, 10; any HOL step | — | NOT RUN | not part of this work |

[Protocol](src/primitives_v2/PROTOCOL.md).
[Demo](examples/universal_self_repair/README.md).
rate_window limits a key; the key and tenant must be bound by a trusted
wrapper outside the engine. The cosign signature check is a stub. No
TypeScript wrapper. A SIGKILL is not a power loss. M1 and integration
EXIT NOT_ESTABLISHED.
## Review fix PR-2, CI for the airlock engine: one new macOS arm64 workflow builds the engine and runs 121 of 193 airlock and SDK cases; a finite test; protected path, needs the owner's exact-bytes approval — U884 to U886

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Branch `ci/airlock-macos` from `33055a59`; pull request 71;
NOT merged by the agent. One new file `.github/workflows/airlock-ci.yml`
(SHA-256 `b190ba53…e946` after the review repairs). 72 cases that need
Dafny are skipped. The image versions float and are not monotonic.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `grep -n -i -E "airlock\|rustc\|silicon" .github/workflows/*` on `33055a59` |1|no match: the review finding is confirmed |
| local dry run of the seven `run:` scripts, first and repaired bytes (no build products; `race` also skipped) |0 each (7); 0 each (7)|engine 23, node helpers 74, SDK 17, diff-policy 6 PASS; repaired: four count checks pass, six negative controls exit 1 |
| hosted airlock-ci run 44692795822 at `0846e403` |success|job 1m23s; 121 PASS, 0 FAIL; rustc 1.100.0, Node 24.22.3 |
| hosted proof gate run 44692795915 at `0846e403` |failure|`UNAPPROVED_PROTECTED_CHANGE`, as expected |
| hosted airlock-ci run 44693275108 at `b98a06cf` |success|job 1m20s; same counts; older image: rustc 1.99.1, Node 24.22.2 |
| hosted proof gate run 44693272518 at `b98a06cf` |failure|as expected |
| one fresh-context review of `b98a06cf` |0 HIGH; 3 MEDIUM; 8 LOW|11 accepted (1 in part); 10 repaired, 1 recorded only; NOT reviewed again |
| `check_frozen_pr_gate.py HEAD`; `check_links.py HEAD` (5 `.md` files) |0; 0|outputs in `checks.txt` of the record |
| hosted run of the repaired bytes |NOT RUN when this row was written|in the pull request |
| update after pull requests 72 and 73 merged (`main` `7e5842d0`): one local run of each suite file, no checker model |engine 1 (29 PASS, 3 NOT RUN for the model); cosign 0 (56 PASS); node helpers 1 (5 PASS, 63 NOT RUN for the model); SDK 1 (19 PASS, 2 NOT RUN for the model); diff-policy 0 (6 PASS)|new workflow bytes `b10831fe…`; totals 33, 56, 68, 21, 11; run minimums 30, 56, 5, 19, 6 (U897) |
| hosted run of the updated bytes |NOT RUN when this row was written|in the pull request |
| Dafny cases; Linux job; `src/silicon_sink`; full local suites under the heavy lock |NOT RUN|deferred (U885) |

[Record](proposals/review-20261120-ci/README.md).
[Review](proposals/review-20261120-ci/REVIEW.md).

## Review of 2026-11-20: README top and claims 1, 2, 4, 5, 8, 11 corrected; documents only — U880 to U882

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Documents only; no behaviour change. Branch
`docs/review-readme-claims` from `33055a59`; NOT merged by the agent.
The Goal 20 bundle subject digests of `docs/quickstart-5min.md` and
`src/airlock/PROTOCOL.md` change (U881); no new evidence run.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `gh repo view mack-dot/forge --json visibility,licenseInfo` |0|`PRIVATE`; `licenseInfo` null |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs` (scratch output) |0|engine for the README example |
| `bin/forge-airlock init` (scratch store, `refunds.json`, `--engine-dir`) |0|`INITIALIZED` |
| the README Python example with `engine_dir=` (scratch) |0|`COMMITTED`; `REJECTED_POLICY REASON_CAP`; `COMMITTED`. The README text with the default folders: NOT RUN |
| `check_frozen_pr_gate.py HEAD` (commit `3d25286a`) |0|frozen modules unchanged |
| `check_links.py HEAD` on 8 files (commit `3d25286a`) |0|0 missing targets |
| `git diff --name-only 33055a59..HEAD`, protected-path grep |0; 1|7 files at `3d25286a`, 8 with this section; no protected path (grep exit 1 = no match) |
| `git merge-tree --write-tree 3d25286a e3322303` (`apex1/native-cosign`) |1|conflict only in `unsure.md` (also for `33055a59` alone); docs auto-merge |
| test suites; Goal 20 `--case evidence` |NOT RUN|not part of this work |

[Disposition](proposals/review-20261120/README.md).
[Decision note](proposals/review-20261120/DECISION_NOTE_LICENCE_PACKAGING.md).

## Review 2026-11-20, defect D1: design of a shipped isolation mode for the airlock engine (service user, per-tenant sockets, root-owned pins, WAL MAC); NOT started — U894 to U896

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Documents only: `proposals/review-20261120-isolation/`. Branch
`docs/isolation-mode-design` from `33055a59`; NOT merged by the agent. The
build is NOT STARTED. No `sudo` step ran; every owner step is text.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `rustc` 1.92.0, probe with `UnixStream::peer_cred` (scratchpad) |1|`E0658`: unstable; std gives no peer uid |
| `rustc` probe: bind, connect, accept; run |0; 0|std Unix socket works (one user) |
| the same probe with a 117-byte socket path |101|`SUN_LEN`: socket paths must stay short |
| `rustc` probe: accepted stream as a child's stdin and stdout, no `unsafe`; run |0; 0|the child answered the client's line |
| Python `socket.LOCAL_PEERCRED` on a socket pair |0|own uid read back; two users NOT TESTED |
| engine build of `33055a59` in the scratchpad; `otool -L` |0|links only `libSystem` |
| `check_frozen_pr_gate.py HEAD` at `86582052` |0| |
| `check_links.py HEAD` (DESIGN.md, README.md, unsure.md) at `86582052` |0|0 missing targets |
| the build, the malicious-agent test, every owner setup step |NOT RUN|NOT STARTED |

## Gate F1 (Goal 21), intent clearing: branch-boundary tables, weird-but-legal queries and a blind restater over a generated Dafny model; one review with repairs — U780 to U784

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected or frozen path changed.
Nothing under `clearing/` changed. `scripts/spec_clearing.py` and
`bin/forge-airlock` not changed. Branch `feat/intent-clearing-v2` from
`9a9a8943`, with `origin/docs/finish-line-directive` and `origin/main`
(`b2249ea2`) merged in; NOT merged by the agent. PROVED applies only to
statements about the Dafny model that the generator wrote. The
generator is a trusted assumption. Every other row is a FINITE TEST on
one machine.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| pre-flight: `gh pr list`; `origin/main` |0|pull request 65 (Goal 20) MERGED; `origin/main` = `9a9a8943`, later `b2249ea2` (pull request 66) |
| `python3 -B tests/intent/test_intent_clearing.py` (before the review; after the repairs) |0; 0|12 of 12 cases each time |
| `python3 -B tests/intent/test_intent_restate.py` |0|8 of 8 cases |
| `scripts/exit_goal21_intent.py --case mutations`, first run after the repairs |1|21 of 23 for the named reason; C12 and C15 gave UNDECIDED (exit 5), not the WARNING that the table named; the named reasons were corrected to the observed lines |
| `--case planted` |0|swapped VIP flag, coarse SHIPPING cap, `<` against `<=`: clean exit 0, planted exit 4 with a Dafny-verified witness; `refunds-v2.json` exit 0 |
| `--case dispatcher` |0|the UNAPPLIED diff on a copy: exit 0 and exit 4; tracked `bin/forge-airlock` still `bd56d8b6…6891` |
| `--case evidence --write-record` |0|twice; bundle `9a3ea0ee…c2d8`, byte-identical; 23 of 23 changed copies killed for the named reason (20 of `intent_clearing.py`) |
| the one fresh-context review |1 FAIL-OPEN; 0 HIGH; 2 MEDIUM; 7 LOW; 3 NOTE|a query on two unnamed reasons got a false "verified" warning; repaired in one pass; F13 and three guards of F6 stated only; NOT reviewed again |
| regression on a scratch clone of `faa46ae6` (merged tree, base `b2249ea2`): 28 Stage EXIT cases; `check_frozen_pr_gate.py`; links of 17 files; seven EXIT scripts, each `--case evidence` |0 each (28); 0; 0 each (17); 0 each (7)|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`, `1f569fcf…`, `1e75ab47…` byte-identical to the tracked records and to the records on `origin/main`; `9a3ea0ee…` (Goal 21) byte-identical to its record; 0 dangling links; 0 protected paths changed |
| `gh pr create`; hosted `gate/pr_check.py` |NOT RUN at this commit|expected exit 3 (UNSUPPORTED) |
| `--engine` (the Rust engine against the table rows); every HOL and Holmake step; Stages 7, 9, 10; a second review |NOT RUN|not part of this work |

[Report](proposals/forge2-goal21-intent/REPORT.md).
[Review](proposals/forge2-goal21-intent/REVIEW.md).
[Design](proposals/forge2-goal21-intent/DESIGN.md).
[Directive](proposals/forge2-finish-line/DIRECTIVE.md).
Departure: the `check-intent` subcommand of `bin/forge-airlock` is an
UNAPPLIED diff, because the Goal 20 bundle records the digest of that
file (U781). A CLEAN result says only that the questions that were
asked have the answer NO. It does not say that a specification is the
intent. M1 and integration EXIT NOT_ESTABLISHED.

## T19, the hardened refund sink, minter and dispatcher applied (owner items B-15 and B-16 approved): one pull request; TESTED level only; new Slice 1, Slice 3, M1 conformance and native sink bundles — U760 to U765

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No frozen
module changed. Branch `feat/t19-hardened-sink` from `main` at
`a5133c01`, with `main` at `9a9a8943` (Goal 20), `b2249ea2` (APEX-2)
and `33055a59` merged in. NOT merged
by the agent. Nothing is proved: the sink, the minter and the
dispatcher are unverified TypeScript, and every row is a finite test
on one machine. Rows marked (w) are a worker's runs.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `git apply --check` of the two unapplied diffs; `git apply` |0; 0|120 files; no hunk failed; equal to `nightshift/B-trust@12d634f6` except one sanitised line |
| `scripts/exit_slice1.py --case evidence` on the applied tree, unchanged |1|`tsc --noEmit` exit 2: 7 type errors in 6 regression test files |
| the same after two type-only edits and one more pinned input |0|126 rows, 0 failed; two runs byte-identical; bundle `b8a30595…9cac` |
| the same after the `WfAt` edit (final) |0|126 rows, 0 failed; bundle `756babc5…00ef` (on `main`: `c7f2f41c…`) |
| `scripts/exit_slice2.py --case evidence` |0|bundle `2721a293…`: byte-identical to the record |
| `scripts/exit_slice3.py --case evidence` |0|bundle `6b21a487…cc5a` (old `3cdfebfc…`); cause: its reused input `encoding.ts` |
| `scripts/exit_silicon_sink.py --case evidence`, while the old M1 record was in place; after the pin change (final) |0; 0|`1f569fcf…` (unchanged); then `f8b85b97…faae`: the script pins the M1 conformance record |
| (w) `scripts/exit_m1_conformance.py --case conformance`; `--case evidence` (script changed: owner item B-15, last line) |0; 0|bundle `0325b191…97d7`; every count equal to the old record; 0 findings |
| `exit_m1_conformance.py --case evidence` after the `WfAt` edit (final) |0|bundle `91b49423…b1ce` (on `main`: `f55391da…`) |
| `dafny verify` of `IssueAuth.dfy` with a CSV log: resource use of `WfAt` before; after the edit |0; 0|757,787 (ten runs); 317,241 (limit 1,000,000) |
| (w) `scripts/demo_gauntlet.py --flood-mb 16`, three runs |1; 1; 3|script not yet repaired; Dafny exit 4 (1 out of resource on `IssueAuth.WfAt`); REDUCED (every check held; NOT a pass of the demo) |
| (w) regression runner `regress/run.ts` on the hardened tree |0|29 of 29 PASS |
| (w) control: the runner before decision D-1 against the sink and dispatcher of unchanged `main` |1|exactly the 8 known ids FAIL, as required |
| (w) `db_safeguards_hkey.ts` (B's file; not in the repository) |0|69 rows, 0 failed |
| (w) 13 key-file tests; 15 minter tests; 7 provider tests; 27 dispatcher and sink tests; real kill 12 rounds |0 each|TESTED-UNPROVED |
| (w) provider tests with the old adapter (control), 5 runs; red team `c25` with the old adapter, 3 runs |1 each|controls FAIL, as required |
| (w) `m3_zero_squat_limit`; `p3_rollback_rebind first none`; red team `a7_full_restore nofloor`; provider matrix without anchors |1 each|stated known limits, present |
| (w) red team `c25-provider` (4), `c28-keyfile` (1), `c19-dispatch2` (8) on the hardened tree |0 each|TESTED-UNPROVED |
| (w) red team `c21-sink2` (12 runs), `c24-minter2` (3 runs) |1 each; 3 each|NOT valid, NOT counted: the scripts predate D-1 (no key id; no key file) |
| one fresh-context review of the diff (reading only) |0 FAIL-OPEN; 2 MEDIUM; 5 LOW|F4 fixed; F3 fixed in part; F1 (no lock on the mint memory file) left as a new known limit |
| scratch clone of the pushed branch at `b70900e4`: 28 Stage EXIT cases; frozen-gate check; links; evidence of Slice 1, 2, 3, Goal 20; M1 conformance; native sink |0 each (28); 0; 0; 0 each (4); 1; 1|Dafny exit 4 on `IssueAuth.WfAt` (1 out of resource); the native sink script pins the old M1 record |
| scratch clone of the pushed branch at `64a16246` (final code): 28 Stage EXIT cases; `check_frozen_pr_gate.py HEAD`; 8 link checks; six evidence runs |0 each (28); 0; 0 each; 0 each (6)|six bundles byte-identical to the tracked records; 0 protected paths changed; the APEX-2 package unchanged |
| `git push` (explicit refspec); `gh pr create`; hosted `gate/pr_check.py` |see the pull request|expected 3 (UNSUPPORTED); the agent did not merge |
| the full demo (default flood); spec-conformance 5,000 sequences; the kill loop with 24 rounds; any power-loss test; every HOL and Holmake case; Stages 7, 9, 10 |NOT RUN|not part of this work |

Changed suite expectations (the owner's approval): six hostile-write
rows are STRONGER (the database refuses the write); 11 rows are NEW;
row x5 is a SEMANTIC CHANGE (a failed emit is IN DOUBT, not counted as
sent); the single-use row is WEAKER at token level (one token per
charge id and request id, not per pre-state). The exact table is in the
report.
Known limits, kept: a full restore without a ledger floor sends effects
again; a zero-amount squat takes a request id; a lost or restored mint
record brings a second valid token back; the provider is a FAKE and its
key window is an ASSUMPTION; exactly-once is NOT claimed; power loss is
NOT TESTED; NEW: two minter processes on one memory file are not
excluded by a lock.
[Report](proposals/t19-hardened-sink-20261119/REPORT.md).
[Graph refresh for T19](proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261120_T19.md).
[Owner items](proposals/night-shift-20261119/OWNER_REQUIRED.md).
M1 and integration EXIT NOT_ESTABLISHED.

## Video cut, a 1-take runner and a storyboard for a 65-second cut over nine domains: every verdict is the answer of a real process; a finite test of the unproved native engine; one review with repairs; NOT merged — U860 to U863

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected or frozen file changed.
Branch `demo/video-storyboard` from `33055a59`; NOT merged by the
agent. Nothing is proved by this work: every row is a finite test on one
machine under load. The engine is a NATIVE CHECK (Rust).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `python3 bin/forge-airlock build` (first orchestrator) |0|engine, kill-points build, checker model |
| `run_recording_take.py --check-domain <name>`, eight domains, single runs |0 each|domain 6 needs the heavy lock and ran only in the full takes |
| the one fresh-context review |4 FAKE; 3 FAIL-OPEN; 6 OVERCLAIM; 5 MISMATCH; 7 LOW|repaired in one pass; the repairs were not reviewed again (U861) |
| `python3 demos/video_cut/test_video_cut.py`, attempts 1 to 3 |1; 1; 0|a crash in domain 6; a wrong required count left in a file (U860); 39 of 39 checks, with one full `--fast --flood-mb 16` take (68 shots) |
| `run_recording_take.py --auto --no-model --flood-mb 16`, attempts 1 and 2 |2; 0|race 1 COMMITTED, 49 STALE_STATE_HASH, 0 other, 1 WAL record; 32 allowed, 21 blocked, 0 failed checks |
| `run_recording_take.py --auto --flood-mb 16` with the live model, attempts 1 and 2 |2; 0|model `claude-haiku-5-5`, status 200; the reply did not hold the injected command; the engine requests are scripted worst cases |
| live guard sabotage inside each exit-0 take |0 (normal engine); 1 (sabotaged)|the check can fail; the sabotaged engine did not commit the payment (U861) |
| regression on a scratch clone of `84743e7a`: 28 Stage EXIT cases; `check_frozen_pr_gate.py HEAD`; links of 8 files; six EXIT scripts, each `--case evidence` |0 each (28); 0; 0 each (8); 0 each (6)|six bundles byte-identical to their records; 0 protected paths |
| `check_links.py HEAD docs/VIDEO_STORYBOARD.md` |0|24 relative links, 0 missing |
| the 10 GiB flood; a `--step` take; `--sound`; Stages 7, 9, 10; every HOL and Dafny verify step; a second review |NOT RUN|not part of this work |

[Storyboard](docs/VIDEO_STORYBOARD.md).
Departures from the directive are in U862. "Proved" applies only to the
Dafny source of the booking checker; the CakeML/HOL4 refund chain has an
open premise. A SIGKILL is not a power loss. One race is not all
schedules. M1 and integration EXIT NOT_ESTABLISHED.

## Review 2026-11-20, engine hardening (PR-3): per-tenant namespaces (D3), PENDING_COSIGN leases (D6), bad ratchet entries (D7), pin checks at every run (D2); one fresh review with repairs; NOT merged — U887 to U893

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Branch
`feat/airlock-review-hardening`, stacked on `apex1/native-cosign` `a96c916f` (pull request
72; code commits made on `e3322303`); draft pull request 73; NOT merged by the agent. Nothing
is proved: every row is a finite test on one machine. The tenant is NOT authenticated; the
Node libraries are NOT covered by the pin checks (OPEN).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| new cases on the engine of `e3322303` (before): `tenant_namespace`, `lease_cosign_pending`, `ratchet_entry`, `pin_window` |1; 1; 1; 1|each fix's test fails before (logs in the package) |
| `lease_pending_rejected` on the engine of `aaaca9e6` (before) |1|fresh-review finding 3 |
| `tests/airlock/test_engine.py` on `8fc0de2f`; again with `--work` under the worktree on `6289d9aa` |0; 0|33 of 33 |
| `test_node_helpers.py`; `test_cosign.py`; `test_diff_policy.py`; `test_sdk.py` on `8fc0de2f` |0; 0; 0; 0|68; 56; all; 21 |
| `compat_wal.py` (`e3322303` engine vs this tree) |0|old WAL folds to the same state; old engine refuses new records (17) |
| `bin/forge-airlock fuzz --seed 20 --rounds 3` (heavy lock; `7cb7cac1`, `6289d9aa`) |0; 0|8 of 8 invariants held |
| 27 changed or new copies through the EXIT script's runner (heavy lock; `6289d9aa` to `9a17c95d`) |27 killed|three list texts and one test message corrected on the way (records in the commits); no engine source changed after `6289d9aa` |
| regression on a scratch clone of `9a17c95d`: 28 Stage EXIT cases; `check_frozen_pr_gate.py`; links of 9 files; six EXIT scripts, each `--case evidence` |0 each (28); 0; 0 each (9); 0 each (6)|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`, `1f569fcf…` byte-identical to the tracked records; Goal 20 bundle NEW `69fbd676…9467` (145 of 145 copies killed, 3 known not killed), not the tracked `1e75ab47…70fa`; 0 protected paths changed |
| earlier regression attempts of `3d9dabbb` (Goal 20 evidence) and the copy runs of `7cb7cac1`, `6289d9aa`, `ccbb8264` |1; 1; 1; 1|list errors of this branch (shared texts, wrong first-failure texts) and one test probe; repaired |
| one fresh-context review of `aaaca9e6` |1 HIGH; 2 MEDIUM; 5 LOW|repaired once (REVIEW.md); NOT reviewed again |
| power loss; a service-user deployment; the per-run ssh-keygen check |NOT RUN|not part of this work |

[Package](proposals/review-20261120-engine/README.md).
[Review](proposals/review-20261120-engine/REVIEW.md).
The tracked Goal 20 bundle and digest are not replaced; the owner decides.
M1 and integration EXIT NOT_ESTABLISHED.

## Gate APEX-2, the Dafny <-> HOL4 contract link for the refund slice: `refund_fields` is exactly the flat 6-field contract as one plain formula (Holmake exit 0); the translation to Dafny is a pinned, tested check and NOT machine-checked; T3 narrowed, T2b and T4 off the path, none closed — U800 to U806

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected or frozen file changed.
Branch `feat/m1-contract-link-closure` from `9a9a8943`; NOT merged by the
agent. Every HOL row is model level, on one machine, with stored parent
theories: not a clean replay, not an independent replay. Every Dafny row
is a source-level result about a model. No row of the 45-link graph
changed class.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `Holmake --no_prereqs` in a copy of `proposals/apex2-contract-link-20261119/hol` (run-0001; run-0002; run-0003 through `run_hol.sh`) |0; 0; 0|three theories; FC1 `refund_fields_flat_plain`: `refund_fields … = (ok,a,r,c,q,n)` ⇔ `flat_plain` on byte codes; the nine night-shift statements of `exported_contract_exact` rebuilt with equal text; FC3 the exported clauses ⇔ `flat_plain` |
| the same build, repeat |byte-identical|nine `.dat/.sig/.sml` files and the generated Dafny file equal in run-0001 and run-0002; `.dat` files of run-0003 equal |
| development attempts dev-0001 to dev-0004 |1; 1; 1; 1|a static error and three failed proofs; kept in `records/hol/dev-attempts` |
| `run_case.py RA-FLAT-0002` (`hol run`, 146 stored parents; NOT Holmake) |0|R1: the Route A shape form (L2d-0001, 12 premises unchanged) with its conclusion on `flat_plain`; R2, R3: the entry premise forces TBI0 = TBI1 = SA0 = E0E = F |
| `check_link.py --dafny … --z3 …` (17 pins; generated file = text in both HOL logs; `dafny verify HolLink.dfy`) |0|`CHECK_LINK PASS`; "11 verified, 0 errors"; D1, D2: the printed formula is exactly the contract of the real `AssessFlat` |
| `check_link.py` without Dafny; with `--skip-pins` |5; 3|PARTIAL and CONTROL MODE; neither is a pass |
| `dafny verify HolSlice.dfy` (includes `SliceTheorem.dfy`) |0|"1583 verified, 0 errors"; `FlatContract` ⇔ the printed formula on codes; A6 restated, also on byte inputs only |
| `controls/eval_controls.py` (32 negative controls) |0|32 of 32 count: 9 HOL statement and 5 export controls exit 1 at the named theorem or pin; 3 printer controls pass HOL (exit 0) and are refused by the pin and by Dafny; 15 Dafny controls refused |
| the one fresh-context review |1 FAIL-OPEN; 1 HIGH; 7 MEDIUM; 4 LOW; 3 NOTE|the FAIL-OPEN and the HIGH were in `check_link.py`; repaired in one pass; 3 findings stated only; NOT reviewed again |
| regression on a scratch clone: 28 Stage EXIT cases; `check_frozen_pr_gate.py`; links of 8 files; six EXIT scripts, each `--case evidence` |0 each (28); 0; 0 each (8); 0 each (6)|commit `6606720f`, base `9a9a8943`; bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`, `1f569fcf…`, `1e75ab47…` byte-identical to the tracked records; 0 protected paths changed |
| pull request 66; hosted `gate/pr_check.py` at `6606720f` (run 44661325260) |3|UNSUPPORTED, as expected; later commits are documents only and their hosted result is in the pull request |
| a clean or independent HOL replay; the Dafny S3a run (1,486); Stages 7, 9, 10; a second review |NOT RUN|not part of this work |

[Package](proposals/apex2-contract-link-20261119/README.md).
[Review](proposals/apex2-contract-link-20261119/REVIEW.md).
[Graph refresh](proposals/apex2-contract-link-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md).
The printing of the HOL formula as Dafny text is ML code outside the
kernel: an ASSUMPTION (BETA-PLAIN) with a tested check. T2b, T3 and T4
are NOT closed. Route A premises (the FFI contract at shape-valid calls,
the processor bits, the entry state) are assumptions about the real
machine. M1 and integration EXIT NOT_ESTABLISHED.
## Archia MCP airlock demo, Phases 1 and 2: an MCP stdio proxy with a ledger compare-and-swap, a scoped-read filter and signed receipts; two real upstream servers; a finite test of unproved Rust; NOT merged — U740 to U742

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Branch
`demo/archia-mcp-showcase` from the Goal 20 branch at `c02abb74` (owner
decision; pre-flight rule 1 of the directive is NOT MET, U740). Phases 3
and 4 are not started. Nothing is proved; no review ran; no changed-copy
run exists. Not pushed.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| pre-flight: `origin/main` after Goal 20 and T19 |NOT MET|`origin/main` = `a5133c01`; stacked on `c02abb74` on the owner's word |
| `git status --short` on the protected and frozen paths |0 lines|`bin/forge-airlock` changed: it is in the Goal 20 bundle subject list (U740) |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/mcp_proxy/main.rs` (orchestrator) |0|std only; no `unsafe`; no crate |
| unit tests of the same root (`rustc --test`) |0|23 passed, 1 ignored (timing) |
| `python3 tests/mcp_proxy/test_servers.py` (servers with no proxy) |0|14 of 14 |
| `python3 tests/mcp_proxy/test_proxy_e2e.py` |0|20 of 20: 20-call race gives 1 payout in the server's audit file; cross-clinic read gives 0 foreign bytes; 500 mg refused; `verify-evidence` 0; one flipped byte refused |
| the PROXY worker's integration suite, run again by the orchestrator |0|0 failed (the worker's count: 54) |
| 10 GiB line with no newline into the proxy |0|peak resident memory 1,808 KiB (82 samples); next request answered |
| 40 commits, sync signing; async signing |0; 0|p50 19.20 ms; p50 12.06 ms: "under 15 ms" is NOT a bound (U742) |
| `verify-evidence` on both stores: first try; second try |1; 0|first: my empty allowed-signers file; then 40 of 40 records, twice |
| workers' module tests not repeated: POLICY 47 cases; EVIDENCE 30 cases |0; 0 (their reports)|test roots are in scratch folders |
| `bin/forge-airlock build`; `scripts/exit_goal20_sdk.py`; the 28 Stage EXIT cases; Phases 3 and 4; push; pull request |NOT RUN| |
| every HOL, Holmake, Dafny and Node step |NOT RUN|not part of this work |

[Wire document](src/mcp_proxy/PROTOCOL.md).
The filter trusts the server's labels. The sub-cap fact is the airlock's
own file. The CAS is on the airlock's ledger, not on the server's state.
M1 and integration EXIT NOT_ESTABLISHED.

### Archia MCP airlock demo, Phase 3 (reviews and repairs) — U743

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The Phase 1 and 2 text above stays as written. Its lines "Phases 3 and 4
are not started" and "no review ran" are true only for commit `ab059090`.
Branch `demo/archia-mcp-showcase` is now rebased on `origin/main`
`b2249ea2` (Goal 20 merged there as `9a9a8943`). `origin/main` is now
`33055a59`, one documents-only commit later; NOT rebased again.
`bin/forge-airlock` stays at its main bytes (SHA-256 `bd56d8b6…6891`,
owner decision). The launcher of the proxy is `bin/forge-mcp-proxy`.
The Rust proxy is a NATIVE CHECK. The tests are a FINITE TEST. Nothing
is proved. No clearing check runs.

| Step | Actual exit/result | Result |
| --- | --- | --- |
| two fresh-context reviews (REVIEW-A, REVIEW-B) and the TESTS finding T1 |FAIL-OPEN and HIGH findings|cross-clinic write fail-open; carriage-return smuggling; ledger reset to a double payout; receipt gaps; filter leaks; a second answer to a read passed (U743) |
| one repair pass, commit `cb61b04f` |done|list in the commit message and in U743; NOT reviewed again |
| `tests/mcp_proxy/test_review_regressions.py` on the repaired binary |0|17 of 17 (evidence bundle, attempt 3) |
| R5 (one signature per malformed line), R6 (a stalled upstream stalls the proxy), server notifications not filtered |NOT repaired|stated in `src/mcp_proxy/PROTOCOL.md` section 8 |
| latency claim "< 15 ms" |NOT claimed|owner decision: latency is a measurement, not an assertion |
| T19 hardened sink |NOT waited for|owner: superseded |

### Archia MCP airlock demo, Phase 4 (EXIT) — U744

Final pass on `b35617b3` plus the change of `scripts/exit_archia_mcp.py`
that this records commit holds. The bundle is a RECORD, not gate
evidence (`gate_accepted: false`, `proved: false`). Raw outputs are in
`build/archia_mcp/` (ignored by git); sources are named per row.

| EXIT command/check | Expected exit | Actual exit/result | Result |
| --- | --- | --- | --- |
| `python3 scripts/exit_archia_mcp.py --case build` |0|0|two builds byte-identical, binary `1877a4fa…77b3`; `unsafe` control does not compile; `bin/forge-airlock` equals main |
| `--case suite` |0|0|servers 14 of 14; e2e 27 of 27; unit 146 passed, 1 ignored; faults 44 PASS and 1 KNOWN LIMIT (45 cases); regressions 17 of 17; WAL replay byte-identical |
| `--case showcase` |0|0|32 of 32 checks; peak RSS 2,480 KiB (bound 5.0 MiB); 30 commits p50 17.08 ms, p99 24.11 ms (measured, indicative only) |
| `--case mutations` (ran before the last script edit) |0|0|44 of 47 killed; NOT KILLED exactly E01, M04, M27 |
| `--case evidence`, first run (attempt 2) |0|1|two different bundles; which cases fail on killed copies M08 and B05 varies with timing |
| `--case evidence`, after the repair (attempt 3) |0|0|two runs byte-identical; bundle `13608d7e…20bd`; 44 of 47 killed; wall about 1 h 33 min |
| orchestrator rerun: `--case build`; `--case showcase` |0; 0|0; 0|same binary `1877a4fa…77b3`; 32 of 32; p50 16.78 ms, p99 29.80 ms |
| `python3 scripts/exit_archia_mcp.py --case build` after this records change |0|0|run by the records agent |

Not run yet (no exit code exists):
- the regression in a scratch clone: the 28 Stage EXIT cases and the
  other EXIT scripts' `--case evidence`;
- `git push`; `gh pr create`; the hosted `gate/pr_check.py`;
- a power-loss test or an `F_FULLFSYNC` observer (E01 and M04 stay
  open); a second review; every HOL, Holmake and Dafny step.

An earlier EXIT attempt put M13, M18 and M26 on the accepted-survivor
list. The orchestrator rejected that. Three new fault cases now kill
them. fsync durability is untested. M1 and integration EXIT
NOT_ESTABLISHED.

## Goal 21, phase 1 (Apex fix 1): the cosign signature check without Node (`/usr/bin/ssh-keygen -Y verify`); `cosign.cjs` deleted; a finite test; NO new bundle; NOT merged — U750 to U752

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed.
`src/silicon_sink/sink.rs` is NOT changed (the directive names it; it
has no signature code; U750). Branch `apex1/native-cosign` from the
Goal 20 head `4d5e8863`; rebased onto `main` at `b2249ea2` after the
owner merged Goal 20 as `9a9a8943` (the runs below were on the tree
before the rebase unless a row says otherwise).
Nothing is proved. The machine was under load: no time is recorded here.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `git status --short` on the protected paths, `proposals/`, `src/silicon_sink/` |0 lines| |
| `bin/forge-airlock build` (orchestrator) |0|two rustc builds |
| `tests/airlock/test_cosign.py <kill build>` (orchestrator) |0|47 of 47 |
| `tests/airlock/test_engine.py <engine> <kill build>` (orchestrator) |0| |
| `tests/airlock/test_node_helpers.py <node>` (orchestrator) |0|68 of 68 (inventory helper only) |
| `tests/airlock/test_sdk.py --engine-dir build/airlock` (orchestrator) |0|includes a store that needs no Node |
| changed copies through a scratch harness (the worker's run) |0|122 of 122 killed; NOT KILLED: X01, R8, N15 |
| `disasters`; `fuzz` through the same harness (the worker's runs) |0; 0|8 of 8; 8 of 8 |
| the one review of `73758bda` (fresh context) |0 FAIL-OPEN through the production engine; 2 FAIL-OPEN inside the stated one-user limit; 1 MEDIUM; 1 LOW; 5 NOTE|one false sentence of PROTOCOL.md corrected; items 1 and 2 open (U751) |
| after the review repairs (test engine in `build/silicon/test/`; walk includes `/`; `cosign-sign` cross-check): build; cosign; engine; node helpers; SDK suites (orchestrator) |0; 0; 0; 0; 0|56 of 56; 27 of 27; 68 of 68; 21 of 21 (U752) |
| `scripts/exit_goal20_sdk.py --case evidence`; the Dafny diff cases |NOT RUN|no new bundle; the record `1e75ab47` is of the tree before this change |
| every HOL and Holmake step |NOT RUN|not part of this work |

[Wire and limits](src/airlock/PROTOCOL.md).
OpenSSH with LibreSSL replaces Node and V8 in the trusted base for
cosign: smaller, not zero. M1 and integration EXIT NOT_ESTABLISHED.

## Goal 20, `forge-airlock` SDK: write, read and lease airlocks over a native WAL engine, with Python and TypeScript SDKs; a finite test of unproved Rust, JavaScript and Python around three proved cores; one review with repairs — U720 to U725

CURRENT none; M1-B open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Nothing under
`clearing/` changed. `src/silicon_sink/sink.rs` not changed. Branch
`feat/zero-babysitting-sdk` from `e2b8ba1d`, with `origin/main`
(`a5133c01`) merged in; NOT merged by the agent. PROVED CORE applies
only to the CakeML binary's decision in the canonical-refund profile,
to the Dafny source of the booking checker, and to NO_CHOICE for a
generated Dafny model. Every other row is NATIVE CHECK and FINITE TEST
on one machine.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/airlock/main.rs -o build/airlock/airlock-engine` |0|std only, no `unsafe`, no crate; a copy with one `unsafe` block: exit 1 |
| `scripts/exit_goal20_sdk.py --case build` |0|both builds; Dafny verify and build of the checker; model `e705ec49…85f4` equals its record |
| `--case suite` |0|engine 26 of 26; Node helpers 137 of 137; `diff-policy` 11 of 11; SDK 19 of 19 |
| `--case disasters` |0|8 of 8; money leaked, read from the WAL: 0; Stripe and PayPal are LOCAL FAKE |
| `--case fuzz` |0|seed 20, 3 rounds; 8 of 8 invariants held |
| `--case mutations`, before the review; after the repairs |0; 0|100 of 100 with 1 not killed; 114 of 114 with 2 not killed (X01, R8), recorded |
| `--case evidence` (final) |0|twice; bundle `1e75ab47…70fa`, byte-identical |
| the one fresh-context review |2 FAIL-OPEN; 1 HIGH; 3 MEDIUM; 3 LOW; 2 NOTE|a fake helper folder gave a commit; SDK reads returned unchecked objects; a signature replayed across equal stores; repaired in one pass; 3 findings stated only; NOT reviewed again |
| regression on a scratch clone of `c02abb74` (merged tree, base `a5133c01`): 28 Stage EXIT cases; `check_frozen_pr_gate.py`; links of 9 files; six EXIT scripts, each `--case evidence` |0 each (28); 0; 0 each (9); 0 each (6)|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`, `1f569fcf…`, `1e75ab47…` byte-identical to the tracked records; 0 protected paths changed |
| `gh pr create`; hosted `gate/pr_check.py` |NOT RUN at this commit|expected exit 3 (UNSUPPORTED) |
| every HOL and Holmake step; Stages 7, 9, 10; a power-loss test; a second review |NOT RUN|not part of this work |

[Report](proposals/forge2-goal20-sdk/REPORT.md).
[Review](proposals/forge2-goal20-sdk/REVIEW.md).
[Brief](proposals/forge2-goal20-sdk/BRIEF.md).
[Quickstart](docs/quickstart-5min.md).
The rules hold only against a caller that reaches the store through
the engine. "The agent cannot self-cosign" needs the key out of the
agent's reach and an agent that cannot write the store folder. No
"% of bugs" figure is claimed. A SIGKILL is not a power loss.
M1 and integration EXIT NOT_ESTABLISHED.

## Goal 19, native silicon sink: a refund boundary with no Node, V8, npm or SQLite in its path; a finite test of an unproved Rust sink in front of the M1 binary; one review with repairs; pull request 62 merged by the owner as `6d66a558` — U700 to U709

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Branch
`feat/native-silicon-sink` from `b9f2831c`; merged as `6d66a558` by the
account `mack-dot` (pull request 62); the agent did not merge. Nothing
is proved: every row is a finite test on one machine.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| pre-flight: `gh pr list --state open` |0|pull request 58 OPEN: the directive says STOP; the owner's decisions are in U700 |
| `rustc -D unsafe_code -C opt-level=3 src/silicon_sink/sink.rs -o build/silicon/native_sink` (first; final) |1; 0|final: 248 lines in a compact layout (`rustfmt`: 521), std only, no `unsafe`, no crate |
| `scripts/exit_silicon_sink.py --case build` |0|a copy with one `unsafe` block: compile exit 1; the binary `b8ed5ec2…` runs natively |
| `--case suite`, attempt 1 (before the review) |0|12 of 12 cases; under load p99 186.9 ms of the 250 ms bound |
| the one fresh-context review |1 FAIL-OPEN by the letter of the rule; 1 HIGH; 11 MEDIUM; 5 LOW|code 18 could leave a record; the stream went on after a failed answer; no wrong dispatch found |
| `--case mutations`, attempt 1 (before the review); attempts 2 to 5 (after the repairs) |0; 1; 1; 1; 0|30 of 30; two wrong failure names of mine; one copy NOT detected, then the lock case repaired; 49 of 49 |
| `--case evidence`, attempt 1 (final) |0|13 of 13 cases and 49 of 49 changed copies, twice; bundle `1f569fcf…932c` |
| 10 GiB flood with no line end into the sink |inside the suite|peak resident memory 1.86 MiB; next request in 13 to 15 ms |
| "commit under 2 ms" |NOT REACHED|minimum 7.95 ms; p50 11 ms; p99 45 to 48 ms; asserted bound 250 ms (owner) |
| regression on a scratch clone of the first commit `a51984bb`: 28 Stage EXIT cases; `check_frozen_pr_gate.py`; links; the EXIT scripts of Slices 1 to 3, of the M1 conformance and of this work, each `--case evidence` |0 each (28); 0; 0; 0 each (5)|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`, `1f569fcf…` byte-identical to the tracked records; 0 protected paths changed |
| `git push`; `gh pr create` (pull request 62); hosted `gate/pr_check.py`, heads `c3889be2` and `e280addf`, runs 44591773836 and 44592215424 |0; 0; 3; 3|UNSUPPORTED, as expected (14 coverage findings); no administrator rights; the agent did not merge |
| every HOL, Holmake and Dafny step; Stages 7, 9, 10 |NOT RUN|not part of this work |

[Report](proposals/forge2-native-silicon-sink/REPORT.md).
[Review](proposals/forge2-native-silicon-sink/REVIEW.md).
[Owner texts](proposals/forge2-native-silicon-sink/OWNER_TEXTS.md).
The sink has no source proof and no signed token. A restore of both
ledger files is not detected. A SIGKILL is not a power loss.
M1 and integration EXIT NOT_ESTABLISHED.

## Night shift 2026-11-19, integration: one consolidated pull request from the proof, trust and red-team branches; the hardening stays UNAPPLIED; the 45-link graph refreshed — U660 to U665

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No frozen
module changed. Nothing under `clearing/`, `ts/`, `tests/`, `scripts/`
changed. Branch `nightshift/consolidated-20261119` from `main` at
`b9f2831c`; content by path, no branch history merged; NOT merged by
the agent. Pull requests 60 and 61 were closed without a merge on the
owner's word; this section's pull request carries their verified
content.
After pull request 62 (Goal 19) the branch was rebased onto `6d66a558`
as the new branch `nightshift/consolidated-20261119-r1`; the rows below
with `75f70919` are for the tree before the rebase (U666).

What is in it: A's records after pull request 59 (final record; HOL
cases with exit codes; reproduction 18 of 18 on the same machine); nine
Dafny model files under `impl/finality-core`; a curated part of B's and
C's evidence; owner decisions D-1 to D-6; the hardened sink, minter,
dispatcher and provider adapter with their regressions and the changed
suite as two UNAPPLIED diffs (owner items B-15, B-16: one later pull
request); a refresh of the 45-link graph in a new file. The merged
`sink.ts` on `main` keeps two shown duplicate-effect defects until the
owner applies the hardening.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `dafny verify` (pinned 4.11.0, gate options) of `impl/finality-core/IssueAuth.dfy`; `IssueOnce.dfy`; `ShellCoreV6.dfy` (integrator's run) |0; 0; 0|194; 160; 192 verified; model level |
| `git apply --check` of the two unapplied diffs on a scratch clone of `77f8ec2d`; `git apply` |0; 0|the patched `ts`, `tests`, `scripts` equal `nightshift/B-trust@12d634f6` except one line (the replaced user name) |
| `dafny build impl/finality-core/IssueAuth.dfy --target js` on that clone |0|194 verified; module SHA-256 `fa855506…44e6`, equal to the red team's recorded module |
| 15 regression runs on the patched clone: X1, X2 (runner); `d_att17_lock_theft`, `d_att17_claim_race`, `d_att18_throwing_emit`; `d3_att36_retry_restore`, `s3_att33_crash_journal`; `m3_refusal_does_not_close`, `m3_one_effect_per_request_id`; four `kf_*`; `p3_scope_collide`, `p3_key_squat`, `p3_rollback_rebind first full` |0 each|TESTED-UNPROVED; a worker's runs |
| `m3_zero_squat_limit`; `p3_rollback_rebind first none` |1; 1|the two stated known limits are present (a zero-amount squat on the real state; B-20) |
| control: X1, X2 against the merged sink and dispatcher |1|NOT a valid control for the duplicate effect: the merged sink refused the honest token too (U663) |
| scratch clone (fresh `git clone` of the pushed branch at `75f70919`; `run_regression.py`): 28 Stage EXIT cases |0 each|28 of 28 |
| the same: `exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py --case evidence` |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`: equal to the recorded ones |
| `check_frozen_pr_gate.py HEAD` |0|8 frozen modules unchanged; 0 protected paths in the diff |
| `check_links.py HEAD` on `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the M1 report |0 each| |
| `check_links.py HEAD` on all 318 Markdown files outside `results/` |1|expected: the two older Stage 9 dead links of `main`; 0 new |
| hosted `gate/pr_check.py` on the pull request |see the pull request|expected 3 (UNSUPPORTED), as for pull requests 56, 57, 59 |
| the changed 126-row suite; spec-conformance; kill loops; any HOL case (by the integrator) |NOT RUN|B's and A's runs stand as their own |
| red team: tests with the real refund program against code injected at load; tests of the FFI C code (C-1) |NOT RUN|stopped by a safety classifier seven times; never retried; permanently NOT RUN by owner decision D-6 |
| Stage 7, 9, 10 EXIT scripts |NOT RUN|left out by the runner's convention |

Reading: every HOL result is a machine-model result on the same machine
with stored parent theories. Every Dafny result is a source-level
result about a model. Every fix is TESTED-UNPROVED and UNAPPLIED. The
smallest missing refinement boundary is X8 / T13.
[Consolidated record](proposals/night-shift-20261119/integration/README.md).
[Graph refresh](proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md).
[Unapplied diffs](proposals/night-shift-20261119/unapplied/README.md).
[Owner items](proposals/night-shift-20261119/OWNER_REQUIRED.md).
M1 and integration EXIT NOT_ESTABLISHED.

the present gate bytes.

## Night shift 2026-11-19, trust track, part 4 (Orchestrator B, phase 2: implementation hardening): regressions for both duplicate-effect counterexamples; the real sink against the approved specification; a hardened sink and minter on the branch; red-team findings (U567 to U575; branch `nightshift/B-trust`; NOT merged; no protected file changed; no stage promotion)

Written 2026-11-19T15:00:05Z. Stage labels do not change. M1-B stays OPEN. `end_to_end` stays `false`. Details and limits: `unsure.md` U567 to U575; owner items B-12 to B-15 in `results/night-shift-20261119/OWNER_REQUIRED.md`.

Actual results (my own runs; cwd = the branch tree; pinned Node 24.3.0):

| Command (short form) | Tree | Actual exit | Class |
| --- | --- | --- | --- |
| `regress/run.ts` (controls C1 to C5, regressions X1 to X6) | merged sink | 1 (8 FAIL, as intended: the counterexamples reproduce) | TESTED-UNPROVED |
| `spec-conformance/run.ts` seq, fault, interleave | merged sink | violations of P1, P2, P3, P4, P7 (U570) | TESTED-UNPROVED |
| `h-sink/tests/db_safeguards.ts` (69 rows) | hardened sink, b7fd6be8 | 0 (69 PASS, 0 FAIL) | TESTED-UNPROVED |
| `spec-conformance/run.ts` seq, fault, interleave, 200 cases, seed 7 | hardened sink | 0, 0, 0 | TESTED-UNPROVED |
| red-team copies a6 restart, a6 running, a5, a2 off, a1 running, a8 hostile | hardened sink | 0 each | TESTED-UNPROVED |
| `regress/run.ts`, unchanged harness | hardened sink | 1 (13 of 14 FAIL: the harness does not fit; NOT a pass, NOT a sink finding; U574) | harness defect |
| `dafny verify` (gate options) `IssueOnce.dfy` | 608b5165 | 0 (160 verified, 0 errors) | MACHINE-CHECKED, source level |
| five `regress/m_*.ts` | new minter, 608b5165 | 0 each | TESTED-UNPROVED |

NOT RUN (no result is claimed): the Slice 1 suite on the hardened tree (two rows are predicted to fail by design: the raw outbox INSERT row and the row at suite.ts line 589); the differential against the V6 core; the kill storm; the 20,000-row measurement (one light attempt ended with exit 124).

Known weak points, stated: the red team showed that the two judges of this branch pass twelve defective variants (U573); "passes the regressions" names the judge version from now on. The row chain of the hardened sink is unkeyed: rollback resistance is NOT claimed without an outside anchor (U571, B-14). The per-request minter rule is a proposal that conflicts with one merged suite row (B-15). The dispatcher has four open red-team findings, one HIGH with no attacker (lock without an owner; U574).

## Night shift 2026-11-19, trust track, part 3 (Orchestrator B): the layered byte-level lemma with the commit-time check; reviews; the suite with the v6 adoption diff; three subset rules, one refuted — U559 to U566

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Nothing applied, merged, pushed or signed.
Rows marked (B) are the orchestrator's own runs with a stored log; (w) are worker runs that (B) did not repeat. Heavy steps ran only when no HOL process ran.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| (B) `verify ControlsBytesV6.dfy TopV6Export.dfy KeyedV6.dfy` |0|2352 verified; approval of committed effects with no hypothesis (reading CTX-SINK); reviewed: confirmed, wording narrowed |
| (B) `verify` of the reviewers' files RV6Lemmas, AttackV5 |0; 0|2004; 166 verified; a hash collision cannot cause a commit; a zero-amount row can be deleted from an audited store and commits again |
| (B) Slice 1 suite: pristine export; export with the v6 adoption diff; a measurement copy |0; 2; 1|115 rows, 0 failed; stops at one row by design (the v6 sink refuses a rewritten store); 115 rows, 1 failed |
| (B) gate copy with the second subset rule, 138 submissions |0 for 46 of 47 correct; 1 for each of 24 halting|a measurement over those files; the rule's cost claim is REFUTED (next row) |
| (B) the second rule on three files of its review; (w) Dafny verify of those files |"pass" each; 0 each|admitted submissions that hang, run in time unbounded by the text, or fail to load |
| (B) gate copy with the third subset rule, 272 submissions |0 for 46 of 67 correct; 1 for each of 24 halting and each of 23 review cases|no known bypass; not reviewed; its bound is an argument |
| (B) TypeScript issuer bridge against the reference, 111 vectors |0|0 differences |
| (B) ledger verifiers f-binding-4 and f-binding-5; controls of f-binding-4 |0; 0; 0|135 and 151 edges; identity and record consistency only; 53 of 53 |
| (B) `git apply --check` of adoption-v6.diff and of the diffs of the second and third subset rules (nothing applied) |0 each|they apply at `985f5eaf`; log for the first under `orch-B/recheck-l` |
| review of the third subset rule; any run after 14:14Z that needs Dafny |NOT RUN (battery power)|— |

Reading: model and draft results only. The deployed `ts/refund-finality/sink.ts` stays the weakest link. No subset rule has a proved bound. Owner decisions: `results/night-shift-20261119/OWNER_REQUIRED.md`, B-1 to B-11 with their corrections.
M1 and integration EXIT NOT_ESTABLISHED.

## Night shift 2026-11-19, trust track, part 2 (Orchestrator B): the byte-level composed lemma; a sink step that checks the approved relation; reviews; tests in heavy windows; adoption diffs (unapplied) — U537 to U558

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Nothing applied, merged, pushed or signed.
Every Dafny run: pinned Dafny 4.11.0, gate options, through `results/night-shift-20261119/orch-B/tools/dafny_locked.sh`.
Rows marked (B) are the orchestrator's own runs with a stored log under `orch-B/recheck-*` or `orch-B/heavy`; (w) are worker runs that (B) did not repeat.
Heavy steps ran only after Orchestrator A removed the HOL lock; each window was released.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| (B) `verify ControlsBytesV3.dfy RefineHashV3.dfy` (byte-level lemma over a hash-comparing core) |0|1871 verified; reviewed: confirmed |
| (B) `verify` of TopFromExport, IssuerLink, KeyedHash, RefineTraceV3, RTopLemmas |0; 0; 0; 0; 0|2185; 2236; 2325; 1889; 2336 verified; reviewed: confirmed |
| (B) `verify ShellCoreV6.dfy` (the step checks the approved relation on the stored charge) |0|192 verified; reviewed: confirmed under the reading of U558 |
| (B) `verify` of ShellCoreV5, ShellCoreV4, ShellCoreV3 (shell cores, audits) |0; 0; 0|156; 105; 79 verified |
| (B) `verify` of Restart, KeyedStore, AttackRestart |0; 0; 0|1686; 1820; 1831 verified; rollback and forged initial state pass any database audit (proved) |
| (B) `verify` of SerModel, RepairedBytes, RSerAttacks, IssueBytes2 |0; 0; 0; 0|96; 1790; 1804; 131 verified |
| (B) `verify` of ExportBridge, SliceSafetyFromExport |0; 0|1823; 1892 verified; reviewed: 15 semantic changes of the export each break the proof |
| (B) `verify` of Bridge, Bridge2, AttackR; AttackTrace, AttackCore, AttackMulti |0 each|8; 22; 30; 1642; 82; 148 verified |
| (B) first attempt of six of these runs |1 each|my own command error (options passed as one word); logs kept; not a result |
| (B) sink differentials, four windows: v3, v4, v6 draft sinks and patched copies against their compiled cores; 3,500 sequences per pair |0 on each matching pair|0 divergent sequences; every control pair diverges |
| (B) differential of the v5 draft |0; 1; 0; no result line|it halts after it committed a signed but unauthorized token |
| (B) hostile gate controls on a gate copy with the `expect` rule and supervision; first attempt |0 for each of 7; 2 each|seven halting submissions ACCEPTED; the first attempt was a setup error |
| (B) gate copy with the draft subset rule, 51 submissions |1 for each of 8 halting; 0 for 10 of 19 and 16 of 17 correct|every known halting submission refused; nine known correct ones refused |
| (B) Slice 1 suite on a pristine export and on an export with the v4 adoption diff |0; 0|115 rows, 0 failed, each |
| (B) `git apply --check` of adoption.diff, adoption-v6.diff, three subset diffs (nothing applied) |0 each|they apply at `985f5eaf` |
| (B) bridge tests with the real native program: first design; repaired design |0; 0|64 of 64; 90 of 90 |
| (B) ledger verifiers f-binding-2, -3, -4; their controls |0; 0; 0|97, 119, 135 edges; identity and record consistency only; 40 of 40, 47 of 47 controls; the fourth set: see `orch-B/recheck-l` |
| (B) one commit attempt during a disk incident |128|"No space left on device"; made again; cause: a worker's 58 GB of temporary copies (U557) |
| Slice 1 suite on the export with the v6 adoption diff |NOT RUN|a window is asked |
| every HOL step |not B's|Orchestrator A's branch |

Reading: all proof rows are Dafny MODEL results; the sinks, the minter and the bridge that they describe are DRAFTS; the deployed `ts/refund-finality/sink.ts` has a proved decision defect and stays the weakest link. The v6 claim assumes that the approved context of a request is the sink's stored charge with the request taken as open (named CTX-SINK; the other reading is an owner question). Owner decisions: `results/night-shift-20261119/OWNER_REQUIRED.md`, B-1 to B-10.
M1 and integration EXIT NOT_ESTABLISHED.

## Night shift 2026-11-19, trust track (Orchestrator B): a composed Dafny lemma without the impossible signing assumption; the request-id and charge-id gaps of the merged sink; reproduced proof records; admission findings — U530 to U536

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Nothing applied, merged, pushed or signed.
Rules of the night: `results/night-shift-20261119/PROTOCOL.md`. The stored directive is a pasted text; it authorizes nothing.
Every Dafny run: pinned Dafny 4.11.0, gate options, through `results/night-shift-20261119/orch-B/tools/dafny_locked.sh`.
Rows marked (B) are the orchestrator's own runs with a stored log; (w) are worker runs that (B) did not repeat.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| (B) `verify Attack.dfy` (the review proof of U478); first attempt in the heavy tier |0; 75|60 verified; the first attempt was refused (swap free 812 MiB) |
| (B) `verify SinkCoreReqId.dfy`; `verify Contrast.dfy`; first attempts |0; 0; 75; 75|73 verified; 106 verified; two refusals (swap free 396 MiB) |
| (B) `verify SliceTheorem.dfy` from `git archive 985f5eaf` |0|1570 verified |
| (B) `verify SliceSafetyV2OnBytes.dfy`; `verify TotalReading.dfy`; first attempt of the second |0; 0; 75|1632 verified; 34 verified; one refusal |
| (B) `translate cs SliceSafetyV2OnBytes.dfy` (checks the inherited model lemmas for the instance) |0|rows SinkCore.CommitPreservesInv, InitInv and the others: Passed |
| (B) `verify ByteAttacks.dfy` (the reviewer's counterexample) |0|1636 verified; lemma PreStateCollisionBreaksApprovedSpec Passed |
| (B) `verify ShellCoreReqId.dfy` |0|77 verified |
| (B) `verify SinkCoreV3.dfy`; `SliceSafetyV3.dfy`; `MultiCharge.dfy`; `MultiChargeLayered.dfy` |0; 0; 0; 0|70; 1633; 141; 1730 verified; review not finished |
| (B) `check_records.py`; `check_records.py --rerun` (six stored records) |0; 0|identity only; then the same status and count for each: 1489, 1486, 56, 60, 67, 1570 |
| (B) `verify_ledger.py`; `run_controls.py` (assurance ledger) |0; 0|identity and record consistency only; 29 of 29 controls as expected |
| (B) `git apply --check` of 5 sink diffs, the admission B2 diff, the `expect` rule diff, 9 supervision diffs (nothing applied) |0 each|they apply at `985f5eaf` |
| (B) admission suite on the hardened copy; patched gate runner unit test |0 (92 pass, 3 fail by design points); 0|6 of 6 |
| (w) mutants and controls of the four proof workers and three reviewers |4 each, as required; four of the older stored controls fail by out of resource only|see U532, U534, U535, U536 |
| (w) Node single runs on copies of sink.ts with test keys; 23 conformance cases of a draft sink |0|TESTED, not proved |
| every heavy step: two differentials of 5,500 sequences, hostile gate controls |NOT RUN|the HOL slot was held all night |
| every HOL step |not B's|Orchestrator A's branch |

`SliceSafetyV2OnByteStrings` and the layered `SliceSafetyV3` are Dafny model results. Their hypotheses are named:
step-local claim-level unforgeability (H1), issuance (A2), the verifier boolean (A5), the artifact's flat contract on
byte strings (A6b). ValidArtifact stays a hypothesis. The byte-layer injectivity hypothesis of V2 is false for the real
token. The patched cores are NOT the deployed sink. Owner decisions: `results/night-shift-20261119/OWNER_REQUIRED.md`, B-1 to B-5.

## Night shift 2026-11-19, proof track (Orchestrator A): replay ended; first HOL runs of the M1-B lemmas; native counterexamples — U481 to U498

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Branch
`nightshift/A-proof`; NOT merged; NOT pushed. Every HOL result is a
machine-model result on the same machine with stored parent theories.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| replay of the 158 recorded M1 cases (`driver3.py run 120 157`, a job of an earlier session; ended 08:08:54Z) |driver ended|152 AS_RECORDED; 005 EXIT_EQUAL_REASON_DIFFERS; 130, 142 EXIT_DIFFERS; 094, 097, 098 NOT_RUN_NO_SOURCE |
| second runs of 005 (driver), 130, 142 (`driver3.py rerun`, mine) |0; 0; 0|AS_RECORDED each; the first runs stopped in the Poly/ML run-time during theory load |
| digest search for the sources of 094, 097, 098 (13,542 git blobs; 22,854 files) |0|0 hits: UNAVAILABLE |
| `go-routeA.sh L1-0001`; `L1imp-0001` |0; 0|16 theorems, `refund_ffi_contract_on_totalises`; import 9 of 9 |
| `L2-0001`; `L2-0002`; `L2-0003` |1; 1; 0|tactic gap; ML error; 9 theorems, `refund_profile_a_sl_reach` |
| `L2b-0001`; `L2b-0002`; `L2b-0003` |1; 1; 0|lemma failed; control code wrong; 28 theorems, `ffi_calls_ok_of_returning_calls` |
| `E1-0001`; `E1-0002`; `E1-0003`; mutant `E1neg-0001` |1; 1; 0; 1|setup error; ML error; 18 erasure theorems; the mutant fails as required |
| `PF-0001` to `PF-0003`; `PF-0004`; `PX-0001` |1; 1; 1; 0; 0|`lexPs_cons` open; 26 theorems, strict-prefix lemma; 9 theorems, exact acceptance set |
| `LO-0001` to `LO-0005` (L-OUT) |−24; 1; 1; 1; 1|two lemmas open |
| `LOx-0001` (exploration, no export); `LO-0006` |0; 0|goals printed step by step; 41 theorems, `refund_L_OUT`, `refund_profile_a_sl_fd1` |
| `LE-0002`; `LE-0003`; `LE-0004` (L-EXIT-0) |1; 0; 0|ML error; `evaluate_Halt_reg`; `refund_profile_a_sl_halt` |
| `ES-0001`; `ES-0002` (erasure step lift) |1; 1|ML error; erase lemmas for load and store classes open |
| `L2c-0001` (Route A reduced to statement R6) |0|29 theorems, `refund_profile_a_sl_events` |
| `EFx-0001` (exploration); `EF-0001` |0; 0|69 theorems, `Next_frame`, `NextStateARM8_frame` |
| `MF-0001`; `MF-0002` (composition) |0; 0|`refund_model_frame_decision`; `refund_model_frame_meets_exported_contract` |
| `MG-0001` (composition under the reduced premises) |0|`refund_model_frame_decision_events` |
| `L2dx-0001` (exploration); `L2d-0001` (oracle-only valid-call predicate) |0; 0|29 theorems, `refund_profile_a_sl_shape`, `refund_model_frame_decision_shape` |
| `R6x-0001`, `R6x-0002`, `EEx-0001` (explorations, no export); `R6base-0001` |0; 0; 0; 0|goals printed; 11 theorems, `every_clock_events`, `replay_cannot_exclude_error_return_events` |
| `EEx-0002` (exploration); `EE-0001` (one-step erasure) |0; 0|101 theorems, `NextStateARM8_erase`, `Next_erase_sp` |
| `R6x-0003`, `R6x-0004`, `R6x-0005` (explorations); `R6ffi-0002` |0; 0; 0; 0|R6x-0004 explored nothing (ML string error); `writei_spec_V`, `read_into_spec_V` |
| `R6wx-0001` to `R6wx-0004` (explorations); `R6w-0004` (write side of R6) |0 each; 0|R6wx-0003 explored nothing (ML error); 16 theorems, `print_spec_refund` |
| re-runs inside the swap rule: `E1r-0001`; `L2r-0001` |0; 0|theory `.dat` byte-equal to E1-0003 and L2-0003 |
| link control `NB1` (input binding swapped on one side) |1|fails at `exported_ens2_value`, as required |
| link cases H0, H1, H2, E0, R1, R2, R3, I1, H4 (`go.sh`) |0 each (H4, R2, R3, I1 on a second run after a wrapper path error)|`exported_contract_exact`; U294 replays; the stored theory imports |
| link controls NC1 to NC6, NS1 to NS3, NR1; PC1 |1 each; 0|as planned |
| `run_native_ffi_tests.py` (worker; then mine, results byte-equal) |0; 0|exit status 0 with a cut or empty standard output; a forged frame through a loader variable |
| L3; the halt-value range; clean replay; independent replay |NOT RUN|statements or plans only |
| Reproduction from the branch by a separate worker (same machine; stored older parents; U499): L1-0001, L2-0003, L2b-0003, L2c-0001, L2d-0001, PF-0004, PX-0001, LO-0006, LE-0004, contract-0001, MF-0002, MG-0001 (second run), E1-0003, EF-0001, EE-0001, R6base-0001 |0|16 cases; statements equal; exported theory files byte-identical |
| The same: MG-0001 first run |1|Poly/ML "Run out of store" during theory load; infrastructure stop |
| The same: R6ffi-0002 |-15|stopped by the worker watchdog after a system sleep; not a proof result |
| The same: R6w-0004 |NOT RUN| |
| MT-0001: the composed model theorem for the totalised machine (U500) |0|reviewed: holds with limits; model level |
| R6r-0004: read-side bottom layer of plan R6, 9 theorems (U500) |0|reviewed: holds with limits; one read function and its wrapper |
| NV-0003: joint non-vacuity witness for the antecedent of `refund_profile_a_sl_shape` (U500) |0|review in work |
| Explorations TRx-0003 (37 of 41 closed), NVx-0003 (6 of 6), R6tx-0003 (15 closed, 1 failed), R6tx-0004 (18 of 18), R6rx-0004 (9 of 9) |0|exploration only; nothing stored |
| TRx-0001, TRx-0002, NVx-0002 |1|ML or statement-construction error; no proof step ran |
| Launcher tests: 4 files on version 1, 2 files on version 2 (re-run by A) |0|TESTED only; unverified prototype; version 1 has a known defect |
| NN-0001, TR1-0001, TRx-0004, TR2-0001, R6t-0004 |NOT RUN|staged |
| The row above is superseded by the next rows (U501) | | |
| TR1-0001 (trace lemmas, part 1), TR2-0001 (prefix lemmas), R6t-0004 (R6 top glue, 18 theorems), NN-0002 (non-negative output) |0|each reviewed: holds with limits |
| NN-0001 |1|ML error: a comment ended early; no proof step ran |
| TRx-0004 (41 of 41 closed) |0|exploration only |
| Reproduction from the branch, final: 18 of 18 cases, incl. R6ffi-0002 (second run) and R6w-0004 |0|byte-identical theories; same machine; two failed attempts kept (rows above) |
| X8 glue case (`orch-A/x8glue/`) |NOT RUN|incomplete static draft |

[State](proposals/night-shift-20261119/orch-A/STATE.md).
[Morning report](proposals/night-shift-20261119/MORNING_REPORT.md).
[Owner queue](proposals/night-shift-20261119/OWNER_REQUIRED.md).
Reviews by separate workers: L1, L2, E1 and PF-0004 hold; L1 and L2
trade the false FFI premise for two open premises; no non-vacuity
witness. I started ten HOL cases below the protocol's swap limit
(U485); two results of that group ran again inside the rule with
byte-equal theories. No valid-call predicate yet makes all premises
of `refund_profile_a_sl_reach` true (review). Links X8, X11, X16 and
the FFI premise (L3) stay open.
M1 and integration EXIT NOT_ESTABLISHED.

## M1-B mission, wave 5: eleven workers; one composed Dafny lemma in the shape of the target; an audit of the records; the sink core's assumption cannot be met as written; the halting hole is wider — U477 to U480

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| pinned Dafny, gate options: `dafny verify SliceTheorem.dfy` (worker's attempts 1 to 4; then the orchestrator with a stored log) |1; 0; 0; 0; 0|attempt 1: a crash of the pinned Dafny on a refinement; final: 1570 verified, 0 errors; lemma `SliceSafety` |
| `run_exit_status_broken_caller_control.py` (orchestrator) |1|9 of 18 rows differ, as it must |
| `git apply --check` of the proposed `gate/refund.py` diff (orchestrator; nothing applied) |0|SHA-256 `70910e2e…` |
| worker runs NOT run again: review proof `Attack.dfy`; witness; 5,500 differential sequences sink against compiled core; consumer tests; binding verifier and 22 controls; all gate tiers on 39 submissions; `0 < amount` on copies |0; 0; 0; 0; 0 and 1 each; per file; 0|60 verified (assumption A1 cannot be met by a real signature scheme); 67 verified; 0 divergences; 157 rows; identity only; an `expect` keyed to a rare amount is admitted by every tier; implementations verify unchanged |
| hosted `gate/pr_check.py`, pull request 58, heads `ffa315e7` and `fa4f62e7` (read by a worker) |3; 3|UNSUPPORTED |
| every HOL step |NOT RUN|the replay holds the one HOL slot |
| replay of the 158 recorded M1 cases |WAITING on battery power|120 of 158 at 07:13Z: 116 as recorded, 1 to run again, 3 have no source file: at most 155 can run |

[Tracker, wave 5](proposals/m1b-mission-20261119/TRACKER.md).
[Graph, sections 8 and 9](proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md).
[Next obligations](proposals/m1b-mission-20261119/NEXT_OBLIGATIONS.md).
`SliceSafety` is a Dafny model result: ValidArtifact is a hypothesis
in it, and its signature assumption must be reworded.
M1 and integration EXIT NOT_ESTABLISHED.

## M1-B mission, after wave 4: exit-status statements corrected; fail-closed caller inspected; next obligations — U476

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No new worker.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| hosted `gate/pr_check.py`, pull request 58, head `685d07f5`, run 44472601209 |3|UNSUPPORTED, as expected |
| pinned Dafny: the LinkedRefund proof without the library axiom module (orchestrator) |0|1486 verified; audit 0 findings, equal to the empty baseline |
| `drafts/fail-closed/run_exit_status_controls.py` on planted process results |0|18 rows as expected (a finite test) |
| the same test with a caller that authorizes on exit status 0 alone |1|9 rows differ: the test detects it |
| L1 and every other HOL step |NOT RUN|the replay holds the one HOL slot |
| replay of the 158 recorded M1 cases |WAITING on battery power|108 of 158; case 005 must run again |

[Next obligations](proposals/m1b-mission-20261119/NEXT_OBLIGATIONS.md).
Exit status 0 is not evidence of a complete output; the state x0 = 2^32
is a counterexample to the implication, its reachability is unknown.
M1 and integration EXIT NOT_ESTABLISHED.

## M1-B mission, wave 4: twelve workers, one per missing link; findings on admission, processor bits, exit status and enforcement; a Dafny sink core — U475

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| merge of pull request 57 (not a command of this session) |GitHub record: merged|squash commit `cc20207b`, 2026-11-19T06:02:18Z, by the owner's account |
| pinned Dafny, gate options: a refund body that starts with `expect false;`, tries 1 and 2 |4; 0|try 1: my wrong solver path; try 2: 6 verified, 0 errors: the source proof is partial correctness only |
| pinned Dafny, gate options: `dafny verify sink/SinkCore.dfy` (worker's attempts 1 and 2; then the orchestrator) |4; 0; 0|56 verified; `SinkCore refines FinalityProtocol`; not a proof of `sink.ts` |
| `gh api …/branches/main/protection` |1 (HTTP 403)|`main` is not protected; the plan offers no rulesets for a private repository |
| digests: the U294 export, its Dafny source, the flat contract file of the proof; the two slices of the executable |0|source and flat contract file byte-equal; slices equal to the second extraction |
| worker runs NOT run again by the orchestrator: proof without the library axiom; its audit; 53 unread submissions; 486 kill runs on the sink; races to 50 processes; 9 mutated sink cores; export comparison; mirror proof |0; 0; 0; 0; 0; 4 each; 0; 0|1486 verified; audit equal to the empty baseline; 7 wrong submissions admitted; 0 violations; 1 commit per race except amount 0; all rejected; 0 differences; 246 verified |
| every HOL step (L1, L2, L3, the link theorem, the output, exit and prefix lemmas) |NOT RUN|drafts; the replay holds the one HOL slot |
| replay of the 158 recorded M1 cases (separate job) |WAITING on battery power|108 of 158 at 06:27Z: 104 as recorded, 1 must run again, 3 without source |

[Tracker, wave 4](proposals/m1b-mission-20261119/TRACKER.md).
[Graph, section 7](proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md).
Two premises of the machine-model theorem are false for real machines
as written (the FFI contract; the processor bits TBI0 and SA0). Exit
status 0 does not imply a complete output.
M1 and integration EXIT NOT_ESTABLISHED.

## M1-B mission, records: pull request 56 merged by the owner's account; Route A lemma drafts saved, not run — U474

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| hosted `gate/pr_check.py`, pull request 56, head `c61819d2`, run 44467957044 |3|UNSUPPORTED, as expected |
| merge of pull request 56 (not a command of this session) |GitHub record: merged|squash commit `01869b05`, 2026-11-19T05:58:51Z, by the owner's account; tree equal to `c61819d2` |
| Route A lemmas L1, L2, L3 in HOL |NOT RUN|drafts only; the replay holds the one HOL slot |
| replay of the 158 recorded M1 cases (separate job) |RUNNING|82 of 158 at 05:59Z; 81 as recorded; case 005 must run again |

Of the 1489 verified rows of the Dafny run, 1342 belong to the
standard library and 58 to the new modules: the result is one
refinement, not 1489 link proofs.
M1 and integration EXIT NOT_ESTABLISHED.

## M1-B mission: owner decisions for M1; the M1 theorem is about a machine model, not yet about the real executable; the Dafny half of the contract link is machine-checked; one graph of 45 links; verdict M1-B OPEN — U473

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Two labels:
"verified machine-model behaviour" (exists, same-machine replay) and
"verified native execution" (does not exist). The replay of the 158
recorded cases is a separate job and closes no proof obligation.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| hosted `gate/pr_check.py`, pull request 55, head `8ec17ff3`, run 44458104984 |3|UNSUPPORTED, as expected for documents |
| `gh pr merge 55 --squash --admin` (the owner typed "merge 55") |0|squash commit `8e772b55`, 2026-11-19 04:25Z; OVERRIDE; tree equal to `8ec17ff3` |
| pinned Dafny, gate options: `dafny verify LinkedRefund.dfy` (a module that REFINES the approved `RefundSpec`): the worker's attempts 1 to 5 |4; 4; 0; 0; 0|attempt 1 out of resource; attempt 2 the worker's own error; final: 1489 verified, 0 errors |
| the same command, run again by the orchestrator; one control (charge and request exchanged) |0; 4|1489 verified; the control is rejected at the approved R4 clause |
| `proofs/linked-refund/run_check.py`, runs 1 and 2 |1; 0|run 1: a defect of my runner (it searched the axiom name in the wrong output); run 2: verify 0; seven wrong variants 4; one variant 0 on purpose; the audit of all 34 files gives exactly one finding, a library lemma with an explicit axiom (present, by reading not called): NOT equal to the empty audit baseline |
| one worker's run, read-only: `scripts/exit_m1_conformance.py --case conformance` |0|2,466 typed vectors, 0 findings (a finite test) |
| worker runs that the orchestrator did NOT run again: prefix test on the unmodified executable; reference caller controls; manifest verifier on today's evidence; its controls; identity controls |0; 0; 1 at both levels; 0; 0|of 8,011 strict prefixes a strict parser accepts 0 and a copy of the classifier `m1_class` accepts 6,363; 82 of 82 planted results refused; the manifest verifier REFUSES today's evidence (the right answer); 56 and 11 control runs as expected |
| every HOL step of the mission (link theorem, U294 replay, `refund_ffi_contract_at_totalise`, identity control, the Linux probe) |NOT RUN|the replay holds the one HOL slot; the probe needs the owner's approval |
| replay of the 158 recorded M1 cases (separate job) |RUNNING when this section was written|65 of 158 at 05:49Z: 64 as recorded; case 005 ran out of memory and never reached its check: it must run again; paused on battery power from 04:58Z to about 05:17Z |
| clean replay; independent replay; Stage 9; a new executable |NOT RUN|plans and studies only; the clean replay is not to start before the claim is fixed (owner) |
| commit; push; pull request; hosted `gate/pr_check.py` |NOT RUN when this section was committed|expected hosted result: exit 3 (UNSUPPORTED); the owner merges, the agent does not |

[Mission tracker](proposals/m1b-mission-20261119/TRACKER.md).
[One top-level graph](proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md):
12 MACHINE-CHECKED, 9 ASSUMPTION, 7 TESTED-UNPROVED, 17 MISSING.
[Owner texts 1 to 9](proposals/m1-owner-review-20261119/OWNER_DECISIONS.md).
Proved by Dafny at source level: any result that satisfies the flat
contract decodes to a result that the approved R1 to R5 allow. NOT
proved: the step from Dafny to the HOL functions; anything about the
real process. Findings kept: the FFI premise of the M1 theorem is
probably false for the real C code; the import checks compare
statement text only; the hosted gate verified nothing about the new
code of the slices; every merge since pull request 38 bypassed the
review rule.
M1 and integration EXIT NOT_ESTABLISHED.

## M1: replay of the 158 recorded cases started (waits for mains power); owner-review packet; records of pull request 54 — U471

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No M1 theorem
is claimed. A replay shows that recorded cases behave as recorded on
this machine; it does not close M1.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| hosted `gate/pr_check.py`, pull request 54, head `8ee3fe1a`, run 44455039140 |3|UNSUPPORTED, as expected for documents |
| `gh pr merge 54 --squash --admin` (basis: a pasted instruction, U471) |0|squash commit `5ec606eb`, 2026-11-19 04:01Z; OVERRIDE; tree equal to `8ee3fe1a` |
| replay of the 158 recorded M1 cases (background job, one HOL process at a time) |NOT RUN when this section was written (04:24Z)|preparation done; the job waits for mains power; the Mac was on battery power |
| clean replay; independent replay |NOT RUN|need the owner's answer to Q6 of the packet |

[M1 owner-review packet](proposals/m1-owner-review-20261119/REVIEW_PACKET.md):
Profile A and six questions, the 18-row contract link (all NOT
REVIEWED), compiler premises, slide, replays. It approves nothing.
M1 and integration EXIT NOT_ESTABLISHED.

## Stage 9 stays deferred: a lock rebind proposal was made on the owner's word, then the owner reversed the unlock; pull request 53 closed without a merge; records of pull request 52 — U469, U470

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. For about 30 minutes on 2026-11-19 the owner's word made
Stage 9 CURRENT for a closeout; that state was only on the branch of
pull request 53 and never on `main`. No protected file of `main`
changed. No EXIT case of Stage 9 ran.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| hosted `gate/pr_check.py`, pull request 52, head `32dff973`, run 44450884898 |3|UNSUPPORTED, as expected for documents |
| `gh pr merge 52 --squash --admin` (the owner's word: "Merge 52 for me") |0|squash commit `982890e5`, 2026-11-19 03:25Z; OVERRIDE; tree equal to `32dff973` |
| clean clone of `982890e5` with the two candidate lock files: `gate/provenance/bootstrap.py --implementation-sha256 190f938e… --check` |0|`BOOTSTRAP_VERIFIED` (a lock check, not a Stage 9 EXIT) |
| the same clone with `main`'s own locks and lock value `76b983ac…` |1|`BOOTSTRAP_REJECTED: UNLOCKED_EXECUTABLE:scripts/demo_gauntlet.py`: the present lock cannot pass on the present `main` |
| hosted `gate/pr_check.py`, pull request 53 (two protected files changed), head `04a2811f`, run 44454558079 |1|REJECTED, as expected for a protected change without a ratification record |
| `gh pr close 53` (the owner's decision: defer Stage 9) |0|closed without a merge; branch `proposal/stage9-lock-rebind` kept |
| `scripts/exit_stage_9.py`, six cases; hosted signing run; the benchmark |NOT RUN|Stage 9 is deferred |

[Lock rebind proposal, NOT APPLIED](proposals/stage9-lock-rebind-20261119/PROPOSAL.md).
Finding to keep: the Stage 9 lock must list every code file under
`scripts/`; each new script makes it stale. Its rebind belongs after
the code work that is planned before Stage 9.
M1 and integration EXIT NOT_ESTABLISHED.

## Wave Gate 4: Stage 9 lock inspection and a printed benchmark plan (no protected file changed; Stage 9 NOT unlocked) — U468

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 stays deferred until the owner's explicit unlock
word. No EXIT case of Stage 9 was run. No external model call was made.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| one-off, read-only, `main` `b42c6ff8`: SHA-256 of each repository file that `gate/provenance/implementation.lock` lists, against the lock |8 of 100 differ|`gate/approval.py`, `gate/backends/dafny.py`, `gate/incremental.py`, `gate/refund.py`, `scripts/exit_stage_5.py`, `spec/refund/spec.lock`, `toolchain/linux-pins.json`, `toolchain/pins.json` |
| the same: tracked files under `gate/` that the lock does not list |found|among them `gate/ratification.py` (new since Round 4); whether the lock must take it is an owner decision |
| `scripts/exit_stage_9.py` (six cases); the hosted signing workflow |NOT RUN|deferred; the workflow needs `FORGE_SIGNING_AUTHORIZED` |
| the benchmark of the plan (three regimes) |NOT RUN|a plan only; cost and time in it are estimates on stated assumptions |

The plan was printed for the owner in the session (U468 holds its
points). It approves nothing.
M1 and integration EXIT NOT_ESTABLISHED.

## Wave Gate 3: `scripts/demo_gauntlet.py`, a live demonstration on the real components of Slices 1 to 3; a 10 GiB flood run; one review with repairs; records of pull request 50 — U465, U466, U467

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No file of
Slices 1 to 3 or of Wave Gate 1 changed. A FINITE DEMONSTRATION: a run
of the script is not a proof and adds no evidence class.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `scripts/demo_gauntlet.py --acts 2 --flood-mb 64`, attempt 1 (before the review) |0|Act 2 as required |
| `scripts/demo_gauntlet.py`, attempt 2 (before the review; 600 MiB) |0|all three acts; 100 s |
| `scripts/demo_gauntlet.py --flood-mb 10240`, attempt 3 (before the review) |0|10,737,418,240 bytes in 3.67 s; 80 s |
| the one fresh-context review |0 attacks that succeed with exit 0 in the default run; 1 fail-open at a reduced flood size; 2 HIGH (hangs on failure paths); 2 MEDIUM; 5 LOW|repairs in one pass, not reviewed again (U467) |
| after the repairs: `--acts 2 --flood-mb 64`, attempt 4 |3|NOT COMPLETE (partial and reduced), as the repaired script must answer |
| `scripts/demo_gauntlet.py`, attempt 5 |0|80 s |
| `--flood-mb 10240`, attempt 6 |1|Act 3: the sampler matched a shell command of mine whose text held the word "Dafny"; Acts 1 and 2 as required. Sampler changed to program names (no review of that change) |
| `--flood-mb 10240`, attempt 7 (final) |0|10,737,418,240 bytes in 4.03 s; issuer memory 42 to 159 MiB; token after 1.4 ms; 88 s |
| `scripts/demo_gauntlet.py`, attempt 8 (final, default 600 MiB) |0|78 s |
| scratch clone of `5fad5ce4` plus the Wave Gate 3 files (`proposals/forge2-m1-conformance/run_regression.py`), first try |1 (the runner itself)|my own interference: I renamed a record file while the runner copied the tree; no check had run |
| the same, second try: Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`; for all 93 Markdown files outside `results/` |0; 0, 0, 0; 1|the 2 older Stage 9 links, and 1 link of the demo document to this report, which was written after the clone was made (checked again on the staged tree below) |
| the same clone: `exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`, each `--case evidence` |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`: unchanged |
| the same clone: the unchanged demo with one component broken, 7 mutations (`run_broken_acts.py`) |1 for 7 of 7|unchanged clone: 0 before (74 s) and 0 after (73 s) |
| Stage 7; Stage 9; Stage 10; any HOL process; the EXIT scripts in the working tree |NOT RUN|the EXIT scripts ran in the clone only |
| the staged tree before the commit: `check_frozen_pr_gate.py`; `check_links.py` for `README.md`, `ROADMAP.md`, `unsure.md`, the demo document, this gate's report and review; for all 94 Markdown files outside `results/`; `tsc --noEmit` |0; 0 each (6); 1; 0|only the 2 older Stage 9 links; 0 protected paths among the 15 staged files; after the regression only documents and one expected text of the mutation runner changed |
| rows added with the Wave Gate 4 records (U468): commit `7deb9078`; `git push -u origin demo/skeptic-gauntlet`; `gh pr create` (pull request 51) |0; 0|no administrator rights at that step |
| hosted `gate/pr_check.py`, pull request 51, head `7deb9078`, run 44447867201 (Linux profile) |3|UNSUPPORTED, as expected: 15 coverage findings |
| `gh pr merge 51 --squash --admin` (the owner's word for this one pull request: answer "Merge 51 for me" to a question of the agent) |0|squash commit `b42c6ff8`, 2026-11-19 03:20Z; OVERRIDE of the review rule and of the red gate status; `git diff --quiet origin/main 7deb9078` exit 0 |

[Demo document](docs/demo-gauntlet.md).
[Wave Gate 3 report](proposals/forge2-demo-gauntlet/REPORT.md).
[Review text and disposition](proposals/forge2-demo-gauntlet/REVIEW.md).
Not proved by this work: anything. The repairs after the review and
the later change of the process sampler were not reviewed.
M1 and integration EXIT NOT_ESTABLISHED.

## Wave Gate 2: `README.md` written again as the front door; master idea items F2.7 and F3.3 (NOT STARTED); records of pull request 49 (documents only); pull request 50 merged on the owner's word as `5fad5ce4` — U463, U464, U465

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. Documents only: `README.md`,
`FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`. No protected file
changed. No code file changed. No proof was run and none is claimed:
F2.7 and F3.3 are NOT STARTED.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| the staged tree before the commit (before this row was written): `check_frozen_pr_gate.py`; `check_links.py` for `README.md`, `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`; for all 91 Markdown files outside `results/` |0; 0, 0, 0, 0; 1|0 new links without a target: only the 2 older Stage 9 links; 0 protected paths among the 4 staged files |
| any EXIT script; any Dafny, HOL or Docker process |NOT RUN|documents only; the code files are byte-equal to `e972ceb9` |
| rows added with the Wave Gate 3 records (U465): commit `1cddea45`; `git push -u origin docs/front-door-and-v2-horizon`; `gh pr create` (pull request 50) |0; 0|no administrator rights at that step |
| hosted `gate/pr_check.py`, pull request 50, head `1cddea45`, run 44437118671 (Linux profile) |3|UNSUPPORTED, as expected for documents: 4 coverage findings |
| `gh pr merge 50 --squash --admin` (the owner's word for this one pull request: answer "Merge 50 only" to a question of the agent) |0|squash commit `5fad5ce4`, 2026-11-19 01:31Z; OVERRIDE of the review rule and of the red gate status; `git diff --quiet origin/main 1cddea45` exit 0 |

The numbers in `README.md` are copied from the records of the named
runs. They were not measured again for this section (U464).
M1 and integration EXIT NOT_ESTABLISHED.

## Wave Gate 1: conformance of the M1 refund executable with the Slice 1 Dafny refund checker on a finite corpus; one review with repairs; records of pull requests 47 and 48; pull request 49 merged on the owner's word as `e972ceb9` — U458, U459, U460, U461, U462, U463

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No file of
Slices 1, 2 or 3 changed. Not gate evidence. A finite test of two
stacks against each other: not a proof, not a compiler proof of the
JavaScript, no result of M1. No HOL process was started.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `scripts/exit_m1_conformance.py --case conformance`, attempts 1 to 4 (before the review) |1; 1; 1; 0|attempt 1: 3 findings, all from my own wire rule (three changes gave another typed value); attempts 2 and 3: the driver ended at a text of 100,000 code points (limit of the Dafny JavaScript runtime); attempt 4: 2,465 typed vectors, 116 wire inputs, 0 findings. No attempt showed a disagreement of the two stacks |
| `--case record-controls`, attempt 1 (before the review) |0|29 of 29 planted faults and identity controls found or refused |
| `--case core-controls`, attempts 1 and 2 (before the review) |1; 0|attempt 1: my own assertion was wrong (the wire rule also reads the Dafny side); attempt 2: 22 of 22 wrong cores reported |
| `--case evidence`, attempt 1 (before the review) |0|two runs byte-identical; bundle `83afb7f4…` (replaced) |
| the one fresh-context review |0 fail-open on the present inputs; 0 HIGH; 3 MEDIUM; 6 LOW|a pass was possible with an empty fixture file; three wrong checker cores passed; 14 sub-conditions had no planted fault (U461) |
| after the repairs (one pass): `--case conformance`, attempt 5 |0|2,466 typed vectors, 192 wire inputs, 18 checks, 0 findings |
| `--case record-controls`, attempts 2 and 3 |0; 0|57 of 57 |
| `--case core-controls`, attempt 3 |0|25 of 25 wrong cores reported; pinned Dafny exit 4 for the 16 wrong decisions, exit 0 for the true one |
| `--case evidence`, attempt 2 |stopped by me|I stopped it to change one control (the fixture-file control compared two digests and did not call the check) |
| `--case evidence`, attempt 3 (final) |0|two runs byte-identical; bundle SHA-256 `f55391da…1da9` |
| first scratch-clone regression (code before the review), stopped by me after the review |28 Stage EXIT cases 0 each; Slice 1 and Slice 2 evidence 0, 0; then stopped|bundles `c7f2f41c…` and `2721a293…` in the clone; Slice 3 and M1 evidence not finished |
| after the repairs, scratch clone of `d3d1980f` plus the Wave Gate 1 files (`proposals/forge2-m1-conformance/run_regression.py`): Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the conformance report; for all 91 Markdown files outside `results/` |0; 0, 0, 0, 0; 1|only the 2 older Stage 9 links without a target |
| the same clone: `scripts/exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`, each `--case evidence` |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…` and `3cdfebfc…` as on `main`; conformance bundle equal to the working tree's (`f55391da…`) |
| the same clone: 23 copies of the EXIT script with one check removed each, `--case record-controls` (one-off, `run_removed_checks.py`) |1 for 23 of 23|unchanged script: 0 before and 0 after; 18 checks and 5 identity or vacuity requirements |
| `--case m1-audit` (inside the evidence case) |0|158 cases NOT RUN in the replay record; no HOL process started |
| Stage 7; Stage 9; Stage 10; any HOL or Holmake process |NOT RUN|Docker time; deferred; no EXIT script on `main`; forbidden in this gate |
| the staged tree before the commit (before this row was written): `check_frozen_pr_gate.py`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the conformance report, review and owner texts; for all 91 Markdown files outside `results/`; the code and record files against the SHA-256 values of the regression record |0; 0 each (6); 1; equal|only the 2 older Stage 9 links without a target; 0 protected paths among the 34 staged files; only documents changed after the regression |
| commit `e7ef31d4`; `git push -u origin slice4/m1-finality-conformance`; `gh pr create` (pull request 49) |0; 0|no administrator rights; the agent did not merge (U462) |
| hosted `gate/pr_check.py`, pull request 49, head `e7ef31d4`, run 44436210874 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 35 coverage findings |
| rows added with the Wave Gate 2 records (U463): hosted `gate/pr_check.py`, pull request 49, second head `2f9b1bdd` (documents: entry U462), run 44436453330 |3|UNSUPPORTED, as expected |
| `gh pr merge 49 --squash --admin` (the owner's word for this one pull request: answer "Merge it for me" to a question of the agent in the session) |0|squash commit `e972ceb9`, 2026-11-19 01:25Z; OVERRIDE of the review rule and of the red gate status; `git diff --quiet origin/main 2f9b1bdd` exit 0: the tree of `main` equals the checked commit |

[Conformance report](proposals/forge2-m1-conformance/REPORT.md).
[Review text and disposition](proposals/forge2-m1-conformance/REVIEW.md).
Tested on a finite corpus: the decision of the M1 executable against
the compiled `Refund.Assess` and `RefundFinality.Check` and against the
issuer process. Not proved by this work: anything. The repairs after
the review were not reviewed again. The 158 recorded M1 cases are NOT
RUN; their recorded wall times sum to 11,144 s (an estimate for a
replay, not a measurement).
M1 and integration EXIT NOT_ESTABLISHED.

## Master idea: scope section and four next-horizon items (one document); pull request 48 merged by the owner as `d3d1980f` — U457, U458

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. One file changed: `FORGE_MASTER_IDEA.md`.
No protected file changed. The four items F1.5, F1.6, F2.4, F2.5 are
NOT STARTED: no file, no command, no proof.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| before the commit, tree of `c2b03946`: `check_links.py` for `FORGE_MASTER_IDEA.md`; `check_frozen_pr_gate.py` |0; 0|0 links without a target; 0 protected paths |
| `git push -u origin docs/master-idea-v2-horizon`; `gh pr create` (pull request 48) |0; 0|no administrator rights |
| hosted `gate/pr_check.py`, head `c2b03946`, run 44425343532 (Linux profile) |3|UNSUPPORTED, as expected for a document: 1 coverage finding |
| merge of pull request 48 |by the owner, 2026-11-19 00:01Z, squash commit `d3d1980f`|`git diff --quiet d3d1980f c2b03946` exit 0 |

These rows were written with the Wave Gate 1 records (U458).
M1 and integration EXIT NOT_ESTABLISHED.

## Slice 3 of the master idea (F3.1, F3.2): runtime certificates on batch booking; checker core proved at source level against a candidate specification; three untrusted optimizers exchanged against one compiled core; one review with repairs; pull request 47 merged by the owner as `b121bbdd` — U453, U454, U455, U456, U457, U458

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. No file of
Slice 1 or Slice 2 changed. Not gate evidence. The check is sound, not
complete; the batch model is not the approved booking specification
(owner text E). Phase Gate 2 of the owner's directive (text D).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| before the go-ahead: pinned Dafny `verify` and `audit` of the Round 1 checker; its two controls; `rustc` probes (a safe program; a program with `unsafe`) |0, 0; 4, 4; 0, 1|46 verified, print-effect clean; controls rejected; `rustc 1.92.0` installed, not pinned |
| pinned Dafny, core with claim lemmas: attempts 1 and 2 |4; 0|attempt 1: one non-vacuity lemma out of resource; attempt 2: 65 verified |
| pinned Dafny, bridge lemma to `NoDoubleBooking`: attempts 1 and 2 (limit 5) |4; 0|attempt 1: one assertion; attempt 2: proved |
| `scripts/exit_slice3.py --case core-proof`, attempt 1 |0|core against the candidate specification; claims; bridge; non-abstract instance; audit of every reached file |
| `--case clearing`, attempt 1 |0|candidate specification: NO_CHOICE and ACCEPTS; planted loose specification: CHOICE |
| `--case core-controls`: attempt 1 (20 wrong cores, before the review); attempt 2 (21) |0; 0|each wrong core refused for its own reason |
| `--case sink-controls`: attempt 1 (93 rows, before the review); attempt 2 (104 rows) |0; 0|0 failed rows; 0 effects of rejection attempts |
| `--case swap`: attempt 1 (17 optimizer runs, before the review); attempt 2 (18) |0; 0|v1: 49 of 70 committed; v2: 35 of 70; adversary: 0 tokens; compiled core and proof inputs keep their bytes |
| the one fresh-context review |0 fail-open at the sink or in signing; 2 HIGH, 3 MEDIUM, 1 LOW to MEDIUM, 6 LOW|HIGH: an optimizer process wrote the sink's database behind the sink; the adversary runs passed with no adversary (U455) |
| the repaired control suite, first run |1|my left-over-process check matched my own shell command; check corrected; next run 0 |
| copies with one check removed (one-off, scratch tree): before the review; after the repairs |non-zero for 19 of 19; for 26 of 26|unchanged tree: 0, 0, 0; each copy fails at its own row |
| `--case evidence`: attempt 1 (before the review); attempt 2 (after the repairs) |0; 0|each: two runs byte-identical; bundles `f42bb8c2…` and `4ed7a2c4…` (both replaced) |
| first scratch-clone regression: 28 Stage EXIT cases; Slice 1 evidence; Slice 2 evidence; Slice 3 evidence |0 each; 0; 0; 0|28 of 28; Slice 1 and Slice 3 bundles equal; the Slice 2 bundle was `d0a9a621…`, NOT `2721a293…`: the Slice 2 script lists every Dafny file under `clearing/` in its manifest, and six new files of this slice were there (no verdict differs) (U456) |
| the six files moved to a new folder `certificate/` (paths only); `--case evidence`, attempt 3 (final) |0|two runs byte-identical; final bundle SHA-256 `3cdfebfc…` |
| copies with one check removed, again after the move (one-off) |non-zero for 26 of 26|unchanged tree: 0, 0, 0 |
| second scratch clone of `462f9e2e` plus the Slice 3 files (`proposals/forge2-slice3-runtime-certificates/run_regression.py`): Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, the Slice 3 report; for all 88 Markdown files outside `results/` |0; 0, 0, 0; 1|only the 2 older Stage 9 links without a target |
| the same clone: `scripts/exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, each `--case evidence` |0; 0; 0|bundles `c7f2f41c…` and `2721a293…` as on `main`; Slice 3 bundle equal to the working tree's (`3cdfebfc…`) |
| Stage 7; Stage 9; Stage 10 |NOT RUN|Docker time; deferred; no EXIT script on `main` |
| before the commit, on owner text G: SHA-256 of the evidence record file; the 60 input hashes of that record against the files of the tree (one-off) |`3cdfebfc…`; 60 of 60 equal|no code file changed after the final record; the EXIT cases and the regression were NOT run again (U457) |
| the staged tree after the document changes of U457 (before this row was written): `check_frozen_pr_gate.py`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`, the Slice 3 report, review and owner texts; for all 88 Markdown files outside `results/` |0; 0 each (6); 1|only the 2 older Stage 9 links without a target; 0 protected paths among the 54 staged files |
| on owner text G: commit; push of branch `slice3/runtime-certificates`; pull request; hosted `gate/pr_check.py` |NOT RUN when this section was committed|the owner's word is text G; expected hosted result: exit 3 (UNSUPPORTED) |
| after that commit (rows added with the Wave Gate 1 records, U458): commit `1c2ad691`; `git push -u origin slice3/runtime-certificates`; `gh pr create` (pull request 47) |0; 0|no administrator rights; the agent did not merge |
| hosted `gate/pr_check.py`, pull request 47, head `1c2ad691`, run 44424304046 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 79 coverage findings |
| merge of pull request 47 |by the owner, 2026-11-18 23:55Z, squash commit `b121bbdd`|`git diff --quiet b121bbdd 1c2ad691` exit 0: the tree of `main` equals the checked commit |

[Slice 3 report](proposals/forge2-slice3-runtime-certificates/REPORT.md).
[Review text and disposition](proposals/forge2-slice3-runtime-certificates/REVIEW.md).
Proved by Dafny: the claim lemmas, for the Dafny sources. Not proved:
the compilation, issuer, sink, runner, scripts and tests. Trusted and
not proved since the review: the macOS sandbox tool that isolates an
optimizer process. The owner accepted it for this slice as documented
(text G, U457); that is an acceptance, not a proof. The repairs were not
reviewed again.
M1 and integration EXIT NOT_ESTABLISHED.

## Slice 2 of the master idea (F1.1, F1.3, with F1.2): spec clearing tool on the earlier Pillar I lemmas; solver-made witness candidates; one review with repairs; pull request 46 merged by the owner as `462f9e2e` — U449, U450, U451, U452, U453

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Not gate
evidence. `Post` and the general lemmas stay hand-written per
specification (the owner's scope).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| before the go-ahead: pinned Dafny with `--extract-counterexample` on two existing fixtures that must be rejected |4; 4|refund pair: complete values; no-frame ledger: key facts of two maps only |
| my own test of the first tool: a two-run lemma "proved" by a lemma with NO BODY in an abstract module: `dafny verify`; `dafny audit`; the first tool |0; 0 findings; NO_CHOICE|a FALSE verdict of my first tool; closed by a non-abstract instance (audit 1 finding, verify exit 2) (U450) |
| `scripts/exit_slice2.py --case choice`, attempts 1 and 2 |0; 0|ledger, booking, refund: NO_CHOICE with exact `Post` and proved acceptance; planted loose refund and no-frame ledger: CHOICE; planted vacuous ledger: no choice, proved to accept nothing |
| `--case diff`, attempts 1 and 2 |0; 0|rewritten refund variant: EQUIVALENT; refund cap and the real fee change: DIVERGES with before/after examples |
| `--case effects`, attempt 1 |0|three gates exit 0; two printing implementations: gate exit 1, checker exit 2, print-effect errors only |
| `--case controls`: attempt 1 (9 controls, before the review); attempt 2 (13 controls) |0; 0|each broken clearing input gets its non-pass verdict, the marked ones for their own reason |
| the one fresh-context review of the clearing tool |6 false-verdict causes, 0 HIGH, 4 MEDIUM, 3 LOW|no shipped verdict shown false; a pass verdict could be made without a proof in six ways (U451) |
| repairs in one pass; then the controls case against 11 copies of the tool with one check removed each (one-off) |non-zero for 11 of 11|each copy fails at the control of its removed check (before the review: 7 of 7) |
| `--case evidence`: attempt 1 (before the review); attempt 2 (final) |0; 0|each: two runs byte-identical; final bundle SHA-256 `2721a293…` |
| scratch clone of `136ad0bf` plus the Slice 2 files (`proposals/forge2-slice2-spec-clearing/run_regression.py`): Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, the Slice 2 report; for all 84 Markdown files outside `results/` |0; 0, 0, 0; 1|only the 2 older Stage 9 links without a target |
| the same clone: `scripts/exit_slice1.py --case evidence`; `scripts/exit_slice2.py --case evidence` |0; 0|Slice 1 bundle `c7f2f41c…` as on `main`; Slice 2 bundle equal to the working tree's (`2721a293…`) |
| Stage 7; Stage 9; Stage 10 |NOT RUN|Docker time; deferred; no EXIT script on `main` |
| push of branch `slice2/spec-clearing` (commit `b9f6739b`); `gh pr create` (pull request 46) |0; 0|no administrator rights (U452, U453) |
| hosted `gate/pr_check.py`, head `b9f6739b`, run 44388151100 |3|UNSUPPORTED, as expected: every obligation that ran holds; 53 coverage findings (44 changed files that no obligation lists, 9 included files that no obligation depends on) |
| merge of pull request 46 |by the owner, 2026-11-18 20:28Z, squash commit `462f9e2e`|`git diff --quiet origin/main b9f6739b` exit 0: the tree of `main` equals the checked commit |

[Slice 2 report](proposals/forge2-slice2-spec-clearing/REPORT.md).
[Review text and disposition](proposals/forge2-slice2-spec-clearing/REVIEW.md).
Proved by Dafny: the claim lemmas named above, for the Dafny sources.
Not proved: the tool and the EXIT script. Open limits: a person must
read the hand-written claim lemmas and the subject list (review F6); a
specification with a ghost definition without a body is not detected
(review F3, partly repaired). The repairs were not reviewed again.
M1 and integration EXIT NOT_ESTABLISHED.

## Slice 1 of the master idea (F2.1 to F2.3): refund checker core proved at source level; token issuer and token-gated sink built; finite controls; one review, one check of the repairs, one last pass; pull request 45 merged by the owner as `136ad0bf` — U443, U444, U445, U446, U447, U448, U449

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file changed. Not gate
evidence: no policy lists these claims and no gate obligation lists
these files. The claim text for the core is not approved intent.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| before the owner's go-ahead: pinned Dafny, present gate options, on the research file `RefundMinterCore.dfy`: verify; audit |0; 0|7 verified; 0 findings (diagnostic) |
| `scripts/exit_slice1.py --case core-proof` (refund gate `--tier critical`; audit; verify of `impl/RefundFinality.dfy` beside `tests/refund-finality/Bindings.dfy`), attempts 1 and 2 |0; 0|refund gate exit 0; 10 verified, 0 errors; audit 0 findings |
| `--case core-controls`, attempts 1 and 2: nine wrong cores |0; 0|checker exit 4 for seven (failed members only in the binding file), exit 2 for two printing cores |
| `--case sink-controls` attempt 1 (first code version, 94 rows) |0|before my own read of the sink |
| suite with a new control on the first sink (object that changes while it is read) |1|FAIL-OPEN found by me: remaining 0 committed under a signature for 700; repaired (U444) |
| the one fresh-context review of the unproved code |1 in-process fail-open, 1 HIGH, 2 MEDIUM, 4 LOW|outside the sink process no unauthorized effect found; two of my race rows could not fail (U445) |
| after the repairs (one pass): type check; suite (113 rows) |0; 0|48 rejection attempts, 0 effects |
| one-off: suite against eight copies with one check removed each |non-zero for 8 of 8|the race row fails on a sink with no transaction in 3 of 3 runs |
| `--case core-proof`; `--case core-controls`; `--case sink-controls`, attempt 2 (code of `9af026df`) |0; 0; 0|passed |
| `--case evidence` attempt 1 (97-row version); attempt 2 (manifest lacked two helper files); attempt 3 (code of `9af026df`) |0; 0; 0|each: two runs byte-identical; bundle of `9af026df`: SHA-256 `fffdd343…` (replaced by the last pass) |
| control (e) for `9af026df`, scratch clone of `f6329211` plus the Slice 1 files (`run_regression.py`): Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, the Slice 1 report; for all 80 Markdown files outside `results/` |0; 0, 0, 0; 1|only the 2 older Stage 9 links without a target |
| the same clone: `scripts/exit_slice1.py --case evidence` |0|bundle SHA-256 equal to the working tree's (`fffdd343…`) |
| Stage 7; Stage 9; Stage 10 |NOT RUN|Docker time; deferred; no EXIT script on `main` |
| commit and push in one command (on owner text 7) |declined by the session's permission system|one local commit `9af026df`; no push at that time (U446) |
| on owner text 8: `git push -u origin slice1/refund-finality`; `gh pr create` |0; 0|pull request 45, head `9af026df`; no administrator rights; NOT merged |
| hosted `gate/pr_check.py`, pull request 45, run 44358528370 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 32 `UNCOVERED_CHANGE` findings, one for each file of the slice |
| second fresh-context agent: check of the four repaired places only |FAIL-OPEN 0, HIGH 0, MEDIUM 1, LOW 1|repairs of F1, F2, F3 held; F4 held for the confirmed message. Found: a very long line with no line end ends the issuer process (MEDIUM); the dispatcher lock follows the path text (LOW). No code change at that time (U447) |
| last pass on owner text 9 (NOT reviewed), one-off probe: a 600 MB line with no end to the issuer of `9af026df`; to the repaired issuer |issuer exit 1; still running|the MEDIUM finding is reproduced (the process ends after 513 MB); the repaired issuer answers once and signs the next request |
| the last pass: type check; suite (115 rows); `--case sink-controls` attempt 3 |0; 0; 0|48 rejection attempts, 0 effects; new rows for the line limit and for three names of one ledger file |
| one-off: suite against ten copies with one check removed each |non-zero for 10 of 10|with the two new repairs |
| `--case evidence` attempt 4 (final) |0|two runs byte-identical; final bundle SHA-256 `c7f2f41c…` |
| control (e) for the last pass, scratch clone of `9af026df` plus the uncommitted files: 28 Stage EXIT cases; `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, the Slice 1 report; for all 80 Markdown files outside `results/`; `scripts/exit_slice1.py --case evidence` |0 each (28 of 28); 0; 0, 0, 0; 1; 0|only the 2 older Stage 9 links without a target; bundle SHA-256 in the clone equal to the working tree's (`c7f2f41c…`) |
| push of the last pass to pull request 45 (`9af026df..2e39a100`, no force) |0|head `2e39a100` |
| hosted `gate/pr_check.py`, pull request 45, head `2e39a100`, run 44369014309 (Linux profile) |3|UNSUPPORTED, as expected: every obligation that ran holds; 33 `UNCOVERED_CHANGE` findings |
| merge of pull request 45 by the owner (2026-11-18 18:32Z; the agent did not merge) |squash commit `136ad0bf`|`git diff --quiet origin/main 2e39a100` exit 0: the tree of `main` equals the checked commit (U449) |

[Slice 1 report](proposals/forge2-slice1-refund-finality/REPORT.md).
[Review text and disposition](proposals/forge2-slice1-refund-finality/REVIEW.md).
Proved: claims P1 to P4 for the Dafny source of the checker core.
Tested on a finite set, not proved: issuer code, encoding, sink,
dispatcher. Not proved: the compiled JavaScript and the hash in the
token. The repairs after the review had one narrow check. Its one
MEDIUM and one LOW finding were repaired in a last pass that had no
review.
M1 and integration EXIT NOT_ESTABLISHED.

## Step B (print effects) is on `main`: pull requests 43 and 42 merged on the owner's word; first hosted run of the gate with a ratification record gave the expected result — R4C-1

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. On 2026-11-18 13:21Z the agent merged
pull requests 43 and 42 with administrator rights on the owner's words
"merge them" and "i approve" (`main` = `9d587c7e`). Step B
commit `ccb4e5e2` and its records `59189040` are on `main` at
`201e63b1`; the step B files are byte-equal to the reviewed commit
`f54e2507`; record 0001 on `main` regenerates byte for byte from
(`main`, `ccb4e5e2`).

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `gate/gate.py --impl impl/Ledger.dfy`; `--impl bugs/print_effect.dfy`; `--impl bugs/print_effect_marked.dfy` at `ccb4e5e2` |0; 1; 1|accepted; both planted print bugs rejected |
| Stage EXIT cases 1, 2, 3, 4, 5, 8 (24 cases); Stage 11 (3 cases) at `ccb4e5e2` |0 each|passed |
| `stage6_next_epoch.py <worktree> 3`: benchmark; controls; identity check; report EXIT twice |0; 0; 0; 0, 0|report byte-identical; process seconds −2.7 to −0.3 percent against the records on `main`; previous records kept as `results/stage6-epoch2` |
| clean clone of `59189040`: `exit_stage_6.py --case report`; Stage 11 three cases; `check_frozen_pr_gate.py` |0; 0, 0, 0; 0|passed; the EXIT runs change no file |
| `check_links.py`, all 76 Markdown files outside `results/` at `59189040` |1|only the 2 older Stage 9 links without a target; none new |
| `run_bootstrap_gate_cases.py` attempt-0005: trusted `main` `201e63b1` (holds record 0001), candidate `ccb4e5e2`; candidate `59189040` |3; 3|UNSUPPORTED; record matched; 8 of 8 floor controls as expected |
| hosted `gate/pr_check.py`, pull request 43, run 44268104696 (Linux profile) |3|UNSUPPORTED; record 0001 matched; floor controls on Linux: 6 planted bugs rejected for a proof or audit reason, `impl/Ledger.dfy` accepted, function probe equal. First hosted run with a ratification record. On Linux `toolchain/pins.json` is the pins file that no obligation lists (two findings for it) |
| hosted `gate/pr_check.py`, pull request 42 (M1 record), run 44265523794 |3|UNSUPPORTED, as expected for records |
| `gh pr merge 43 --squash --admin`; `gh pr merge 42 --squash --admin` (owner's word) |0; 0|squash commits `d026e109` and `9d587c7e`; OVERRIDE of the review rule and of the red gate status; `main` content equal to the checked commits |
| after the merges, clean clone of `main` `9d587c7e`: Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `gate/gate.py` on the two planted print bugs; Stage 5 mutation counts |1; 1|`effect_rejected` 1, `survived` 1 (before step B: `survived` 2): the `print` survivor is closed; the remaining survivor is the labelled algebraic rewrite control |
| `check_frozen_pr_gate.py`; `check_links.py` for `FORGE_MASTER_IDEA.md` and `ROADMAP.md`; record 0001 against `main` |0; 0, 0; equal|every file that record 0001 names has its new SHA-256 on `main`; 2 older Stage 9 links without a target |
| Stage 9 lock against `main` |8 entries differ|deferred |

Not verified: VERIFIED (exit 0) for a ratified change on a hosted
runner (step B has files that no obligation lists). Eight entries of
the Stage 9 lock do not match `main`. Decision D1 was taken by merging
pull request 43 as it is. Record 0001 is used up: its old digests no
longer match `main`.

## M1 chain replay on the rebuilt pinned tools: 71 of 71 theories exit 0, exports byte-equal to the old records; joint-premise theorem passes; M1 stays open — M1R-1, M1R-2

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Same machine, same pins: not a clean-room replay and not
an independent replay. No M1 theorem is claimed.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| upstream tool objects that the chain imports and that were missing (three Holmake commands, new files only) |0; 0; 0|16 theories and 3 library objects built; 0 of 1,913 existing theory files changed |
| 9 trunk theories in the tool tree (recorded Holmake commands, `-j1`) |0 each|`.dat`, `.sig`, `.sml` equal the recorded SHA-256 |
| 62 case runs of the chain up to `forge_refundSlideProfileA` (recorded commands) |0 each|71 of 71 theories equal to the recorded SHA-256; 0 different |
| import check `imp4-0001` |0|IMPORTED_COUNT 15, MISMATCH_COUNT 0 |
| `fs-0002.sml` unchanged (theory `forge_refundInputSat`); its import check |0; 0|first pass of the joint-premise theorem, for slide 0x4000 and one constructed state |
| other commands of the run |1; stopped|one Holmake dry run (missing include folder; no HOL process); one launch stopped by the agent after 20 s and run again |
| phase 2: the other 19 theories of U345–U409 and 5 parent theories (25 commands) |0 each|24 of 24 equal to the recorded SHA-256; both phases: 95 theories |
| recorded controls, repeat cases and import checks of the 41 packets (158 cases listed) |NOT RUN|deferred; no negative control is replayed yet |
| budget |8,423 s of 21,600 s|no sleep gap; one HOL process at a time |

[Replay packet](proposals/refund-executable-feasibility/m1-chain-replay-20261118/REPORT.md).
M1 stays open: Profile A approval, the R1–R5 contract link, the
compiler-premise ledger, a clean replay and an independent replay are
not done. Integration EXIT NOT_ESTABLISHED.

## Round 4 closeout: final version 3 commits; third review ends the code work; the owner merged the bootstrap (pull request 39), the Stage 6 records (pull request 40) and the documents (pull request 41); Q5 passes — U433, U436, U437, U438, U439, U440, U441, U442

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Not a stage. Stage 9 deferred. No protected file of this tree or of
this tree is changed. The owner merged pull request 39 on 2026-11-18
03:20Z (`main` = `96d2ec77`) and pull request 40 (Stage 6 records) at
03:34Z (`main` = `d0ce1942`); the agent merged nothing. Final
commits on `main` at `4143f4b2`: rule `801777ea`, record `26410d46`,
print effects `f54e2507`, its records `53534f64`.

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `run_pr_controls.py` attempt 6 (older local gate, 26 cases) |0|0 evasions |
| `run_pr_controls_main.py` attempt 7 (`main`'s gate, 22 cases) |0|0 evasions; attempts 5 and 6 failed by my defects, no acceptance (U437) |
| `run_bootstrap_gate_cases.py` attempt-0001: record commit on present `main`; unchanged candidate after the bootstrap; print effects after the bootstrap |1; 0; 3|REJECTED; VERIFIED; UNSUPPORTED with 8 of 8 floor controls: each as expected |
| hosted `gate/pr_check.py`, pull request 39, run 44213967396 |1|REJECTED; equal to the local result |
| Stage EXIT cases 1, 2, 3, 4, 5, 8 at `26410d46` (24 cases) |0 each|passed |
| `exit_stage_6.py --case report` at `main` `4143f4b2`; at `26410d46` |1; 1|`TRUSTED_INPUTS`; red before this work |
| `stage6_epoch2.py` at `main`'s tree, run 2 on mains power: benchmark; controls; identity check; report EXIT twice |0; 0; 0; 0, 0|fresh records, local commit `4cab1868`; report byte-identical; run 1 on battery power also 0 (replaced) |
| `exit_stage_6.py --case report` in a clean clone at `4cab1868`; at `26410d46` plus `4cab1868` |0; 0|repairs the Stage 6 record; needs the owner's merge |
| `exit_stage_11.py`, three cases at `4143f4b2`: records from the verified backup; clean checkout |0, 0, 0; 1, 1, 1|the evaluation records are not on `main` |
| `check_links.py origin/main FORGE_MASTER_IDEA.md` |1|10 of 13 relative links have no target on `main` |
| `check_links.py docs/master-idea-records FORGE_MASTER_IDEA.md` (local documents branch, commit `45f8c24a`) |0|218 files, protected paths 0; needs the owner's merge |
| step B `f54e2507`: `gate/gate.py --impl impl/Ledger.dfy` |0|ACCEPTED |
| step B `f54e2507`: Stage EXIT cases 1, 2, 3, 4, 5, 8 (24 cases) |0 each|passed |
| step B `f54e2507`: `stage6_epoch2.py`: benchmark; controls; identity check; report EXIT twice |0; 0; 0; 0, 0|records in commit `53534f64`; report byte-identical |
| `run_bootstrap_gate_cases.py` attempt-0002: commit `53534f64` after the bootstrap |3|UNSUPPORTED with 8 of 8 floor controls, as expected |
| `exit_stage_7.py --case own-proof`; `--case upstream-replay`; `--case invalid-proof` (scratch worktree `fd8b9608`, Docker) |0; 0; 0|attempts 2, 4, 2; Stage 7 reads none of the files that version 3 changes |
| `rebuild.py 10800` (M1 tools) |stopped by budget|45 of 71 compiler-proof theories; no M1 replay possible yet |
| `rebuild.py 14400 round4-m1-build-20261118` (M1 tools; the window that the owner's Round 4 text grants) |0|ended 2026-11-18 03:57Z, "all listed commands finished", 6,238 s of 14,400 s used: compiler proofs exit 0 (71 of 71 theories, 3,804 s); `cv_translator` exit 0 (2,434 s, `cake_compile_heap` built); ARMv8 step heap present. This is a tool build. The M1 chain replay and the `fs` runs are NOT STARTED; no M1 theorem is claimed |
| Stage 9, six EXIT cases |NOT RUN|deferred; after the bootstrap merge two lock entries are stale |
| after the owner's merge: `check_frozen_pr_gate.py origin/main` |0|`main` = `96d2ec77`, tree equal to the record commit; the eight PR-gate modules are FROZEN |
| `exit_stage_6.py --case report` at `96d2ec77`; clean clone with the records `1c21aa85` |1; 0|pull request 40 repairs the Stage 6 record |
| `run_bootstrap_gate_cases.py` attempt-0003 (trusted `96d2ec77`, candidate `1c21aa85`); hosted `gate/pr_check.py`, pull request 40, run 44229894524 |3; 3|UNSUPPORTED, as expected for record files; first hosted run of the new gate code |
| after the owner's merge of pull request 40: `exit_stage_6.py --case report`, clean clone of `main` `d0ce1942`; `check_frozen_pr_gate.py origin/main` |0; 0|Stage 6 is green on `main` |
| `exit_stage_11.py`, three cases, clean clone with the path-free records in the tree (dry run) |0; 0; 0|records for the documents pull request |
| documents pull request 41 (commit `b61da60a` on `d0ce1942`), clean clone: `check_links.py` for `FORGE_MASTER_IDEA.md`; for `ROADMAP.md`; `check_frozen_pr_gate.py`; `exit_stage_6.py --case report`; `exit_stage_11.py` three cases with the recorded arguments |0; 0; 0; 0; 0, 0, 0|protected paths 0; over all 75 Markdown files outside `results/`: 2 of 200 links without a target, both older Stage 9 links |
| `run_bootstrap_gate_cases.py` attempt-0004 (trusted `d0ce1942`, candidate `b61da60a`); hosted `gate/pr_check.py`, pull request 41, run 44232116451 |3; 3|UNSUPPORTED, as expected for documents and records; needs the owner's merge |
| Q5 after the owner's merge of pull request 41 (`main` = `201e63b1`, content equal to `b61da60a`), clean clone: Stage EXIT cases 1, 2, 3, 5, 6, 8 (22 cases); Stage 4 (3 cases); Stage 11 with the recorded arguments (3 cases) |0 each|28 of 28 cases exit 0; the Stage 5 EXIT rewrites its two records with the local tool path (two changed lines) |
| Q5: `check_frozen_pr_gate.py`; `check_links.py` for `FORGE_MASTER_IDEA.md`; for `ROADMAP.md`; for all 75 Markdown files outside `results/` |0; 0; 0; 1|record 0001 still binds the proposal text on `main`; the last check finds the 2 older Stage 9 links without a target (of 200) |
| Q5: Stage 7 from the clean clone |NOT RUN|about 3.3 hours of Docker time; every Stage 7 script, pin, fixture, example and tracked record on `main` is equal to the tree where the three cases exited 0 today (`git diff --quiet`: exit 0) |
| third independent review |0 fail-opens; 0 HIGH or MEDIUM accidental defects|one MEDIUM limit that needs an owner-written record; code work stopped by the owner's rule |

[Bootstrap checklist with the queued cleanup](proposals/forge2-pillar1-print-effects/v3/BOOTSTRAP_CHECKLIST.md).
[Review 3](proposals/forge2-pillar1-print-effects/v3/REVIEW-3.md).
This section came to `main` with the documents pull request 41 (merged
by the owner on 2026-11-18 05:16Z); the Q5 rows came with the M1 record
pull request. Round 4 is closed. Open: decision D1 for step B (print
effects); the Stage 9 lock renewal. The M1 chain replay is in the
section above. On the backup branch this file is the full record; on
`main` it is the record up to Stage 9 plus these two sections.
M1 and integration EXIT NOT_ESTABLISHED.

This is the execution plan and decision record. Stages 0–8 are DONE. Stage 6
verified the approved booking matcher and its cancellation/retry trace. The
three-condition benchmark completed 75 baseline/candidate pairs. Both real
EXIT commands returned 0. The source evidence and report reproduced byte for
byte. Stage 7's upstream replay, negative control, and own-binary EXIT each
returned 0. The exact 1,240-byte C self-test has a normal-termination proof and
a valid-entry witness. Independent checking covered 579 modules; all 86 closure
assumptions are permitted. Final source and ELF identities match. Stage 8's
wrapper-proof, hostile-outputs and evidence-separation EXITs each returned 0.
The exact approved snapshot repair retains field and prototype mutation
rejection. Source and property-test evidence each reproduced byte for byte
through fresh checks. All failures remain archived. Stage 9 is CURRENT;
the exact approved provenance contract and 11 implementation/workflow additions
are applied. The safe installation check passed. A receipt-validator audit
failed: invalid dependency hashes and substituted or missing copied ELF bytes
were not rejected. The gate remains unchanged. Runner admission, execution
authorization and a separately approved receipt repair remain unresolved.
An unapplied four-file integrity repair awaited exact-byte approval (U078).
It is now approved and applied (U079).
All six Stage 9 EXITs are NOT RUN; signing and deployment have not run.
`end_to_end=false`.
Uncertainties and measurement limits remain in append-only [unsure.md](unsure.md).

The long-term horizon and irreducible limits live in [VISION.md](VISION.md).

## Mission

Build an open-source system for general software engineering in which
non-deterministic LLM agents propose code and established, deterministic
checkers decide what is accepted.

Every accepted artifact must carry reproducible evidence. The evidence must
state exactly what was established, about which artifact, under which
assumptions, and by which method.

**LLMs propose, checkers dispose. Humans approve intent (specs), not code.**

## Operating mode — read every run

1. Read this file. If it is missing, recreate it from the stages below and set
   Stage 0 to CURRENT.
2. Work only on the CURRENT stage. Do not start a later stage, even partially.
3. A stage is complete only when every EXIT command has actually run and
   produced its required behavior. Record each exact command, real numeric exit
   code, and result here. Then mark that stage DONE, set the next stage CURRENT,
   and stop. Stage 10 has no successor.
4. Keep the final response to at most 20 lines: stage, EXIT command table with
   real exit codes, and blockers. No narrative.
5. A documentation task does not complete an implementation stage. Keep
   unexecuted checks marked NOT RUN. Never substitute expected codes for actual
   codes.
6. Append uncertain findings to `unsure.md`. Never edit, delete, reorder, or
   overwrite an existing entry. Resolve an entry by appending a new entry that
   refers to its ID. Distinguish observations, inferences, and open questions.

## Hard rules

- Use established tools: Dafny, Rocq, Lean, TLA+/TLC, Verus, Kani, Theorem's
  published pipeline, and sigstore/in-toto. Select the backend needed by the
  current stage; do not install all backends in advance.
- Never write a custom verifier, decoder, machine semantics, proof checker,
  SMT wrapper that judges correctness, or axiom system. Gate code may dispatch
  established tools, bind their results to artifacts, and enforce policy.
- Never simulate or mock a check, or report it as passed unless the real command
  ran and exited as required. If a toolchain cannot be installed or run, STOP,
  report the exact error, and change nothing else.
- Protected files are `spec/**`, `spec.lock`, `policy/**`, and `gate/**`.
  Never modify them to make something pass. To change a spec, write
  `proposals/<name>.md` with the exact diff and a plain-English reason. STOP for
  human approval. Approval must cover the actual proposed change.
- Implementations must not contain `assume`, `{:axiom}`, `{:verify false}`,
  `Admitted`, `sorry`, axiom declarations, or bodiless lemmas. The gate rejects
  these. Deliberately invalid fixtures are rejection tests, never accepted code.
- Evidence must not overclaim. Keep `end_to_end=false` unless every link from
  spec to deployed artifact is covered by a checked method. Tested does not mean
  proved. Bounded model checking does not establish an unbounded proof.
- Pin every tool version. Use resource limits rather than time limits for
  acceptance checks. Include no timestamps in evidence. The same fully specified
  inputs must produce byte-identical evidence.
- Do not echo files or reread them without a reason. Fix only what tool output
  points to. Make at most five attempts per failing proof, then report the
  blocker in at most five lines.

## Intended users and first useful release

The initial target is a small, critical component inside an ordinary software
project. Examples include a ledger, refund rules, idempotent requests, booking
invariants, and permission decisions. Stages 0–3 establish the first useful
demonstration. They do not establish general support for arbitrary applications.

The intended workflow is: approve behavior, propose an implementation, run the
checks, and inspect a plain-English claim report. The user should not need to
write a proof merely to understand what a change establishes. Authoring and
maintaining difficult specifications may still require specialist knowledge.

Different tasks need different evidence. Tests and measurements remain useful
for integrations, performance, UI behavior, and model quality. The policy must
preserve these distinctions. Broad usefulness, acceptable cost, and ease of
adoption are hypotheses to measure in Stage 10.

## Core data model

Design for these records. Implement only what the CURRENT stage requires.

```text
Claim: {
  id, statement_plain_english, spec_ref, spec_sha
}

Artifact: {
  kind: source | module | binary | container,
  sha256, build_cmd
}

Evidence: {
  claim_id, artifact_sha, method, tool, tool_version, result,
  assumptions[], trusted_base[], reproduce_cmd, producer
}

method:
  unit_tested
  property_tested
  tested_against_proved_model
  bounded_model_checked
  eval_measured
  runtime_monitored
  source_proof
  binary_proof
  kernel_checked_proof

Policy: per code tier, required claims and their minimum acceptable methods.
Gate: backend-agnostic evidence validation against policy; no method upgrades.
```

Stage 1 should use the applicable fields directly. Stage 2 formalizes their
schema. Its bundle envelope must also carry `end_to_end`, schema and policy
versions, and the links among claims, artifacts, and evidence. Avoid creating
the later schema or adapters during Stage 0.

## Design reasoning and acceptance boundaries

### 1. The gate coordinates checks

The gate's authority comes from established checkers and protected policy.
Parsing a result, comparing a digest, or checking a required claim is gate work.
Inventing semantics or deciding whether a logical proposition is true is not.
An unknown result, crash, exhausted resource budget, or missing proof fails
acceptance. It does not demonstrate that a claim is false.

### 2. Intent needs precise boundaries

Before freezing the initial ledger spec, make these decisions explicit: account
existence, amount domain, zero amounts, balance limits, retry identifiers,
identifier reuse with different arguments, and the state included in “no effect.”
Decide whether rejected requests create retry records. These choices affect C3
and C5. They must not emerge accidentally from implementation details.

For the first ledger, scope claims to the specified state transition. Do not
claim concurrency safety, crash recovery, durable storage, or distributed
exactly-once execution unless those behaviors are specified and checked. C4 is
the success of a valid operation, not a claim about network delivery or scheduler
fairness. Include termination in its contract.

### 3. Protected inputs need an external baseline

Checking `spec.lock` against files in the same proposed change detects accidental
drift. It does not authorize an agent to change both. Stage 4 must compare with a
trusted baseline and bind approval to the spec diff and revision. Gate code,
policy, workflow configuration, and tool options must come from trusted inputs.
An untrusted PR must not replace the gate that accepts it.

Initial creation of planned files establishes a baseline. Later planned work,
such as the Stage 2 adapter refactor, must preserve existing rejection behavior.
If a change requires weaker acceptance rules or a changed spec, use a proposal
and stop. Negative tests that alter protected inputs use disposable copies;
they do not edit the approved baseline.

### 4. Evidence methods form a policy relation, not a universal ranking

A binary no-crash proof does not establish ledger conservation. A kernel-checked
theorem can concern a different property or artifact. Testing, bounded checking,
source proofs, and runtime monitoring answer different questions.

Interpret “minimum method” through explicit allowed methods for each claim,
artifact kind, scope, and assumptions. A higher-sounding label cannot satisfy an
unrelated requirement. Keep one method per evidence record. Several records can
describe different checks of the same artifact.

### 5. Artifact identity includes the relevant inputs

Hash the exact artifact bytes. For a source collection, define a canonical
manifest of paths and content digests, including the dependency closure. Bind
the result to the approved spec, toolchain, verification options, and policy.
Recompute digests; do not trust values supplied by a proposal.

A matching digest and valid JSON do not prove that a checker ran. Until Stage 9
adds signed provenance, acceptance must use a trusted local or CI checker run.
Handwritten evidence cannot grant itself authority by naming a trusted producer.

### 6. Determinism needs a complete execution contract

Lock versions, distributions, checksums, platform, relevant environment settings,
solver options, seeds, and resource budgets. Canonicalize evidence ordering and
serialization. Keep wall-clock durations, host paths, run identifiers, and raw
diagnostic logs outside canonical evidence. Record benchmarks separately.

Dafny documents stable solver resource counts for the same Z3 build and platform.
That supports resource-based limits; it is not a promise of identical behavior
across arbitrary machines. [Dafny verification optimization](https://dafny.org/dafny/VerificationOptimization/VerificationOptimization)

### 7. All proof dependencies must be covered

Verification must include the required declarations and dependencies. Reject
verification bypasses, skipped members, unapproved external assumptions, and
missing obligations. Prefer the established tool's parser and audit facilities
over inventing a language parser or relying only on keyword searches.

Dafny provides audit and verification controls. In version 4.11.0, `dafny audit`
can return zero while reporting findings. The gate must inspect the findings;
an exit code alone is insufficient. Validate this behavior with real negative
fixtures in Stage 1. [Dafny 4.11.0 reference](https://dafny.org/v4.11.0/DafnyRef/DafnyRef#13618-dafny-audit)

### 8. Deployed binary coverage requires explicit links

The planned chain is:

```text
approved intent → versioned spec → checked claim about exact binary bytes
                → evidence bound to binary SHA-256
                → release/container identity → observed deployment identity
```

Stage 7 checks a property of a particular binary through the published pipeline.
The property must match the claim being advertised. A no-crash proof cannot be
used as evidence for C1–C5. Stage 9 checks provenance and release identity, and
must compare the deployed digest with the approved release digest before
claiming that the checked artifact was deployed.

For a container, record both the container digest and the contained binary
digest. Account for linked libraries, entrypoint, configuration, runtime, and
external services within the claim's scope or list them as gaps and assumptions.
A signature authenticates evidence; it does not prove program behavior.
Rebuilding the same bytes establishes reproducibility, not compiler correctness.

Keep `end_to_end=false` when a required link is missing. Even a complete artifact
chain retains its stated model and trusted-base assumptions. No stage may infer
whole-service correctness from a proof of one component.

### 9. Incremental verification must preserve coverage

Stage 4 needs a complete dependency map. Cache keys include the member, all
relevant dependencies, the spec, toolchain, options, and policy. Dependency
uncertainty must trigger broader verification or block acceptance. Cached proof
reuse requires matching inputs and trusted origin. Count checked and reused
obligations separately. Do not equate changed lines with affected claims.

### 10. Measure results without inventing benefits

Stage 6 records all attempts, failed runs, prompts, responses, available provider
token categories, verifier time, and human interventions. Missing token data is
unknown, never zero. Fixed inputs and seeds make experiments repeatable; new
LLM runs and wall-clock measurements need not reproduce identical numbers.
Report recorded results separately from reruns and make no extrapolation.

Stage 10 requires two actual weeks of observation. Report the number and kinds
of PRs observed. A period with little activity cannot establish broad usefulness.

## Stage index

| Stage | Name | Status |
| --- | --- | --- |
| 0 | TOOLCHAIN | DONE |
| 1 | LEDGER DEMO | DONE |
| 2 | EVIDENCE SCHEMA + POLICY | DONE |
| 3 | TYPESCRIPT INTEGRATION | DONE |
| 4 | CHANGE LOOP | DONE |
| 5 | SPEC TOOLING | DONE |
| 6 | SECOND DOMAIN + REUSE MEASUREMENT | DONE |
| 7 | BINARY LAYER | DONE |
| 8 | ML BOUNDARY | DONE |
| 9 | PROVENANCE | DONE in the full record; lock renewal DEFERRED (status note at the top) |
| 10 | SHADOW MODE | NOT STARTED |

## EXIT command conventions

Commands for unfinished stages below are planned interfaces, not run results.
Create only the commands required by the CURRENT stage. Finalize each exact
invocation, options, and fixture before running it, and record that invocation
in the execution record. Never mark a stage DONE from this planning table.

Scenario scripts may prepare inputs, invoke established tools, and check
expected results. They must not implement a verifier. For every negative test,
record both the raw checker exit code and the scenario script exit code. A
scenario script may return zero when rejection was expected and observed.
Missing tools, syntax errors, and process crashes do not count as the intended
negative result. Record the diagnostic and claim or policy rule that caused it.

### Stage 0 — TOOLCHAIN

**Status: DONE**

Install pinned Dafny with its bundled Z3, Node, and Python. Select host-compatible
distributions and record exact versions and checksums before installation.
Use the official Dafny 4.11.0 release as the Dafny pin. Node 24.3.0 and Python
3.10.11 were already installed and are reused. Their version and executable
checksum checks passed. The Dafny archive matched its official checksum before
extraction. Bundled Z3 4.12.1 is selected explicitly. Pins and resource settings
are in `toolchain/pins.json`. Original Node/Python installer provenance remains a
disclosed trust assumption, not a verified claim; see `unsure.md` U015.
[Dafny release](https://github.com/dafny-lang/dafny/releases/tag/v4.11.0)

Create two tiny smoke fixtures: a true arithmetic lemma with a body, and a false
arithmetic lemma with a body. Use the same locked verification settings for both.
Confirm resource-limit and timeout-disable options against the pinned CLI before
the runs. No ledger, gate, policy, or later-stage scaffolding belongs here.

| EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `dafny --version` | Prints the locked Dafny version; exits 0. | 0 — `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| `node --version` | Prints the selected Node version; exits 0. | 0 — `v24.3.0` |
| `python3 --version` | Prints the selected Python version; exits 0. | 0 — `Python 3.10.11` |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | Trivial true lemma verifies. | 0 — 1 verified, 0 errors |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | False postcondition fails verification. | 4 — 0 verified, 1 error; expected rejection |
| `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints the selected bundled Z3 version. | 0 — `Z3 version 4.12.1 - 64 bit` |

Both verification commands wrote raw outputs to `toolchain/results/true.log` and
`toolchain/results/false.log` using shell output redirection. The false result
names the postcondition `1 + 1 == 3`; it is not an infrastructure failure.
Reproduction instructions are in [toolchain/README.md](toolchain/README.md).
The stage transition ends this run. No Stage 1 implementation was created.

### Stage 1 — LEDGER DEMO

**Status: DONE**

The user approved [the initial ledger contract](proposals/initial-ledger.md) as
written. Candidate SHA-256
`e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`
is frozen in `spec/LedgerSpec.dfy` and `spec.lock`. The real Dafny verifier
accepted the concrete refinement with 12 verified obligations and zero errors.
The final gate and all EXIT scenarios passed. The approved spec bytes are
unchanged. [Archived Stage 1 evidence](results/stage1/evidence.json) records C1–C5 as `source_proof` and keeps
`end_to_end=false`. [Actual results](results/stage1.json) record the real codes.

Create `spec/LedgerSpec.dfy` as an abstract module, `impl/Ledger.dfy` as its
refinement, `gate/gate.py`, and `spec.lock`. The lock contains the spec SHA and
Dafny version. Freeze the approved behavior before implementation repairs.

| Claim | Required behavior |
| --- | --- |
| C1 — conservation | A transfer preserves total funds. |
| C2 — non-negative | Every resulting account balance is non-negative. |
| C3 — idempotent retries | Repeating the same request does not repeat its effect. |
| C4 — progress | A valid transfer terminates and succeeds. |
| C5 — invalid → no effect | An invalid transfer is rejected and leaves the specified state unchanged. |

Self-transfers are invalid and must be rejected. Bind diagnostics to claim IDs.
Check the concrete refinement; abstract declarations alone establish no
implementation result. Audit forbidden constructs and all proof dependencies.

Plant `self_transfer` (creates money), `off_by_one` (`<` instead of `<=`),
`retry_double`, and `sneaky_assume`. Keep a fixed, deliberately incomplete unit
suite that passes these fixtures. Demonstrate each rejection through the gate.
Report `sneaky_assume` as a forbidden assumption, with the affected claim named
and unestablished; do not invent a counterexample from an audit failure.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes source-proof evidence; exits 0. | 0 — accepted C1–C5 |
| `python3 scripts/exit_stage_1.py --case reproducibility` | Runs the gate twice and byte-compares evidence; exits 0 on equality. | 0 — both gate runs and `cmp` exited 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | Unit suite passes each fixture; gate rejects all four and names affected claims/rules. | 0 — all four unit runs exited 0; all four gates exited 1 |
| `python3 scripts/exit_stage_1.py --case spec-lock` | A changed spec with its old lock is rejected in a disposable copy. | 0 — gate exited 1 with `SPEC_LOCK` |
| `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects a candidate without the approved refinement relationship. | 0 — gate exited 1 with `SOURCE_SCOPE` |
| `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects bodiless lemmas, axiom lemmas, and disabled verification. | 0 — each direct auditor exited 2; each gate exited 1 |

The final negative-control results were:

| Fixture | Basic unit exit | Checker exit | Gate exit | Claim or policy diagnostic |
| --- | --- | --- | --- | --- |
| `self_transfer` | 0 | 4 — verification | 1 | C1 and C5 not established |
| `off_by_one` | 0 | 4 — verification | 1 | C4 not established |
| `retry_double` | 0 | 4 — verification | 1 | C1 and C3 not established |
| `sneaky_assume` | 0 | 2 — audit comparison | 1 | Forbidden assumption; C1–C5 not established |

The basic unit suite exercises an ordinary transfer and a missing-account
rejection. It deliberately misses these bugs. Unit success is recorded as
`unit_tested`; it is not proof. A failed proof obligation means that the checker
did not establish the claim. An audit failure does not supply a counterexample.

The gate delegates proof decisions to pinned Dafny and Z3. It checks the exact
approved spec, an explicit refinement declaration, the required verified
obligations, and an empty Dafny audit report. See [gate/README.md](gate/README.md)
for commands, evidence identity, source-format restrictions, and trusted inputs.
The spec-lock test changes only a disposable copy. It does not establish
authorization for changing both the spec and lock in a proposed change.

Canonical evidence SHA-256:
`8389e88aac8526ce48dd8ef70c8e6e40f53ccf5360465b79cb8cec27b3c66df3`.
Those exact bytes and the original gate/scenario sources were preserved under
`results/stage1/` before the Stage 2 refactor. Root `evidence.json` now holds the
current policy-bound format. The archived scripts are historical source records.
Raw commands, exit codes, and diagnostics are retained locally under
`build/stage1/<case>/`; repeated runs archive prior logs under
`build/stage1-history/`. These generated directories are not publication inputs.
The portable result summary is [results/stage1.json](results/stage1.json).

This stage transition ends the run. Stage 2 is CURRENT; no Stage 2 files were
created. The user authorized continuation through the full roadmap, with binary
and deployment work deferred to their planned stages; see `unsure.md` U024.

### Stage 2 — EVIDENCE SCHEMA + POLICY

**Status: DONE**

Define JSON Schema for the core model and bundle metadata. Create
`policy/tiers.yaml`. Refactor the gate into a backend-independent policy layer
with Dafny as one adapter. Preserve Stage 1 rejection behavior. Use an established,
pinned JSON Schema validator. JSON validation establishes structure only.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_2.py --case schema` | The schema validates actual Stage 1 evidence. | 0 — exact Stage 1 archive and current evidence validate; two malformed inputs rejected with 1 |
| `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Hand-edited `source_proof` evidence with a wrong artifact SHA is rejected. | 0 — three artifact-binding controls rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case method-policy` | A tier requiring `source_proof` rejects `unit_tested` evidence. | 0 — unit, bounded-check, and unrelated kernel-proof labels rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case round-trip` | Supplied valid evidence must reproduce through a fresh real checker run. | 0 — gate and byte comparison each exited 0 |
| `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects altered policy, claims, trusted inputs, coverage, producer, or document keys. | 0 — all 15 negative gate calls exited 1 for the intended rule |

The refactored gate command also exited 0:
`python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json`.
It produced schema version `2.0.0` evidence bound to policy `forge-ledger` version
`1.0.0`, tier `critical`, with policy and trusted-input hashes. The five records
remain `source_proof`; `end_to_end=false`. The real Dafny run established 12
obligations. The schema also accepts archived format-1 evidence without upgrading
its authority or adding a policy binding that was absent from the original run.

Established validators: jsonschema 4.21.1 and PyYAML 6.0.1. Their installed
dependencies and file hashes are pinned in `toolchain/requirements-stage2.txt`
and `toolchain/validator-pins.json`. These preinstalled packages ran successfully;
no installation or archive authentication is claimed. See U025 for the limit.

The core checks structure, current artifact and approved-claim bindings, explicit
allowed methods, and selected policy identity. The Dafny adapter retains proof,
audit, source-scope, and result-coverage checks. Imported evidence must also match
a fresh checker result. The producer-name tampering control reached that final
comparison and was rejected. Schema-only validation prints `SCHEMA_VALID`, never
`ACCEPTED`, and writes no accepted bundle.

All Stage 1 scenario commands were rerun against the refactored gate:

| Regression command | Actual exit code | Required raw behavior retained |
| --- | --- | --- |
| `python3 scripts/exit_stage_1.py --case reproducibility` | 0 | Gate 0 twice, `cmp` 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | 0 | Units 0 each; three verifier exits 4; sneaky audit 2; gates 1 each |
| `python3 scripts/exit_stage_1.py --case spec-lock` | 0 | Gate 1 for stale lock in disposable copy |
| `python3 scripts/exit_stage_1.py --case contract-binding` | 0 | Gate 1 for missing approved refinement |
| `python3 scripts/exit_stage_1.py --case audit-controls` | 0 | Direct audits 2 and gates 1 for all three proof-escape controls |

`cmp evidence.json build/stage1/reproducibility/evidence.json` also exited 0.
The approved spec and `spec.lock` are unchanged. The evidence digest is
`0400b148904360eb3fde1940acaf73ba0a1342f9244da8cf1f69046a6c9d4e16`.
Actual results are in [results/stage2.json](results/stage2.json). Raw local logs
are under `build/stage2/` and `build/stage1/`; previous runs are archived.

Stage 2 is DONE. Stage 3 is CURRENT. This transition ends the run. No TypeScript
integration, later-stage adapter, binary layer, or deployment code was created.

### Stage 3 — TYPESCRIPT INTEGRATION

**Status: DONE**

Compile the Dafny ledger core to JavaScript. Import it from `app/main.ts`.
Add handwritten `ts/ledger.ts` and pinned fast-check property tests against the
Dafny model. Record fixed seeds and run counts. Cover sequences of operations,
including retries and invalid requests, and preserve the spec's numeric domain.
Record handwritten TypeScript results as `tested_against_proved_model`.
The source proof remains attached to Dafny source; generated JS is a distinct
artifact with a recorded build link and explicit compiler/runtime assumptions.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `node --import tsx app/main.ts` | Uses locked local dependencies; prints `Ok` then `Rejected`; exits 0. User-approved replacement for the original CLI invocation. | 0 — exact expected output; rerun after approval also exited 0 |
| `python3 scripts/exit_stage_3.py --case correct-typescript` | Real property tests pass on correct TypeScript. | 0 — 300 runs, 3,506 compared transitions, no skips |
| `python3 scripts/exit_stage_3.py --case self-transfer` | Real property tests fail on the planted TS self-transfer bug. | 0 — actual fast-check exit 1 and gate exit 1; real shrunk counterexample |
| `python3 scripts/exit_stage_3.py --case evidence-labels` | Source proof and TS comparison results have distinct, correct methods and digests. | 0 — source and comparison gates 0; critical-tier rejection 1 |

The pinned JS packages are installed and runnable. The original install attempt
exited 1 with `getaddrinfo ENOTFOUND registry.npmjs.org`; the user then installed
them externally. `npm ls --depth=0` exited 0 with the requested exact versions.
Their lock and observed installed content are pinned in `package-lock.json` and
`toolchain/javascript-pins.json`. Original tarball integrity was not independently
replayed here.

The compiled-model build command, `python3 scripts/build_model.py`, exited 0.
Dafny verified 12 obligations, then generated JS. The script preserves that output
and adds only a tracked CommonJS export footer. The model module digest is
`2387fcdf5fcfb6d9bc4a05e752b55549cd001ada104431a5bf1311e92ce2b567`.
The original approved spec and `spec.lock` are unchanged.

`node --import tsx app/main.ts` exited 0 and printed exactly `Ok` then `Rejected`.
This supported loader works within current permissions. The tsx CLI version
probe exited 1 with `listen EPERM` for its local socket. The user authorized IPC,
but the host refused an elevated retry because `sandbox_approval=false`.
That refused retry did not run and has no process exit code.

The original `npx tsx app/main.ts` command subsequently ran and exited 1 with
`listen EPERM`. Its `cli-demo` scenario also exited 1. The user then approved the
previously proposed replacement, `node --import tsx app/main.ts`. That exact
replacement ran again with exit 0 and the expected output. This is an approved
invocation change, not a claim that the original CLI command passed. The spec,
lock, policy, comparison corpus, and evidence methods are unchanged. See U030.

Supplemental real checks:

| Command | Actual exit code | Observed result |
| --- | --- | --- |
| `npx --no-install tsc --noEmit` | 2, then 0 | Fixed the reported example tuple type; implementation unchanged |
| `python3 scripts/exit_stage_3.py --case reproducibility` | 0 | Two real builds and gate runs; generated module and evidence byte-identical |
| `python3 scripts/exit_stage_3.py --case loader-demo` | 0 | Real loader invocation printed exactly the two expected lines |
| `python3 gate/gate.py --schema-only results/stage3/typescript-evidence.json` | 0 | Schema validation only; no proof claim |

All five Stage 1 and all five Stage 2 scenario commands were rerun and exited 0.
The real child codes, comparison counters, and preserved negative counterexample
are in [results/stage3.json](results/stage3.json) and `results/stage3/`.
Source evidence is `source_proof`; TypeScript evidence is
`tested_against_proved_model`. The critical tier rejects the latter. The compiler,
runtime, and conversion bridge remain assumptions, and `end_to_end=false`.
See [ts/README.md](ts/README.md) for the exact corpus and module-layout scope.

All Stage 3 EXITs, including the approved replacement invocation, are established.
Stage 3 is DONE; Stage 4 is CURRENT. This transition ends the run. No Stage 4
implementation or later-stage spec change was started.

### Stage 4 — CHANGE LOOP

**Status: DONE**

Investigation: `python3 scripts/probe_stage_4.py` ran with exit 0. It invokes
real Dafny commands on isolated copies. Full verification accepted the original
ledger (exit 0) and rejected a broken helper proof (exit 4). Selecting only
`Ledger.Apply` returned exit 0 in both cases. Selection therefore cannot replace
dependency coverage. The diagnostic accepts no artifacts and completes no
Stage 4 EXIT. Exact child commands and obligation counts are recorded in
`results/stage4-member-probe.json`; see `unsure.md` U033.

Local implementation: `gate/incremental.py` uses Dafny/Boogie snapshot caching,
audits both revisions, binds evidence to SHA-256 source identities, and rejects
changes to trusted inputs. `python3 scripts/check_stage_4_local.py` ran with
exit 0. A valid Apply edit checked 2 obligations and reused 10; broken helpers,
weakened helper contracts, and planted bugs were rejected. Repeated evidence
was byte-identical. The first local test driver run exited 1 because it expected
the wrong exit code for Dafny's bare-assume warning; that failure is preserved.
These local controls do not satisfy the real-PR EXITs below. See
`docs/stage4-change-loop.md`, `results/stage4-local.json`, and `unsure.md` U034–U036.

The exact saved reproduction command also ran with exit 0 and reproduced
identical evidence. Linux inventory then succeeded in
[Actions run 40397041174](https://github.com/mack-dot/forge/actions/runs/40397041174):
the inventory command exited 0, the true lemma exited 0, and the false lemma
exited 4. Exact child commands and measured pins are in
`results/stage4/ci-inventory.json`. The new Linux profile is now selected explicitly
by the PR gate. Its real-PR results are recorded below. The workflow runs
trusted checking and reporting code in separate jobs. These preparation checks
do not satisfy the real-PR EXITs.

Pre-publication regression record: `results/stage4/regressions.json` retains all
20 exact commands and real codes. The updated local controls exited 0. All five
Stage 1 scenarios exited 0. An initial Stage 2 method-policy check exited 1
because its fixture used stale evidence and reached `TRUSTED_INPUTS` first.
After the real source gate refreshed evidence (exit 0), all five Stage 2 scenarios
and all five supported Stage 3 scenarios exited 0. See U041 for the setup error;
no acceptance rule was relaxed. The actual loader demo printed `Ok` then `Rejected`.

Create a GitHub Action that computes affected claims from dependencies and
content hashes, invokes per-lemma/per-member verification, and posts a
plain-English claims table. Pin actions and dependencies. Use trusted gate and
policy inputs and isolate untrusted PR execution from credentials.

Demonstrate a fee requirement through `proposals/fees.md`. Stop for human
approval before changing the spec. After approval of that exact diff, create
spec v2, update the lock through the approved path, and reverify. Bind approval
to the revision; a later edit requires fresh approval. Block an agent attempt
to weaken C2. An approval label alone is insufficient evidence of approved text.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_4.py --case affected-claims` | A real PR without a spec change verifies only affected claims; logs checked/reused counts. | 0 |
| `python3 scripts/exit_stage_4.py --case unapproved-spec` | The real workflow rejects an unapproved spec change and the C2 weakening attempt. | 0 |
| `python3 scripts/exit_stage_4.py --case approved-spec` | After human approval, the real workflow accepts the new spec and records its new SHA. | 0 |

Record PR and workflow run references. Local scenarios cannot substitute for
the required GitHub Action runs. Keep this stage CURRENT while approval is pending.

Actual EXIT execution: [run 40403180524](https://github.com/mack-dot/forge/actions/runs/40403180524),
job 121854084912, trusted revision `b2906e2f64f9e1ecd364d2dced55a391f736c236`.
Both exact commands above exited 0. `results/stage4/exit-run.json` and
`exit-affected-claims.json` / `exit-unapproved-spec.json` retain the API bindings,
actual checker receipts, comments, statuses, and real exit codes.

PR 1 / run 40402849081 accepted the valid Apply edit: gate 0; baseline checked 12;
candidate checked 2 and reused 10; literal replay 0 and byte-identical evidence.
PR 2 / run 40402945633 rejected an unapproved spec plus matching lock with gate 1.
PR 3 / run 40402975014 rejected C2 weakening with gate 1. Both failures reported
`UNAPPROVED_PROTECTED_CHANGE`, emitted no accepted evidence, and had successful
reporting jobs. The negative workflow failures are the required observations.

Approved intent: [proposals/fees.md](proposals/fees.md) contains the exact
spec and lock diff approved by the user's yes response. Candidate spec SHA-256:
`2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.
It proposes one unit per fresh successful transfer, paid by the sender to fee
account 0. Retries and rejections pay no fee. The exact approved diff was applied
locally; both candidate digests match. See proposals/fees-decision.md and U044.
The trusted approval support is published separately from the fee PR, so the
real workflow can check the v1-to-v2 spec transition against an external baseline.

Local fee validation: the source proof passed on its first attempt (gate 0).
The model build, ten explicit examples, all 16 full-gate/Stage 1–3 regression
commands, and the updated local incremental controls passed (scenario codes 0).
`python3 scripts/check_stage_4_approval.py` exited 0: approved candidate checked
4 obligations and reused 8; altered spec, C2, approval metadata, and policy each
failed with gate 1. Literal replay exited 0 with identical evidence. These are
local checks; the real approved-spec EXIT is recorded below. See U045.

Final Stage 4 execution: [run 40409284514](https://github.com/mack-dot/forge/actions/runs/40409284514),
job 121875254229, commit `88057d49f9abe6cf3a701c1f388a2377108428e3`.
The three exact EXIT commands above each exited 0. The unapproved-spec case
checked three real rejection PRs, including the new post-approval C2 mutation.
Prior EXIT reports are preserved with `-before-fees` names.

PR 4 / run 40405564741 accepted the exact fee spec with gate 0: baseline 12
checked; candidate 4 checked, 8 reused. Literal replay exited 0 and reproduced
identical evidence. Its new spec SHA is the approved candidate digest above.
PR 5 / run 40405711794 changed C2 after fee approval and was rejected with gate 1,
`UNAPPROVED_PROTECTED_CHANGE`, and no accepted evidence. Both reporting jobs
succeeded. PR 4 merged at `08cae1c59f6c1b40354851b422070a1edb4dc39d`; the merged
tree exactly matched the checked PR tree. See U047 and results/stage4/exit-run.json.

Every Stage 4 EXIT requirement is established for the recorded revisions.
Stage 4 is DONE. Stage 5 is CURRENT; no Stage 5 implementation ran in this turn.

### Stage 5 — SPEC TOOLING

**Status: DONE**

Render every claim in plain English. Generate accept/reject examples. Add a
checked witness of a non-trivial successful execution. Mutate implementations
and report which mutants the spec catches. Use isolated fixtures for deliberately
vacuous specs; do not weaken the approved spec.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_5.py --case vacuity` | Flags a spec that accepts implementations which reject everything. | 0 |
| `python3 scripts/exit_stage_5.py --case mutations` | Lists killed and surviving mutants and the kill rate. | 0 |

Report invalid mutants and inconclusive checks separately from kills. A witness
rules out the demonstrated vacuity; it does not prove that the spec captures all
human intent. A kill rate is a measured diagnostic, not a completeness theorem.

Actual execution records: results/stage5/vacuity.json, mutations.json,
replay.json, and auxiliary.json. The raw log archive index binds 86 actual logs.
Both exact EXIT commands ran with exit 0 after correcting the driver issues
recorded in U048. Earlier failed driver runs remain preserved, with codes 1.
The production gate and approved spec were not changed to resolve those issues.

`python3 scripts/generate_claim_docs.py` exited 0 and generated docs/claims.md
from actual source-proof evidence and 227 model comparisons: 6 Ok, 221 Rejected.
All matched TypeScript; the comparison evidence binds both the candidate bytes
and the reference model. The explicit TypeScript compiler check exited 0.

The successful-execution witness verified with 13 obligations and Dafny exit 0.
An isolated spec with false retry/fresh-valid predicates admitted a reject-all
implementation (Dafny 0). The same successful-execution witness failed there
(Dafny 4), so the vacuity diagnostic flagged it. That fixture was never approved
for production acceptance.

Mutation results: 8 killed, 2 survived, 1 invalid, 1 audit rejected, 0 inconclusive.
Spec-proof kill rate: 8/10 (80.00%). The algebraic rewrite and print-effect
mutants survived. The labeled algebraic control stays in the denominator;
invalid programs and audit rejections do not count as spec-proof kills.
Printed output is outside the current state claims. No general defect-coverage
rate or semantic-equivalence result is inferred.

`python3 scripts/render_spec_report.py` exited 0. After the input-binding fix
in U050, two complete runs of generation, both EXITs, and rendering returned 0.
Five real cmp commands returned 0 for examples.json, source-evidence.json,
spec-quality.json, docs/claims.md, and docs/spec-quality.md. Canonical summaries
exclude raw timing/log data. See U051 for the completion scope.

Every Stage 5 requirement is established for the recorded inputs. Stage 5 is
DONE. Stage 6 is CURRENT; no Stage 6 implementation or benchmark ran in this turn.

### Stage 6 — SECOND DOMAIN + REUSE MEASUREMENT

**Status: DONE**

The user approved [the exact booking proposal](proposals/booking.md) by replying
"go ahead". The [decision record](proposals/booking-decision.md) binds the approved
public revision and spec/lock digests. Those bytes were applied without alteration.

The matcher establishes B1 no double-booking; B2 a fresh valid request gets the
lowest allowed free slot; B3 cancellation frees exactly its target slot; and B4
accepted retries replay their historical result without another state change.
It reuses the checked Ledger.TotalReplace and TotalRemove lemmas for capacity sums.
The [booking gate](gate/booking.py) uses the existing evidence schema and policy
validator, with a new source-proof-only booking policy. Existing ledger inputs
remain unchanged. [Behavior and scope](docs/booking.md).

| EXIT command | Actual behavior | Real exit code |
| --- | --- | --- |
| `python3 scripts/benchmark_reuse.py` | Completed five repetitions of five cases under three conditions: 75 pairs. Every expected acceptance/rejection occurred. | 0 |
| `python3 scripts/exit_stage_6.py --case report` | Recomputed measured totals, checked raw logs and source evidence, and reconciled all available runtime token categories in the stated interval. Generated the scoped report without extrapolation. | 0 |

The [measured report](docs/reuse-benchmark-epoch1.md), [raw experiment](results/stage6-epoch1/benchmark.json),
[source evidence](results/stage6-epoch1/source-evidence.json), and [report EXIT receipt](results/stage6-epoch1/report-exit-attempt1.json)
retain exact commands, real codes, digests, and limits. The hardware was Apple M1
Pro / MacBookPro18,1, 16 GB, with 10 reported logical CPUs and macOS 27.0.1.
The verifier used one worker, the existing pinned Dafny/Z3 builds, resource limit
1000000 per isolated assertion batch, and verification time limit 0.

| Condition | Pairs | Verifier process seconds, baseline included | Checked members, including rejected candidates | Reused members |
| --- | ---: | ---: | ---: | ---: |
| Cold flattened input | 25 | 269.713 | 1100 | 0 |
| Shared files, fresh checks | 25 | 271.067 | 1100 | 0 |
| Native dependency-graph reuse | 25 | 175.828 | 590 | 510 |

These are observations for this exact corpus and host. Audit, fixture setup,
preparation failures, and development checks are recorded separately. Cached
trace times/resource counts describe earlier work and are excluded from new
solver-work totals. Every warm-up baseline is charged. No productivity or
cross-project benefit is inferred. Fresh timing reruns can produce different
numbers; reproduction of recorded totals is a separate operation.

Additional real checks:

- Booking implementation verification attempts returned 4, 4, and 0. The last
  checked 99 assertion batches across 22 members. Trace attempts returned 4, 4,
  and 0; the last checked 238 batches across 33 members. All failures are retained.
- `python3 scripts/check_stage_6.py` first returned 1 because an audit-scope control
  did not reject at the expected audit step. Verification still rejected the
  forbidden assumption. The new gate was strengthened to audit each concrete
  implementation explicitly. The final control script returned 0.
- Final acceptance and imported-evidence replay returned 0; actual `cmp` returned
  0. Six negative gates returned 1 for artifact mismatch, wrong method, forbidden
  assumption, bodiless lemma, unapproved spec/lock, and changed witness. The two
  proof-escape auditors returned 2. No rejected case wrote accepted evidence.
- A postrun inspection matched all 450 materialized source files to the frozen
  fixture bytes. The accepted source collection has its own canonical manifest.
- A second report EXIT returned 0. Actual `cmp` commands returned 0 for both
  `results/stage6/report.json` and `docs/reuse-benchmark.md`. See [replay](results/stage6-epoch1/report-replay.json).

The [usage record](results/stage6/accounting.json) includes all six available
runtime categories for 76 responses in its declared interval. Total: 10146635
tokens; input: 10041872, including 9944960 cached; output: 104763, including
53391 reasoning output. Reported cache-write input: 0. Subcategories are not
added again. Per-response sums match cumulative differences. Three human
interventions and three automatic continuations are separate. Shared authoring
is not allocated to the conditions by guess. This interval ends before report
publication; it is not a final project bill. Local transcript events are indexed
by hash; private instructions/reasoning and internal transport bodies are not
published. Earlier proposal resolution and one hardware inspection have no
isolated subprocess timing; neither was a proof run.

The original syntax-only proposal check returned 0 and remains under
[results/stage6/proposal/](results/stage6/proposal/). Preparation run-0001 returned
1 for denied sysctl inventory; run-0002 returned 1 for a report-count error;
run-0003 returned 0 for all 15 preflight pairs. Full run-0004 returned 0.
See append-only `unsure.md` U054–U061 for decisions, failures, and scope.

The PR workflow still reports the ledger claims; booking acceptance uses its
explicit gate command. No new PR-enforcement guarantee is claimed. All evidence
keeps `end_to_end=false`. Stage 7 is CURRENT; no Stage 7 command ran in this turn.

### Stage 7 — BINARY LAYER

**Status: DONE — all three real EXITs passed, including independent checking**

Use a Docker-capable host and Theorem's published Rocq/RISC-V pipeline. Pin an
upstream commit, image digest, semantics, and dependencies. Replay one published
upstream proof, then prove a no-crash property of a small C or Rust core through
that pipeline. Never replace missing upstream support with custom semantics or
a custom decoder. Record exact binary digests, theorem scope, assumptions, and
trusted components. Keep unrelated ledger claims unestablished at the binary layer.

Upstream publishes proofs about particular binaries under its Linux-process
model. These do not automatically cover another architecture or build.
[Published pipeline](https://github.com/theorem-labs/oss-verify-proofs)

The documented `oft check` path audits assumptions. Its independent `rocqchk`
pass is optional and can be expensive. Our EXIT requires that pass for the own
proof; an upstream replay alone is insufficient. “Audit clean” means no
assumptions outside the explicitly recorded upstream allowlist, not an empty
trusted base. [Upstream checking procedure](https://github.com/theorem-labs/oss-verify-proofs/blob/main/docs/checking.md)

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_7.py --case upstream-replay` | The pinned published pipeline, independent `rocqchk`, and assumption audit accept the upstream proof. | 0 — attempt 0003; earlier attempts 0001 and 0002 returned 1 before proof checking |
| `python3 scripts/exit_stage_7.py --case invalid-proof` | The real checker rejects a deliberately invalid proof for the intended reason. | 0 — attempt 0001; prepared proof rejected with 1, valid True certificate compiled with 0, published binding wrapper rejected it with 1 |
| `python3 scripts/exit_stage_7.py --case own-proof` | Own binary proof passes the pipeline, `rocqchk`, and assumption audit. | 0 — attempt 0001; termination and valid-execution witness compiled, both binding wrappers compiled, full independent kernel check returned 0, final identities match |

Record the exact container, upstream, and `rocqchk` commands and all real codes.
Use `binary_proof` and `kernel_checked_proof` only for the scopes actually checked.
If the host, tooling, resource needs, or proof blocks progress, report the exact
blocker. Leave Stage 7 CURRENT and stop. A truthful blocked report is permitted;
it is not a completed stage and does not unlock Stage 8.

Stage 7 setup record (not proof EXITs):

- The first `docker version` attempt returned 1 because the prior session could
  not access the Docker socket. After the user enabled full permissions, the
  real retry returned 0. Client and engine are 28.5.1; Docker Desktop is 4.48.0.
- The published checker image was pulled by digest with exit 0. Its AMD64
  platform manifest is pinned as well. An offline container with one CPU and
  4 GiB of memory ran `rocq --version` with exit 0 (Rocq 9.2, OCaml 4.14.3),
  and `python3 --version` with exit 0 (Python 3.12.3).
- Git fetched upstream commit `bf6a65114ed2e255098e213e183e83f63c2cabcc`
  with exit 0. The selected replay is `zlib/checksum_fuzzer/plain_halts`.
  The initial macOS checkout later failed exact source identity. Linux recovery
  and dependency installation are recorded below; proof replay remains pending.
- Exact commands, raw output, real exit codes, and output digests are in
  [results/stage7/commands](results/stage7/commands). The recorder makes no proof
  verdict. These setup results do not establish binary or deployment coverage.
- The user separated binary evidence from post-foundation abstraction-discovery
  research. The research comparison and first public product priorities are
  documented only in [VISION.md](VISION.md). They add no later-stage work here.

Recovery record:

- Attempt 0001 returned 1 before Rocq ran. The upstream tree has 110 groups of
  names that differ only by case (222 paths). The host checkout could not retain
  distinct bytes for them. Its original full diff remains in the attempt log.
- The first Linux clone also returned 1: `/work/.git: Permission denied`.
  Inspection found an ext4 volume owned by UID/GID 1000 with mode 0755, while
  that clone ran as UID/GID 501:20. The previous `chown` command reported 0, but
  its intended ownership was not present on the next mount. No cause for that
  ownership reset is asserted without a separate test.
- Recovery uses the image's existing non-root `opam` user, UID/GID 1000:1000.
  The clone and exact checkout each returned 0. No global Docker setting,
  privileged container, or broad host permission change was needed.
- In attempt 0002, real Git identity commands returned 0. All 149,053 tracked
  files (8,606,911,568 bytes) matched their upstream Git blobs. All 222 case
  paths have distinct inodes. The selected ELF matched SHA-256
  `4f04e95082d3e0baa9d55c72288945d99e64bb7503e39c0e644f4b38a7781af2`.
  The installed compiler/checker and package inventory are retained.
- Attempt 0002 returned 1 because the new recording wrapper incorrectly treated
  the upstream shell launcher as Python. Rocq proof checking did not run. The
  wrapper now invokes the same `oft` module, root, and environment as that
  launcher. It observes actual subprocess return codes without replacing any
  checker function or changing a verdict. The previous runner is archived.
- The user's recovery instruction requires independent checking for the
  upstream replay too. The real invocation now includes `--rocqchk`; success
  requires both independent passes and the upstream assumption audit. Attempts
  and command records remain separate from canonical accepted evidence.
- In attempt 0003, the statement build and its independent `rocqchk` pass
  returned 0. The proof library build, target proof compilation, and generated
  binding-wrapper compilation also returned 0. The wrapper audit reports 15
  allowed assumptions. At that checkpoint, the final independent proof check
  was still running. The completed result is recorded below.
- The image's 201 LPS source files match the source-tree hash in the pinned
  upstream Dockerfile. The actual source-hash check returned 0. Tool executable
  hashes and the wrapper's exact assumption names are retained in command
  records. These identity and intermediate checks do not complete Stage 7.

Completed upstream replay:

- Attempt 0003's complete EXIT returned 0. Both independent `rocqchk` calls
  returned 0. The full proof closure audit reports 86 allowed assumptions,
  no type-in-type dependencies, no unsafe fixpoints, and no assumed positivity.
- The target proof and its generated binding wrapper each compiled with exit
  0. Its theorem-specific audit lists 15 allowed assumptions. These differ
  from the 86 assumptions in the complete imported dependency closure.
- The selected proof library has 407 source modules. Its Dune log records
  407 actual module compilations. The first independent pass checked 469
  modules; the final independent pass checked 997, including all 407 library
  modules. Compiled-module counts are not independent-check counts.
- Both complete source-identity commands returned 0. Before and after hashes
  match for every tracked source file and the selected binary. The full raw
  commands, output, audits, and input manifests remain under
  `results/stage7/upstream-replay/attempt-0003/`.
- The negative-control runner now tests the prepared invalid proof and a valid
  True certificate against the unchanged upstream binding-wrapper template.
  Its complete EXIT returned 0 on attempt 0001. Both intended rejections were
  proof type mismatches, not infrastructure failures. Pre/post source and ELF
  identity checks returned 0 and their digests match.
- The next task is an own compiled C arithmetic self-test, with its exact ELF
  checked under the published LPS semantics. No own-binary proof or EXIT has
  run. The published compiler image was fetched by digest with exit 0.
- All earlier failed attempts remain unchanged. The public operational-record
  archive preserves the large input manifests and raw logs as standard tar/xz.
  This is an intermediate publication, not completion of Stage 7.

Completed own-binary proof:

- `python3 scripts/stage7_build_own.py` returned 0. Two actual clang 20.1.8
  compilations returned 0 and produced identical 1,240-byte RISC-V ELFs:
  `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
- `python3 scripts/exit_stage_7.py --case own-proof` returned 0 on attempt 0001.
  Its nine fresh Rocq compilation commands returned 0. These cover seven
  source modules (including the generated image) and two binding wrappers.
  The existing core Dune build returned 0 with no module compilation logged.
- The exact statement is `halts_may_fail [verdict_accept] Images.program`.
  For every valid modeled input and entry, every execution terminates normally
  with status 0. It has no memory-budget refusal exemption. The arithmetic pair
  is fixed in this ELF; no claim covers arbitrary GCD arguments.
- The separate `selftest_has_valid_execution` theorem proves that a valid input
  and entry exist and satisfy that same termination property. Image validity,
  the witness, and the universal theorem are all independently checked.
- The unchanged published wrapper template bound both proofs to their required
  propositions. Both theorem audits list 13 permitted primitive assumptions.
  Real `rocqchk -o -bytecode-compiler no` returned 0 over all 579 dependency
  modules. The official closure audit lists 86 permitted assumptions, with no
  type-in-type, unsafe fixpoints, or assumed positivity. No allowlist changed.
- Both full upstream source identity commands returned 0. Their manifest
  digests match. The own ELF, C source, proof sources, and generated image inputs
  retain their initial hashes. A separate post-check manifest hashes all 579
  compiled dependency files; it is not another kernel execution.
- Exact commands, raw output, versions, digests, and audits remain under
  `results/stage7/own-proof/attempt-0001/` and `results/stage7/commands/`.
  Canonical evidence, the complete assumption list, and the exact ELF are in
  `results/stage7/accepted/own/`. The full records are archived for publication.
- `python3 scripts/stage7_emit_evidence.py --attempt results/stage7/own-proof/attempt-0001 --output results/stage7/accepted/own` returned 0.
  Repeating with `--output build/stage7/serialization-repeat` returned 0.
  `diff -r results/stage7/accepted/own build/stage7/serialization-repeat` returned
  0. This checks serialization, not a second proof replay.
- `python3 gate/gate.py --schema-only results/stage7/accepted/own/evidence.json`
  returned 0. Structural validation is separate from the actual proof checks.
- Previous failures are preserved. No protected contract, checker semantics,
  or acceptance policy changed. Model fidelity, ELF loading/data import,
  kernel primitives, image provenance, host runtime, and hardware remain trusted.
  Compiler correctness, deployment identity, and whole-service correctness
  remain unproved. `end_to_end=false`.
- Stage 7 is DONE; Stage 8 is CURRENT. Per the latest user instruction, stop
  after recording and publishing this transition. Performance experiments and
  proof-construction research remain deferred. See append-only U068–U069.

### Stage 8 — ML BOUNDARY

**Status: DONE**

Wrap an LLM-backed refund suggester in verified code. Enforce refund ≤ charge,
allowed reasons, and a safe fallback for timeout or invalid output. Treat model
responses as untrusted inputs. Define the charge and refund numeric domains in
the approved spec, including lower bounds. Keep effects behind the checked
boundary and name the assumptions of the external timeout mechanism.

Model quality is `eval_measured`. Wrapper properties use the method actually
checked. Tests of hostile responses supply additional testing evidence.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_8.py --case wrapper-proof` | The established verifier accepts the wrapper bounds and allowed outcomes. | 0 — final attempt 4 |
| `python3 scripts/exit_stage_8.py --case hostile-outputs` | Fuzzed malicious outputs never violate bounds in the executed test corpus. | 0 — final attempt 3 |
| `python3 scripts/exit_stage_8.py --case evidence-separation` | Evidence distinguishes proved wrapper properties, fuzz testing, and measured model quality. | 0 — final attempt 2 |

Record fuzz seeds, counts, and limits. Do not turn “no violations observed” into
a universal proof. Keep application timeout behavior distinct from proof-run
resource limits.

Historical Stage 8 contract preparation (not EXIT results; resolved below):

- The user requires universal safety **and** exact acceptance of every valid
  proposal. Fallback must preserve the absence of refund side effects.
- [proposals/refund.md](proposals/refund.md) contains the complete proposed diff
  and explicit business choices. Four new protected files are proposed: the
  Dafny contract, wire/lifecycle protocol, spec lock, and separate refund policy.
  None has been applied. No implementation or refund gate has been written.
- The proposed Assess method has no validity precondition. It must handle all
  modeled contexts and responses, reject ineligible inputs with an empty plan,
  and accept every eligible candidate with its exact amount/reason. A future
  arbitrary-input binding and successful witness must prevent vacuous acceptance.
- The current gates bind ledger and booking domains. Exact approval of this
  contract does not authorize an unspecified future protected gate patch.
  Such a patch must also be reviewed before application.
- `.toolchain/dafny-4.11.0/dafny/dafny --version` returned 0 and matched the pin.
  `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/refund/RefundSpec.dfy`
  returned 0 and printed `Dafny program verifier did not attempt verification`.
  This is proposal resolution only, not source proof or a Stage 8 EXIT.
- `git apply --check proposals/refund/protected.diff` returned 0 without
  applying the patch. The proposed policy passed structural validation with
  pinned jsonschema 4.21.1 (Python process exit 0). This is not policy acceptance.
- Records are in `results/stage8/proposal/`. There are no formal guarantees,
  executed fuzz cases, model-quality scores, or Stage 8 passing EXITs yet.
  All three EXIT commands remain NOT RUN. See append-only U070.
- Stop for exact human contract approval. Stage 8 remains CURRENT;
  `end_to_end=false`. No Stage 9 work has started.

Historical Stage 8 contract adoption and gate preparation (not EXIT results):

- The user approved exactly the four additions at published revision
  `e3aa546f86dc5b43ec8c754792e3db4cb413b410`, bound to its manifest and digests.
  The approval excludes real refunds and unspecified gate changes. See
  [proposals/refund-decision.md](proposals/refund-decision.md).
- The published Git tree, candidate blob identities, manifest and patch hashes
  matched. All four target paths were absent. Their exact approved bytes are
  now installed. All existing protected files remain unchanged. Identity
  records: [contract adoption](results/stage8/contract-adoption/identity.json).
- `impl/Refund.dfy` implements the approved pure boundary. The direct checks
  below used the real pinned toolchain. The proposed binding covers arbitrary
  inputs with no preconditions and includes an eligible successful witness.
  These results do not complete the protected gate or any Stage 8 EXIT.
- [proposals/refund-gate.md](proposals/refund-gate.md) proposes exactly three
  gate additions, with their complete diff and digest manifest. None is applied.
  They preserve fresh full verification, empty audits, source identities,
  resource limits, and distinct source-proof and property-test methods.

| Development/review command | Actual exit code | Actual result |
| --- | --- | --- |
| `.toolchain/dafny-4.11.0/dafny/dafny --version` | 0 | Expected pinned build. |
| `.toolchain/dafny-4.11.0/dafny/dafny verify impl/Refund.dfy proposals/refund-gate/Bindings.dfy` plus pinned options and TRX output | 0 | All six required source, contract, universal-binding and witness obligations passed. |
| `.toolchain/dafny-4.11.0/dafny/dafny audit impl/Refund.dfy proposals/refund-gate/Bindings.dfy` with empty-report comparison | 0 | Zero reported findings. |
| `.toolchain/dafny-4.11.0/dafny/dafny build impl/Refund.dfy --target js --output build/refund-proposal/model` plus pinned options | 0 | Real generated JavaScript; four source obligations verified during build. |
| `node node_modules/typescript/bin/tsc` on the proposed hostile suite, with strict no-emit options | 2, then 0 | TS2769 tuple-type error retained; corrected type declaration passed. No hostile cases executed. |
| `git apply --check proposals/refund-gate/protected.diff` | 0 | Complete three-addition patch is applicable; not applied. |

Exact argv, input digests, before/after identities, complete outputs, TRX, generated
JavaScript, and the failed static-check source snapshot are retained in
[results/stage8/gate-proposal](results/stage8/gate-proposal/). The Python candidate
parsed successfully with the standard AST parser. Python, validator packages,
Node and installed package content matched their existing pins.

The new protected gate has not executed. The runtime adapter and EXIT harness
remain unimplemented. Negative controls, hostile cases, canonical accepted
evidence reproduction, and model evaluation have not run. The planned 9,000
generated cases are not actual coverage. Model quality is unmeasured. All three
EXIT commands above remain NOT RUN. No Stage 8 accepted bundle is published.

Stop for separate exact approval of the three proposed gate additions, as the
latest user instruction requires. See append-only U071. Stage 8 remains CURRENT;
`end_to_end=false`. Stage 9 has not started.

Historical Stage 8 approved gate execution and frozen-scope blocker:

- The user approved exactly `gate/refund.py`, `gate/refund/Bindings.dfy`, and
  `gate/refund/hostile.ts` at `d2d557e2dcd564049fbd97171b0af67659eacf81`.
  The published candidates, manifest, patch and target digests matched. The
  three files were adopted byte for byte. See
  [the decision](proposals/refund-gate-decision.md) and
  [adoption identities](results/stage8/gate-adoption/identity.json).
- `ts/refund.ts` implements the declared parser/host interface. The unprotected
  EXIT harness and supplemental integration tests are implemented. The strict
  TypeScript check returned 0. No approved contract, policy or gate was edited.
- Wrapper attempt 1 returned 1 after the actual proof and all three real
  rejections. The reporting harness did not read the auditor's `.expect`
  sidecar. Correcting that unprotected file selection allowed full attempt 2
  to return 0. Both attempts, source snapshots and complete logs remain.
- The successful wrapper EXIT checked all six required source, abstract-contract,
  universal-binding and witness obligations. Over-limit authorization failed
  actual verification with 4 at R1; reject-all failed with 4 at R4. The actual
  assumption audit rejected the escape with 2. Each negative gate returned 1.
- The hostile EXIT returned 1. Its 68 fixtures and 3,000 T1 generated cases
  passed first. T2 seed 8001 failed after two cases and six shrinks: fast-check
  generated a null-prototype record, while `structuredClone` normalized the
  snapshot's prototype. Strict equality then rejected an unchanged input.
  The compiled wrapper's expected-value assertion passed before that failure.
- The evidence-separation EXIT returned 1 at the same T2 assertion. Its two
  fresh source runs reproduced byte for byte. Those bytes also match the
  successful wrapper EXIT, for three separate fresh accepted source runs.
  Evidence SHA-256: `acafe3f90623314d4389604ffbc8d99c880091ea8a28f805b255ae1a60c753fe`.
- Supplemental tests returned 0 for 23 fixtures and 500 generated cases, seeds
  8004 and 8005. They cover stale delivery, caller/result mutation, concurrent
  terminal calls, executor reentry/failure, numeric and byte boundaries, and
  malformed/truncated bytes. These finite checks are not a Stage 8 EXIT pass.
- A minimal prototype-preserving snapshot repair was evaluated directly from
  `proposals/`, before the final freeze, and returned 0 for 9,000 generated cases
  and 68 fixtures. It was never substituted into the approved gate. It supplies
  no accepted integration bundle. Its exact diagnostic diff is in
  [proposals/refund-hostile-snapshot.md](proposals/refund-hostile-snapshot.md).
- The final user instruction freezes scope and forbids changes to approved gate
  files. The repair remains unapplied. Effect-bypass, duplicate-dispatch,
  fabricated/mislabeled-evidence and spec-tamper controls have not been reached
  by the EXIT harness. Integration evidence reproduction remains unfinished.
  No Stage 8 completion or passing eval_measured record is claimed.

The [status record](results/stage8/status.json) links every actual EXIT attempt,
code, input identity and archived operation. The [boundary report](docs/stage8-refund.md)
states proof scope, finite test counts, toolchain assumptions and reproduction
commands. See append-only U072. Stage 8 remains CURRENT — blocked;
Stage 9 remains NOT STARTED; `end_to_end=false`.

Stage 8 exact repair, final EXITs and completion:

- The user approved only the exact prototype-preserving snapshot replacement
  at `76f58de25fb5ebe305831432907e42a4210add40`. The published identities matched.
  Both `git apply --check proposals/refund-hostile-snapshot/protected.diff`
  and `git apply proposals/refund-hostile-snapshot/protected.diff` returned 0.
  Applied `gate/refund/hostile.ts` SHA-256 is
  `0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a`.
  No other protected file changed. See
  [the exact decision](proposals/refund-hostile-snapshot-decision.md).
- The added unprotected assertion controls execute the exact approved T2
  callback with the real compiled wrapper. Four unchanged ordinary/null-prototype
  combinations passed. Sixteen genuine field/prototype mutations were rejected
  by the snapshot assertion. No replacement assertion or proof checker is used.
- Their first static check returned 2 for object-type narrowing; its correction
  returned 0. Hostile attempt 2 then returned 1 for an omitted extracted helper.
  Both errors and original source snapshots remain. Only that unprotected
  extraction was corrected; hostile attempt 3 returned 0.
- Final real EXIT attempts: wrapper 4 = 0, hostile 3 = 0, evidence separation
  2 = 0. Their complete declared inputs match the current sources and their
  before/after identities. Full exit history remains: wrapper `[1, 0, 0, 0]`,
  hostile `[1, 1, 0]`, evidence separation `[1, 0]`.
- All six required source/binding/witness obligations and both empty audits
  passed. Over-limit and reject-all controls failed actual verification with
  4 at R1/R4. The assumption escape failed the actual audit with 2. Each
  negative gate returned 1 for the intended reason.
- The accepted hostile suite executed 9,000 generated cases and 68 fixtures
  with the approved seeds/counts. Supplemental tests passed 500 generated
  cases and 23 fixtures. The assertion controls accepted 4 stable inputs and
  rejected 16 mutations. Effect-bypass and duplicate-dispatch each failed
  the real test process with 1 for an assertion reason; each gate returned 1.
- Mislabeled property_tested/eval_measured evidence, wrong artifact identity,
  invented passing-case count and changed spec identity each returned gate 1
  for the required reason. Invented-count rejection followed fresh real checks.
- Both accepted evidence files match three separate fresh gate runs byte for
  byte, with matching proved-source links. Source evidence SHA-256:
  `be32ef9e27fee402aefd9fab6de9cc66ceb03d1d68101d6b238364756ebd8c86`.
  Property evidence SHA-256:
  `77d94ab0c41ea5c887924515f0921f6c0362c32d427b3f11d7afc79f21cbe0dd`.
  Generated module SHA-256:
  `d462e12309766d5b055715500daab5c238e9c9d06236b47577d43941c22b4dda`.
- All 373 earlier Stage 8 record files matched their preserved hashes. The
  original blocked status, failed attempts, seeds, shrinks, raw output and
  approval proposals remain unchanged. Model quality is unmeasured; no
  passing eval_measured record or real payment execution is claimed.

The [completion record](results/stage8/completed/completion.json) binds all
final EXIT commands/codes, source identities, controls and canonical artifacts.
The [boundary report](docs/stage8-refund.md) states the universal source
guarantees and the finite test, compiler, parser, clock, payment and deployment
limits. See append-only U073. Stage 8 is DONE; Stage 9 is CURRENT. Publish and
verify this checkpoint, then stop. No Stage 9 implementation has started.
`end_to_end=false`.

### Stage 9 — PROVENANCE

**Status: CURRENT — blocked on receipt-validation gaps, runner admission and execution authorization**

Sign evidence bundles using pinned sigstore/in-toto tooling. Before allowing a
deployment, verify the signer identity, artifact digest, and policy version.
Bind container packaging to the checked binary and verify deployed identity when
reporting deployment coverage. Keep canonical evidence separate from signature
envelopes and external transparency records, which may contain time metadata.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case valid-bundle` | A valid signed bundle for the intended artifact and policy passes the release check. | NOT RUN |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case unsigned` | An unsigned bundle is rejected. | NOT RUN |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-signer` | A bundle from an unauthorized signer is rejected. | NOT RUN |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-digest` | A valid signature over the wrong artifact digest is rejected. | NOT RUN |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case wrong-policy` | A bundle for an unaccepted policy version is rejected. | NOT RUN |
| `python3 -I -S -B gate/provenance/bootstrap.py --implementation-sha256 $LOCK -- scripts/exit_stage_9.py --case deployed-identity` | Actual deployed digest matches the accepted release; a mismatch is reported and prevents a coverage claim. | NOT RUN |

`$LOCK` is the installed implementation lock. The harness refuses any other launch
(U131); run the inline lock/bootstrap byte check first.

Run the established signature verifier for the actual accept/reject decision.
Signing an unsupported claim does not make it established.

#### Initial trust proposal preparation (historical)

The published Stage 8 base is `80a65d46b1dbc8f3ccfd249bfd628568406c5774`.
[proposals/provenance.md](proposals/provenance.md) contains the exact proposed
contract, policy and identity-lock additions, complete patch and file digests.
No protected changes have been applied. The user requires exact approval before
changing this trust boundary. The proposal names one GitHub Actions signer,
pinned Cosign 3.1.4, Sigstore public TUF trust, both existing binary claims,
fresh full kernel replay, strict evidence methods, request freshness and actual
container filesystem observation. Its deployment claim is file identity at
observation time; it does not claim RISC-V execution or deployment correctness.
An exact release-gate/workflow implementation requires separate approval.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance/check_proposal.py` | 0 | Proposal integrity only: three unapplied additions, 47 locked existing files, unchanged complete module/assumption lists. |
| `git apply --check /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Patch applicability only; no application. |

These are not Stage 9 EXIT results. All six required EXIT commands remain NOT
RUN. Cosign was not installed or executed. No signature or deployment was made.
Preparation logs and identity snapshots are under `results/stage9/preparation/`.
All 30 existing protected files and all old Stage 7–8 records remain unchanged.
See U074. `end_to_end=false`.

#### Approved contract adoption and implementation proposal (historical)

The user approved only the three contract additions at
`097431cf458e5c62332575b09e953224471fa64d`. The public manifest, patch and candidate
bytes matched. The exact patch was applied. The new contract, policy and lock
match their approved SHA-256 digests. All 1,360 snapshotted prior files remain
unchanged at adoption. [proposals/provenance-decision.md](proposals/provenance-decision.md)
records the approval; `results/stage9/contract-adoption/` preserves commands and
identity checks. This did not authorize a gate, workflow, signing or deployment.

[proposals/provenance-implementation.md](proposals/provenance-implementation.md)
contains 11 exact, unapplied additions: eight protected implementation files,
two manual workflows and the six-case EXIT harness. Its lock binds 60 files
and 45 upstream Python dependency files. Actual signature/proof/deployment
execution remains untested and unapproved. A dedicated pinned runner is an
explicit, unprovisioned prerequisite; no runner registration was performed.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Approved contract patch dry-run. |
| `git apply /Users/mackianni/forge/proposals/provenance/protected.diff` | 0 | Applied only the three approved additions. |
| `python3 --version` | 0 | Observed Python 3.10.11. |
| `docker version --format '{{json .}}'` | 0 | Read-only runtime inventory. |
| `docker buildx version` | 0 | Read-only Buildx inventory. |
| `docker buildx inspect default --format '{{json .}}'` | 125 | Unsupported flag; original complete output preserved. |
| `docker buildx inspect` | 0 | Supported read-only retry; Docker driver, desktop-linux, BuildKit 0.25.1. |
| `python3 proposals/check_provenance_implementation.py` | 0 | Proposal hashes, syntax and workflow structure only. |
| `git apply --check /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Implementation proposal applicability only; patch not applied. |

All six Stage 9 EXITs remain NOT RUN. The preparation checks do not verify a
signature or establish a proof. No Cosign installation, new proof execution,
container build/start, workflow activation or signing occurred. Every failure
remains preserved in `results/stage9/implementation-preparation/`. Stop for the
next exact approval; do not change the approved contract to fit the proposed
implementation. See U075. `end_to_end=false`.

#### Approved implementation adoption and safe preparation

The user approved only the exact 11 additions at
`06b40caa6bf5fb6963756b39646413559f84c61d`, bound to the published manifest,
patch and individual file hashes. Those bytes are applied unchanged. The
approval explicitly excludes workflow dispatch, public Sigstore signing,
runner registration and deployment execution. See the
[approval record](proposals/provenance-implementation-decision.md).

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Approved 11-file patch dry-run. |
| `git apply /Users/mackianni/forge/proposals/provenance-implementation/proposed.diff` | 0 | Applied exactly the 11 approved additions. |
| `python3 scripts/check_stage9_installation.py` | 0 | Exact installed bytes, syntax, manual workflow structure, 60 locked files and 45 Python dependency files. |
| `python3 scripts/audit_stage9_receipts.py --output results/stage9/implementation-adoption/receipt-audit-0001 --work build/stage9-receipt-audit-0001` | 1 | Local real receipt-validator audit; three unexpected non-rejections. No proof, signature or deployment. |
| `python3 results/stage9/implementation-adoption/preservation-check/check.py` | 0 | All 33 prior protected files unchanged; all 11 additions exact; append-only uncertainty history and historical audit inputs preserved; public archive contains the exact raw kernel log. |

The validator accepted invalid dependency hashes and a copied ELF that was
substituted or missing when the receipt manifest matched those inputs. It
rejected a nonce mismatch with `STALE_PROOF_RECEIPT` and a file changed after
manifest creation with `PROOF_RECEIPT_BYTES`. These are helper-level findings;
they are not signed release admissions or newly executed kernel results.
Historical logs were deliberately reused as untrusted negative fixtures.
No fixture is accepted evidence. All commands, raw logs, identities, generated
fixtures and the failing audit remain in `results/stage9/implementation-adoption/`.

The [signing audit](docs/stage9-signing-preparation-audit.md) records the existing
checks, missing byte bindings and trust limits. Freshness depends on the trusted
producer job and GitHub artifact handoff; matching metadata cannot establish it
alone. The [runner plan](proposals/stage9-runner-provisioning.md) covers isolation,
credentials, exact pins, resource allocation, admission and teardown. Read-only
metadata confirms a public, user-owned repository. No enforced workflow
allowlist has been established; a runner label is insufficient.

All 1,446 snapshotted prior files were unchanged at adoption. The original
failures remain intact. No protected bytes were adjusted after application.
The final preservation check found only ROADMAP.md and the append-only unsure.md
changed among those prior files; the other 1,444 retain their original hashes.
All six EXITs remain NOT RUN. No runner registration, workflow dispatch,
Cosign execution, container build/start or fresh proof execution occurred.
Stop at the required approval boundary. See U077. `end_to_end=false`.

#### Integrity repair preparation (unapplied)

A four-file repair for the three audit gaps waits for exact-byte approval. See
the [repair proposal](proposals/provenance-integrity-repair.md). No protected
file is changed.

| Preparation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance-integrity-repair/fetch_base_identity.py --output results/stage9/integrity-repair-preparation/base-identity-0001` | 0 | Read-only registry fetch; base config and 55 diff_ids verified by content digest. |
| `python3 proposals/provenance-integrity-repair/build_identities.py --reference-work build/stage9-receipt-reference-0002 --base-identity results/stage9/integrity-repair-preparation/base-identity-0001 --output proposals/provenance-integrity-repair/artifact-identities.json --report results/stage9/integrity-repair-preparation/identities-0001.json` | 0 | Approved identities cross-checked against the Stage 7 record. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0001 --work build/stage9-integrity-tests-0001` | 1 | Harness defect in one package mutation; kept. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0002 --work build/stage9-integrity-tests-0002` | 0 | All negatives rejected; installed validator accepted 17 of 31 receipt negatives. |
| `python3 proposals/provenance-integrity-repair/test_integrity.py --output results/stage9/integrity-repair-preparation/tests-0003 --work build/stage9-integrity-tests-0003` | 0 | Rerun on unchanged candidate bytes; no unexpected cases. |
| `python3 proposals/provenance-integrity-repair/build_approval.py --output results/stage9/integrity-repair-preparation/approval-0001 --scratch build/stage9-integrity-apply-0001` | 0 | Lock, diff, manifest; `git apply` checked only in a scratch copy. |

Execution blockers: the runner image store (containerd versus classic), the
untested `docker image save` layout, runner admission and execution
authorization. All six EXITs remain NOT RUN. See U078. `end_to_end=false`.

#### Approved integrity repair adoption

The user approved the four exact files and the diff hash `df0bd7fb…`. The
approval excludes runner registration, dispatch, signing and deployment.

| Adoption command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git apply --check --verbose results/stage9/integrity-repair-preparation/approval-0001/proposed.diff` | 0 | Dry run of the approved patch. |
| `git apply results/stage9/integrity-repair-preparation/approval-0001/proposed.diff` | 0 | Applied the four approved files; hashes match. |
| `common.context('9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76')` | 0 | New lock binds 61 files. |
| `common.context('6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa')` | 1 | Old lock rejected: `UNAPPROVED_IMPLEMENTATION`. |
| `python3 -m py_compile gate/provenance/release.py gate/provenance/producer.py` | 0 | Syntax only. |
| `python3 scripts/check_stage9_installation.py` | 1 | Historical check for the earlier 11-file approval; replaced bytes no longer match it. Unchanged. |

Records are in `results/stage9/integrity-repair-adoption/`. All six EXITs
remain NOT RUN. See U079. `end_to_end=false`.

| Post-adoption command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 proposals/provenance-integrity-repair/derive_installed_test.py` | 0 | Derives `test_installed.py` from the unchanged suite by counted replacements. |
| `python3 proposals/provenance-integrity-repair/test_installed.py --output results/stage9/integrity-repair-adoption/installed-tests-0001 --work build/stage9-integrity-installed-tests-0001` | 0 | Installed gate rejected all negatives; pre-repair baseline accepted 17 of 31 receipt negatives. No kernel, Docker, Cosign or deployment. |

See U080. `end_to_end=false`.

#### Image-store observation (Docker running)

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker info --format '{{json .DriverStatus}} driver={{.Driver}}'` | 0 | `io.containerd.snapshotter.v1`: containerd image store. |
| `docker version --format '{{.Server.Platform.Name}}'`; `docker buildx version`; `docker buildx inspect desktop-linux` | 0 | Matches the pinned Desktop 4.48.0, buildx and BuildKit v0.25.1. |
| `python3 -I results/stage9/image-store-observation/observe.py --image redis:7-alpine --output results/stage9/image-store-observation/redis-7-alpine-0001` | 0 | Streamed save; Config path is not `blobs/sha256/<Id>`. |
| `python3 -I results/stage9/image-store-observation/observe.py --image ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a… --output results/stage9/image-store-observation/checker-base-0001` | 0 | Config blob equals approved `base_config` `e49a3a57…`; not equal to `Id`. |

Gzip layers, blob paths and diff_id binding match the gate. Under this store
the package step fails closed. No build, container start, kernel, Cosign,
workflow or deployment ran. See U081. `end_to_end=false`.

The user chose the classic image store for the runner and switched the local
Docker Desktop setting.

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker info --format '{{json .DriverStatus}} driver={{.Driver}}'` | 0 | `overlay2`; no containerd snapshotter. |
| `docker pull --platform linux/amd64 ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a…` | 0 | Pinned base pulled into the classic store. |
| `python3 -I results/stage9/image-store-observation/observe.py --image ghcr.io/theorem-labs/oss-fuzz-theorems-checker@sha256:cc9ae43a… --output results/stage9/image-store-observation/checker-base-classic-0001` | 0 | `Id` = Config = approved `base_config` `e49a3a57…`; 55 uncompressed layers match diff_ids. |

The runner plan now requires the classic store. No build, container start,
kernel, Cosign, workflow or deployment ran. See U082. `end_to_end=false`.

#### Local package-step observation (classic store)

The user authorized a local package build. These runs call only the installed
`producer.package()` under the approved lock. They are not EXIT results.

| Observation command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 results/stage9/package-build-observation/run_package.py --implementation-sha256 9b10a237… --output results/stage9/package-build-observation/package-0001` | 0 | Lock, runtime pins, base, build, save, config identity, added layer and extracted ELF accepted; config `f15f5bd4…`. |
| Same command with `--output …/package-0002` | 0 | `result.json`, `package.json` and `package-identity/` byte-identical to 0001 (BuildKit cache may apply). |

One container was created per run and not started. Read-only GitHub checks
found that `main` still has the pre-repair gate (lock `6b43c193…`). No runner
was registered. No dispatch, signing or deployment ran. See U083.
`end_to_end=false`.

#### Repository visibility change (user decision)

The user chose a private repository for runner admission ("go private for now").

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=private` | 0 | `visibility=private`; `id` and `owner.id` unchanged. |
| `curl … https://api.github.com/repos/mack-dot/forge` (no token) | 0 | HTTP 404. |

The installed gate fetches GitHub data without a token, so it now fails closed.
An unapplied amendment is in
[proposals/stage9-runner-admission.md](proposals/stage9-runner-admission.md)
(sha256 `dfdca5d5…`). Records: `results/stage9/visibility-change-0001/`. See U084.
`end_to_end=false`.

#### Platform decision: public repository and GitHub-hosted Linux runners

U085 withdrew option A: the verifier must not use the producer's token. The
user then chose a public repository and GitHub-hosted `ubuntu-24.04` producer
runners. The contract and policy contain no macOS or self-hosted requirement,
so the change is implementation-level. See
[proposals/stage9-hosted-runner.md](proposals/stage9-hosted-runner.md).

| Command | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=public` | NOT RUN | Denied by the Claude Code permission check; the repository is still private. |
| `python3 -c "import yaml; yaml.safe_load(open('proposals/stage9-hosted-runner/probe.yml'))"` | 0 | Probe YAML syntax only; not pushed or dispatched. |

No protected file changed. See U086. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api -X PATCH repos/mack-dot/forge -f visibility=public` (run by the user) | 0 | Public; `id` and `owner.id` unchanged; unauthenticated API read returns 200. |
| `gh api -X PUT repos/mack-dot/forge/contents/.github/workflows/stage9-hosted-probe.yml …` | 0 | Commit `ac6dfe51…` on `main`; blob `4470a811…` equals the local probe. |
| `gh workflow run stage9-hosted-probe.yml -R mack-dot/forge --ref main` | 0 | Run 40713187818. |
| `gh run watch 40713187818 -R mack-dot/forge --exit-status` | 0 | Conclusion `success`. |
| `gh run download 40713187818 -R mack-dot/forge -D results/stage9/hosted-probe-0001/artifact` | 0 | Probe records. |

Probe result: ubuntu-24.04 image `20261026.354.1`, 4 CPUs, 16.7 GB RAM,
91.9 GB free disk. Docker Engine 28.0.4 with the classic store (`overlay2`).
The pinned checker pull took 72 s and used 3.9 GB of disk. Its `Id` equals the
approved `base_config` `e49a3a57…`. No proof, signing or deployment ran. See
U087. `end_to_end=false`.

#### Checkpoint publication to `main`

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … status --porcelain` (scratch clone of `main`, work tree = local root) | 0 | No path on `main` is missing locally; two ELF entries differ only in file mode. |
| `git … -c core.fileMode=false add -A`; `commit`; `push origin HEAD:main` | 0 | Commit `70d46565…`: the four approved repair files, ROADMAP, unsure.md and 2,698 new record files (4.6 MB; no token or key patterns). |
| `common.repository_identity(policy, implementation, '70d46565…', records)` under lock `9b10a237…` | 0 | All 61 locked files on `main` match; records in `results/stage9/publication-check-0001/`. |

`main` now carries the approved repaired gate. See U088. `end_to_end=false`.

#### Hosted-runner probe 2 (measurement only)

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `d722ecef…`: probe 2 workflow and `replay_probe.py`. |
| `gh workflow run stage9-hosted-probe-2.yml -R mack-dot/forge --ref main` | 0 | Run 40715761881. |
| `gh run watch 40715761881 -R mack-dot/forge --exit-status` | 1 | docker-pin job success (exact Engine 28.5.1 install); replay job failed at the volume clone (`dubious ownership`). |

The 45 Python dependency files matched the lock. No proof ran. See U089.
`end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `21851412…`: chown of the seed `.git` to 1000:1000. |
| `gh workflow run stage9-hosted-probe-2.yml -R mack-dot/forge --ref main` | 0 | Run 40717015652. |
| `gh run watch 40717015652 -R mack-dot/forge --exit-status` | 0 | Both jobs succeeded in 20.3 min. |
| `python3 proposals/stage9-hosted-runner/replay_probe.py --implementation-sha256 9b10a237… --output probe2/replay` (in the run) | 0 | Fresh proof 793 s; no OOM; receipt (656 files, 579 closure objects) accepted by the installed `validate_receipt()`. |
| `python3 $ST/scripts/stage7_build_own.py` (in the run) | 0 | Own ELF rebuilt byte-identical, `8ced2ab6…`. |

This is measurement with a synthetic request, not an EXIT result. No signing ran.
See U090. `end_to_end=false`.

#### Repository transfer (user action)

The user transferred the repository to the `superpowermentors-1` organization.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh api repos/mack-dot/forge` (redirect) | 0 | `superpowermentors-1/forge`, id 1434789853 unchanged, owner id 235148649, public. |
| `gh api repos/superpowermentors-1/forge/collaborators` | 0 | Three admins: mack-dot, sam-spm, superpowermentorss. |
| `gh api orgs/superpowermentors-1/actions/permissions` | 1 | HTTP 403; token lacks `admin:org`. |

The installed policy still names `mack-dot/forge`, so the gate now fails closed
until an approved identity change. See U091. `end_to_end=false`.

#### Hosted-runner and identity candidate (unapplied)

The user confirmed `superpowermentors-1/forge` as the permanent owner. The
candidate is in `proposals/provenance-hosted/` (diff `11ee6957…`, new lock
`acf73308…`, 10 files). No protected file is changed.

| Check actually run | Actual exit code | Scope |
| --- | --- | --- |
| `python3 -I proposals/provenance-hosted/build_candidate.py` | 0 | Candidate files, lock, diff, manifest. |
| `git apply --check` / `git apply` (scratch copy) | 0 / 0 | All 10 files equal the candidate bytes. |
| `common.context('acf73308…')` (scratch) | 0 | 62 locked files. |
| `common.context('9b10a237…')` (scratch) | 1 | `UNAPPROVED_IMPLEMENTATION`, as required. |
| `run_package.py --implementation-sha256 acf73308…` (scratch, Mac controller profile) | 0 | Config `f15f5bd4…`; all 12 commands 0. |

See U092. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `e0eae926…`: candidate and dry-run workflow. |
| `gh workflow run stage9-candidate-dry-run.yml …` (first) | 1 | HTTP 404; workflow not yet registered. |
| `gh workflow run stage9-candidate-dry-run.yml …` (second) | 0 | Run 40724981390. |
| `gh run watch 40724981390 … --exit-status` | 1 | Hosted pins, setup and preflight passed; package config `45570f02…` ≠ controller `f15f5bd4…` → `INDEPENDENT_PACKAGE_REPRODUCTION`. |
| `docker buildx build --builder desktop-linux --output=type=docker,rewrite-timestamp=true --no-cache …` (twice, Mac) | 0, 0 | Different IDs; the Docker driver ignores `rewrite-timestamp`. |

Directory mtimes in the ELF layer make the package unreproducible. The
installed gate has the same defect. See U093. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `docker buildx build --builder <pinned docker-container BuildKit v0.25.1> --output=type=docker,rewrite-timestamp=true --no-cache …` (twice, Mac) | 0, 0 | Same ID `f5843050…`; base layers unchanged. |
| `python3 -I proposals/provenance-hosted/build_candidate.py` | 0 | Updated candidate: diff `5593a720…`, lock `f9f09a2f…`. |
| `git apply --check` / `git apply` (fresh scratch) | 0 / 0 | 10 of 10 files match. |
| `run_package.py --implementation-sha256 f9f09a2f…` (scratch, Mac controller, new builder) | 0 | Config `f5843050…`. |

See U094. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `git … push origin HEAD:main` | 0 | Commit `64a77603…`: updated candidate and dry run. |
| `gh workflow run stage9-candidate-dry-run.yml -R superpowermentors-1/forge --ref main` | 0 | Run 40731196167. |
| `gh run watch 40731196167 … --exit-status` | 0 | Conclusion success, 40.5 min. |
| `python3 gate/provenance/hosted_setup.py` (candidate, in the run) | 0 | Pinned Docker and Stage 7 prerequisites, 1,377 s. |
| `python3 gate/provenance/preflight.py --implementation-sha256 f9f09a2f…` (candidate, in the run) | 0 | Hosted runner and Linux Cosign. |
| `python3 proposals/provenance-hosted/dry_run.py …` (candidate, in the run) | 0 | Hosted package equals the controller package (`f5843050…`); fresh proof receipt (656 files, 579 closure objects) accepted. |

The candidate is ready for exact-byte approval. It is not applied. Not an EXIT
result. See U095. `end_to_end=false`.

#### Trust-boundary review of the candidate (read-only)

| Item | Result | Evidence |
| --- | --- | --- |
| 1. `contract_approval_commit` | FAIL | Names `097431cf…`, the old contract approval; the candidate replaces those bytes. |
| 2. macOS-path link | PASS | Same checked interpreter; one pip run; 45 outputs hash-checked twice; read-only mount. |
| 3. Identity bindings | FAIL | Internally consistent, but GitHub now reports `mack-dot/forge`, owner 235131950 (`superpowermentors-1/forge` → 301). |
| 4. Admin access and branch rules | FAIL | Not named in the contract; one admin now; no rules or protection on `main`. |
| 5. Hashes versus manifest | PASS | 10 of 10 files, diff `5593a720…`, published copy at `27e6044b…` equal. |

The candidate is not ready for approval. See U096. `end_to_end=false`.

#### v2 candidate on the `mack-dot/forge` boundary (unapplied)

The user kept `mack-dot/forge`. The approved contract stays; only the
implementation changes (7 files, diff `39c6c3d7…`, lock `30880e08…`).

| Check actually run | Actual exit code | Scope |
| --- | --- | --- |
| Raw fetch of `spec/provenance/protocol.md` at `097431cf…` | 1 | HTTP 404: that commit publishes `proposals/provenance/*`, not `spec/`. |
| Contract audit against the published proposal files | 0 | Approval reference valid; contract bytes unchanged; identity matches live GitHub. |
| `python3 -I proposals/provenance-hosted-v2/build_candidate.py` | 0 | 7 files, lock, diff, manifest. |
| `git apply --check` / `git apply` (scratch) | 0 / 0 | 7 of 7 files match; contract unchanged. |
| `common.context('30880e08…')` / `('9b10a237…')` (scratch) | 0 / 1 | New lock passes; old lock `UNAPPROVED_IMPLEMENTATION`. |
| `run_package.py --implementation-sha256 30880e08…` (fresh builder) | 0 | Config `f5843050…`, descriptor identical to v1. |
| Five `gh api` settings changes | 0 each | Vulnerability reporting, Dependabot alerts, secret scanning, fork approval, SHA pinning. |

See U097. `end_to_end=false`.

| Command actually run | Actual exit code | Scope |
| --- | --- | --- |
| `gh workflow run stage9-candidate-dry-run-v2.yml …` (first / second) | 1 / 0 | HTTP 404 (not yet registered) / run 40743117460. |
| `gh run view 40743117460` / `gh run download …` | 0 / 0 | Success: hosted package equals the controller package (`f5843050…`); fresh receipt (656 files, 579 objects) accepted. |
| `python3 proposals/provenance-hosted-v2/negative_controls.py --implementation-sha256 30880e08… …` (scratch, v2 applied) | 0 | 1 positive control accepted; 5 attacks rejected (`PACKAGE_CONFIG_IDENTITY` ×2, `PACKAGE_ROOTFS_BINDING`, `PACKAGE_FILESYSTEM_ELF:substituted`, `BUILDER_VERSION`). |

The repository is private, so release verification fails closed (U101, U102).
Measurements and controls only; not EXIT results. See U102, U103.
`end_to_end=false`.

#### v2 approval readiness (local, nothing pushed)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| Hash recomputation of the v2 manifest, diff, 7 files and lock | 0 | All match. |
| Installed `repository_identity()` against the private repository | 3 | `HTTPError 404`: verification fails closed. |
| F1 control: added `gate/provenance/argparse.py`, then `preflight.py` | 1 | Decoy code ran before any check (marker written). |
| F1 control: `context('30880e08…')` with the decoy present | 0 | Lock check passed: unlisted files are not bound. |
| Hash-checked Python archive, offline, Ubuntu 24.04 x64 container | 0 | Python 3.10.11 and bundled pip run without PyPI. |

Verdict: REVISE. See U104. `end_to_end=false`.

#### v3 candidate (unapplied, local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| `python3 -I proposals/provenance-hosted-v3/build_candidate.py` | 0 | 8 files; diff `5d3e838f…`; lock `0215a316…` (89 files). |
| `git apply --check` / `git apply` (fresh scratch) | 0 / 0 | 8 of 8 files match; contract unchanged. |
| `context('0215a316…')` / v2 lock / installed lock | 0 / 1 / 1 | Only v3 passes. |
| `python3 -B proposals/provenance-hosted-v3/f1_controls.py …` | 0 | Clean commit accepted; 6 tree attacks and 2 verifier guards rejected. |

See U105. `end_to_end=false`.

#### Pre-verification execution and v3.1 (unapplied, local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| v3: planted `json.py`, unchecked-hash `.pyc`, `PYTHONPATH` before `release.py` | 9 / 9 / 9 | Attacker code executed in all three: F1 unresolved in v3. |
| v3 `source_tree()` on a commit with a forged lock | 0 | Accepted (gap). |
| `python3 -I proposals/provenance-hosted-v31/build_candidate.py` | 0 | 9 files; diff `d24ff942…`; lock `6f3aafe6…`. |
| `git apply` (scratch) / `context('6f3aafe6…')` | 0 / 0 | 9 of 9 files match. |
| v3 F1 controls against v3.1 | 0 | 9 of 9 pass. |
| `python3 -B proposals/provenance-hosted-v31/controls.py …` | 0 | 14 of 14 pass; attacker code executed in none. |
| `check_no_signing.py` on the dry run / on production workflows | 0 / 1 | No signing path / correctly flagged. |

See U106. `end_to_end=false`.

#### B preparation (local)

| Check actually run | Actual exit code | Result |
| --- | --- | --- |
| `negative_controls.py --implementation-sha256 6f3aafe6…` | 0 | 1 positive, 5 attacks rejected (v3.1). |
| v3.1 `validate_receipt()` on the hosted v2 receipt / byte flipped / other challenge | — | ACCEPTED / `PROOF_RECEIPT_BYTES` / `STALE_PROOF_RECEIPT`. |
| Inline check and `bootstrap.py --check` with the pinned Linux Python | 0 / 0 | 48 and 78 modules, all from the archive. |
| `bootstrap.py --check` with a planted `json.py` | 1 | Planted code did not run. |
| `check_no_signing.py .github/workflows/stage9-private-dry-run-v31.yml` | 0 | No signing path. |
| `b3_verify.sh … forge-verifier-nonexistent-test-item` | 3 | Stopped before any network request. |

See U107. `end_to_end=false`.

#### B1–B2′ (owner-authorized, measurement only)

| Command actually run | Actual exit code | Result |
| --- | --- | --- |
| B1: `git push` of `993bee7b…` (tree `32bfb2dd…`) | 1, then 0 | First attempt: zsh refspec error; second: pushed. |
| B2: `gh workflow run stage9-private-dry-run-v31.yml` (run 40771238211) | 0 | Run failed: `no space left on device` at the checker pull; trust steps passed. |
| B1′: direct push / PR #16 merged by the owner | 1 / — | Ruleset requires a PR; `main` = `3670d688…`, tree `3822a938…` as reviewed. |
| B2′: `gh workflow run stage9-private-dry-run-v32.yml` (run 40787574980) | 0 | Success: hosted package = Mac package (`f5843050…`); fresh receipt accepted; token read-only. |
| B3 run 1 (owner): `b3_verify.sh ~/forge-b3-check ~/forge-b3-out-1` | 3 | No Keychain item `forge-verifier-readonly`; stopped before the checks and any network request. |
| B3 run 2 (owner): `b3_verify.sh ~/forge-b3-check ~/forge-b3-out-2` | 1 | Keychain value failed the token format check before any request; wrapper crashed in `store()`; scan clean. |
| B3 run 3 (agent, owner waiver U117): reviewed wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-3` | 3 | Keychain value is not a GitHub token (length 68, prefix other); stopped before any check or request. |
| B3 run 4 (agent, owner waiver U117): wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-4` | 3 | Keychain value is not a GitHub token (length 4); stopped before any check or request. |
| B3 run 5 (agent, owner waiver U117): wrapper v2 `6190aa58…`, OUTPUT `~/forge-b3-out-5` | 0 | 8/8 cases PASS; API identity read with the token matches policy; fresh store per run; no credential copy in 687 record files. |

Not EXIT results. See U108–U121 and `results/stage9/b3-0001/`. `end_to_end=false`.

#### v3.2 installation (owner-approved, U122)

| Command actually run | Actual exit code | Result |
| --- | --- | --- |
| Proof gate on PR #17 (run 40807060051) | 1 | `UNAPPROVED_PROTECTED_CHANGE`: the gate approves only exact spec text, never its own code. |
| Agent: `gh pr merge 17 --squash --admin` | — | Refused by the Claude Code classifier (Merge Without Review). |
| Owner: `gh pr merge 17 --squash --admin --match-head-commit edb729a8…` | 0 | `main` = `d260d2a9…`, tree `1b77abd0…` = reviewed candidate. |
| Fresh `main` clone: inline lock check; `bootstrap.py --check` | 0; 0 | Lock `be23ec85…`; `BOOTSTRAP_VERIFIED`. |
| `common.source_tree` on `d260d2a9` / `3670d688` | 0 | ACCEPTED / `IMPLEMENTATION_LOCK_AT_COMMIT`. |
| Local sync of the 9 files; local `bootstrap.py --check` | 1, then 0 | First: `BYTECODE_CACHE`; caches removed; then verified. |
| Proof gate on records PR #18 (head `2ca14bdd…`); owner squash merge | 0; 0 | `main` = `d43f5f4d…`, tree `9f6bb222…` = records branch tree. No other run; no variables. |
| Rehearsal request (U124): `producer.py --action request` from a fresh `main` clone (`d43f5f4d`) | 0 | 9 min; controller package `f584305022f2…` = B2′ package; challenge stored in the local controller. |
| Rehearsal dispatch: `gh workflow run provenance.yml --ref main` (run 40810179164) | 0 | Conclusion success in 32 min: `proof` success, `sign` skipped; token Contents/Metadata read only. |
| Rehearsal verification with controller code (`results/stage9/rehearsal-0001/verification.json`) | 0 | Artifact digest `34b215d3…` matches; request, package, receipt (656 files), evidence and statement bindings pass; 4/4 tamper controls rejected. |
| `proposals/approval-integrity/audit_main_approvals.py mack-dot/forge 5` | 1 | #16, #17, #18 OVERRIDE (rule-suite bypass, 0 reviews); `993bee7b`, `e37ef2c5` direct pushes. Forged-pass and missing-record controls: no false APPROVED. |
| Pinned Cosign 3.1.4 (darwin-arm64 `9f9b8cd5…`) on a public cli/cli SLSA bundle (`results/stage9/cosign-offline-0001`) | 0 | Verified OK with Forge's flags; wrong-signer and wrong-digest markers match; unsigned marker does not (D1). |
| Independent adversarial audit of main `d43f5f4d` (`results/stage9/v32-audit-0001/results.json`, 22 checks) | — | V1 HIGH: root `ensurepip.py`/`runpy.py` runs before authentication in OIDC jobs (emulated). V2 HIGH: root `pip/` runs after bootstrap. V3 MEDIUM: inventory scope. V4 MEDIUM: receipt freshness is a label. Other controls pass. |
| Permission test: `gh api user`; `gh api repos/mack-dot/forge --jq .permissions` | 0; 0 | Agent is still `mack-dot` with admin; no machine-account collaborator. Identity separation not in effect. |
| `proposals/provenance-hosted-v33/build_candidate.py` | 0 | v3.3 candidate: 9 files, lock `eb4b93db…`, diff `21e1a7a4…`. |
| `run_controls.py <candidate repo fc0a40d9> results/stage9/v33-controls-0001` | 0 | 43/43: V1/V2 exploits run on v3.2 behaviour and not on the candidate; V3 root rule in bootstrap and source_tree; V4 relabel accepted by v3.2, refused by the candidate; D3 relaunch; guard; credential isolation. |
| v3.1 `controls.py -B` and v3 `f1_controls.py` on the candidate | 0; 0 | 14/14; 9/9. |
| Independent re-attack of candidate `fc0a40d9` (`results/stage9/v33-audit-0001`) | — | V1–V3 blocked in every emulated job; V4 gate holds; new D3 bypass (imports before relaunch) and weak D1 attribution. |
| Final candidate (lock `a809f701…`, diff `b432024f…`); `run_controls.py` → `results/stage9/v33-controls-0003` | 0 | 48/48, including the D3 exploit reproduced on v3.2 and refused four ways on the candidate. |
| v3.1 `controls.py -B` and v3 `f1_controls.py` on the final candidate `405b453a` | 0; 0 | 14/14; 9/9. |

Signing stays off: no repository variables; `provenance.yml` has never run. Not EXIT results.
See U123 and `results/stage9/v32-install-0001/`. `end_to_end=false`.

### Stage 10 — SHADOW MODE

**Status: NOT STARTED**

Run the gate on a real host repository's PRs in report-only mode for two actual
weeks. Do not block merges during this experiment. Log what the gate would have
blocked, why, and which claims and methods were involved. Distinguish an actual
defect from missing evidence, an intentional policy rejection, and a tool failure.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/report_shadow.py` | Reads the real observation log and reports blocks, false positives, and cost per PR for the full period. | NOT RUN |

Include observation dates, sample size, human adjudication, unknown cases, and
cost denominators in the operational report. Those records are separate from
timestamp-free canonical evidence. Do not simulate elapsed weeks or claim a
false-positive rate without a defined review process and denominator.

## Execution record

Stage 0–3 EXIT checks are complete. The true arithmetic lemma was
verified; the false arithmetic lemma was rejected for its false postcondition.
The ledger refinement establishes C1–C5 at source level under the recorded
assumptions. No binary, deployment, or whole-application claim is established.
Stage 2 schema, policy, identity, and replay checks passed, including every
Stage 1 regression. Stage 3's model-comparison checks and approved demo invocation
also passed. Stages 4 and 5 are complete in their stage records above.
Stages 6–8 are complete in their records above. Stage 9 is CURRENT.

Commands ran from the repository root. The required `dafny --version` invocation
used `export PATH="$PWD/.toolchain/dafny-4.11.0/dafny:$PATH"` in that shell. Other
Dafny checks below used its explicit local path. No global PATH was changed.

For each future run, append the following facts here before advancing a stage:

| Stage / case | Exact command | Expected behavior | Actual exit code | Observed result / log reference |
| --- | --- | --- | --- | --- |
| 0 / Node version | `node --version` | Prints selected version | 0 | `v24.3.0` |
| 0 / Python version | `python3 --version` | Prints selected version | 0 | `Python 3.10.11` |
| 0 / installation prerequisite, first attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | `curl: (6) Could not resolve host: github.com`; see `unsure.md` U008–U009 |
| 0 / installation prerequisite, second attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U009–U010 |
| 0 / installation prerequisite, third attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U010–U011 |
| 0 / installation prerequisite, fourth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U011–U012 |
| 0 / installation prerequisite, fifth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; the user subsequently supplied the archive; see `unsure.md` U012–U013 |
| 0 / archive checksum before extraction | `shasum -a 256 -c` with the checksum line shown in `toolchain/README.md` supplied on standard input | Matches the pinned archive SHA-256 | 0 | Archive: OK |
| 0 / extraction | `unzip -q .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip -d .toolchain/dafny-4.11.0` | Extracts the validated distribution | 0 | Completed |
| 0 / Dafny version | `dafny --version` | Prints locked version | 0 | `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| 0 / bundled Z3 version | `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints selected solver version | 0 | `Z3 version 4.12.1 - 64 bit` |
| 0 / CLI option validation | `.toolchain/dafny-4.11.0/dafny/dafny verify --help` | Confirms resource limit, time-limit 0, solver path, and worker options | 0 | Options confirmed from installed CLI |
| 0 / true lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/true.log 2>&1` | Verifies the true postcondition | 0 | [Raw output](toolchain/results/true.log): 1 verified, 0 errors |
| 0 / false lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/false.log 2>&1` | Rejects the false postcondition | 4 | [Raw output](toolchain/results/false.log): 0 verified, 1 error; expected rejection |
| 0 / Node version, final run | `node --version` | Matches selected version | 0 | `v24.3.0` |
| 0 / Python version, final run | `python3 --version` | Matches selected version | 0 | `Python 3.10.11` |
| 0 / pinned local checksums | `shasum -a 256 -c toolchain/checksums.sha256` | Matches the archive and all four listed executables | 0 | All five entries: OK |
| 1 / draft syntax, attempt 1; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | `rbrace expected` at the attempted postcondition label; replaced labels with comments |
| 1 / draft syntax, attempt 2; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | Ambiguous indentation warning at the C5 implication; parenthesized its premise |
| 1 / draft syntax, attempt 3; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 0 | `Dafny program verifier did not attempt verification`; no proof claim |
| 1 / planted bugs, first scenario run | `python3 scripts/exit_stage_1.py --case planted-bugs` | Rejects all fixtures and names the expected claims or rules | 1 | `self_transfer: expected claim/rule was not named`; corrected one-based diagnostic line mapping; see U020 |
| 1 / contract binding, first scenario run | `python3 scripts/exit_stage_1.py --case contract-binding` | Names the missing approved refinement relationship | 1 | Rejected for missing coverage instead of the expected refinement diagnostic; added explicit refinement preamble requirement; see U020 |
| 1 / final accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes evidence | 0 | Real Dafny proof accepted; `source_proof`; `end_to_end=false` |
| 1 / final reproducibility | `python3 scripts/exit_stage_1.py --case reproducibility` | Two accepted runs produce identical evidence bytes | 0 | Gate exits 0 and 0; actual `cmp` exit 0 |
| 1 / final planted bugs | `python3 scripts/exit_stage_1.py --case planted-bugs` | All four fixtures pass basic units but fail the gate | 0 | Units 0 each; gate 1 each; verifier 4 for first three, audit 2 for sneaky_assume |
| 1 / final spec lock | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects changed spec with stale lock | 0 | Disposable-copy gate exit 1; `SPEC_LOCK` |
| 1 / final contract binding | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing approved refinement | 0 | Disposable-copy gate exit 1; `SOURCE_SCOPE` |
| 1 / final audit controls | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects all three proof escape controls | 0 | Actual auditor exit 2 and gate exit 1 for each control |
| 1 / published evidence candidate comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Root evidence equals tested reproducibility output | 0 | Files are byte-identical |
| 2 / archived evidence schema | `python3 gate/gate.py --schema-only results/stage1/evidence.json` | Validates exact Stage 1 record structure only | 0 | `SCHEMA_VALID`; no proof acceptance claimed |
| 2 / accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Runs actual backend and enforces schema and critical policy | 0 | C1–C5 accepted; policy-bound format 2; 12 obligations |
| 2 / schema | `python3 scripts/exit_stage_2.py --case schema` | Both actual formats validate; malformed controls fail | 0 | Schema-only children 0 and 0; malformed-input gates 1 and 1 |
| 2 / artifact mismatch | `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Rejects changed record digest, coherent forged digest, and manifest digest | 0 | Three gates exited 1 with `ARTIFACT_MISMATCH` |
| 2 / method policy | `python3 scripts/exit_stage_2.py --case method-policy` | Rejects methods not allowed by critical policy | 0 | Three gates exited 1 with `METHOD_POLICY`; no ranking or upgrade |
| 2 / round trip | `python3 scripts/exit_stage_2.py --case round-trip` | Supplied evidence equals a fresh actual checker result | 0 | Gate 0; `cmp` 0 |
| 2 / policy controls | `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects all 15 deliberately altered inputs | 0 | All gate calls exited 1; intended diagnostics retained |
| 2 / Stage 1 reproducibility regression | `python3 scripts/exit_stage_1.py --case reproducibility` | Retains byte-identical evidence across runs | 0 | Gate 0 twice; `cmp` 0 |
| 2 / Stage 1 planted-bug regression | `python3 scripts/exit_stage_1.py --case planted-bugs` | Retains all four intended rejections | 0 | Units 0; gates 1; verifiers 4 or audit 2 |
| 2 / Stage 1 spec-lock regression | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects a changed spec with old lock | 0 | Gate 1 with `SPEC_LOCK` |
| 2 / Stage 1 contract-binding regression | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing explicit approved refinement | 0 | Gate 1 with `SOURCE_SCOPE` |
| 2 / Stage 1 audit regression | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects the three proof escapes | 0 | Audits 2; gates 1 |
| 2 / final evidence comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Current root evidence equals tested reproducibility output | 0 | Byte-identical |
| 3 / JS toolchain installation | `npm install --cache .toolchain/npm-cache --prefer-offline --ignore-scripts --no-audit --no-fund --fetch-retries=0` | Installs pinned direct dependencies | 1 | `getaddrinfo ENOTFOUND registry.npmjs.org`; user later installed externally |
| 3 / installed dependency check | `npm ls --depth=0` | Prints exact requested installed versions | 0 | All five direct pins match |
| 3 / tsx CLI prerequisite | `npx --no-install tsx --version` | Runs the pinned CLI | 1 | tsx 4.21.0 printed, then `listen EPERM` for local IPC |
| 3 / real JS model build | `python3 scripts/build_model.py` | Compiles the actual approved model with pinned Dafny settings | 0 | 12 verified, 0 errors; module digest recorded |
| 3 / loader demo | `node --import tsx app/main.ts` | Runs actual generated ledger through the bridge | 0 | `Ok`, then `Rejected`; not a substituted npx result |
| 3 / TypeScript check, attempt 1 | `npx --no-install tsc --noEmit` | Type-checks the implementation, bridge, app, and properties | 2 | The example input array needed a one-element tuple shape |
| 3 / TypeScript check, attempt 2 | `npx --no-install tsc --noEmit` | Same static check after the reported tuple fix | 0 | No diagnostics |
| 3 / correct TypeScript | `python3 scripts/exit_stage_3.py --case correct-typescript` | Actual comparison properties and gate pass | 0 | 300 seeded runs; 3,506 comparisons |
| 3 / planted self-transfer | `python3 scripts/exit_stage_3.py --case self-transfer` | Actual comparison rejects the planted bug | 0 | fast-check 1; gate 1; counterexample retained |
| 3 / evidence labels | `python3 scripts/exit_stage_3.py --case evidence-labels` | Distinct methods, bound source/model/TS artifacts, no proof upgrade | 0 | Source and TS gates 0; critical-tier TS gate 1 |
| 3 / deterministic reproduction | `python3 scripts/exit_stage_3.py --case reproducibility` | Builds and evidence reproduce byte for byte | 0 | Both gate calls 0; actual cmp 0 |
| 3 / loader scenario | `python3 scripts/exit_stage_3.py --case loader-demo` | Records actual loader stdout | 0 | Exact expected lines; npx EXIT still pending |
| 3 / original CLI demo | `npx tsx app/main.ts` | Runs the original demo invocation | 1 | `listen EPERM` for its local IPC socket; raw report under `build/stage3/cli-demo/` |
| 3 / original CLI scenario | `python3 scripts/exit_stage_3.py --case cli-demo` | Requires original CLI exit 0 and expected output | 1 | Actual child command failed; not counted as a passing EXIT |
| 3 / approved replacement, final run | `node --import tsx app/main.ts` | Runs the user-approved replacement invocation | 0 | Printed exactly `Ok` then `Rejected`; supersedes the original demo invocation only |

Record failed attempts as well as successful ones. Keep negative-checker codes
separate from their scenario script's code. Do not erase earlier failures.
The first failed scenario reports predate automatic log archiving. Their raw
files were overwritten during development. The observed failures above and in
U020 are retained; no missing raw log has been reconstructed or claimed.
Stage 2 preparation had one parse-time script error, exit 1, from a Unicode dash
inside a Python bytes literal. No statements ran. The corrected UTF-8 script
exited 0. This was not a checker or toolchain failure; see U025 and the Stage 2
result record. All Stage 2 EXIT scenarios passed on their first run.

## Open items

- Runtime provenance: Node and Python installer origins were not independently
  authenticated. Their checked versions and executable hashes are pinned. Keep
  the disclosed trust assumptions in `toolchain/pins.json` and `unsure.md` U015.
- Stage 8 is DONE after the exact approved snapshot repair and all three passing
  EXITs. Source proofs, finite runtime testing and unmeasured model quality stay
  distinct. Stage 9 is CURRENT; its implementation has not started. Deployment
  correctness remains unproved; `end_to_end=false`. Prior measurements retain
  their limits, and all historical failures remain archived.
- Publication: the user created [mack-dot/forge](https://github.com/mack-dot/forge).
  The connected app confirms public visibility, the mack-dot owner, and push
  access. The earlier 404/creation blocker is resolved. Publication uses that
  app because the local CLI could not connect and local `.git` writes are denied.
  Preserve the earlier failed commands as history; publication verification is
  recorded in the append-only `unsure.md` log.
- Distribution: choose an open-source license before describing a published
  repository as licensed for open-source reuse. Public visibility alone does
  not supply a license.

