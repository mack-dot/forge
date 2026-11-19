#!/bin/bash
# Compares a matrix SUMMARY.tsv with h-provider2's matrix1 (same p_*.ts code as 5d99be9d: no diff 74fb70eb..5d99be9d in ts/ tests/).
B=<REPO>/results/night-shift-20261119/orch-B/h-provider2/logs/matrix1/SUMMARY.tsv; N=$1
awk -F'\t' 'NR==FNR { if ($1 ~ /^p_/) old[$1"|"$2"|"$3"|"$4]=$5"\t"$6; next }
  $1 ~ /^p_/ { k=$1"|"$2"|"$3"|"$4; n++; split(old[k],o,"\t"); if (o[1]!=$5 || o[2]!=$6) { d++; print "CHANGED\t" k "\told " old[k] "\tnew " $5 "\t" $6 } }
  END { print "cells compared: " n ", changed (exit or layer): " d+0 }' $B $N
