#!/usr/bin/env python3
"""Unit tests of the rule-3 functions extracted VERBATIM (by AST) from the patched gate COPIES (diff/work/*),
plus corpus agreement with the standalone subset_rule3.py and the scope rules of prepare()."""
import ast, json, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
E = Path(__file__).resolve().parent.parent
R = Path('<REPO>')
sys.path.insert(0, str(E))
from subset_rule3 import rule as standalone


class Rejected(Exception):
    pass


def load_subset(path):
    tree = ast.parse(path.read_text())
    keep = [n for n in tree.body if isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', '').startswith('SUBSET3_')
            or isinstance(n, ast.FunctionDef) and (n.name.startswith('subset3_') or n.name == 'bounded_subset3')
            or isinstance(n, ast.ClassDef) and n.name.startswith('Subset3')]
    env = {'re': re, 'Rejected': Rejected}
    exec(compile(ast.Module(body=keep, type_ignores=[]), str(path), 'exec'), env)

    def rule(data):
        try:
            env['bounded_subset3'](data)
        except Rejected as error:
            return str(error)
        return None
    return rule, len(keep), env['bounded_subset3']


def load_scope(path, real):
    src = path.read_text()
    marker = "    code = (ROOT / 'impl/Refund.dfy').read_bytes()\n"
    body = src[src.index(marker) + len(marker):src.index("    if b'include' in (ROOT / BINDING)")]
    env = {'re': re, 'Rejected': Rejected, 'bounded_subset3': real}
    if 'def code_words' in src:
        keep = [n for n in ast.parse(src).body if isinstance(n, ast.FunctionDef) and n.name == 'code_words' or
                isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', '') in ('LINE_END', 'CHAR')]
        exec(compile(ast.Module(body=keep, type_ignores=[]), str(path), 'exec'), env)
    exec('def check(code):\n' + body + '    return None\n', env)

    def check(code):
        try:
            env['check'](code)
        except Rejected as error:
            return str(error)
        return None
    return check, ('bounded_subset3(code)' in body)


HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '  method Assess(context: Context, response: ModelResponse)\n      returns (decision: Decision, plan: seq<RefundIntent>)\n'


def m(body, pre='', post=''):
    return (HEAD + pre + SIG + '  {\n' + body + '  }\n}\n' + post).encode()


OK = '    decision, plan := Rejected, [];\n'
UNIT = [  # (name, source, expected refusal prefix or None)
    ('minimal', m(OK), None),
    ('canonical', (R / 'impl/Refund.dfy').read_bytes(), None),
    ('while', m('    var i := 0;\n    while i < 3 { i := i + 1; }\n' + OK), 'SUBSET3_STATEMENT'),
    ('for', m('    for i := 0 to 4 { }\n' + OK), 'SUBSET3_STATEMENT'),
    ('recursion', m('    var c := L(1);\n' + OK, '  function L(n: nat): nat { if n == 0 then 0 else L(n - 1) }\n'), 'SUBSET3_RECURSION'),
    ('ghost-recursion', m(OK, '  ghost function L(n: nat): nat { if n == 0 then 0 else L(n - 1) }\n'), None),
    ('lemma-loop', m(OK, '  lemma L() { var i := 0; while i < 3 { i := i + 1; } }\n'), None),
    ('product-fields', m('    var p := context.original * context.remaining;\n' + OK), 'SUBSET3_PRODUCT'),
    ('product-literal', m('    var p := 2 * context.original;\n' + OK), None),
    ('division-literal', m('    var p := context.original / 7;\n' + OK), None),
    ('division-zero', m('    var p := context.original / 0;\n' + OK), 'SUBSET3_PRODUCT'),
    ('concat', m('    var y := context.chargeId + context.requestId;\n' + OK), 'SUBSET3_KIND'),
    ('seq-concat', m('    var y := [1] + [2];\n' + OK), 'SUBSET3_KIND'),
    ('tree-cap', m('    var a := [context, context, context, context, context];\n' + OK), 'SUBSET3_TREE'),
    ('tree-ok', m('    var a := [context, context, context];\n' + OK), None),
    ('extra-module', m(OK, '', 'module X {\n  lemma L() ensures true { }\n}\n'), 'SUBSET3_MODULE'),
    ('shadow-param', m(OK, '  const C := [0]\n  function F(C: int): int { C }\n'), 'SUBSET3_NAME'),
    ('shadow-local', m('    var C := 1;\n' + OK, '  const C := [0]\n'), 'SUBSET3_NAME'),
    ('reuse-local', m('    if true { var x := 1; } else { var x := 2; }\n' + OK), 'SUBSET3_NAME'),
    ('js-name', m('    var eval := 1;\n' + OK), 'SUBSET3_NAME'),
    ('guard-brace', m('    if 1 in {1} { }\n' + OK), 'SUBSET3_GUARD_BRACE'),
    ('guard-paren-brace', m('    if (1 in {1}) { }\n' + OK), None),
    ('chain-call', m('    var b := 0 <= F() <= 1;\n' + OK, '  function F(): int { 0 }\n'), 'SUBSET3_CHAIN'),
    ('chain-atoms', m('    var b := 0 <= context.original <= context.remaining;\n' + OK), None),
    ('ghost-var-method', m('    ghost var g := M();\n' + OK, '  method M() returns (r: int) { r := 0; }\n'), 'SUBSET3_GHOST'),
    ('ghost-method-call', m('    G(5);\n' + OK, '  ghost method G(n: nat) { }\n'), None),
    ('assert-by', m('    assert true by { }\n' + OK), None),
    ('hex', m('    var h := 0x10;\n' + OK), 'SUBSET3_LITERAL'),
    ('big-literal', m('    var h := 12345678901234567890;\n' + OK), 'SUBSET3_LITERAL'),
    ('as', m('    var h := 1 as int;\n' + OK), 'SUBSET3_SYNTAX'),
    ('index', m('    var h := context.chargeId[0];\n' + OK), 'SUBSET3_SYNTAX'),
    ('such-that', m('    var k :| k == 1;\n' + OK), 'SUBSET3_SYNTAX'),
    ('expect', m('    expect true;\n' + OK), 'SUBSET3_FORBIDDEN'),
    ('induction-false', m(OK, '  lemma {:induction false} L() ensures true { }\n'), None),
    ('induction-true', m(OK, '  lemma {:induction true} L() ensures true { }\n'), 'SUBSET3_ATTRIBUTE'),
    ('at-attribute', m(OK, '  @IsolateAssertions method X() { }\n'), 'SUBSET3_ATTRIBUTE'),
    ('ls-in-comment', m('    // a b\n' + OK), None),
    ('nul-in-comment', m('    // a\x00b\n' + OK), 'SUBSET3_LEX'),
    ('cr-ends-comment', m('    // a\rwhile true { }\n' + OK), 'SUBSET3_STATEMENT'),
    ('backslash-newline', m('    var s := "a\\\n";\n' + OK), 'SUBSET3_LEX'),
    ('fanout-cap', m('    var f := F6(context);\n' + OK, '  predicate F0(c: Context) { ValidContext(c) }\n' + ''.join(
        '  predicate F%d(c: Context) { F%d(c) && F%d(c) }\n' % (k, k - 1, k - 1) for k in range(1, 7))), 'SUBSET3_WEIGHT'),
]
SCOPE = [  # (name, bytes, refused by today's gate?, refused after the scope diff?)
    ('C9-comment-word', HEAD.encode() + b'  // We include no other file.\n' + m(OK)[len(HEAD):], True, False),
    ('C12-crlf', m(OK).replace(b'\n', b'\r\n'), True, False),
    ('C10-induction', m(OK, '  lemma {:induction false} L() ensures true { }\n'), True, False),
    ('C11-at-in-string', m(OK, '  const Contact: string := "a@b"\n'), True, None),
    ('second-include-line', HEAD.encode() + b'include "x.dfy"\n' + m(OK)[len(HEAD):], True, True),
    ('crlf-second-include', (HEAD + 'include "x.dfy"\n').replace('\n', '\r\n').encode() + m(OK)[len(HEAD):], True, True),
    ('verify-false', m(OK, '  lemma {:verify false} L() ensures false { }\n'), True, True),
    ('at-attribute', m(OK, '  @IsolateAssertions method X() { }\n'), True, True),
]
fails = 0
base = E / 'diff/work'
corpus = json.loads((E / 'eval3_results.json').read_text())
for label in ('refund-subset3-standalone', 'refund-subset3-combined', 'refund-subset3-combined-scope'):
    rule, n, real = load_subset(base / label / 'gate/refund.py')
    check, called = load_scope(base / label / 'gate/refund.py', real)
    print('%s: %d definitions extracted; bounded_subset3 called in prepare: %s' % (label, n, called))
    fails += not called
    for name, data, want in UNIT:
        got = rule(data)
        ok = (got is None) if want is None else (got is not None and got.startswith(want))
        fails += not ok
        if not ok or label == 'refund-subset3-standalone':
            print('  %-4s %-20s want=%-20s got=%s' % ('ok' if ok else 'FAIL', name, want, (got or 'pass')[:60]))
    mismatch = [r['file'] for r in corpus if (rule((R / r['file']).read_bytes()) or 'pass') != r['rule3']]
    agree = [r['file'] for r in corpus if (standalone((R / r['file']).read_bytes()) or 'pass') != r['rule3']]
    print('  corpus %d files: patched-copy mismatches %d; standalone mismatches %d' % (len(corpus), len(mismatch), len(agree)))
    fails += len(mismatch) + len(agree)
for label, column in (('a', 0), ('refund-scope-minimal', 1), ('refund-subset3-combined-scope', 2)):
    path = base / label / 'gate/refund.py'
    check, called = load_scope(path, load_subset(path)[2] if column == 2 else None)
    print('scope rules of %s:' % ('985f5eaf (today)' if label == 'a' else label))
    for name, data, today, after in SCOPE:
        got = check(data)
        want = today if column == 0 else (after if after is not None else (column == 1))
        ok = (got is not None) == want
        fails += not ok
        print('  %-4s %-22s want_refused=%-5s got=%s' % ('ok' if ok else 'FAIL', name, want, (got or 'pass')[:60]))
print('FAILURES', fails)
sys.exit(1 if fails else 0)
