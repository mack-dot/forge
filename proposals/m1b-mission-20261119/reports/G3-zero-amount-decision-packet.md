# Step G3: an UNAPPLIED decision packet for the amount-0 question (Z3, Opus; pinned Dafny on copies; no repository file changed)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Z3 report: zero-amount decision packet. UNAPPLIED. I approve nothing. M1-B stays OPEN; end_to_end=false.

**Findings**
1. **Zero is an approved business decision, not a bug.** `spec/refund/protocol.md:25-27` says "Zero is a legitimate authorization… returns Authorized(0, reason)". `proposals/refund.md:57,78` says the same. The lock hashes `protocol.md`. So B and C reverse an earlier approval, and `protocol.md` plus its lock hash must change too.
2. **The smallest spec diff is one line.** `RefundSpec.dfy:35` changes `0 <=` to `0 <`. Old SHA-256 is `90a21c71…`, new is `9d96d67c…`, diff is `3326d904…`. `Money` in R1 still holds.
3. **`impl/Refund.dfy` and `impl/RefundFinality.dfy` verify UNCHANGED.** They call the spec predicate `Eligible`. The smallest impl diff is none.
4. **Clearing:** the new spec gives NO_CHOICE. The pair old→new gives DIVERGES at amount 0: `(ch_1,rq_1,100,60)` and `Candidate(0,"duplicate_charge")` give old `Authorized(0,…)` and new `Rejected`. The solver witness also has amount 0. Dafny proved `new Eligible <==> old Eligible && amount != 0`.
5. **Slice 2 side effect:** the planted pair `refund-rewrite` restates the OLD rule. Under the new spec it gives LINK_BROKEN. `exit_slice2.py` expects EQUIVALENT, so that check would fail. `clearing/` would have to change.
6. **M1 conformance side effect:** the control `RefundRejectsZero` (listed as a WRONG decision) now VERIFIES, so `exit_m1_conformance.py:1003` would fail. 1 of 22 recorded fixtures flips (`eligible_zero`). 126 of 2,466 corpus vectors flip (boundary 54, pseudo-random 69, adversarial 2, fixture 1).
7. **The M1 executable `b8ed5ec2…` matches the OLD spec only.** The rule is in HOL `eligible_def` (`forge_refundScript.sml:61`, guard at `:25`). The FlatCore hash goes from `a89484e3` to `46082c38`. The U294 export (`58154ddf`, two `Le 0 amount` nodes) then no longer matches.
8. **LinkedRefund** needs 4 files changed: FlatCore, plus three amount-0 witnesses (Transport, UnicodeRelation, LinkedRefund). After that it verifies.
9. **SinkCore:** `ZeroAmountRepeats` now FAILS, the required negative result. Two new facts are proved under the new spec: "every commit strictly decreases remaining" (N7 of D7) and "at most `original` commits per charge". Both fail under the old spec.
10. **Option C:** the U8 text plus `0 < amount` proves step decrease, settled-id refusal and a trace bound. U8 alone cannot prove the decrease or the bound.

**What I ran** (copies only; pinned Dafny through the lock script; gate options)
| run | expected | exit |
|---|---|---|
| r1 Refund + gate Bindings, new spec | 0 | 0 (6 verified) |
| r2 NEG old guard, new spec | 4 | 4 |
| r3 RefundFinality + Slice 1 Bindings | 0 | 0 (10) |
| r4 RejectsZero fixture, new spec | (finding) | 0 |
| r5 `spec_clearing.py refund` on a mirror tree | NO_CHOICE | 0 |
| r6 clearing pair old→new | DIVERGES | 0 |
| r7 NEG LinkedRefund, old FlatCore | 4 | 4 |
| r8 LinkedRefund, attempt 1 | 0 | 4 (WitnessUnicode used amount 0) |
| r9 LinkedRefund, fixed | 0 | 0 (1489) |
| s1 SinkCore unchanged, new spec | 4 | 4 (only ZeroAmountRepeats) |
| s2 SinkCore with new lemmas | 0 | 0 (60) |
| s3 NEG same, old spec | 4 | 4 |
| r10 clearing `refund-rewrite`, new spec | (finding) | 1 (LINK_BROKEN) |
| c1 Option C checks | 0 | 0 (13) |
| c2 NEG U8 only | 4 | 4 |
| v1 `count_zero.py` (vector count) | 0 | 0 |

**Consequences and texts** (detail in the packet, sections 3 and 4)
- **A:** no proof is redone. If the sink or issuer refuses zero, it breaks R4 and `protocol.md:23-24` ("No extra heuristic may reject"). That would be a hidden rule in unproved TypeScript, outside the spec lock. That is the governance problem.
- **B:** these protected files change: `spec/refund/RefundSpec.dfy`, `protocol.md`, `spec.lock`, `gate/refund/hostile.ts:47`, the `clearing/` fixtures, and the pinned spec hashes. M1 needs a new HOL chain and a new binary.
- **C:** everything in B, plus the U8 text. It also widens the gap to the stateless M1.
- **My ranking (advice only):** 1. A now, with B as a later separate decision. 2. B. 3. C. I do not recommend A with a hidden refusal.

**I could not determine** the wire-input effect at amount 0 (192 inputs; I only read them, none is a typed 0). I did not run the full `exit_*` scripts, HOL, or the gate's hostile and TS suites. Those breakages are from reading.

`proposals/m1b-mission-20261119/TRACKER.md` shows as modified in git status. I did not change it.

**Graph links**
| link id | proposed class | evidence |
|---|---|---|
| U8 (stored state) | MISSING (draft only) | c1/c2 are checks on copies; the spec is not changed |
| X16 / zero repeats (D6 M3) | ASSUMPTION/decision pending | ZeroAmountRepeats is true under the approved spec; it is false under B (s1) |
| S5 (U294 export) | unchanged now; under B it would become MISSING | FlatCore and export hashes no longer match |

**Files are in** `<session scratch folder>/m1b/Z3/`:
- `DECISION_PACKET_ZERO_AMOUNT.txt`: the full packet, with the file-and-line inventory, the consequences table, the owner texts and the ranking
- `spec-change/`: the spec diffs and the old and new spec copies
- `linked/`: the four LinkedRefund diffs and the tree that verified
- `sink/`: the SinkCore diff, the new lemmas and the three copies
- `option-c/`, `option-c-neg-U8-only/`: the Option C copy and its negative control
- `mirror-new/`, `mirror-pair/`: the clearing mirror trees with their `build/` records
- `tools/`: `count_zero.py`, `vrun.sh` and the stubbed script copy
- `logs/`: every run log, and `v1-flip-vectors.log` with the 126 vector ids
