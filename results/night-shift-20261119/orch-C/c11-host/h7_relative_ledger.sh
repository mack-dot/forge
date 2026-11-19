#!/bin/bash
# c11-host H7: dispatch_cli with a RELATIVE ledger path, started from two working directories (an honest host that
# changes its cwd): two ledgers, the same committed refunds sent twice. Exit 1 = more effects than committed refunds.
unset GH_TOKEN GITHUB_TOKEN; source <REPO>/results/night-shift-20261119/orch-C/c11-host/env.sh
W=$E/w/h7; tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || exit 3
for t in t0 t1; do tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/$t.token 0 >/dev/null 2>&1; done
mkdir -p $W/cwdA $W/cwdB
for d in cwdA cwdB; do (cd $W/$d && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=<REPO>/node_modules $NODE --import tsx $T/tests/refund-finality/dispatch_cli.ts $W/sink.sqlite ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 2>/dev/null; echo " rc=$?"); done
n=$(wc -l < $W/effects.jsonl | tr -d ' '); echo "committed=2 effects=$n (sum of amounts: $(grep -o 'amount\\":\\"[0-9]*' $W/effects.jsonl | grep -o '[0-9]*$' | paste -sd+ - | bc) on original 1000)"
[ "$n" -gt 2 ] && exit 1; exit 0
