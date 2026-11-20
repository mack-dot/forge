include "RefundLogSpec.dfy"
include "../../impl/Refund.dfy"

// One module that refines the proposed specification RefundLogSpec, for the clearing tool only: the
// approved stateless module is bound to the approved implementation impl/Refund.dfy (unchanged), and the
// specified decision returns Step. It shows that the specification can be met. It is NOT an engine and
// NOT a verifier. NOT approved. end_to_end=false.
module RefundLogByStep refines RefundLogSpec {
  import R = Refund

  method Decide(s: LedgerState, q: RefundRequest) returns (r: Option<LedgerState>)
  {
    r := Step(s, q);
  }
}
