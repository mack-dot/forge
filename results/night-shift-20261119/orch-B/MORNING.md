# Orchestrator B (trust track) — morning report, version of 2026-11-19T09:28:52Z

Status: M1-B OPEN. `end_to_end=false`. No stage CURRENT. Nothing merged, pushed, signed, deployed or applied. No protected file changed.
Branch `nightshift/B-trust` (from 985f5eaf). unsure entries U530–U539. Owner queue: `OWNER_REQUIRED.md` B-1 to B-6.
All results below are Dafny MODEL results or finite TESTS. "(B)" = the orchestrator's own run with a stored log. Pinned Dafny 4.11.0, gate options.
Still running when this version was written (NOT in this report): e-totality, r-ser, b-restart, f-binding-2, r-export. See STATE.md.

## 1. New proofs (B's own runs, exit 0; file under orch-B/, verified count)
| File | Count | What it states | Review |
|---|---|---|---|
| b-signing/SliceSafetyV2OnBytes.dfy | 1632 | composed lemma for one charge WITHOUT IdealMac: every committed effect meets the approved eligibility, the artifact's flat result, unique authorization; from H1, A2, A5, A6b | confirmed (r-signing) |
| b-signing/TotalReading.dfy | 34 | a model instance with a TOTAL verifier (the reading used by the witnesses exists) | confirmed |
| d-reqid/…/SinkCoreReqId.dfy, Contrast.dfy | 73, 106 | request-id check: one effect per request id with no signature assumption (from an empty or audited store); counterexample on the unchanged core | confirmed, narrowed (r-reqid) |
| b-integrate/SinkCoreV3.dfy | 70 | core with request-id and charge-id checks; exact acceptance; executable start audit | confirmed (r-integrate) |
| b-integrate/SliceSafetyV3.dfy | 1633 | layered: L0 NO hypothesis (uniqueness, id binding); L2 H1+A2+A5 (approved, money bounds, sum); L3 +A6b | confirmed; empty start only |
| b-integrate/MultiCharge.dfy, MultiChargeLayered.dfy | 141, 1730 | several charges: no two effects share (charge id, request id); per-charge bounds | confirmed; needs one database per charge id |
| r-integrate/work/AttackTrace.dfy, AttackCore.dfy | 1642, 82 | under H1+A2+A5 the two new checks lose no honest commit (zero amount included) | reviewer's own lemma |
| b-ser/SerModel.dfy | 96 | model of the real token encoding: round trip, canonical-only parser, injective | review running |
| b-ser/RepairedBytes.dfy | 1790 | byte-level theorem with a trace-local no-collision hypothesis in place of the false injectivity hypothesis | review running |
| b-export-bridge/ExportBridge.dfy, SliceSafetyFromExport.dfy | 1823, 1892 | the exported clauses (58154ddf…), read by an independent reader, are equivalent to FlatContract; composed lemma from the exported clauses | review running |
| x-issuer-bridge/dafny/Bridge.dfy | 8 | decision model of a dual-check issuer step | — |
| d-corebacked/…/ShellCoreReqId.dfy | 77 | core with a boolean pre-state input agrees with the patched core | — |
| f-records: six stored records, rerun from `git archive 985f5eaf` | 1489, 1486, 56, 60, 67, 1570 | the owed records of U479, with full closures | B's rerun: same |

