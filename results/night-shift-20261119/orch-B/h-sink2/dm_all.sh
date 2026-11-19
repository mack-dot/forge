#!/bin/bash
# usage: dm_all.sh <treeRoot> <logprefix>: run every d_*.ts / m_*.ts regression (not the helpers) on <treeRoot>
T=$1; P=$2; CORE=<REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs
export PATH=/opt/homebrew/bin:/usr/bin:/bin
cd "$T" || exit 3
for f in tests/refund-finality/regress/d_*.ts tests/refund-finality/regress/m_*.ts; do
  b=$(basename $f .ts); case $b in d_lib|d_child|d_host_cli|m_lib) continue;; esac
  env -i PATH=$PATH HOME=<REPO>/results/night-shift-20261119/orch-B/h-sink2 timeout 120 node --no-warnings --import tsx $f "$T" $CORE > $P-$b.log 2>&1; rc=$?
  echo "exit $rc" >> $P-$b.log; echo "$b exit $rc"
done
