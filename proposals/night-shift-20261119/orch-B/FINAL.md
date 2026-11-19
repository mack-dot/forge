# Orchestrator B (trust track): FINAL record of the night shift 2026-11-19

Written 2026-11-19T17:48:45Z (from `date -u`). Branch `nightshift/B-trust` (from 985f5eaf), pushed to origin. Nothing is merged. No protected file changed. No pull request opened. Stage labels unchanged: M1-B OPEN; `end_to_end=false`.
Details: `unsure.md` on the branch, entries U530 to U631; owner items B-1 to B-20 and decisions D-1 to D-3 in `results/night-shift-20261119/OWNER_REQUIRED.md`.
Classes: MACHINE-CHECKED (a Dafny run of mine with exit 0), TESTED-UNPROVED, ASSUMPTION, MISSING. "RT" = the red team (Orchestrator C), its own runs.

## (a) Fixes on the branch

All regressions live in `tests/refund-finality/regress/`. Usage: `node --import tsx <file> <tree> <compiled issuer module>` (pinned Node 24.3.0); exit 0 = safe, 1 = defect. "My run" = on the branch tree at the named commit.

| Fix | Commit | Regressions and actual exits (my runs) | RT re-test |
| --- | --- | --- | --- |
| Line splitter and client id in the proposer (C-ATT-01, 16) | de71cf4d, 216dfbe2 | c_att_01, c_att_16: 0 | PASS |
| Hardened sink: request identity, charge binding, cumulative limit and one-statement commit in the database schema (both duplicate-effect counterexamples; C-ATT-02, 04, 06, 10, 11, 12, 20) | b7fd6be8 | db_safeguards 69 PASS, exit 0; regression runner (X1 to X6 and controls) on the hardened tree: all PASS, exit 0; on the merged sink the eight known ids FAIL (exit 0 only with the expected-fail list; exit 1 without) | PASS at 608b5165 for a writer that drops triggers too (02, 04, 06, 10, 11, 12, 20) |
| Dispatcher: claim rule, owned lock, in-doubt records, dispatch witness, CLI exit codes (C-ATT-17, 18, 22; C-HOST-01 to 05, 07) | f08a21c1 | ten d_*.ts: 0 | PASS for 17, 18 (fresh scripts at 88ae6cbf); C-ATT-22 and C-HOST items: not re-tested by RT |
| Sink, second change: old-row check while running, outside-head interface, planted files, hard links, durability settings, intent bound (C-ATT-21, 23, 24, 25, 26, 27) | 88ae6cbf | eight s_*.ts: 0 | PASS: 23, 24, 26; 25 only WITH the dispatcher's outside head; 21 and 27 rest on named assumptions (below) |
| Sink and dispatcher, third change: journal classifier, recover rule, ledger hash chain, identity by inode (C-ATT-33 to 37) | f67c5c16 | s3_*.ts and d3_*.ts (six): 0; real kill, 24 rounds: 0 failures, exit 0; RT crash script 20 rounds: exit 1 before, 0 after | PASS: 33, 34, 35, 36, 37 |
| Judges rebuilt twice (C-JUDGE-01 to 03; three later survivors) | cf242303, 7667574c | runner 29 of 29, exit 0 on the head; the three surviving inputs exit 1 in my worker's runs (not repeated by me) | C-JUDGE-02, 03 PASS at cf242303; the second rebuild is NOT re-tested by RT |
| D-3 provider adapter: key = digest of namespace, charge id, request id, amount; every answer compared with the committed row (C-ATT-41, 42, 44) | e9c79928 | p3_scope_collide, p3_key_squat, p3_keytext, p3_in_progress: old adapter 1, new adapter 0; p3_rollback_rebind with both anchors: 0 | PASS: 41, 42 (wrong booking), 44; key variants: no collision |
| D-2 minter: a refusal records nothing; only a minted token and the settled row close a request id (C-ATT-38, 39, 40; earlier 03, 15, 29, 30 for an invented state) | 219bf0ca (earlier 608b5165, 370ff65c) | five m3_*.ts: 0; all m_ and m2_: 0; m3_zero_squat_limit: 1 by design (a known limit) | PASS: 38 (spray and oracle), 39, 40; earlier 03, 15, 29, 30 |
| D-1 key file, key id, sink allowlist, durable mint record (C-ATT-05) | b22b6b34 | thirteen kf_*.ts: 0 (symlink, modes, other owner, FIFO and directory, unknown, retired and mismatched key id, old format, allowlist, no environment key, positive controls, restart same key, restart one token) | PASS: C-ATT-05 closed; RT's own key-file script exit 0 twice; my 13 tests exit 0 in RT's runs; key-id substitution and retired ids were tested by my tests only |

