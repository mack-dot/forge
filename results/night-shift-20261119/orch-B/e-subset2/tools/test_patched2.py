#!/usr/bin/env python3
"""Unit tests of the rule functions extracted VERBATIM (by AST) from the patched gate COPIES (diff/work/*)."""
import ast, json, re, sys, textwrap
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
R = Path('/Users/mackianni/forge')
sys.path.insert(0, str(E))
from subset_rule2 import rule as standalone


class Rejected(Exception):
    pass


def load_subset(path):
    tree = ast.parse(path.read_text())
    keep = [n for n in tree.body if isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', '').startswith('SUBSET_')
            or isinstance(n, ast.FunctionDef) and (n.name.startswith('subset_') or n.name == 'straight_line_subset')]
    env = {'re': re, 'Rejected': Rejected}
    exec(compile(ast.Module(body=keep, type_ignores=[]), str(path), 'exec'), env)
    load_subset.env = env

    def rule(data):
        try:
            env['straight_line_subset'](data)
        except Rejected as error:
            return str(error)
        return None
    return rule, len(keep)


def load_scope(path):
    """The byte rules of prepare() between reading impl/Refund.dfy and the binding check, as check(code)."""
    src = path.read_text()
    start = src.index("    code = (ROOT / 'impl/Refund.dfy').read_bytes()\n") + len("    code = (ROOT / 'impl/Refund.dfy').read_bytes()\n")
    end = src.index("    if b'include' in (ROOT / BINDING)")
    body = src[start:end]
    real = None
    if 'def straight_line_subset' in src:
        load_subset(path)
        real = load_subset.env['straight_line_subset']
    env = {'re': re, 'Rejected': Rejected, 'code_words': None, 'straight_line_subset': real}
    if 'def code_words' in src:
        tree = ast.parse(src)
        keep = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'code_words' or
                isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', '') in ('LINE_END', 'CHAR')]
        exec(compile(ast.Module(body=keep, type_ignores=[]), str(path), 'exec'), env)
    exec('def check(code):\n' + body + '    return None\n', env)

    def check(code):
        try:
            env['check'](code)
        except Rejected as error:
            return str(error)
        return None
    return check, ('straight_line_subset(code)' in body)


HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '  method Assess(context: Context, response: ModelResponse)\n      returns (decision: Decision, plan: seq<RefundIntent>)\n'


def m(body, pre='', post=''):
    return (HEAD + pre + SIG + '  {\n' + body + '  }\n}\n' + post).encode()


