# Orchestrator B (trust track) — morning report, FINAL for the joint report, written 2026-11-19T10:19:32Z

Status: M1-B OPEN. `end_to_end=false`. No stage CURRENT. Stage 9 deferred. Stage 12 unauthorized. Nothing merged, pushed, signed, deployed or applied. No protected file changed.
Branch `nightshift/B-trust` (from 985f5eaf), head bd523de5 when written. unsure entries U530–U546. Owner queue: `OWNER_REQUIRED.md` B-1 to B-8.
All proof results are Dafny MODEL results. All runs with the real sink, minter, gate or native program are finite TESTS on copies. Pinned Dafny 4.11.0, gate options, through `orch-B/tools/dafny_locked.sh`. Every count below is from the orchestrator's own run with a stored log (orch-B/recheck-*/), unless marked (w) = worker run only.
Open when written (results NOT in this report; an addendum follows in STATE.md and unsure.md): reviews r-bytes3 (of §1 row 1) and r-drafts (of rows 9, 10, 12); worker b-top (a top-level composition); f-binding-3 (last ledger refresh).

## 1. New proofs (exit 0; file under orch-B/; verified count; review)
| # | File | Count | Statement | Review |
|---|---|---|---|---|
| 1 | b-ser2/ControlsBytesV3.dfy + RefineHashV3.dfy (with HashCore.dfy, SliceSafetyBytesV3.dfy) | 1871 | THE CORRECTED COMPOSED LEMMA at byte level. A sink core whose token has no pre-state value (it compares hashes, like the real sink). From: issuance by the proved IssueBytes method (A2p), byte unforgeability per trace (H1B), the verifier boolean (B5), one trace-local no-collision hypothesis (A4), and the artifact's flat contract on byte strings (A6b): every committed effect is approved by R1–R5 on the STORED charge at commit time, its bytes were minted, money bounds and the sum equation hold. Structure (one effect per request id, id binding) needs no hypothesis. No IdealMac; no reading of an uninterpreted verifier; verifier and hash are parameters. Zero amount commits. | running |
| 2 | b-signing/SliceSafetyV2OnBytes.dfy, TotalReading.dfy | 1632, 34 | the first lemma without IdealMac (claim level, value core) and a model instance with a total verifier | confirmed |
| 3 | b-integrate/SinkCoreV3.dfy, SliceSafetyV3.dfy | 70, 1633 | core with request-id and charge-id checks; layered L0 (no hypothesis) / L2 (H1+A2+A5) / L3 (+A6b) | confirmed; empty start |
| 4 | b-integrate/MultiCharge.dfy, MultiChargeLayered.dfy | 141, 1730 | several charges: no two effects share (charge id, request id); per-charge bounds | confirmed; needs one store per charge id |
| 5 | r-integrate/work/AttackTrace.dfy, AttackCore.dfy, AttackMulti.dfy | 1642, 82, 148 | under the hypotheses the two new checks lose no honest commit; counterexamples for a bad start store and for two stores with one charge id | reviewer's lemmas |
| 6 | b-restart/Restart.dfy, KeyedStore.dfy | 1686, 1820 | restart lemma; executable audits; checked creation makes "key = stored charge id" an invariant | confirmed, narrowed (§2 items 6–8) |
| 7 | b-ser/SerModel.dfy, RepairedBytes.dfy | 96, 1790 | model of the real token encoding (round trip, injective, canonical-only parser); first byte repair (superseded by row 1) | confirmed, narrowed |
| 8 | b-export-bridge/ExportBridge.dfy, SliceSafetyFromExport.dfy | 1823, 1892 | the exported contract bytes (58154ddf…), read by an independent reader, are equivalent to FlatContract; composed lemma from the exported clauses | confirmed; 15 semantic export mutants break it |
| 9 | d-minter/src/IssueBytes2.dfy | 131 | IssueTokenBytes: bytes iff the checker authorizes and the body is well-formed; bytes are the model serialization | running |
| 10 | d-v3sink/…/ShellCoreV3.dfy; d-corebacked/…/ShellCoreReqId.dfy | 79, 77 | shell forms of the cores (boolean pre-state input) agree with the cores | running |
| 11 | d-reqid/…/SinkCoreReqId.dfy, Contrast.dfy | 73, 106 | request-id check alone; counterexample on the unchanged core | confirmed, narrowed |
| 12 | x-issuer-bridge/dafny/Bridge.dfy | 8 | decision model of a dual-check issuer step | running |
| 13 | six stored records, rerun from `git archive 985f5eaf` (f-records) | 1489, 1486, 56, 60, 67, 1570 | the owed records of U479 with full closures; B's rerun: same | — |
Reviewer files re-run by B: r-signing ByteAttacks 1636; r-ser RSerAttacks 1804; r-restart AttackRestart 1831.

