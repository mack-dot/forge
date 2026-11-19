# Adoption packet v6: core-backed sink (v6), issue-bytes minter, dispatcher request-id check

Night shift 2026-11-19, Orchestrator B, task p-adopt2. Base: commit 985f5eaf. Replaces the v4 packet (p-adopt/).
Nothing here is applied to the repository. Nothing here is executed by an agent after this packet. The owner decides.

## 1. The change (adoption-v6.diff)
- File `p-adopt2/adoption-v6.diff`: 6731 lines, SHA-256 `0207444f1622d8542e6fd0fb86636bb9b102eb0b5015a0b63b6f88b2780d193d`.
- `git -C /Users/mackianni/forge apply --check adoption-v6.diff`: exit 0 (check only). Protected or `clearing/` paths: 0.
  File list = full tree difference (`changed-files.txt`); applied to copies, it gives all 14 files byte for byte (make_diff_v6.sh).

| File | Kind | SHA-256 (after) |
|---|---|---|
| impl/finality-core/IssueBytes2.dfy | added (as v4 packet) | 2ac62b5f927a650a… |
| impl/finality-core/SerModel.dfy | added (as v4 packet) | a07f955846276e24… |
| impl/finality-core/ShellCoreV3.dfy | added (as v4 packet) | 1358e5d8d0b4cd63… |
| impl/finality-core/ShellCoreV4.dfy | added (as v4 packet) | 8e45d7b13c7caafb… |
| impl/finality-core/ShellCoreV5.dfy | added (d-v6sink copy, unchanged) | 1c6f4531ce1b0da2… |
| impl/finality-core/ShellCoreV6.dfy | added (d-v6sink, unchanged) | 771fa96f062b23d6… |
| impl/finality-core/SinkCoreV3.dfy | added (as v4 packet; include paths changed) | fbd28947470561bb… |
| ts/refund-finality/core/sinkcore-v6.cjs | added (generated ShellCoreV6 + footer; = d-v6sink build) | 11ba1f388d2cd39d… |
| ts/refund-finality/sink.ts | replaced by the v6 draft (import path, core path, new header, "v6 sink refuses") | 1ba4682b7a979fa7… |
| ts/refund-finality/minter.ts | replaced by the issue-bytes draft (as v4 packet) | 046b64bb3e4cfd5a… |
| ts/refund-finality/dispatcher.ts | dispatcher-reqid.diff (1 line; as v4 packet) | 5cecfd775a10d6da… |
| scripts/exit_slice1.py | v4 packet version, sink core = ShellCoreV6, module sinkcore-v6.cjs, footer, FINALITY_CORE + V5, V6 | 4c4186faaf125102… |
| **TEST** tests/refund-finality/suite.ts | 2 lines: initialState passed (lines 240, 390) | 8038c809b6c1f7d5… |
| **TEST** tests/demo-gauntlet/sink_tool.ts | line 14 -> 14-15: `init` passes the given state as initialState | 557019246f042e23… |

Full digests: `new-files-sha256.txt`. sink.ts = d-v6sink draft except header (stale "ShellCoreV4.StepQ" text), import
`./encoding`, `CORE_FILE`, and "v5 sink refuses" -> "v6". Owner choices as in the v4 packet (FinalityProtocol.dfy include
from `proposals/` or a copy; commit the generated .cjs; the "DRAFT" .dfy headers).

## 2. Test edits (sensitive; no assertion changed)
- suite.ts:240 `sinkCfg` gets `initialState: initial` (the state that world() already passes to `init`, line 248). It
  also reaches sink-config.json (line 242) and so commit_cli.ts; it reaches dispCfg (line 241) as an extra key that the
  dispatcher ignores.
