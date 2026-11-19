// r-v5 control: the OPPOSITE claim (the middle zero-row deletion is refused). It MUST FAIL to verify.
include "AttackV5.dfy"
module MutantClaimRefused {
  import opened ShellCoreV5
  import opened AttackV5
  lemma ClaimRefused()
    ensures !AuditV5(Ch(1000), Ch(900), D(), 2, 2, 2)
  {
    MiddleZeroDeletionPasses();
  }
}
