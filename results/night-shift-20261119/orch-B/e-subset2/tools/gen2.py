#!/usr/bin/env python3
"""Generate the new correct (N*) and hostile (X*) variants for subset rule 2. Writes under ../subs only."""
from pathlib import Path
E = Path(__file__).resolve().parent.parent
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = ('  method Assess(context: Context, response: ModelResponse)\n'
       '      returns (decision: Decision, plan: seq<RefundIntent>)\n')
DECIDE = ('    if Eligible(context, response) {\n'
          '      decision := Authorized(response.amount, response.reason);\n'
          '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
          '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n')
REASONS = '  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]\n'


def m(body, pre='', post=''):
    return HEAD + pre + SIG + '  {\n' + body + '  }\n}\n' + post


CORRECT = {
    'N01-while-literal-table': m(
        '    var found := false;\n    var i := 0;\n    while i < 3\n      invariant 0 <= i <= 3\n'
        '      invariant found <==> response.Candidate? && response.reason in Reasons[..i]\n'
        '      decreases 3 - i\n    {\n'
        '      if response.Candidate? && Reasons[i] == response.reason { found := true; }\n      i := i + 1;\n    }\n'
        '    assert Reasons[..3] == Reasons;\n'
        '    if found && ValidContext(context) && 0 <= response.amount <= context.remaining {\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n', REASONS),
    'N02-for-const-display-table': m(
        '    var found := false;\n    for i := 0 to |Reasons|\n'
        '      invariant found <==> response.Candidate? && response.reason in Reasons[..i]\n    {\n'
        '      if response.Candidate? && Reasons[i] == response.reason { found := true; }\n    }\n'
        '    assert Reasons[..|Reasons|] == Reasons;\n'
        '    if found && ValidContext(context) && 0 <= response.amount <= context.remaining {\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n', REASONS),
    'N03-for-bounded-local-plan': m(
        '    var n := if Eligible(context, response) then 1 else 0;\n    plan := [];\n'
        '    for i := 0 to n\n      invariant |plan| == i\n'
        '      invariant forall k :: 0 <= k < i ==> plan[k] == Intent(context.chargeId, context.requestId, '
        'response.amount, response.reason)\n    {\n'
        '      plan := plan + [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    }\n'
        '    decision := if n == 1 then Authorized(response.amount, response.reason) else Rejected;\n'),
    'N04-flag-product': m(
        '    var f := if ValidContext(context) then 1 else 0;\n'
        '    var g := if response.Candidate? && 0 <= response.amount <= context.remaining then 1 else 0;\n'
        '    var h := if response.Candidate? && AllowedReason(response.reason) then 1 else 0;\n'
        '    var p := f * g * h;\n'
        '    if p == 1 {\n      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n'),
    'N05-recursion-over-display': m(
        '    var checks := [ValidContext(context), response.Candidate? && 0 <= response.amount,\n'
        '                   response.Candidate? && response.amount <= context.remaining,\n'
        '                   response.Candidate? && AllowedReason(response.reason)];\n'
        '    AllTrueIff(checks);\n'
        '    if AllTrue(checks) {\n'
        '      assert checks[0] && checks[1] && checks[2] && checks[3];\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      assert !(checks[0] && checks[1] && checks[2] && checks[3]);\n'
        '      decision := Rejected;\n      plan := [];\n    }\n',
        '  function AllTrue(bs: seq<bool>): bool\n    decreases |bs|\n'
        '  {\n    if |bs| == 0 then true else bs[0] && AllTrue(bs[1..])\n  }\n\n'
        '  lemma AllTrueIff(bs: seq<bool>)\n    ensures AllTrue(bs) <==> forall i :: 0 <= i < |bs| ==> bs[i]\n'
        '    decreases |bs|\n  {\n    if |bs| > 0 { AllTrueIff(bs[1..]); }\n  }\n\n'),
    'N06-extra-ghost-module': m(DECIDE, '', '\nmodule Facts {\n'
        '  lemma AddZero(x: int)\n    ensures x + 0 == x\n  {\n  }\n\n'
        '  ghost function Twice(x: int): int\n  {\n    x + x\n  }\n\n'
        '  lemma TwiceIsDouble(x: int)\n    ensures Twice(x) == 2 * x\n  {\n  }\n}\n'),
    'N07-separator-comments': m(
        '    // line separator paragraph separator next line\u0085 tab\x0bform\x0cfeed: while (true) {}\n'
        + DECIDE),
    'N08-input-field-product': m(
        '    if Eligible(context, response) {\n'
        '      var scaled := response.amount * context.original;\n'
        '      decision := Authorized(response.amount + 0 * scaled, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n'),
    'N09-nested-literal-loops': m(
        '    var count := 0;\n    var i := 0;\n    while i < 3\n      invariant 0 <= i <= 3\n'
        '      invariant count == 2 * i\n      decreases 3 - i\n    {\n'
        '      var j := 0;\n      while j < 2\n        invariant 0 <= j <= 2\n'
        '        invariant count == 2 * i + j\n        decreases 2 - j\n      {\n'
        '        count := count + 1;\n        j := j + 1;\n      }\n      i := i + 1;\n    }\n'
        '    if count == 6 && Eligible(context, response) {\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n'),
    'N10-induction-false-lemma': m(DECIDE, '  lemma {:induction false} LengthNonNeg(s: seq<int>)\n'
        '    ensures |s| >= 0\n  {\n  }\n\n'),
    'N11-extra-module-lemma-call': m(
        '    Facts.AddZero(response.amount);\n' + DECIDE, '', '\nmodule Facts {\n'
        '  lemma AddZero(x: int)\n    ensures x + 0 == x\n  {\n  }\n}\n'),
}
CORRECT['N12-crlf-induction-false'] = CORRECT['N10-induction-false-lemma'].replace('\n', '\r\n')

