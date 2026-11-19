#!/usr/bin/env python3
"""c13-gate-js: match-flattening blow-up generator. Usage: gen_match.py K BODY OUT.dfy
Scrutinee: a K-tuple of the out-parameter `decision` (kind Decision, tree 0 -> T = 1 + K <= 32; Dafny tuples <= 20).
Rows r1..rK: row i has the constructor pattern `Rejected` in column K+1-i and `_` elsewhere; then `case _`.
Row r1's body is BODY terms `1 + 1 + ...` (counted ONCE by rule 3's W; duplicated by a decision tree)."""
import sys
k, body, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
rows = []
for i in range(1, k + 1):
    col = k + 1 - i
    pat = ', '.join('Rejected' if c == col else '_' for c in range(1, k + 1))
    rhs = ' + '.join(['1'] * body) if i == 1 else str(i)
    rows.append('      case (%s) => y := %s;' % (pat, rhs))
src = '''include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
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
''' % (', '.join(['decision'] * k), '\n'.join(rows))
open(out, 'w').write(src)
