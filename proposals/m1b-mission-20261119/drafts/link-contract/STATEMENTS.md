# Y2 (wave 4): the HOL half of the contract link (graph links S5, S6). DRAFT

Nothing in this folder ran in HOL. No statement here is proved. "Read" means
read from a file; "measured" means a hash command ran on this machine.

## 1. Artifacts (located; loadability by reading)

| Artifact | Where | Measured | Loadable with the present tool tree? |
| --- | --- | --- | --- |
| Export (3,621 bytes) | `origin/backup/forge-local-2026-11-11`: `proposals/refund-executable-feasibility/source-model-binding-20261104/records/hol-0004/input.sexp` (also `export-0003/output.sexp`, `export-repeat/output.sexp`) | SHA-256 `58154ddf…dd0d` for all three | data file; no load needed |
| Exporter input | same branch, `records/export-0003/input.dfy`; `source-export-feasibility-20261104/records/FlatCore-original.dfy` | SHA-256 `a89484e3…1f4d`, the SAME bytes as `proofs/linked-refund/inputs/transport/FlatCore.dfy` | — |
| U294 script 1 | `records/proof-0004.sml` (= `hol-0004/proof.sml`) | `a79edc4b…` = recorded `source_sha256` | text loads `sexp_to_dafnyTheory`, `forge_refundTheory` by name |
| U294 script 2 | `records/relation.sml` | `a8f783a2…` = recorded | no `load`; needs preload + the SourceBinding `.sig`/`.sml` as `hol run` arguments |
| U294 script 3 | `records/bridge.sml` | `e9d12e06…` = recorded | loads `forge_refundCertifiedProgTheory` by name; cwd `forge_refundCertifiedProg_experiment` |
| Stored theory SourceBinding | `records/hol-0004/.hol/objs/forge_refundSourceBindingTheory.{dat,sig,sml}` | `.dat` SHA-256 `6f30ff5d…` = recorded; SHA-1 `2677fe68…` | parents: `forge_refund` `aafcbc1d…`, `sexp_to_dafny` `7bd0f755…` |
| Stored theory SourceRelation | `records/relation-0001/.hol/objs/…` | — | parent: SourceBinding `2677fe68…` |
| Stored theory CompiledInputBinding | `records/bridge-0001/.hol/objs/…` | — | parents: `forge_refundCertifiedProg` `439e5c15…`, SourceBinding `2677fe68…` |
| Present parents | `.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/{forge_refund_experiment,.,forge_refundCertifiedProg_experiment}/.hol/objs/*.dat` (built 2026-11-18) | SHA-1 `aafcbc1d…`, `7bd0f755…`, `439e5c15…` | **all three EQUAL the parent hashes stored in the U294 theories** |

Result (by reading): the three stored U294 theories name parents that exist
with the same content hashes in the present tree. So a fresh import of the
stored objects is expected to pass HOL's parent check. Not run.

Three concrete blockers for a replay WITHOUT edits (all read, none run):

1. The U294 runners `run_hol.py`, `run_bridge.py` assert the heap SHA-256
   `36f7c254…`. The present `cakeml/misc/cakeml-heap` is `66b1654b…`
   (rebuilt 2026-11-17). They stop at the assert. Use the recorded
   `run_case.py` of 2026-11-17 (no heap pin) or edit the one line.
2. The raw folder `results/refund-source-binding-2026-11-04/` that the
   recorded `argv` names is not on disk. Restore the inputs from the backup
   branch into a new run folder.
3. `load` by name: `forge_refund_call_experiment/Holmakefile` has no
   `INCLUDES`; `forge_refundProg_experiment` (named by the CertifiedProg
   `INCLUDES`) is an EMPTY folder made on 2026-11-18. Whether `load
   "forge_refundTheory"` resolves today cannot be decided by reading. My
   scripts add the folders to `loadPath` explicitly. Probe H0 decides.

Not built in the present tree (read): `vcg/` (no `.hol/objs`), so
`conditions_hold` is not available; `dafny_eval_relTheory` (with `eval_true`)
has no objects in `semantics/.hol/objs`.

## 2. Is the flat contract of `LinkedRefund` the same as the U294 export?

**Yes at the level of source text, by measurement:** `LinkedRefund` reaches
`FlatRefund.AssessFlat` only through `transport/FlatCore.dfy`, and that file
is byte-equal (SHA-256 `a89484e3…`) to the exporter input of U294 `export-0003`.
No other `module FlatRefund` is in the 34 included files (grep).

