#!/bin/bash
# rr.sh <logname> <script> <args...>: run via run.sh, log, print exit
EV=/Users/mackianni/forge/results/night-shift-20261119/orch-C/c21-sink2
n=$1; shift; $EV/run.sh "$@" > $EV/logs/$n.log 2>&1; rc=$?; echo "exit=$rc" >> $EV/logs/$n.log; echo "$n exit=$rc"; tail -c 1500 $EV/logs/$n.log | head -c 1500
