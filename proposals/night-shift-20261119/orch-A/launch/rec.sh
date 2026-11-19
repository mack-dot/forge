#!/bin/bash
# rec.sh: run one command (as a bash -c string) from the launch folder, append the command, its actual exit code
# and a UTC time to commands.txt; output goes to the log file named by $LOG (default: static/last.log).
cd /Users/mackianni/forge/results/night-shift-20261119/orch-A/launch || exit 99
LOG=${LOG:-static/last.log}
bash -c "$1" >"$LOG" 2>&1
rc=$?
printf '%s | exit %d | log %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "$LOG" "$1" >> commands.txt
cat "$LOG"
exit $rc
