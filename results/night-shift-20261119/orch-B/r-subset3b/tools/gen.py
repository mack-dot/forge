#!/usr/bin/env python3
"""Probe generator (r-subset3b). Template: Assess authorizes iff Eligible(...) && FACT. FACT verifies true,
so a compiled run on an eligible input must print Authorized; Rejected or an exception is a mismatch."""
import os, sys
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = '''include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
%(helpers)s
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
%(pre)s
    if Eligible(context, response) && %(fact)s {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
'''
def write(sub, name, helpers='', pre='', fact='true', raw=None):
    p = os.path.join(D, 'subs', sub, name + '.dfy')
    text = raw if raw is not None else T % dict(helpers=helpers, pre=pre, fact=fact)
    open(p, 'w', newline='').write(text)
    return p

JS = '''length name caller arguments apply call bind toString valueOf hasOwnProperty isPrototypeOf __proto__
constructor default then Symbol undefined NaN Infinity globalThis process Buffer BigNumber _dafny _module Refund
RefundSpec __default Companion exports module require eval await yield static get set async of let enum
implements package interface private public protected super this null true false new delete typeof void in
instanceof with debugger'''.split()

if __name__ == '__main__':
    what = sys.argv[1]
    if what == 'names':
        for n in JS:
            write('names', 'NF-' + n.strip('_') + ('' if n[0] != '_' else '_u'),
                  helpers='  function %s(x: int): int { x + 1 }' % n, fact='%s(1) == 2' % n)
            write('names', 'NC-' + n.strip('_') + ('' if n[0] != '_' else '_u'),
                  helpers='  const %s: int := 7' % n, fact='%s == 7' % n)
            write('names', 'NM-' + n.strip('_') + ('' if n[0] != '_' else '_u'),
                  helpers='  method %s(x: int) returns (y: int) ensures y == x + 1 { y := x + 1; }' % n,
                  pre='    var q := %s(1);' % n, fact='q == 2')
            write('names', 'NL-' + n.strip('_') + ('' if n[0] != '_' else '_u'),
                  pre='    var %s := 3;' % n, fact='%s == 3' % n)
