#!/bin/bash
# F-01 measurement: SIGCHLD set INSIDE the launcher process (not inherited). Not a caller attack; it tells
# whether XNU auto-reaps at all. Uses ${LAUNCHER:-launcher.py}.
L=/Users/mackianni/forge/results/night-shift-20261119/orch-A/launch
for m in inproc-ign inproc-nocldwait; do for fake in fake_accept_exit7 fake_accept_abort; do
  printf '%s %s: ' $m $fake
  /opt/homebrew/bin/timeout 15 /usr/bin/env -i /usr/bin/python3 -B -I $L/tests_v2/driver.py $L/${LAUNCHER:-launcher.py} decide $L/bin2/$fake $m 2>&1 | tr '\n' ' '
  echo " [rc=${PIPESTATUS[0]}]"
done; done
