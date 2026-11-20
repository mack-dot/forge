# Refresh of the 45-link assurance graph after gate APEX-2 (2026-11-19)

CURRENT none. Stage 9 deferred. Stage 12 unauthorized.
`end_to_end=false`. **Verdict: M1-B OPEN.**

This file refreshes
[TOP_LEVEL_GRAPH_REFRESH_20261119.md](../m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md)
(the refresh after the night shift). That file and
[TOP_LEVEL_GRAPH.md](../m1b-mission-20261119/TOP_LEVEL_GRAPH.md) are NOT
edited. Read this file after them. Evidence for every change: the runs of
[README.md](README.md) (actual exits there), read from `records/`.

Rules, unchanged: the class of a row is the class of its WEAKEST part.
A machine-checked sub-part does not raise the row. MC = MACHINE-CHECKED,
AS = ASSUMPTION, TU = TESTED-UNPROVED, MI = MISSING. Every HOL result:
model level, same machine, stored older parent theories. Every Dafny
result: source level, about a model.

## 1. Rows that this gate touched (6 of 45)

| Link | Class before | Change (evidence) | Class now | Still open |
| --- | --- | --- | --- | --- |
| S4 | TU (export file); exporter fidelity AS (T4) | none for the exporter. New cross-check for the three `ensures` clauses only: FC3 (HOL) with D1, D2 (Dafny), under BETA-PLAIN | TU; exporter fidelity AS (unchanged) | the export is now OFF the path of the contract link; the exporter build is absent; nothing for the method body |
| S6 | MC (model; `hol run`; run plus repeat) | the same nine statements built by `Holmake`, exit 0, three runs, objects byte-identical; FC1 `refund_fields_flat_plain` (the contract as a plain formula, both directions); FC0, FC2, FC4, FC5, FC6; 14 HOL and export controls exit 1 for the named reason | MC (model; same machine) | clean and independent replay; input encoding T4i MISSING; output decoding MISSING |
| S7 | AS (BETA): no artefact relates the Dafny and HOL semantics | an artefact exists: FC1 (HOL), the printed formula, D1 to D4 (Dafny: the printed formula is exactly the contract of the real `AssessFlat` and exactly `FlatContract`); `check_link.py` exit 0; 18 printer and Dafny controls refused | **AS, narrowed to BETA-PLAIN**; its check is TU | the four parts of BETA-PLAIN (README section 4): the 10-row printer table; integers, booleans and integer sequences are the same in both tools; byte = character code on strings below 256; soundness and identity of the loaded theories |
| X3 | MC (model, 11 premises) | R1 `refund_route_a_flat_plain_shape`: the shape form of case L2d-0001 with its conclusion on the plain contract (exit 0; two runs, same `.dat`) | MC (unchanged; model; 12 premises) | the premises are not met by the real C (X6); no resource bound |
| X7 | MISSING | none. R1 restates the reachable-call form of the FFI premise (contract only at shape-valid calls, `fficlose` included) | MISSING (unchanged) | R6; the native contract at valid calls is an ASSUMPTION; the signed-length gap at close |
| X11 | AS; X11e MISSING | R2, R3: the entry premise forces TBI0 = TBI1 = SA0 = E0E = F, and refuses a state with TBI0 or SA0 set (exit 0) | AS (unchanged); X11e MISSING | run lift ML-08, ML-09; ML-05; the real register values were never observed |

No row changed class. S7 is narrower. S6 gained a Holmake build and FC1.
X3, X7, X11 gained machine-checked sub-parts or an honest restatement
only. The other 39 rows: NOT touched by this gate; read them in the file
this one refreshes.

## 2. Transitions to `end_to_end=true` (section 3 of the refreshed file)

| # | Transition | Class before | Class now | Link |
| --- | --- | --- | --- | --- |
| T2b | the reader of the export bytes is right | AS | AS as a statement; **off the path** of the contract link (the link does not read the export on the Dafny side) | S5 |
| T3 | Dafny meaning of the 3 clauses = HOL meaning | AS (BETA) | **AS, narrowed to BETA-PLAIN** (pinned check, TU; 32 controls) | S7 |
| T4 | exporter fidelity | AS | AS as a statement; **off the path** of the contract link; cross-check for the three clauses only (FC3 with D1, D2) | S4 |
| T3p (new) | the printed Dafny text means the HOL term `flat_plain_def`; the value identification | — | AS (BETA-PLAIN), check TU | S7 |

T4i, T7 to T22: unchanged. NOT closed by this gate: T2b, T3, T4.

## 3. What is still not proved

Everything of section 3 of the refreshed file except the narrowing above.
The smallest missing refinement boundary is still X8 (T13). The merged
sink defect (U3), the entry state (T10), the processor bits (T11), the
FFI premise (T9), the launch environment (T15), rollback (T20), the
provider (T21) and power loss (T22) are as they were.
