#!/bin/bash
# Orchestrator B, h-gate. PREPARED, NOT RUN. Bulk light translations (`dafny translate js --no-verify`, one at a time
# through tools/dafny_locked.sh) of every file in LIST, then the JS checker and its five mutants over all outputs.
# Usage: LIST=heavy/list_jsbound.txt [OUT=heavy/translate-all] heavy/translate_all.sh
# It refuses while hol.lock exists or a HOL process runs. It does not take heavy.lock (the orchestrator holds it).
set -u
H=<REPO>/results/night-shift-20261119/orch-B/h-gate; L=<REPO>/results/night-shift-20261119/locks
LIST=${LIST:-$H/heavy/list_jsbound.txt}; OUT=${OUT:-$H/heavy/translate-all}
[ -e $L/hol.lock ] && { echo "refused: hol.lock exists"; exit 75; }
pgrep -f 'bin/hol' >/dev/null && { echo "refused: a HOL process runs"; exit 75; }
case "$(pmset -g batt | head -1)" in *"AC Power"*) ;; *) echo "refused: battery"; exit 75;; esac
mkdir -p $OUT/js $OUT/logs
while read cls S; do
  [ -e $L/hol.lock ] && { echo "stopped: hol.lock appeared"; break; }
  n=$(basename $S .dfy); [ -f $OUT/js/$n.js ] && continue
  W=$H/work/ta-$n; rm -rf $W; mkdir -p $W/impl $W/spec/refund
  cp <REPO>/spec/refund/RefundSpec.dfy $W/spec/refund/; cp $S $W/impl/Refund.dfy
  sh <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh h-gate-bulk $W $OUT/logs/$n.translate.log 60 \
     translate js impl/Refund.dfy --no-verify --output $W/model >/dev/null 2>&1
  [ -f $W/model.js ] && cp $W/model.js $OUT/js/$n.js; rm -rf $W
  echo "$cls $n $(tail -1 $OUT/logs/$n.translate.log)"
done < $LIST | tee $OUT/translate.txt
for m in none no-loop no-recursion no-load no-shape no-cost; do
  arg=""; [ $m != none ] && arg="--mutant=$m"
  env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/work node --max-old-space-size=400 $H/js_bound_check.cjs $arg --work=$H/work $OUT/js/*.js > $OUT/check-$m.jsonl
  echo "mutant $m: $(grep -c '"ACCEPT"' $OUT/check-$m.jsonl) accepted of $(wc -l < $OUT/check-$m.jsonl)"
done
