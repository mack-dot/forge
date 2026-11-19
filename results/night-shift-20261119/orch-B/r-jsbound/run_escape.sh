#!/bin/bash
# Usage: run_escape.sh FILE.js PROOF_NAME [CASE]. Runs run.sh; exit 1 when the checker ACCEPTs and the real call wrote
# runs/PROOF_NAME (code outside the module ran: require('fs')), or when run.sh itself reports a break.
E=<REPO>/results/night-shift-20261119/orch-B/r-jsbound; cd $E
rm -f runs/$2; ./run.sh $1 ${3:-elig} 2; c=$?
[ $c -eq 2 ] && exit 2
if [ -f runs/$2 ]; then echo "outside code ran: runs/$2 = $(cat runs/$2)"; echo "CLAIM BROKEN -> exit 1"; exit 1; fi
exit $c
