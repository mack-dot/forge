# b-export-bridge REPORT (Orchestrator B, night shift 2026-11-19). DRAFT. Dafny model only. No HOL run.
Dir: results/night-shift-20261119/orch-B/b-export-bridge/ (E below). Export SHA-256 58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d (3,621 B), checked by my reader.
MACHINE-CHECKED (all via tools/dafny_locked.sh, gate options; logs in E/logs):
- ExportBridge.dfy: exit 0, 1823 verified (bridge-01.log, .csv). ExportedIffFlat: ∀x,o. ExportedContract(x,o) ⇔ FlatContract(x,o), NO side condition
  (no byte-string, no integer range). ReaderTreesAreMirrorTrees: my 3 trees == Mirror.dfy Tree1..3. ClausesAreMirrorSources.
  ExportedIffMirror (byte strings): ExportedContract ⇔ all 3 Mirror MEval = BoolV(true). ZeroAmountAllowed, HolWitnessC9, RejectAllFails.
- SliceSafetyFromExport.dfy: exit 0, 1892 verified (fromexport-01.log). A6xIffA6b (A6x ⇔ A6b for every art); SliceSafetyFromExport
  (= SliceSafetyV2OnByteStrings with A6x); FlatSpecFnMeetsA6x (non-vacuity); RejectAllFailsA6x; FromExportCoversMainRun (under SigReading,
  covers the committed 40 effect AND the zero-amount effect).
- dafny audit: ExportBridge exit 0, SliceSafetyFromExport exit 0; both reports empty tables (audit-*.md). No assume/axiom/extern/expect.
Mutant table (run_mutants.sh; gate options + --filter-symbol MutantIffFlat; logs mut-<name>-01.log):
| mutant | exit | result |
| M00 none (positive control) | 0 | 1 verified |
| M01 Le→< ; M02 And→|| ; M03 Or→&& ; M04 Imp→<== ; M06 Eq→!= ; M07 Not dropped ; M08 IntL+1 | 4 each | postcondition error |
| M05 "Neq==" (my typo: entry "=") | 2 | PARSE error, NOT a valid control; replaced by M05b Neq→== : exit 4 |
| M09 swap chargeId/requestId (in) ; M10 swap outputCharge/outputRequest ; M11 swap original/remaining | 4 each | postcondition error |
| M12 double swap (in AND out charge/request) | 0 | PASSES: invisible to the proof (expected; same for A's HOL proof) |
| RA reject-all clause set (clause 1 := !authorized; unpinned control) | 4 | postcondition error |
| D1 one byte flipped (Le→Lt) ; D1b reject-all bytes without control flag | 2 each | generator REFUSED: digest mismatch |
G1: gen_exported.py (own parser, 9-line table, fail closed; binds by position after checking names/types against parsed FlatIn and
  FlatTuple). gen-01.txt exit 0; all 9 table lines used; no other form. Second reader agreement: machine-checked tree equality above.
G4 (TEST, not proof): g4_textcheck.py, FlatCore.dfy (a89484e3…) vs export: 3 of 3 clauses SAME, 0 differences (g4-01.txt exit 0).
  Controls: source amount `<=`→`<`: clause 1 DIFF exit 1; source charge/request swap in clause 2: DIFF exit 1.
G3: BRIDGE_STATEMENT.md (87 lines). Residual pieces and classes:
  BETA-VALUES ARGUED; BETA-OPS/BETA-FORMULA ARGUED (two routes); BETA-ORDER ARGUED (double swap invisible on both sides;
  HOL name binding AS:129-136 is hand-written, read as identity); EXPORT-BYTES-ID RECORDED (digest on both sides);
  EXPORTER-ID RECORD only and NOT NEEDED for the chain (ExportedContract comes from bytes and is proved ⇔ FlatContract);
  A7-ART ASSUMPTION (art = refund_fields via β; runtime bytes = U.Encoded(...): NOT pinned by either theorem); TOOLS ASSUMPTION.
  A's HOL theorem (H1/H2 go exit 0) already discharges inside HOL: parse of the exact bytes, CakeML operator semantics,
  partiality (Rval for all values), short-circuit order, integer literal values. Remaining gap = "under β, Dafny's meaning
  of ExportedContract (≡ FlatContract, machine) equals HOL Φ1∧Φ2∧Φ3 (kernel-proved for evaluate_exps of the same bytes)",
  plus the identity name binding.
SHA-256 (new files): gen_exported.py db2acbc0…101c; ExportBridge.dfy 655534e0…2a55b; SliceSafetyFromExport.dfy 9fbfd16e…84e2;
  gen/ExportedContract.dfy 41329a00…8352; gen/ReaderTrees.dfy c66c6b79…d4f8; g4_textcheck.py f5f091a4…681a;
  make_controls.py 7e0e0cc5…447a; gen_controls.sh 963bcf2e…e563; run_mutants.sh e4527fb0…0358; BRIDGE_STATEMENT.md 882d2da0…a55b.
  Full list: E/SHA256SUMS.txt. Copies (byte-equal): inputs/ (= b-signing inputs, inputs-sha256.txt), mirror/Mirror.dfy cc846331…,
  SliceSafetyV2.dfy 1ed076d1…, SliceSafetyV2OnBytes.dfy 7577af08….
NOT RUN: any HOL; the exporter (build folder missing); a HOL-side check of the name binding (AS:129-136) by generation.
Open doubts:
- Mutant runs use --filter-symbol (only the lemma); the full gate run is on the unmutated files only.
- CakeML line citations are from the source tree A loads; the heap actually used is a separate record (heap SHA 2f5dbb71…).
- Rule note: I ran `dafny verify --help` once directly (no verification, seconds) to check --filter-symbol exists.
- gen/ExportedContract.dfy was regenerated after bridge-01 (same generator, same inputs; the generator is deterministic and M00 equals it below line 2); I did not hash the first copy.
