#!/bin/bash
# c11-host H5: the documented recovery step (remove the lock file) during a slow run: the run sends its effects, its
# finally's unlinkSync throws ENOENT, the FlushResult is lost; dispatch_cli prints {"stopped": "ENOENT ..."} with exit 0
# although effects were sent. Exit 1 = defect present (effects sent AND the CLI said "stopped" or exited non-zero
# without reporting them), 0 = safe.
unset GH_TOKEN GITHUB_TOKEN; source <REPO>/results/night-shift-20261119/orch-C/c11-host/env.sh
W=$E/w/h5; tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || exit 3
for t in t0 t1; do tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/$t.token 0 >/dev/null 2>&1; done
(cd $T && exec env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$E LANG=C NODE_PATH=<REPO>/node_modules $NODE --import tsx tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 >$W/run1.out 2>/dev/null) &
P=$!
for i in $(seq 1 400); do [ -s $W/effects.jsonl ] && break; /bin/sleep 0.01; done
rm -f "$(cd $W && pwd -P)/ledger.jsonl.lock"; wait $P; rc=$?
n=$(wc -l < $W/effects.jsonl | tr -d ' '); out=$(cat $W/run1.out)
echo "rc=$rc out=$out effects_sent=$n"
out2=$(tsrun tests/refund-finality/dispatch_cli.ts $W/sink.sqlite $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl 0 2>/dev/null); echo "retry rc=$? $out2"
[ "$n" -gt 0 ] && ! echo "$out" | grep -q "\"emitted\":$n" && exit 1; exit 0
