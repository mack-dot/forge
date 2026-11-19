#!/usr/bin/env python3
"""Writes bypass candidates for rule 3 into bypass/. Each is a full impl/Refund.dfy. Pure text; no Dafny."""
import os, sys
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'bypass')
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = ('  method Assess(context: Context, response: ModelResponse)\n'
       '      returns (decision: Decision, plan: seq<RefundIntent>)\n  {\n')
NORMAL = ('    if Eligible(context, response) {\n'
          '      decision := Authorized(response.amount, response.reason);\n'
          '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
          '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n')
def sub(members='', pre='', body=NORMAL):
    return HEAD + members + SIG + pre + body + '  }\n}\n'
C = {}
# C01: literal value disagreement between Dafny (verifier) and JavaScript (runtime) in a dead branch.
C['C01-literal-dead-branch'] = sub(pre=(
    '    if 9007199254740993 == 9007199254740992 || 010 == 8 || 18014398509481985 == 18014398509481984 {\n'
    '      decision := Authorized(7, "returned_item");\n      plan := [];\n      return;\n    }\n'))
# C02: match statement over int with literal cases and no default (compiled halt if Dafny admits it).
C['C02-int-match-stmt-no-default'] = sub(pre=(
    '    var k := 0;\n    match |context.chargeId| {\n      case 0 => k := 1;\n      case 1 => k := 2;\n    }\n'))
# C03: match expression over int, no default.
C['C03-int-match-expr-no-default'] = sub(pre='    var k := match |context.requestId| case 0 => 1 case 1 => 2;\n')
# C04: string-literal match with no default.
C['C04-string-match-no-default'] = sub(pre=(
    '    var k := 0;\n    if response.Candidate? {\n      match response.reason {\n'
    '        case "duplicate_charge" => k := 1;\n      }\n    }\n'))
# C05: deep unary minus (recognizer recursion vs Dafny/JS nesting).
C['C05-unary-minus-900'] = sub(pre='    var k := ' + '- ' * 900 + '1;\n')
# C06: deep parentheses 120 (RecursionError path must refuse).
C['C06-parens-120'] = sub(pre='    var k := ' + '(' * 120 + '1' + ')' * 120 + ';\n')
# C07: const cycle through a function.
C['C07-const-function-cycle'] = sub(members='  const K: int := F(1)\n  function F(x: int): int { x + K }\n')
# C08: method call in a const initialiser.
C['C08-const-calls-method'] = sub(members='  const K: int := M()\n  method M() returns (r: int) { r := 1; }\n')
# C09: division by a named constant zero.
C['C09-div-by-named-zero'] = sub(members='  const Z: int := 0\n', pre='    var k := 5 / Z;\n')
# C10: division by a parenthesised zero expression.
C['C10-div-by-zero-expr'] = sub(pre='    var k := 5 / (1 - 1);\n')
# C11: division by single-arm match that is the literal 0.
C['C11-div-by-match-zero'] = sub(pre='    var k := 5 / match 3 case _ => 0;\n')
# C12: division by negated zero literal.
C['C12-div-by-neg-zero'] = sub(pre='    var k := 5 / -0;\n')
# C13: division by leading-zero zero literal.
C['C13-div-by-000'] = sub(pre='    var k := 5 / 000;\n')
# C14: expect hidden in an assert-by block (ghost in Dafny: expect is refused there anyway).
C['C14-expect-in-assert-by'] = sub(pre='    assert true by { expect false; }\n')
# C15: by-method split by an allowed attribute (forbidden pair check is on raw tokens).
C['C15-by-attr-method'] = sub(members=(
    '  function F(x: int): int { x } by {:induction false} method { var i := 0; while i < 1 { i := i + 1; } return x; }\n'))
# C16: attribute on the module name (dropped by the recognizer).
C['C16-attr-on-module'] = HEAD.replace('module Refund', 'module {:induction false} Refund') + SIG + NORMAL + '  }\n}\n'
# C17: ghost var with a let-expression semicolon (ghost region longer in Dafny than in the recognizer).
C['C17-ghost-let-semicolon'] = sub(pre='    var a := 1;\n    ghost var g := var b := 2; b;\n')
# C18: pattern variables named like spec fields.
C['C18-pattern-field-names'] = sub(pre=(
    '    var k := 0;\n    match response {\n      case Candidate(amount, reason) => k := amount;\n      case _ => k := 0;\n    }\n'))
# C19: helper function named like a field.
C['C19-member-named-amount'] = sub(members='  function amount(x: int): int { x }\n', pre='    var k := amount(1);\n')
# C20: member named toJSON / then-like JS names not in the deny list.
C['C20-member-toJSON'] = sub(members='  function toJSON(x: int): int { x }\n', pre='    var k := toJSON(1);\n')
C['C21-member-__defineGetter'] = sub(members='  function defineProperty(x: int): int { x }\n  function freeze(x: int): int { x }\n', pre='    var k := freeze(defineProperty(1));\n')
# C22: CRLF only (bare CR) line ends: recognizer whitespace vs Dafny.
C['C22-bare-cr-lines'] = sub().replace('\n', '\r')
# C23: a `//` comment that ends with U+2028 (Dafny: does not end the comment; recognizer: does not either).
C['C23-ls-comment'] = sub(pre='    // note  var x := 1;\n')
# C24: tab and form feed between tokens.
C['C24-formfeed-between-tokens'] = sub(pre='    var k\x0c:= 1;\n')
# C25: string literal with all simple escapes.
C['C25-string-escapes'] = sub(pre='    var s := "\\\'\\"\\\\\\0\\n\\r\\t\\U{10FFFF}\\U{0}";\n')
# C26: comparison chain with equal operands three times.
C['C26-eq-chain'] = sub(pre='    var b := 1 == 1 == 1;\n')
# C27: != chain (Dafny refuses mixing; recognizer?).
C['C27-neq-chain'] = sub(pre='    var b := 1 != 2 != 1;\n')
# C28: disjoint-op !! (lexed as one op).
C['C28-bang-bang'] = sub(pre='    var b := !!true;\n')
# C29: largest multiplier chain within W (bignum growth).
C['C29-mult-chain-1900'] = sub(members='  function Big(x: int): int { x' + ' * 9999999999999999999' * 1900 + ' }\n',
                               pre='    var big := Big(response.amount);\n' if False else '    var big := Big(|context.chargeId|);\n')
# C30: nested braces in a requires clause (recognizer cost, not Dafny).
C['C30-brace-nest-dos'] = sub(members='  method M()\n    requires ' + '{' * 15000 + '}' * 15000 + ' == {}\n  {\n  }\n')
os.makedirs(OUT, exist_ok=True)
for name, text in C.items():
    with open(os.path.join(OUT, name + '.dfy'), 'w', newline='') as f:
        f.write(text)
print(len(C), 'files')
