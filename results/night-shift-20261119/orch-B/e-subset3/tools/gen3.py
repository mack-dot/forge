#!/usr/bin/env python3
"""Second attack round against rule 3 (Y01-Y46): writes ../subs/hostile/*.dfy and ../subs/probe/*.dfy."""
from pathlib import Path
E = Path(__file__).resolve().parent.parent
H, P = E / 'subs/hostile', E / 'subs/probe'
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '  method Assess(context: Context, response: ModelResponse)\n      returns (decision: Decision, plan: seq<RefundIntent>)\n'
GOOD = ('    if Eligible(context, response) {\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n')
TRIG = 'response.Candidate? && response.amount == 123456789'


def m(body, pre='', post='', good=GOOD):
    return HEAD + pre + SIG + '  {\n' + body + good + '  }\n}\n' + post


S = {}
# Sharing through var chains (B1 family): tree size doubles per level.
S['Y01-var-chain-sharing'] = m('    var a0 := [context];\n' + ''.join(
    '    var a%d := [a%d, a%d];\n' % (k, k - 1, k - 1) for k in range(1, 30)) + '    var same := a29 == a29;\n')
# Nested if-expression tower, 40 levels, linear text (only one path executes).
S['Y02-if-tower-40'] = m('    var x := ' + ''.join('if %s then %d else ' % (TRIG, k) for k in range(40)) + '0;\n')
# Deep nesting of match expressions, 20 levels.
S['Y03-match-nest-20'] = m('    var y := ' + ''.join('match response { case Candidate(a%d, r%d) => ' % (k, k) for k in range(20))
                           + '0' + ' case _ => 1 }' * 20 + ';\n')
# Field selection chains on a string field: refused (no field on string).
S['Y04-field-chain'] = m('    var z := context.chargeId.chargeId;\n')
# Flatness through helper returns: helpers returning structures, nested in displays.
S['Y05-helper-structure-returns'] = m(
    '    var q := [P2(context), P2(context)];\n',
    pre='  function P1(c: Context): seq<RefundIntent> { [Intent(c.chargeId, c.requestId, 0, ""), '
        'Intent(c.chargeId, c.requestId, 1, "")] }\n'
        '  function P2(c: Context): seq<seq<RefundIntent>> { [P1(c), P1(c)] }\n')
# Helper fan-out: 12 levels of 2 calls = 4096 spec calls.
fan = ''.join('  predicate F%d(c: Context, r: ModelResponse) { F%d(c, r) && F%d(c, r) }\n' % (k, k - 1, k - 1)
              for k in range(1, 13))
S['Y06-helper-fanout-2x12'] = m('    var f := F12(context, response);\n',
                                pre='  predicate F0(c: Context, r: ModelResponse) { Eligible(c, r) }\n' + fan)
# Fan-out under the cap: 3 levels (8 spec calls).
S['Y07-helper-fanout-2x3'] = m('    var f := F3(context, response);\n',
                               pre='  predicate F0(c: Context, r: ModelResponse) { Eligible(c, r) }\n' +
                               fan.split('\n')[0] + '\n' + fan.split('\n')[1] + '\n' + fan.split('\n')[2] + '\n')
S['Y08-default-parameter'] = m('    var d := H();\n', pre='  function H(x: int := 5): int { x }\n')
S['Y09-as-conversion'] = m('    var e := (if response.Candidate? then response.amount else 0) as real;\n')
S['Y10-char-arithmetic'] = m("    var ch := 'a' + 'b';\n")
S['Y11-string-index'] = m('    var s0 := if |context.chargeId| > 0 then context.chargeId[0] else \'x\';\n')
S['Y12-string-slice'] = m('    var s1 := if |context.chargeId| > 3 then context.chargeId[..3] else "";\n')
S['Y13-length-of-input'] = m('    var n := |context.chargeId| + |context.requestId|;\n    var big := n > 1000000;\n')
S['Y14-string-compare-chain'] = m('    var eq := context.chargeId == context.requestId == context.chargeId;\n    var lt := 0 <= |context.chargeId| <= '
                                  '|context.requestId| <= 99;\n')
S['Y15-large-int-compare'] = m('    var c1 := context.original < context.remaining;\n    var c2 := '
                               'context.original - context.remaining + MaxMoney > 0;\n')
S['Y16-ghost-var-calls-compiled-method'] = m('    ghost var g := Spin(5);\n',
                                             pre='  method Spin(n: nat) returns (r: nat) { r := n; }\n')
S['Y17-ghost-method-loop-huge'] = m('    if %s { Relay(); }\n' % TRIG,
                                    pre='  ghost method Spin(n: nat) {\n    var i := 0;\n    while i < n decreases n - i '
                                        '{ i := i + 1; }\n  }\n'
                                        '  method Relay() {\n    Spin(1000000000000000000);\n  }\n')
S['Y18-extern-attribute'] = m('', pre='  function {:extern} Ext(): int\n')
S['Y19-extra-module-require'] = m('', post='module require {\n  const x := 1\n}\n')
S['Y20-js-let-local'] = m('    var let := 1;\n')
S['Y21-js-toString-member'] = m('    var t := toString(context);\n', pre='  function toString(c: Context): int { 0 }\n')
S['Y22-js-arguments-await'] = m('    var arguments := 1;\n    var await := arguments + 1;\n')
S['Y23-js-proto-name'] = m('    var __proto__ := 1;\n')
S['Y24-addition-doubling-400'] = m('    if %s {\n      var x0 := response.amount;\n' % TRIG + ''.join(
    '      var x%d := x%d + x%d;\n' % (k, k - 1, k - 1) for k in range(1, 400)) + '    }\n')
