# Step I.1a: feasibility of a machine-checked link (Plan agent, Fable, read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

# M1-B feasibility: linking the approved Dafny refund contract to the HOL4 model

Read-only study. I ran no HOL, Holmake, Dafny or build. I wrote no file.

Path shorthand used below:
- `D` = `<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny`
- `BK` = git branch `origin/backup/forge-local-2026-11-11`, directory `proposals/refund-executable-feasibility`

## 0. Headline

- Most of "Route A" already exists. U294 exported the flat method WITH its three `ensures` from a patched Dafny front end. HOL parsed that text and proved the parsed `ensures` true for all typed inputs. HOL also proved the outputs equal `refund_fields`.
- The Dafny side already proves a flat-to-approved relation (U262 `Transport.dfy`, U295 `Boundary.dfy`). Its postconditions mention only `R.Eligible`. They never mention `decision` or `plan`.
- The real remaining gap is narrower than the 18-row matrix suggests. It has three parts:
  1. No Dafny theorem ties the flat outputs to `(Decision, seq<RefundIntent>)` under the approved `ensures` text (matrix rows 10 to 15, 17).
  2. No HOL theorem states "the exported contract holds on `refund_fields`" as one statement.
  3. No tool connects Dafny's meaning of the flat contract to HOL's meaning. This cannot be closed by any route found. It can be shrunk to a small named fragment.
- Recommendation: a refinement route (Route D below). A new Dafny module `refines RefundSpec`, so Dafny checks the approved `ensures` text itself with no transcription. The HOL side reuses the retained U294 export. The VCG is optional.
- Hard limit: the result is "M1-B with named assumptions", not an inter-kernel proof.

## 1. Facts read from the pinned CakeML Dafny front end

### 1.1 Supported Dafny features

- Types are `BoolT | IntT | StrT | ArrT type` only. `D/dafny_astScript.sml:11-17`.
- There are no datatypes, sets, sequences, tuples or `char`. Same lines.
- Binary operators are `Lt Le Ge Eq Neq Sub Add Mul And Or Imp Div Mod`. The only unary operator is `Not`. `D/dafny_astScript.sml:19-25`.
- There is no `Iff` and no set membership.
- Literals are bool, int and `mlstring`. `D/dafny_astScript.sml:27-32`.
- Expressions: `Lit, Var, Exp_If, UnOp, BinOp, ArrLen, ArrSel, FunCall, Forall, Old, OldHeap, Let, ForallHeap, Prev, PrevHeap, SetPrev`. `D/dafny_astScript.sml:34-60`.
- There is no string length, index or concatenation. `ArrLen`/`ArrSel` are for arrays.
- String equality is supported. `do_bop Eq/Neq` works on any two values of the same type, including `StrV`. `D/semantics/dafny_semanticPrimitivesScript.sml:233-237`, `:217-223`.
- A string value is `StrV mlstring`, a byte string. `D/semantics/dafny_semanticPrimitivesScript.sml:20-27`. `all_values StrT` is all `mlstring`s, `:359-364`.
- Methods carry `requires`, `ensures`, `reads`, `decreases`, outs and `modifies`: `Method name ins req ens reads decreases outs mod body`. `D/dafny_astScript.sml:102-108`.
- Functions exist in the AST (`:109-113`) and in the semantics (`D/semantics/dafny_evaluateScript.sml:86-107`).
- The VCG rejects any program that contains a Function: `dependencies … | _ => fail «dependencies: Functions unsupported»`. `D/vcg/dafny_vcgScript.sml:466-475`. Also `can_get_type (FunCall _ _) ⇔ F`, `D/vcg/dafny_wp_calcScript.sml:153`.
- A program is one module with the default class. `D/dafny_astScript.sml:127-131`.
- `Forall` over a typed variable is in the semantics. `D/semantics/dafny_evaluateScript.sml:108-110`; `eval_forall` at `D/semantics/dafny_semanticPrimitivesScript.sml:395-406`.

