#!/bin/bash
E=<REPO>/results/night-shift-20261119/orch-B/r-drafts; L=$E/logs
T=<REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh; Z3=<REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
G=(--solver-path $Z3 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects)
for v in "$@"; do $T r-drafts $E/r1 $L/bisect-$v.log 90 verify "${G[@]}" $E/r1/IB2S_$v.dfy; echo "$v exit $?"; done
