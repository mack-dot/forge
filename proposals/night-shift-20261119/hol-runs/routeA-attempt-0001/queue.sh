#!/bin/zsh
# Serial HOL queue of Orchestrator A. Usage: ./queue.sh <tag> "<case> <cpu> [deps]" ...
# Before each case: wait (poll 30 s, at most 4 h) until the amended swap rule holds and AC power; then nightshift-run.sh.
cd ${0:A:h}; tag=$1; shift
for spec in "$@"; do
  a=(${=spec}); n=0
  while true; do
    sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/')
    mf=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/')
    if { [[ $sw -ge 1024 ]] || { [[ $mf -ge 40 ]] && [[ $sw -ge 512 ]]; }; } && ! pmset -g batt | head -1 | grep -q Battery; then break; fi
    n=$((n+1)); [[ $n -ge 480 ]] && { echo "$(date -u +%FT%TZ) QUEUE_GAVE_UP before $a[1] swap_free=$sw" >> queue-$tag.log; date -u > QUEUE_${tag}_DONE; exit 1; }
    [[ $((n % 10)) -eq 1 ]] && echo "$(date -u +%FT%TZ) WAIT before $a[1] swap_free=$sw" >> queue-$tag.log
    sleep 30
  done
  echo "$(date -u +%FT%TZ) START $a[1] swap_free=$sw" >> queue-$tag.log
  ./nightshift-run.sh $a
  echo "$(date -u +%FT%TZ) END $a[1] $(tail -1 $a[1].go.log)" >> queue-$tag.log
done
date -u > QUEUE_${tag}_DONE