H = 'if response.Candidate? && response.amount == 123456789 '
HOSTILE = {
    'X01-loop-bound-1e12': m('    var i := 0;\n    while i < 1000000000000 { i := i + 1; }\n' + DECIDE),
    'X02-for-literal-bigint-multiplier': m(
        '    var x := if response.Candidate? then response.amount else 0;\n'
        '    for i := 0 to 64 {\n      x := x * 1000000000000000000000000000000000000000;\n    }\n' + DECIDE),
    'X03-display-bound-by-function': m(
        '    var i := 0;\n    while i < |Make()| { i := i + 1; }\n' + DECIDE,
        '  function Make(): seq<int> { [1, 2, 3] }\n'),
    'X04-nested-1000-cubed': m(
        '    for a := 0 to 1000 {\n      for b := 0 to 1000 {\n        for c := 0 to 1000 {\n'
        '          var t := 1;\n        }\n      }\n    }\n' + DECIDE),
    'X05-loop-iterated-input-product': m(
        '    var acc := 1;\n    if response.Candidate? {\n      for i := 0 to 64 {\n'
        '        acc := acc * response.amount;\n      }\n    }\n' + DECIDE),
    'X06-loop-one-level-input-product': m(
        '    if response.Candidate? {\n      for i := 0 to 64 {\n'
        '        var x := response.amount * context.original;\n      }\n    }\n' + DECIDE),
    'X07-ghost-module-hides-compiled': m(DECIDE, '', '\nmodule Helpers {\n'
        '  function Spin(n: nat): nat { if n == 0 then 0 else Spin(n - 1) }\n}\n'),
    'X08-extra-module-called-from-compiled': m(
        '    var k := Helpers.G(3);\n' + DECIDE, '', '\nmodule Helpers {\n'
        '  ghost function G(n: nat): nat { if n == 0 then 0 else G(n - 1) }\n}\n'),
    'X09-extra-lemma-name-collision': m(
        '    var k := Spin(response.amount);\n' + DECIDE,
        '  function Spin(n: int): int decreases if n < 0 then 0 else n { if n <= 0 then 0 else Spin(n - 1) }\n',
        '\nmodule Helpers {\n  lemma Spin(n: int) { }\n}\n'),
    'X10-decreases-lies': m(
        '    var i := 0;\n    while i < 10 decreases 1000000 - i { i := i + 1; }\n' + DECIDE),
    'X11-counter-reset-in-body': m(
        '    var i := 0;\n    while i < 10 {\n      if ' + H[3:] + '{ i := 0; }\n      i := i + 1;\n    }\n'
        + DECIDE),
    'X12-bound-shadowed-by-case-pattern': m(
        '    var n := 3;\n    match response {\n      case Candidate(n, r) =>\n        var i := 0;\n'
        '        while i < n { i := i + 1; }\n      case _ =>\n    }\n' + DECIDE),
    'X13-bound-shadowed-in-block': m(
        '    var n := 3;\n    {\n      var n := if response.Candidate? then response.amount else 0;\n'
        '      var i := 0;\n      while i < n { i := i + 1; }\n    }\n' + DECIDE),
    'X14-hex-bound': m('    var i := 0;\n    while i < 0x7fffffff { i := i + 1; }\n' + DECIDE),
    'X15-underscore-bound': m('    for i := 0 to 1_000_000_000 {\n    }\n' + DECIDE),
    'X16-recursion-over-input-string': m(
        '    var c := if response.Candidate? then Count(response.reason) else 0;\n' + DECIDE,
        '  function Count(s: string): nat\n    decreases |s|\n  {\n'
        '    if |s| == 0 then 0 else 1 + Count(s[1..])\n  }\n'),
    'X17-recursion-two-self-calls': m(
        '    var c := Fib([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);\n' + DECIDE,
        '  function Fib(s: seq<int>): bool\n    decreases |s|\n  {\n'
        '    if |s| == 0 then true else Fib(s[1..]) && Fib(s[1..])\n  }\n'),
    'X18-recursion-decreases-other-param': m(
        '    var c := if response.Candidate? && response.amount >= 0 then Down([true], response.amount) else 0;\n'
        + DECIDE,
        '  function Down(s: seq<bool>, n: nat): nat\n    decreases n\n  {\n'
        '    if n == 0 then 0 else 1 + Down(s, n - 1)\n  }\n'),
    'X19-display-local-reassigned': m(
        '    var s := [true, true];\n    if response.Candidate? {\n      s := s + [true];\n    }\n'
        '    var c := Len(s);\n' + DECIDE,
        '  function Len(bs: seq<bool>): nat\n    decreases |bs|\n  {\n'
        '    if |bs| == 0 then 0 else 1 + Len(bs[1..])\n  }\n'),
    'X20-invariant-set-display-misparse': m(
        '    var i := 0;\n    while i < 3 invariant i in {0, 1, 2, 3} {\n'
        '      var j := 0;\n      while j < 4000 { j := j + 1; }\n      i := i + 1;\n    }\n' + DECIDE),
    'X21-case-pattern-shadow-squaring': m(
        '    var p := 1;\n    match response {\n      case Candidate(p, r) =>\n        var q := p * p;\n'
        '      case _ =>\n    }\n' + DECIDE),
    'X22-bounded-local-overflow-chain': m(
        '    var a := 1000000000000000000000000000000000000000;\n    var b := a * a;\n    var c := b * b;\n'
        '    var d := c * c;\n' + DECIDE),
    'X23-three-field-product': m(
        '    if response.Candidate? {\n'
        '      var x := context.original * response.amount * context.remaining;\n    }\n' + DECIDE),
    'X24-field-product-fed-back': m(
        '    if response.Candidate? {\n      var a := context.original * response.amount;\n'
        '      var b := a * a;\n    }\n' + DECIDE),
    'X25-shadowed-response-field-product': m(
        '    if response.Candidate? {\n      var x := context.original;\n      {\n'
        '        var response := Candidate(response.amount * response.amount, "");\n'
        '        var y := response.amount * response.amount;\n      }\n    }\n' + DECIDE),
    'X26-braceless-match-arm-increment': m(
        '    var i := 0;\n    while i < 10 {\n      match response\n      case Missing => i := i + 0;\n'
        '      case _ => i := i + 1;\n    }\n' + DECIDE),
    'X27-loop-break': m('    var i := 0;\n    while i < 10 {\n      if i == 5 { break; }\n      i := i + 1;\n    }\n'
                        + DECIDE),
    'X28-for-downto': m('    for i := 10 downto 0 {\n    }\n' + DECIDE),
    'X29-while-guard-le': m('    var i := 0;\n    while i <= 10 { i := i + 1; }\n' + DECIDE),
    'X30-loop-sequence-doubling': m(
        '    var s := if response.Candidate? then response.reason else "";\n'
        '    for i := 0 to 64 {\n      s := s + s;\n    }\n' + DECIDE),
    'X31-bounded-local-big-loop-bound': m(
        '    var n := if ' + H[3:] + 'then 1000000 else 0;\n    var i := 0;\n'
        '    while i < n { i := i + 1; }\n' + DECIDE),
    'X32-lone-cr-comment-hides-decrement': m(
        '    var i := 0;\n    while i < 10 {\n      // note\ri := i - 1;\n      i := i + 1;\n    }\n' + DECIDE),
    'X33-ls-comment-loop-text': m('    // note     while true { }\n' + DECIDE),
    'X34-counter-two-loops': m(
        '    var i := 0;\n    while i < 10 { i := i + 1; }\n    while i < 20 { i := i + 1; }\n' + DECIDE),
    'X35-display-append-in-big-loop': m(
        '    var s: seq<int> := [];\n    for i := 0 to 4000 {\n      s := s + [1, 2, 3, 4];\n    }\n' + DECIDE),
    'X36-counter-out-param-reset': m(
        '    var i := 0;\n    while i < 10 {\n      var t;\n      t, i := Zero();\n      i := i + 1;\n    }\n'
        + DECIDE, '  method Zero() returns (a: int, b: int) { a, b := 0, 0; }\n'),
    'X37-recursion-display-local-bigger-elements': m(
        '    var s := [response.reason];\n    var c := Len(s);\n' + DECIDE,
        '  function Len(bs: seq<string>): nat\n    decreases |bs|\n  {\n'
        '    if |bs| == 0 then 0 else |bs[0]| + Len(bs[1..])\n  }\n'),
    'X38-bounded-local-in-display-append-loop': m(
        '    var k := 16;\n    var s: seq<int> := [];\n    var i := 0;\n    while i < k {\n'
        '      s := s + [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];\n      i := i + 1;\n    }\n'
        + DECIDE),
    'X39-tuple-index-plus-concat': m(
        '    var t := ("a", 1);\n    var s := t.0 + t.0;\n' + DECIDE),
    'X40-recursion-measure-not-decreasing': m(
        '    var c := Grow([true, true]);\n' + DECIDE,
        '  function Grow(bs: seq<bool>): nat\n    decreases |bs|\n  {\n'
        '    if |bs| == 0 then 0 else Grow(bs[1..] + [true])\n  }\n'),
    'X41-recursive-call-in-loop': m(
        '    var c := 0;\n    for i := 0 to 3 {\n      c := Walk([true, true]);\n    }\n' + DECIDE,
        '  method Walk(bs: seq<bool>) returns (n: nat)\n    decreases |bs|\n  {\n'
        '    n := 0;\n    for i := 0 to 2 {\n      if |bs| > 0 { n := Walk(bs[1..]); }\n    }\n  }\n'),
}

CONTROLS = {'N11-extra-module-lemma-call': CORRECT.pop('N11-extra-module-lemma-call')}  # Dafny exit 2: Facts unresolved
for kind, table in (('correct', CORRECT), ('hostile', HOSTILE), ('controls', CONTROLS)):
    d = E / 'subs' / kind
    d.mkdir(parents=True, exist_ok=True)
    for name, text in table.items():
        (d / (name + '.dfy')).write_bytes(text.encode('utf-8'))
print(len(CORRECT), 'correct', len(HOSTILE), 'hostile')
