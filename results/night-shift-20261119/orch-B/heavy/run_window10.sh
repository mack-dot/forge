#!/bin/bash
# Orchestrator B: heavy window 10 (wind-down): the real-kill regression of the sink (h-sink3 wrapper) and the full suite on the branch head.
[ -e <REPO>/results/night-shift-20261119/locks/hol.lock ] && { echo "refused: hol.lock"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: HOL process"; exit 75; }
sw=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if [ "$sw" -lt 512 ] || { [ "$sw" -lt 1024 ] && [ "${mf:-0}" -lt 40 ]; }; then echo "refused: swap $sw MiB, memory free $mf %"; exit 75; fi
mkdir <REPO>/results/night-shift-20261119/locks/heavy.lock || exit 76
trap 'rm -rf <REPO>/results/night-shift-20261119/locks/heavy.lock' EXIT
echo orch-B > <REPO>/results/night-shift-20261119/locks/heavy.lock/owner; date -u +%FT%TZ > <REPO>/results/night-shift-20261119/locks/heavy.lock/start
echo "# start $(date -u +%FT%TZ) $(pmset -g batt | head -1) swap free $sw MiB memory free $mf %"
bash <REPO>/results/night-shift-20261119/orch-B/h-sink3/heavy_kill_NOT_RUN.sh; echo "# kill wrapper exit $? end $(date -u +%FT%TZ)"
cd <SCRATCH>/B-trust && ln -sfn <REPO>/node_modules node_modules
rm -f <REPO>/results/night-shift-20261119/locks/heavy.lock/owner.tmp
