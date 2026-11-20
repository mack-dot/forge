# APEX-2: the Dafny <-> HOL4 contract link for the refund slice (Profile A)

CURRENT none. Stage 9 deferred. Stage 12 unauthorized. `end_to_end=false`.
**M1-B OPEN.** Not a stage. No protected or frozen path changed. NOT merged
by the agent.

Owner text: `proposals/forge2-native-silicon-sink/OWNER_TEXTS.md`, Text 7,
section "GATE APEX-2". Uncertainty entries: `unsure.md` U800 to U806.
Graph: [TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md](TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md).
Review: [REVIEW.md](REVIEW.md).

Every HOL result here is MODEL level, on one machine, with stored older
parent theories. It is not a clean replay and not an independent replay.
Every Dafny result is a source-level result about a model.

## 1. What existed before (not proved again)

Night shift, link cases H1 and H2 (`hol run`, not Holmake): the three
`ensures` clauses of the export (3,621 bytes, SHA-256 `58154ddf…dd0d`),
read in the logic by the published parser and evaluated by the published
Dafny semantics, hold exactly on `refund_fields`
(`exported_contract_exact`). Three transitions stayed assumptions:

- T2b: the Python reader that turns the export bytes into a Dafny predicate
  is right.
- T3: the Dafny meaning of the three clauses is the HOL meaning.
- T4: the exporter is faithful (Dafny source to export bytes).

## 2. The design

```text
Dafny: R1-R5  <=  FlatContract  ==  contract of the real method AssessFlat     (existing, Dafny)
Dafny: contract of AssessFlat  <=>  FlatPlain on character codes               (NEW, Dafny, D1 D2 D3)
       FlatPlain (Dafny text)   ~   flat_plain (HOL term)                      (NEW, the BOUNDARY: NOT machine-checked)
HOL:   flat_plain on byte codes <=> refund_fields gives these six values       (NEW, HOL, FC1)
HOL:   flat_plain on byte codes <=> the three exported clauses hold            (NEW, HOL, FC3; a cross-check, not on the path)
```

`flat_plain` is one plain HOL formula over integers, booleans and lists of
integers. The boundary carries only `/\ \/ ==> <=> ~ = <=`, integer
literals and integer-list literals. The export, the exporter, the HOL
reader of the export and the Python reader are NOT on the path
"`refund_fields` meets the contract of `FlatCore.dfy`".

## 3. Theorem table (actual exits)

Command for rows H: `hol/run_hol.sh <tool-tree> <new-folder>`, which runs
`Holmake --no_prereqs` in a copy of `hol/` (heap `cakeml/misc/cakeml-heap`).
Actual exit **0** in three runs (`records/hol/run-0001`, `run-0002`, and a
third run through `run_hol.sh`). Class of every H and R row:
MACHINE-CHECKED in HOL4, model level, same machine. Every stored theorem
has 0 hypotheses, no axiom, and only the tag `DISK_THM`. Exact printed
statements: the lines `FORGE_STATEMENT` of the three logs in
`records/hol/run-0001/`.

| Id | Theorem (theory) | Exact statement | Premises |
| --- | --- | --- | --- |
| H-C7 | `exported_contract_on_refund_fields` (`forge_refundExportedContract`) | as night-shift case contract-0001; the nine statements are EQUAL text to the stored ones | 1 (the equation on `refund_fields`) |
| H-C8 | `exported_contract_exact` (same) | the three exported clauses evaluate to `[BoolV T; BoolV T; BoolV T]` ⇔ `refund_fields … = (ok,a,r,c,q,n)` | none |
| FC0 | `codes_11`, `codes_bytes`, `codes_onto` (`forge_refundFlatContract`) | `codes s = codes t ⇔ s = t`; `EVERY (λx. 0 ≤ x ∧ x < 256) (codes s)`; `EVERY (λx. 0 ≤ x ∧ x < 256) l ⇒ ∃s. codes s = l` | none; the range premise in the third |
| **FC1** | `refund_fields_flat_plain` (same) | `refund_fields charge request original remaining enabled opened candidate amount reason = (ok,a,r,c,q,n) ⇔ flat_plain (codes charge) (codes request) original remaining enabled opened candidate amount (codes reason) ok a (codes r) (codes c) (codes q) n` | none |
| FC2 | `eligible_flat_plain` (same) | `eligible … ⇔ ∃a r c q n. flat_plain (codes charge) (codes request) … (codes reason) T a r c q n` | none |
| FC3 | `exported_contract_flat_plain` (`forge_refundFlatExported`) | the three exported clauses evaluate to true ⇔ `flat_plain (codes charge) … n` | none |
| FC4 | `flat_plain_functional`, `flat_plain_total` (`forge_refundFlatContract`) | at most one six-tuple; one always exists (all integer lists) | none |
| FC5 | `flat_plain_fallback` (same) | `flat_plain … F a r c q n ⇒ a = 0 ∧ r = [] ∧ c = [] ∧ q = [] ∧ n = 0` | 1 |
| FC6 | `flat_plain_witnesses` (same) | accepted case with different ids; the same case with the two output ids swapped is refuted; amount 61 of 60 gives the zero answer; `original = 9223372036854775807` accepted and `9223372036854775808` refused | none |

