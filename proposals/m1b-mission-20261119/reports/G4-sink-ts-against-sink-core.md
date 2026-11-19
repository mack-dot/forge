# Step G4: the real sink.ts against the Dafny sink core: the request-id gap by a run, a differential test, what a proof needs (Z4, Opus; pinned Node and Dafny; repository code unchanged)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z4 report (M1-B wave 5, links U5b and X16)

**Findings**
1. **The request-id gap is real in the code, and it is a defence-in-depth gap. It is not an open hole.** I ran it. The unchanged `sink.ts` commits a token whose `body.requestId` is `rq_body` and whose `intent.requestId` is `rq_victim`, when a key the sink trusts signs it.
   - The settled row and the outbox `request_id` show `rq_body`. The outbox intent shows `rq_victim`.
   - Then an honest token for `rq_victim` also commits. The outbox now holds two intents that both carry request id `rq_victim`.
   - `audit()` returns `[]`. The unchanged `dispatcher.ts` sends both effects.
   - Smallest reproduction: one signed token on S0 with the two different ids. It commits. Then a second token for the intent's id commits too.
   - **What an attacker needs:** the signing key, or code execution inside the issuer. That is already total compromise, because the key can sign any post-state.
   - **The real issuer cannot sign such a token.** The proof of `RefundFinality.Check` guarantees `token.requestId == t.request.requestId`. `Authorizes` requires `t.intent == Intent(pre.chargeId, t.request.requestId, …)`. `minter.ts` copies the body from Check's result and checks it again. In my run, the real minter (recorded core e6d5f5e5…) refused all four mismatched transitions with "core: Refuse": other id, empty id, a change of case only, and a trailing space. The control transition got a token.
2. **The differential test found NO divergence between the real `sink.ts` and the compiled `SinkCore.Step`.** Seed 20261119:
   - Plain: 2,000 sequences, 12,998 steps (7,511 commits).
   - Fault-1: 500 sequences, 293 faults injected.
   - Fault-2: 500 sequences.
   - Interleave: 500 sequences (357 with B first, 143 with A first).
   - Seed 7, plain: 2,000 more sequences, 0 divergences.
   - 16 directed cases, all equal. This includes the mismatch token: **the core commits it too**, because `Step` has no request-id check. The core's safety comes only from A1, A2 and A5. A test key violates A1 (IdealMac), so the proved theorems do not apply to that token.
3. **The negative controls diverge, but only nocheck diverges in sequential mode.**
   - nocheck: 665 of 2,000 plain sequences diverge. Smallest: one stale token.
   - twotx: 0 in plain mode; 233 of 500 in fault-2 mode. Smallest: one valid token, then a valid token with the fault. The state changed but no settled row and no outbox row were written.
   - toctou: 0 in plain and fault modes; 276 of 500 in interleave mode. Smallest: 2 steps. A commits on a stale pre-state.
   - So a sequential-only test does not detect the crash bug or the race bug.
4. **Fix tested on copies.** I patched a copy of `sink.ts`. I also made a copy of SinkCore with the same check after the signature check (new `ReqIdMismatch`). Results:
   - The patched sink against the patched core: 0 divergences in all three modes.
   - The real sink against the patched core: 797 of 2,000 diverge.
   - The patched core verifies (exit 0, 56) only after I weakened its contract. `StepRefinesCommit` now requires `IdealMac(s) && MinterSound(s.minted)`. In `SinkCommit`, Rel and the commit-iff now hold only under that condition. `CommitAt` gets the same new requires. Without these changes it fails (exit 4, on the iff). This is a DRAFT; it changes no link.
5. **Task 4: it depends on the command.** In Dafny 4.11, with the same gate options:
   - `dafny verify` gives 56 rows: 28 under `SinkCore` and 22 under `FinalityProtocol`. There are NO `SinkCore` rows for the 15 inherited lemmas.
   - `dafny build --target js` gives 71 rows: it adds `SinkCore.CommitPreservesInv`, `CommitKeepsChain`, `CommitKeepsDistinctIds`, `CommitKeepsLogSound`, `CommitKeepsOutboxIsLog`, `CommitKeepsSettledIsLog`, `AcceptedClaimSatisfiesSpec`, `ForgedTagRejected`, `HonestCommitSettles`, `InitInv`, `InvMeaning`, `MintPreservesInv`, `OtherSpecOrCheckerRejected`, `ReplayRejected` and `StaleStateRejected` (all correctness, all Passed).
   - In both runs, 7 inherited well-formedness rows (for example `Chain`, `LogSound`, `InvMeaning`) appear only under `FinalityProtocol`.
   - The orchestrator's recorded "56 verified" is the run without the instance re-check. GUESS: the abstract proofs hold for every instance, but that is a meta-argument, not a row.

