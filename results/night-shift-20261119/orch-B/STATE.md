# Orchestrator B (trust track) STATE — refresh after each result

- Branch `nightshift/B-trust` from `985f5eaf`; worktree `<SCRATCH>/B-trust`. No commit yet.
- Partner: Orchestrator A, agent ID `aabe04fa1c6495747`. A holds hol.lock (replay driver PID 90163/90164, not A's).
- unsure block U530–U579: none used yet.
- Tools: `orch-B/tools/dafny_locked.sh` (dafny.lock, power and swap check). Rules for workers: `orch-B/WORKER_RULES.md`.
- 07:42Z power AC; swap free 0.8 to 1.5 GB (varies). heavy.lock: NOT allowed while hol.lock exists.

## Results re-checked by B
| Time Z | Command | Exit | Result | Log |
|---|---|---|---|---|
| 07:42 | dafny_locked.sh, heavy tier, `verify Attack.dfy` | 75 | refused, swap free 812 MiB | orch-B/smoke/attack.refused-1.log |
| 07:42 | dafny_locked.sh, light tier, `verify … Attack.dfy` (gate options) | 0 | 60 verified, 0 errors (B's own run of the U478 review proof) | orch-B/smoke/attack.log |

| 07:57 | `git apply --check` of the five d-reqid diffs (B's run; nothing applied) | 0 each | apply cleanly at 985f5eaf | — |
| 07:57 | light re-run of SinkCoreReqId.dfy and Contrast.dfy (B) | 75; 75 | NOT RUN: swap free 396 MiB | d-reqid/recheck/*.log |
| 08:20–08:25 | B's re-run (light tier, gate options): `verify SinkCoreReqId.dfy`; `verify Contrast.dfy` | see d-reqid/recheck logs | SinkCoreReqId: exit 0, 73 verified | d-reqid/recheck/*.log |

## Workers (wave 1, started 07:45Z)
| Task dir | Goal | State |
|---|---|---|
| b-signing | B: realizable signing and issuance model; SliceSafety v2 | running |
| d-reqid | D: signed request-ID mismatch; patched core lemma; patch checks | REPORTED 07:55Z; B re-check: diffs done, Dafny re-run PENDING (refused, swap) |
| e-expect | E: expect rule reproduction and attack; supervision patch draft | running |
| f-records | F: reproducible Dafny proof records from repository sources | running |
| g-admission | G: admission authority design and negative tests | REPORTED 07:58Z; B re-check PENDING |

## Queue
1. Adversarial review of b-signing (after it reports). 2. Review of d-reqid. 3. Differential run of the patched sink (heavy; after HOL ends).
4. Multi-charge theorem. 5. Supervision tests with hostile programs (heavy). 6. Integration: v2 theorem on the patched core.

## Worker results (the workers' runs unless a row in "re-checked by B" says otherwise). Workers cannot write REPORT.md (harness rule); summaries are here.

### d-reqid (reported 07:55Z)
- Gap is in the MERGED sink `ts/refund-finality/sink.ts` (L86–88, L108): no `intent.requestId` check. `ts/` is not a protected path, but a fix changes the Slice 1 and Slice 3 bundles (owner decision). Round-2 copy under proposals/ has a residual gap. Booking sinks: no gap.
- Worker Dafny runs (gate options): `verify SinkCoreReqId.dfy` exit 0, 73 verified (first try exit 4, log kept); `build --target js` exit 0, 88 verified; `verify Contrast.dfy` exit 0, 106 verified; audits exit 0, 0 findings. Files: d-reqid/dafny/inputs/sink/ (SinkCoreReqId.dfy 287ffe32…, Contrast.dfy 52609f5b…).
- New lemmas with NO signature assumption: RunGrowth, RunKeepsGood, FromInitGood, RejectedChangesNothing, MismatchNeverCommits, StepExact, ZeroAmountStillCommits, Witness, PatchedRefusesGapTrace. Counterexample on the unchanged core: UnpatchedGap, UnpatchedBreaksGood (two intents with one request id). Also proved: ChargeIdNotBound (intent.chargeId and post.chargeId are not bound to the stored charge) — a second gap, same class.
- StepRefinesCommit for the patched core now needs IdealMac && MinterSound; StepRefinesModelStep needs only A5. NOTE for integration with b-signing: must be restated without IdealMac.
- Mutants M1, M2, M1b, M2b: exit 4 each (M1 alone did not break RunGrowth; M1b does).
- Node single runs on copies with test keys (exit 0): unchanged sink commits the mismatched token and then the honest one; dispatcher sent two refunds of 100 for one request id; patched copy refuses; zero-amount commits.
- NOT RUN: 5,500-sequence differential on the patched sink (heavy). Script d-reqid/heavy_differential.sh (untested wrapper).
- Diffs (unapplied) in d-reqid/diffs: sink-reqid (0f111954…), dispatcher-reqid (49704aa1…), sink-reqid-and-chargeid (3ce2a48c…), sink-chargeid-on-top-of-reqid (340f85cb…), pillar2-sink-reqid (0b807dbb…), SinkCoreReqId-vs-SinkCore (520f19db…).

### g-admission (reported 07:58Z)
- Threat table: 21 routes; today BLOCKED 2, OPEN 15, UNKNOWN 4. Live GETs: rulesets and branch protection return HTTP 403 (plan limit); `main` has protected:false; PR 58 is open with a FAILURE check and nothing blocks its merge. The session can act as the owner account (admin:true; credential helper osxkeychain and store; ~/.git-credentials exists).
- New finding 1: required-check pin integration_id 15368 is the GitHub Actions app, not a workflow: a workflow on another branch can post the same check name (test R21). New finding 2: an approval record is bound to the owner only by presence on `main`; an unsigned record is accepted (test A02); two-PR route.
- Tests (local, no network): suite 95 tests on the draft admission.py: 87 pass, 8 fail (exit 1); hardened proposal-B2: 92 pass, 3 fail (R21, R22, A02; exit 1). Reject-all and accept-all controls both fail the suite. Mutants 13 of 16 killed; 3 survivors equivalent on 5223 enumerated inputs (bounded).
- Unapplied: proposal-B2/admission-option-B2.diff 4e02fddb… (`git apply --check` exit 0 per worker). Owner actions O1–O12 in g-admission/OWNER_ACTIONS.md. Design: AUTHORITY_DESIGN.md.
- The worker used the owner's gh credential for 18 read-only calls and one `git ls-remote` (read only; outside its brief's `gh` rule; recorded).
- Ruleset tests use a LOCAL MODEL of GitHub: an ASSUMPTION.

## 08:08Z update
- Launcher relay: work on; up to 5 workers; swap free about 1.5 GB after Chrome quit (measured by B: 1527 MiB at 08:06Z).
- Wave 2 started 08:08Z: `r-reqid` (adversarial review of d-reqid), `d-corebacked` (draft sink whose decision is the compiled Dafny Step; trust table). Running now: b-signing, e-expect, f-records, r-reqid, d-corebacked (5).
- A's message 08:03Z: HOL can give the flat contract only for byte strings (chars < 256); exporter identity is a record only (build folder missing). B told b-signing to add hypothesis A6b (byte range) and prove v2 from it.
- OWNER_REQUIRED: B-1 (request-id diffs), B-2 (charge-id binding), B-3 (admission authority) written.
- Queue after reports: adversarial review of b-signing; integrate v2 with the patched core; charge-id check in the core; heavy differential (needs hol.lock gone); supervision heavy controls; unsure entries U530+; commit to nightshift/B-trust.
- 08:14Z, A's message: the replay ended 08:08:54Z; A holds hol.lock for its whole HOL queue. No heavy.lock for B unless B asks A for a window between HOL cases. Keep Dafny runs serialized and short. HEAVY ITEMS WAITING: d-reqid/heavy_differential.sh; e-expect heavy controls; d-corebacked differential.

## 08:40Z update (results; the workers' runs unless "B's run")
### f-records (reported ~08:33Z)
- Runner `f-records/reproduce_dafny_proofs.py` (93f1e219…) and `check_records.py`; `PROOF_RECORDS.json` (1ee7c90f…). Source: git archive of 985f5eaf in f-records/checkout.
- Verify (gate options, lock script), all exit 0: linked-refund 1489; linked-refund-no-axiom 1486; sink-core 56; Attack 60; WitnessCore 67; slice-theorem 1570. Full closures with digests (33, 33, 5, 6, 5, 37 files). Audits exit 0 (one expected finding: HexConversion.CharsConsistent).
- Inherited lemmas: `dafny build` exit 3 (no dotnet); `dafny translate cs` checks them: sink-core 71 rows (15 inherited), WitnessCore 82, linked-refund 4 instance rows; all passed.
- Controls: 42 runs as expected; OUT-OF-RESOURCE only: Z3b, C3, C4, M4. CrashRepro exit 1 reproduced. Self-controls (a)–(d) behave as required.
- Not reproducible as stored (table in the worker's report): run_check.py, make_neg.py, run_y7.py, mutate.py, several records without command or closure. FlatCore, Transport, UnicodeRelation, Library, Boundary, Std have NO original outside the proofs folders.
- Doubt: translate summary for linked-refund says 883 verified, CSV has 1644 rows (unexplained). 77 logs hold absolute home paths.
- B's runs: see the tail of this section's command output in the table below.
### b-signing (reported ~08:36Z)
- `SliceSafetyV2.dfy` (1ed076d1…): exit 0, 1622 verified. `SliceSafetyV2OnBytes.dfy` (7577af08…): exit 0, 1632 verified (final form: `SliceSafetyV2OnByteStrings`, hypothesis A6b). `TotalReading.dfy` (fcf9edd2…): exit 0, 34 verified. Audits: 0 findings.
- Hypotheses: InitOk, A2_MintOnlyOnCheck, A5, H1_SignatureAuthenticity (step-local, claim-level), A6b. No IdealMac. Byte layer: H3a, H3b, H3c, B5, H1B give H1 and A5.
- Witness MainWitness under SigReading (total verifier): zero-amount and 40-unit effects commit; forged tag and replay rejected; IdealMac false in every state. Refutation lemmas for dropping H1, A2, A6. Mutant M3 fails by out-of-resource only.
- NOT done: several charges; SinkCommit restated.
- B read the statements of H1, H1B, H3a–c, UniqueAuthorizationV2, SliceSafetyV2, MainWitness: no global quantifier over all claims in H1; B's own re-run queued (recheck-b/).
### A's message 08:37Z (cross-cutting)
- Native counterexamples: exit 0 with truncated or empty stdout (CE-1); DYLD_INSERT_LIBRARIES forges a complete frame (CE-3). B must name two assumptions outside A6: A-LOADER (launcher integrity, scrubbed environment) and strict parse of ONE complete frame by any consumer or issuer glue. HOL: L1-0001 exit 0, L1imp-0001 exit 0, L2-0001 exit 1 (A's runs).
### Workers running at 08:40Z (5)
e-expect, r-reqid (review), d-corebacked, r-signing (adversarial review of V2), b-integrate (V3: both sink checks + layered theorem + several charges).