- suite.ts:390 the "no stored state" sink gets `initialState: none` (the state its token was minted for; init never runs).
- sink_tool.ts:14-15 `init` uses its state argument as initialState when the config has none.
- tests/refund-finality/commit_cli.ts: NOT changed (it passes the config file through; the suite's file now carries it).
- NOT changed and broken by v6: scripts/demo_gauntlet.py:257 writes a config without initialState, so `sink_tool report`
  and commit_cli refuse in act 2; the gauntlet already breaks in the v4 packet (issuer module). Owner decision.

## 3. Checks done in the scratch export (actual exit codes)
| Check | Log | Exit / result | Class |
|---|---|---|---|
| dafny build ShellCoreV6.dfy --target js, gate options, lock script | logs/b1-shellv6-build-2.log (-1: shell quoting, no Dafny run) | 0; 207 verified | MACHINE-CHECKED (model) |
| dafny build IssueBytes2.dfy, same | logs/b2-issuer-build-1.log | 0; 131 verified | MACHINE-CHECKED (model) |
| generated JS byte-equal to d-v6sink and d-minter builds; rebuild + footer == committed sinkcore-v6.cjs | cmp | equal; equal; True | — |
| audit, exit_slice1 style (`--compare-report` vs gate/expected-audit.md), both cores | logs/c-*-audit-compare.log | 0, 0; 0 findings | MACHINE-CHECKED |
| `tsc --noEmit`, repository tsconfig, whole project (suite.ts, sink_tool.ts listed) | logs/tsc-export-1.log | 0 | — |
| sink conformance, 31 cases, draft-v6 = export sink.ts | logs/n1-conformance-v6-export-2.log | 0; 0 unexpected | TESTED-UNPROVED |
| (run 1 of it: 4 "unexpected" = only the renamed prefix "v6 sink refuses" in v6==v5; run 2 compares without it) | -1.log | 1 | — |
| minter conformance, 581 requests, new vs old minter, v6 sinks | logs/m1-minter-conf-v6-1.log | 0; 0 diff; 55 issued (19 zero), 55 commit + replay | TESTED-UNPROVED |
| end to end: mint -> commit once -> replay -> dispatcher emits once (100 and 0) | logs/e2e-v6-1.log | 0; 2 effects, then 0 | TESTED-UNPROVED |
| legacy store (pristine sink wrote it) opened by v6: none / right / wrong initialState | logs/legacy-v6-1.log | 0; refuse / start (+commit 0, 2 effects) / refuse | TESTED-UNPROVED |
| raw-tamper stores of suite rows x1 x2 x3 x6 x7 | logs/tamper-v6-1.log | 0; dispatcher as suite expects; v6 refuses to start on all 5 | TESTED-UNPROVED |
| checker pin of the export | logs/checker-id-1.log | 61438653b7e709ee…e021 (= v4 packet) | — |
Earlier evidence (not repeated): heavy/v6-1/summary.txt (v6 draft vs compiled core: 0 divergences); d-v6sink logs; r-v6.

## 4. Heavy step for the orchestrator (prepared, NOT run)
`/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt2/run_suite_v6.sh [N]`: refuses (64) while
locks/hol.lock exists or `bin/hol` runs; takes no heavy.lock; `env -i`, Node 24.3.0; SUITE_TIMEOUT_S (default 1200 s)
per run. Runs: pristine (p-adopt/pristine), export, x3probe (a measurement copy of suite.ts in suite-variant/: only the
x3 audit row catches a refusal; its pass condition is unchanged; NOT in the diff; NO_PROBE=1 skips it). Writes
suite/attempt-N/summary.txt with every failing or missing row side by side and a line "PREDICTION MET|NOT MET".
PREDICTED (not observed) differences, by design:
- export run: exit 2, NO report. suite.ts:517 (row "dispatcher | the public-key audit of that changed database")
  constructs a sink on the x3 store (attacker-signed row + state update, lines 512-516); v6 refuses to start
  (sigOk false in AuditV5); main() rejects (suite.ts:614). Rows after it do not run. Reproduced in tamper-v6-1.log.
- x3probe run: exit 1, 115 rows, exactly that 1 row FAILED ("the sink refused to start").
Predicted to pass unchanged: x1, x2, x4-x8 (the judge uses only the Dispatcher; no sink opens after the change);
races b (suite.ts:411-426) and c (:451-461): each commit_cli process audits at start (serialised by BEGIN IMMEDIATE),
the losers see a foreign data_version, re-audit an honest store, then get STALE (b) or replayed (c); risk: START_DELAY_MS
5000 is tighter (more start work per process); "no_state" (:389): rejected, 0 rows; zero-amount rows (c, d): commit.
Any other FAIL row is NOT predicted: a regression or an environment fault.

## 5. Records and pins that change (re-record after the owner's run)
- Checker pin of every sink: 61438653b7e709ee…e021 (issuer module a60786ae…; unchanged from the v4 packet).
- Slice 1 records (evidence.json: source_manifest, compiled_core incl. sink_core = ShellCoreV6; links-final.json;
  regression.json; REPORT.md trusted-base text: sink.ts is no longer the decision).
- Wave Gate 1 (exit_m1_conformance.py :57, :60, :515-519, :536) and the demo gauntlet (demo_gauntlet.py :64, :182, :244,
  plus :257 config without initialState): BREAK by design; adapt or record as superseded (owner decision).
- Binding manifest draft rows for sink.ts and minter.ts: new digests and "why".
- The suite row at suite.ts:517 (Section 4): the owner decides its new expectation (e.g. "refused to start").

## 6. Deployment duties
- Authentic initial charge in the sink configuration (`SinkConfig.initialState`, REQUIRED; THE anchor; from outside
  the database). The audit is sound only RELATIVE TO this supplied charge.
- Key or pin rotation: the start-up audit re-verifies every stored signature with the configured key and checks the
  pinned ids; a restart with a new key or pin refuses the old store unless the old key is kept for the audit (r-v6).
- Legacy stores (old sink): start only with the right initialState (meta hash must match); tested.
- A tampered store refuses to start; a foreign change seen at commit HALTS the sink (availability lost, not money).
  Start-up cost: one signature check per stored row (2.7 s at 20,000 rows; d-v6sink worker's number).

## 7. Owner questions that block adoption (OWNER_REQUIRED.md B-10)
1. "Request open" is fixed to true; the sink's "not settled" stands in for it, where spec/refund/protocol.md lines
   15-18 says the host supplies the context and that flag. Approved meaning? Who closes a request? (r-v6: fixing it
   to true WIDENS acceptance.)
2. Which context governs when the host's remaining differs from the sink's stored remaining?
3. The sink would enforce the three choices of impl/RefundFinality.dfy that its header calls not ratified (charge
   shape; remaining decreases by the amount only; request taken as open): ratify them, or not.

## 8. Assumptions that remain (not proved)
Dafny compiler and JS runtime, bignumber.js, the .cjs footers and value conversions; Node, SQLite (IMMEDIATE
transaction, UNIQUE index, data_version); the database assumptions of the streaming audit; no rollback of the whole file
to an earlier valid prefix (needs an external anchor); a key holder who writes only authorized rows is a legitimate
writer; the minter's hash input line (`stateSha256(pre)` computed in minter.ts, glue G-H); the TypeScript loop that
feeds AuditStep is TESTED-UNPROVED against the proved fold (row order, decoding, request-id column); the mint layer is
not proved for StepQ6 (r-v6); Ed25519, SHA-256.

## 9. NOT RUN
The Slice 1 suite (HOL lock held; run_suite_v6.sh prepared). `scripts/exit_slice1.py` on the changed tree. exit_m1_conformance.py, demo_gauntlet.py. Differential, kill, race and
scale runs of the export (heavy). No HOL. No second-agent review of the adapted exit_slice1.py or of the test edits.

## 10. Order of owner actions
1. Answer B-10 (Section 7); without it the v6 sink is not a candidate. 2. Review adoption-v6.diff, test files first.
3. Let the orchestrator run run_suite_v6.sh in a heavy window; compare with Section 4.
4. Decide the expectation of suite.ts:517, Wave Gate 1 and the gauntlet (Section 5).
5. On a branch: `git apply adoption-v6.diff`; run `python3 scripts/exit_slice1.py --case sink-controls`, then `--case evidence`.
6. Re-record the Slice 1 records, the binding manifest and every sink's checker pin; add an unsure.md entry.
7. Merge only on the owner's word.
