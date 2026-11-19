#!/bin/bash
# Runs the h-judges spec judge (seq 200 1, with the dispatcher) against the merged sink, the v6 draft, the hardened
# sink and the red team's mutants (read only). One light run each, in sequence.
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-judges; C=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c10-judges; V=$C/v6/ts/refund-finality
HT=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-sink/tree/ts/refund-finality; T=$D/tree/ts/refund-finality
M=/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt/build/pristine-core/model.cjs
LIST="merged|$T/sink.ts|$T/dispatcher.ts|P1,P2,P3,P4,P7 hardened|$HT/sink.ts|$HT/dispatcher.ts|- base_v6|$V/sink.ts|$V/dispatcher.ts|-
m_accept_bad_sig|$V/m_accept_bad_sig.ts|$V/dispatcher.ts|- m_accept_noncanon|$V/m_accept_noncanon.ts|$V/dispatcher.ts|- m_skip_prestate|$V/m_skip_prestate.ts|$V/dispatcher.ts|-
m_replay_says_rejected|$V/m_replay_says_rejected.ts|$V/dispatcher.ts|- m_replayed_any|$V/m_replayed_any.ts|$V/dispatcher.ts|- m_id_gt32_or_nonascii|$V/m_id_gt32_or_nonascii.ts|$V/dispatcher.ts|-
m_late20|$V/m_late20.ts|$V/dispatcher.ts|- m_wipe_on_open|$V/m_wipe_on_open.ts|$V/dispatcher.ts|- md_ignore_sig|$V/sink.ts|$V/md_ignore_sig.ts|- md_ignore_chain|$V/sink.ts|$V/md_ignore_chain.ts|-
md_emit_before_ledger|$V/sink.ts|$V/md_emit_before_ledger.ts|- enc_unsigned_body|$C/enc/ts/refund-finality/sink.ts|$C/enc/ts/refund-finality/dispatcher.ts|-
i_exit_early|$V/i_exit_early.ts|$V/dispatcher.ts|- i_forge_output|$V/i_forge_output.ts|$V/dispatcher.ts|- s_rollback_guard|$V/s_rollback_guard.ts|$V/dispatcher.ts|- m_reject_all|$V/m_reject_all.ts|$V/dispatcher.ts|-"
for e in ${ONLY:-$LIST}; do IFS="|" read tag s d x <<< "$e"
  EX=(); [ "$x" != "-" ] && EX=(--expect-violations "$x")
  $D/rj.sh $D/tree $D/logs/spec-$tag.log tests/refund-finality/spec-conformance/run.ts "$s" seq 200 1 $M $D/work --dispatcher "$d" "${EX[@]}"
  c=$?
  echo "$tag exit=$c $(python3 -I $D/specsum.py $D/logs/spec-$tag.log)"
done
