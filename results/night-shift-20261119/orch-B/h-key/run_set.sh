#!/bin/bash
# usage: run_set.sh <tree> <label> : the existing regressions (s_, s3_, d_, d3_, m_, m2_) and the p sample (modes a, c; anchors none, full)
H=<REPO>/results/night-shift-20261119/orch-B/h-key; T=$1; L=$2
cd $T/tests/refund-finality/regress
F=$(ls s_*.ts s3_*.ts d_*.ts d3_*.ts m_*.ts m2_*.ts | grep -v "_lib\|d_child")
$H/run_regress.sh $T $L $F || exit $?
for m in a c; do for a in none full; do PMODE=$m PANCHOR=$a $H/run_regress.sh $T $L $(ls p_*.ts | grep -v p_lib) || exit $?; done; done
