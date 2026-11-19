# Adoption packet: core-backed sink (v4), issue-bytes minter, dispatcher request-id check

Night shift 2026-11-19, Orchestrator B, task p-adopt. Base: commit 985f5eaf. Nothing here is applied to the
repository. Nothing here is executed by an agent after this packet. The owner decides each step.

## 1. The change (adoption.diff)
- File: `p-adopt/adoption.diff`, 5239 lines, SHA-256 `ab2ca0dac7f249e48421a72e8c57abbd849ada7ab3755341ab682aca5b6ab042`.
- `git -C /Users/mackianni/forge apply --check adoption.diff`: exit 0 (check only). Protected or `clearing/` paths: 0.
- The diff, applied to copies of the four pristine files, gives the 10 export files byte for byte (`applytest/`).
- Rebuild: `make_diff.sh` (log `logs/make_diff-1.log`).

| File | Kind | SHA-256 (after) |
|---|---|---|
| impl/finality-core/IssueBytes2.dfy | added (d-minter; include path changed) | 2ac62b5f927a650a… |
| impl/finality-core/SerModel.dfy | added (d-minter, unchanged) | a07f955846276e24… |
| impl/finality-core/ShellCoreV3.dfy | added (d-v3sink2, unchanged) | 1358e5d8d0b4cd63… |
| impl/finality-core/ShellCoreV4.dfy | added (d-v3sink2, unchanged) | 8e45d7b13c7caafb… |
| impl/finality-core/SinkCoreV3.dfy | added (d-v3sink2; two include paths changed) | fbd28947470561bb… |
| ts/refund-finality/core/sinkcore-v4.cjs | added (generated: dafny build of ShellCoreV4 + footer) | 2317a34e7f6cb260… |
| ts/refund-finality/sink.ts | replaced by the v4 draft (import path, core path, header) | c49cbe63110886d3… |
| ts/refund-finality/minter.ts | replaced by the issue-bytes draft (import path, pin path, header) | 046b64bb3e4cfd5a… |
| ts/refund-finality/dispatcher.ts | d-reqid/diffs/dispatcher-reqid.diff applied (1 line) | 5cecfd775a10d6da… |
| scripts/exit_slice1.py | builds IssueBytes2 as the issuer module; rebuilds ShellCoreV4 and requires byte equality with the committed .cjs; audits both new cores; SUBJECT extended | 67f8e5fa872377fa… |

