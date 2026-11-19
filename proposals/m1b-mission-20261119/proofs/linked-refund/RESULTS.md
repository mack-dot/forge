# W9 refine-proof: results (Dafny side only)

Scratch folder: `<session scratch folder>/m1b/W9/` (short: `W9/`).
No repository file was created or changed. No HOL ran. One Dafny process at a time.
This is one Dafny-side half of Route D. It does not link Dafny to HOL. M1-B stays open.

## 1. Inputs (byte copies; SHA-256)

| File in `W9/proof/inputs/` | SHA-256 | Source | Equal to source |
| --- | --- | --- | --- |
| `transport/spec/refund/RefundSpec.dfy` | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | working tree `spec/refund/RefundSpec.dfy`; U295 `command.json` | yes, both |
| `transport/impl/Refund.dfy` | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | working tree `impl/Refund.dfy`; U295 | yes, both |
| `transport/FlatCore.dfy` (AssessFlat) | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | U295 inputs; U294 `export-0003/input.dfy` (same hash; REPORT.md "Original FlatCore") | yes |
| `UnicodeRelation.dfy` (U262 encoder) | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | U295 `command.json` | yes |
| `transport/Transport.dfy` | `a07fec89…cdd8efc8` (full list in `audit/reached-sha256.txt`) | U295 | yes |
| `Library.dfy` + 24 `library/Std/*` files | see `audit/reached-sha256.txt` | U295 | yes (same branch blobs) |
| `transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | working tree, same path | yes |
| `transport/clearing/RefundExact.dfy` | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | working tree `clearing/RefundExact.dfy` | yes |
| U294 export `output.sexp` (not used by Dafny) | `58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d` | `export-0003` | equals REPORT.md |

The two working-tree files sit under `transport/` so that their own relative `include` lines reach the same spec copy. Their bytes are unchanged.
`Boundary.dfy` is NOT reached. The proof uses strings (the type of `AssessFlat`), not `Codes`.

## 2. New proof file

`W9/proof/inputs/LinkedRefund.dfy`, final SHA-256 `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34`.
Modules: `LinkedRefund refines RefundSpec` (non-abstract), `RefundDeterminismLinked refines RefundDeterminism` (non-abstract), `RefundExactLinked refines RefundExact` (non-abstract), `LinkedPost` (non-abstract).

## 3. Command (gate OPTIONS, solver path made absolute)

```
cd W9/proof/inputs && <HOME>/forge/.toolchain/dafny-4.11.0/dafny/dafny verify LinkedRefund.dfy \
  --solver-path <HOME>/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 \
  --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files \
  --track-print-effects --log-format 'csv;LogFileName=<run>/verification.csv'
