# False rejections: final cause table (h-gate, 2026-11-19)

Runs: R1 = rule 1 gate run (heavy/gate-subset/summary.txt); R3 = rule 3 gate run (heavy/window-10.log, 21 of 67
correct refused); "rule run" = rule 3 standalone (e-subset3/subset_rule3.py) on the reviewer files F01-F12, all
verified exit 0 by r-subset3b (light tier, gate options, logs r-subset3b/logs/F*.verify.1.log).
Clause lines: `gate-copy/refund.py` is 985f5eaf gate/refund.py + e-subset3/diff/refund-subset3-combined-scope.diff.
Categories: A incidental formatting/comment (lexer or scope rule); B bounded construct a sound analysis can admit;
C construct no analysis here can bound (data-dependent); D rightly refused; E recognizer incompleteness.
Status: MACHINE results: scope = tools/scope_check.py on the proposed gate (logs/scope_new.out); JS = js_bound_check.cjs
on `dafny translate js` output (results/check-none.jsonl). The full gate run (Dafny verify + tests) is NOT RUN (G5).

| file | run | refusing clause (file:line) | construct | essential? | unsafe class the clause stops | cat | status |
|---|---|---|---|---|---|---|---|
| C04-local-datatype-verdict | R3 | gate-copy/refund.py:1004 FORBIDDEN `datatype` | local enum datatype Ok/Bad | incidental | new kinds of values the recognizer cannot measure | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=167 size<=6*N+388) |
| C05-loop-over-local-reason-list | R3 | gate-copy/refund.py:606 STATEMENT `while` | while i < \|local display\| | incidental | unbounded loop (E08) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=244 size<=6*N+388) |
| C06-reason-index-loop-early-exit | R3 | gate-copy/refund.py:606 STATEMENT `while` | while i < \|const\| && !hit | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=294 size<=6*N+388) |
| C08-label-assert | R3 | gate-copy/refund.py:1004 FORBIDDEN `label` | ghost label before an assignment | incidental | none (labels only name states) | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=158 size<=6*N+388) |
| C16-reason-string-concat-log | R3 | gate-copy/refund.py:688 KIND string `+` | one string concatenation | incidental | string doubling (HV08, Y47) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=174 size<=6*N+388) |
| C18-for-range-over-local-list | R3 | gate-copy/refund.py:606 STATEMENT `for` | for i := 0 to \|local display\| | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=228 size<=6*N+388) |
| C19-map-reason-table | R3 | gate-copy/refund.py:989 NAME `map` | map display, `in` test | incidental | unknown collection kinds | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=159 size<=6*N+388) |
| C20-loop-with-break | R3 | gate-copy/refund.py:606 STATEMENT `while` | while i < 3 with break | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=255 size<=6*N+388) |
| A11-abstract-trap-dead | R1,R3 | gate-copy/refund.py:1004 FORBIDDEN `abstract` | abstract module with bodiless `ensures false` lemma | n/a | unchecked axiom-like lemma outside compile and audit | D | KEPT REFUSED by new source rule `abstract` (scope: SOURCE_SCOPE: abstract modules are not allowed); JS alone would admit it (ACCEPT) |
| C1-table | R1,R3 | gate-copy/refund.py:606 STATEMENT `while` (in InTable) | while i < \|const display\| | essential to this style | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=274 size<=6*N+388) |
| C2-recursion | R1,R3 | gate-copy/refund.py:408 TYPE helper param `seq` | recursion over a 4-element display | essential to this style | unbounded recursion (H02, E06) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=305 size<=6*N+388) |
| C4-arith | R1,R3 | gate-copy/refund.py:815 PRODUCT | product of 0/1 flags | incidental | BigNumber growth (HV07) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=214 size<=6*N+394) |
| C7-loop-plan | R1,R3 | gate-copy/refund.py:606 STATEMENT `while` | while i < n, n in {0,1} | essential to this style | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=187 size<=6*N+389) |
| N01-while-literal-table | R3 | gate-copy/refund.py:606 STATEMENT `while` | while i < 3 | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=242 size<=6*N+388) |
| N02-for-const-display-table | R3 | gate-copy/refund.py:606 STATEMENT `for` | for i := 0 to \|const display\| | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=240 size<=6*N+388) |
| N03-for-bounded-local-plan | R3 | gate-copy/refund.py:606 STATEMENT `for` | for i := 0 to n, n in {0,1} | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=183 size<=6*N+389) |
| N04-flag-product | R3 | gate-copy/refund.py:815 PRODUCT | product of 0/1 flags | incidental | BigNumber growth | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=184 size<=6*N+388) |
| N05-recursion-over-display | R3 | gate-copy/refund.py:408 TYPE helper param `seq` | recursion over a display | incidental | unbounded recursion | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=255 size<=6*N+388) |
| N06-extra-ghost-module | R3 | gate-copy/refund.py:1014 MODULE (one module) | second (ghost) module | incidental | JS name collision (A03), extra code | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=158 size<=6*N+388) |
| N08-input-field-product | R3 | gate-copy/refund.py:815 PRODUCT | amount * original (unused) | incidental | BigNumber growth | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=174 size<=8*N+520) |
| N09-nested-literal-loops | R3 | gate-copy/refund.py:606 STATEMENT `while` | nested while 3 x 2 | incidental | unbounded loop | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=311 size<=6*N+388) |
| C9-comment-word-include | R1 | gate/refund.py@985f5eaf:101 SOURCE_SCOPE include count | word include in a comment | incidental | second include | A | RESOLVED by diff (i)/(ii) scope rules: scope PASS; JS NOT RUN (no translation; heavy/translate_all.sh) |
| C10-induction-attr | R1 | gate/refund.py@985f5eaf:104 SOURCE_SCOPE attribute | {:induction false} | incidental | verification-weakening attributes | A | RESOLVED by diff (i)/(ii) scope rules: scope PASS; JS NOT RUN (no translation; heavy/translate_all.sh) |
| C11-at-in-string | R1 | gate/refund.py@985f5eaf:104 SOURCE_SCOPE `@` byte | @ inside a string literal | incidental | new attribute syntax @Name | A | RESOLVED by diff (i)/(ii) scope rules: scope PASS; JS NOT RUN (no translation; heavy/translate_all.sh) |
| C12-crlf-header | R1 | gate/refund.py@985f5eaf:101 SOURCE_SCOPE prefix bytes | CRLF line ends in the header | incidental | a changed refinement header | A | RESOLVED by diff (i)/(ii) scope rules: scope PASS; JS NOT RUN (no translation; heavy/translate_all.sh) |
| CV07-odd-comments | R1(new-correct) | rule 1 lexer SUBSET_LEX U+2028 | line separator in a comment | incidental | comment/lexer confusion | A | RESOLVED by diff (i)/(ii) scope rules: scope PASS; JS NOT RUN (no translation; heavy/translate_all.sh) |
| F01-match-no-braces | R3 (rule run) | gate-copy/refund.py:392 SYNTAX | match without braces | incidental | parser confusion | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=171 size<=6*N+388) |
| F02-set-in-guard | R3 (rule run) | gate-copy/refund.py:912 GUARD_BRACE | set display in an if guard | incidental | Dafny brace rule not modelled (HV23) | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=149 size<=6*N+388) |
| F03-typed-set-const | R3 (rule run) | gate-copy/refund.py:423 TYPE `set` | typed set constant | incidental | unmeasured kinds | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=152 size<=6*N+388) |
| F04-seq-param-helper | R3 (rule run) | gate-copy/refund.py:408 TYPE helper param `seq` | helper with seq parameter | incidental | tree growth through helpers (Y48) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=162 size<=6*N+388) |
| F05-calc-in-body | R3 (rule run) | gate-copy/refund.py:606 STATEMENT `calc` | ghost calc statement | incidental | none (ghost) | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=158 size<=6*N+388) |
| F06-named-result | R3 (rule run) | gate-copy/refund.py:423 TYPE `d` | named function result (d: Decision) | incidental | none | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=167 size<=6*N+388) |
| F07-local-name-length | R3 (rule run) | gate-copy/refund.py:314 NAME `name` | locals named name/length | incidental | JavaScript name collision | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=164 size<=6*N+388) |
| F08-seq-append-one | R3 (rule run) | gate-copy/refund.py:688 KIND seq `+` | plan := plan + [intent] | incidental | sequence growth (Y46) | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=160 size<=6*N+389) |
| F09-let-expression | R3 (rule run) | gate-copy/refund.py:989 NAME `var` | let expression in a function | incidental | unknown forms | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=169 size<=6*N+388) |
| F10-tuple-nested-select | R3 (rule run) | gate-copy/refund.py:843 SELECT `.0.0` | nested tuple selection | incidental | unknown forms | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=200 size<=6*N+388) |
| G01-reason-list-helper | C-GATE-04 (rule run) | gate-copy/refund.py:408 TYPE helper param `seq` | helper over a reason list | incidental | tree growth through helpers | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=156 size<=6*N+388) |
| G02-let-expression-cap | C-GATE-04 (rule run) | gate-copy/refund.py:989 NAME `var` | let expression in a helper | incidental | unknown forms | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=182 size<=6*N+388) |
| G03-reason-in-set-guard | C-GATE-04 (rule run) | gate-copy/refund.py:912 GUARD_BRACE | `reason in {..}` in a guard | incidental | Dafny brace rule not modelled | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=149 size<=6*N+388) |
| G08-ok-flag-in-two-branches | C-GATE-04 (rule run) | gate-copy/refund.py:400 NAME reused | a local declared once in each of two branches | incidental | shadowing (A08, A09) | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=161 size<=6*N+388) |
| G09-percent-cap-const | C-GATE-04 (rule run) | gate-copy/refund.py:815 PRODUCT | amount times a named constant | incidental | BigNumber growth | B | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=181 size<=6*N+388) |
| G11-digit-separator-cap | C-GATE-06 (rule run) | gate-copy/refund.py:885 LITERAL `1_000_000` | digit separators in a money constant | incidental | huge or odd literals (Y35, Y36) | E | RESOLVED by diff (ii): scope PASS; JS ACCEPT (steps<=179 size<=6*N+388) |
| F11-ghost-forall-assert | none | not refused: rule 3 passes (W=209 T=6) | ghost forall assert | - | - | - | NOT A FALSE REJECTION (scope PASS; JS NOT RUN) |
| F12-reason-helper-chain | none | not refused: rule 3 passes (W=249 T=6) | helper predicate chain | - | - | - | NOT A FALSE REJECTION (scope PASS; JS NOT RUN) |

## Totals (rows = distinct files; F11, F12 are not false rejections)

| category | status | files |
|---|---|---|
| - | NOT | 2 |
| A | RESOLVED | 5 |
| B | RESOLVED | 20 |
| D | KEPT | 1 |
| E | RESOLVED | 16 |
