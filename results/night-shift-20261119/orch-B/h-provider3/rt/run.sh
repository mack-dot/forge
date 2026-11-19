#!/bin/bash
# h-provider3 copy of orch-C/c25-provider/run.sh: usage run.sh <tree> <script.ts> <args...>; cwd = <tree>; scrubbed env.
E=<REPO>/results/night-shift-20261119/orch-B/h-provider3/rt
T=$1; shift
cd "$T" && env -i $(env | grep "^RP_" | tr "\n" " ") PATH=/opt/homebrew/bin:/usr/bin:/bin HOME="$E" LANG=C TMPDIR="$E/tmp" NODE_PATH=<REPO>/node_modules timeout 120 node --import tsx "$@"
