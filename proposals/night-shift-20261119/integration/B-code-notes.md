# Code notes: origin/nightshift/B-trust (12d634f6) against 985f5eaf

## (a) How the tests load the code under test
Mixed. Most regressions load the code under test from `<tree>` at run time; judges import only their TRUSTED encoding/store statically.
- Run time, from `<tree>`: `tests/refund-finality/regress/d_lib.ts:19` `const [root, core] = process.argv.slice(2);` and
  `d_lib.ts:31` `Sink: require(join(root, "ts/refund-finality/sink.ts")).Sink`. Same pattern: `m_lib.ts:29`,
  `s_lib.ts:31`, `p_lib.ts:92`, `kf_lib.ts:45`, `d_child.ts:10`, `s3_kill_commits.ts:30`.
- Static relative import, code under test: `tests/refund-finality/regress/c_att_01_line_separator.ts:10`
  `import { LineSplitter } from "../../../ts/refund-finality/proposer";` (also `c_att_16_client_id_override.ts:8`).
- Static relative import, trusted judge side (by design): `tests/refund-finality/spec-conformance/oracle.ts:16`
  `... from "../../../ts/refund-finality/encoding";`; `regress/harness.ts:30-31` (encoding, core/store).
  The runner (`regress/run.ts`, `worker.ts:28,83`) and `spec-conformance/run.ts` take the sink path as an argument.
- `tests/refund-finality/provider/*`: no import of `ts/`; `emit_adapter.ts:44` imports only `./fake_provider`.

## (b) The second argument, the "compiled issuer module" (issueonce.cjs / issueauth.cjs)
- It is the Dafny-to-JavaScript build of the issuer core plus an export footer. The recipe on the branch is
  `scripts/exit_slice1.py:40-41,289`: `dafny build impl/finality-core/IssueAuth.dfy --target js --output <dir>/model <gate options>`,
  then `model.cjs = model.js + b'\nmodule.exports = { IssueAuth, IssueBytes2, RefundFinality, Refund, SerModel, runtime: _dafny };\n'`.
- B's final build: `orch-B/h-minter3/logs/b02-build-js.log` (cmd `dafny build --target js --output .../h-minter3/build/issueauth.js ... IssueAuth.dfy`,
  "194 verified, 0 errors", exit 0). The footer step for that build has no stored record (NOT FOUND).
- The built module that the final runs used (`orch-B/h-minter3/build/issueauth.cjs`, named in `h-suite/logs/B-full-5.meta`) is NOT committed.
  `h-minter2/build/issueauth.cjs` is NOT committed either.
- Committed copies: `results/night-shift-20261119/orch-B/r-issueauth/issueauth.cjs` (133,810 bytes, commit 5d99be9d, older rule-2 IssueAuth;
  INFERRED: it is not the 194-verified build), the same bytes size at `r-issueauth/closed/core.cjs` (133,810), and a red-team shadow
  `h-minter/redteam/c7/shadow/issueonce.cjs` (118,874). No committed issueonce.cjs from B's own IssueOnce build.

## (c) Files outside results/ that exist at 985f5eaf and B MODIFIED (git diff --numstat, +/-)
- ROADMAP.md +110/-0; scripts/demo_gauntlet.py +39/-5; scripts/exit_slice1.py +38/-6; tests/demo-gauntlet/sink_tool.ts +8/-1
- tests/refund-finality/commit_cli.ts +32/-10; tests/refund-finality/dispatch_cli.ts +56/-12; tests/refund-finality/suite.ts +257/-58; ts/refund-finality/dispatcher.ts +465/-73
- ts/refund-finality/encoding.ts +25/-5; ts/refund-finality/minter.ts +357/-68; ts/refund-finality/proposer.ts +33/-7; ts/refund-finality/sink.ts +443/-102
- unsure.md +699/-0
13 modified, 118 added. exit_slice1.py matches scripts/exit_*.py but is NOT in gate/incremental.py PROTECTED_* at 985f5eaf; no protected-dir file changed.

## (d) ts/refund-finality/core/sinkcore-v6.cjs (2,916 lines, 96,953 bytes, blob 592623ad, added in b7fd6be8)
- Generation recipe recorded in `scripts/exit_slice1.py:45-47,297-302`: `dafny build impl/finality-core/ShellCoreV6.dfy --target js`
  + SINK_FOOTER; the script REQUIRES byte equality with the committed file. No stored run of that check on the branch was found.
- Stored build: `orch-B/p-adopt2/logs/b1-shellv6-build-2.log` (cwd p-adopt2/export, `dafny build impl/finality-core/ShellCoreV6.dfy --target js`,
  "207 verified, 0 errors", exit 0). `orch-B/p-adopt2/new-files-sha256.txt` records sinkcore-v6.cjs = 11ba1f38…79dd, equal to the head file,
  and ShellCoreV6.dfy = 771fa96f…, equal to `impl/finality-core/ShellCoreV6.dfy` at head. Source: ShellCoreV6.dfy (+ V5, V4, V3, SinkCoreV3 via includes).

## (e) Secrets and absolute paths
Outside results/ (added lines of B only): no private key, token, password or PEM. One absolute home path:
- `tests/refund-finality/spec-conformance/heavy_spec.sh:14` `LOCKS=${LOCKS:-/Users/USER/forge/results/night-shift-20261119/locks}`.
- `tests/refund-finality/regress/m2_closed_launch.ts:66` contains the string "PRIVATE KEY-----" as a CHECK (no key).
results/night-shift-20261119/orch-B at head (files with a hit, text files only):
- PRIVATE KEY PEM: 0. `-----BEGIN `: 285 (282 PUBLIC KEY blocks, 3 SSH SIGNATURE: g-admission/s1-demo/work/*.sig; rest are sink-config.json public keys).
- `/Users/`: 9 (all sanitiser code: f-binding*/ledger_lib.py, make_guarantee.py, make_ledger.py; no real home path).
- `/home/`: 46 (relative `.../h-anchor/home/...` temp names in logs, and `/home/opam` in a copied scripts/stage7_job.py).
- `<TMP>/claude`: 1 (`h-gate3/logs/run-all.log:3` "<TMP>/claude-cwd").
- `/var/folders`: 25 (temp paths in test logs, e.g. recheck-d2/d_att22_short_write.log, recheck-s3/heavy_s3_kill_commits.log).
- `.env` file name: 0. `password`: 2 (g-admission/AUTHORITY_DESIGN.md, OWNER_ACTIONS.md: command text, no value). Token patterns: 0.
HISTORY: commit 10611550 has 1,941 files under orch-B with `/Users/USER` (fixed forward in 5d99be9d: 0). A merge of the branch carries it.
Per-pattern first 20 paths: scan-hits.txt (same folder).
