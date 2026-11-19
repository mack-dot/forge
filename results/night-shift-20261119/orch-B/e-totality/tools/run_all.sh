#!/bin/bash
E=<REPO>/results/night-shift-20261119/orch-B/e-totality
for D in correct hostile; do for f in $E/subs/$D/*.dfy; do
  n=$(basename $f .dfy); sh $E/tools/dafny_variant.sh $D $n verify 1
done; done
sh $E/tools/dafny_variant.sh hostile HV15-ghost-method-with-loop translate 1
echo ALLDONE
