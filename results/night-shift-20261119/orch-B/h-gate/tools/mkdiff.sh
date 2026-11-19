#!/bin/bash
# Regenerates diff/refund-jsbound-combined.diff from gate-new (a = 985f5eaf, b = proposal) and apply-checks it.
H=<REPO>/results/night-shift-20261119/orch-B/h-gate
cp $H/js_bound_check.cjs $H/gate-new/b/gate/refund/js_bound_check.cjs
( cd $H/gate-new && diff -ruN a/gate b/gate | perl -pe 's/^((?:\+\+\+|---) \S+)\t.*/$1/' > $H/diff/refund-jsbound-combined.diff )
git -C <REPO> apply --check $H/diff/refund-jsbound-combined.diff; echo "apply --check exit $?"
shasum -a 256 $H/diff/refund-jsbound-combined.diff $H/js_bound_check.cjs
