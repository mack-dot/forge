#!/bin/bash
# Re-runs c23's correct set (js/K*.js) and unsafe set (js/U*.js) through the checker (--no-load, as the critical
# tier) and prints the counts; then B's stored set (orch-B/h-gate/js, js-reuse) for the union. Light (Node only).
E=<REPO>/results/night-shift-20261119/orch-C/c23-jsgate; H=<REPO>/results/night-shift-20261119/orch-B/h-gate
CHK=${1:-$H/js_bound_check.cjs}
run() { env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E/work perl -e 'alarm 120; exec @ARGV' /opt/homebrew/bin/node --max-old-space-size=300 "$CHK" --no-load --work=$E/work "$@"; }
run $E/js/K*.js > $E/logs/sets-correct.jsonl; run $E/js/U*.js > $E/logs/sets-unsafe.jsonl
run $H/js/*.js $H/js-reuse/*.js > $E/logs/sets-B.jsonl
for s in correct unsafe B; do
  f=$E/logs/sets-$s.jsonl
  echo "$s: files $(wc -l < $f | tr -d ' ') accepted $(grep -c '"ACCEPT"' $f) refused $(grep -c '"REFUSE"' $f)"
  grep '"REFUSE"' $f | sed -E 's/.*"file":"([^"]*)".*"code":"([^"]*)","detail":"([^"]{0,90}).*/  REFUSE \1 \2 \3/'
done | grep -v '^  REFUSE.*' ; for s in correct unsafe; do grep '"REFUSE"' $E/logs/sets-$s.jsonl | sed -E 's/.*"file":"([^"]*)".*"code":"([^"]*)","detail":"([^"]{0,90}).*/  '$s' REFUSE \1 \2 \3/'; grep '"ACCEPT"' $E/logs/sets-$s.jsonl | sed -E 's/.*"file":"([^"]*)".*/  '$s' ACCEPT \1/'; done
