#!/bin/bash
# baselines.sh (h-judges2): the four baseline runs of the rebuilt regress judge, one after another.
D=<REPO>/results/night-shift-20261119/orch-B/h-judges2; K=$(cat $D/known_merged.txt); M=$D/merged/ts/refund-finality
V=<REPO>/results/night-shift-20261119/orch-B/p-adopt2/export/ts/refund-finality
$D/rj.sh $D/tree $D/logs/base-merged-known.log tests/refund-finality/regress/run.ts $M/sink.ts $M/dispatcher.ts --expect-fail $K; echo "merged, eight known ids expected: exit=$?"
$D/rj.sh $D/tree $D/logs/base-merged-nolist.log tests/refund-finality/regress/run.ts $M/sink.ts $M/dispatcher.ts; echo "merged, no list: exit=$?"
$D/rj.sh $D/tree $D/logs/base-head-empty.log tests/refund-finality/regress/run.ts ts/refund-finality/sink.ts ts/refund-finality/dispatcher.ts; echo "head 74fb70eb, empty list: exit=$?"
$D/rj.sh $D/tree $D/logs/base-v6-x6z1.log tests/refund-finality/regress/run.ts $V/sink.ts $V/dispatcher.ts --expect-fail X6-Z1-zero-row-deleted-recommitted; echo "v6 draft, X6-Z1 expected: exit=$?"
for f in base-merged-known base-merged-nolist base-head-empty base-v6-x6z1; do echo "$f: $(grep '^# verdicts' $D/logs/$f.log)"; done
