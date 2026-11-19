#!/bin/zsh
# Orchestrator A: second runs after the path fix in go.sh (first runs: setup error, `.hol/objs/.hol/objs`; logs *.setup-error-1.go.log).
# Usage: ./linkq2.sh "CASE folder" ...   (same rule checks as linkq.sh)
cd ${0:A:h}
for spec in "$@"; do
  a=(${=spec}); c=$a[1]; n=0
  while true; do
    sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/'); mf=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/')
    if { [[ $sw -ge 1024 ]] || { [[ $mf -ge 40 ]] && [[ $sw -ge 512 ]]; }; } \
       && ! pgrep -f 'cake_compile_heap|arm8-heap|cakeml-heap' >/dev/null; then break; fi
    n=$((n+1)); [[ $n -ge 480 ]] && { echo "$(date -u +%FT%TZ) GAVE_UP before $c" >> linkq-r.log; date -u > LINKQ_r_DONE; exit 1; }
    sleep 20
  done
  { echo "$(date -u +%FT%TZ)"; echo "START_STATE swap_free_mib=$sw memory_free_percent=$mf"; ALLOW_SWAP=1 bash ./go.sh $a; rc=$?; echo "go exit $rc"; } > $c.go.log 2>&1
  echo "$(date -u +%FT%TZ) END $c $(tail -1 $c.go.log)" >> linkq-r.log
done
date -u > LINKQ_r_DONE
