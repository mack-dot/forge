#!/bin/zsh
# Route A runner (worker X7 draft; NOT RUN). Same pattern as records/final-cases/go-e4.sh.
# Usage (from the attempt folder that holds run_case.py, the deps file and the case source):
#   ./go-routeA.sh <case> <source.sml> <deps-file> [extra theory files]
# Example: FORGE_CPU_SECONDS=600 ./go-routeA.sh L1-0001 L1-0001.sml deps-L1.txt
cd ${0:A:h}
deps=("${(@f)$(cat $3)}")
python3 -I -B run_case.py $1 $2 $deps ${@:4} > $1.run.json; rc=$?; echo "exit $rc"
python3 -c "import json;d=json.load(open('$1/command.json'));print('actual_exit',d['actual_exit'],'wall',d['wall_seconds'],'cpu',d['child_user_cpu_seconds'],'rss_mib',d['child_max_rss_bytes']//2**20,d['markers'],'inputs_unchanged_after',d['inputs_unchanged_after'])"
tail -c 600 $1/stderr.log
grep -n "^CHECKED\|^IMPORTED\|^IMPORT_MISMATCH\|^CONTROL\|^UNEXPECTED\|^CLOSURE\|COMPLETE\|^LEMMA_FAILED\|^TEXT_CHECK\|^STATEMENT_\|^SHOW\|^  GOAL\|rror\|xception" $1/stdout.log | cut -c1-260 | tail -${LINES_MAX:-60}
python3 -I -B hash_parents.py $3 $1 ${@:4} > $1.hashes.json; echo "hash_parents exit $?"
exit $rc