Whole-tree checks at b22b6b34 (my runs): the adapted Slice 1 suite: exit 0, 126 rows, 0 failed (`orch-B/h-suite/logs/B-full-5.*`); regression runner 29 of 29; spec-conformance 5,000 sequences x 3 modes on the hardened sink (at f08a21c1): no violation, exit 0; zero-amount refunds succeed in every run.
The suite passes only with CHANGED expectations that the owner has not accepted (B-15, B-16): six hostile-write rows, six new rows, the in-doubt delivery policy, the per-request rule, D-2 rows. The merged 115-row suite does not complete on the hardened tree (exit 2 at the first raw tamper row, as predicted).

## (b) Dafny proofs

Command for every row: `.toolchain/dafny-4.11.0/dafny/dafny verify --solver-path <z3 4.12.1> --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects FILE.dfy`, through `orch-B/tools/dafny_locked.sh`. All are source-level results about MODELS. None is bound to the running TypeScript by proof.

| File (on the branch under `impl/finality-core/` or in evidence) | Verified, exit | What it says | Hypotheses |
| --- | --- | --- | --- |
| IssueAuth.dfy (issuer rule after D-2) | 194, exit 0 (at 219bf0ca) | one byte string per (charge id, request id); a refusal changes nothing; a settled id is not issued again; spray is harmless | the stored state, settled flag, pre-state hash and memory are FREE inputs; binding to the real store is unproved (STORE-READ, G-H); KEYID-GLUE is outside the model |
| IssueOnce.dfy (first per-request rule; superseded) | 160, exit 0 | superseded by IssueAuth | same class |
| ShellCoreV6.dfy (sink step that evaluates the approved relation on the stored charge) | 192, exit 0 | a committed step satisfies the approved relation | reading CTX-SINK (governing context = stored charge; owner decision B-10) |
| ControlsBytesV6, TopV6Export, KeyedV6 (byte-level composed lemma, V6) | 2352, exit 0 | approval of committed effects with no signing hypothesis at layer 0 | H1B and B5 at layer 1; A6b or A6x for the export bridge; hash glue G-H |
| ControlsBytesV3, RefineHashV3; TopFromExport, IssuerLink, KeyedHash, RefineTraceV3 | 1871; 2185, 2236, 2325, 1889, exit 0 | byte-level lemma over a hash-comparing core | A2p, H1B, B5, A4 |
| ExportBridge, SliceSafetyFromExport | 1823; 1892, exit 0 | the exported contract equals the flat contract | A6x |
| Restart, KeyedStore, AttackRestart | 1686; 1820; 1831, exit 0 | rollback and a forged initial state pass any database audit (a negative result) | none (it is the reason for the outside anchor) |
| Anchor.dfy (row-log head) | 61, exit 0 | a rollback to a prefix is detected against an outside head | ANCHOR-MONOTONE; a model only |
| SliceTheorem, SliceSafetyV2OnBytes, SinkCoreReqId, SinkCoreV3, SliceSafetyV3, MultiCharge and the review files | see ROADMAP.md, night-shift parts 1 to 3 (each row has its count and exit 0) | phase 1 chain | listed there per row |

Corrections that stand: the global IdealMac assumption is impossible for a real signature scheme (U478); byte-layer injectivity is false for the real token (phase 1; see ROADMAP part 2); the IssueAuth theorem does not say "signs only on the state the sink stores" (U624).

