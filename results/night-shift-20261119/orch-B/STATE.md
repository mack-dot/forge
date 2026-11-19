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

## 09:00Z update
- Commit on nightshift/B-trust: 865730fd (part 1: evidence, U530–U534). Sync script: <scratchpad>/sync.sh (rsync + path sanitise; excludes f-records/checkout, logs of f-records, keys, >1 MB flood file).
- B's own re-runs (exit 0): SinkCoreReqId 73; Contrast 106; SliceTheorem (from archive) 1570; SliceSafetyV2OnBytes 1632 (CSV rows Passed for the headline lemmas); TotalReading: see recheck-b/TotalReading.log (first try refused 75); check_records.py exit 0 (identity only); admission suite on B2 copy 92 pass / 3 fail.
- r-reqid (review of d-reqid) REPORTED: counts confirmed. Findings: D1 upgrade (no-duplicate needs a good start store; false after the unpatched sink wrote; needs a start-up audit); D2 cross-charge double refund without a charge-id check (lemma CrossChargeWithReqIdPatch); ForeignPostLocksStore. Recorded in U534, OWNER_REQUIRED B-4; sent to b-integrate.
- d-corebacked REPORTED: the token carries only preStateSha256, so the hash compare cannot be in Step; ShellCoreReqId.StepP takes a boolean preOk (A4'); `verify` exit 0, 77 verified; mutant exit 4; draft sink_core_backed.ts (127e1044…): 23 conformance cases, equal to sink.ts except the intended request-id case (worker's Node runs, exit 0). Bad-signature tokens now take BEGIN IMMEDIATE (cost); O(n) load per commit. Heavy differential prepared, NOT RUN. B's re-run of ShellCoreReqId queued (recheck-d/).
- Running at 09:00Z (5): e-expect, r-signing, b-integrate, b-ser (serialization injectivity model, issuer glue review, IssueBytes contract), f-binding (assurance ledger + verifier + controls).
- Queue: review of b-integrate and b-ser results; heavy window request to A (three prepared heavy scripts: d-reqid, d-corebacked, e-expect); ROADMAP section; MORNING.md.

