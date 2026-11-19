include "SinkCore.dfy"
module W refines SinkCore {
  ghost predicate VerifyTag(c: Claim, t: Tag) { false }
}
