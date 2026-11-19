// c13-gate-js probe 4: \u surrogate escapes under the default --unicode-char.
module Probe4 {
  predicate Q36() { |"😀"| == 2 }
  predicate Q37() { "😀" == "\U{1F600}" }
  lemma Check() { assert Q36(); assert Q37(); }
}