## 09:25Z update
- r-signing (adversarial review of V2) REPORTED: claim-level theorem CONFIRMED (own runs 1622/1632 exit 0; mutants MA, MB, MC, MD, M1, M2 exit 4; no hidden global quantifier; could not derive false). DEFECTS: D1 HIGH byte-layer H3a is FALSE for the real serializer (token holds SHA-256 of the pre-state; lemma PreStateCollisionBreaksApprovedSpec); D2 no witness for the byte theorem; D3 wording: key secrecy sits in A2; D4 inherited lemmas not re-checked (CLOSED by B: `translate cs` on SliceSafetyV2OnBytes.dfy exit 0, SinkCore.Commit*/Init*/Mint* rows Passed, log recheck-b/translate-V2OnBytes.log); D5 scope: empty start, one charge. Repairs sent to b-ser (D1, D2, D3) and b-integrate (D5).
- f-binding REPORTED: ASSURANCE_LEDGER.json (67 edges: MC 20, ASSUMPTION 8, TESTED 9, MISSING 22, UNKNOWN-TONIGHT 7, CLAIMED 1); verify_ledger.py exit 0 and run_controls.py 29/29 (B's own runs). Chain of 33 edges: MC 6. Key structural gap: X16 (issuer calls the compiled Dafny checker, not the M1 binary). FIELDS_FOR_A.md sent to A; A's answers: orch-A/FIELDS_FOR_B.md. TODO near the end: refresh the ledger (make_ledger.py) with A's fields and tonight's late results.
- B's re-runs: TotalReading exit 0 (34); ShellCoreReqId exit 0 (77); ByteAttacks queued (recheck-b/ByteAttacks.log).
- Running at 09:25Z (4): e-expect, b-integrate, b-ser, x-issuer-bridge (dual-check issuer: Dafny verdict AND native strict frame; hardened launcher; edges X15/X16).
- A: hol.lock held all night; A's commit 68b2e67b.

## 10:00Z update
- PROTOCOL amended by the launcher (swap rule): heavy step if swap free >= 1024 MiB OR (memory free >= 40 % AND swap free >= 512 MiB). Applied in tools/dafny_locked.sh. Lock script also has a FIFO queue (locks/dafny.queue) since 08:19Z.
- Commit 2 on nightshift/B-trust: fa5d74d7 (U535).
- b-integrate REPORTED (worker runs, exit 0): SinkCoreV3.dfy 70 (request-id + charge-id checks; StepExact; GoodStart + executable AuditStart); SliceSafetyV3.dfy 1633 (layered: L0 no assumption; L1 A5; L2 InitOk+H1+A2+A5; L3 +A6b); MultiCharge.dfy 141; MultiChargeLayered.dfy 1730. Seven mutants exit 4. Protocol.md lines 61, 65: attempts keyed by (charge ID, request ID). B read the L0/L2/MultiChargeSafety statements and Step. B's re-run queued (recheck-i/). Adversarial review r-integrate started.
- A's message 09:40Z: HOL `exported_contract_exact` passed (H1.go.log, H2.go.log go exit 0); controls pending (do not mark S6 MACHINE-CHECKED yet). PF-0004 and L2-0003 go exit 0. Worker b-export-bridge started: Dafny reading of the export <==> FlatContract; BRIDGE_STATEMENT.md.
- B's independent rerun of the six proof records: recheck-f/rerun.out (see its last lines).
- Running at 10:00Z (5): e-expect, b-ser, x-issuer-bridge, b-export-bridge, r-integrate.

## 10:20Z update
- e-expect REPORTED: expect rule reproduced (75/75 verdicts; 0 false refusals of 19 correct); no lexer bypass; NEW admitted run-time halts without `expect` (H04 seq(2^32) RangeError; H01b `:|` search; H02; H03); supervision diffs for 9 files (all `git apply --check` exit 0 in B's run); B re-ran the patched run() unit test: 6 of 6 ok, exit 0 (recheck-e/). Heavy controls prepared NOT RUN (e-expect/p3/heavy_controls.sh). OWNER_REQUIRED B-5.
- B's independent rerun of the six proof records via check_records.py --rerun: SAME for all six (1489, 1486, 56, 60, 67, 1570; exit 0) — recheck-f/rerun.out.
- Running at 10:20Z (5): b-ser, x-issuer-bridge, b-export-bridge, r-integrate, e-totality (bounded straight-line subset rule for refund submissions; confusion table on correct and hostile sets; unapplied diff).

## CORRECTION (measured 09:04Z by `date -u`)
- The headings "09:00Z", "09:25Z", "10:00Z" and "10:20Z" above, and the times "08:40Z", "08:50Z" in section titles, were B's ESTIMATES, not clock readings; they run ahead of the clock. The real time at this line is 2026-11-19T09:04Z. Order of events is as written. Times inside unsure.md entries come from `date -u` and are right. Lock-script logs carry measured start and end times.
- B's session ended once on an API overload (529) and was resumed by the launcher at about 09:03Z. No lock was stale: dafny.lock holder (b-export-bridge, PID 42218) alive; all queue tickets alive.

## HANDBACK 2026-11-19T09:04:51Z
- The harness required B to hand back. B's loop STOPPED here; it did not continue after this line.
- Workers assigned and not yet reported/re-checked: b-ser, x-issuer-bridge, b-export-bridge, r-integrate, e-totality (no directory seen at 09:05Z: may not have started). Their directories under orch-B/ hold whatever they wrote.
- To resume: re-check each worker directory (re-run its final Dafny files through tools/dafny_locked.sh), write unsure entries from U537, refresh f-binding ledger with orch-A/FIELDS_FOR_B.md, add a ROADMAP section (NOT yet written), finalize MORNING.md, confirm to A.
- OWED: ROADMAP.md section for U530–U536 on the branch.

## RESUMED 2026-11-19T09:06:06Z (launcher order after the interim handback; branch a6933536)
- Order: (1) reconcile b-ser, x-issuer-bridge, b-export-bridge, r-integrate, e-totality; (2) finish review of V3 files; (3) realizable replacement for the byte-layer hypothesis; (4) ROADMAP section U530–U536, ledger to V3 and A's S6; (5) heavy steps only with no HOL process, by message with A.
- Sync script is now orch-B/sync.sh (B's own; A's is orch-A/sync.sh). Usage: sync.sh <task dirs to leave out>.
- Evidence at 09:05Z (clock): b-ser, x-issuer-bridge, b-export-bridge, r-integrate wrote files within the last minute and have lock-script jobs: ALIVE. e-totality: no directory: did not start; B sent it a resume message.
- A's message: S6 controls as planned (H0, H1, H2 go exit 0; NC1–NC6, NS1–NS3 go exit 1 as expected; PC1 go exit 0; E0, R1 go exit 0). S6 may be marked MACHINE-CHECKED (model level) with BETA-DAFNY-HOL and EXPORTER-ID. H4, NR1, R2, R3, I1 not valid yet.
- 09:07:44Z: ROADMAP section for U530–U536 written on the branch. Heavy window prepared: orch-B/heavy/run_window.sh (takes heavy.lock; refuses while hol.lock exists; runs heavy/run_diff.sh with 7 core:sink pairs, 2000 plain + 500 x 3 modes each), then heavy/hostile_controls.sh (B's copy of e-expect's script; FIFO ticket for dafny.lock). Glue smoke (3 sequences, plain): reqid core vs patched sink exit 0; reqid core vs real sink exit 1 (divergence, as it must). A will remove hol.lock after its queue (5 link reruns + L2b-0003) and send one line; B must send one line on take and on release of heavy.lock.

## HANDBACK 2 at 2026-11-19T09:08:02Z (the harness required it again; B's loop STOPPED here)
- Branch nightshift/B-trust at 445f6035. ROADMAP section for U530–U536 is written.
- Workers still running and NOT re-checked, NOT in the branch: b-ser, x-issuer-bridge, b-export-bridge, r-integrate (all had live jobs at 09:05Z), e-totality (resume message queued; no directory seen).
- Heavy window: NOT RUN. Waiting for A's line that hol.lock is gone. Then: orch-B/heavy/run_window.sh; then orch-B/heavy/hostile_controls.sh; send A one line on take and on release.
- Still owed: review verdict on V3 (r-integrate); realizable byte-layer hypothesis (b-ser); ledger refresh (V3, A's S6: MACHINE-CHECKED at model level with BETA-DAFNY-HOL and EXPORTER-ID); unsure entries from U537; final MORNING.md (the present one is INTERIM).

## RESUMED 2 — checkpoint 2026-11-19T09:11:53Z
- A removed hol.lock at 09:10:45Z. B TOOK heavy.lock at 09:11:00Z: heavy/run_window.sh running (log heavy/window-1.log; results heavy/diff-1/summary.txt). After it: run heavy/hostile_controls.sh (needs heavy.lock again: wrap or take it by hand), then SEND A THE RELEASE LINE.
- A: S5 and S6 done at MODEL level (H0,H1,H2,H4,R1,R2,R3,I1,E0 go exit 0; NC1–NC6, NS1–NS3, NR1 go exit 1 as required; PC1 go exit 0). Also L2b-0003, PX-0001 go exit 0. X9 L-OUT MISSING.
- b-ser REPORTED: SerModel.dfy 96 (model of encoding.ts canon; RoundTrip; injective; ParseExact); RepairedBytes.dfy 1790 (ClaimInjective lemma; SliceSafetyV2BytesRepaired with trace-local A4_NoCollisionInRun, H3d, B6; CollisionControl; Witness; IssueBytes); conformance 443/443 (TEST); issuer path table (minter.ts calls the compiled proved Check in-process; one signing call; key per process). B's re-run queued: recheck-s/summary.txt. Review r-ser started.
- x-issuer-bridge REPORTED: Bridge.dfy 8 verified (BridgeSound, BridgeComplete); launcher.py/decide.py with the REAL M1 binary (b8ed5ec2…): tests 64/64 (run 4), mutants 31/32 killed (1 equivalent); CE-3 dylib case: hardened launcher gives the honest frame. It ran 3-minute mutation runs while hol.lock existed (short sequential runs; noted). B's re-run of Bridge.dfy queued; tests.py re-run TODO after the heavy window.
- e-totality: started (directory exists since 09:08Z).
- Running workers: b-export-bridge, r-integrate, e-totality, r-ser.
- 09:16:29Z HEAVY WINDOW DONE, heavy.lock RELEASED 09:16:11Z, release line sent to A. (1) heavy/diff-1: 28 runs; exit 0 / 0 divergences for sinkcore.cjs:real, sinkcore.cjs:cb-orig, sinkcore-reqid.cjs:cb-reqid, sinkcore-reqid.cjs:patched-reqid (2000 plain + 500 fault-1 + 500 fault-2 + 500 interleave each); exit 1 for sinkcore-reqid.cjs:real, sinkcore.cjs:cb-reqid, sinkcore.cjs:patched-reqid (797/2000 plain divergent; kind reqid-mismatch). (2) heavy/hostile: E06, E07, E08, H01b, H02, H03, H04 all "ACCEPTED: T1 T2 T3", exit 0, through the patched gate copy, tier hostile-tests only. First attempt: setup error exit 2 (attrs pin; fixed by PYTHONUSERBASE), kept in heavy/hostile-1-setup-error.
- 09:17:35Z commit 3c43bdcf (U537). r-integrate REPORTED: V3 CONFIRMED with narrowing (empty start only; WellKeyed needed); NoHonestCommitLost proved. Repair worker b-restart started (restart theorem, AuditFull, creation rule for charge keys). B's re-runs in recheck-s/run.sh (SerModel, RepairedBytes, Bridge, AttackTrace, AttackCore, AttackMulti): results in recheck-s/summary.txt; an earlier attempt was B's CLI error (exit 1, zsh word splitting; kept in recheck-s/cli-error-1; NOT a result).
- Running workers: b-export-bridge, e-totality, r-ser, b-restart. TODO: x-issuer-bridge tests.py re-run by B; ledger refresh; U538 for b-ser/x-issuer-bridge after re-check; final MORNING.md.
- 09:22:15Z B's re-runs exit 0: SerModel 96, RepairedBytes 1790, Bridge 8, AttackTrace 1642, AttackCore 82, AttackMulti 148; x-issuer-bridge tests.py on a copy: 64/64 exit 0 (recheck-xb/tests.log). U538 written (not yet committed). b-export-bridge REPORTED (ExportBridge.dfy 1823; SliceSafetyFromExport.dfy 1892; double charge/request swap invisible to both proofs; A answered: new control NB1 go exit 1; names pin the order on both sides). B's re-run: recheck-x/summary.txt (background be6tfi3yg).
- 09:24:14Z commit 7a15e89e (U538, U539). B's re-runs exit 0: ExportBridge 1823, SliceSafetyFromExport 1892. Running: e-totality, r-ser, b-restart. Next: f-binding-2 (ledger refresh), OWNER_REQUIRED B-6, final MORNING.md.
- 09:25:13Z OWNER_REQUIRED B-6 written. Workers running (5): e-totality, r-ser, b-restart, f-binding-2 (ledger refresh; no Dafny), r-export (review of the export bridge). Each needs B's re-check on report. Then: U540+ entries, final MORNING.md, commit, confirm to A.
- 09:29:33Z r-ser REPORTED: SerModel and RepairedBytes CONFIRMED as Dafny facts; conformance extended (6581 bodies + 4736 malformed texts, 0 differences; TEST). Defects: D1 IssueBytes does not give H3d (Authorizes holds for a chargeId with U+0000); D2 B6 is necessary (amount -1 clamps to the zero-amount bytes); D3 Step compares values, the real sink compares hashes: an unstated mapping (A4b); D4 witness uses toy hash texts. Repair worker b-ser2 started. B's re-run of RSerAttacks.dfy queued (recheck-s/summary.txt).
- 09:33:01Z commit 07fb3f1c (U540). B's re-run RSerAttacks exit 0 (1804). Running (5): e-totality, b-restart, f-binding-2, r-export, b-ser2.
- 09:36:09Z A: L-OUT passed (LO-0006 go exit 0; refund_profile_a_sl_fd1: Success with exact render, or resource stop with a prefix; model level, under the stored premises incl. the all-states FFI contract). A works on a composed model theorem (L-OUT + exact strict parse) that the dual-check issuer draft can cite. f-binding-2 should pick LO-0006 from logs.
- 09:43:31Z r-export REPORTED: export bridge CONFIRMED; 15 semantic export mutants each exit 4; low defects only (reader binds by position; audit covers the top file only). U541 written.
- 09:46:29Z f-binding-2 REPORTED: ledger refreshed (97 edges: MC 50, ASM 9, TESTED 13, MISSING 18, CLAIMED 1, UNKNOWN 6; chain of 33: MC 8, ASM 8, TESTED 5, MISSING 7, UNKNOWN 5). MC by scope: deployed 2 (Dafny source only), model 34, draft 14. Weakest link: the deployed sink.ts (edges U5b/U3). B's re-run of verify_ledger.py and run_controls.py: see next line.
- 09:46:42Z B's own run: f-binding-2/verify_ledger.py exit 0 (CONSISTENT; 97 edges), run_controls.py 40 of 40. Running: e-totality, b-restart, b-ser2.
- 09:47:15Z e-totality REPORTED: subset rule draft; G1 correct 13 admitted / 6 refused; hostile all known refused; diffs check 0 (B). U542, OWNER_REQUIRED B-7 written. Running: b-restart, b-ser2. Slots free: 3.
- 09:48:17Z commit 54bcc8d0 (U542, B-7). A confirmed the ledger reading (R2/R3 differ in the timing line only; LO-0006 review done; chain X9 stays MISSING). A will ask for one line that MORNING.md is final. New workers: d-v3sink (ShellCoreV3, v3 draft sink, harness with foreign-charge tokens, heavy_v3.sh prepared), d-minter (IssueTokenBytes with a well-formedness guard; draft minter that signs only its output). Running (4): b-restart, b-ser2, d-v3sink, d-minter.
- 09:53:14Z b-restart REPORTED: Restart.dfy 1686 (ExecAppend; Restart theorem with H1Cont over the history; executable AuditFull, AuditSound, AuditComplete; AuditFullSpec gives money bound with no signature hypothesis; reviewer's bad core refused); KeyedStore.dfy 1820 (checked Create makes WellKeyed an invariant; KeyedL0, KeyedTop); unapplied TS diff sink-keyed-chargeid (556b55fb…). Two controls out-of-resource only. B's re-run queued: recheck-r/summary.txt. NEEDS a reviewer (r-restart).
- 09:56:51Z B's re-runs exit 0: Restart 1686, KeyedStore 1820. U543 written. Running (4): b-ser2, d-v3sink, d-minter, r-restart.
- 10:00:34Z A: MF-0002 go exit 0: refund_model_frame_meets_exported_contract (machine model -> fd-1 bytes -> strict parse -> value -> exported clauses; one HOL theorem, model level, stored premises incl. the all-states FFI premise). Also L2c-0001, EF-0001, LE-0004 exit 0; the original executable rebuilds byte-exactly (b8ed5ec2…). Ledger f-binding-2 predates MF/L2c/EF and B's U543 results: final refresh TODO (re-run make_ledger.py after adding edges; or note as stale in MORNING.md).
- 10:02:51Z d-v3sink REPORTED: ShellCoreV3.dfy 79 (B's re-run exit 0, 79; recheck-d/ShellCoreV3.log); draft sink_core_backed_v3.ts refuses to start on a store that fails AuditStart; 28 conformance cases (worker run); heavy_v3.sh prepared. B asked A for a second heavy window; then run heavy/run_window3.sh (output heavy/v3-1) and send take/release lines. Expected by the worker: exit 0 for v3:cb-v3 and v3:hand-v3; exit 3 for the three control pairs. Running (3): b-ser2, d-minter, r-restart.
- 10:05:52Z HEAVY WINDOW 2 DONE (10:03:01Z–10:05:23Z), heavy.lock released, release line sent. heavy/v3-1: 0 divergences for sinkcore-v3:cb-v3 and sinkcore-v3:hand-v3 (4 modes); controls diverge (exit 3; two fault-1 control runs exit 1 with 3 and 1 extra "replay" divergences).
- d-minter REPORTED: IssueBytes2.dfy 131 (IssueTokenBytes: Some iff Authorizes && WfBody; bytes = Utf8(SerBody(body)); U+0000 refused in proved code); draft minter_issuebytes.ts; 581 cases vs real minter: 0 decision differences, 55 issued, body text byte-equal (worker's Node run). Mutants M3–M6 out-of-resource only.
- r-restart REPORTED: Restart/KeyedStore CONFIRMED as model theorems; HIGH limits: rollback to an honest prefix passes both audits and the dropped token commits again; the audit's init is unauthenticated (ForgedInitPassesSpecAudit); MEDIUM: delete+re-create defeats the key invariant; TS chargeKey is opt-in. Reviewer's AttackRestart.dfy 1831.
- B's re-runs queued: recheck-m/summary.txt (IssueBytes2, AttackRestart). Running workers: b-ser2 only. TODO: U544, OWNER_REQUIRED B-8, final ledger note, final MORNING.md, confirm to A.
- 10:08:10Z B's re-runs exit 0: IssueBytes2 131, AttackRestart 1831. U544 and OWNER_REQUIRED B-8 written.
- 10:09:22Z commit 05a7a9a4 (U544, B-8). Prepared heavy/gate_subset.sh (gate copy with the combined subset diff over the list heavy/gate-subset/list.txt: 19 G1-correct, 17 new-correct, new-hostile, halting). NOT RUN; needs a third window from A (est. 5 s per file). Running workers: b-ser2, r-drafts.
- 10:15:05Z HEAVY WINDOW 3 DONE (10:11:56Z–10:14:47Z), release line sent. heavy/gate-subset: halting 0/8 accepted; G1-correct 10/19; new-correct 16/17; new-hostile 3/7 accepted. U545 written.
- 10:16:36Z b-ser2 REPORTED: HashCore.dfy + SliceSafetyBytesV3.dfy + ControlsBytesV3.dfy + RefineHashV3.dfy: exit 0, 1871 verified (worker). Token without pre-state value; hypotheses InitOk, A2p (mints are IssueBytes outputs), H1B, B5, A4_HashBindsInRun, A6b; NO VerifyTag reading; witness with a total verifier and real-shaped values. B's re-run queued (recheck-m/summary.txt, BytesV3). Review r-bytes3 started. Running: r-drafts, r-bytes3.
- 10:17:30Z B's re-run BytesV3 exit 0 (1871). U546 written.
- 10:19:32Z MORNING.md written as FINAL for the joint report (open items listed in it). Workers running: r-drafts, r-bytes3, b-top, f-binding-3. After each: re-check, unsure entry from U547, addendum section in MORNING.md.
- 10:28:33Z r-bytes3 REPORTED: SliceSafetyBytesV3 CONFIRMED; corrections G-H glue, A2p class, InitOk not enforced by the sink. U547 written; MORNING.md addendum 1. Open: r-drafts, b-top, f-binding-3.
- 10:43:29Z f-binding-3 REPORTED; B's runs: verify_ledger exit 0 (119 edges), controls 47/47. MORNING.md addendum 2. Open: r-drafts, b-top.
- 10:44:15Z commit 4150ae3b (ledger f-binding-3; B's controls run: controls: 47 run, 47 as expected, failed: []). r-drafts REPORTED: proofs confirmed; bridge draft overclaims (no post-state; mismatched inputs sign); v3 draft sink quadratic and audit gap; minter hash input. U548, MORNING addendum 3, OWNER_REQUIRED correction written. Open: b-top.
- 10:46:02Z commit a9472d65 (U548). b-top REPORTED: TopFromExport 2185, IssuerLink 2236 (SliceSafetyBytesTop: InitOk, A2q, H1B, B5, A4, A6x), KeyedHash 2325 (several charges with checked creation over the hash core), RefineTraceV3 1889 (core-level simulation; Restart results do not transfer). B's re-run queued: recheck-t/summary.txt. A: MG-0001 and L2d-0001 have a review (A27); R6base-0001 go exit 0. New workers: d-v3sink2 (constant-state StepQ, linear audit, v4 draft), x-bridge2 (single-input bridge with post-state recomputation; Bridge2.dfy with check/native as parameters), r-top (review of b-top).
- 10:56:56Z B's re-runs exit 0: TopFromExport 2185, IssuerLink 2236, KeyedHash 2325, RefineTraceV3 1889. U549; MORNING addendum 4. Running: d-v3sink2, x-bridge2, r-top.
- 11:03:26Z r-top REPORTED: CONFIRMED (B re-ran RTopLemmas: 2336). d-v3sink2 REPORTED: ShellCoreV4 105 (B's re-run exit 0); v4 draft; heavy_v4.sh prepared; wrapper heavy/run_window5.sh (output heavy/v4-1). Asked A for a fourth window. U550, addendum 5. Running: x-bridge2.
- 11:06:11Z HEAVY WINDOW 4 DONE (11:03:39Z–11:05:53Z), released, line sent. heavy/v4-1: 0 divergences for v3core:cb-v4, cb-v3, hand-v3; controls diverge. U551, addendum 6. Running: x-bridge2 only.
- 11:06:55Z commit 020990e4 (U551, addendum 6). New worker p-adopt: adoption packet as an exact diff against 985f5eaf on a scratch export (v4 sink, issue-bytes minter, dispatcher diff), static checks, run_suite.sh prepared for a heavy window (NOT to be run by the worker). Running: x-bridge2, p-adopt. Later: last ledger refresh (f-binding-4) with b-top, v4, bridge2 results; final handback only when the launcher asks or the window ends.
- 11:08:48Z x-bridge2 REPORTED; B's runs: Bridge2 22 exit 0; tests2 90/90. U552, addendum 7, OWNER_REQUIRED update. Running: p-adopt.
- 11:09:57Z commit f2b05b69 (U552, addendum 7). New workers: r-repairs (adversarial review of x-bridge2 and d-v3sink2), f-binding-4 (ledger refresh with b-top, v4, bridge2, finished reviews). Running (3): p-adopt, r-repairs, f-binding-4. On each report: re-check, unsure from U553, MORNING addendum 8+, line to A.
- 11:18:00Z p-adopt REPORTED: adoption.diff ab2ca0da… (B: git apply --check exit 0; 10 files; no protected or clearing path); static checks by the worker (builds exit 0, tsc exit 0, conformance 31 + 581, e2e, legacy); run_suite.sh prepared. Wrapper heavy/run_window6.sh (timeout 900 s per tree). Ask A for a window (up to 30 min).
- 11:20:08Z HEAVY WINDOW 5 DONE (11:18:43Z–11:19:30Z), released. Suite: pristine 115/0 failed; with diff 115/0 failed. r-repairs REPORTED (bridge confirmed; v4 audit structural only: over-refund after hostile balance reset; cfg.initialState ignored; schema unchecked). B re-ran AttackR.dfy: 30, exit 0. U553, addendum 8, OWNER_REQUIRED B-9. Running: f-binding-4, d-v5sink. After v5: review (r-v5), regenerate the packet, suite again.
- 11:41:36Z d-v5sink REPORTED; B's re-run ShellCoreV5 156 exit 0. U554. New worker d-v6sink (commit-time re-check of the approved relation: no-assumption conformance; no brick). Running: f-binding-4, d-v6sink. Then: review of v5+v6, packet regeneration (p-adopt2), heavy window for heavy_v5/v6 + suite.
- 12:05:15Z d-v6sink REPORTED; B's re-run ShellCoreV6 192 exit 0. U555, addendum 9. Review r-v6 started. Next: ask A for a window for d-v6sink/heavy_v6.sh (+ d-v5sink/heavy_v5.sh); then packet regeneration with v6. Running: f-binding-4, r-v6.
- 12:11:39Z HEAVY WINDOW 6 DONE (12:05:45Z–12:11:13Z), released. v6core:cb-v6 0 divergences all modes; controls diverge (exit 1; allowed-kind list incomplete). v5: halts in fault-1/interleave (brick after committing unauthorized token). U556, addendum 10. Running: f-binding-4, r-v6. Next: p-adopt2 (packet with v6; suite config must pass initialState) after r-v6.
- 12:14:50Z DISK INCIDENT: f-binding-4/tmp grew to 58 GB; data volume 100 % full; B's commit failed (No space left on device). B killed one process; told the worker to stop, delete tmp, cap overlays at 20 MB. Avail 70 GiB at this line; f-binding-4 still 25 GB (worker cleaning?). If f-binding-4/tmp is still present when the worker is gone: delete it (it is B's worker's temp data). r-v6 REPORTED: V6 CONFIRMED with corrections (requestOpen fixed to true WIDENS acceptance: owner question; no-brick needs same key and pins at restart; mint layer not proved for StepQ6; arbitrary settled boolean keeps conformance and money, breaks only uniqueness). TODO: U557, addendum 11, commit, tell A about the disk incident.
- 12:15:35Z U557, addendum 11, OWNER_REQUIRED B-10 written. Commit fda093a4 holds U556. f-binding-4 NOT USED (disk incident); last usable ledger f-binding-3.
- 12:16:27Z commit 1af07182 (U557, addendum 11, B-10). Disk: 88 GiB available; f-binding-4 worker is cleaning its tmp. DISK RULE added to WORKER_RULES.md. Running: f-binding-4 (cleanup/retry). Next: p-adopt2 (packet with the v6 draft; callers pass initialState; suite), then a ledger refresh by a fresh small script if f-binding-4 does not deliver.
- 12:17:49Z f-binding-4: cause found (overlay copied the whole orch-B root, incl. its own tmp); fixed (copy closure files only; 20 MB cap; 100 MB directory cap); tmp deleted; controls running again. Its ledger may be used IF its final report and B's own verify run confirm. Running: f-binding-4, p-adopt2.
- 12:27:24Z p-adopt2 REPORTED: adoption-v6.diff 0207444f… (B: git apply --check exit 0; 14 files incl. 2 test files; no protected or clearing path); static checks by the worker; run_suite_v6.sh prepared; PREDICTION: export run exits 2 at suite.ts:517 (v6 refuses to start on a tampered store). Wrapper heavy/run_window8.sh; asked A for a window. Running: f-binding-4.

## HANDBACK 3 at 2026-11-19T12:27:35Z (the harness required it; B's loop STOPPED here)
- Branch nightshift/B-trust; last commit 1af07182 plus the one made with this note. unsure U530–U557. MORNING.md is final with addenda 1–11. OWNER_REQUIRED B-1 to B-10.
- OPEN, not re-checked, not in the branch: f-binding-4 (ledger refresh; after the disk incident it runs its controls again; use its ledger only after B's own verify run; else the last usable ledger is f-binding-3).
- OPEN: p-adopt2 reported (adoption-v6.diff 0207444f…; B's git apply --check exit 0); NO unsure entry yet (next id U558); the suite for it is NOT RUN: a window was asked from A; when A sends the line, run heavy/run_window8.sh and send take/release lines. If nobody resumes, A must be told that B will not take the window.
- heavy.lock: not held. dafny.lock: taken only per run by the script.
- 12:30:23Z RESUMED 3. U558 and ROADMAP section (U537–U558) written. f-binding-4 REPORTED; B's verify_ledger exit 0 (135 edges); B's controls run in recheck-l/controls-f4.out. WORKER_RULES disk rule: stop below 30 GiB. New worker e-subset2 (why the subset rule refuses correct work; relaxed rule2). Asked A for the suite window (heavy/run_window8.sh). CTX-SINK named for the v6 claim.
