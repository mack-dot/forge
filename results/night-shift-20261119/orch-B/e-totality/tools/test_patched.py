#!/usr/bin/env python3
"""Unit tests of the rule function extracted VERBATIM (by AST) from the patched gate COPIES."""
import ast, json, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
R = Path('/Users/mackianni/forge')
sys.path.insert(0, str(E))
from subset_rule import rule as standalone

def load(path):
    tree = ast.parse(path.read_text())
    keep = [n for n in tree.body if isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', '').startswith('SUBSET_')
            or isinstance(n, ast.FunctionDef) and (n.name.startswith('subset_') or n.name == 'straight_line_subset')]
    class Rejected(Exception):
        pass
    env = {'re': re, 'Rejected': Rejected}
    exec(compile(ast.Module(body=keep, type_ignores=[]), str(path), 'exec'), env)
    def rule(data):
        try:
            env['straight_line_subset'](data)
        except Rejected as error:
            return str(error)
        return None
    src = path.read_text()
    called = re.search(r"raise Rejected\('SOURCE_SCOPE: only assertion-isolation attributes allowed'\)\n(.*\n)*?"
                       r"    straight_line_subset\(code\)\n", src) is not None
    return rule, called, len(keep)

HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '  method Assess(context: Context, response: ModelResponse)\n      returns (decision: Decision, plan: seq<RefundIntent>)\n'
def m(body, pre=''):
    return (HEAD + pre + SIG + '  {\n' + body + '  }\n}\n').encode()