`flat_plain_def` (the contract; printed in the log) and `codes_def`
(`codes s = MAP (λc. &ORD c) (explode s)`) are definitions.

Rows R: command `python3 -I -B run_case.py RA-FLAT-0002 RA-FLAT.sml <146
stored parent files> <FlatContract .sig .sml>` (`hol run`, heap
`cake_compile_heap`; NOT Holmake: the parents are the stored theories of
the M1 chain, which have no Holmake build). Actual exit **0**, 126.4 s,
3,186 MiB. A first run (RA-FLAT-0001) gave the same `.dat`.

| Id | Theorem (`forge_refundRouteAFlat`) | Statement | Premises |
| --- | --- | --- | --- |
| R1 | `refund_route_a_flat_plain_shape` | the stored `refund_model_frame_decision_shape` (case L2d-0001) with its last conjunct rewritten: for the strictly parsed descriptor-1 output `g = (ok,a,r,c,q,n)`, `flat_plain (codes charge) … n` | 12, unchanged (section 6) |
| R2 | `refund_entry_forces_plain_user_state` | `refund_entry_pre_sl sl s h stk e ⇒ ¬TBI0 ∧ ¬TBI1 ∧ ¬SA0 ∧ ¬E0E ∧ EL = 0 ∧ exception = NoException` | 1 |
| R3 | `refund_entry_refuses_tagged_user_state` | `s.TCR_EL1.TBI0 ∨ s.SCTLR_EL1.SA0 ⇒ ¬refund_entry_pre_sl sl s h stk e` | 1 |

Rows D: Dafny 4.11.0, Z3 4.12.1, the options of `gate/backends/dafny.py`.
Class: MACHINE-CHECKED in Dafny (source level, model).

| Id | File | Statement | Actual exit |
| --- | --- | --- | --- |
| D1 | `dafny/HolLink.dfy`, method `AssessFlatMeetsHol` | every result of a CALL of the real `FlatRefund.AssessFlat` satisfies `FlatPlain` on the character codes | 0; "11 verified, 0 errors" |
| D2 | same, method `HolMeetsAssessFlat` | any six values that satisfy `FlatPlain` on the codes ARE the result of `AssessFlat` | same run |
| D3 | same, `CodesInjective`, `CodesLiterals`, `Witnesses` | `Codes` is injective; the literals; the five witnesses of FC6 | same run |
| D4 | `dafny/HolSlice.dfy`: `FlatContractIffHol`, `A6hIffA6`, `A6hbIffA6b` | predicate `FlatContract` of `SliceTheorem.dfy` ⇔ `FlatPlain` on codes; hypothesis A6 restated; the same on byte inputs only | 0; "1583 verified, 0 errors" (twice: alone, and inside `check_link.py --slice`) |

## 4. The translation boundary (NEVER call it machine-checked)

Class: **ASSUMPTION, narrowed; the check is TESTED-UNPROVED.** Name:
BETA-PLAIN. It has four parts:

