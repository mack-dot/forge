# The remaining Dafny-to-HOL bridge for the flat contract (b-export-bridge, 2026-11-19). A DRAFT.

Export: `…/source-model-binding-20261104/records/export-0003/output.sexp`, 3,621 B, SHA-256 `58154ddf…dd0d`
(byte-equal to `orch-A/link/run/attempt-0001/inputs/FlatCore.sexp`). CakeML paths below are under
`.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/` (the tree that A's `go.sh` loads; the HOL heap
itself is a separate record). SP = `semantics/dafny_semanticPrimitivesScript.sml`, EV = `semantics/dafny_evaluateScript.sml`,
SX = `sexp_to_dafnyScript.sml`, AS = `orch-A/link/run/attempt-0001/forge_refundExportedContractScript.sml` (= `contract-0001/proof.sml`).

## 1. What each side has machine-checked
- HOL (A, H1 and H2 `go exit 0`; `contract-0001/stdout.log` lines 42-118): for all h, env and all values,
  `evaluate_exp (state …) env exported_ensK = (state, Rval (BoolV Φk))` with Φ1 = `ok ⇔ eligible …`,
  Φ2 = `ok ⇒ a = amount ∧ r = reason ∧ c = charge ∧ q = request ∧ n = 1`, Φ3 = `¬ok ⇒ a = 0 ∧ r = «» ∧ c = «» ∧ q = «» ∧ n = 0`;
  and `exported_contract_exact`: [T;T;T] ⇔ `refund_fields charge request … reason = (ok,a,r,c,q,n)`. The parse
  (`mlsexp$parse`, `to_program`) and the evaluation are inside the HOL kernel (AS C1, C2, C3-C5).
- Dafny (this task): `ExportedClausek` = node-by-node image of exported clause k under the 9-line table below;
  `ExportedIffFlat`: ∀x,o. ExportedContract(x,o) ⇔ FlatContract(x,o) (no side condition); `SliceSafetyFromExport` from A6x.

## 2. Operator and literal table (all forms used by the 3 clauses; no other form occurs)
| export token | Dafny reading (gen_exported.py) | HOL reading (parse; evaluation) | agree on the domain? | class |
|---|---|---|---|---|
| `BinOp (Eq)` on bool | `==` (bool equality = `<==>`) | SX:173; EV:55-68, SP:234-235 `BoolV(v0 = v1)` after `value_same_type` | yes; A proves Rval for all values | IDENTICAL BY DEFINITION (under β) |
| `BinOp (Eq)` on int | `==` | same; IntV i = IntV j ⇔ i = j | yes, unbounded both | IDENTICAL BY DEFINITION |
| `BinOp (Eq)` on string | `==` on `seq<char>` | same; StrV s = StrV t ⇔ s = t (mlstring) | yes on byte strings via β (injective) | ARGUED (BETA-STRINGS) |
| `BinOp (Neq)` (string vs `""`) | `!=` | SX:175; SP:236-237 | as Eq | ARGUED (BETA-STRINGS) |
| `BinOp (And)` | `&&` | SX:183; SP:197-201 (do_sc), SP:238-241 | yes; operands total (A: Rval), so short-circuit = classical | IDENTICAL BY DEFINITION |
| `BinOp (Or)` | `\|\|` | SX:185; SP:202-205, SP:246-249 | yes, same argument | IDENTICAL BY DEFINITION |
| `BinOp (Imp)` | `==>` | SX:187; SP:206-209 (F gives T), SP:242-245 | yes | IDENTICAL BY DEFINITION |
| `BinOp (Le)` | `<=` on `int` | SX:169; SP:254-257 `i0 ≤ i1` on HOL `int` | yes; no bound on either side | IDENTICAL BY DEFINITION |
| `UnOp (Not)` | `!` | SX:154-155; EV:48-54, SP:213-214 | yes | IDENTICAL BY DEFINITION |
| `Var "n"` | bound field (sect. 3) | SX:240-244; EV:37-40 `read_local`; AS:125-136 binds names | yes; A proves no Rerr | ARGUED (BETA-ORDER) |
| `Lit (IntL d)` (0, 1, 9223372036854775807) | decimal `d` | SX:210-215 `to_int` = `fromString` (SX:32-38); SP:287 | HOL value pinned by kernel: Φ1 contains the numeral (forge_refundScript.sml:59) | IDENTICAL (machine on HOL side; decimal on Dafny side) |
| `Lit (StrL "s")` ("", duplicate_charge, service_not_delivered, returned_item) | `"s"` (ASCII [A-Za-z0-9_] only) | SX:216-221 `to_mlstring` of the atom; SP:289 | same code lists (Mirror.dfy `Literals()` checks the Dafny codes); HOL side pinned by Φ1/Φ3 numerals «…» | ARGUED (BETA-STRINGS) |

Partiality and order: the 3 clauses contain no Div, Mod, index, conversion, call or `If`. HOL `evaluate_exp` can
give `Rerr` (unbound name, type mismatch, `Abort` in do_sc); A's C3-C5 prove `Rval` for ALL values in the stated
state, so no partiality remains on the HOL side. Dafny is total on these forms. Evaluation order is irrelevant (pure,
total). Integers: Dafny `int` and HOL `int` are both the mathematical integers; amount 0 is inside both readings.

