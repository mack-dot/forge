"""Builds FALSE_REJECTIONS.md from the hand-written row facts below and the MACHINE results:
results/check-none.jsonl (JS checker on translations) and logs/scope_new.out (new source-scope rules)."""
import json, os
H = '/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-gate'
js = {}
for l in open(H + '/results/check-none.jsonl'):
    r = json.loads(l); js[r['file'][:-3]] = r
scope = {}
for l in open(H + '/logs/scope_new.out').readlines() + open(H + '/logs/scope_G.out').readlines() + open(H + '/logs/scope_c13.out').readlines():
    n, v = l.split(' | ', 1); scope[n[:-4]] = v.strip()
G = 'gate-copy/refund.py'  # 985f5eaf + e-subset3 refund-subset3-combined-scope.diff
P = 'gate/refund.py@985f5eaf'
# file, run(s), refusing clause, construct, essential?, unsafe class the clause stops, category
ROWS = [
 ('C04-local-datatype-verdict', 'R3', G + ':1004 FORBIDDEN `datatype`', 'local enum datatype Ok/Bad', 'incidental', 'new kinds of values the recognizer cannot measure', 'E'),
 ('C05-loop-over-local-reason-list', 'R3', G + ':606 STATEMENT `while`', 'while i < |local display|', 'incidental', 'unbounded loop (E08)', 'B'),
 ('C06-reason-index-loop-early-exit', 'R3', G + ':606 STATEMENT `while`', 'while i < |const| && !hit', 'incidental', 'unbounded loop', 'B'),
 ('C08-label-assert', 'R3', G + ':1004 FORBIDDEN `label`', 'ghost label before an assignment', 'incidental', 'none (labels only name states)', 'E'),
 ('C16-reason-string-concat-log', 'R3', G + ':688 KIND string `+`', 'one string concatenation', 'incidental', 'string doubling (HV08, Y47)', 'B'),
 ('C18-for-range-over-local-list', 'R3', G + ':606 STATEMENT `for`', 'for i := 0 to |local display|', 'incidental', 'unbounded loop', 'B'),
 ('C19-map-reason-table', 'R3', G + ':989 NAME `map`', 'map display, `in` test', 'incidental', 'unknown collection kinds', 'E'),
 ('C20-loop-with-break', 'R3', G + ':606 STATEMENT `while`', 'while i < 3 with break', 'incidental', 'unbounded loop', 'B'),
 ('A11-abstract-trap-dead', 'R1,R3', G + ':1004 FORBIDDEN `abstract`', 'abstract module with bodiless `ensures false` lemma', 'n/a', 'unchecked axiom-like lemma outside compile and audit', 'D'),
 ('C1-table', 'R1,R3', G + ':606 STATEMENT `while` (in InTable)', 'while i < |const display|', 'essential to this style', 'unbounded loop', 'B'),
 ('C2-recursion', 'R1,R3', G + ':408 TYPE helper param `seq`', 'recursion over a 4-element display', 'essential to this style', 'unbounded recursion (H02, E06)', 'B'),
 ('C4-arith', 'R1,R3', G + ':815 PRODUCT', 'product of 0/1 flags', 'incidental', 'BigNumber growth (HV07)', 'B'),
 ('C7-loop-plan', 'R1,R3', G + ':606 STATEMENT `while`', 'while i < n, n in {0,1}', 'essential to this style', 'unbounded loop', 'B'),
 ('N01-while-literal-table', 'R3', G + ':606 STATEMENT `while`', 'while i < 3', 'incidental', 'unbounded loop', 'B'),
 ('N02-for-const-display-table', 'R3', G + ':606 STATEMENT `for`', 'for i := 0 to |const display|', 'incidental', 'unbounded loop', 'B'),
 ('N03-for-bounded-local-plan', 'R3', G + ':606 STATEMENT `for`', 'for i := 0 to n, n in {0,1}', 'incidental', 'unbounded loop', 'B'),
 ('N04-flag-product', 'R3', G + ':815 PRODUCT', 'product of 0/1 flags', 'incidental', 'BigNumber growth', 'B'),
 ('N05-recursion-over-display', 'R3', G + ':408 TYPE helper param `seq`', 'recursion over a display', 'incidental', 'unbounded recursion', 'B'),
 ('N06-extra-ghost-module', 'R3', G + ':1014 MODULE (one module)', 'second (ghost) module', 'incidental', 'JS name collision (A03), extra code', 'E'),
 ('N08-input-field-product', 'R3', G + ':815 PRODUCT', 'amount * original (unused)', 'incidental', 'BigNumber growth', 'B'),
 ('N09-nested-literal-loops', 'R3', G + ':606 STATEMENT `while`', 'nested while 3 x 2', 'incidental', 'unbounded loop', 'B'),
 ('C9-comment-word-include', 'R1', P + ':101 SOURCE_SCOPE include count', 'word include in a comment', 'incidental', 'second include', 'A'),
 ('C10-induction-attr', 'R1', P + ':104 SOURCE_SCOPE attribute', '{:induction false}', 'incidental', 'verification-weakening attributes', 'A'),
 ('C11-at-in-string', 'R1', P + ':104 SOURCE_SCOPE `@` byte', '@ inside a string literal', 'incidental', 'new attribute syntax @Name', 'A'),
 ('C12-crlf-header', 'R1', P + ':101 SOURCE_SCOPE prefix bytes', 'CRLF line ends in the header', 'incidental', 'a changed refinement header', 'A'),
 ('CV07-odd-comments', 'R1(new-correct)', 'rule 1 lexer SUBSET_LEX U+2028', 'line separator in a comment', 'incidental', 'comment/lexer confusion', 'A'),
 ('F01-match-no-braces', 'R3 (rule run)', G + ':392 SYNTAX', 'match without braces', 'incidental', 'parser confusion', 'E'),
 ('F02-set-in-guard', 'R3 (rule run)', G + ':912 GUARD_BRACE', 'set display in an if guard', 'incidental', 'Dafny brace rule not modelled (HV23)', 'E'),
 ('F03-typed-set-const', 'R3 (rule run)', G + ':423 TYPE `set`', 'typed set constant', 'incidental', 'unmeasured kinds', 'E'),
 ('F04-seq-param-helper', 'R3 (rule run)', G + ':408 TYPE helper param `seq`', 'helper with seq parameter', 'incidental', 'tree growth through helpers (Y48)', 'B'),
 ('F05-calc-in-body', 'R3 (rule run)', G + ':606 STATEMENT `calc`', 'ghost calc statement', 'incidental', 'none (ghost)', 'E'),
 ('F06-named-result', 'R3 (rule run)', G + ':423 TYPE `d`', 'named function result (d: Decision)', 'incidental', 'none', 'E'),
 ('F07-local-name-length', 'R3 (rule run)', G + ':314 NAME `name`', 'locals named name/length', 'incidental', 'JavaScript name collision', 'E'),
 ('F08-seq-append-one', 'R3 (rule run)', G + ':688 KIND seq `+`', 'plan := plan + [intent]', 'incidental', 'sequence growth (Y46)', 'B'),
 ('F09-let-expression', 'R3 (rule run)', G + ':989 NAME `var`', 'let expression in a function', 'incidental', 'unknown forms', 'E'),
 ('F10-tuple-nested-select', 'R3 (rule run)', G + ':843 SELECT `.0.0`', 'nested tuple selection', 'incidental', 'unknown forms', 'E'),
 ('G01-reason-list-helper', 'C-GATE-04 (rule run)', G + ':408 TYPE helper param `seq`', 'helper over a reason list', 'incidental', 'tree growth through helpers', 'B'),
 ('G02-let-expression-cap', 'C-GATE-04 (rule run)', G + ':989 NAME `var`', 'let expression in a helper', 'incidental', 'unknown forms', 'E'),
 ('G03-reason-in-set-guard', 'C-GATE-04 (rule run)', G + ':912 GUARD_BRACE', '`reason in {..}` in a guard', 'incidental', 'Dafny brace rule not modelled', 'E'),
 ('G08-ok-flag-in-two-branches', 'C-GATE-04 (rule run)', G + ':400 NAME reused', 'a local declared once in each of two branches', 'incidental', 'shadowing (A08, A09)', 'E'),
 ('G09-percent-cap-const', 'C-GATE-04 (rule run)', G + ':815 PRODUCT', 'amount times a named constant', 'incidental', 'BigNumber growth', 'B'),
 ('G11-digit-separator-cap', 'C-GATE-06 (rule run)', G + ':885 LITERAL `1_000_000`', 'digit separators in a money constant', 'incidental', 'huge or odd literals (Y35, Y36)', 'E'),
 ('F11-ghost-forall-assert', 'none', 'not refused: rule 3 passes (W=209 T=6)', 'ghost forall assert', '-', '-', '-'),
 ('F12-reason-helper-chain', 'none', 'not refused: rule 3 passes (W=249 T=6)', 'helper predicate chain', '-', '-', '-'),
]
def status(name, cat):
    sc = scope.get(name, 'not run')
    j = js.get(name)
    if cat == '-':
        return 'NOT A FALSE REJECTION (scope %s; JS %s)' % ('PASS' if sc == 'PASS' else sc, j['verdict'] if j else 'NOT RUN')
    if cat == 'D':
        return 'KEPT REFUSED by new source rule `abstract` (scope: %s); JS alone would admit it (%s)' % (sc, j['verdict'] if j else 'NOT RUN')
    if cat == 'A':
        jv = (j['verdict'] if j else 'NOT RUN (no translation; heavy/translate_all.sh)')
        return ('RESOLVED by diff (i)/(ii) scope rules: scope %s; JS %s' % (sc, jv)) if sc == 'PASS' else 'UNRESOLVED: scope ' + sc
    if sc != 'PASS':
        return 'UNRESOLVED: source scope ' + sc
    if not j:
        return 'PENDING: no translation yet (heavy/translate_all.sh); scope PASS'
    if j['verdict'] == 'ACCEPT':
        return 'RESOLVED by diff (ii): scope PASS; JS ACCEPT (%s)' % j['detail'].split(' cost')[0]
    return 'UNRESOLVED: JS %s: %s' % (j['code'], j['detail'][:70])
