# Step D7: a Dafny sink core proved against the protocol model (Y7, Opus; pinned Dafny)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y7 report (links U4, U5, U8, X16). M1-B is still OPEN. `end_to_end=false`. Stage 9 is still deferred.

**Findings**
1. I wrote `SinkCore.dfy`, an executable Dafny sink core. The pinned Dafny verifies it with the gate options: exit 0, "56 verified, 0 errors". The module `SinkCore refines FinalityProtocol`. It makes the refund-slice instance of the model: State is `F.Charge`, Request is `F.Request`, Effect is `R.RefundIntent`, and `SpecRel` is `RefundFinality.Authorizes`, which uses the approved `R.Eligible`. The inherited model lemmas verify again for this instance, `CommitPreservesInv` among them.
2. These lemmas are proved:
   - `StepRefinesCommit`: every step of the core is the model's `Commit` on the related model state, for every token. The core commits only when the model's `SinkAccepts` holds.
   - `StepPreservesInv` and `SinkCommit` add that `Inv` and `IdealMac` are kept.
   - `MintKeepsRel` and `InitRel` cover the mint step and the initial state.
   - `CommitAt` lifts the step to a map of charges, one core for each charge id.
   - `Enc` maps text request ids to the model's int ids, and its injectivity is proved.
3. Target shape: lemma `RefundSliceShape` proves these for every reachable related state:
   - T1: each commit has exactly one verifying token, minted for exactly that claim.
   - T2: no token commits twice. No two commits or effects share a request id.
   - T3: each effect is the intent of its token, `intent.requestId == requestId`, and its amount is not negative.
   - T4: `remaining` is never negative, and `original` never changes.
   - T5: the sum of committed refunds equals the decrease of `remaining` and is at most `original`.
4. `IssuedClaimMintAllowed`: a claim built from the token of `RefundFinality.Check` satisfies `MintAllowed`. So the proved checker discharges A2 for each mint. The signer glue that builds that claim is not proved.
5. Finding M3 is now a proved fact. Lemma `ZeroAmountRepeats` shows that two zero-amount claims with fresh request ids both satisfy the approved relation and both commit. The store stays the same and the outbox grows by two. Control N7 confirms that "every commit changes the state" cannot be proved.
6. Gaps in `sink.ts` that the core does not have:
   - The sink never checks that `body.requestId` equals `intent.requestId`. Only the issuer makes sure of it. In the core this equality follows from A1 and A2.
   - `sink.ts` compares SHA-256 hashes, so it still needs A4. The core compares state values and does not need A4.
7. The audit of all 5 files gives exit 0 and 0 findings. Two points about that result:
   - It does not report the uninterpreted `VerifyTag`, which is inherited into a non-abstract module. That assumption is visible only as the named predicate `A5_VerifierMatches` and as the model's `IdealMac`.
   - The grep for forbidden words has one hit, line 12. It is a comment that contains the word "assume". The code has no `assume`.
8. Rule violation: my first probe run (`probe/Probe.dfy`, 2 verified, exit 0) ran while Y10's Dafny was running. From then on, `dafny_one.sh` waits until no other Dafny or z3 process runs.

**What I ran (actual exits)**
| command | exit |
|---|---|
| probe verify, then audit | 0, 0 |
| verify SinkCore.dfy, attempt 1 (the T5 lower bound was missing) | 4 |
| verify SinkCore.dfy, attempt 2 | 0 |
| `python3 run_y7.py` (the whole run) | 0 |
| in that run: SHA-256 of the 4 copies (model `8b70b6b4…`, RefundFinality `23269345…`, Refund `04168824…`, RefundSpec `90a21c71…`) | all equal to the repo files |
| in that run: main verify (SinkCore sha `198474e4…`) | 0 |
| in that run: controls, expected 4 each: N1 drop fresh-id check, N2 drop pre-state check, N3a double deduct, N3b add instead of subtract, N4 commit on invalid signature, N5 drop pinned ids, N6 non-injective `Enc`, N7 "every commit changes the state", N8 two effects per commit | 4 each (9 of 9 rejected) |
| in that run: `dafny audit` of the 5 files | 0 (0 findings) |