Consequence for the approved spec. None of these can be expressed: `Context`, `ModelResponse` (7 constructors), `Decision`, `RefundIntent`, `seq<RefundIntent>`, `|plan|`, `intent in plan`, `reason in {…}`, `abstract module`, `refines`. The membership test can only be written as three `==` joined by `||`.

### 1.2 How a Dafny program gets into HOL

- A fork of the Dafny tool has a `bake` command that writes an S-expression. `D/examples/README.md` names the fork `dnezam/dafny`, branch `feat-sexp`, and the command `dafny bake foo.sexp foo.dfy`.
- HOL parses it with `to_program`. `D/sexp_to_dafnyScript.sml:578-594`. Methods are read with nine fields including `ens`, `:539-560`.
- The parser accepts `Lit, Var, Exp_If, UnOp, BinOp, ArrLen, ArrSel, FunCall, Forall, OldHeap`. `:227-336`. Types at `:103-125`. Operators at `:161-196`.
- The parser is a HOL function evaluated by `EVAL`. It is not a trusted component beyond HOL. The C# exporter is trusted.

What U294 did (`BK/source-model-binding-20261104/REPORT.md`, `records/hol-0004/proof.sml`, `records/bridge.sml`, `records/relation.sml`, `frontend/frontend.patch`):
- It patched one file, `Bake.cs`, of the fork (upstream commit `6eb1ed63…`, declares Dafny 4.10.1). The patch accepts one named leaf module. It maps `Iff` to `Eq`. It maps string `SeqEq/SeqNeq` to `Eq/Neq`. It maps a literal empty `modifies {}` to an empty frame.
- It exported `FlatCore.dfy` (`module FlatRefund`, `method AssessFlat`, nine flat inputs, six outputs, three `ensures`) to a 3621-byte S-expression. SHA256 `58154ddf…`. Retained at `BK/source-model-binding-20261104/records/export-0003/output.sexp`. Source at `…/export-0003/input.dfy`.
- HOL theorems in `forge_refundSourceBinding`:
  - `source_decode`: the exact bytes parse fully to `source_program`.
  - `source_signature`: one method, typed ins and outs, `source_ensures`, `source_body`.
  - `source_full_result`: all six outputs equal the `eligible` conditionals.
  - `source_postconditions`: `evaluate_exps final env source_ensures = (final, Rval [BoolV T; BoolV T; BoolV T])` for all typed inputs, any heap, any env.
  - `mapped_operators`.
- `forge_refundCompiledInputBinding.source_compiled_fields`: the parsed method's six outputs equal `refund_fields …`.
- `forge_refundSourceRelation.source_model_result`: the parsed method agrees with `refund_body`.
- Recorded times: about 167 s and 206 s for the source proof, about 7 s each for the other two (REPORT.md).

Important fact about the compiled program. The binary is not produced by the Dafny compiler. It comes from the CakeML translator applied to the HOL function: `val _ = translate refund_fields_def;` in `BK/exception-compiler-20261105/records/replay-sources/forge_refundCertifiedProg.sml:40-41`. So the model the ARM64 proof targets is the HOL function `refund_fields` / `eligible`. The Dafny AST `refund_body` is a side model. It is related by `refund_fields_original_method` (same file, lines 18-36) and by U294.

### 1.3 The VCG soundness theorem

Two theorems compose.

`D/vcg/dafny_vcgProofScript.sml:230-234`:
```
Theorem mets_vcg_correct:
  ∀mets vcs.
    mets_vcg mets = INR vcs ∧ (EVERY (λ(vs,p). forall vs p) vcs) ⇒
    proved_methods (set mets)
```

