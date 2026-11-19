#!/usr/bin/env python3
"""Write the NEW hostile variants. Each one tries to defeat the subset rule. Most are keyed to amount 123456789."""
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / 'subs/hostile'
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '''  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
'''
KEY = 'response.Candidate? && response.amount == 123456789'
TAIL = '''    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
def assess(pre):
    return SIG + '  {\n' + pre + TAIL
V = {}
V['HV01-mutual-recursion-three'] = '''  function F(n: nat): nat decreases n, 0 { if n == 0 then 0 else G(n - 1) }
  function G(n: nat): nat decreases n, 1 { H(n) }
  function H(n: nat): nat decreases n, 1 { F(n) }
''' + assess('    if %s { var z := F(100000000); }\n' % KEY)
V['HV02-function-type-param'] = '''  function Apply(f: nat -> nat, x: nat): nat { f(x) }
''' + assess('    if %s { var z := Apply(x => x, 3); }\n' % KEY)
V['HV03-function-value-reuse'] = '''  predicate Heavy(c: Context, r: ModelResponse) { Eligible(c, r) && Eligible(c, r) }
''' + assess('    var f := Heavy;\n    var b := f(context, response) && f(context, response) && f(context, response);\n')
V['HV04-var-such-that'] = assess('    if %s { var k: int :| k >= 1000000000000000000; }\n' % KEY)
V['HV05-huge-literal-sequence'] = assess(
    '    if %s { var s := [%s]; }\n' % (KEY, ', '.join('0' for _ in range(2000))))
# v2 (after run 1): HV01 decreases fixed, HV11/HV23/HV26 guarded by Candidate?, HV22 cut to 40 steps.
# Exponential evaluation without recursion: F_i calls F_(i-1) twice; 40 levels = 2^40 calls of F_0.
tower = '  predicate T0(x: int) { x == x }\n' + ''.join(
    '  predicate T%d(x: int) { T%d(x) && T%d(x) }\n' % (i, i - 1, i - 1) for i in range(1, 41))
V['HV06-call-tower-exponential'] = tower + assess('    if %s { var b := T40(response.amount); }\n' % KEY)
sq = ''.join('      var x%d := x%d * x%d;\n' % (i, i - 1, i - 1) for i in range(1, 21))
V['HV07-repeated-squaring'] = assess('    if %s {\n      var x0 := response.amount;\n%s    }\n' % (KEY, sq))
cat = ''.join('      var s%d := s%d + s%d;\n' % (i, i - 1, i - 1) for i in range(1, 21))
V['HV08-string-doubling'] = assess('    if %s {\n      var s0 := response.reason;\n%s    }\n' % (KEY, cat))
V['HV09-string-doubling-via-display'] = assess('    if %s {\n      var s0 := [response.reason];\n%s    }\n' % (
    KEY, ''.join('      var s%d := [s%d, s%d];\n' % (i, i - 1, i - 1) for i in range(1, 21))))
V['HV10-tuple-dag-equality'] = assess('    if %s {\n      var t0 := (response.reason, 0);\n%s      var b := t20 == t20;\n    }\n' % (
    KEY, ''.join('      var t%d := (t%d, t%d);\n' % (i, i - 1, i - 1) for i in range(1, 21))))
cases = ''.join('      case %d => decision := Rejected;\n' % i for i in range(300))
V['HV11-match-huge-literal-admissible-size'] = SIG + '''  {
    decision, plan := Rejected, [];
    match (if response.Candidate? then response.amount else 0) % 1000 {
''' + cases + '''      case _ => decision := Rejected;
    }
''' + TAIL
V['HV12-match-too-large'] = SIG + '''  {
    decision, plan := Rejected, [];
    match response.amount % 1000 {
''' + ''.join('      case %d => decision := Rejected;\n' % i for i in range(999)) + '''      case _ => decision := Rejected;
    }
''' + TAIL
V['HV13-cyrillic-homoglyph-while'] = assess('    var i := 0;\n    whіle i < 0 { i := i + 1; }\n')
V['HV14-lone-cr-comment-hides-loop'] = assess(
    '    var n: int := if %s then 1000000000000000000 else 0;\n    var i: int := 0;\n'
    '    // harmless\r    while i < n decreases n - i { i := i + 1; }\n' % KEY)
V['HV15-ghost-method-with-loop'] = '''  ghost method Spin(n: nat) {
    var i := 0;
    while i < n decreases n - i { i := i + 1; }
  }
''' + assess('    if %s { Spin(1000000000000000000); }\n' % KEY)
V['HV16-ghost-var-from-compiled-method'] = '''  method Step(n: nat) returns (r: nat) { r := n; }
''' + assess('    ghost var g := Step(5);\n')
V['HV17-forall-in-compiled-predicate'] = '''  predicate AllSmall(n: nat) { forall i :: 0 <= i < n ==> i >= 0 }
''' + assess('    if %s { var b := AllSmall(1000000000000000000); }\n' % KEY)
V['HV18-by-method-loop'] = '''  function Zero(n: nat): nat { 0 } by method {
    var i := 0;
    while i < n decreases n - i { i := i + 1; }
    return 0;
  }
''' + assess('    if %s { var z := Zero(1000000000000000000); }\n' % KEY)
V['HV19-seq-constructor-comment-split'] = assess('    if %s { var s := seq/**/(4294967296, i => 0); }\n' % KEY)
V['HV20-const-self-cycle'] = '''  const A: int := B + 1
  const B: int := A + 1
''' + assess('')
V['HV21-literal-mult-chain'] = assess('    if %s {\n      var x0 := response.amount;\n%s    }\n' % (KEY, ''.join(
    '      var x%d := x%d * 1 * x%d;\n' % (i, i - 1, i - 1) for i in range(1, 21))))
V['HV22-big-literal-multiplier-chain'] = assess('    if %s {\n      var x0 := response.amount;\n%s    }\n' % (KEY, ''.join(
    '      var x%d := x%d * 1000000000000000000000000000000000000000;\n' % (i, i - 1) for i in range(1, 41))))
V['HV23-set-display-in-guard'] = assess('    if response.Candidate? && response.amount in {1, 2, 3} { decision := Rejected; }\n')
V['HV24-negation-doubling'] = assess('    if %s {\n      var x0 := response.amount;\n%s    }\n' % (KEY, ''.join(
    '      var x%d := x%d - (0 - x%d);\n' % (i, i - 1, i - 1) for i in range(1, 201))))
V['HV25-tuple-of-helper-tuples'] = '''  function Pair(c: Context): (string, int) { (c.chargeId, 0) }
''' + assess('    if %s {\n      var t := (Pair(context), Pair(context));\n    }\n' % KEY)
V['HV26-set-display-guard-then-hidden-loop'] = assess(
    '    var i := 0;\n    if response.Candidate? && response.amount in {1} { } { while i < 0 { i := i + 1; } }\n')
for name, body in V.items():
    (OUT / (name + '.dfy')).write_bytes((HEAD + body + '}\n').encode('utf-8'))
print(len(V))
