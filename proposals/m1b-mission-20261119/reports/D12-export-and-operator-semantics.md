# Step D12: the exported contract against the Dafny text, and the operator fragment (Y12, Opus; pinned Dafny and Python; no HOL)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y12 report (links S4 and S7). M1-B stays OPEN. `end_to_end=false`. I approve nothing.

**Findings**
1. **S4: no difference found.** The export is `…/source-model-binding-20261104/records/export-0003/output.sexp` (3,621 B, `58154ddf…`). It is under `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/`. Its source `export-0003/input.dfy` (`a89484e3…`) is byte-identical to `proofs/linked-refund/inputs/transport/FlatCore.dfy` (same hash, also git `d8e1687d`). So the three-way comparison is really two-way. My reader compared 62 clauses: signature, requires, reads, modifies, decreases, every conjunct of the 3 ensures, the full trees and the body. 0 differences.
2. **Other routes agree:**
   - (a) `dafny resolve --rprint` output, read by my reader: 0 differences. It confirms that the default `decreases` is the 9 in-parameters, which the export carries.
   - (b) `dafny verify --bprint` Boogie: the 11 string `==`/`!=` resolve to `Seq#Equal`. The decoded `char#FromInt` literals equal the export's StrL atoms.
   - (c) HOL's own parse, as printed in the stored theory doc `byte-boundary-20261104/records/hol-0002/imported/.hol/docs/forge_refundSourceBindingTheory.html` (`source_ensures_def`), equals my tree. That doc is the pretty-printer output, not the kernel term.
3. **Latent exporter defects (READ in `export-0003/Bake.cs`).** None is triggered here.
   - `EscapeAndQuote` escapes `"` but not `\`. A literal with a backslash would serialize wrongly for the mlsexp reader, which treats `\` as an escape.
   - The literal text is iterated as C# UTF-16 units. I did not confirm whether escapes are decoded first (GUESS).
   - `<==>` is exported as `Eq` without a bool check. My checker checks that type.
4. **S7 fragment (exact):**
   - Var (15 names)
   - IntL 0, 1, 9223372036854775807
   - StrL `""` and 3 ASCII literals
   - Not, And, Or, Imp
   - Eq on bool, int and string
   - Neq on string only
   - Le on int

   The fragment has no Lt/Ge, no arithmetic, no `/` or `%`, no quantifier, no function, no old, no `|s|`, indexing or concatenation.

   HOL meanings are at `semantics/dafny_semanticPrimitivesScript.sml`: `do_sc` :197-211, `do_uop` :213-215, `value_same_type` :217-223, `do_bop` :233-284, `lit_to_val` :286-290, `all_values StrT` :362. Evaluation is at `dafny_evaluateScript.sml:35-68`. Dafny meanings come from the pinned prelude in flat.bpl: `int` is Boogie int; `Seq#Equal` is extensional (:1373-1383); `char#IsChar` gives scalar ranges, so `--unicode-char` is true (:158-161).
5. **Where the meanings could differ:**
   - int: unbounded on both sides. Same.
   - `/` and `%`: absent from the fragment. HOL `ediv`/`emod` (integerScript.sml:3970-3976) are Euclidean. I believe Dafny's are also Euclidean (not re-read in this run).
   - char: Dafny uses Unicode scalars, HOL uses bytes 0..255. They agree only through the relation R below.
   - Short-circuit: both evaluate left first, and the fragment is total, so the order does not matter.
   - HOL gives Rfail on mistyped operands or unset variables. Typed inputs and `source_full_result` exclude both.
6. **Residual assumption (proposed wording):**
   - R maps int i to IntV i and bool b to BoolV b.
   - R maps a Dafny string s to StrV m iff |s| = strlen m and, for all k, `s[k] as int = ORD(strsub m k)`.
   - R is a bijection between Dafny strings with all chars below 256 and all mlstrings.
   - Claim: for each exported ensures tree E1..E3 (`58154ddf…`) and every R-related binding of the 15 names, HOL `evaluate_exp` gives `Rval (BoolV b)`, and b is the truth value Dafny 4.11.0 gives the matching FlatCore clause.
   - One environment where the two values differ falsifies it.
7. **Different technique (part 3), done as a DRAFT.**
   - `Mirror.dfy` transcribes the HOL rules above into Dafny. It proves, for all R-related environments, `MEval(Tree_k) == Rval(BoolV(Source_k))`. Tree_k is generated from the S-expression. Source_k is copied byte for byte from FlatCore.
   - Result: exit 0, 246 verified, no assume or axiom. All 3 controls are rejected: an Lt tree, a changed literal, and a mutated `do_sc Imp`.
   - What it establishes: S4 semantically, and S7 relative to the mirror.
   - What it does not establish: anything about HOL itself. The remaining trust is that the ~45 mirror lines faithfully transcribe the HOL lines cited in finding 4, plus my generator.
   - Differential testing would only be TESTED-UNPROVED, and it needs HOL runs, which I may not start.
8. **Rule breach:** mirror attempts 1 and 2 ran while another worker's Dafny process (Y10) was running. They were short (4 s and 17 s, ≤206 MB). From attempt 3 on, each run waited until no Dafny process was running.

**Files** (all in `<session scratch folder>/m1b/Y12/`)
- `s4_check.py`, `s4_run.txt`, `s4_run_rprint.txt`
- `bpl_literals.py`, `hol_doc_check.py`, `gen_mirror.py`
- `Mirror.dfy` (sha `cc846331…`)
- `rprint.txt`, `flat.bpl`
- `neg/` (all controls and their outputs)
- `mirror-{1,2,3}.stdout`

**Commands run, actual exits**

| command | exit |
|---|---|
| s4_check (positive; against rprint) | 0; 0 |
| s4_check negatives N1–N6; N1–N5 against rprint | 1 each |
| dafny resolve --rprint | 0 |
| dafny verify FlatCore copy --bprint (gate options) | 0 (1 verified) |
| bpl_literals; N3 control | 0; 1 |
| hol_doc_check; 4 controls | 0; 1 each |
| Mirror attempts 1/2/3 | 4 / 4 (out of resource) / 0 (246 verified) |
| Mirror controls N1/N3/M1 | 4/4/4 |

**Could not determine:** whether the mirror is faithful to the HOL kernel terms (I read the source; I ran no HOL). Exporter behaviour on escaped or non-ASCII literals. The Dafny manual text for `/` and `%`.

| step | status | evidence or blocker |
|---|---|---|
| S4 independent reader | done, 0 differences | s4_run.txt, controls rejected |
| S4 Dafny print routes | done, agree | rprint.txt, flat.bpl |
| S4 against the HOL-printed parse | done, agree | hol_doc_check.py |
| S7 enumeration and residual wording | done | findings 4 to 6 |
| S7 mirror proof | DRAFT, exit 0 | Mirror.dfy; proof about a mirror, not HOL |

| link id | proposed class | evidence |
|---|---|---|
| S4 | TESTED-UNPROVED | four independent readings of this one fixed artifact agree; unverified Python readers; no exporter rebuild |
| S7 | ASSUMPTION (narrowed) | fragment and wording in findings 4 and 6; the mirror draft does not upgrade it |
