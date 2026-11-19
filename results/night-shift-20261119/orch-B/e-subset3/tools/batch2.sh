#!/bin/bash
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-subset3; B=$E/..
for f in $B/e-totality/subs/hostile/HV11-match-huge-literal-admissible-size.dfy $B/e-totality/subs/hostile/HV24-negation-doubling.dfy $B/e-totality/subs/hostile/HV25-tuple-of-helper-tuples.dfy $B/e-subset2/subs/hostile/X33-ls-comment-loop-text.dfy; do
  sh $E/tools/dv3.sh $f 1 translate
done
for n in Y42b-literals-display-16x64; do sh $E/tools/dv3.sh $E/subs/hostile/$n.dfy 1 verify; sh $E/tools/dv3.sh $E/subs/hostile/$n.dfy 1 translate; done
echo BATCH2-DONE
