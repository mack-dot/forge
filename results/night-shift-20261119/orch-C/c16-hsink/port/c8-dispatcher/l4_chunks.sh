#!/bin/bash
# Runs l4_chain_search.ts over all 1554 histories in chunks of 200 (each run < 120 s), twice.
D=<SCRATCH>/redteam-C/retarget-608b5165/c8-dispatcher
for i in 1 2; do for a in 0 200 400 600 800 1000 1200 1400; do b=$((a+200)); [ $b -gt 1554 ] && b=1554
  $D/run.sh l4_chain_search.ts $D/work/l4 $a $b > $D/logs/l4-run$i-$a.log 2>&1; echo "l4 run$i [$a,$b) EXIT $? $(tail -1 $D/logs/l4-run$i-$a.log)"; done; done
