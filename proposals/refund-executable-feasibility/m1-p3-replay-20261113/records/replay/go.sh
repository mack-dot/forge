#!/bin/zsh
# Usage: go.sh <case> <source>; loads deps.txt first.
cd ${0:A:h}
deps=("${(@f)$(cat deps.txt)}")
python3 -I -B run_case.py $1 $2 $deps > $1.run.json; echo "exit $?"
python3 -c "import json;d=json.load(open('$1/command.json'));print('wall',d['wall_seconds'],'rss_mib',d['child_max_rss_bytes']//2**20,d['markers'])"
tail -c 700 $1/stderr.log
grep -n "CASE_PROVED\|compile_no_install_prefix:\|Proved triv\|Saved\|compile_correct:\|Failed\|failed\|rror\|xception\|CHECKED\|FIDELITY\|COMPLETE\|Saved theorem\|Stashing\|Finalis" $1/stdout.log | cut -c1-300 | tail -${LINES_MAX:-40}
