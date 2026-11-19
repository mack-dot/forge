// c13-gate-js probe 3: underscore in \U{..} and \u escapes under the default --unicode-char.
module Probe3 {
  predicate Q17() { "\U{1_F600}" == "\U{1F600}" }
  predicate Q33() { "A" == "A" }
  predicate Q34() { 'A' == 'A' }
  lemma Check() { assert Q17(); assert Q33(); assert Q34(); }
}
