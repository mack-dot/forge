#!/usr/bin/env python3
"""Generate adversarial candidates for subset_rule2 review (r-subset2)."""
import os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'subs')
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = ('  method Assess(context: Context, response: ModelResponse)\n'
       '      returns (decision: Decision, plan: seq<RefundIntent>)\n  {\n')
DECIDE = ('    if Eligible(context, response) {\n'
          '      decision := Authorized(response.amount, response.reason);\n'
          '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
          '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n')
def sub(name, members='', pre='', tail='', post=''):
    text = HEAD + members + SIG + pre + DECIDE + post + '  }\n}\n' + tail
    open(os.path.join(D, name + '.dfy'), 'w').write(text)

# A01: exponential DAG equality. Display element `if c == c then a else a` counts as "boolean" (flat).
def dag(levels, width):
    lines = ['    var c := 0;\n', '    var a0 := [true];\n', '    var b0 := [true];\n']
    for i in range(1, levels + 1):
        for v in 'ab':
            el = ', '.join(['if c == c then %s%d else %s%d' % (v, i - 1, v, i - 1)] * width)
            lines.append('    var %s%d := [%s];\n' % (v, i, el))
    lines.append('    var same := a%d == b%d;\n' % (levels, levels))
    lines.append('    if same { decision := Rejected; }\n')
    return ''.join(lines)
sub('A01-dag-equality-2x40', pre=dag(40, 2))
sub('A01s-dag-equality-2x12-small', pre=dag(12, 2))

# A02: a compiled method named `hide` is skipped as a ghost statement; unbounded recursion on input.
sub('A02-hide-named-method', members=(
    '  method hide(n: int)\n    decreases if n < 0 then 0 else n\n  {\n'
    '    if n > 0 { hide(n - 1); hide(n - 1); }\n  }\n\n'),
    pre='    hide(context.original);\n')

# A03: extra ghost-only modules whose names collide with JavaScript names of the CommonJS wrapper / runtime.
for nm in ('require', 'exports', 'BigNumber', 'module_'):
    sub('A03-extra-module-' + nm, tail='\nmodule %s {\n  ghost function G(): int { 0 }\n}\n' % nm)

# A04: `+ [display]` where the display element is a sequence via the boolean trick: s := s + [if c==c then s else s]
sub('A04-seq-of-seq-growth', pre=(
    '    var c := 0;\n    var s: seq<seq<int>> := [[]];\n    var i := 0;\n'
    '    while i < 600 {\n      s := s + [if c == c then [] else []];\n      i := i + 1;\n    }\n'))

# A05: literal hex operand of `*` beyond 10^40 (claim arithmetic): x := x * 0xFFFF... in a loop.
sub('A05-hex-multiplier-loop', pre=(
    '    var x := 1;\n    var i := 0;\n'
    '    while i < 500 {\n      x := x * 0x' + 'F' * 38 + ';\n      i := i + 1;\n    }\n'))

# A06: `-` is unrestricted: x := x - (0 - x) doubling inside a loop of 600 (2^600 only: bounded).
sub('A06-minus-doubling-loop', pre=(
    '    var x := context.original;\n    var i := 0;\n'
    '    while i < 600 {\n      x := x - (0 - x);\n      i := i + 1;\n    }\n'))

# A07: the token `hide` starts a skipped "ghost statement" anywhere, even as an identifier.
sub('A07a-hide-named-function', members=(
    '  function hide(n: nat): nat\n  {\n'
    '    if n == 0 then 0 else var r := hide(n - 1); var t := hide(n - 1); r - t\n  }\n\n'),
    pre='    var z := hide(if context.original < 0 then 0 else context.original);\n')
sub('A07b-hide-local-then-seq-comprehension', pre=(
    '    var hide := 0;\n'
    '    var z := hide + |seq(if context.original < 0 then 0 else context.original, i => i)|;\n'))
sub('A01m-dag-equality-2x22-measure', pre=dag(22, 2))

# A08: a parameter shadows the const display C; `|C|` is then the input length, not the display length.
sub('A08-param-shadows-const-display', members=(
    '  const C := [0]\n\n'
    '  method Spin(C: string) returns (n: int)\n  {\n    n := 0;\n'
    '    for a := 0 to |C| {\n      for b := 0 to |C| {\n        for d := 0 to |C| {\n'
    '          for e := 0 to |C| {\n            for f := 0 to |C| {\n              n := n + 1;\n            }\n          }\n        }\n      }\n    }\n  }\n\n'),
    pre='    var spun := Spin(context.chargeId);\n')
# A09: a local shadows the const display C inside Assess.
sub('A09-local-shadows-const-display', members='  const C := [0]\n\n', pre=(
    '    var C := context.chargeId;\n    var n := 0;\n'
    '    for a := 0 to |C| {\n      for b := 0 to |C| {\n        for d := 0 to |C| {\n'
    '          for e := 0 to |C| {\n            for f := 0 to |C| {\n              n := n + 1;\n            }\n          }\n        }\n      }\n    }\n'))

# A05b: per-operation growth with a 40-character hex literal (2^152 > 10^40); loop of 100.
sub('A05b-hex-multiplier-loop-100', pre=(
    '    var x := 1;\n    var i := 0;\n'
    '    while i < 100 {\n      x := x * 0x' + 'F' * 38 + ';\n      i := i + 1;\n    }\n'))
# L-series lexer/scope probes (rule only).
L = {
 'L11-block-comment-with-slashes-cr': '    /* // hidden\r  while true { } */\n',
 'L12-string-with-comment-close': '    var s := "*/ while true { } /*";\n',
 'L13-verbatim-doubled-quote': '    var s := @"a""b // c";\n',
 'L14-char-dquote-and-escaped-quote': "    var a := '\"'; var b := '\\'';\n",
}
for k, v in L.items():
    sub(k, pre=v)
open(os.path.join(D, 'L15-attr-induction-then-verify-false.dfy'), 'w').write(
    HEAD + '  lemma {:induction false}{:verify false} F() { }\n' + SIG + DECIDE + '  }\n}\n')
open(os.path.join(D, 'L16-attr-induction-extern.dfy'), 'w').write(
    HEAD + '  lemma {:induction false, extern} F() { }\n' + SIG + DECIDE + '  }\n}\n')
open(os.path.join(D, 'L17-crlf-second-include.dfy'), 'w').write(
    (HEAD.replace('\n', '\r\n')).replace('module', 'include "../spec/refund/RefundSpec.dfy"\r\nmodule', 1) + SIG + DECIDE + '  }\n}\n')
open(os.path.join(D, 'L18-include-at-line-start-in-block-comment.dfy'), 'w').write(
    HEAD + '/*\ninclude "x.dfy"\n*/\n' + SIG + DECIDE + '  }\n}\n')
open(os.path.join(D, 'L19-attr-induction-extra-spaces.dfy'), 'w').write(
    HEAD + '  lemma {:induction   false } F() { }\n' + SIG + DECIDE + '  }\n}\n')

# A10: recursion depth: a local shadows const display C and is passed at the decreasing parameter.
sub('A10-recursion-shadowed-const-display', members=(
    '  const C := [0]\n\n'
    '  function Len(P: string): int\n    decreases |P|\n  {\n    if |P| == 0 then 0 else 1 + Len(P[1..])\n  }\n\n'),
    pre='    var C := context.chargeId;\n    var depth := Len(C);\n')
