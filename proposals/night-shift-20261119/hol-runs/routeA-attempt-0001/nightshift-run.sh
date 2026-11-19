#!/bin/zsh
# Night-Shift Orchestrator A wrapper: pre-check, then go-routeA.sh (or run_case.py directly when no deps file is given).
# Usage: ./nightshift-run.sh <case> <cpu-seconds> [deps-file]
cd ${0:A:h}
c=$1; cpu=$2; deps=$3
{
  date -u +%FT%TZ; pmset -g batt | head -1; sysctl -n vm.swapusage; memory_pressure | tail -1
  if pmset -g batt | head -1 | grep -q Battery; then echo "PRECHECK_REFUSED battery"; echo "go exit 97"; exit 97; fi
  if pgrep -f 'cake_compile_heap|arm8-heap|cakeml-heap' >/dev/null; then echo "PRECHECK_REFUSED other hol"; echo "go exit 98"; exit 98; fi
  if [[ -n $deps ]]; then
    FORGE_CPU_SECONDS=$cpu ./go-routeA.sh $c $c.sml $deps; rc=$?
  else
    FORGE_CPU_SECONDS=$cpu python3 -I -B run_case.py $c $c.sml > $c.run.json; rc=$?; echo "exit $rc"
    python3 -c "import json;d=json.load(open('$c/command.json'));print('actual_exit',d['actual_exit'],'wall',d['wall_seconds'],'cpu',d['child_user_cpu_seconds'],'rss_mib',d['child_max_rss_bytes']//2**20,d['markers'],'inputs_unchanged_after',d['inputs_unchanged_after'])"
    tail -c 600 $c/stderr.log
    grep -n "^CHECKED\|^TACTIC_\|^OPTIONAL_\|^CONTROL\|^UNEXPECTED\|^STATEMENT_TYPECHECKS\|^CLOSURE\|COMPLETE\|^LEMMA_FAILED\|^SHOW\|^  GOAL\|^STORED\|^DEFINITION\|rror\|xception" $c/stdout.log | cut -c1-260 | tail -80
  fi
  echo "go exit $rc"
} > $c.go.log 2>&1