1. The ML function `dafny_of_term` (in
   `hol/forge_refundFlatContractScript.sml`, outside the HOL kernel) prints
   the right-hand side of `flat_plain_def` as the text of
   `dafny/HolFlatGenerated.dfy`, under a table of 10 rows (variable; `/\`;
   `\/`; `==>`; `~`; `=` at bool; `=` at int or int list; `<=` at int;
   non-negative integer literal; integer-list literal). Every binary form
   has its own brackets. Any other term form stops the build.
2. HOL `int`, `bool`, `int list` and Dafny `int`, `bool`, `seq<int>` mean
   the same mathematical integers, booleans and finite integer sequences.
3. A HOL `mlstring` and a Dafny `string` are the same value exactly when
   `codes` (HOL) = `Codes` (Dafny). This needs every Dafny character below
   256. The map is byte = character code. It is not a UTF-8 decoding. On
   the Dafny side the approved text is held as `RefundUnicode.Encoded`
   (its UTF-8 bytes, one character per byte).
4. HOL4 with the loaded parent theories, and Dafny 4.11.0 with Z3 4.12.1,
   are sound; the loaded `forge_refund` and `forge_refundCertifiedProg`
   are the theories of the compiled program (file evidence only).

The check `check_link.py` (SHA-256
`ccd17098f974076d905b97f028fd0c84df5a7ac47033ca2184f9ecf17a5e3f14`): pins of 17 files in `PINS.json`
(14 required keys); the generated file must equal the text in both
recorded HOL logs; Dafny must give "11 verified, 0 errors", and with
`--slice` also "1583 verified, 0 errors" for `HolSlice.dfy`. Actual: exit
**0**, `CHECK_LINK PASS (HolLink and HolSlice)`
(`records/dafny/check_link-full.log`). Without Dafny it exits 5 (PARTIAL, not a pass).
With `--skip-pins` it exits 3 (CONTROL MODE, never a pass). The check
compares a file with a log of the same printer. It does not check the
printer. What tests the printer: the three printer controls below, and the
fact that Dafny proves the printed text equal to the contract of
`AssessFlat` in both directions.

Not detectable by any proof or control: a CONSISTENT swap of `chargeId`
and `requestId` on inputs AND outputs at the same place. The contract is
symmetric under it, so it changes no meaning. A swap on one side only is
detected (HN1, HN9, XN3, DN1, DN8, DN12, DN13). That the native caller
passes the charge id first is outside this link (T4i).

## 5. Negative controls: 32 of 32 count

Record: `records/controls/controls.json` (written by
`controls/eval_controls.py`, actual exit 0). A control counts only with
the exact expected failure text.

| Group | Controls | Actual |
| --- | --- | --- |
| HOL statement (9) | HN1 output ids swapped; HN9 input ids swapped; HN2 MaxMoney + 1; HN3 MaxMoney − 1; HN4 `candidate` deleted; HN5 `amount <= remaining` altered; HN8 `0 <= amount` to `1 <= amount`; HN6 fallback count 1; HN7 reason byte | Holmake exit 1 each; `Tactic failure proving "refund_fields_flat_plain"`; no other failure |
| Export (5) | XN1 bytes changed, pin kept; XN2 MaxMoney + 1; XN5 MaxMoney − 1; XN3 ids swapped; XN4 `candidate` replaced (XN2 to XN5 with the pin moved to the mutant) | Holmake exit 1 each; XN1 `Export SHA-1 differs from the pin`; XN2, XN4, XN5 at `exported_ens1_value`; XN3 at `exported_ens2_value` |
| Printer (3) | PN1 `<=` printed `<`; PN2 `/\` printed `\|\|`; PN3 arguments reversed | Holmake exit 0 (HOL cannot see a printer fault); the file differs; `check_link.py` exit 1 at the pin; Dafny exit 4 with postcondition errors in `HolLink.dfy` |
| Dafny source (6) | DN1 ids swapped; DN2, DN3 MaxMoney ± 1; DN4 `candidate` deleted; DN5 fallback count 1; DN6 reason literal (clause and body changed together) | check exit 1 at the pin; with `--skip-pins` exit 4; postcondition errors only in `HolLink.dfy` |
| Generated file and link (9) | DN7, DN9 MaxMoney ± 1; DN8 ids; DN10, DN11 guard conjuncts; DN14 `true`; DN15 `false`; DN12, DN13 one-side id swap in `HolLink.Plain` | the same |

## 6. What R1 does NOT say (Route A, honest form)

R1 is the reachable-call ("shape") form. Its 12 premises are assumptions
about the real machine. None is proved for the real process:

- P1 `refund_entry_pre_sl`: the entry state. By R2 it forces TBI0 = TBI1 =
  SA0 = E0E = F at EL0. By R3 a state with TBI0 or SA0 set does NOT meet
  it. The records say that the real user state has TBI0 and SA0 set (U473;
  not observed on this machine). So R1 speaks of the ERASED state only.
  The step-level erasure results (E1-0003, EF-0001, EE-0001) are not lifted
  to a run (ML-08, ML-09 MISSING). R1 does not use them.
- P2 to P6: alignment, heap bounds, heap clear, program addresses.
- P7: interference keeps the program memory.
- P8, the FFI premise, simulation form: the contract ONLY at calls that
  meet the shape predicate (read and write: `4 <= REG 3`; `fficlose`,
  index 2: `REG 1 = 8` and `REG 3 <> 0`; open_in: `REG 3 <> 0`). Nothing
  is said about a call outside the shape. The night-shift review found
  that no environment that describes the present C meets even this form
  (review-L2d); the signed-length gap at close (`¬word_msb`) is not in the
  predicate. P8 is an ASSUMPTION. It is not the false all-states premise
  `refund_env_ok_sl`, and it is not proved.
- P9: standard input is exactly the well-formed request. P10 to P12: the
  file-system model.
- The conclusion is under `refund_strict_parse (fd1_written io) = SOME g`.
- Not in any premise: the ARMv8 model is the silicon; `basis_ffi` is the
  real kernel I/O; the loader.

## 7. T2b, T3, T4

| Transition | Before | Now | Why |
| --- | --- | --- | --- |
| T2b reader of the export bytes | ASSUMPTION | **NOT CLOSED. Off the path of this link.** Still an ASSUMPTION for the route through `ExportBridge.dfy` (A6x) | the link no longer reads the export on the Dafny side |
| T3 Dafny meaning = HOL meaning | ASSUMPTION (BETA; no artefact) | **NARROWED, not closed.** ASSUMPTION BETA-PLAIN (section 4) with a pinned check that is TESTED-UNPROVED | FC1 + D1 + D2; HOL's Dafny semantics is no longer on the path |
| T4 exporter fidelity | ASSUMPTION | **NOT CLOSED. Off the path of this link.** For the three `ensures` clauses only, a cross-check now exists: FC3 with D1, D2 (under BETA-PLAIN and the published parser and semantics). Nothing for the method body; no rebuild of the exporter | the link compares with `FlatCore.dfy` directly |

Not changed: T4i (input encoding), T8 to T22, S1, every X row's class.

## 8. Repeat and regression

- HOL exports: `records/hol/exports.json`. The nine files (`.dat`, `.sig`,
  `.sml` of three theories) and the generated Dafny file are byte-identical
  in run-0001 and run-0002. A third run gave the same `.dat` files.
- The tool tree was only read: no file in it is newer than the first job.
  Holmake ran a `.hol_preexec` hook of the HOL tree (`asl-equiv`); it did
  nothing because its folder exists.
- Scratch-clone regression of commit `6606720f` (`records/regression.json`,
  `unsure.md` U807): 28 of 28 Stage EXIT cases exit 0;
  `check_frozen_pr_gate.py` exit 0; link checks of 8 files exit 0 (0
  dangling links); six EXIT scripts with `--case evidence` exit 0, bundles
  byte-identical to the tracked records; 0 protected paths changed.
- Hosted `gate/pr_check.py` on pull request 66 at `6606720f`: exit 3
  (UNSUPPORTED), run 44661325260. That is the expected result.

## 9. NOT RUN, and limits

- No clean replay and no independent replay of any HOL result (V4, V5).
- `hol/` cannot be built from a clone: the tool tree is not tracked.
- R1 has no Holmake build. Stages 7, 9, 10: NOT RUN.
- One review, by a worker of the same model family on the same machine.
  The repairs were not reviewed again.
- The count "1,486" of the owner text is the Dafny run WITHOUT the library
  axiom module (S3a). It was not run again here.
