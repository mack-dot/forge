#!/bin/zsh
# Night-Shift Orchestrator A wrapper: pre-check, then go-routeA.sh (or run_case.py directly when no deps file is given).
# Usage: ./nightshift-run.sh <case> <cpu-seconds> [deps-file]
cd ${0:A:h}
c=$1; cpu=$2; deps=$3
{
  date -u +%FT%TZ; pmset -g batt | head -1; sysctl -n vm.swapusage; memory_pressure | tail -1
  if pmset -g batt | head -1 | grep -q Battery; then echo "PRECHECK_REFUSED battery"; echo "go exit 97"; exit 97; fi
  # added 2026-11-19T08:50Z: PROTOCOL.md rule "swap free < 1 GB: start no heavy step". Before this line was added, ten cases
  # (PF-0001, E1-0001..0003, E1neg-0001, L2-0002, L2-0003, L2b-0001, LO-0002, LO-0003, PF-0002) started below 1 GB free.
  swfree=$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/')
  # amended rule (PROTOCOL.md, launcher, ~09:00Z): start if swap free >= 1024 MiB, OR (memory free >= 40 % AND swap free >= 512 MiB).
  memfree=$(memory_pressure | tail -1 | sed -E 's/.*: ([0-9]+)%.*/\1/')
  echo "START_STATE swap_free_mib=$swfree memory_free_percent=$memfree"
  if ! { [[ $swfree -ge 1024 ]] || { [[ $memfree -ge 40 ]] && [[ $swfree -ge 512 ]]; }; }; then echo "PRECHECK_REFUSED swap free $swfree MiB memory free $memfree %"; echo "go exit 96"; exit 96; fi
  if pgrep -f 'cake_compile_heap|arm8-heap|cakeml-heap' >/dev/null; then echo "PRECHECK_REFUSED other hol"; echo "go exit 98"; exit 98; fi
  # added after review A32: files that the case source reads with `use` by absolute path are hashed BEFORE the run
  # (the runner hashes only the command-line inputs); the same list is hashed again after the run.
  used=($(grep -o '"/Users/[^"]*\.sml"' $c.sml | tr -d '"' | sort -u)); dirs=($(grep -o '"/Users/[^"]*/"' $c.sml | tr -d '"' | sort -u))
  for d in $dirs; do used+=($d*.sml(N)); done
  : > $c.used-files.pre.txt; for f in ${(u)used}; do [[ -f $f ]] && shasum -a 256 $f >> $c.used-files.pre.txt; done
  echo "USED_FILES_PRE $(wc -l < $c.used-files.pre.txt | tr -d ' ') $(shasum -a 256 $c.used-files.pre.txt | cut -c1-16)"
  if [[ -n $deps ]]; then
    FORGE_CPU_SECONDS=$cpu ./go-routeA.sh $c $c.sml $deps; rc=$?
  else
    FORGE_CPU_SECONDS=$cpu python3 -I -B run_case.py $c $c.sml > $c.run.json; rc=$?; echo "exit $rc"
    python3 -c "import json;d=json.load(open('$c/command.json'));print('actual_exit',d['actual_exit'],'wall',d['wall_seconds'],'cpu',d['child_user_cpu_seconds'],'rss_mib',d['child_max_rss_bytes']//2**20,d['markers'],'inputs_unchanged_after',d['inputs_unchanged_after'])"
    tail -c 600 $c/stderr.log
    grep -n "^CHECKED\|^TACTIC_\|^OPTIONAL_\|^CONTROL\|^UNEXPECTED\|^STATEMENT_TYPECHECKS\|^CLOSURE\|COMPLETE\|^LEMMA_FAILED\|^SHOW\|^  GOAL\|^STORED\|^DEFINITION\|rror\|xception" $c/stdout.log | cut -c1-260 | tail -80
  fi
  : > $c.used-files.post.txt; for f in ${(u)used}; do [[ -f $f ]] && shasum -a 256 $f >> $c.used-files.post.txt; done
  cmp -s $c.used-files.pre.txt $c.used-files.post.txt && echo "USED_FILES_UNCHANGED true" || echo "USED_FILES_UNCHANGED false"
  echo "go exit $rc"
} > $c.go.log 2>&1