**What stays unproved**
- `sink.ts` itself. The Dafny core is not compiled into it or linked to it.
- The text decoder (K1). The token fields and the step order are only read from the code.
- The canonical JSON and the round trip between text and state (K8).
- Ed25519, the library behind A1/A5, and the bytes that are signed.
- SHA-256 collision resistance (A4) for `sink.ts`.
- SQLite atomicity (A3), the rollback path, durability (K4), concurrency (K5), crash recovery (K6) and bypass paths (K7).
- `Sink.init`, and two databases for one charge.
- Node, the Dafny compiler and its run time.
- The issuer glue in `minter.ts`, and the checker id, which the issuer declares for itself (V, M4).
- The dispatcher, and the payment processor.

**Files (all in <session scratch folder>/m1b/Y7/)**
- `inputs/sink/SinkCore.dfy`, plus byte-equal copies in `inputs/model/`, `inputs/impl/` and `inputs/spec/refund/`
- `GAP_TABLE.txt`: 16 rows that compare `sink.ts` with the model actions and guards, and a list of model parts that have no sink code
- `SPEC_STATE_PROPOSAL_U8.txt`: an UNAPPLIED draft, not run
- `run_y7.py`, `dafny_one.sh`, `wait.sh`
- `logs/` (`result-all.json`, one log for each run, `audit.md`), `mutants/`, `probe/`

**The gap table, in short (read from the code, not run)**
- The sink's checks for ids, signature, settled request id and pre-state hash map to the model guards `Ours`, `VerifyTag`, `reqId !in settled` and `store == pre`.
- The three writes in one transaction map to the `Commit` update under A3.
- No model counterpart: decoding (text, size, shape, canonical form), the "replayed" status, the "no stored state" path, rollback on failure, `busy_timeout`, concurrency, `audit()`, and the per-database scope.
- No sink code for: `Mint`/A2, A1, and any refund rule. The sink rests wholly on A1 and A2.

**The U8 proposal (not run)**
- It adds `StoredCharge` (with a set of settled ids), `ContextAt` with `requestOpen := requestId !in settled`, and a `Settles` predicate to `RefundSpec`.
- It changes no existing line, but it changes the spec lock hash, so the pinned spec lock must be rebound.
- Expected gain: T2 and T5 become facts about approved intent, and RefundFinality rules 1 to 3 become ratified.
- It does not stop zero-amount refunds with fresh ids. That needs `0 < amount`, which is a separate owner decision.

**What I could not determine**
- Whether `impl/Refund.dfy` still verifies with the proposal applied. Not run.
- Whether `sink.ts` really does what the core does. That needs a proof of the code, or a sink generated from the core.

| step | status | evidence or blocker |
|---|---|---|
| (1) gap table | DONE (read) | `GAP_TABLE.txt` |
| (2) core, refinement, invariant, shape | MACHINE-CHECKED (scratch) | `logs/main.log` exit 0, 56 verified |
| (2) negative controls | 9 of 9 rejected | `logs/N*.log`, exit 4 each |
| (2) audit | exit 0, 0 findings | `logs/audit.md`; the uninterpreted `VerifyTag` is not reported |
| (3) spec proposal | DRAFT, UNAPPLIED | `SPEC_STATE_PROPOSAL_U8.txt` |
| (4) what stays unproved | stated | the list above |

| link id | proposed class | evidence |
|---|---|---|
| U4 | MACHINE-CHECKED (model only) | inherited lemmas verify again for the refund instance, Y7 main run |
| U5 | MISSING for `sink.ts` | new sub-link "model to Dafny sink core" is MACHINE-CHECKED in scratch under A1, A2, A3 and A5 (`StepRefinesCommit`); `sink.ts` is not linked |
| U8 | MISSING | the proposal is drafted and unapplied; a draft never upgrades a link |
| X16 | MISSING | not addressed; `IssuedClaimMintAllowed` links the Dafny Check to A2, not M1 |
| U3 | TESTED-UNPROVED | no change |
