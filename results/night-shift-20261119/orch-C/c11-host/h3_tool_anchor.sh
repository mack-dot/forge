#!/bin/bash
# c11-host H3: sink_tool.ts init with a config that has no initialState takes THE ANCHOR from its command-line argument
# (v6 diff line 15) and writes it to meta; every later CLI then needs a config with initialState, whose only stored
# source is that meta. Exit 1 = defect present (init accepted an argv anchor and stored it), 0 = safe (refused).
unset GH_TOKEN GITHUB_TOKEN; source /Users/mackianni/forge/results/night-shift-20261119/orch-C/c11-host/env.sh
W=$E/w/s1; DB=$E/w/h3-anchor.sqlite; rm -f $DB
out=$(tsrun tests/demo-gauntlet/sink_tool.ts init $DB $W/sink-config-noinit.json '{"chargeId":"ch_host","original":"1000","remaining":"1000","refundEnabled":true}' 2>/dev/null); rc=$?
meta=$(/usr/bin/sqlite3 $DB "select v from meta where k='initial_state'" 2>/dev/null)
echo "rc=$rc out=$out meta=$meta"; rm -f $DB
[ $rc -eq 0 ] && [ -n "$meta" ] && exit 1; exit 0
