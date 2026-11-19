#!/bin/bash
# HEAVY: the FULL Slice 1 suite on one tree. Tries at most 10 times, one minute apart, to start:
# refuses while locks/hol.lock exists or a HOL process runs, or swap free < 512 MiB; takes locks/heavy.lock with mkdir
# (owner h-suite), removes it by trap; holds it at most 3 minutes (timeout 170 s on the run).
# Usage: run_heavy.sh <tree> <label>
H=<REPO>/results/night-shift-20261119/orch-B/h-suite; T=$1; L=$2
LK=<REPO>/results/night-shift-20261119/locks
CORE=<REPO>/results/night-shift-20261119/orch-B/h-minter2/build/issueauth.cjs
M=$H/logs/$L.meta; : > $M
for try in 1 2 3 4 5 6 7 8 9 10; do
  why=""
  [ -e $LK/hol.lock ] && why="hol.lock exists"
  pgrep -f 'bin/hol' >/dev/null && why="$why; a HOL process runs"
  free=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
  [ "${free:-0}" -lt 512 ] && why="$why; swap free ${free} MiB < 512"
  if [ -z "$why" ] && mkdir $LK/heavy.lock 2>/dev/null; then
    echo "owner h-suite pid $$ $(date -u +%FT%TZ)" > $LK/heavy.lock/owner
    trap 'rm -rf $LK/heavy.lock' EXIT INT TERM
    { echo "try $try start $(date -u +%FT%TZ) tree=$T core=$CORE"; pmset -g batt | head -1; sysctl -n vm.swapusage; } >> $M
    cd $T || exit 9
    /usr/bin/time -p env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C timeout 170 node --import tsx tests/refund-finality/suite.ts $H/runs/$L $CORE > $H/logs/$L.stdout 2> $H/logs/$L.stderr
    rc=$?
    echo "end $(date -u +%FT%TZ) exit $rc" >> $M
    rm -rf $LK/heavy.lock; trap - EXIT INT TERM
    echo "$L exit $rc"; grep '^FAIL' $H/logs/$L.stdout; tail -1 $H/logs/$L.stdout; exit $rc
  fi
  [ -z "$why" ] && why="heavy.lock held: $(cat $LK/heavy.lock/owner 2>/dev/null)"
  echo "try $try $(date -u +%FT%TZ) refused: $why" >> $M
  [ $try -lt 10 ] && sleep 60
done
echo "NOT RUN after 10 tries" >> $M; echo "$L NOT RUN"; exit 75
