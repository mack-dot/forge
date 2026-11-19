#!/bin/bash
# Night shift 2026-11-19, Orchestrator B. Serialized Dafny runner (dafny.lock, atomic mkdir).
# Usage: dafny_locked.sh OWNER WORKDIR LOGFILE TIMEOUT_SECONDS <dafny subcommand and args...>
# It adds NO verifier options: the caller passes them. Recommended gate options:
#   verify --solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects FILE.dfy
# Exit codes: the Dafny exit code; 75 = refused (battery or swap free < 1024 MiB); 76 = lock wait expired;
# 124 = timeout (Dafny killed). The log ends with a line "exit N". The lock is removed in every exit path.
set -u
ROOT=<REPO>
DAFNY=$ROOT/.toolchain/dafny-4.11.0/dafny/dafny
export Z3=$ROOT/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
LOCK=$ROOT/results/night-shift-20261119/locks/dafny.lock
OWNER=$1; WORKDIR=$2; LOG=$3; TMO=$4; shift 4
mkdir -p "$(dirname "$LOG")"
# FIFO queue (added 08:19Z: one worker's loop starved the others). A ticket per call; the oldest live ticket goes first.
QDIR=$ROOT/results/night-shift-20261119/locks/dafny.queue; mkdir -p "$QDIR"
TICKET="$QDIR/$(date +%s)-$$-$RANDOM"; echo $$ > "$TICKET"
trap 'rm -f "$TICKET"' EXIT
sleep 8   # lets callers of the earlier script version (5 s poll, no ticket) take the lock first
waited=0
while :; do
  first=""
  for t in $(ls "$QDIR" | sort); do
    p=$(cat "$QDIR/$t" 2>/dev/null)
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then first="$QDIR/$t"; break; else rm -f "$QDIR/$t"; fi
  done
  if [ "$first" = "$TICKET" ] && mkdir "$LOCK" 2>/dev/null; then break; fi
  sleep 2; waited=$((waited+2))
  if [ $waited -ge 3600 ]; then echo "lock wait expired; holder: $(cat $LOCK/owner 2>/dev/null)" | tee -a "$LOG"; echo "exit 76" >> "$LOG"; exit 76; fi
done
trap 'rm -rf "$LOCK"; rm -f "$TICKET"' EXIT
echo "$OWNER" > $LOCK/owner; echo $$ > $LOCK/pid; echo "$*" > $LOCK/cmd; date -u +%FT%TZ > $LOCK/start
batt=$(pmset -g batt | head -1)
swapfree=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/')
{ echo "# owner=$OWNER start=$(date -u +%FT%TZ) cwd=$WORKDIR"; echo "# power: $batt"; echo "# swap free MiB: $swapfree"; echo "# dafny: $($DAFNY --version)"; echo "# cmd: dafny $*"; } > "$LOG"
case "$batt" in *"AC Power"*) ;; *) echo "refused: not on AC power" >> "$LOG"; echo "exit 75" >> "$LOG"; exit 75;; esac
# A run with TIMEOUT_SECONDS <= 90 is a LIGHT check (PROTOCOL: not an expensive Dafny run): floor 400 MiB.
# Every other run is a heavy step: floor 1024 MiB.
floor=1024; [ "$TMO" -le 90 ] && floor=400
if [ "$swapfree" -lt $floor ]; then echo "refused: swap free $swapfree < $floor MiB" >> "$LOG"; echo "exit 75" >> "$LOG"; exit 75; fi
cd "$WORKDIR" || { echo "exit 77" >> "$LOG"; exit 77; }
/usr/bin/time -l "$DAFNY" "$@" >> "$LOG" 2>&1 &
pid=$!
( sleep "$TMO"; pkill -P $pid 2>/dev/null; kill $pid 2>/dev/null; echo "TIMEOUT after $TMO s" >> "$LOG"; touch "$LOG.timeout" ) &
watch=$!
wait $pid; code=$?
kill $watch 2>/dev/null; pkill -P $watch 2>/dev/null
if [ -e "$LOG.timeout" ]; then code=124; rm -f "$LOG.timeout"; fi
echo "# end=$(date -u +%FT%TZ)" >> "$LOG"
echo "exit $code" >> "$LOG"
exit $code
