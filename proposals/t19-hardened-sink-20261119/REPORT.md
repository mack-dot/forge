# T19: the hardened refund sink, minter and dispatcher become the code on `main` (owner items B-15 and B-16)

Date: 2026-11-19 and 2026-11-20 (UTC). Branch `feat/t19-hardened-sink` from `main` at `a5133c01`;
`main` at `9a9a8943` (Goal 20), `b2249ea2` (APEX-2) and `33055a59` (a design document) merged in.
Not a stage. CURRENT none. M1-B OPEN. `end_to_end=false`. Stage 12 unauthorized.
T19 closes at the TESTED level. Nothing here is a proof. The sink, the minter and the dispatcher are
unverified TypeScript. Every row below is a finite test on one machine.
The agent did not merge. The merge is the owner's.

## 1. Authority

Owner text of 2026-11-19, as the launcher gave it: "T19: Apply the hardened sink (B-15 and B-16 approved)
to main as the immediate priority." The code implements the earlier owner decisions D-1 to D-6
([OWNER_REQUIRED.md](../night-shift-20261119/OWNER_REQUIRED.md)).
Evidence class of the approval: a text relayed by the launcher of this session. I did not see the
owner type it.

## 2. What changed

1. `git apply` of the two diffs of the night shift, unchanged
   ([README](../night-shift-20261119/unapplied/README.md)): `hardening-code.diff`
   (SHA-256 `d8a4ba916bd3062d5dd40c30b053e593a597cf3495bb103a2d57e9dd35190ec9`, 119 files) and
   `suite-expectations-B15-B16.diff`
   (SHA-256 `163cc9e1d863e1962eec4bb546346af1c0ef4c044951530490264feb24e074d1`, `suite.ts`).
   `git apply --check`: exit 0. `git apply`: exit 0. No hunk failed. No hunk was rebased by hand.
   For `ts`, `tests/refund-finality`, `tests/demo-gauntlet` and the two scripts, the tree after the apply
   is equal to `nightshift/B-trust@12d634f6` except one line: the replaced user name in
   `tests/refund-finality/spec-conformance/heavy_spec.sh` (`git diff`: 1 file, 1 line).
2. Hand changes after the apply. Each one is a separate commit or is named in a commit message.
   - `tests/refund-finality/regress/p3_lib.ts` and `kf_unknown_keyid_refused.ts`: one type annotation
     each. Cause: `scripts/exit_slice1.py --case evidence` on the applied tree gave exit 1, because
     `tsc --noEmit` gave exit 2 (7 type errors in 6 regression files). The two edits change types only.
     B ran the suite without the type check of the EXIT script; so B's record did not show this.
   - `scripts/exit_slice1.py`: `ts/refund-finality/mintmemory.ts` added to the `SUBJECT` list (review
     finding F3: the bundle did not pin a file that the minter loads).
   - `scripts/exit_m1_conformance.py`: the same module change as `exit_slice1.py` (owner item B-15), a
     throwaway key file made at run time (decision D-1), and five new pinned inputs. Section 5.
   - `scripts/demo_gauntlet.py`: act 2 builds ONE module (IssueAuth) and requires byte equality with the
     Slice 1 record. The applied diff built a second module that no record pinned (review finding F4).
3. New records: the Slice 1, Slice 3, M1 conformance and native sink bundles. The old records are kept beside them.
4. `main` at `9a9a8943` (Goal 20, pull request 65) and at `b2249ea2` (APEX-2, pull request 66) are merged
   into the branch (merge commits, no rebase, no force). No conflict. Neither changed a file of this work,
   and this work changes no file of the APEX-2 package (`proposals/apex2-contract-link-20261119/`; its 8
   pinned files have the digests of its `PINS.json`).
5. After the first scratch-clone regression (section 6): `scripts/exit_silicon_sink.py` pins the SHA-256 of
   the M1 conformance record; the pin follows the new record. And the ghost lemma `WfAt` of
   `impl/finality-core/IssueAuth.dfy` states the premises of `WfOfT` one by one (same statement).

No protected path changed: nothing under `gate/`, `spec/`, `policy/`, `governance/`, `clearing/`, and not
`spec.lock`, `package.json`, `package-lock.json`, `tsconfig.json`. No frozen module changed.

## 3. Every changed suite expectation (B-15, B-16, D-2)

