#!/bin/bash
# h-provider3 copy of h-provider2/run_matrix.sh (only D and the swap gate changed): every p_*.ts regression x provider mode x anchor, one short Node run at a time (about 1 s each).
# Gate before EVERY cell: swap free >= 512 MiB (brief of h-provider3), else stop (exit 5). No concurrency. Each log ends with "exit N".
# Usage: run_matrix.sh <tree> <logdir>
T=$1; L=$2; D=<REPO>/results/night-shift-20261119/orch-B/h-provider3
export PATH=/opt/homebrew/bin:/usr/bin:/bin
mkdir -p $L; S=$L/SUMMARY.tsv
[ -f $S ] && echo "# resume $(date -u +%FT%TZ)" >> $S || { echo "# node $(node --version) | $(pmset -g batt | head -1) | $(date -u +%FT%TZ) | tree $T" > $S; printf "test\tcase\tanchor\tmode\texit\tstopped_by\n" >> $S; }
cell() { # test anchor mode [case]
  local t=$1 a=$2 m=$3 k=$4
  # resume (h-provider3): a cell whose log already ends with "exit N" is not run again
  [ -f $L/${t}${k:+_$k}_${a}_${m}.log ] && tail -1 $L/${t}${k:+_$k}_${a}_${m}.log | grep -q "^exit " && return
  local free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
  # fail closed: an unreadable value stops the run (matrix1 had sysctl outside PATH and the test failed open)
  if ! [[ "$free" =~ ^[0-9]+$ ]] || [ "$free" -lt 512 ]; then echo "STOP: swap free ${free} MiB < 512 before $t $a $m $k" | tee -a $S; exit 5; fi
  local f=$L/${t}${k:+_$k}_${a}_${m}.log
  echo "cmd: env -i PATH=$PATH HOME=$D/home TMPDIR=$D/home LANG=C node --import tsx tests/refund-finality/regress/$t.ts $T $m $a $k" > $f
  echo "swap free MiB before: $free" >> $f
  (cd $T && env -i PATH=$PATH HOME=$D/home TMPDIR=$D/home LANG=C node --import tsx tests/refund-finality/regress/$t.ts $T $m $a $k) >> $f 2>&1
  local rc=$?; echo "exit $rc" >> $f
  local sb=$(grep -m1 '^stopped by:\|^positive control:' $f | sed 's/^stopped by: //')
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$t" "${k:--}" "$a" "$m" "$rc" "$sb" >> $S
}
for t in p_zero_amount p_provider_faults p_timeout_retry p_ledger_restore p_db_restore_retry p_db_restore_new_ids p_param_rebind p_second_ledger; do
  for a in none full; do for m in a b c d-a d-b; do cell $t $a $m; done; done
done
for t in p_full_ledger_lag p_full_restore_retry p_full_restore_new_ids p_full_param_rebind; do
  for a in none floor head full; do for m in a b c d-a d-b; do cell $t $a $m; done; done
done
for k in ledger ledger+witness; do
  for a in none floor head full; do for m in a b c d-a d-b; do cell p_att28_new_ledger $a $m $k; done; done
done
echo "# end $(date -u +%FT%TZ)" >> $S
