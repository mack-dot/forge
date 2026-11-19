#!/bin/bash
# B's p_*.ts scenarios, unchanged, against realprov.ts. Column = provider setting; value = B's own exit code.
E=<REPO>/results/night-shift-20261119/orch-C/c25-provider
T=<SCRATCH>/redteam-C/fix-74fb70eb
out=$E/logs/W_SUMMARY.txt; : > $out
for f in $T/tests/refund-finality/regress/p_*.ts; do n=$(basename $f .ts); [ $n = p_lib ] && continue
  cases=_; [ $n = p_att28_new_ledger ] && cases="ledger ledger+witness"
  for c in $cases; do cc=$c; [ $c = _ ] && cc=""; line="$n${cc:+ $cc}:"
    for col in "first:a:none:RP_REPLAY=first" "ret24:d-a:none:RP_RET=24" "ret24ceil:d-b:none:RP_RET=24" "ret48:d-a:none:RP_RET=48" "ret24full:d-a:full:RP_RET=24" "inflight:a:none:RP_INFLIGHT=1"; do
      IFS=: read tag m a ev <<< "$col"
      env $ev RP_CEIL=$([ $tag = ret24ceil ] && echo 1 || echo 0) $E/run.sh $E/wrap.ts $n $T $m $a $cc > $E/logs/W_${n}${cc:+_$cc}_$tag.log 2>&1; line="$line $tag=$?"
    done; echo "$line" >> $out; done; done
cat $out