OK = '    decision, plan := Rejected, [];\n'
UNIT = [  # (name, source bytes, expected code prefix or None for pass)
    ('minimal', m(OK), None),
    ('while', m(OK + '    while false { }\n'), 'SUBSET_EXEC_FORBIDDEN'),
    ('for', m(OK + '    for i := 0 to 3 { }\n'), 'SUBSET_EXEC_FORBIDDEN'),
    ('forall-stmt', m(OK + '    forall i | 0 <= i < 3 { }\n'), 'SUBSET_EXEC_FORBIDDEN'),
    ('exists-expr', m('    var b := exists i :: 0 <= i < 3;\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('forall-in-assert', m(OK + '    assert forall i :: 0 <= i < 3 ==> i < 3;\n'), None),
    ('such-that', m('    var k :| k == 1;\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('ghost-such-that', m('    ghost var k :| k == 1;\n' + OK), None),
    ('seq-ctor', m('    var s := seq(3, i => i);\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('set-compr', m('    var s := set i | 0 <= i < 3;\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('map-display', m('    var s := map[1 := 2];\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('multiset', m('    var s := multiset([1]);\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('new', m('    var a := new int[3];\n' + OK), 'SUBSET_FORBIDDEN'),
    ('expect', m('    expect true;\n' + OK), 'SUBSET_FORBIDDEN'),
    ('assume', m('    assume true;\n' + OK), 'SUBSET_FORBIDDEN'),
    ('print', m('    print 1;\n' + OK), 'SUBSET_FORBIDDEN'),
    ('colon-dash', m('    var x :- Foo();\n' + OK), 'SUBSET_FORBIDDEN'),
    ('decreases-star', m(OK, '  method Spin() decreases * { }\n'), 'SUBSET_FORBIDDEN'),
    ('extern', m(OK, '  method {:extern} X()\n'), 'SUBSET_ATTRIBUTE'),
    ('isolate-ok', (HEAD + '  method {:isolate_assertions} Assess(context: Context, response: ModelResponse)\n'
                    '      returns (decision: Decision, plan: seq<RefundIntent>)\n  {\n' + OK + '  }\n}\n').encode(), None),
    ('import', m(OK, '  import opened RefundSpec\n'), 'SUBSET_FORBIDDEN'),
    ('nested-module', m(OK, '  module Inner { }\n'), 'SUBSET_SHAPE'),
    ('class', m(OK, '  class C { }\n'), 'SUBSET_FORBIDDEN'),
    ('datatype', m(OK, '  datatype T = A | B\n'), 'SUBSET_FORBIDDEN'),
    ('self-recursion', m(OK, '  function F(n: nat): nat { if n == 0 then 0 else F(n - 1) }\n'), 'SUBSET_RECURSION'),
    ('ghost-recursion', m(OK, '  ghost function F(n: nat): nat { if n == 0 then 0 else F(n - 1) }\n'), None),
    ('lemma-recursion', m(OK, '  lemma L(n: nat) { if n > 0 { L(n - 1); } }\n'), None),
    ('lambda', m('    var f := x => x;\n' + OK), 'SUBSET_LAMBDA'),
    ('arrow-type', m(OK, '  function A(f: int -> int): int { f(1) }\n'), 'SUBSET_HEADER'),
    ('mul-vars', m('    var x := 2;\n    var y := x * x;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('mul-literal', m('    var x := 2;\n    var y := x * 3;\n' + OK), None),
    ('add-vars-int', m('    var x := 2;\n    var y := x + x;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('add-literal', m('    var x := 2;\n    var y := x + 1;\n' + OK), None),
    ('add-length', m('    var y := |context.chargeId| + |context.requestId|;\n' + OK), None),
    ('concat', m('    var y := context.chargeId + context.requestId;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('div-var', m('    var x := 2;\n    var y := 4 / x;\n' + OK), None),
    ('mod-var', m('    var x := 2;\n    var y := x % x;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('display-17', m('    var s := [' + ','.join(['1'] * 17) + '];\n' + OK), 'SUBSET_DISPLAY'),
    ('display-16', m('    var s := [' + ','.join(['1'] * 16) + '];\n' + OK), None),
    ('display-var', m('    var s := [context.chargeId];\n' + OK), 'SUBSET_DISPLAY'),
    ('tuple-var', m('    var t := (context, 1);\n' + OK), 'SUBSET_TUPLE'),
    ('tuple-flat', m('    var t := (Rejected, []);\n' + OK), None),
    ('set-display', m('    var b := 1 in {1, 2};\n' + OK), 'SUBSET_BRACE'),
    ('function-value', m('    var f := Eligible;\n' + OK), 'SUBSET_FUNCTION_VALUE'),
    ('by-method', m(OK, '  function F(): int { 0 } by method { return 0; }\n'), 'SUBSET_FORBIDDEN'),
    ('assert-by', m(OK + '    assert true by { assert true; }\n'), None),
    ('calc', m(OK + '    calc { 1; 1; }\n'), None),
    ('ghost-var-method', m('    ghost var g := Step();\n' + OK, '  method Step() returns (r: int) { r := 0; }\n'), 'SUBSET_GHOST'),
    ('non-utf8', HEAD.encode() + b'  // \xff\n' + m(OK)[len(HEAD):], 'SUBSET_LEX'),
    ('nul', m(OK).replace(b'{\n    decision', b'{\n    decision\x00'), 'SUBSET_LEX'),
    ('formfeed', m(OK).replace(b'    decision', b'\x0c    decision'), 'SUBSET_LEX'),
    ('unterminated-comment', m(OK)[:-2] + b'/*', 'SUBSET_LEX'),
    ('attr-split-comment', m(OK, '  method {/**/:verify false} X() { }\n'), 'SUBSET_ATTRIBUTE'),
    ('at-attribute', m(OK, '  @IsolateAssertions method X() { }\n'), 'SUBSET_ATTRIBUTE'),
    ('trailing-module', m(OK) + b'module Other { }\n', 'SUBSET_SHAPE'),
    ('size', m(OK + '    // ' + 'x' * 70000 + '\n'), 'SUBSET_SIZE'),
    ('no-assess', (HEAD + '}\n').encode(), 'SUBSET_SHAPE'),
    ('bodiless-function', m(OK, '  function F(): int\n'), 'SUBSET_SHAPE'),
    ('long-number', m('    var x := ' + '9' * 41 + ';\n' + OK), 'SUBSET_LITERAL_SIZE'),
]
fails = 0
for label in ('standalone', 'combined'):
    rule, called, n = load(E / 'diff' / label / 'b/gate/refund.py')
    print('%s: %d definitions extracted; call site after the attribute rule: %s' % (label, n, called))
    fails += not called
    for name, data, want in UNIT:
        got = rule(data)
        ok = (got is None) if want is None else (got is not None and got.startswith(want))
        fails += not ok
        if not ok or label == 'standalone':
            print('  %-4s %-22s want=%-22s got=%s' % ('ok' if ok else 'FAIL', name, want, got))
    corpus = json.loads((E / 'eval_results.json').read_text())
    mismatch = [r['file'] for r in corpus if (rule((R / r['file']).read_bytes()) or 'pass') != r['subset']]
    agree = [r['file'] for r in corpus if (standalone((R / r['file']).read_bytes()) or 'pass') != r['subset']]
    print('  corpus %d files: patched-copy mismatches %d; standalone mismatches %d' % (len(corpus), len(mismatch), len(agree)))
    fails += len(mismatch) + len(agree)
print('FAILURES', fails)
sys.exit(1 if fails else 0)
