# Report C: critical blockers, ranked for the owner's question

Scores 1 (low) to 5 (high). "Impact" = dependency impact on the DETECTION path (Line V), unless "prevention" is named. Effort: D days, W weeks, M months, R research. Every effort is an estimate; the basis is in Report E or F.

| Rank | Blocker (edges) | Security | Proof difficulty | Impact | Effort | Blocks |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | B1 No verifier checks a durable log against the spec (A9.4, A9.10). Today an outsider can check only the CRC and the FNV chain; FNV is not cryptographic (`sink.rs:12`) | 5: an engine bug that commits a disallowed refund is invisible to a third party | 2: fold over 64-byte records; `ShellCoreV5` has the proof pattern (Report F) | 5: the owner's question names the verifier | W | any third-party statement about an actual execution |
| 2 | B2 No approved stateful spec (A1.5). `RefundSpec` is stateless; at-most-once, `remaining` update and `refundEnabled` at genesis are new intent (`DESIGN.md:281`; draft U8 "NOT approved") | 4: without it, "respected its specification" has no durable meaning | 1 (text exists) | 5: D-1 and D-2 both need it | owner decision | the meaning of every durable conclusion |
| 3 | B3 H_LOG unchecked: no witness, no anchor, no reconciliation (A9.2, A9.5, A8.5) | 5: a same-uid engine or operator can rewrite or restore both files; a dispatched effect without a record is invisible | 1–2: signatures, anchors, joins | 4: turns D-1's main hypothesis into checks | W each | "actual" and "durable" in the question |
| 4 | B4 Receipt content, trust root, provenance, time (A9.3, A9.6–A9.8) | 4: a valid log does not show who asked | 1 | 3 | D–W | provenance; replay of a verdict by an outsider |
| 5 | B5 M1 not rebuildable from `main`; no clean replay. Top layer (LOut, ModelFrame, RouteAFlat, FlatContract) is in no restore list; its parents sit in 34 untracked `results/` folders (A4.2, all HOL edges) | 3: no outsider can check any machine-code theorem | 1–2: packaging and a long machine run; inventory not done | 1 for detection; 5 for prevention and M1 closure | not shown (inventory first) | M1 closure, D-2 C4, any third-party check of HOL results. NOT the detection path |
| 6 | B6 Durable transition unproved: no WAL model, no crash model, A3 assumed, no Rust link (A3.6, A7.1, A8.3) | 4: prevention rests on tests | 3 | 1 for detection (V reads the result); 5 for prevention | W | D-2 C1/C2 |
| 7 | B7 Rollback: joint restore undetected; silicon D7 shape (A8.4) | 4: forgotten ids commit again | 1 | 3 (V3 closes it for detection) | D (D7), W (anchor) | at-most-once across restores |
| 8 | B8 native-to-model gap: X8, loader, FFI contract, TBI0/SA0 (A6.1–A6.5) | 2: after the native rechecks, it affects completeness, not safety (Report D-2) | 5 | 0 for detection; 4 for M1-B | M, partly R | M1-B; D-2 C4 |
| 9 | B9 Executed artifact not bound (A5.3, A5.4) | 2 for detection: V does not trust the engine or the binary; 4 for prevention | 1 | 1 | D | receipts that name the deciding binary |
| 10 | B10 Silicon flags caller-chosen; binary asked before the lock (`sink.rs:133,192`) | 2: the native checks under the lock decide safety; a caller can make the binary accept with any flags | 1 | 1 for detection; 3 for D-2b | D | the "binary sole decider" design (D-2b) |
| 11 | B11 Printer trust HOL→Dafny (A3.4) | 2 | 3 | 0 for detection | W | D-2b crossing (or all-HOL variant) |
| 12 | B12 Approval unauthenticated (A1.4); refund spec outside approval records (A1.2) | 3 | 1 | 2 | D | A1 |
| 13 | B13 Power-loss durability assumed (A8.2) | 3 | n/a (empirical) | 2 (V4 shows a lost record as a mismatch) | W + rig | A8 in reality |
| 14 | B14 Stale or missing evidence bundles: airlock (20 of 64), MCP, primitives | 2 | 1 | 1 | D | trust in TESTED_ONLY rows |
| 15 | B15 `@Axiom CharsConsistent` in the LinkedRefund closure (A3.2) | 1 | 1 | 0 for detection | D | a cheat-free A3.2 |

Order rule: impact on the detection path first, then security, then low difficulty.

Why M1 reproducibility moved from rank 1 to rank 5:
- The engines recheck every conjunct of `Eligible` natively, except the two flag bits (Report D-2).
- A verifier that evaluates the spec predicate needs no binary theorem.
- M1-R still blocks three things: M1 closure, the completeness conclusion, and any outsider check of a machine-code theorem.