## 2. New counterexamples (proved in Dafny or shown by a run)
1. Unchanged sink core: two effects for one request id; also on a copy of the MERGED ts/refund-finality/sink.ts with test keys (the dispatcher sends two refunds).
2. Request-id patch alone: false after an upgrade from an unpatched store; cross-charge double refund without a charge-id check.
3. "Serializer injective on claims" is false for the real token (it holds a SHA-256 of the pre-state).
4. IssueBytes authorizes a charge id with U+0000 (the real decoder refuses it); a token with amount -1 had the bytes of a zero-amount claim in the first byte model.
5. A value-comparing core does not describe a sink that compares hashes without a second collision assumption.
6. A rollback of the store to an honest earlier state passes every audit; the dropped token commits again.
7. The audit's initial charge is an unauthenticated input: with a forged one, 500 refunded on a true 100 passes.
8. Two stores with one charge id, or delete and re-create: the same token commits twice.
9. Gate: seven submissions that halt or hang on one keyed amount are ACCEPTED by a gate copy with the `expect` rule and supervision (B's run).
10. A double swap of charge and request is invisible to the Dafny bridge proof and to the HOL theorem (harmless at that layer; one-sided swaps fail on both sides).
11. Admission: `main` unprotected; ruleset endpoints HTTP 403; an agent session holds the owner's admin credential (read by GET).

## 3. Tests in three heavy windows (B's runs; HOL lock removed by A each time; all released)
- Sink differentials, seed 20261119, 3,500 sequences per pair (plain, two fault modes, interleaving): 0 divergences for the merged sink.ts vs the unchanged compiled core; the draft sinks vs their compiled cores (incl. V3 with foreign-charge tokens); the hand-patched copies vs the patched cores. Every control pair diverges.
- Hostile gate controls: see §2 item 9. With the draft subset rule in the gate copy: 0 of 8 halting submissions accepted; 10 of 19 known correct and 16 of 17 new correct accepted.
- Light runs: bridge tests 64 of 64 with the real native program b8ed5ec2… (B); admission suite 92 pass / 3 fail by design points (B); minter draft 581 requests, 0 decision differences (w); encoding model 6,581 bodies and 4,736 malformed texts, 0 differences (w).

## 4. Composed guarantee (honest reading)
One refund slice, MODEL level: if only the issuer signs, and only outputs of the proved issue method; if signatures are unforgeable and no hash collision occurs in the run; if the sink's verifier boolean is the verifier on the token's bytes; and if the artifact's flat function meets the exported contract on byte strings; then every committed effect is approved by the approved R1–R5 relation on the stored charge, is unique per request id, and money bounds hold. Orchestrator A's HOL theorem (model level) gives the last "if" for the machine model's strict-parsed output, for the same export bytes; the two meet through an ARGUED bridge (values, nine operator readings, name order, reader fidelity) and the assumption that the artifact function is the HOL function.
NOT connected to the deployed system: the patched or compiled-core sinks and the issue-bytes minter are drafts; the deployed sink.ts has a proved decision defect; the issuer calls the compiled Dafny checker, not the native program; nothing is proved about sink.ts, minter.ts, compiled JavaScript, SQLite or the running process.

## 5. Remaining gaps
ASSUMPTION: A2p (key only in the issuer; issuer glue), H1B, A4, B5, A6b/A6x, the bridge to HOL, atomic commit (SQLite), the Dafny-to-JavaScript compiler, launcher and OS, tool soundness; authentic initial charge; no rollback; no delete and re-create; who may create a charge.
TESTED ONLY: every sink, minter, gate and bridge behaviour; the encoding model against encoding.ts.
MISSING: any proof about deployed code; enforced admission on GitHub; a memory bound in the gate; a machine-checked bound for executable totality (the subset rule is an argument); the trace-level lift from the value core to the hash core; a review verdict on rows 1, 9, 10, 12.

## 6. Security: routes that still bypass the trusted boundary
An agent session can merge to `main`. A trusted but faulty signer can cause a duplicate or cross-charge refund in the DEPLOYED sink. A database rollback replays a refund. A submission that halts on a rare input passes every tier of the deployed gate. An approval record is accepted without an owner signature once on `main`. The required check is pinned to the Actions app, not to a workflow.

## 7. Reproducibility (a separate operator, from the branch)
`orch-B/f-records/reproduce_dafny_proofs.py` and `check_records.py --rerun` (six records). Each new proof: in the file's directory, `orch-B/tools/dafny_locked.sh OWNER DIR LOG 300 verify --solver-path <z3-4.12.1> --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects FILE.dfy`; expected counts in §1. Tests: `orch-B/heavy/run_window.sh`, `run_window3.sh`, `gate_subset.sh` (they need the compiled cores, which are build outputs and not in the branch: rebuild with `dafny build --target js` as the workers' logs show). Ledger: `orch-B/f-binding-2/verify_ledger.py` (identity and record consistency only; it predates rows 1, 6, 9, 10 and A's last HOL cases; refresh f-binding-3 in work). The verify logs of f-records are not in the branch copy (home paths); they stay in the main checkout.

## 8. Next critical obligation
The deployed sink.ts is the weakest link. Adopt, by owner decision, the sink whose decision is the compiled V3 (or hash) core with a start-up audit, and the minter that signs only the bytes of the proved method (B-6, B-8d). Inputs: orch-B/d-v3sink/sink_core_backed_v3.ts, orch-B/d-minter/minter_issuebytes.ts, orch-B/b-ser2/HashCore.dfy. Command: `orch-B/heavy/run_window3.sh` plus the Slice 1 suite on the drafts. Acceptance: 0 divergences on matching pairs, every control pair diverges, the suite passes, new bundle digests recorded. Then the one proof that removes the largest TESTED edge: a Dafny `{:extern}` contract or a generated shell, so that "TypeScript writes exactly the core's result in one transaction" is the only unproved step.

## 9. Owner decisions (exact items; nothing is applied; each diff has a SHA-256 and `git apply --check` exit 0 by B)
B-1 request-id diffs (sink, dispatcher). B-2 charge-id binding. B-3 admission authority (steps O1–O12). B-4 start-up audit; digests that change. B-5 `expect` rule; halts without `expect`; nine supervision diffs. B-6 adoption of the issuer and sink drafts; token format. B-7 the subset rule and its cost. B-8 rollback anchor, authentic initial state, one store per charge id.

## ADDENDUM 1 (2026-11-19T10:28:33Z) — review of §1 row 1 ended: CONFIRMED (U547)
Reviewer's own runs: exit 0, 1871 verified; own lemmas 1877; three step mutants exit 4; no contradiction derivable; hypotheses hold for every trace under an injective hash. Corrections to the reading: (1) one more piece of glue, G-H: the issuer and the sink use the same hash of the same canonical text, and the stored text is always canonical (true by reading; not a listed hypothesis); (2) A2p is key custody PLUS TypeScript glue in minter.ts PLUS the Dafny-to-JavaScript compiler — the proved IssueBytes is a model of the issuer, not the issuer; (3) the sink does not enforce InitOk (its init accepts remaining above original); only the money conclusions need it. No finding refutes the lemma.

## ADDENDUM 2 (2026-11-19T10:43:29Z) — last ledger refresh
`orch-B/f-binding-3` (B's own runs: verify_ledger.py exit 0, identity and record consistency only; run_controls.py 47 of 47): 119 edges: 65 MACHINE-CHECKED (2 about deployed Dafny source, 44 about models, 19 about drafts), 9 ASSUMPTION, 18 TESTED-UNPROVED, 20 MISSING, 1 claimed without a log, 6 without a log of this night. Chain of 35 edges from the approved contract to durable state: 8 MACHINE-CHECKED, 8 ASSUMPTION, 5 TESTED, 9 MISSING (restart and store creation added as MISSING for the deployed path), 5 without a log of this night. It includes Orchestrator A's MF-0002, MG-0001, L2c-0001, L2d-0001, EF-0001, LE cases from their logs and refuses exploration runs. Weakest link unchanged: the deployed sink.ts.

## ADDENDUM 3 (2026-11-19T10:44:15Z) — review of the drafts ended (U548): proofs of §1 rows 9, 10, 12 CONFIRMED; three drafts are weaker than stated
1. Dual-check issuer draft (§3, B-6a): as built it does NOT stop a wrong Dafny-to-JavaScript compile that accepts a wrong post-state (no post-state in the compared fields), and it signed when the two sides were given different inputs (three cases with the real native program). Repair: derive both sides from one input and compare the post-state. Read B-6(a) with this limit.
2. Draft sink with the compiled V3 core (§8, B-8d): quadratic cost per commit inside the write lock (7.4 s at 20,000 settled ids; failure at 200,000): a liveness defect of the draft; the start-up audit does not bind the stored charge to the initial charge; the audit runs at construction only. Repair before any adoption: indexed lookup of the settled id; bind the initial charge. §8's acceptance criteria must add these.
3. Draft minter: the hash text is an unchecked input of the proved method; one TypeScript line carries it.