```
Exact text per run: `<run>/command.txt`. The recorded U295 command (`dafny-0002/command.json`) had the same options except `--track-print-effects`. I used the gate list, which adds that flag. No other option was needed.
Resource limits that are NOT the command-line value: the unchanged included files carry per-declaration `@ResourceLimit` attributes: `UnicodeRelation.dfy` lines 8, 25, 45, 156, 185 (`"20e6"`, U262 as recorded); library `DivMod.dfy:1336` (`2200000`), `ModInternals.dfy:331` (`2e6`), `LittleEndianNat.dfy:444` (`10e6`), `Seq.dfy:702` (`1e6`), `Utf8EncodingForm.dfy:216` (`115e6`). My file has no `@ResourceLimit`. My file uses `@IsolateAssertions` on `Assess` and on `WitnessUnicode` (splits batches; each batch keeps the 1000000 limit).

## 4. Verification runs of LinkedRefund.dfy (5 of 5 allowed attempts used)

| Run | File SHA-256 (prefix) | Exit | Dafny summary | Wall s | Swap free before | after |
| --- | --- | --- | --- | --- | --- | --- |
| attempts/01 | `6f0b821da9c2495b…` | 4 | 1445 verified, 0 errors, 2 out of resource | 34.8 | 1173.56M | 1181.56M |
| attempts/02 | `872cd320ec3eef09…` | 4 | 1449 verified, 6 errors, 1 out of resource | 33.9 | 1189.56M | 1205.56M |
| attempts/03 | `9cc2caecebbc91c3…` | 0 | 1457 verified, 0 errors | 34.6 | 1357.56M | 1389.56M |
| attempts/04 (final) | `0d67b4838e390a33…` | 0 | 1489 verified, 0 errors | 41.3 | 1541.56M | 1510.00M |
| attempts/05-repeat (unchanged final) | `0d67b4838e390a33…` | 0 | 1489 verified, 0 errors | 43.5 | 842.56M | 914.56M |

Free disk before every run: 88 GiB. Final CSV: 1489 rows, all `Passed`; 58 rows belong to `LinkedRefund`/`LinkedPost`.
Failed attempts, kept with file and output in `W9/attempts/NN/`:
- 01: `UnflattenFlatten` and `Witnesses` out of resource. Fix: `Decode` made `opaque`; witnesses split.
- 02: `UnflattenFlatten` postcondition not proved; witness asserts failed. Cause: my mistake. `ApprovedFlattensToFlat` and `Uniqueness` do not export the approved ensures, so the witnesses could not know `d`. Fix: the witnesses call `Assess` and `AssessFlat` directly; `UnflattenFlatten` got explicit steps. No statement was weakened.
- 03: passed. 04 adds only `@IsolateAssertions` on `Assess` (for clear negative-control messages).
`dafny resolve` (no verification) ran before attempts 01, 02, 03, 04. I did not count those as attempts. The first `resolve` failed with exit 2 on an indentation warning; fixed with parentheses.

Finding: Dafny 4.11 did NOT verify the inherited bodies again in `RefundDeterminismLinked` and `RefundExactLinked`. The CSV has only `RefundDeterminism.*` and `RefundExact.*` (the abstract originals, which are parametric in the import). So `LinkedPost` proves the instance facts directly; no claim below rests on the two reuse modules.

## 5. Audit

Commands (cwd `W9/proof/inputs`; outputs in `W9/audit/`):
- (a) `dafny audit LinkedRefund.dfy --report-format md --report-file a-top-only.md --compare-report` (report file = copy of `gate/expected-audit.md`): exit 0, "0 findings". This shows the known trap: included files are not audited.
- (b) `dafny audit <33 files of audit/reached-files.txt> --report-format md --report-file b-all-compare.md --compare-report`: exit 2. "1 findings"; report does not match the empty baseline.
- (c) same 33 files, no compare: exit 0. Table: `| Std.Strings.HexConversion.CharsConsistent | False | True | False | Declaration has explicit {:axiom} attribute. | Provide a proof or test. |`

So the full closure does NOT match the empty baseline. The one finding is the library axiom below.

## 6. Forbidden-word grep over all 33 reached files

Pattern `assume|axiom|Axiom|expect|verify false|extern|Extern|\{:options|@Options|ResourceLimit|@Verify` (`audit/grep.txt`). Matches:
- `library/Std/Strings.dfy:185 @Axiom` (the HexConversion axiom).
- `UnicodeRelation.dfy:5` comment only ("imports no axiom-bearing character wrapper").
- the `@ResourceLimit` lines listed in section 3.
No `assume`, `expect`, `{:verify false}`, `extern`, `{:options}` anywhere. `LinkedRefund.dfy`: no match.

## 7. Does the proof use the library axiom?

No call path reaches it. Evidence by reading:
- `Strings.dfy:174-188`: `module HexConversion` has `@Axiom lemma CharsConsistent()` with no body (line 185-187).
- The only use of `CharsConsistent` is inside `ParametricConversion.OfInt` (`Strings.dfy:78`); each refinement calls its own copy.
- `Strings.OfInt` (`Strings.dfy:221-225`) calls `DecimalConversion.OfInt`. `DecimalConversion.CharsConsistent` has a body `{}` (`Strings.dfy:199-201`) and is verified (CSV row "Std.Strings.DecimalConversion.CharsConsistent (correctness), Passed").
- `UnicodeEncodingForm.dfy:22` imports `Strings`; its only use is `Strings.OfInt(index)` at line 310 in `DecodeErrorMessage`, which my `Decode` reaches through `DecodeCodeUnitSequenceChecked` (failure branch).
- `grep HexConversion` over the 33 files: one hit, its own declaration (`Strings.dfy:174`). Nothing refers to it.
- A Dafny lemma's ensures enters a proof only at a call. No call exists.
Conclusion: the axiom is IN the verified program (so the audit is not empty) but the dependency closure of my statements does not use it. Residual trust: that Dafny does not turn a bodiless lemma into a global axiom (its documented semantics).

## 8. Negative controls (each a separate tree under `W9/negative/<N>/`; diff in `mutation.diff`)

Final runs (built from the final file). First runs (from the attempt-03 file, without `@IsolateAssertions`) are kept in `W9/negative-run01/`; there `Assess` failed only as "out of resource" for N1, N2, N3b, N4.

| Control | Mutated file SHA-256 (prefix) | Exit | Summary | Wall s | Swap free before / after | Failing obligation in the claim |
| --- | --- | --- | --- | --- | --- | --- |
| N1 charge and request exchanged in `Unflatten` | LinkedRefund `efbf5de1…` | 4 | 1486 verified, 3 errors | 44.4 | 773.69M / 818.50M | `Assess`: RefundSpec.dfy:52 (R4 plan) not proved; `UnflattenFlatten` line 144; `FlatYieldsOnlyImages` line 156 |
| N1b charge and request exchanged in `Flatten` | LinkedRefund `8b26e909…` | 4 | 1483 verified, 4 errors, 2 out of resource | 46.9 | 818.50M / 499.44M | `FlattenShapes` line 117, `AuthorizedPreimage` line 125, `UnflattenFlatten` line 140, `FlatYieldsOnlyImages` line 156; `ApprovedFlattensToFlat` out of resource. `Assess` passes (it does not use `Flatten`). |
| N2 amount + 1 in `Unflatten` | LinkedRefund `7ac6f1d9…` | 4 | 1484 verified, 5 errors | 40.6 | 507.44M / 675.44M | `Assess`: RefundSpec.dfy:43 (R1, `Money`, line 20), :44 (R1 bound), :51 (R4 decision); `UnflattenFlatten` line 143; `FlatYieldsOnlyImages` line 156 |
| N3a flat ensures 1 (`authorized <==> guard`) dropped | FlatCore `483b20f3…` | 4 | 1469 verified, 13 errors, 7 out of resource | 44.1 | 675.44M / 560.25M | `Assess`: R1 (:43 via ValidContext :28-30), R2 (:46); several R-batches out of resource; `FlatYieldsOnlyImages` :157; `ApprovedFlattensToFlat` line 193; U262 `Transport.dfy:44` also fails |
| N3b flat ensures 2 (authorized outputs) dropped | FlatCore `30a22d79…` | 4 | 1476 verified, 12 errors, 5 out of resource | 43.0 | 568.25M / 608.25M | `Assess`: R1 (:43, :44), R2 (:46), R4 (:51, :52); `FlatYieldsOnlyImages` :156 |
| N3c flat ensures 3 (rejected outputs) dropped | FlatCore `2999b06c…` | 4 | 1484 verified, 10 errors | 40.6 | 608.25M / 704.25M | `Assess`: RefundSpec.dfy:48 (R3); `FlatYieldsOnlyImages` :156; `ApprovedFlattensToFlat` :179; `WitnessRejected` line 238 |
| N4 count 0 for an authorization (flat ensures and body both changed, so `AssessFlat` still verifies) | FlatCore `bc11503b…` | 4 | 1483 verified, 3 errors, 3 out of resource | 39.2 | 704.25M / 704.25M | `Assess`: RefundSpec.dfy:52 (R4 plan); `FlatYieldsOnlyImages` :156 (Conforming) |
| N5 `Assess` reads `response.reason` instead of the reason bytes | LinkedRefund `f566022e…` | 0 | 1491 verified, 0 errors | 39.1 | 704.25M / 736.25M | none: PASSES, as predicted |

N5 explanation. In N5 the decision reason comes from the approved input, not from the flat output. The proof then no longer depends on the `outputReason` field or on `Decode` for the reason. A wrong `outputReason` (for example a flat contract that returned `""` or another label) would not be detected. So the honest form must build `decision` and `plan` from the six outputs only. The final file does that: `Unflatten` has only the six outputs as parameters, so it cannot read `context` or `response`.
Note on N1: the run reported only R4 line 52 for `Assess`, not the R5 lines 57-63. I did not investigate why. One reported failure is enough for the control.

## 9. Scope of the result

Proved by Dafny 4.11.0 (statements in `STATEMENTS.md`):
- For every `context`, `response`, and every six values that satisfy the three flat ensures of `AssessFlat` on the UTF-8 encoded inputs, `Unflatten` of the six values satisfies every inherited ensures R1-R5 of the approved `RefundSpec.Assess`.
- Converse: any approved result flattens to those six values, and they read back to it.
- The approved contract fixes one result. Flatten is injective on conforming pairs. The flat contract yields only the two image shapes.
- Non-vacuity: accepted, rejected and non-ASCII witnesses, through contracts.
Not proved here: anything about HOL, `refund_fields`, the exported S-expression, the exporter, the wire text, or the producer.
