#!/bin/bash
# Orchestrator B: heavy window 9: hardened sink: Slice 1 suite (pristine and hardened), differential against the V6 core, kill storm, 20,000-row measurement. PREPARED; power state is logged, not a gate (POWER AMENDMENT).
set -u
R=<REPO>; NS=$R/results/night-shift-20261119; B=$NS/orch-B; L=$NS/locks
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
echo "# power: $(pmset -g batt | head -1)"
sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if [ "$sw" -lt 512 ] || { [ "$sw" -lt 1024 ] && [ "${mf:-0}" -lt 40 ]; }; then echo "refused: swap $sw MiB, memory free $mf %"; exit 75; fi
av=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}'); [ "$av" -lt 20 ] && { echo "refused: disk $av GiB"; exit 75; }
mkdir $L/heavy.lock || { echo "heavy.lock held"; exit 76; }
trap 'rm -rf $L/heavy.lock' EXIT
echo orch-B > $L/heavy.lock/owner; echo $$ > $L/heavy.lock/pid; date -u +%FT%TZ > $L/heavy.lock/start
echo "# start $(date -u +%FT%TZ) swap free $sw MiB memory free $mf % disk $av GiB"
SUITE_TIMEOUT_S=600 $B/h-sink/run_suite_h.sh 1
echo "# run_suite_h exit $? end $(date -u +%FT%TZ)"
$B/h-sink/heavy_h.sh $B/heavy/h-1 all
echo "# heavy_h exit $? end $(date -u +%FT%TZ)"