OK = '    decision, plan := Rejected, [];\n'
UNIT = [  # (name, source, expected refusal prefix or None)
    ('minimal', m(OK), None),
    ('while-literal', m('    var i := 0;\n    while i < 3 { i := i + 1; }\n' + OK), None),
    ('while-decreases-exact', m('    var i := 0;\n    while i < 3 decreases 3 - i { i := i + 1; }\n' + OK), None),
    ('while-decreases-lie', m('    var i := 0;\n    while i < 3 decreases 9 - i { i := i + 1; }\n' + OK), 'SUBSET_LOOP'),
    ('while-big', m('    var i := 0;\n    while i < 5000 { i := i + 1; }\n' + OK), 'SUBSET_SIZE'),
    ('while-no-increment', m('    var i := 0;\n    while i < 3 { i := i + 2; }\n' + OK), 'SUBSET_LOOP'),
    ('while-counter-param', m('    while i < 3 { i := i + 1; }\n' + OK), 'SUBSET_LOOP'),
    ('while-negative-start', m('    var i := -9;\n    while i < 3 { i := i + 1; }\n' + OK), 'SUBSET_LOOP'),
    ('while-guard-input', m('    var i := 0;\n    while i < |context.chargeId| { i := i + 1; }\n' + OK), 'SUBSET_LOOP'),
    ('for-literal', m('    for i := 0 to 4 { }\n' + OK), None),
    ('for-downto', m('    for i := 4 downto 0 { }\n' + OK), 'SUBSET_'),
    ('for-input-bound', m('    for i := 0 to |context.chargeId| { }\n' + OK), 'SUBSET_LOOP'),
    ('nested-cap', m('    for i := 0 to 100 {\n      for j := 0 to 100 { }\n    }\n' + OK), 'SUBSET_SIZE'),
    ('loop-break', m('    for i := 0 to 4 { break; }\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('loop-set-in-invariant', m('    var i := 0;\n    while i < 3 invariant i in {0,1,2,3} { i := i + 1; }\n' + OK), 'SUBSET_LOOP'),
    ('bounded-product', m('    var f := if true then 1 else 0;\n    var p := f * f;\n    var q := p * p;\n' + OK), None),
    ('unbounded-product', m('    var f := context.original;\n    var p := f * f;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('field-product', m('    var p := context.original * context.remaining;\n' + OK), None),
    ('field-product-chain', m('    var p := context.original * context.remaining * context.original;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('field-product-helper', m(OK, '  function F(context: Context): int { context.original * context.original }\n'), 'SUBSET_ARITHMETIC'),
    ('reassigned-bounded', m('    var f := 2;\n    f := context.original;\n    var p := f * f;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('display-append', m('    var s: seq<int> := [];\n    s := s + [1, 2];\n' + OK), None),
    ('display-append-var', m('    var s: seq<int> := [];\n    s := s + [context.original];\n' + OK), 'SUBSET_DISPLAY'),
    ('concat', m('    var y := context.chargeId + context.requestId;\n' + OK), 'SUBSET_ARITHMETIC'),
    ('recursion-display', m('    var c := L([true, false]);\n' + OK,
                            '  function L(b: seq<bool>): nat decreases |b| { if |b| == 0 then 0 else 1 + L(b[1..]) }\n'), None),
    ('recursion-input', m('    var c := L(context.chargeId);\n' + OK,
                          '  function L(b: string): nat decreases |b| { if |b| == 0 then 0 else 1 + L(b[1..]) }\n'), 'SUBSET_RECURSION'),
    ('recursion-no-decreases', m(OK, '  function F(n: nat): nat { if n == 0 then 0 else F(n - 1) }\n'), 'SUBSET_RECURSION'),
    ('ghost-recursion', m(OK, '  ghost function F(n: nat): nat { if n == 0 then 0 else F(n - 1) }\n'), None),
    ('extra-ghost-module', m(OK, '', 'module X {\n  lemma L() ensures true { }\n}\n'), None),
    ('extra-compiled-module', m(OK, '', 'module X {\n  function F(): int { 1 }\n}\n'), 'SUBSET_MODULE'),
    ('extra-abstract-module', m(OK, '', 'abstract module X {\n  lemma L() ensures false\n}\n'), 'SUBSET_FORBIDDEN'),
    ('extra-bodiless-lemma', m(OK, '', 'module X {\n  lemma L() ensures false\n}\n'), 'SUBSET_SHAPE'),
    ('extra-refines', m(OK, '', 'module X refines RefundSpec {\n}\n'), 'SUBSET_SHAPE'),
    ('ls-in-comment', m('    // a b\n' + OK), None),
    ('ls-in-code', m('     ' + OK), 'SUBSET_LEX'),
    ('nul-in-comment', m('    // a\x00b\n' + OK), 'SUBSET_LEX'),
    ('cr-ends-comment', m('    // a\rwhile true { }\n' + OK), 'SUBSET_LOOP'),
    ('induction-false', m(OK, '  lemma {:induction false} L() ensures true { }\n'), None),
    ('induction-true', m(OK, '  lemma {:induction true} L() ensures true { }\n'), 'SUBSET_ATTRIBUTE'),
    ('at-in-string', m(OK, '  const C: string := "a@b"\n'), None),
    ('at-attribute', m(OK, '  @IsolateAssertions method X() { }\n'), 'SUBSET_ATTRIBUTE'),
    ('expect', m('    expect true;\n' + OK), 'SUBSET_FORBIDDEN'),
    ('seq-ctor', m('    var s := seq(3, i => i);\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
    ('such-that', m('    var k :| k == 1;\n' + OK), 'SUBSET_EXEC_FORBIDDEN'),
]
SCOPE = [  # (name, bytes, refused by today's gate?, refused after the scope diff?)
    ('C9-comment-word', HEAD.encode() + b'  // We include no other file.\n' + m(OK)[len(HEAD):], True, False),
    ('C12-crlf', m(OK).replace(b'\n', b'\r\n'), True, False),
    ('C10-induction', m(OK, '  lemma {:induction false} L() ensures true { }\n'), True, False),
    ('C11-at-in-string', m(OK, '  const C: string := "a@b"\n'), True, None),  # None: stays refused without a lexer
    ('second-include-line', HEAD.encode() + b'include "x.dfy"\n' + m(OK)[len(HEAD):], True, True),
    ('second-include-indented', HEAD.encode() + b'   include "x.dfy"\n' + m(OK)[len(HEAD):], True, True),
    ('crlf-second-include', (HEAD + 'include "x.dfy"\n').replace('\n', '\r\n').encode() + m(OK)[len(HEAD):], True, True),
    ('other-prefix', m(OK).replace(b'refines RefundSpec', b'refines RefundSpecX'), True, True),
    ('verify-false', m(OK, '  lemma {:verify false} L() ensures false { }\n'), True, True),
    ('induction-other', m(OK, '  lemma {:induction true} L() ensures true { }\n'), True, True),
    ('at-attribute', m(OK, '  @IsolateAssertions method X() { }\n'), True, True),
]
fails = 0
base = E / 'diff/work'
for label in ('refund-subset2-standalone', 'refund-subset2-combined', 'refund-subset2-combined-scope'):
    rule, n = load_subset(base / label / 'gate/refund.py')
    check, called = load_scope(base / label / 'gate/refund.py')
    print('%s: %d definitions extracted; straight_line_subset called in prepare: %s' % (label, n, called))
    fails += not called
    for name, data, want in UNIT:
        got = rule(data)
        ok = (got is None) if want is None else (got is not None and got.startswith(want))
        fails += not ok
        if not ok or label == 'refund-subset2-standalone':
            print('  %-4s %-24s want=%-22s got=%s' % ('ok' if ok else 'FAIL', name, want, (got or '')[:70]))
    corpus = json.loads((E / 'eval2_results.json').read_text())
    mismatch = [r['file'] for r in corpus if (rule((R / r['file']).read_bytes()) or 'pass') != r['rule2']]
    agree = [r['file'] for r in corpus if (standalone((R / r['file']).read_bytes()) or 'pass') != r['rule2']]
    print('  corpus %d files: patched-copy mismatches %d; standalone mismatches %d' % (len(corpus), len(mismatch), len(agree)))
    fails += len(mismatch) + len(agree)
for label, column in (('a', 0), ('refund-scope-minimal', 1), ('refund-subset2-combined-scope', 2)):
    path = (base / 'a/gate/refund.py') if label == 'a' else (base / label / 'gate/refund.py')
    check, called = load_scope(path)
    print('scope rules of %s:' % ('985f5eaf (today)' if label == 'a' else label))
    for name, data, today, after in SCOPE:
        got = check(data)
        want = today if column == 0 else (after if after is not None else (column == 1))
        ok = (got is not None) == want
        fails += not ok
        print('  %-4s %-26s want_refused=%-5s got=%s' % ('ok' if ok else 'FAIL', name, want, (got or 'pass')[:60]))
print('FAILURES', fails)
sys.exit(1 if fails else 0)
