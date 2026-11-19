#!/bin/bash
cd <REPO>/results/night-shift-20261119/orch-B/r-jsbound
for f in T2b-set-equality-inline D1-checker-text-cost; do ./tr.sh src/$f.dfy 1; done
for f in T2b-set-equality-inline D1-checker-text-cost; do ./vf.sh src/$f.dfy 1; done
echo BATCH2 DONE