"Old line" is the line in the merged `suite.ts`. No row is deleted. Every old row name is kept.
The merged suite had 115 rows. The new suite has 126 rows: 6 "variant 2" rows, 1 single-use row and
4 store-mode rows are new. The first 13 table rows are the table of the
[unapplied README](../night-shift-20261119/unapplied/README.md); the last 4 rows were not listed there
(B's record names them "D-2 rows"); I read their names and expectations from the suite report of my run.

| Row | Old line | Merged expectation | Proposed expectation | Stronger / weaker / semantic change |
| --- | --- | --- | --- | --- |
| x1 raw INSERT: an outbox row without a settled row | 506 | effects none; the dispatcher refuses: no settled row | the DATABASE refuses the write; store unchanged; effects none | STRONGER (the write never lands). This row is the cause of exit 2 of the merged suite on the hardened tree |
| x2 raw UPDATE before dispatch: amount 100 to 900 | 511 | effects none; refused: outbox intent is not the signed intent | the database refuses the write; store unchanged; the committed signed row (100) is dispatched as usual | STRONGER (write refused). Note: one effect is now sent, the honest one |
| x3 raw INSERT and UPDATE with an attacker's key | 516 | effects none; refused: signature does not verify | the database refuses the write; store unchanged; effects none | STRONGER |
| x3 public-key audit of that changed database | 518 | problems found: more than 0 | the same, on the variant-2 database; a sink that refuses to start counts as 1 problem | INTERFACE ADAPTATION (same claim) |
| x4 replay after dispatch: outbox rows deleted and inserted again | 522 | effects none; nothing refused | the database refuses the DELETE; store unchanged; effects none | STRONGER |
| x5 an emit that fails (crash between the ledger line and the effect) | 527 | effects [rq_x5_2]; nothing refused (the merged at-most-once record) | effects [rq_x5_2]; rq_x5_1 refused: IN DOUBT (1 row) | **SEMANTIC CHANGE** (delivery policy): the loss is reported as in doubt for an operator, not silently counted as sent. Red team C-ATT-18 |
| x6 raw INSERT: a validly signed token for an earlier state | 531 | effects none; refused: token does not continue the dispatched chain | the database refuses the write; store unchanged; effects none | STRONGER |
| x7 raw INSERT: a copy of a committed token under a new request id | 535 | effects none; refused: request id is not the signed one | the database refuses the write; store unchanged; effects none | STRONGER |
| x1, x2, x3, x6, x7 "variant 2" (NEW rows): a file writer that first drops the triggers, recomputes the chain, restores the triggers | new | (none) | the running sink halts; a restart is refused; the dispatcher reports the audit failure; effects none | STRONGER (new coverage) |
| x4 "variant 2" (NEW row) | new | (none) | the sink starts; effects none; nothing refused (the rewritten rows are byte-identical; the ledger stops a second effect) | STRONGER (new coverage; same result as the merged x4) |
| option "single-use on: another transition for a pre-state that has a signed token" | 589 | no token (single use per PRE-STATE) | a token that verifies (single use per charge id and request id; constant `SINGLE_USE_RULE = "per-request"`) | **WEAKER at token level**: two tokens can exist for one pre-state. The sink still commits at most one (TESTED-UNPROVED at the composed level). Reason: the merged rule lets a zero-amount refund freeze a charge (C-ATT-03). Owner item B-15, approved |
| option "another transition for a request id that has a signed token (same pre-state)" (NEW row) | new | (none) | no token | STRONGER (new coverage; holds under both readings) |
| report fields `counts.known_limit_rows`, `owner_decisions_pending` (NEW) | new | (none) | extra report fields | INTERFACE ADAPTATION |
| "store mode: a zero-amount request for a victim's request id on an INVENTED pre-state" (NEW row; decision D-2; C-ATT-30) | new | (none) | refused: core: Refuse | STRONGER (new coverage) |
| "store mode: then the victim's request on the stored state" (NEW row; D-2) | new | (none) | committed | STRONGER (new coverage) |
| "store mode: the settled request id with another candidate on the new stored state" (NEW row; D-2) | new | (none) | refused: attempt completed: use a new request id | STRONGER (new coverage) |
| "store mode: a zero-amount request with a new id on the new stored state" (NEW row; D-2) | new | (none) | committed | STRONGER (new coverage) |

Not changed in the code and now stale: the report field `owner_decisions_pending` and the expectation
text of the single-use row still say "owner decision B-15 pending". The owner approved B-15. I did not
edit these texts, because `suite.ts` is applied unchanged.

## 4. Bundles: old and new

| Bundle | Old SHA-256 (record on `main`) | New SHA-256 | Cause of the change |
| --- | --- | --- | --- |
| Slice 1 (`scripts/exit_slice1.py`) | `c7f2f41c872b5c133d422ef881d36e6c09390f081d555d74761d4890283833f1` | `756babc50f37d8388bd31bda84056ec808c04fc01a8fc9295cf2acfac21300ef` | its inputs: sink, minter, dispatcher, proposer, encoding, suite, the script, `IssueAuth.dfy`; 16 new inputs. Before the `WfAt` edit the bundle was `b8a30595…9cac` |
| Slice 2 (`scripts/exit_slice2.py`) | `2721a293023baf230ecb944ea3ad2a3c02d7be6d82f128f10d07cc2b0f91854e` | the same | no input changed; byte-identical |
| Slice 3 (`scripts/exit_slice3.py`) | `3cdfebfc0ae96adafccc7f417bcd9113aaa63df9c9cd31583983c3b2e11bddb4` | `6b21a487748be891d5f83ffaf56544558c4e705f6cc08c462cb366a73daecc5a` | one reused input: `ts/refund-finality/encoding.ts` (`f96086b1…` to `8b32f673…`); the computed checker id and 19 report digests follow from it; no other field differs |
| M1 conformance (`scripts/exit_m1_conformance.py`) | `f55391dad17a0a4ea707806c59dbac2419df51c692161704af71f0cfe0a11da9` | `91b49423d5377612a99751912e2fd916c0e662e6a088ebeda89dbdfbe2d9b1ce` | its inputs: `minter.ts`, `encoding.ts`, the Slice 1 record, the script itself; five new pinned inputs (`IssueAuth.dfy`, `IssueBytes2.dfy`, `SerModel.dfy`, `keyfile.ts`, `mintmemory.ts`); the compiled module is now the Slice 1 IssueAuth module. Every count field is equal to the old record (field-by-field comparison: 13 differences, all of them digests, the build source and the artifact text). Before the `WfAt` edit the bundle was `0325b191…97d7` |
| Goal 19 native sink (`scripts/exit_silicon_sink.py`) | `1f569fcfc4c87fbeb8d787cee687eb74acde8200c9350d8f0a5959b8cd1c932c` | `f8b85b97d72253da2117d9238d1ac400d496fc2cc87e67a4ecdec0503106faae` | the script pins the SHA-256 of the M1 conformance record as a linked record. Two fields differ: that linked digest and the digest of the script. No test result differs |
| Goal 20 SDK (`scripts/exit_goal20_sdk.py`) | `1e75ab47…` | the same | no input changed; byte-identical (scratch clone) |

Old records, kept: `proposals/forge2-slice1-refund-finality/records/evidence-before-t19-c7f2f41c.json`,
`proposals/forge2-slice3-runtime-certificates/records/evidence-before-t19-3cdfebfc.json`,
`proposals/forge2-m1-conformance/records/evidence-before-t19-f55391da.json`,
`proposals/forge2-native-silicon-sink/records/evidence-before-t19-1f569fcf.json`.
The Slice 1 compiled module is now the IssueAuth module: SHA-256
`fa855506da1333395a2579f3d6bdf6c4b41aa0577d140bd4566666d07cbc44e6` (equal to the module that the red
team recorded). The old module was `e6d5f5e5…06ce` (RefundFinality only). The committed sink module
`ts/refund-finality/core/sinkcore-v6.cjs` (`11ba1f38…79dd`) is rebuilt by the EXIT script and must be
byte-equal.

## 5. The M1 conformance script

Owner item B-15 says that `scripts/exit_m1_conformance.py` and `scripts/demo_gauntlet.py` need the same
module change as `scripts/exit_slice1.py`. The night shift left this undone. A worker made the change; I
read the diff and compared the bundles.

- The true core is built from `impl/finality-core/IssueAuth.dfy` with the footer bytes of
  `exit_slice1.py`. The script still requires byte equality with the module of the Slice 1 record
  (`fa855506…44e6`): observed, not assumed. The driver and the issuer process use this one module.
- The wrong cores keep the old footer and the driver-only path.
- The issuer process gets a throwaway Ed25519 key file (mode 0600, made at run time). No key, key id or
  path is in the bundle.
- No expectation changed. Every count of the new bundle equals the old record: 2466 M1 runs compared,
  1761 finality vectors, issuer answers 410 tokens, 522 "core: Refuse", 828 "shape", 1 "message too
  long"; 0 findings.
- `demo_gauntlet.py`: one module for act 2, required equal to the Slice 1 record; it reads the new exit
  code of `commit_cli.ts` (1 = rejected); its forged token has the D-1 shape (a key id), with the same
  expected refusal ("signature does not verify").

A finding on the way: `IssueAuth.dfy` is near the resource limit of the gate options. In 10 verifying
builds of this session (the worker's count), 9 gave exit 0 and 1 gave exit 4 ("193 verified, 0 errors,
1 out of resource", `IssueAuth.WfAt`). That run came directly after four parallel Dafny processes. The
cause is not known. It happened a second time in the first scratch-clone regression (M1 conformance
evidence: exit 1). Measured (my runs, `--log-format csv`): the resource use of `WfAt` is 757,787 or 757,788 in
ten of ten measured runs; so the rare failure is not a small drift over the limit.
Repair attempt: the body of `WfAt` now states the premises of `WfOfT` one by one. The statement is the
same. Measured resource use: 317,241. The compiled module is byte-identical (`fa855506…44e6`).
NOT shown: that the rare failure is gone. `IssueAuth.Issue` (820,9xx) and `SerModel.Tail1` (814,549) are
also above 80 % of the limit; I did not change them.

## 6. Tests on the hardened tree, with controls (actual exit codes)

Tree W = the branch at `ddcdbd09` (the apply). Tree C = unchanged `main` at `a5133c01`.
Exit 0 = safe; exit 1 = the defect or the stated limit is present. Each run used the pinned Node 24.3.0,
an empty environment, and test keys made at test time. Rows marked (o) are my runs. Rows marked (w) are a
worker's runs; I read the logs of the rows marked (w, log read).

| Test | Tree | Actual exit | Result |
| --- | --- | --- | --- |
| (o) `scripts/exit_slice1.py --case evidence`, first run on the applied tree | W | 1 | `tsc --noEmit` exit 2: 7 type errors in regression files; the suite did not start |
| (o) the same after the two type-only edits | W + edits | 0 | 126 rows, 0 failed; two runs byte-identical; bundle `b8a30595…` |
| (o) the same after the `WfAt` edit (final) | branch head | 0 | 126 rows, 0 failed; two runs byte-identical; bundle `756babc5…`; module `fa855506…` unchanged |
| (o) `exit_slice2.py`, `exit_slice3.py`, `exit_silicon_sink.py`, each `--case evidence` | W + edits | 0; 0; 0 | section 4. The native sink run passed here only because the M1 record was still the old one |
| (o) `exit_silicon_sink.py --case evidence` after the pin change (final) | branch head | 0 | bundle `f8b85b97…` |
| (w, log read) regression runner `regress/run.ts` | W | 0 | 29 of 29 verdicts PASS |
| (w, log read) the same runner at its form before decision D-1 (`219bf0ca`; `run.ts` byte-equal) against the merged sink and dispatcher | C | 1 | control FAILS as required: exactly the 8 known ids fail (X1, X2, X2b, X3, X4, X5a, X5b, X6-Z1); with `--expect-fail` for these 8: exit 0 |
| (w) the runner of W against the merged sink | C | 1 | NOT a valid control: the judge signs tokens with a key id, and the merged sink refuses the honest ones too |
| (w, log read) `db_safeguards_hkey.ts` (B's version for decision D-1; from the owner's untracked `results/`, not in the repository) | W | 0 | 69 rows, 0 failed |
| (w) `db_safeguards.ts` of the repository (`proposals/…/orch-B/h-sink/tests`) | W | 1 | NOT valid: the test predates D-1 and stops while it builds its own tokens |
| (w) 13 key-file tests `kf_*.ts` (D-1) | W | 0 each | PASS |
| (w) 15 minter tests `m_*.ts`, `m2_*.ts`, `m3_*.ts` (D-2) | W | 0 each | PASS |
| (w) `m3_zero_squat_limit.ts` | W | 1 | KNOWN LIMIT, as stated (limit 5) |
| (w) 7 provider tests `p3_*.ts`, new adapter (D-3) | W | 0 each | PASS |
| (w) `p3_rollback_rebind.ts first none` | W | 1 | KNOWN LIMIT B-20 (limit 2) |
| (w) the same `p3_*.ts` with the old adapter (`P_ADAPTER=v1`), 5 runs | W | 1 each | control FAILS as required |
| (w) 12 dispatcher tests `d_*.ts`, `d3_*.ts`; 13 sink tests `s_*.ts`, `s3_*.ts`; `c_att_01`, `c_att_16` | W | 0 each | PASS |
| (w) `s3_kill_commits.ts`, 12 rounds of a real kill | W | 0 | 0 failures (B ran 24 rounds) |
| (w) `p_*.ts` and `p_att28` matrix, idempotent provider "a", both anchors, 14 runs | W | 0 each | PASS |
| (w) the same, provider "a", NO anchor, 14 runs | W | 0: 12; 1: 2 | the two exit 1 (`p_full_param_rebind`, `p_full_restore_new_ids`) are stated limits 1 and 2 |
| (w) the same, non-idempotent control provider "c", both anchors, 14 runs | W | 0: 13; 1: 1 | `p_timeout_retry` exit 1: the provider is not idempotent and pays a retry twice; stated limit 3 (an ASSUMPTION on the provider), not a sink defect |
| (w) the same, provider "c", NO anchor, 14 runs | W | 0: 2; 1: 6; 2: 6 | exit 1: stated limits 1 to 3; exit 2: "the control does not bite" (informational) |
| (w) red team `c25-provider`: `s1_scope.ts collide`, `squat`; `s4_rebind.ts none`; `k1_key_variants.ts` | W | 0 each | PASS; with the old adapter: 1, 1, 1 (control FAILS as required) |
| (w) red team `c28-keyfile/kf_c_own.ts` | W | 0 | PASS |
| (w) red team `c19-dispatch2`: `a1` attack, floor; `a2` remove, deadpid; `a3` kill; `a8` link, case; `a7` with a floor | W | 0 each (8) | PASS |
| (w) red team `c19-dispatch2/a7_full_restore.ts nofloor` | W | 1 | KNOWN LIMIT (limit 1) |
| (w, log read) red team `c21-sink2`, 12 runs; `c24-minter2`, 3 runs | W | 1 each (12); 3 each (3) | NOT valid, NOT counted: these scripts predate D-1 (their token builder has no key id; they start the minter with no key file). The classes are covered on this tree only by B's `d_att17_*`, `s_att2*`, `s3_*` and `m3_*` files |
| (w) five control tries on `main` for classes that need the new interface | C | 3, 1, 1, 1, 1 | NOT valid controls (set-up reasons: `main` has no `core/store.ts`; another module shape) |
| (w, log read) `scripts/exit_m1_conformance.py --case conformance`; `--case evidence` | W + edits | 0; 0 | two runs byte-identical; bundle `0325b191…`; 0 findings; every count equal to the old record |
| (o) `exit_m1_conformance.py --case evidence` after the `WfAt` edit (final) | branch head | 0 | bundle `91b49423…`; the `conformance` part is equal to the old record |
| `scripts/demo_gauntlet.py --flood-mb 16` | W + edits | 1; 1; 3 | (w, log read) run 1: exit 1, the script did not yet read the new exit code of `commit_cli.ts` (repaired in the script). Run 2: exit 1, the pinned Dafny gave exit 4 on `IssueAuth.dfy` (1 out of resource; section 5). Run 3: exit 3 = REDUCED: all three acts ran and every check held, but the memory bound of the flood is not checked below 512 MiB. NOT a pass of the demo. The full demo (default flood) is NOT RUN |
| (o) scratch clone of the pushed branch at `b70900e4` (before the pin and `WfAt` changes), Goal 20's `run_regression.py`: 28 Stage EXIT cases; `check_frozen_pr_gate.py HEAD`; 9 link checks; evidence of Slice 1, 2, 3, Goal 20; M1 conformance; native sink | clone 1 | 0 each (28); 0; 0 each; 0, 0, 0, 0; 1; 1 | M1 conformance: Dafny exit 4, 1 out of resource (section 5). Native sink: LINKED_RECORD, the script pins the old M1 record (section 4). [Record](regression-b70900e4.json) |
| (o) scratch clone of the pushed branch at `64a16246` (final code), APEX-2's `run_regression.py`: 28 Stage EXIT cases; `check_frozen_pr_gate.py HEAD`; 8 link checks; six evidence bundles | clone 2 | 0 each (28); 0; 0 each; 0 each (6) | 28 of 28; 8 frozen modules unchanged; 0 protected paths changed; 0 files of the APEX-2 package changed; the six clone bundles are byte-identical to the tracked records (`756babc5…`, `2721a293…`, `6b21a487…`, `91b49423…`, `f8b85b97…`, `1e75ab47…`). [Record](regression-64a16246.json) |
| (o) `check_links.py HEAD` on this report and on the new graph file | branch | 0; 0 | after the documents commit |
| hosted `gate/pr_check.py` | pull request | see the pull request | expected 3 (UNSUPPORTED) |
| the full demo (default flood); spec-conformance 5,000 sequences; the kill loop with 24 rounds; x1 to x6 and `k_judge_blindspots.ts` standalone; red team `a27_head`, `a6_fsize`; any power-loss test; any HOL or Holmake case; Stages 7, 9, 10 | | NOT RUN | not run in this work; B's runs stand as B's own |

The worker's summary of its valid runs on W: 112 with exit 0; 14 with exit 1, each a stated limit; 0 defects.
I did not recount these two totals; the per-row exits above are from the batch log.

## 7. The one fresh-context review (it got the diff, not my conclusions)

Result: no fail-open path found by reading. No code was run by the reviewer. Not read: the inside of
`sinkcore-v6.cjs`, `spec-conformance/`, most `m2_`, `m3_`, `p_`, `s_`, `d_` regression files.

| Id | Severity | Finding | State |
| --- | --- | --- | --- |
| F1 | MEDIUM | Two minter processes with the same key file, store and memory file can each sign a different valid token for one (charge id, request id): no exclusive lock on the mint memory file. The sink still commits at most one. Needs an operator error, not an attacker | LEFT: new known limit 9. I checked by `grep` that no lock exists; I did not run two processes |
| F2 | LOW | An fsync error after a full write of a mint record can make the next minter start refuse ("a key appears twice"). Availability only | LEFT |
| F3 | LOW | The checker id and the bundle did not cover `keyfile.ts` and `mintmemory.ts` | PARTLY FIXED: `mintmemory.ts` is now a bundle input (`keyfile.ts` was one). The checker id of `minter.ts` still covers only the core module, `encoding.ts` and `minter.ts`: LEFT |
| F4 | MEDIUM | `demo_gauntlet.py` of the applied diff reported a record-equal module digest for an issuer that ran another, unpinned module | FIXED: one module, required equal to the Slice 1 record |
| F5 | LOW | Suite rows x1, x3, x6, x7 (variant 1) count ANY database error as "the database refuses the write" (the INSERT also lacks NOT NULL columns); the x3 audit row passes on any constructor error; `harness.ts` `twoWriters` passes when the attacking writer is itself refused | LEFT. The "variant 2" rows and the runner's X5a, X5b, X6 cover the writer that drops the triggers |
| F6 | LOW | The "single-use on" suite rows run the minter in test mode (no store). The production rule (store and memory file) is covered only by `kf_restart_one_token.ts` and the `m_*`, `m3_*` files, which the EXIT script does not run | LEFT |
| F7 | LOW | `heavy_spec.sh` has the default `LOCKS=/Users/USER/…` (a placeholder, so its lock-file check never refuses); `regress/README.md` shows an `--expect-fail` command that is stale for the hardened sink | LEFT |

## 8. Known limits (kept from B's final record; none is hidden)

1. A full restore of every local file WITHOUT an outside ledger floor sends effects again (my worker's
   run of the red team's `a7_full_restore.ts nofloor`: exit 1). Rollback resistance needs BOTH anchors:
   the outside head and the ledger floor (D-5).
2. Without anchors, a rollback plus the same request id with another amount is paid again (B-20).
3. The provider is a FAKE in every test. Every provider property is an ASSUMPTION (key window,
   idempotent key, honest answers). After the key window a request id can pay twice.
4. Exactly-once delivery is NOT claimed. A failed emit is IN DOUBT for an operator.
5. A zero-amount mint on the real state with a victim's request id takes that id (zero-amount squat).
6. A deleted or restored mint record file brings a second valid token back after a restart (lost mint
   record). Power loss is NOT TESTED.
7. The key-file check covers only the last path part. A same-uid attacker and a party that can create
   files in the database directory are OUT of the claims.
8. No migration: stores and tokens of earlier formats are refused. A deployment that holds a store of
   the merged format must start a new store.
9. NEW (review F1): two minters on one memory file are not excluded by a lock.
10. "At most one effect per request id" for the composed system is TESTED, not proved.
11. The red team did not re-test the last judge rebuild, and its `c21` and `c24` scripts do not run on
    the tree after D-1.

Labels: every test row is TESTED-UNPROVED. The Dafny runs inside `exit_slice1.py` (IssueAuth and
ShellCoreV6 verify and build with exit 0) are MACHINE-CHECKED at source level about MODELS; no proof
binds them to the running TypeScript. Provider behaviour, anchors kept fresh by the host, and a single
writer are ASSUMPTIONS. A proof of the sink is MISSING.
