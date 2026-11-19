#!/bin/bash
# blindspots2.sh: C-JUDGE-01/03 re-run against the judges of cf242303 (tree fix-f08a21c1). Each mutant / impostor /
# evasion in judges/m runs through BOTH judges (judge.sh). A mutant is PASSED by a judge when that judge exits 0.
# Exit 1 if ANY defective input is passed by BOTH judges (a blind spot remains); 0 otherwise.
# md_ignore_chain is EQUIVALENT on this tree (the compiled AuditStep still refuses a chain break; confirm.ts exit 0): not counted.
# Defects of the counted inputs: judges/confirm.ts (exit 1 = defect) for the sink/dispatcher/enc mutants.
# s_rollback_guard is the SAFER sink of C-JUDGE-02: it is reported (a FAIL there is a false rejection), not counted.
# Skip the judge runs with REUSE=1 (only re-score existing logs).
EV=<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2; M=$EV/judges/m
TS=<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality
LIST="base|$TS/sink.ts|$TS/dispatcher.ts"
for s in m_accept_bad_sig m_accept_noncanon m_skip_prestate m_replay_says_rejected m_replayed_any m_id_gt32_or_nonascii m_late20 m_wipe_on_open i_exit_early i_forge_output e_status_lie s_rollback_guard; do LIST="$LIST $s|$M/$s/sink.ts|$TS/dispatcher.ts"; done
for d in md_ignore_sig md_ignore_chain md_emit_before_ledger e_emit_twice_hidden e_emit_twice_hidden2 e_emit_before_ledger_hidden e_exit0; do LIST="$LIST $d|$TS/sink.ts|$M/$d/dispatcher.ts"; done
LIST="$LIST enc_unsigned_body|$M/enc_unsigned_body/sink.ts|$M/enc_unsigned_body/dispatcher.ts"
if [ "$REUSE" != 1 ]; then i=0
  for e in $LIST; do IFS="|" read tag s d <<< "$e"; $EV/judges/judge.sh $tag $s $d & i=$((i+1)); [ $((i % 2)) -eq 0 ] && wait; done; wait
fi
both=0
printf "%-30s %-34s %-24s %s\n" input regress spec verdict
for e in $LIST; do IFS="|" read tag s d <<< "$e"
  r=$(tail -1 $EV/judges/logs/$tag.regress.log); sp=$(tail -1 $EV/judges/logs/$tag.spec.log)
  fl=$(grep -o '^# verdicts=.*FAIL=[0-9]* \[[^]]*\]' $EV/judges/logs/$tag.regress.log | sed 's/.*FAIL=/FAIL=/')
  v="caught"; if [ "$r" = "exit 0" ] && [ "$sp" = "exit 0" ]; then v="PASSED BY BOTH"; fi
  case $tag in base) v="(baseline)";; md_ignore_chain) v="(equivalent: confirm.ts shows no defect; not counted)";; s_rollback_guard) [ "$r" = "exit 0" ] && [ "$sp" = "exit 0" ] && v="(safer sink: not failed = correct)" || v="(safer sink FAILED: false rejection)";; *) [ "$v" = "PASSED BY BOTH" ] && both=$((both+1));; esac
  printf "%-30s %-34s %-24s %s\n" "$tag" "$r ${fl:0:26}" "$sp" "$v"
done
echo "# defective inputs passed by both judges: $both"
[ $both -gt 0 ] && exit 1; exit 0
