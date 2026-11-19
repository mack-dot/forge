#!/bin/bash
E=/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-subset3; B=$E/..
for n in Y02-if-tower-40 Y03-match-nest-20 Y07-helper-fanout-2x3 Y13-length-of-input Y14-string-compare-chain Y15-large-int-compare Y17-ghost-method-loop-huge Y24-addition-doubling-400 Y25-literal-multiplier-chain-300 Y28-set-display-in-if-expression Y34-tuple-helper-equality Y42-long-literals-display Y45-if-statement-tower-30 Y50-assert-hides-statement; do
  sh $E/tools/dv3.sh $E/subs/hostile/$n.dfy 1 verify
  sh $E/tools/dv3.sh $E/subs/hostile/$n.dfy 1 translate
done
for n in P01-js-locals P02-js-members P03-js-proto-hasown; do sh $E/tools/dv3.sh $E/subs/probe/$n.dfy 1 translate; done
sh $E/tools/dv3.sh $B/e-totality/subs/hostile/HV15-ghost-method-with-loop.dfy 1 translate
echo BATCH1-DONE
