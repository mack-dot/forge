# Step D6: a real crash and race test of the Slice 1 finality sink (Y6, Opus; pinned Node; a finite test)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y6 report: crash-recovery and race test of the Slice 1 finality sink (links U7, U3). This is a finite test, NOT a proof.

**Findings**
1. The real sink had no violation in 486 SIGKILL runs (498 with the tsx cross-check). Every reopen held all invariants: remaining = 1000 − sum of committed refunds; each settled row has exactly one outbox row with the same id and amount; no partial row; `integrity_check` = ok; `audit()` = []; settled rows are a prefix of the token chain; every replay returned `replayed` with a byte-identical table dump.
   - 206 kills hit an open transaction: the `-journal` file was still there at reopen, and the reopen rolled it back.
   - In 26 runs the commit was durable but the child died before it reported the commit. A retry of the same token answers `replayed`, so a caller can recover.
   - In 90 contender runs, a second process waited on the lock and then committed once its holder was killed. A killed holder leaves no stale lock.
2. Races: 20 rounds (K = 2×5, 5×5, 10×5, 25×3, 50×2). Every round ended with exactly 1 commit and K−1 `stale` answers, and no process was late for the common start. For K = 10, 25 and 50, 50 concurrent replays of the winning token were all `replayed` and left the store unchanged. **K = 100 did NOT run.** Each child needs about 46 MB, so 100 children need about 4.6 GB. Free plus inactive memory was about 3.3 GB, swap was 8.5 of 9.2 GB used, and another session's HOL job was running.
3. **Zero amount (reproduced).** The real issuer signs amount 0, and the spec allows it (`0 <= amount`). A zero-amount token has post = pre, so its pre-state hash still matches after it commits.
   - Smallest reproduction: fresh store S0 (remaining 1000); commit `rq_zero_1` … `rq_zero_5` (amount 0, pre = S0). All 5 return `committed`, with 5 settled rows and 5 outbox intents of amount "0". Remaining stays 1000 and the audit passes.
   - A race of 5 zero tokens: all 5 commit. "Exactly one commit per pre-state" is FALSE for amount 0.
   - The same request asked again gives the same token text (Ed25519 is deterministic), and the sink answers `replayed`. The same id with another reason is `rejected` ("request id is already settled with another token").
   - The money invariant still holds. The effect is outbox rows of amount 0 with no limit.
4. **Negative controls: the harness detected all three broken copies.**
   - Two transactions, killed between them: 10 of 10 runs detected. Smallest case: one commit, kill after the first COMMIT. Remaining is 998 with 0 settled rows, and the audit reports "stored state is not the end of the chain".
   - Two transactions, random kills: 20 of 52 killed runs detected (only kills that land between the two transactions show it).
   - No pre-state check: 10 of 10 commit, in 3 of 3 rounds.
   - Pre-state checked before the transaction: 3 to 10 commits in each of 6 of 6 rounds.
5. **Storage settings (measured):** Node 24.3.0 bundles SQLite 3.50.1. The settings are `journal_mode=delete` (rollback journal), `synchronous=2` (FULL) and `fullfsync=0`. The sink sets none of these: they are the defaults.
   - READ, not tested: with FULL and the rollback journal, SQLite promises atomic commits across a process crash. On macOS, `fsync` without `F_FULLFSYNC` may not empty the drive's write cache, so a committed transaction may be lost at power loss or OS crash.
   - **kill -9 does NOT test power loss.** Power loss is still open.

**Method.** I obtained the tokens from the real issuer (`minter.ts`, run with tsx exactly as the demo does). Its core is a copy of the demo build, SHA-256 `e6d5f5e5…`, equal to the Slice 1 record. No Dafny ran. The sink ran unchanged: an esbuild bundle that only strips types, cross-checked with tsx on the `.ts` source. The controlled pause works by patching `node:sqlite` inside the child process only. Repository files are unchanged (`shasum -c` OK; `git status` shows nothing).

**Files** (folder `<session scratch folder>/m1b/Y6/`)
- Scripts: `harness.py`, `mint.py`
- Sources: `src/child.ts`, `src/checker.ts`, `src/init.ts`
- Broken copies: `broken/sink-{twotx,nocheck,toctou}.ts`
- Build outputs: `build/*.cjs`
- Results: `results/{kill-points,kill-external,kill-self,race,zero,negative,crosscheck}.json`
- Data: `logs/`, `db/`, `cfg.json`, `tokens.json`

**Commands run (actual exit codes)**
- `python3 -I mint.py` → 0 (issuer exit 0)
- esbuild bundles → 0
- `harness.py kill-points` → 0 (220 kills)
- `harness.py kill-external` → 0 (126 kills)
- `harness.py kill-self` → 0 (140 kills)
- `harness.py race` → 0 (K=100 skipped by the memory guard)
- `harness.py zero` → 0 (it records the behaviour; it does not reject it)
- `harness.py negative` → 0 (exit 0 means every broken copy was detected)
- `harness.py crosscheck` → 0
- One `rm -rf` of old smoke stores was refused by the safety check. No other effect; the old stores are still in `db/`.

**Could not determine:** behaviour at power loss or OS crash; the K=100 race; a kill in the middle of SQLite's own C commit code (random kills reach that code only by chance; I cannot confirm that one did).

| step | status | evidence or blocker |
|---|---|---|
| 1 kill/recovery ≥300 | DONE (486) | kill-points/-external/-self.json, 0 violations |
| 2 race K≤100, 50 replays | PARTIAL (K≤50) | race.json; memory blocker for K=100 |
| 3 zero/repeat | DONE, finding | zero.json |
| 4 negative control | DONE, all detected | negative.json |
| 5 durability settings | DONE (measured and read) | delete/FULL/fullfsync=0; power loss untested |

| link id | proposed class | evidence |
|---|---|---|
| U7 | TESTED-UNPROVED (process crash only); ASSUMPTION for power loss | 486 SIGKILLs, 0 violations; negative control detected |
| U3 | TESTED-UNPROVED | races K≤50; replays; zero-amount exception recorded |

M1-B stays OPEN; end_to_end=false.
