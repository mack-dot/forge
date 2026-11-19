#!/bin/bash
# usage: run_regress.sh <tree> <label> [files...]  (light, sequential). Writes logs/<label>/<name>.out and a summary.
H=<REPO>/results/night-shift-20261119/orch-B/h-key; T=$1; L=$2; shift 2
CORE=<REPO>/results/night-shift-20261119/orch-B/h-minter2/build/issueauth.cjs
free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
[ "$free" -ge 512 ] || { echo "STOP: swap free ${free} MiB < 512"; exit 75; }
df -g /System/Volumes/Data | tail -1 | awk '{ if ($4 < 30) { print "STOP: disk"; exit 1 } }' || exit 75
mkdir -p $H/logs/$L; cd $T || exit 9
for f in "$@"; do
  n=$(basename $f .ts)
  if [[ $n == p_* ]]; then args="$T ${PMODE:-a} ${PANCHOR:-none}"; n2="$n-${PMODE:-a}-${PANCHOR:-none}"; else args="$T $CORE"; n2=$n; fi
  env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/tmp ${EXTRA_ENV} timeout 120 node --no-warnings --import tsx $T/tests/refund-finality/regress/$n.ts $args > $H/logs/$L/$n2.out 2>&1
  echo "$n2 exit $?" | tee -a $H/logs/$L/SUMMARY
done