`D/vcg/dafny_wp_calcScript.sml:7464-7490` (`methods_lemma`, exported as `methods_correct` at `:7528`):
```
∀m. proved_methods m ⇒
  ∀x st name mspec body env mods mod_locs.
    x = eval_measure st env (mspec.rank, mspec.decreases) ∧
    Method name mspec body ∈ m ∧
    st.locals_old = st.locals ∧ st.heap_old = st.heap ∧ state_inv st ∧
    dest_Vars mspec.mods = INR mods ∧
    LIST_REL (mod_loc st.locals) mods mod_locs ∧
    conditions_hold st env mspec.reqs ∧ compatible_env env m ∧
    strict_locals_ok mspec.ins st.locals ∧
    locals_ok mspec.outs st.locals ∧
    ALL_DISTINCT (MAP FST mspec.ins ++ MAP FST mspec.outs) ⇒
    ∃st' out_vs.
      eval_stmt st env body st' (Rstop Sret) ∧
      st'.locals_old = st.locals_old ∧ st'.heap_old = st.heap_old ∧
      valid_mod st.heap (MAP get_loc mod_locs) st'.heap ∧
      locals_ok (mspec.ins ++ mspec.outs) st'.locals ∧ state_inv st' ∧
      LIST_REL (mod_loc st'.locals) mods mod_locs ∧
      conditions_hold st' env (MAP (wrap_Old (set (MAP FST mspec.ins))) mspec.ens) ∧
      LIST_REL (eval_exp st' env) (MAP (Var o FST) mspec.outs) out_vs
```

- Yes. It lets one conclude inside HOL that a method terminates and its `ensures` hold in the final state, for every start state meeting the side conditions. It is total correctness.
- Side conditions: the VCs must be proved by hand in HOL. A VC has the form `forall vars prop`, defined at `D/vcg/dafny_wp_calcScript.sml:980-989`. There is no SMT solver. Other conditions: `requires` hold; inputs are typed and initialised (`strict_locals_ok`, `:971-978`); `state_inv`; old state equals current state; names are distinct; the environment holds the same methods (`compatible_env`, `:1009-1016`).
- `ensures` are checked with inputs wrapped in `Old`. `D/vcg/dafny_vcgScript.sml:410-422`.
- VC proofs in the examples are manual simplification. `D/vcg/examples/dafny_vcg_exampleScript.sml:66-80` (`plus_one_correct`), `:423-427` (`vc_ok_mccarthy_prog`).

### 1.4 Does compiler correctness carry `ensures`?

- `correct_compile` is behaviour only. `D/proofs/dafny_compilerProofScript.sml:179-189`. It relates `evaluate_program … = (s, Rcont)` to `evaluate_decs` of the compiled declarations through `state_rel`. It mentions no `ensures`. It needs a `Main` method.
- `vc_ok_imp` does carry `ensures`. `D/proofs/dafny_compilerProofScript.sml:507-539`, with `vc_ok_def` at `:449-452`. From `vc_ok prog`, `requires`, and technical conditions it gives:
  - `eval_stmt s dafny_env body s' (Rstop Sret)`;
  - `conditions_hold s' dafny_env (MAP (wrap_Old …) ens)`;
  - an `evaluate` of the compiled CakeML body with `state_rel` to `s'`.
- The `ensures` are stated on the Dafny final state. They are not restated on CakeML values.

### 1.5 Local state (blockers)

- `D/vcg/.hol` holds only `make-deps`. `dafny_wp_calc` (7528 lines), `dafny_vcg` and `dafny_vcgProof` are not built in the working tree.
- `D/proofs/.hol/objs` has `dafny_freshenProof` and `dafny_to_cakemlProof` only. `dafny_compilerProof` and `dafny_remove_assertProof` are not built.
- The patched front end build is absent. U294 used `<HOME>/forge/.toolchain/experiments/refund-dafny-frontend-20261104/…` (see `BK/source-model-binding-20261104/COMMANDS.md`). `<HOME>/forge/.toolchain/experiments/` now holds only `refund-cakeml-20261104`. Only Dafny 4.11.0 is present, at `<HOME>/forge/.toolchain/dafny-4.11.0`. With no network, a rebuild is not possible now.
- `forge_refundSourceBinding`, `…SourceRelation`, `…CompiledInputBinding` and `…ByteBoundary` are not built in the working tree. Their scripts are on the backup branch. Their parents `forge_refundTheory` and `forge_refundCertifiedProgTheory` are built under `D/forge_refund_experiment` and `D/forge_refundCertifiedProg_experiment`.
- The heap `<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap` exists. A HOL job is using it now.
- The working-tree `spec/refund/RefundSpec.dfy`, `impl/Refund.dfy` and the U294 `FlatCore.dfy` have the same git blob hashes as the copies U295 verified (`ad456868…`, `4c61b7db…`, `766d795e…`). The Dafny evidence still speaks about the current approved text.

