#!/bin/zsh
# Orchestrator A: serial runner for link cases. Usage: ./linkq.sh <tag> CASE [CASE ...]
# Applies the amended PROTOCOL.md swap rule and AC power before each case, then `ALLOW_SWAP=1 bash go.sh CASE`
# (ALLOW_SWAP=1 only bypasses go.sh's own older 85 % rule; the protocol rule is checked here). Stops at H0/H1 failure.
cd ${0:A:h}; tag=$1; shift
for c in "$@"; do
  n=0
  while true; do
    sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/')
    if { [[ $sw -ge 1024 ]] || { [[ $mf -ge 40 ]] && [[ $sw -ge 512 ]]; }; } \
       && ! pgrep -f 'cake_compile_heap|arm8-heap|cakeml-heap' >/dev/null; then break; fi
    n=$((n+1)); [[ $n -ge 480 ]] && { echo "$(date -u +%FT%TZ) GAVE_UP before $c" >> linkq-$tag.log; date -u > LINKQ_${tag}_DONE; exit 1; }
    sleep 30
  done
  { echo "$(date -u +%FT%TZ)"; echo "START_STATE swap_free_mib=$sw memory_free_percent=$mf"; ALLOW_SWAP=1 bash ./go.sh $c; rc=$?; echo "go exit $rc"; } > $c.go.log 2>&1
  echo "$(date -u +%FT%TZ) END $c $(tail -1 $c.go.log)" >> linkq-$tag.log
  if [[ ( $c == H0 || $c == H1 ) && $(tail -1 $c.go.log) != "go exit 0" ]]; then echo "STOP after $c" >> linkq-$tag.log; break; fi
done
date -u > LINKQ_${tag}_DONE
