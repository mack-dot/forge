#!/bin/bash
# Usage: run.sh FILE.js [CASE] [LEN]. Step 1: the h-gate checker, exactly as h-gate/tools/run_set.sh runs it (scrubbed env,
# 60 s alarm, 300 MB heap, --work=). Step 2: one real Assess call in a child Node (scrubbed env, 5 s SIGKILL, 200 MB heap).
# Exit 1 = the checker ACCEPTs and the real call throws, times out, runs out of memory or returns a wrong answer (claim broken).
# Exit 0 = no break. Exit 2 = the checker refuses (no break).
set -u
B=<REPO>/results/night-shift-20261119/orch-B; H=$B/h-gate; E=$B/r-jsbound
F=$1; KASE=${2:-elig}; LEN=${3:-2}; N=$(basename $F .js)
P=/opt/homebrew/bin:/usr/bin:/bin
V=$(env -i PATH=$P HOME=$E/work perl -e 'alarm 60; exec @ARGV' node --max-old-space-size=300 $H/js_bound_check.cjs --work=$E/work $F)
echo "checker: $V"
echo "$V" | grep -q '"verdict":"ACCEPT"' || { echo "checker REFUSE -> exit 2"; exit 2; }
D=$(mktemp -d $E/work/run-XXXX); cp $H/runtime-prefix.js $D/model.cjs
cat $F >> $D/model.cjs; printf '\nmodule.exports = { Refund, runtime: _dafny };\n' >> $D/model.cjs
env -i PATH=$P HOME=$D perl -e 'alarm 5; exec @ARGV' node --max-old-space-size=200 $E/drive.cjs $D/model.cjs $KASE $LEN
c=$?; rm -rf $D
echo "real run exit $c (142 = killed by 5 s alarm)"
[ $c -eq 0 ] && { echo "claim held on this run -> exit 0"; exit 0; }
echo "CLAIM BROKEN -> exit 1"; exit 1