## 2. Routes

### Route A: contract inside HOL through the VCG

Would prove: `vc_ok source_program` for the U294-exported program. Then, by `methods_correct`, for every typed input state the body returns and `conditions_hold st' env (MAP (wrap_Old …) source_ensures)`.

Judgment:
- It gives the same content as the existing `source_postconditions`. The gain is that upstream's theorem fixes the start-state conditions, not Forge's own `source_initial`.
- It does not shrink the cross-tool gap.
- `vc_ok_imp` would add a link to the Dafny-compiled body. The shipped binary comes from the translator, so that link is not on the path.
- The method has no loop, no call and no array. One VC over three `ensures`.

Trusted additions: none beyond U294 (the exporter).
Cannot express: everything in section 1.1; unchanged.
Size: build three theories, then one VC proof. Roughly the U294 source proof (four attempts) plus a one-time build.
Smallest experiment: build `D/vcg` once, then `EVAL “vcg source_program”`. `INR` means alive. `INL` means dead for this export.
Not determined: whether `vcg` returns `INR`. The exported `decreases` list holds string and bool variables. `stmt_vcg` returns `ens` at `Return` (`D/vcg/dafny_vcgScript.sml:162-171`) and I saw no decreases check outside calls and loops, but only the evaluation settles it. Build time is also not determined. U258 records 268 s for the 4933-line `dafny_to_cakemlProof`.
Main risk: time spent for a restatement.

### Route B: HOL transcription of R1 to R5

Would prove: define HOL types `context`, `model_response`, `decision`, `intent`. Define `flatten` and `unpack`. Prove that `unpack (refund_fields (flatten c r))` satisfies R1 to R5 written in HOL.

Judgment:
- Proof is minutes, like `byte_fields_result` in `BK/byte-boundary-20261104/records/byte-proof.sml`.
- Rows 10 to 15 become HOL theorems.
- The HOL text of R1 to R5 is a hand transcription of the Dafny text. One reading claim remains, and it is the central one. This is not a mechanical link.

Unicode: either HOL strings stay bytes and the encoding stays in Dafny, or a HOL UTF-8 encoder with an injectivity proof is written. That duplicates U262 and would take hours.
Smallest experiment: the HOL definitions plus the theorem. Minutes.
Main risk: it is presented as more than it is.

### Route C: export the approved `impl/Refund.dfy` itself

Judgment: dead with the pinned front end.
- The AST has no datatypes or sequences. `D/dafny_astScript.sml:11-17`.
- The exporter refuses abstract and refining modules. The patch requires `ModuleKind == Concrete` and `Implements == null`. U294's `abstract-module` fixture exits 1.
- It would need new AST nodes, new semantics for datatypes, sequences, sets and Unicode strings, and matching changes to the parser. That is a new unreviewed semantics of Dafny, a larger trusted item than the gap it closes.

Smallest experiment: none needed. The refusal is already recorded in `BK/source-model-binding-20261104/records/abstract-module/`.

### Route D (recommended): Dafny refinement plus the retained export

Idea. Let Dafny check the approved text itself, using only the flat method's contract.

