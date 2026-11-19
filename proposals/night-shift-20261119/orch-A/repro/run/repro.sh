#!/bin/zsh
# W-repro driver. Same-machine reproduction of tonight's Route A theory chain from the sources committed on
# branch nightshift/A-proof (head dae1b93e0e5ce5c59feefd699497c125d355d3ee). See REPRO_PLAN.md.
# Runs ONE case at a time, in dependency order. Stops at the first case whose actual exit is not 0 or whose
# completion marker is missing. Never edits a source. Start only when the orchestrator gives the HOL slot.
# Usage: ./repro.sh [first-case]     (first-case: resume from that case; earlier cases must already exist)
cd ${0:A:h}
RUN=${0:A:h}
LOG=$RUN/repro-driver.log
CASES=(
  "L1-0001 600 deps-L1.txt"
  "L2-0003 1600 deps-L2.txt"
  "L2b-0003 1500 deps-L2b2.txt"
  "L2c-0001 1500 deps-L2c.txt"
  "PF-0004 600 deps-L1.txt"
  "PX-0001 600 deps-PX.txt"
  "LO-0006 900 deps-L1.txt"
  "LE-0004 1200 deps-LE.txt"
  "contract-0001 1200 LINK"
  "MF-0002 900 deps-MF2.txt"
  "MG-0001 900 deps-MG.txt"
  "L2d-0001 1500 deps-MG.txt"
  "E1-0003 600 deps-L1.txt"
  "EF-0001 600 deps-ES.txt"
  "EE-0001 1500 deps-EE.txt"
  "R6base-0001 900 deps-R6x.txt"
  "R6ffi-0002 3600 deps-R6ffi.txt"
  "R6w-0004 3600 deps-R6w.txt"
)
say() { echo "$(date -u +%FT%TZ) $*" | tee -a $LOG; }

waitslot() {  # the queue.sh rule, for the link case that does not go through queue.sh
  local n=0 sw mf
  while true; do
    sw=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/')
    mf=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/')
    if { [[ $sw -ge 1024 ]] || { [[ $mf -ge 40 ]] && [[ $sw -ge 512 ]]; }; } && ! pmset -g batt | head -1 | grep -q Battery; then return 0; fi
    n=$((n+1)); [[ $n -ge 480 ]] && { say "WAIT_GAVE_UP swap_free=$sw"; return 1; }
    [[ $((n % 10)) -eq 1 ]] && say "WAIT swap_free=$sw memory_free=$mf"
    sleep 30
  done
}

check() {  # <case-folder> <marker>
  local f=$1/command.json
  [[ -f $f ]] || { say "STOP $1: no command.json"; return 1; }
  python3 -I -c "import json,sys;d=json.load(open(sys.argv[1]));ok=d['actual_exit']==0 and sys.argv[2] in d['markers'];print('actual_exit',d['actual_exit'],'markers',d['markers'],'cpu',d['child_user_cpu_seconds'],'wall',d['wall_seconds']);sys.exit(0 if ok else 1)" $f $2 | tee -a $LOG
  return ${pipestatus[1]}
}

started=0; [[ -z $1 ]] && started=1
for spec in $CASES; do
  a=(${=spec}); c=$a[1]; cpu=$a[2]; deps=$a[3]
  [[ $started -eq 0 && $c == $1 ]] && started=1
  [[ $started -eq 0 ]] && continue
  if pgrep -f 'cakeml-heap|arm8-heap|cake_compile_heap|bin/hol |poly-install|bin/poly' > /dev/null; then say "STOP before $c: another HOL/poly process runs"; exit 98; fi
  [[ -e /Users/mackianni/forge/results/night-shift-20261119/locks/heavy.lock ]] && { say "STOP before $c: locks/heavy.lock exists"; exit 95; }
  # resume 2026-11-19 (orchestrator, owner amendment in PROTOCOL.md): power state no longer blocks a start in this driver
  # (queue.sh and nightshift-run.sh are unchanged runner copies and still wait for / refuse battery power). Disk rule added.
  dfree=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [[ $dfree -lt 30 ]] && { say "STOP before $c: disk free ${dfree} GiB < 30"; exit 94; }
  say "BEGIN $c cpu=$cpu deps=$deps"
  if [[ $deps == LINK ]]; then
    waitslot || exit 1
    say "LINK_PRESTATE $(pmset -g batt | head -1 | tr -d "\t") swap_free_mib=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/') memory_free_percent=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/') ALLOW_SWAP=1 (orchestrator permission)"
    ALLOW_SWAP=1 bash $RUN/link/go.sh H1 contract-0001 > $RUN/link/contract-0001.go.log 2>&1; rc=$?
    say "go.sh H1 exit $rc"
    check $RUN/link/contract-0001 EXPORTED_CONTRACT_COMPLETE || { say "STOP after $c"; exit 1; }
  else
    try=1
    while true; do
      ./queue.sh repro-$c "$c $cpu $deps"; rc=$?
      say "queue exit $rc; $(tail -1 $c.go.log) (try $try)"
      check $RUN/$c EXACT_COMPLETE && break
      if grep -q 'Run out of store' $c/stderr.log 2>/dev/null && [[ $try -lt 3 ]]; then
        n=1; while [[ -e $c.fail-$n ]]; do n=$((n+1)); done
        mv $c $c.fail-$n
        for s in go.log hashes.json run.json used-files.pre.txt used-files.post.txt; do [[ -e $c.$s ]] && mv $c.$s $c.fail-$n.$s; done
        [[ -e queue-repro-$c.log ]] && mv queue-repro-$c.log queue-repro-$c.fail-$n.log
        [[ -e QUEUE_repro-${c}_DONE ]] && mv QUEUE_repro-${c}_DONE QUEUE_repro-${c}.fail-${n}_DONE
        say "INFRA_STOP $c 'Run out of store' (try $try); moved to $c.fail-$n*; wait 120 s, then try again"
        sleep 120; try=$((try+1)); continue
      fi
      say "STOP after $c"; exit 1
    done
  fi
done
say "ALL_DONE"
