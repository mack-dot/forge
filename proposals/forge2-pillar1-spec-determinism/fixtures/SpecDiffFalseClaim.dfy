// NEGATIVE CONTROL (U413). A FALSE spec-diff claim: "the specifications agree whenever the NEW one does not accept".
// False at the boundary balance == amount (the old one accepts). Verification MUST FAIL.
include "../SpecDiffFee.dfy"

abstract module SpecDiffFalseClaim {
  import D : SpecDiffFee

  lemma UnchangedWhenNewDoesNotAccept(s: D.O.State, id: int, r: D.O.Request,
                                      n: D.O.State, o: D.O.Outcome, n': D.N.State, o': D.N.Outcome)
    requires D.O.WellFormed(s) && !D.N.IsFreshValid(D.StateN(s), id, D.ReqN(r))
    requires D.PostO(s, id, r, n, o) && D.PostN(D.StateN(s), id, D.ReqN(r), n', o')
    ensures n == s
  {
    D.PostOCases(s, id, r, n, o);
    D.PostNCases(D.StateN(s), id, D.ReqN(r), n', o');
  }
}
