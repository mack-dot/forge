#!/bin/bash
# Runs the h-judges regress judge (from the h-judges export) against the red team's mutants (read only).
D=<REPO>/results/night-shift-20261119/orch-B/h-judges2; C=<REPO>/results/night-shift-20261119/orch-C/c10-judges; V=$C/v6/ts/refund-finality
LIST="base_v6|$V/sink.ts|$V/dispatcher.ts m_accept_bad_sig|$V/m_accept_bad_sig.ts|$V/dispatcher.ts m_accept_noncanon|$V/m_accept_noncanon.ts|$V/dispatcher.ts
m_skip_prestate|$V/m_skip_prestate.ts|$V/dispatcher.ts m_replay_says_rejected|$V/m_replay_says_rejected.ts|$V/dispatcher.ts m_replayed_any|$V/m_replayed_any.ts|$V/dispatcher.ts
m_id_gt32_or_nonascii|$V/m_id_gt32_or_nonascii.ts|$V/dispatcher.ts m_late20|$V/m_late20.ts|$V/dispatcher.ts m_wipe_on_open|$V/m_wipe_on_open.ts|$V/dispatcher.ts
md_ignore_sig|$V/sink.ts|$V/md_ignore_sig.ts md_ignore_chain|$V/sink.ts|$V/md_ignore_chain.ts md_emit_before_ledger|$V/sink.ts|$V/md_emit_before_ledger.ts
enc_unsigned_body|$C/enc/ts/refund-finality/sink.ts|$C/enc/ts/refund-finality/dispatcher.ts i_exit_early|$V/i_exit_early.ts|$V/dispatcher.ts
i_forge_output|$V/i_forge_output.ts|$V/dispatcher.ts i_sqlite_hide|$V/i_sqlite_hide.ts|$V/dispatcher.ts s_rollback_guard|$V/s_rollback_guard.ts|$V/dispatcher.ts m_reject_all|$V/m_reject_all.ts|$V/dispatcher.ts"
for e in ${ONLY:-$LIST}; do IFS="|" read tag s d <<< "$e"
  $D/rj.sh $D/tree $D/logs/reg-$tag.log tests/refund-finality/regress/run.ts "$s" "$d" --expect-fail X6-Z1-zero-row-deleted-recommitted
  echo "$tag exit=$? FAIL=$(grep -o '^FAIL [^:]*' $D/logs/reg-$tag.log | cut -c6- | tr '\n' ',') $(grep -o 'KNOWN-LIMIT X6[^:]*\|PASS X6-P1[^:]*' $D/logs/reg-$tag.log)"
done
