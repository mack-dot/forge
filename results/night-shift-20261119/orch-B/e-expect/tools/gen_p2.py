#!/usr/bin/env python3
"""Generate the Part 2 candidate submissions (e-expect). Each is impl/Refund.dfy with one change."""
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / 'p2/subs'
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = ('  method Assess(context: Context, response: ModelResponse)\n'
       '      returns (decision: Decision, plan: seq<RefundIntent>)\n  {\n')
BODY = ('    if Eligible(context, response) {\n'
        '      decision := Authorized(response.amount, response.reason);\n'
        '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n'
        '    } else {\n      decision := Rejected;\n      plan := [];\n    }\n  }\n')
KEY = 'response.Candidate? && response.amount == 123456789'


def make(name, pre_method='', in_body='', tail='}\n', raw=None):
    data = raw if raw is not None else (HEAD + pre_method + SIG + in_body + BODY + tail)
    (OUT / (name + '.dfy')).write_bytes(data.encode('utf-8') if isinstance(data, str) else data)

# ---- H: run-time failure without the token `expect` (resource class) ----
make('H01-such-that-enumeration-hang',
     in_body='    if %s {\n      var k: int :| k >= 1000000000000000000;\n      var unused := k;\n    }\n' % KEY)
make('H01b-such-that-modulus-hang',
     in_body='    if %s {\n      assert 0 <= 999999999999999999 && 999999999999999999 %% 1000000000000000000 == 999999999999999999;\n'
             '      var k: int :| 0 <= k && k %% 1000000000000000000 == 999999999999999999;\n      var unused := k;\n    }\n' % KEY)
make('H02-exponential-recursion-hang',
     pre_method='  function Slow(n: nat): nat { if n == 0 then 0 else Slow(n - 1) + Slow(n - 1) }\n\n',
     in_body='    if %s {\n      var z := Slow(200);\n    }\n' % KEY)
make('H03-seq-comprehension-alloc',
     in_body='    if %s {\n      var s := seq(1000000000000, i => 0);\n    }\n' % KEY)
make('H04-seq-length-2pow32-throws',
     in_body='    if %s {\n      var s := seq(4294967296, i => 0);\n    }\n' % KEY)
# ---- K: hide `expect` from the lexer while Dafny still sees it ----
make('K01-string-backslash-newline',
     in_body='    var s := "a\\\nexpect !(%s); var t := "; var u := "";\n' % KEY)
make('K02-string-bad-unicode-escape',
     in_body='    var s := "\\U{";\n    expect !(%s);\n    var t := "}";\n' % KEY)
make('K03-comment-split-attribute',
     pre_method='  method {/**/:verify false} Halt() ensures false {}\n\n',
     in_body='    if %s { Halt(); }\n' % KEY)
make('K04-isolate-wrapping-attribute',
     pre_method='  method {:isolate_assertions}{:verify false} Halt() ensures false {}\n\n',
     in_body='    if %s { Halt(); }\n' % KEY)
make('K05-eof-line-comment-no-newline', tail='}\n// expect false;')
make('K06-unterminated-block-comment-eof', tail='}\n/* expect false;\n')
make('K07-u0085-line-comment',
     in_body='    // note\u0085expect !(%s);\n' % KEY)
make('K08-nul-in-line-comment',
     in_body='    // note\x00\n    expect !(%s);\n' % KEY)
# ---- B: benign (correct) programs; the ideal verdict is ADMITTED ----
make('B01-identifiers-expected',
     in_body='    var expected := 1;\n    var Expect := 2;\n    var expect_ok := 3;\n    var unexpected := expected + Expect + expect_ok;\n')
make('B02-word-in-comments-strings',
     in_body='    // we expect a decision here\n    /* expect /* nested expect */ expect */\n'
             '    var msg := "expect \\"expect\\" here";\n    var c := \'e\';\n')
make('B03-identifier-prime-expect',
     in_body="    var x'expect := 1;\n")
make('B04-formfeed-comment-word',
     in_body='    // page break\x0c we expect a decision\n')
make('B05-latin1-comment', raw=(HEAD + SIG + '    // caf\xe9\n' + BODY + '}\n').encode('latin-1'))
make('B06-unicode-in-string',
     in_body='    var msg := "na\u00efve \\U{1F600} expect";\n')
print(sorted(p.name for p in OUT.iterdir()))
