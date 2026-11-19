#!/bin/bash
# rj.sh <cwd tree> <log> <cmd args...>: one light judge run, scrubbed env, pinned Node; appends "exit N".
H=<REPO>/results/night-shift-20261119/orch-B/h-key
T=$1; L=$2; shift 2
free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
[ "$free" -ge 512 ] || { echo "STOP: swap free ${free} MiB" > "$L"; exit 75; }
cd "$T" || exit 3
{ echo "# $(date -u +%FT%TZ) cwd=$T cmd=$*"; pmset -g batt | head -1; /usr/sbin/sysctl -n vm.swapusage; } > "$L"
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home TMPDIR=$H/tmp LANG=C NODE_PATH=<REPO>/node_modules \
  timeout 600 node --no-warnings --import tsx "$@" >> "$L" 2>&1
c=$?; echo "exit $c" >> "$L"; exit $c
