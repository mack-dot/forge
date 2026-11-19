#!/bin/bash
# Usage: rund.sh <base|tree> <prefix>: runs every d_*.ts regression (from the fixed tree's files) against the tree <base|tree>.
H=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-dispatch
T=$1; P=$2; [ -n "$T" ] && [ -n "$P" ] || exit 2
CORE=/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs
for f in ${ONLY:-d_positive_controls d_att17_lock_theft d_att17_claim_race d_att18_throwing_emit d_att19_ledger_restore d_att20_blob_request_id d_att22_short_write d_host02_dead_lock_takeover d_host05_second_ledger d_host_cli}; do
  (cd $H/$T && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C TMPDIR=$H/home timeout 120 node --no-warnings --import tsx $H/tree/tests/refund-finality/regress/$f.ts $H/$T $CORE) > $H/logs/$P-$f.log 2>&1
  e=$?; echo "exit $e" >> $H/logs/$P-$f.log; echo "$P $f exit $e"
done
