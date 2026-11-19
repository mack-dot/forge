#!/bin/bash
# rt.sh <label> <tree> <test file relative to tree> [args...]: one regression run, scrubbed env, log in logs/<label>.log ending "exit N".
H=<REPO>/results/night-shift-20261119/orch-B/h-sink3
L=$1; shift; T=$1; shift; F=$1; shift
mkdir -p $H/logs $H/tmp
( cd "$T" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/tmp TMPDIR=$H/tmp/ LANG=C timeout ${TMO:-180} /opt/homebrew/bin/node --no-warnings --import tsx "$F" "$@" ) > $H/logs/$L.log 2>&1
echo "exit $?" >> $H/logs/$L.log
