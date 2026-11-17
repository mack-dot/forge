#!/bin/zsh
# Usage: go.sh <case> <source> [extra theory files]; loads deps-asm.txt first.
cd ${0:A:h}
deps=("${(@f)$(cat deps-asm.txt)}")
python3 -I -B run_case.py $1 $2 $deps ${@:3} > $1.run.json; echo "exit $?"
python3 -c "import json;d=json.load(open('$1/command.json'));print('wall',d['wall_seconds'],'rss_mib',d['child_max_rss_bytes']//2**20,d['markers'])"
tail -c 600 $1/stderr.log
grep -n "^CHECKED\|^IMPORTED\|^CONTROL\|^CLOSURE\|^EVAL\|COMPLETE\|Failed\|failed\|rror\|xception\|^STAGE\|^ARM8_\|^SHOW\|^  ASM\|^  GOAL\|^REPLAY_\|^STORED_\|^SOUNDNESS\|^CONFIG\|^EVAL_\|^LEMMA\|^AFTER\|^AFTER\|^LEMMA\|^FIDELITY\|^NEG\|^CONTROL_NOT" $1/stdout.log | cut -c1-260 | tail -${LINES_MAX:-40}