Dafny side, new file outside `spec/`, `impl/`, `policy/`, `gate/`:
```
module LinkedRefund refines RefundSpec {
  method Assess(context, response) returns (decision, plan) {
    ok, a, r, c, q, n := FlatRefund.AssessFlat(
        Encoded(context.chargeId), Encoded(context.requestId),
        context.original, context.remaining,
        context.refundEnabled, context.requestOpen,
        response.Candidate?, (if response.Candidate? then response.amount else 0),
        Encoded(if response.Candidate? then response.reason else ""));
    decision := if ok then Authorized(a, Decode(r)) else Rejected;
    plan := if n == 1 then [Intent(Decode(c), Decode(q), a, Decode(r))] else [];
  }
}
```
- Dafny reasons about a called method through its contract only. So Dafny proves: for all contexts and responses, and for any six values that satisfy the three flat `ensures` on the encoded inputs, the decoded pair satisfies every `ensures` of the approved `RefundSpec.Assess`.
- The approved `ensures` are inherited by `refines`. Nothing is transcribed. `spec/refund/RefundSpec.dfy` is included and not edited. `impl/Refund.dfy` already uses the same `refines` pattern.
- `Decode` must be a function of the output bytes only. Reusing `response.reason` there would hide the gap.
- Add `Uniqueness`: two calls of `R.Assess` on the same inputs return equal results. R3 and R4 imply it. Then the approved contract fixes one result and the link is an equivalence.
- Add `FlatSatisfiable`: keep `FlatCore.dfy`'s own body verified, so the flat contract is not vacuous.
- Reuse the U262 lemmas (`EncodedInjective`, `EncodedEmpty`, `SameReasons`, `StringRoundTrip`, `EncodedIsBytes`) from `BK/byte-boundary-20261104/records/dafny-0002/inputs/UnicodeRelation.dfy`.

HOL side:
- Replay the three U294 theories from the retained export bytes.
- Add one theorem, `exported_contract_on_refund_fields`: for all `charge request original remaining enabled opened candidate amount reason h env`, if `refund_fields … = (ok,a,r,c,q,n)` and `st` binds the nine input names and six output names of `source_signature` to these values, then `evaluate_exps st env source_ensures = (st, Rval [BoolV T; BoolV T; BoolV T])`.
- This says "the function the binary is proved against satisfies the exported contract". It does not go through the exported body.
- Compose it with the existing output equation (U387, U404, conditional).

Resulting claim: the machine output is `refund_render_fields` of a tuple that satisfies the exported flat contract; Dafny proves that any tuple satisfying the flat contract on UTF-8-encoded approved inputs decodes to the unique result allowed by the approved R1 to R5.

New trusted components:
- The patched `Bake.cs` (already in U294).
- Agreement of Dafny and the HOL Dafny semantics on one small fragment: `&& || ==> <==> ! <= == !=` on int, bool and string, integer and ASCII string literals, variables.
- Dafny string with all chars below 256 is identified with `mlstring`.

Size: Dafny part is comparable to `Transport.dfy` plus `Boundary.dfy` (U262 needed 5+2+2 attempts, U295 two). HOL part is comparable to one U294 theory.
Smallest experiment: the Dafny file alone, on the pinned Dafny 4.11.0. U262 full runs took about 33 s. Exit 0 means alive.
Not determined: whether the standard-library decoder's precondition can be met for the reject branch, or whether a checked decoder returning an option is needed. The Dafny run settles it.
Main risks:
- Resource exhaustion in Dafny. U262 hit it several times.
- A reader takes "Dafny-checked plus HOL-checked" for "one proof".

### Comparison

| | A (VCG) | B (HOL transcription) | C (export impl) | D (refinement) |
| --- | --- | --- | --- | --- |
| Approved text checked by a tool without transcription | no | no | would be | yes, by Dafny |
| Matrix rows 10 to 15, 17 become theorems | no | 10 to 15, in HOL about a copy | yes | yes, in Dafny |
| Cross-tool gap left | exporter, fragment semantics, strings | full reading of R1 to R5 | new semantics | exporter, fragment semantics, strings |
| Needs front end rebuild | no | no | yes, plus extension | only for step 6 below |
| First experiment | build `vcg`, one `EVAL` | minutes of HOL | none; already refused | about a minute of Dafny |

