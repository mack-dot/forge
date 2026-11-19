#!/bin/bash
# Runs B's own p_*.ts at 74fb70eb: anchor none in all 5 modes, anchor full in modes b and d-b.
E=<REPO>/results/night-shift-20261119/orch-C/c25-provider
T=<SCRATCH>/redteam-C/fix-74fb70eb
out=$E/logs/B_SUMMARY.txt; : > $out
for f in $T/tests/refund-finality/regress/p_*.ts; do n=$(basename $f .ts); [ $n = p_lib ] && continue
  cases=""; [ $n = p_att28_new_ledger ] && cases="ledger ledger+witness"
  for c in ${cases:-_}; do cc=$c; [ $c = _ ] && cc=""
    line="$n${cc:+ $cc}:"
    for spec in a:none b:none c:none d-a:none d-b:none b:full d-b:full; do m=${spec%%:*}; a=${spec##*:}
      $E/run.sh tests/refund-finality/regress/$n.ts $T $m $a $cc > $E/logs/B_${n}${cc:+_$cc}_${m}_${a}.log 2>&1; line="$line $m/$a=$?"
    done; echo "$line" >> $out; done; done
cat $out