Clause by clause (export read by eye; independent parser: worker Y12):

| Dafny (`FlatCore.dfy`) | Export (`input.sexp`) | HOL meaning (my value lemmas) | Same? |
| --- | --- | --- | --- |
| 9 inputs `chargeId:string … reason:string` | `(("chargeId" (StrT)) … ("reason" (StrT)))`, same order | `exported_contract_shape` pins names, types, order | yes |
| 6 outputs `authorized:bool … intentCount:int` | same names, `BoolT IntT StrT StrT StrT IntT` | pinned by shape | yes |
| no `requires`; `modifies {}` | `()` reqs, `()` reads, `()` mods | pinned by shape | yes |
| E1 `authorized <==> c != "" && q != "" && enabled && requestOpen && 0 <= original <= 9223372036854775807 && 0 <= remaining <= original && candidate && 0 <= amount <= remaining && (reason == "duplicate_charge" \|\| … \|\| reason == "returned_item")` | `Eq (Var authorized) G`; `G` left-nested `And`, chains split into two `Le`, `Or` left-nested | `BoolV (ok ⇔ eligible …)` | yes (association differs; value equal) |
| E2 `authorized ==> outputAmount == amount && outputReason == reason && outputCharge == chargeId && outputRequest == requestId && intentCount == 1` | `Imp (Var authorized) (And (And (And (And …))))` | `BoolV (ok ⇒ a = amount ∧ r = reason ∧ c = charge ∧ q = request ∧ n = 1)` | yes |
| E3 `!authorized ==> outputAmount == 0 && outputReason == "" && … && intentCount == 0` | `Imp (UnOp Not (Var authorized)) …` | `BoolV (¬ok ⇒ a = 0 ∧ r = «» ∧ c = «» ∧ q = «» ∧ n = 0)` | yes |

Differences (none is a mismatch of the contract; each is a named assumption or a gap):

- D1 Strings. Dafny 4 `string` = sequence of Unicode scalar values; HOL
  `mlstring` = list of 8-bit chars. The common domain is Dafny strings with
  every char < 256. `LinkedRefund` uses the contract only at `U.Encoded(·)`
  values (`EncodedIsBytes`: every char < 256) and at `""`; `refund_fields`
  outputs only inputs or `«»`. So the use stays inside the common domain.
  The map between the two is assumption S7 (not machine-checked).
- D2 Names. HOL `refund_fields charge request original remaining enabled
  opened candidate amount reason` is positional; the HOL state binds the
  export names to these positions (`requestOpen` ↦ `opened`). A swap of
  `enabled` and `opened`, or of `chargeId` and `requestId` inside the guard,
  is INVISIBLE to clause E1 (the guard is symmetric in them). The id swap is
  caught by E2 (controls NC2, NS2). The `enabled`/`opened` swap is caught by
  nothing, and it is harmless: both are plain conjuncts in E1 and in the
  approved `Eligible`.
- D3 Integers: unbounded on both sides; no `nat`, no bounded type. The
  literal `9223372036854775807` is read by the published parser; U294
  `source_full_result` already depended on its value. Outputs `int` both sides.
- D4 Operators (`<==>`→`Eq`, `!=`→`Neq` exist only through the U294 patch of
  the exporter). Their HOL meaning is checked by C3 to C5; their Dafny meaning
  is assumption S7.
- D5 **GAP (new):** `proofs/linked-refund/run_check.py` pins the three
  approved copies and the proof file, but NOT `inputs/transport/FlatCore.dfy`.
  Today the bytes are equal (measured). If the copy changes, the Dafny half
  still passes but no longer speaks of the exported contract. One pin line
  closes it (`a89484e3…`).
- D6 The HOL theorem evaluates the clauses in a state that the script
  builds (`init_state 0` with the 15 locals). The published "method meets
  its spec" notion (`conditions_hold`, vcg) is not built in the tree.

## 3. Draft statements (file `forge_refundExportedContractScript.sml`)

Notation: `S(h, in9, ok,a,r,c,q,n)` = `exported_contract_state …`; `E` =
`exported_ensures = [exported_ens1; exported_ens2; exported_ens3]`, defined
from the PARSED export; `rf` = `forge_refundCertifiedProg$refund_fields`.

