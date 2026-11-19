#!/bin/bash
# usage: run.sh <script.ts> <args...>   (cwd = target tree; scrubbed env; TMPDIR inside the evidence dir)
E=<REPO>/results/night-shift-20261119/orch-C/c25-provider
T=<SCRATCH>/redteam-C/fix-74fb70eb
cd "$T" && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME="$E" LANG=C TMPDIR="$E/tmp" NODE_PATH=<REPO>/node_modules timeout 120 node --import tsx "$@"
