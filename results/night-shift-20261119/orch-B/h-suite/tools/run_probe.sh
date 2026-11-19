#!/bin/bash
# LIGHT probe run (seconds, one issuer process). Usage: run_probe.sh <tree> <probe file rel. to tree> <label>
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-suite; T=$1; P=$2; L=$3
CORE=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs
{ date -u +%FT%TZ; pmset -g batt | head -1; sysctl -n vm.swapusage; echo "tree=$T probe=$P core=$CORE"; } > $H/logs/$L.meta
cd $T || exit 9
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C timeout 120 node --import tsx $P $H/runs/$L $CORE > $H/logs/$L.stdout 2> $H/logs/$L.stderr
rc=$?; echo "exit $rc" >> $H/logs/$L.meta; echo "$L exit $rc"; grep '^FAIL' $H/logs/$L.stdout; tail -1 $H/logs/$L.stdout