## (c) Open items, as known limits

Money safety:
1. Full restore of every local file WITHOUT an outside ledger floor: effects are sent again (RT: still exit 1). Rollback resistance is claimed ONLY with both the sink's outside head (kept fresh by the host) and the ledger floor (D-3, U623). ASSUMPTIONS: ANCHOR-OUTSIDE, ANCHOR-FRESH, SINGLE-WRITER.
2. Without anchors, a rollback plus the same request id with another amount is paid again, because the amount is in the provider key by decision D-3 (owner item B-20; `p3_rollback_rebind first none` exit 1).
3. Provider layer: tested with a FAKE provider only. Every provider property is an ASSUMPTION (key window, idempotent key, honest and complete answer fields, account scope, durable state). After the key window a request id can pay twice.
4. Exactly-once delivery is NOT claimed. A crash between the effect and the done line leaves an in-doubt record for an operator.
5. A zero-amount mint on the REAL state with a victim's request id takes that id (no caller identity; `m3_zero_squat_limit` exit 1).
6. A deleted or restored mint record file brings a second valid token back after a restart; then only the sink's rule (one settled row per request id) holds (MEMORY-FILE-INTACT). Power loss is NOT TESTED for the sink, the ledger or the mint record (FS-SYNC).
7. The key-file check covers only the LAST path part: a symbolic link in a PARENT directory of the key path is followed, and a hard link to another private file of the same user starts (KEY-DIR-TRUSTED: the directories above the key file must be writable only by the minter's user). A party that can create files in the database directory, a same-uid attacker, and a file writer who recomputes the unkeyed row chain without an outside head are OUT of the claims (DIR-EXCLUSIVE, SAME-UID).
8. No migration: stores of earlier branch formats and old-format tokens are refused.

Gate:
9. The JavaScript bound checker is ADVISORY ONLY. It accepts modules from verified Dafny files that throw, run for a minute or exhaust memory (my runs: two breaks; RT: two more). Do not adopt B-17 as a safety argument.
10. Subset rule 3 admits a bodiless lemma (my run) and is superseded; rule 2 was bypassed. No static rule tonight is a sound safety argument for an admitted module.
11. Unfinished lead (a stopped worker's runs, not mine): supervised execution that fails closed plus a recomputation of the answer by the proved checker through the pinned core; 256 supervised calls, 0 unsafe authorizations; the known break sets were NOT RUN under it; no diff. Its readings of today's code (no re-check after the decision in ts/refund.ts; the core loaded in the key's process; no timeout in the gate) are to be checked.
12. The gate options "warnings are errors" and the audit step are load-bearing (a bodiless `ensures false` lemma verifies).

Judges and tests:
13. Three defective inputs passed both judges at cf242303 (RT). The rebuild at 7667574c fails them in my worker's runs; RT did not re-test it; the RT's full blind-spot script (17 other inputs) is NOT RUN on it. Named remaining trust: an effect through a channel the parent does not own; tampering inside the child; hidden code loading.
14. "At most one effect per request id" for the composed system is TESTED, not proved.
15. The differential against the V6 core gave no result (harness error). scripts/exit_m1_conformance.py is unchanged and cannot start the new minter (unapplied diffs exist).
16. Unverified reading leads of the RT on f67c5c16 (nothing run): a journal that is a symlink or directory blocks recover for ever; a crash during the first schema creation; a copy failure inside recover without a log line; many ledger lines with one `prev`.

Owner decisions still open: B-12 (meaning of request-open; POST-RULE), B-13 (id length and NUL limits), B-14 (anchor operation), B-15 and B-16 (changed suite expectations), B-17 (gate route), OQ-H2-2 of B-18 (store mode only), B-20 (amount in the provider key).

Record of my own errors tonight: estimated time labels (corrected); set-up errors recorded as "not a result"; one test with a cut reason text; a sync step that skipped path sanitising (one file with a temporary path that holds the local user name is in two earlier commits; fixed forward; history not rewritten).