## 2. New counterexamples (each proved in Dafny or shown by a run)
1. Unchanged sink core: two effects for one request id (also on a copy of the MERGED ts/refund-finality/sink.ts, test keys).
2. Request-id patch alone: fails after an upgrade from an unpatched store; cross-charge double refund without a charge-id check.
3. V2 byte layer: "serializer injective on claims" is false for the real token (SHA-256 of the pre-state); a collision commits an unapproved effect.
4. Start audit: a store passes the structural audit and holds 500 refunded on an original of 100.
5. Two databases with one charge id: one token commits in both.
6. Gate: seven submissions that halt or hang on one keyed amount are ACCEPTED (exit 0) by a gate copy with the `expect` rule and supervision (B's run).
7. Export bridge: a double swap of charge and request is invisible to the Dafny proof and to the HOL theorem.
8. Admission: `main` unprotected; ruleset endpoints HTTP 403; an agent session holds the owner's admin credential (read by GET).

## 3. Composed guarantee (honest reading)
For ONE refund slice, at MODEL level: IF only the issuer signs and only claims the proved checker authorizes (A2), the scheme is unforgeable and no hash collision occurs in the run (H1 / H1B + A4), the sink's verifier boolean is the model's (A5), and the artifact's flat function meets the exported contract on byte strings (A6b = A6x), THEN every committed effect is approved by R1–R5 on the stored charge, is uniquely authorized, and money bounds hold. Uniqueness and id binding need no assumption for the V3 core.
Not connected: the V3 core is not the deployed sink; sink.ts against a core is TESTED (0 divergences on 3,500 sequences per matching pair, B's run); the issuer calls the compiled Dafny checker, not the native program (ledger edge X16 MISSING); the Dafny lemma and A's HOL theorem meet through an ARGUED bridge (values, operators, name order) and the assumption that the artifact function is the HOL function.

## 4. Remaining gaps
ASSUMPTION: A2 (issuer glue, key only in the issuer), H1/H1B (EUF-CMA), A4 and A4b (no collision), A5, A6b/A6x, the bridge to HOL, atomic commit (SQLite), the Dafny-to-JavaScript compiler, launcher integrity, tool soundness.
TESTED ONLY: sink.ts vs cores; serialization model vs encoding.ts (443 bodies, worker run); bridge tests (64 of 64, B's run).
MISSING: restart from a non-empty store (trace lemmas start empty); enforcement of one database per charge id; executable totality (run-time halts admitted); a memory bound in the gate; enforced admission on GitHub; any proof about minter.ts, sink.ts, compiled JavaScript or the running process.

## 5. Security: routes that still bypass the boundary
An agent session can merge to `main` (no protection; owner credential on this machine). A trusted but faulty signer can cause a duplicate or cross-charge refund in the DEPLOYED sink (B-1, B-2 unapplied). A submission that halts on a rare input passes every gate tier. An approval record is accepted without an owner signature once on `main`.

## 6. Reproducibility (a separate operator, from the branch)
`orch-B/f-records/reproduce_dafny_proofs.py`, `check_records.py --rerun` (six records). Each new proof: `orch-B/tools/dafny_locked.sh OWNER DIR LOG 300 verify <gate options> FILE.dfy` in the file's directory; expected counts in the table above. `orch-B/heavy/run_window.sh` (differential; needs the untracked compiled cores in d-corebacked/build: rebuild with `dafny build --target js`). `orch-B/f-binding/verify_ledger.py` (identity only; the ledger predates V3: refresh in work). f-records verify logs are not in the branch copy (home paths).

## 7. Next critical obligation
Make the proved decision the deployed decision: adopt the compiled V3 core in the sink (B-6c with B-1/B-2) and the IssueBytes path in the issuer (B-6b). Input: b-integrate/SinkCoreV3.dfy, d-corebacked/sink_core_backed.ts, b-ser/RepairedBytes.dfy. Command: `orch-B/heavy/run_window.sh` extended with a V3 pair and foreign-charge tokens. Acceptance: 0 divergences on matching pairs, each control pair diverges, then the owner's decision on the exact diffs.

## 8. Owner decisions
`results/night-shift-20261119/OWNER_REQUIRED.md`: B-1 request-id diffs; B-2 charge-id binding; B-3 admission authority (O1–O12); B-4 start-up audit and digest changes; B-5 `expect` rule, halts without `expect`, supervision diffs; B-6 adoption of the drafts. Every diff has a SHA-256 and `git apply --check` exit 0 (B's run); none is applied.
