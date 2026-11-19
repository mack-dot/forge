#!/bin/bash
# c11-host H6: commit_cli.ts exits 0 on a rejected token (and on a typo'd database path, where it also creates a new empty
# store file). Exit 1 = defect present (a refusal path exits 0), 0 = safe.
unset GH_TOKEN GITHUB_TOKEN; source <REPO>/results/night-shift-20261119/orch-C/c11-host/env.sh
W=$E/w/h6; tsrun $E/setup.ts $T $CORE $W two >/dev/null 2>&1 || exit 3
echo '{}' > $W/bad.token
o1=$(tsrun tests/refund-finality/commit_cli.ts $W/sink.sqlite $W/sink-config.json $W/bad.token 0 2>/dev/null); r1=$?
o2=$(tsrun tests/refund-finality/commit_cli.ts $W/typo.sqlite $W/sink-config.json $W/t0.token 0 2>/dev/null); r2=$?
echo "bad token rc=$r1 $o1"; echo "typo db rc=$r2 $o2 created=$([ -e $W/typo.sqlite ] && echo yes || echo no)"
[ $r1 -eq 0 ] || [ $r2 -eq 0 ] && exit 1; exit 0
