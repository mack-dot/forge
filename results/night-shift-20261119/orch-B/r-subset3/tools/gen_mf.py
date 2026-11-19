#!/usr/bin/env python3
"""gen_mf.py K OUT: match statement on a K-tuple; row i has literal 0 at column K-1-i (late columns first).
Each split on an early column copies all later-column rows into both branches (MatchFlattener)."""
import sys
k, out = int(sys.argv[1]), sys.argv[2]
cols = ', '.join(['context.original'] * k)
rows = []
for i in range(k):
    c = k - 1 - i
    pat = ', '.join('0' if j == c else '_' for j in range(k))
    rows.append('      case (%s) => y := %d;' % (pat, i + 1))
src = '''include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := 0;
    match (%s) {
%s
      case _ => y := 0;
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
''' % (cols, '\n'.join(rows))
open(out, 'w').write(src)
