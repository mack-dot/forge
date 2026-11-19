#!/bin/bash
# Usage: run2s.sh SCRIPT.js [args]. Scrubbed env, pinned Node, 2 s wall-clock kill (SIGALRM), 200 MB heap.
D=<REPO>/results/night-shift-20261119/orch-B/r-subset2
start=$(perl -MTime::HiRes=time -e 'print time')
env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=$D/js perl -e 'alarm 2; exec @ARGV' node --max-old-space-size=200 "$@"
code=$?
end=$(perl -MTime::HiRes=time -e 'print time')
echo "exit $code elapsed $(perl -e "printf '%.2f', $end-$start") s"
