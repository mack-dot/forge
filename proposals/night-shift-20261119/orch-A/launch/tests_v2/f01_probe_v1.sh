#!/bin/bash
# F-01 probe against the UNCHANGED launcher.py (W-launch round 2). Each line: mode, fake, the driver's line.
L=/Users/USER/forge/results/night-shift-20261119/orch-A/launch
T=/opt/homebrew/bin/timeout
for mode in none ign nocldwait; do
  for fake in fake_accept_exit7 fake_accept_abort; do
    printf '%s %s: ' $mode $fake
    $T 15 /usr/bin/python3 -B -I $L/tests_v2/sigchld_exec.py $mode /usr/bin/env -i /usr/bin/python3 -B -I \
      $L/tests_v2/driver.py $L/${LAUNCHER:-launcher.py} decide $L/bin2/$fake 2>&1 | tr '\n' ' '
    echo " [pipeline rc=${PIPESTATUS[0]}]"
  done
done