- C1 `exported_contract_decode`: the export parses completely (`INR (se, [])`) to `exported_contract_program`.
- C2 `exported_contract_shape`: the program is ONE method `AssessFlat`, inputs/outputs as in section 2, `[]` requires/reads/mods, ensures EXACTLY `exported_ensures`.
- C3, C4, C5 `exported_ens{1,2,3}_value`: for ALL `ok a r c q n`, each clause evaluates without error, leaves the state unchanged, and gives the HOL values in the table above.
- C6 `exported_contract_value`: the list `E` gives `Rval [three values]`.
- **C7 `exported_contract_on_refund_fields` (the S6 theorem):**
  `rf charge request original remaining enabled opened candidate amount reason = (ok,a,r,c,q,n) ⇒ evaluate_exps (S …) env E = (S …, Rval [BoolV T; BoolV T; BoolV T])`, for all `h env` and all typed inputs (all `int`, all `bool`, all `mlstring`).
- C8 `exported_contract_exact`: the clauses all hold ⇔ `rf … = (ok,a,r,c,q,n)` (the exported contract leaves no freedom).
- C9 `exported_contract_witnesses`: `rf «ch_1» «rq_1» 100 60 T T T 40 «duplicate_charge» = (T,40,…,1)`; amount 61 gives `(F,0,«»,«»,«»,0)` (the Dafny witnesses of `LinkedRefund`).
- H4 (file `forge_refundExportedRenderScript.sml`) `exported_contract_on_rendered_output`: if the COMPLETE rendered text of `rf …` is parsed and read by `refund_response_fields`, no bytes remain and the six fields read back satisfy E.

The theorems do not use the method body. U294 `source_compiled_fields` relates the body.

Composed reading (two kernels, NOT one theorem): S3 (Dafny: any six values
that satisfy the flat contract on the encoded inputs give the approved
result) + C7/C8 (HOL: `refund_fields` gives exactly the six values that
satisfy the exported contract) + the assumptions below ⇒ the six fields of
`refund_fields` on `⌈Encoded(·)⌉` inputs decode to THE approved result.

## 4. Assumptions that stay after C7 and C8, and the smallest way to shrink each

| # | Assumption | Smallest way to shrink it |
| --- | --- | --- |
| A1 (S4) | The export is a faithful image of the `FlatCore.dfy` contract (patched exporter, declares 4.10.1; build gone) | A checked round trip instead of a trusted exporter: a short printer turns the S-expression back into Dafny clauses, and pinned Dafny proves each printed clause `<==>` the `FlatCore.dfy` clause for all inputs and outputs. The trust moves from `Bake.cs` to a printer of about 100 lines that a person can read in full. Until then: a review of the 3,621 bytes by a person (table above), and Y12's independent parse |
| A2 (S7) | Dafny's `&&` `\|\|` `==>` `<==>` `!` `<=` `==` `!=` on `bool`, `int`, `string` mean HOL `∧ ∨ ⇒ ⇔ ¬ ≤ =` | C3 to C5 already reduce the HOL side to plain HOL logic. What stays is an 8-row table about Dafny only (operator, type, the Dafny reference text). Make it one owner-approved assumption with that table; no tool can close it with the pinned tools |
| A3 (S7) | A Dafny string with all chars < 256 and the HOL `mlstring` with the same codes are "the same value"; equality agrees | State the bridge on code lists only (Dafny `seq<int>` of `s[i] as int`, HOL `MAP ORD (explode s)`); add the HOL lemma `s = t ⇔ MAP ORD (explode s) = MAP ORD (explode t)`. Then the assumption is about integer lists only |
| A4 | `int`/`bool` identification across kernels (T4) | none beyond A3's form; keep it named |
| A5 (D6) | "the ensures hold" = `evaluate_exps` in the built state gives three `BoolV T` | Generalise C3 to C7 to every state `st` with `st.locals = L` (one more lemma); later restate with `conditions_hold` after the vcg theories are built |
| A6 | The nine values given to `refund_fields` are the encodings of the approved inputs | Outside this link: S8 (wire reader), Q1/Q5 canonical input |
| A7 | HOL kernel and the identity of loaded theories (V3, V4) | the closure check of B4 |
| A8 (S3a) | The Dafny half: Dafny/Z3 soundness and the library axiom | worker Y10 |

## 5. Not covered

Cut or empty output (X13); bytes on descriptor 1 (X9); the real process
(X8); non-UTF-8 byte inputs (C7 holds for them, the approved contract says
nothing about them); the wire reader's extra spellings (S8).
