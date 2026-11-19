#!/bin/bash
# Orchestrator B: heavy window: the Slice 1 refund-finality suite on two scratch exports (pristine; with the adoption diff).
set -u
R=<REPO>; NS=$R/results/night-shift-20261119; B=$NS/orch-B; L=$NS/locks
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "refused: battery"; exit 75;; esac
sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if [ "$sw" -lt 512 ] || { [ "$sw" -lt 1024 ] && [ "${mf:-0}" -lt 40 ]; }; then echo "refused: swap $sw MiB, memory free $mf %"; exit 75; fi
mkdir $L/heavy.lock || { echo "heavy.lock held"; exit 76; }
trap 'rm -rf $L/heavy.lock' EXIT
echo orch-B > $L/heavy.lock/owner; echo $$ > $L/heavy.lock/pid; date -u +%FT%TZ > $L/heavy.lock/start
echo "# start $(date -u +%FT%TZ) swap free $sw MiB memory free $mf %"
SUITE_TIMEOUT_S=900 $B/p-adopt/run_suite.sh 1
echo "# run_suite exit $? end $(date -u +%FT%TZ)"
