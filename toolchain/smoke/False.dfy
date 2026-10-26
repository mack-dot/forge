// Negative control. The real verifier must reject this false postcondition.
lemma FalseArithmetic()
  ensures 1 + 1 == 3
{
}
