#!/bin/bash
# LIGHT probe (one suite copy without the dispatcher section). usage: run_probe.sh <tree> <core> <label>
H=<REPO>/results/night-shift-20261119/orch-B/h-minter2/b; T=$1; C=$2; L=$3
rm -rf $H/runs/$L; mkdir -p $H/runs
{ date -u +%FT%TZ; pmset -g batt | head -1; sysctl -n vm.swapusage; echo "tree=$T core=$C"; } > $H/logs/$L.meta
cd $T || exit 9
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/../home LANG=C TMPDIR=$H/../home timeout 300 node --import tsx tests/refund-finality/probe_h2.ts $H/runs/$L $C > $H/logs/$L.stdout 2> $H/logs/$L.stderr
rc=$?; echo "exit $rc" >> $H/logs/$L.meta; echo "$L exit $rc"; grep '^FAIL' $H/logs/$L.stdout; tail -1 $H/logs/$L.stdout