**Task 3: what a proof of the link needs (READ and GUESS).**
- **Option A (recommended): compile `Step` from Dafny and keep TypeScript as glue.** About 120 of the roughly 150 lines stay in TypeScript: the decoder, the Ed25519 call, the hash-to-value map, and the SQLite transaction with its three writes. The glue must not decide, reorder or skip a check, run caller code, or write outside the transaction. It still rests on A3, A4, A5 and the unproved decoder (K1). If the token carried the pre-state VALUE (the F2.7 plan), A4 would go away.
- **Option B: prove the TypeScript itself.** There is no toolchain in the repository for that.
- **Unapplied diff for `sink.ts`:** `<session scratch folder>/m1b/Z4/patched/sink-reqid.diff`, SHA-256 `0f111954bcfa05c8d99a35cd003d4f2ac16a422a818b036c51c757da5035a45e`. It has two changed lines: the commit check and the audit check. In a `patch --dry-run` the first version applied cleanly; I did not dry-run the final version.
- **Test:** `repro.ts` reports FAIL on the real `sink.ts` and PASS on the patched copy.
- **Core diff (draft):** `<session scratch folder>/m1b/Z4/patched/SinkCore-reqid.diff`, SHA-256 `bddb4c2d…`.

**Files I wrote** (all in `<session scratch folder>/m1b/Z4/`):
- `lib.ts`, `repro.ts`, `diff.ts`
- `sinkcore.cjs` (built `sinkcore.js` f9bf8faf…), `sinkcore-reqid.cjs`, `model.cjs`
- `broken/`, `patched/`, `core-reqid/`
- `results/*.json`, `logs/*` (CSVs: `logs/sinkcore-verify.csv`, `logs/orig-verify.csv`)

I changed no repository file. The repository already showed changes when I looked (TRACKER.md and new drafts and reports). Other agents made them, not me.

**Commands run (actual exit codes)**
| command | exit |
|---|---|
| `dafny build` SinkCore, first try (fnm Node could not load bignumber.js) | 3 (71 verified) |
| `dafny build` SinkCore with the pinned Node | 0 (71) |
| `dafny verify` SinkCore, original | 0 (56) |
| `dafny verify` core-reqid, attempts 1, 2, 3, 4 | 4, 4, 0, 0 |
| `dafny build` core-reqid | 0 (71) |
| `repro.ts` | 0 (real FAIL, patched PASS) |
| `diff.ts` on the real sink, all modes, both cores | 0 against the original core; 1 against core-reqid |
| `diff.ts` on the broken copies and the patched copy | 1 where the expected divergence occurs |

Core-reqid used 4 Dafny verification runs; the 4th repeated the passing 3rd version to get its CSV.

**What I could not determine:** why `verify` and `build` give different row sets. I did not test power loss, real SIGKILL, or a downstream processor that keys on `intent.requestId`.

| step | status | evidence or blocker |
|---|---|---|
| 1 request-id gap | DONE | `results/repro.json` |
| 2 differential | DONE, 0 real divergences | `results/diff-*.json` |
| 3 proof needs and diff | DONE (draft) | `patched/*.diff` |
| 4 CSV rows | DONE | 56 rows from verify, 71 from build |

| link id | proposed class | evidence |
|---|---|---|
| U5b | TESTED-UNPROVED | 2,000×2 plain + 1,500 fault and interleave sequences, 0 divergences; negative controls detected |
| U5a | MACHINE-CHECKED (under A1, A2, A5); the instance re-check appears only in the build run | CSV |
| X16 (request-id binding at the sink) | ASSUMPTION (rests on the issuer key plus the proved Check) | `repro.json` |
