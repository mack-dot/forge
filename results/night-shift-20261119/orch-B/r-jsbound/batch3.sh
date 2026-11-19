#!/bin/bash
cd <REPO>/results/night-shift-20261119/orch-B/r-jsbound
./tr.sh src/M1b-live-strings-in-recursion.dfy 1
./vf.sh src/M1b-live-strings-in-recursion.dfy 1
echo BATCH3 DONE
