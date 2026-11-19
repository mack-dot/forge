#!/bin/bash
# h-provider3: every p3_*.ts case with the new adapter (v3) and the frozen old adapter (v1, the control). One short Node run
# at a time. Gate before each run: swap free >= 512 MiB (the brief of h-provider3) (fail closed). Each log ends with "exit N".
# Usage: run_p3.sh <tree> <logdir>
T=$1; L=$2; D=<REPO>/results/night-shift-20261119/orch-B/h-provider3
export PATH=/opt/homebrew/bin:/usr/bin:/bin
mkdir -p $L; S=$L/SUMMARY.tsv
echo "# node $(node --version) | $(date -u +%FT%TZ) | tree $T" > $S
run() { # tag env test args...
  local tag=$1 ev=$2 t=$3; shift 3
  local free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
  if ! [[ "$free" =~ ^[0-9]+$ ]] || [ "$free" -lt 512 ]; then echo "STOP: swap free ${free} MiB" | tee -a $S; exit 5; fi
  local f=$L/${t}_${tag}.log
  echo "cmd: cd $T && env -i PATH=$PATH HOME=$D/home TMPDIR=$D/home LANG=C $ev node --import tsx tests/refund-finality/regress/$t.ts $T $*" > $f
  (cd $T && env -i PATH=$PATH HOME=$D/home TMPDIR=$D/home LANG=C $ev node --import tsx tests/refund-finality/regress/$t.ts $T "$@") >> $f 2>&1
  local rc=$?; echo "exit $rc" >> $f; printf "%s\t%s\t%s\t%s\n" "$t" "$tag" "$*" "$rc" >> $S
}
for A in v3 v1; do
  run ${A}_first P_ADAPTER=$A p3_scope_collide first
  run ${A}_error P_ADAPTER=$A p3_scope_collide error
  for r in first error; do for a in none full; do run ${A}_${r}_${a} P_ADAPTER=$A p3_rollback_rebind $r $a; done; done
  for k in literal derived; do for r in first error; do run ${A}_${k}_${r} P_ADAPTER=$A p3_key_squat $k $r; done; done
  run ${A}_long P_ADAPTER=$A p3_keytext long
  run ${A}_nonascii P_ADAPTER=$A p3_keytext nonascii
  run ${A} P_ADAPTER=$A p3_in_progress
done
for r in first error; do run v3noamount_${r}_none "P_ADAPTER=v3 P_KEY=noamount" p3_rollback_rebind $r none; done
echo "# end $(date -u +%FT%TZ)" >> $S
