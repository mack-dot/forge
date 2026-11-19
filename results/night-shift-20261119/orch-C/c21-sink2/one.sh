#!/bin/bash
<REPO>/results/night-shift-20261119/orch-C/c21-sink2/run.sh <SCRATCH>/redteam-C/fix-88ae6cbf/tests/refund-finality/regress/$1 <SCRATCH>/redteam-C/fix-88ae6cbf <REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs > <REPO>/results/night-shift-20261119/orch-C/c21-sink2/logs/b-$1.log 2>&1; echo "$1 exit=$?"
