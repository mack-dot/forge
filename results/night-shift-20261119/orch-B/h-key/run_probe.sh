#!/bin/bash
# LIGHT probe (one suite copy without the dispatcher section; h-minter2 tool, h-key paths). usage: run_probe.sh <tree> <core> <label>
H=<REPO>/results/night-shift-20261119/orch-B/h-key; T=$1; C=$2; L=$3
free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}; [ "$free" -ge 512 ] || { echo "STOP swap $free"; exit 75; }
python3 <REPO>/results/night-shift-20261119/orch-B/h-minter2/b/make_probe.py $T/tests/refund-finality/suite.ts $T/tests/refund-finality/probe_h2.ts
rm -rf $H/runs/$L; mkdir -p $H/runs
{ date -u +%FT%TZ; pmset -g batt | head -1; /usr/sbin/sysctl -n vm.swapusage; echo "tree=$T core=$C"; } > $H/logs/probe-$L.meta
cd $T || exit 9
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/tmp timeout 300 node --import tsx tests/refund-finality/probe_h2.ts $H/runs/$L $C > $H/logs/probe-$L.stdout 2> $H/logs/probe-$L.stderr
rc=$?; echo "exit $rc" >> $H/logs/probe-$L.meta; echo "$L exit $rc"; rm -f $T/tests/refund-finality/probe_h2.ts; grep '^FAIL' $H/logs/probe-$L.stdout; tail -1 $H/logs/probe-$L.stdout
