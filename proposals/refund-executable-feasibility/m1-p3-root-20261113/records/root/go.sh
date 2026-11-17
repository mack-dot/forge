#!/bin/zsh
# Usage: go.sh <case> <source> [extra theory files]; loads deps.txt first.
cd ${0:A:h}
deps=("${(@f)$(cat deps.txt)}")
python3 -I -B run_case.py $1 $2 $deps ${@:3} > $1.run.json; echo "exit $?"
cat $1/stderr.log | cut -c1-700 | tail -3; grep -n "STAGE\|LEMMA\|AFTER\|ASM\|GOAL\|rror\|xception\|CHECKED\|IMPORTED\|CONTROL\|CLOSURE\|COMPLETE\|Fail" $1/stdout.log | head -${LINES_MAX:-70}
