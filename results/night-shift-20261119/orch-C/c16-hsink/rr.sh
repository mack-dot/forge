#!/bin/bash
# rr.sh <logname> <script> <args...>: run, log, print exit
EV=<REPO>/results/night-shift-20261119/orch-C/c16-hsink
n=$1; shift; $EV/run.sh "$@" > $EV/logs/$n.log 2>&1; rc=$?; echo "exit=$rc" >> $EV/logs/$n.log; echo "$n exit=$rc"
