#!/bin/bash
# c11-host H2: a dispatch_cli run stopped by SIGTERM or SIGINT inside a run leaves the lock; every later run then exits 0
# with {"stopped": ...} and sends nothing. Exit 1 = defect present (lock left AND a later run exits 0), 0 = safe.
# Usage: bash h2_signal_lock.sh TERM|INT
unset GH_TOKEN GITHUB_TOKEN; source <REPO>/results/night-shift-20261119/orch-B/h-dispatch/c11copy/env.sh
S=$1; W=$W0/h2-$S
tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || { echo "setup failed"; exit 3; }
for t in t0 t1; do tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/$t.token 0 2>/dev/null >/dev/null; done
(cd $T && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$H/home LANG=C NODE_PATH=<REPO>/node_modules $NODE --import tsx tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 >$W/run1.out 2>/dev/null) &
P=$!
for i in $(seq 1 400); do [ -s $W/effects.jsonl ] && break; /bin/sleep 0.01; done
kill -$S $P; wait $P; rc1=$?
L="$(cd $W && pwd -P)/ledger.jsonl.lock"
echo "run1 rc=$rc1 out=[$(cat $W/run1.out)] ledger=$(wc -l < $W/ledger.jsonl | tr -d ' ') effects=$(wc -l < $W/effects.jsonl | tr -d ' ') lock_left=$([ -e "$L" ] && echo yes || echo no)"
out=$(tsrun tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 2>/dev/null); rc2=$?
echo "run2 rc=$rc2 $out"
[ -e "$L" ] && [ $rc2 -eq 0 ] && exit 1; exit 0
