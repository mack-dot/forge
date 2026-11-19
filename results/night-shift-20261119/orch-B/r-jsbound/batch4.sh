#!/bin/bash
cd <REPO>/results/night-shift-20261119/orch-B/r-jsbound
./tr.sh src/M1c-live-strings-built-by-doubling.dfy 1
./vf.sh src/M1c-live-strings-built-by-doubling.dfy 1
echo BATCH4 DONE