out = ['# False rejections: final cause table (h-gate, 2026-11-19)', '',
       'Runs: R1 = rule 1 gate run (heavy/gate-subset/summary.txt); R3 = rule 3 gate run (heavy/window-10.log, 21 of 67',
       'correct refused); "rule run" = rule 3 standalone (e-subset3/subset_rule3.py) on the reviewer files F01-F12, all',
       'verified exit 0 by r-subset3b (light tier, gate options, logs r-subset3b/logs/F*.verify.1.log).',
       'Clause lines: `' + G + '` is 985f5eaf gate/refund.py + e-subset3/diff/refund-subset3-combined-scope.diff.',
       'Categories: A incidental formatting/comment (lexer or scope rule); B bounded construct a sound analysis can admit;',
       'C construct no analysis here can bound (data-dependent); D rightly refused; E recognizer incompleteness.',
       'Status: MACHINE results: scope = tools/scope_check.py on the proposed gate (logs/scope_new.out); JS = js_bound_check.cjs',
       'on `dafny translate js` output (results/check-none.jsonl). The full gate run (Dafny verify + tests) is NOT RUN (G5).', '',
       '| file | run | refusing clause (file:line) | construct | essential? | unsafe class the clause stops | cat | status |',
       '|---|---|---|---|---|---|---|---|']
tot = {}
for f, run, cl, con, ess, cls, cat in ROWS:
    st = status(f, cat)
    key = (cat, st.split(' ')[0].split(':')[0])
    tot[key] = tot.get(key, 0) + 1
    out.append('| %s |' % ' | '.join(x.replace('|', '\\|') for x in (f, run, cl, con, ess, cls, cat, st)))
out += ['', '## Totals (rows = distinct files; F11, F12 are not false rejections)', '', '| category | status | files |', '|---|---|---|']
for (c, s), n in sorted(tot.items()):
    out.append('| %s | %s | %d |' % (c, s, n))
open(H + '/FALSE_REJECTIONS.md', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out[-12:]))
