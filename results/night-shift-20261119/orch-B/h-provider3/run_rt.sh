#!/bin/bash
# h-provider3: the red team's scripts (copies in rt/) on the BEFORE tree (5d99be9d export) and the AFTER tree (this work).
# One short Node run at a time; swap gate 512 MiB before each (fail closed). Usage: run_rt.sh <logdir>
D=<REPO>/results/night-shift-20261119/orch-B/h-provider3; L=$1; mkdir -p $L $D/rt/tmp; S=$L/SUMMARY.tsv
echo "# $(date -u +%FT%TZ)" > $S
run() { # tag tree envs... -- script args...
  local tag=$1 tree=$2; shift 2; local ev=(); while [ "$1" != "--" ]; do ev+=("$1"); shift; done; shift
  local free=$(/usr/sbin/sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9.]+)M.*/\1/'); free=${free%.*}
  if ! [[ "$free" =~ ^[0-9]+$ ]] || [ "$free" -lt 512 ]; then echo "STOP: swap free ${free} MiB" | tee -a $S; exit 5; fi
  local f=$L/$tag.log
  echo "cmd: env ${ev[*]} $D/rt/run.sh $tree $*" > $f
  env -u RP_SHARED "${ev[@]}" $D/rt/run.sh $tree "$@" >> $f 2>&1; local rc=$?; echo "exit $rc" >> $f
  printf "%s\t%s\n" "$tag" "$rc" >> $S
}
for side in before after; do T=$D/$side; [ $side = after ] && T=$D/tree
  run ${side}_s1_collide_first $T RP_SHARED=$D/rt/tmp/shared.json RP_REPLAY=first -- $D/rt/s1_scope.ts $T collide
  run ${side}_s1_collide_error $T RP_SHARED=$D/rt/tmp/shared.json RP_REPLAY=error -- $D/rt/s1_scope.ts $T collide
  run ${side}_s1_squat_first $T RP_SHARED=$D/rt/tmp/shared.json RP_REPLAY=first -- $D/rt/s1_scope.ts $T squat
  run ${side}_s4_first_ceil1_none $T RP_REPLAY=first RP_CEIL=1 -- $D/rt/s4_rebind.ts $T none
  run ${side}_s4_first_ceil1_full $T RP_REPLAY=first RP_CEIL=1 -- $D/rt/s4_rebind.ts $T full
  run ${side}_s4_error_ceil1_none $T RP_REPLAY=error RP_CEIL=1 -- $D/rt/s4_rebind.ts $T none
  run ${side}_s4_first_ceil0_none $T RP_REPLAY=first RP_CEIL=0 -- $D/rt/s4_rebind.ts $T none
  run ${side}_s5_long $T RP_KEYPOLICY=reject -- $D/rt/s5_keytext.ts $T long
  run ${side}_s5_nonascii $T RP_KEYPOLICY=reject -- $D/rt/s5_keytext.ts $T nonascii
  run ${side}_s5_ctrl $T RP_KEYPOLICY=reject -- $D/rt/s5_keytext.ts $T ctrl
  run ${side}_s5_prefix_trunc_first $T RP_KEYPOLICY=truncate RP_REPLAY=first -- $D/rt/s5_keytext.ts $T prefix
  run ${side}_s5_empty_nokey $T RP_EMPTYKEY=nokey -- $D/rt/s5_keytext.ts $T empty
  run ${side}_w43_ret24_none $T RP_RET=24 RP_CEIL=1 -- $D/rt/wrap.ts p_full_restore_retry $T d-a none
  run ${side}_w43_ret24_full $T RP_RET=24 RP_CEIL=1 -- $D/rt/wrap.ts p_full_restore_retry $T d-a full
  run ${side}_w_inflight_timeout $T RP_INFLIGHT=1 RP_CEIL=0 -- $D/rt/wrap.ts p_timeout_retry $T a none
done
echo "# end $(date -u +%FT%TZ)" >> $S