## 3. Argument order and tuple order (a charge/request swap)
| pos | Dafny FlatIn / tuple | export name (SX order, A's C2) | HOL state (AS:129-136) | refund_fields |
|---|---|---|---|---|
| in 1-9 | chargeB, requestB, original, remaining, enabled, requestOpen, candidate, amount, reasonB | chargeId, requestId, original, remaining, enabled, requestOpen, candidate, amount, reason | «chargeId»→charge, «requestId»→request, …, «requestOpen»→opened, …, «reason»→reason | charge request original remaining enabled opened candidate amount reason |
| out 0-5 | (ok, amount, reason, charge, request, count) = o.0..o.5 | authorized, outputAmount, outputReason, outputCharge, outputRequest, intentCount | «authorized»→ok, «outputAmount»→a, «outputReason»→r, «outputCharge»→c, «outputRequest»→q, «intentCount»→n | (ok,a,r,c,q,n) |
- Dafny side: gen_exported.py binds by POSITION after it checks names count and types against the parsed
  `FlatIn` and `FlatTuple` declarations. Mutants M09 (inputs swapped), M10 (outputs swapped), M11 fail (exit 4).
- M12 (inputs AND outputs swapped) PASSES (exit 0): a double swap is invisible to the Dafny proof. The same double
  swap in AS:129-136 is invisible to `exported_contract_exact` (Φ2 then reads q = request, c = charge again).
- Pinning today: the HOL name binding is hand-written and read (identity); the Dafny binding is mechanical. A cross
  witness pins output positions relative to inputs: HOL C9 `refund_fields «ch_1» «rq_1» 100 60 T T T 40 … =
  (T,40,«duplicate_charge»,«ch_1»,«rq_1»,1)`; Dafny `HolWitnessC9` accepts the same tuple and rejects the one with
  charge and request swapped. NOT pinned: that the caller of the native function puts the charge id first.

## 4. String encoding
Dafny: `FlatInputsOf` uses `U.Encoded(pre.chargeId)`, `U.Encoded(e.requestId)`, `U.Encoded(e.reason)` (UTF-8 bytes as
chars < 256; `U.EncodedIsBytes`). HOL: `charge`, `request`, `reason` are universally quantified mlstrings (chars < 256).
Neither theorem says which bytes the native program receives for a given request. That the runtime bytes equal
`U.Encoded(...)` of the Dafny model's ids is NOT pinned here (part of A7-ART below). The literals are ASCII, so their
UTF-8 bytes and code points coincide.

## 5. Residual assumptions (independent pieces)
1. **BETA-VALUES** (ARGUED). Dafny `int` = HOL `int`; Dafny `bool` = HOL `bool`; a Dafny string with every char < 256
   corresponds to the HOL mlstring with the same code list, and equality is preserved both ways.
   Discharge: one logic that holds both value spaces (a Dafny-semantics value type in HOL with a proved embedding).
2. **BETA-OPS / BETA-FORMULA** (ARGUED). Under BETA-VALUES, `ExportedClausek` ⇔ Φk. Two routes, either suffices:
   (T) the 9 table lines of section 2 plus "my parser and HOL `mlsexp$parse`/`to_program` give the same tree"
   (BETA-PARSE; corroborated: my tree = the independently generated Mirror.dfy tree, machine-checked); or
   (F) a direct reading of Φ1 (eligible_def, forge_refundScript.sml:56-64), Φ2, Φ3 against FlatContract: same atoms,
   same connectives, only ∧/∨ re-association differs. Discharge: a verified Dafny front end, or a HOL statement
   of FlatContract generated from the Dafny source by a proved translator.
3. **BETA-ORDER** (ARGUED). The name binding AS:129-136 is the identity of section 3 (a double swap is invisible to
   both proofs). Discharge: generate the HOL state from the export's parameter list (ZIP of names and values) and
   prove it in HOL; at the call site, the frame/argument decoder passes the charge id first.
4. **EXPORT-BYTES-ID** (RECORDED). Both sides read the same bytes: my reader refuses unless SHA-256 = 58154ddf…;
   A's go.sh checks the digest and `inputs_unchanged_after = true` (contract-0001/command.json).
5. **EXPORTER-ID** (RECORD only; NOT NEEDED for the chain). The Dafny side never reads the source through the
   exporter: `ExportedContract` comes from the bytes and is PROVED ⇔ FlatContract, which is proved ⇔ the AssessFlat
   contract. So exporter fidelity is provenance, not a premise. G4 (text test, 0 differences) corroborates it.
6. **A7-ART** (ASSUMPTION, outside this bridge). The Dafny parameter `art` is `refund_fields` read through β, and
   the runtime input bytes are `U.Encoded(...)` of the model's ids. Discharge: the native and frame edges.
7. **TOOLS** (ASSUMPTION). Dafny 4.11.0 + Z3 4.12.1 and the HOL4 kernel (commit 9783a499) are sound.

Answer to the precise question: A's theorem has DISCHARGED, inside HOL, the parse of the exact bytes, the CakeML
operator semantics, partiality, short-circuit order and the integer literal values. Exporter fidelity is NOT needed
(item 5). The remaining gap is items 1-3 only: "under β, Dafny 4.11.0's meaning of `ExportedContract` (equivalently
FlatContract, machine-checked) equals the HOL formula Φ1∧Φ2∧Φ3 that the kernel proved for `evaluate_exps` of the
same bytes", with the name binding read as the identity. A6x then follows from `exported_contract_on_refund_fields`
plus items 1-3 and 6.
