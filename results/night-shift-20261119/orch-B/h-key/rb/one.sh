#!/bin/bash
# one.sh <label> <test file name> [args after <tree>]: one light run on the rebased tree; prints "label exit N".
R=<REPO>/results/night-shift-20261119/orch-B/h-key/rb; T=$R/tree; L=$1; F=$2; shift 2
free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
[ "$free" -ge 512 ] || { echo "$L STOP swap ${free}"; exit 75; }
cd $T && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$R/home LANG=C TMPDIR=$R/tmp timeout 120 node --no-warnings --import tsx $T/tests/refund-finality/regress/$F "$T" "$@" > $R/logs/$L.out 2>&1
c=$?; echo "$L exit $c" | tee -a $R/logs/SUMMARY; exit 0
