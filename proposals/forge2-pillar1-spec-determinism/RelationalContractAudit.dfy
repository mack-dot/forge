// Round 3 task 3 (U430): shared skeleton for the relational spec audits of Pillar I.
// NOT part of the gate. NOT a protected file. An instance gives the types, the predicate Post (the postcondition of
// the specified method, restated) and ONE proof: Deterministic. Everything else is proved here once.
// The link between Post and the method postcondition stays in each instance's wrapper method (ApplyThenPost).
abstract module RelationalContractAudit {
  type Input(!new)      // pre-state together with the request
  type Result(!new)     // post-state together with the outcome
  ghost predicate Valid(i: Input)
  ghost predicate Post(i: Input, r: Result)
    requires Valid(i)

  // Obligation of each instance.
  lemma Deterministic(i: Input, a: Result, b: Result)
    requires Valid(i) && Post(i, a) && Post(i, b)
    ensures a == b

  // Proved once: an allowed result is the only allowed result.
  lemma AtMostOne(i: Input, a: Result)
    requires Valid(i) && Post(i, a)
    ensures forall b: Result :: Post(i, b) ==> b == a
  {
    forall b: Result | Post(i, b)
      ensures b == a
    {
      Deterministic(i, a, b);
    }
  }
}

// Two audited specifications and a way to carry an input of the old one to the new one.
abstract module RelationalSpecDiff {
  import Old : RelationalContractAudit
  import New : RelationalContractAudit

  function Carry(i: Old.Input): New.Input
  ghost predicate Same(a: Old.Result, b: New.Result)

  ghost predicate BothValid(i: Old.Input) { Old.Valid(i) && New.Valid(Carry(i)) }

  // The change does not touch this input: every allowed old result and every allowed new result agree.
  ghost predicate Unchanged(i: Old.Input)
    requires BothValid(i)
  {
    forall a: Old.Result, b: New.Result :: Old.Post(i, a) && New.Post(Carry(i), b) ==> Same(a, b)
  }

  // Proved once: ONE pair of allowed results decides the input. This is the principle behind every boundary witness.
  lemma OnePairDecides(i: Old.Input, a: Old.Result, b: New.Result)
    requires BothValid(i) && Old.Post(i, a) && New.Post(Carry(i), b)
    ensures Unchanged(i) <==> Same(a, b)
  {
    Old.AtMostOne(i, a);
    New.AtMostOne(Carry(i), b);
  }
}
