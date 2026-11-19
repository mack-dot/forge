#!/bin/bash
# h-provider: run every p_*.ts regression in every provider mode, sequentially (light: under 1 s each).
# Each log ends with a line "exit N" (the actual exit code). Summary: logs/SUMMARY.txt.
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-provider
cd $D/tree || exit 3
: > $D/logs/SUMMARY.txt
echo "node $(/opt/homebrew/bin/node --version) $(pmset -g batt | head -1) $(date -u +%FT%TZ) tree=e65f9ec8 export" >> $D/logs/SUMMARY.txt
for t in p_ledger_restore p_db_restore_retry p_db_restore_new_ids p_second_ledger p_timeout_retry p_param_rebind p_provider_faults p_zero_amount; do
  line="$t"
  for m in a b c d-a d-b; do
    L=$D/logs/${t}_${m}.log
    echo "cmd: node --import tsx tests/refund-finality/regress/$t.ts <tree> $m" > $L
    env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D/home TMPDIR=$D/home LANG=C node --import tsx tests/refund-finality/regress/$t.ts $D/tree $m >> $L 2>&1
    rc=$?; echo "exit $rc" >> $L; line="$line $m=$rc"
  done
  echo "$line" >> $D/logs/SUMMARY.txt
done
cat $D/logs/SUMMARY.txt
