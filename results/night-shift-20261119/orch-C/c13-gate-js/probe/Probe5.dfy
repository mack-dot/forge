// c13-gate-js probe 5: \u surrogate escapes in a STRING under the default --unicode-char.
module Probe5 {
  predicate Q36() { |"😀"| == 2 }
  predicate Q37() { "😀" == "\U{1F600}" }
  predicate Q39() { |"\uD83D"| == 1 }
  lemma Check() { assert Q36(); assert Q37(); assert Q39(); }
}
