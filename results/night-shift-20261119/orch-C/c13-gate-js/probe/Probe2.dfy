// c13-gate-js probe 2: escape forms that the rule-3 lexer admits without checking. Expect parse errors.
module Probe2 {
  predicate Q17() { "\U{1_F600}" == "\U{1F600}" }
  predicate Q32() { "\U{D83D}" != "\U{1F600}" }
  predicate Q33() { "A" == "A" }
  predicate Q34() { 'A' == 'A' }
  predicate Q35() { "\U{110000}" != "A" }
  lemma Check() { assert Q17(); assert Q32(); assert Q33(); assert Q34(); assert Q35(); }
}