## 3. Unicode in each route

- Fact: the HOL model covers every byte string. `all_values StrT`, `D/semantics/dafny_semanticPrimitivesScript.sml:362`. That is wider than valid UTF-8.
- Fact: U262 proves in Dafny that `Encoded` is byte-valued, injective, keeps emptiness, and fixes the three reasons. The upstream axiom-bearing wrapper is excluded.
- Route A: untouched. The flat contract is about strings; HOL reads them as bytes. Encoding stays in U262/U295.
- Route B: a second encoder proof in HOL, or the encoding stays a Dafny-side claim.
- Route C: would need Unicode strings in the HOL semantics. Not available.
- Route D: encoding and decoding live in Dafny, inside the refinement body. The round trip is Dafny-checked. HOL needs only byte strings. The claim must speak about encoded approved inputs only. Bytes that are not valid UTF-8 are outside it. What stays assumed: a Dafny string with chars below 256 and an `mlstring` are the same byte list (matrix rows 3 and 4), and the wire carries exactly those bytes (row 18).

## 4. Recommended plan: Route D, at most 8 steps

| # | What is run | Tool | Time class | Evidence left | Approval first? |
| --- | --- | --- | --- | --- | --- |
| 1 | Write `LinkedRefund refines RefundSpec` (body as above), `Uniqueness`, and a `Decode` built on the U262 library files. Verify with the unchanged spec, impl, `FlatCore.dfy`. | Dafny 4.11.0 | minutes per run; expect several attempts | source hash, batch count, exit code, repeat run | No spec change. Owner should approve the file location (suggest a new `proposals/…` packet). |
| 2 | Negative controls: `Decode` swapped between charge and request; amount + 1; one flat `ensures` dropped; `Decode` replaced by reading `response.reason`. The first three must fail. The fourth documents why the honest form matters. | Dafny 4.11.0 | minutes | exit codes and the failing assertion for each | no |
| 3 | Replay U294 `proof-0004.sml`, `relation.sml`, `bridge.sml` from the retained `output.sexp`. Check SHA256 `58154ddf…` first. | HOL, existing heap | minutes (recorded about 3.5 min + 7 s + 7 s) | three theory files, tag audit | Wait until the running HOL job ends, or get the owner's word to run beside it. |
| 4 | Prove `exported_contract_on_refund_fields` (section 2, Route D). Then one corollary joining it to the existing output equation. | HOL | minutes | theorem statements, no new axiom, negative control with one output swapped | same as step 3 |
| 5 | Write the binding record: one table tying `FlatCore.dfy` hash `a89484e3…`, export hash, `Bake.cs` patch hash `df88831b…`, the Dafny lemma file hash and the HOL theory hashes. Replace matrix rows 10 to 15 and 17 by theorem names. List the rows that remain. | none (document) | an hour | the record | no |
| 6 | Rebuild the patched front end from the retained patch and locks. Re-export `FlatCore.dfy` and compare bytes. Verify the step 1 file with that same binary. | patched Dafny fork, .NET SDK | an hour; needs network or a retained package cache | byte-identical export; exit 0 on verification | YES. Needs network and a toolchain rebuild. Independent review of the patch is still open (U294). |
| 7 | Optional. Build `D/vcg` and prove `vc_ok source_program`; derive the upstream-phrased statement through `methods_correct`. | HOL / Holmake | build: an hour (not determined); proof: minutes to an hour | `vc_ok` theorem | YES if the build may exceed an hour. Skip if step 4 is accepted as the contract statement. |
| 8 | Owner decision: does "R1 to R5 linked by a Dafny refinement proof and a HOL proof over one exported artifact, with the assumptions in section 5" satisfy M1-B? | owner | n/a | recorded decision | YES |

