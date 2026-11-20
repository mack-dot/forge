# Independent review of 2026-11-20: record and disposition

[REVIEW.md](REVIEW.md) is a byte-exact copy of the review that the owner received on
2026-11-20. It was written read-only against `origin/main` `33055a59`. Its line numbers
refer to that commit. SHA-256 of the copy and of the source file (both measured with
`shasum -a 256`):
`06367be466d307ebe0caf8368036ac0f12c619ce12e78876eb8c3ae69e68ff70` (20,180 bytes).

The reviewer is a worker of the same model family on the same machine. It is not an
independent party in the sense of a separate organization. Entries: `unsure.md` U880 to
U883. `end_to_end=false`. M1-B OPEN. Nothing here is a proof.

## Claims table: disposition

"Verified" means that this pull request read the cited files on `33055a59` and found the
reviewer's statement true. It does not mean a re-run of a test or a proof.

| # | Claim | Verified? (evidence read) | Action |
| --- | --- | --- | --- |
| 1 | "Humans approve intent (specs), not code." | yes: [TOP_LEVEL_GRAPH.md](../m1b-mission-20261119/TOP_LEVEL_GRAPH.md) S1 (MISSING, line 40), E2, E4 (lines 101, 103), blocker 5 (line 143); [refresh](../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md) line 198 (`main` NOT protected, HTTP 403) | this pull request: the tagline is an aim; the README says that S1 and enforcement are missing |
| 2 | "public research prototype" | yes: `gh repo view mack-dot/forge --json visibility,licenseInfo` gave `PRIVATE`, `licenseInfo: null` (exit 0, 2026-11-20) | this pull request: "research prototype (private; no licence)"; License section corrected |
| 3 | Stage 8 `source_proof` | yes: `wc -l` gives 64 lines for `spec/refund/RefundSpec.dfy` and 15 for `impl/Refund.dfy` | no change needed; the README top now states the size |
| 4 | Slice 1 sink counts | yes: [refresh](../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md) lines 77, 232; [E1 log](../night-shift-20261119/orch-C/c3-identity/logs/e1_two_effects_one_reqid-merged.log) and [E2 log](../night-shift-20261119/orch-C/c3-identity/logs/e2_cross_charge-merged.log): `exit=1`, two refunds for `rq_1`; `git log` of `ts/refund-finality/sink.ts`: last change `136ad0bf` (#45) | this pull request: the Slice 1 row names the defect; the sink is NOT edited (team T19) |
| 5 | Round 4 "three independent reviews" | yes: refresh lines 31-32 ("separate workers of the same model family on the same machine"); graph E2 and blocker 5 | this pull request: wording changed; the row states that nothing enforces the rule on `main` |
| 6 | Stage 7 | not re-checked here | no change |
| 7 | M1 row | not re-checked here | no change |
| 8 | "PROVED CORE" | yes: quickstart lines 197-203 (three bullets after "only two decisions"); `src/airlock/verbs.rs` line 169 re-checks amount and reason natively | this pull request: quickstart and `src/airlock/PROTOCOL.md` wording. The `.rs` comments are DEFERRED to the engine pull request (see below) |
| 9 | APEX-2 wording | not re-checked here | no change |
| 10 | 70 copies | not re-checked here | no change |
| 11 | "Run it" | yes: README on `33055a59` has no `forge-airlock`, `sdk/` or quickstart link | this pull request: new README top; the old commands sit under "Run the proof-gate research stages" |

No claim of the review was rejected. One precision: exploit E2 uses two stores and gives
two refunds for one (charge, request id) pair; E1 gives two refunds for one request id on
one store.

## "PROVED CORE": where the label stays, and why

The Goal 20 evidence bundle (`scripts/exit_goal20_sdk.py`, list `SUBJECT`, lines 94-97)
hashes `docs/quickstart-5min.md`, `src/airlock/PROTOCOL.md`, every `src/airlock/*.rs`
file, both SDK files, `bin/forge-airlock`, `run_demo.py` and the tests. Its `subject` key
records each SHA-256. So this pull request CHANGES the subject digests of
`docs/quickstart-5min.md` and `src/airlock/PROTOCOL.md`, and a new `--case evidence` run
would not give the tracked bundle bytes. No new evidence run is made here.

Left unchanged, and listed:

- `src/airlock/main.rs` line 6, `src/airlock/verbs.rs` lines 162 and 252: comments.
  DEFERRED to the engine pull request (the `.rs` files are bundle subjects, and branch
  `apex1/native-cosign` also edits both files).
- `bin/forge-airlock` lines 6-7, `src/airlock/node/booking_check.cjs` line 11,
  `src/airlock/py/diff_policy.py` lines 29, 84, 515: bundle subjects; line 84 and 515 are
  printed output.
- `examples/unbreakable_store/run_demo.py` lines 7-8, 63-64 and
  `tests/airlock/test_sdk.py` line 241: the test pins the printed label.
- `scripts/exit_goal20_sdk.py` lines 395, 1001, 1004: the bundle labels.
- `ROADMAP.md` line 71 and `unsure.md` line 19716: past records (append-only).

## Defects D1 to D8 and other items

| Item | Handled by |
| --- | --- |
| D1 engine in the caller's trust domain | other pull request (not in this one): isolation design (documents) |
| D2 pins checked once by path | other pull request (not in this one): engine hardening, stacked on `apex1/native-cosign` |
| D3 shared key and request-id namespace | other pull request (not in this one): engine hardening |
| D4 O(N) WAL re-read | deferred (performance); not handled |
| D5 known-defective Slice 1 sink | other pull request (not in this one): team T19, branch `feat/t19-hardened-sink` |
| D6 cosign verdict closes a lease | other pull request (not in this one): engine hardening |
| D7 ratchet and WAL corruption | other pull request (not in this one): engine hardening |
| D8 hand-written primitives; SDK divergence | not handled; OPEN |
| No CI for the engine | other pull request (not in this one): a CI proposal |
| Licence and packaging | owner decision: [DECISION_NOTE_LICENCE_PACKAGING.md](DECISION_NOTE_LICENCE_PACKAGING.md) |

None of these is fixed by this pull request.
