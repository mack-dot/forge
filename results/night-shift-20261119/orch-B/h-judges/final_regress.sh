#!/bin/bash
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-judges; HT=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-sink/tree/ts/refund-finality
K=$(cat $D/known_merged.txt)
$D/rj.sh $D/tree $D/logs/final-merged-baseline.log tests/refund-finality/regress/run.ts ts/refund-finality/sink.ts ts/refund-finality/dispatcher.ts --expect-fail $K; echo "merged baseline exit=$?"
$D/rj.sh $D/tree $D/logs/final-hardened.log tests/refund-finality/regress/run.ts $HT/sink.ts $HT/dispatcher.ts; echo "hardened (empty expect list) exit=$?"
$D/rj.sh $D/tree $D/logs/final-hardened-anchored.log tests/refund-finality/regress/run.ts $HT/sink.ts $HT/dispatcher.ts $D/anchor_hsink.ts; echo "hardened anchored exit=$?"
$D/mutants_regress.sh