Dependencies: 2 after 1. 4 after 3. 5 after 1 to 4. 6 and 7 are independent of 1 to 5. Steps 1 and 2 need no HOL and can start at once.

## 5. What is STILL assumed after Route D succeeds

1. Dafny, Boogie and Z3 are sound for the refinement proof and the UTF-8 lemmas. The proofs are not kernel-checked.
2. The patched `Bake.cs` wrote the flat method's signature and three `ensures` faithfully. It is unverified C#. It is based on a 4.10.1 fork while the proofs use 4.11.0. The patch is not independently reviewed. The export is 3621 bytes and can be read by a person against `FlatCore.dfy`; that is review, not proof.
3. Dafny and the HOL Dafny semantics give the same meaning to the fragment used in the flat contract: `&&`, `||`, `==>`, `<==>` (exported as `Eq` on bools), `!`, `<=`, `==`/`!=` on int, bool and string, integer literals, three ASCII string literals and `""`. No tool checks this.
4. A Dafny string whose characters are all below 256 is the same object as an `mlstring`. `int` is the same integers. `bool` is the same booleans. (Matrix rows 1 to 4.)
5. `Encoded`/`Decode` in the Dafny file describe what the real producer and consumer of the wire text do. The producer and the wire format stay outside the claim (row 18, A7).
6. The claim covers encoded approved inputs only. The HOL model also accepts byte strings that are not valid UTF-8. Nothing is claimed for them at the contract level.
7. Dafny reasons about `AssessFlat` by contract. The link is to the flat contract, not to the flat body. This is intended, since HOL proves the contract of `refund_fields`. It depends on items 2 and 3.
8. HOL4 kernel, Poly/ML, and the four HOL axioms (`SELECT_AX`, `INFINITY_AX`, `ETA_AX`, `BOOL_CASES_AX`).
9. Every machine-level premise of the compiled-program theorem is unchanged: Profile A not approved, `refund_env_ok` not established for a real environment, entry state, FFI, resource-limit prefixes (U404). Route D adds nothing there.
10. Same host, same agent, no independent replay or review, no authenticated provenance of packages or heaps.
11. If step 6 is not done: the retained export bytes are trusted to be what the patched tool produced on 2026-11-04. Only recorded hashes support that.

## 6. Judgments, separated from facts

- A machine-checked link between the two kernels is not available by any route with the pinned tools. The honest end state is "two machine-checked halves joined at one exported artifact, with assumptions 2 to 4 named".
- The 18-row matrix overstates the gap in one way: rows 5 to 9 and 16 are already covered in substance by U294's parsed `ensures` and U295. It understates it in another: row 10 (the tuple as a representation of `Decision` and `plan`) has no theorem anywhere today. Route D step 1 is the one new proof that matters.
- Route A through the VCG is sound and probably cheap, but adds a restatement, not assurance. Keep it optional.
- Do not extend the Dafny AST for datatypes (Route C). It creates a new unreviewed semantics.
- Nothing here weakens or edits the approved contract.

### Critical Files for Implementation
- <HOME>/forge/spec/refund/RefundSpec.dfy (read-only; the module the new Dafny module refines)
- `origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/byte-boundary-20261104/records/dafny-0002/inputs/UnicodeRelation.dfy` (with `transport/Transport.dfy`, `transport/FlatCore.dfy`, `Boundary.dfy` in the same directory; lemmas to reuse)
- `origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/source-model-binding-20261104/records/hol-0004/proof.sml` (with `records/bridge.sml`, `records/relation.sml`, `records/export-0003/output.sexp`, `frontend/frontend.patch`)
- `origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/exception-compiler-20261105/records/replay-sources/forge_refundCertifiedProg.sml` (`refund_fields_def`; with `forge_refund.sml` for `eligible_def`)
- <HOME>/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/vcg/dafny_wp_calcScript.sml (with `vcg/dafny_vcgScript.sml` and `proofs/dafny_compilerProofScript.sml`; only for optional step 7)