Full digests: `p-adopt/new-files-sha256.txt`. Include targets: SinkCoreV3 includes
`../../proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy` (byte-equal to the draft's copy, 8b70b6b4…) and
`../RefundFinality.dfy`; IssueBytes2 includes `../RefundFinality.dfy`. Public interfaces kept: `Sink(path, cfg)`,
`SinkConfig` (+ optional `initialState`), `CommitResult`, `OutboxRow`; minter arguments and ready line unchanged.
Owner choices: (a) include from `proposals/` or copy FinalityProtocol.dfy into impl/finality-core/;
(b) commit the generated .cjs (this packet) or pass a sink-core path in SinkConfig; (c) the .dfy header comments
still say "DRAFT"; edit them before merge if wanted (it changes their digests, not the proofs).

## 2. Checks done in the scratch export (actual exit codes)
| Check | Command / log | Exit | Class |
|---|---|---|---|
| verify+compile sink core (new paths) | `dafny build impl/finality-core/ShellCoreV4.dfy --target js` gate options, lock script; logs/b1-sinkcore-build.log | 0 (120 verified) | MACHINE-CHECKED (model) |
| verify+compile issuer core | same for IssueBytes2.dfy; logs/b2-issuer-build.log | 0 (131 verified) | MACHINE-CHECKED (model) |
| generated JS equal to the drafts' builds | cmp build/*/model.js vs d-v3sink2, d-minter | equal | — |
| audit, exit_slice1 style (`--compare-report` vs gate/expected-audit.md) | logs/c-*-audit-compare.log | 0, 0 (no findings) | MACHINE-CHECKED |
| pristine module reproduces the Slice 1 record | logs/b3-pristine-core-build.log; sha e6d5f5e5… | 0; equal | — |
| `tsc --noEmit` (repository tsconfig, whole project) | logs/tsc-export.log (1.6 s); pristine logs/tsc-pristine.log | 0; 0 | — |
| sink conformance (31 cases; v4 = export sink.ts, real = pristine) | conf/sink_conf.ts; conf/sink-conf-1.json | 0 (0 unexpected) | TESTED-UNPROVED |
| minter conformance (581 cases; new vs old minter; new sink) | conf/minter_conf.ts; conf/minter-conf-1.json | 0 (0 differences; 55 issued, 19 zero; 55 commit in the new sink) | TESTED-UNPROVED |
| end to end: new minter -> new sink -> patched dispatcher | conf/e2e.ts; logs/e2e-1.log | 0 (100 and 0 commit once, replay once; 2 effects, then 0) | TESTED-UNPROVED |
| legacy store (old sink wrote it) opened by the v4 sink | conf/legacy.ts; logs/legacy-1.log | 0 (no initialState: refuses; right initialState: starts; wrong: refuses) | TESTED-UNPROVED |
Earlier evidence (not repeated): heavy/v4-1/summary.txt (0 divergences v4 vs compiled V3 core, 3,500 sequences);
d-reqid patch checks; d-minter mutants (M1, M2 fail; M3–M6 out of resource only).

## 3. NOT RUN
- The Slice 1 suite (both trees): HOL lock held. Prepared: `p-adopt/run_suite.sh` (Section 5).
- `scripts/exit_slice1.py --case sink-controls|evidence` on the changed tree (it runs Dafny outside the lock script).
- exit_m1_conformance.py and demo_gauntlet.py (they break after adoption; Section 4).
- Differential/kill/race runs of the export (heavy). No HOL. No review of the adapted exit_slice1.py by a second agent.

## 4. Records and pins that change (re-record after the owner's run)
- Checker pin of every sink: H(issuer module, encoding.ts, minter.ts). Recorded f42af94e… (module e6d5f5e5…);
  new value with the IssueBytes2 module a60786ae… and the new minter.ts: `61438653b7e709ee…e021`.
- Slice 1: proposals/forge2-slice1-refund-finality/records/evidence.json (source_manifest, compiled_core,
  ids, report), links-final.json and regression.json (sink/minter/dispatcher digests), removed-check-copies.json if
  it names these files; REPORT.md text (K-a..K-d, trusted base: sink.ts is no longer the decision).
- Wave Gate 1 (exit_m1_conformance.py) and the demo gauntlet: BOTH BREAK by design. Lines: exit_m1_conformance.py:57
  `CORE`, :60 `FOOTER`, :515-519 `check_core_module` (module must equal the Slice 1 record), :536 issuer call;
  demo_gauntlet.py:64 `REFUND_FOOTER`, :244 `compile_core(REFUND_CORE, …, SLICE1_RECORD)`, :182 issuer call. The
  new minter needs `core.IssueBytes2`; a module of impl/RefundFinality.dfy alone makes the minter throw at the
  first issue. Adapting them (and their recorded bundles, e.g. M1 conformance bundle f55391da…) is a separate
  owner decision; this packet does not touch them.
- Binding manifest draft (proposals/m1b-mission-20261119/drafts/binding-manifest/refund_binding_manifest.json):
  rows for sink.ts and minter.ts (lines ~1204-1820) need new digests and a new "why" (decision now compiled core).

## 5. Heavy step for the orchestrator (prepared, not run)
`/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt/run_suite.sh [N]` — refuses (64) while
locks/hol.lock exists or `bin/hol` runs; takes no heavy.lock; `env -i`, Node 24.3.0; timeout SUITE_TIMEOUT_S
(default 1200 s) per tree; outputs suite/attempt-N/{pristine,export}.{stdout,stderr,meta}, *-out/report.json,
summary.txt. Same command as exit_slice1.py: `node --import tsx tests/refund-finality/suite.ts <out> <module>`.
Expected: pristine exit 0 with 115 rows (recorded counts). Export: exit 0 expected; NO row is expected to fail by
design: the suite has no digest pin (it computes the checker id live, suite.ts:104) and mints all real-key tokens
through the proved issuer (request id and charge id agree). Expected differences that are NOT failures:
report ids (module a60786ae…, checker 61438653…), the issuer grid text (byCore/byShape split, suite.ts:157).
Rows to watch (a failure there needs analysis, not a re-record): dispatcher x3 "the public-key audit of that
changed database" (suite.ts:517: the v4 constructor runs the start-up audit after a raw tamper; if it refuses, the
suite stops with exit 2); races b (suite.ts:417) and c (suite.ts:455) (each process now loads the compiled core and
audits at start: START_DELAY_MS 5000 may be short); "no_state" (suite.ts:389). Any other FAIL row, or a pristine
failure, is a regression or an environment fault (compare with the pristine column in summary.txt).

## 6. New deployment preconditions
- Start-up audit: the sink refuses to start when AuditEnd is false; there is no option to skip it.
- Initial charge: init() writes meta 'initial_state' (text) beside 'initial_state_sha256'. A store made by the
  old sink lacks it: the v4 sink refuses to start unless cfg.initialState is given and its canon hash equals
  'initial_state_sha256' (tested, logs/legacy-1.log). The operator must supply the authentic initial state.
- Writer guard: another writer triggers a re-audit; a false audit HALTS the sink (all later commits rejected).
- Dispatcher: refuses an outbox row whose token intent request id differs from the row (one more refusal reason path).

## 7. Assumptions that remain (not proved)
Dafny compiler and JS runtime, bignumber.js; Node, SQLite (IMMEDIATE transaction, UNIQUE index); the database
assumptions A-DB1..A-DB3 of the streaming audit; no rollback of the whole file (needs an external anchor); the
authentic initial charge (the audit's init is unauthenticated: r-restart); the minter's hash input line
(`stateSha256(pre)` computed by the shell, glue G-H, minter.ts); the TypeScript loop that feeds AuditStep is
not proved to be the proved fold (row order, decoding, column = intent request id); Ed25519, SHA-256; the
.cjs footers and conversions in sink.ts/minter.ts; the audit does not check signatures (audit() does, offline).

## 8. Order of owner actions
1. Review adoption.diff (and the choices in Section 1). 2. On a branch: `git apply adoption.diff`.
3. Run `python3 scripts/exit_slice1.py --case sink-controls`, then `--case evidence` (or first run_suite.sh).
4. Decide on Wave Gate 1 and the gauntlet (Section 4); adapt or record them as superseded.
5. Re-record the Slice 1 records, the binding manifest and every sink's checker pin; add an unsure.md entry.
6. Merge only on the owner's word.
