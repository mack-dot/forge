#!/bin/bash
# c11-host H1: dispatch_cli.ts exits 0 on every error path. Exit 1 = defect present (some error path exits 0), 0 = safe.
# Cases: emitfail (the effect cannot be written: the ledger line is kept, the effect is lost, the retry says emitted 0),
#        lock (a lock file left by a killed run), chain (dispatcher ledger is not one chain), refused (a pinned id is wrong:
#        every row refused; the CLI prints only the emitted count).
# Usage: bash h1_dispatch_exit.sh <case>
unset GH_TOKEN GITHUB_TOKEN; source /Users/mackianni/forge/results/night-shift-20261119/orch-C/c11-host/env.sh
C=$1; W=$E/w/h1-$C
tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || { echo "setup failed"; exit 3; }
tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/t0.token 0 2>/dev/null
D() { tsrun tests/refund-finality/dispatch_cli.ts $W/sink.sqlite "$1" "$2" "$3" 0 2>/dev/null; }
case $C in
  emitfail) out=$(D $W/ledger.jsonl $W/disp-config.json $W/no-such-dir/effects.jsonl); rc=$?
            out2=$(D $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl); rc2=$?
            echo "run1 rc=$rc $out"; echo "retry rc=$rc2 $out2"; echo "ledger lines: $(wc -l < $W/ledger.jsonl)"; echo "effects lines: $(cat $W/effects.jsonl 2>/dev/null | wc -l)"
            [ $rc -eq 0 ] || [ $rc2 -eq 0 -a "$(cat $W/effects.jsonl 2>/dev/null | wc -l | tr -d ' ')" = 0 ] && exit 1; exit 0;;
  lock)     : > $W/ledger.jsonl; : > "$(cd $W && pwd -P)/ledger.jsonl.lock"
            out=$(D $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl); rc=$?; echo "rc=$rc $out"; [ $rc -eq 0 ] && exit 1; exit 0;;
  chain)    echo '{"requestId":"x","tokenSha256":"0","preStateSha256":"bad","postStateSha256":"0","intentSha256":"0"}' > $W/ledger.jsonl
            out=$(D $W/ledger.jsonl $W/disp-config.json $W/effects.jsonl); rc=$?; echo "rc=$rc $out"; [ $rc -eq 0 ] && exit 1; exit 0;;
  refused)  /usr/bin/python3 -I -c "import json,sys;c=json.load(open(sys.argv[1]));c['initialStateSha256']='0'*64;json.dump(c,open(sys.argv[2],'w'))" $W/disp-config.json $W/disp-bad.json
            out=$(D $W/ledger.jsonl $W/disp-bad.json $W/effects.jsonl); rc=$?; echo "rc=$rc $out (1 committed row pending)"
            [ $rc -eq 0 ] && exit 1; exit 0;;
esac