S['Y25-literal-multiplier-chain-300'] = m('    if %s {\n      var x0 := response.amount;\n' % TRIG + ''.join(
    '      var x%d := x%d * 9999999999999999999;\n' % (k, k - 1) for k in range(1, 300)) + '    }\n')
S['Y26-pattern-var-shadows-const'] = m('    match response {\n      case Candidate(K, r) =>\n      case _ =>\n    }\n',
                                       pre='  const K := [0]\n')
S['Y27-name-reuse-disjoint-branches'] = m('    if response.Candidate? { var x := 1; } else { var x := [context]; }\n')
S['Y28-set-display-in-if-expression'] = m('    var inset := if response.Candidate? && response.amount in {1, 2, 3} then 1 else 0;\n')
S['Y29-set-display-match-scrutinee'] = m('    match {1} == {1} {\n      case true =>\n      case false =>\n    }\n')
S['Y30-chain-with-call-in-middle'] = m('    var w := 0 <= G(context) <= 1;\n', pre='  function G(c: Context): int { 0 }\n')
S['Y31-mutual-recursion-methods'] = m('    var v := M1(3);\n',
                                      pre='  method M1(n: nat) returns (r: nat) decreases n, 1 { r := 0; if n > 0 { r := M2(n); } }\n'
                                          '  method M2(n: nat) returns (r: nat) decreases n, 0 { r := M1(n - 1); }\n')
S['Y32-const-function-cycle'] = m('    var u := A;\n', pre='  const A: int := Fa(1)\n  function Fa(x: int): int { if x > 0 then 0 else A }\n')
S['Y33-const-nested-displays'] = m('    var p := D2 == D2;\n',
                                   pre='  const D1 := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]\n'
                                       '  const D2 := [D1, D1, D1]\n')
S['Y34-tuple-helper-equality'] = m('    var t := (Pr(context), Pr(context));\n    var same := t.0 == t.1;\n',
                                   pre='  function Pr(c: Context): (string, string) { (c.chargeId, c.requestId) }\n')
S['Y35-hex-multiplier'] = m('    var hx := if response.Candidate? then response.amount * 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF else 0;\n')
S['Y36-underscore-literal'] = m('    var us := 1_000;\n')
S['Y37-division-by-input'] = m('    var dv := if response.Candidate? && response.amount != 0 then 10 / response.amount else 0;\n')
S['Y38-compiled-forall'] = m('    var fa := forall i :: 0 <= i < |context.chargeId| ==> context.chargeId[i] == \'a\';\n')
S['Y39-compiled-such-that'] = m('    var st :| st == 1;\n')
S['Y40-lambda'] = m('    var fn := (x: int) => x + 1;\n')
S['Y41-display-17'] = m('    var big := [' + ', '.join(['0'] * 17) + '];\n')
S['Y42-long-literals-display'] = m('    var lits := [' + ', '.join(['"' + 'x' * 250 + '"'] * 16) + '];\n'
                                   '    var hit := response.Candidate? && response.reason in lits;\n')
S['Y42b-literals-display-16x64'] = m('    var lits := [' + ', '.join(['"' + chr(97 + k) * 64 + '"' for k in range(16)]) + '];\n'
                                     '    var hit := response.Candidate? && response.reason in lits;\n')
S['Y43-main-method'] = m('', pre='  method Main() { }\n')
S['Y44-havoc'] = m('    var hv: int := *;\n')
S['Y45-if-statement-tower-30'] = m('    var acc := 0;\n' + ''.join('    ' + '  ' * k + 'if %s {\n' % TRIG for k in range(30))
                                   + '    ' + '  ' * 30 + 'acc := 1;\n' + ''.join('    ' + '  ' * k + '}\n' for k in reversed(range(30))))
S['Y46-seq-concat-doubling'] = m('    var s0 := [context.chargeId];\n' + ''.join(
    '    var s%d := s%d + s%d;\n' % (k, k - 1, k - 1) for k in range(1, 40)))
S['Y47-string-concat-input'] = m('    var sc := context.chargeId + context.chargeId;\n')
S['Y48-method-out-tree-growth'] = m('    var o1 := Grow([context]);\n',
                                    pre='  method Grow(s: seq<Context>) returns (r: seq<seq<Context>>) { r := [s, s]; }\n')
S['Y49-unparenthesized-guard-display-then-block'] = m('    var i := 0;\n    if response.Candidate? && response.amount in {1} { } { i := i + 1; }\n')
S['Y50-assert-hides-statement'] = m('    assert true; var hidden := 1;\n')

# Probes (not admitted by rule 3; translated to JavaScript to learn whether pinned Dafny mangles JS names).
PRB = {}
PRB['P01-js-locals'] = m('    var let := 1;\n    var await := let + 1;\n    var arguments := await + 1;\n    var eval := arguments;\n')
PRB['P02-js-members'] = m('    var a := toString(context);\n    var b := valueOf(context);\n    var c := require(context);\n',
                          pre='  function toString(c: Context): int { 1 }\n  function valueOf(c: Context): int { 2 }\n'
                              '  function require(c: Context): int { 3 }\n')
PRB['P03-js-proto-hasown'] = m('    var hasOwnProperty := 1;\n    var x := prototype(context);\n',
                               pre='  function prototype(c: Context): int { 4 }\n')

if __name__ == '__main__':
    H.mkdir(parents=True, exist_ok=True)
    P.mkdir(parents=True, exist_ok=True)
    for d, group in ((H, S), (P, PRB)):
        for name, text in group.items():
            (d / (name + '.dfy')).write_text(text)
    print(len(S), 'hostile', len(PRB), 'probes')
