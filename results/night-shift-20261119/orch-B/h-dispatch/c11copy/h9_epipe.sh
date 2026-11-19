#!/bin/bash
# c11-host H9: stdout = a pipe whose reader has exited (EPIPE). commit_cli commits and dispatch_cli emits, then the
# result write fails and the CLI exits 1: the host sees a failure for a refund that was committed / sent; its retry
# gets "replayed" (commit: truthful) and {"emitted":0} (dispatch: the host never learns the refund went out).
# Exit 1 = defect present (a non-zero exit after the effect happened), 0 = safe.
unset GH_TOKEN GITHUB_TOKEN; source <REPO>/results/night-shift-20261119/orch-B/h-dispatch/c11copy/env.sh
W=$W0/h9; tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || exit 3
c=$(/usr/bin/python3 -I $E/epipe.py $T $E 1500 -- tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/t0.token START)
r=$(tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/t0.token 0 2>/dev/null)
d=$(/usr/bin/python3 -I $E/epipe.py $T $E 1500 -- tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl START)
d2=$(tsrun tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 2>/dev/null)
n=$(wc -l < $W/effects.jsonl | tr -d ' ')
echo "commit under EPIPE: $c ; retry: $r"; echo "dispatch under EPIPE: $d ; effects=$n ; retry: $d2"
echo "$c" | grep -q '"exit": 1' && echo "$r" | grep -q replayed && exit 1
echo "$d" | grep -q '"exit": 1' && [ "$n" -ge 1 ] && exit 1; exit 0
