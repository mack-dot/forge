#!/bin/bash
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-totality
sh $E/tools/dafny_variant.sh correct CV13-ghost-loop-in-lemma verify 2
for n in HV01-mutual-recursion-three HV11-match-huge-literal-admissible-size HV22-big-literal-multiplier-chain HV23-set-display-in-guard HV26-set-display-guard-then-hidden-loop HV10-tuple-dag-equality; do
  sh $E/tools/dafny_variant.sh hostile $n verify 2; done
echo ALLDONE
