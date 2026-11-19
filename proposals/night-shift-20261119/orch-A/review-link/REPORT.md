# A17 adversarial review of the link runs S5/S6 (condensed by Orchestrator A)
Verdict: S6 (H1, H2) and S5 (R1–R3, I1) are MACHINE-CHECKED in HOL (same machine, run plus repeat). Every control fails
for the intended reason (each stderr read by the reviewer). The link to the Dafny R1–R5 result is NOT machine-checked end to end.
- Integrity HOLDS: every recorded SHA-256 recomputed; H1 and H2 `.dat` equal; R1 stdout byte-equal to the recorded hol-0004;
  R2, R3 differ only in a timing line.
- Controls: NC1, NC5 fail at `exported_ens1_value`; NC2 at ens2; NC3 at ens3; NS1–NS3 at
  `exported_contract_on_refund_fields`; NC4 "Expected exactly three ensures clauses"; NC6 "Trailing export bytes";
  ctl-NR1-2 a real proof failure at the render theorem.
- DEFECT A (`check.py:166-169`): the NR1 rule passes on ANY failure; the first NR1 run (path error) got "PASS".
  DEFECT B (`check.py:21-22, 153-159`): NC4/NC6 pass on any failure before the first FORGE_BEGIN; the checker never reads
  stderr. Tonight's verdicts are honest only after the manual stderr check. Fix: require the exact failure text in stderr.
- Meaning HOLDS: the clauses are parsed in-logic from the export text; for all inputs; names and positions match the export
  signature and `FlatCore.dfy`; `refund_fields` is `forge_refundCertifiedProg$refund_fields`, the constant of the stored
  machine-model theorem (same parent `.dat` SHA-1).
- Gaps: the export digest is not in the theorem nor in `command.json` (only `go.sh` logs it). SYMMETRY: the contract is
  symmetric in charge/request; a consistent swap of inputs and outputs is undetectable; no control swaps the INPUT binding.
- Chain classes: (a) R1–R5 ⇐ flat ensures: MACHINE-CHECKED (Dafny). (b) Dafny source ≡ export: ASSUMPTION (B's
  ExportBridge: TESTED-UNPROVED, trusted Python reader). (c) HOL `evaluate_exp` meaning ≡ Dafny meaning under β: ASSUMPTION.
  (d) clauses exactly on `refund_fields`: MACHINE-CHECKED. (e) export body ↔ `refund_fields` (U294): MACHINE-CHECKED replay.
  (f) same constant in two sessions: ASSUMPTION with file evidence. (g) input encoding Dafny ↔ stdin bytes: MISSING.
  (h) output decoding Dafny ↔ HOL `refund_response_fields`: MISSING as one relation.
