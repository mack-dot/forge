#!/bin/bash
# Sequential light translations of ${Q:-tr-queue.txt} (one Dafny run at a time through the lock). Skips existing js.
E=<REPO>/results/night-shift-20261119/orch-B/h-gate
while read S; do n=$(basename $S .dfy); [ -f $E/js/$n.js ] && continue
  [ "$(sysctl -n vm.swapusage | sed -E 's/.*free = ([0-9]+)\..*/\1/')" -lt 500 ] && { echo "stop: low swap"; break; }
  $E/tools/tr.sh $S ${RUN:-2} 2>/dev/null | tail -1; done < $E/${Q:-tr-queue.txt}
echo QUEUE-DONE
