#!/bin/zsh
# W-repro watchdog: if a HOL child of this reproduction runs and its stdout.log has no new bytes for 600 s, kill it (HUNG).
RUN=${0:A:h}; LOG=$RUN/repro-driver.log
while true; do
  grep -qE 'ALL_DONE|STOP' $LOG 2>/dev/null && { echo "watchdog end: $(tail -1 $LOG)"; exit 0; }
  pid=$(pgrep -f "$RUN/.*proof.sml" | head -1)
  if [[ -n $pid ]]; then
    f=$(ps -o args= -p $pid | grep -oE "$RUN/[^ ]*proof.sml" | head -1); f=${f%proof.sml}stdout.log
    if [[ -f $f ]]; then age=$(( $(date +%s) - $(stat -f %m $f) ))
      if [[ $age -ge 600 ]]; then echo "$(date -u +%FT%TZ) HUNG $f age=$age pid=$pid" | tee -a $LOG; pkill -f "$RUN/.*proof.sml"; echo "kill sent"; exit 3; fi
    fi
  fi
  sleep 30
done
