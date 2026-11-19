#!/bin/bash
# Light: the JS checker and five mutants over js/ and js-reuse/ (single short Node runs, scrubbed env, 60 s cap each).
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-gate; O=$H/results; mkdir -p $O
for m in none no-loop no-recursion no-load no-shape no-cost; do
  arg=""; [ $m != none ] && arg="--mutant=$m"
  env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/work perl -e 'alarm 60; exec @ARGV' node --max-old-space-size=300 \
     $H/js_bound_check.cjs $arg --work=$H/work $H/js/*.js $H/js-reuse/*.js > $O/check-$m.jsonl
  echo "mutant $m exit $? accepted $(grep -c '"ACCEPT"' $O/check-$m.jsonl) of $(wc -l < $O/check-$m.jsonl)"
done
