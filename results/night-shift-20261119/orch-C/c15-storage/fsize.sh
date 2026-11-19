#!/bin/bash
# usage: fsize.sh <blocks of 512> <child args...> : runs child_op.ts with RLIMIT_FSIZE and SIGXFSZ ignored (write -> EFBIG)
N=$1; shift
trap '' XFSZ; ulimit -f "$N" || exit 9
exec node --import tsx /Users/mackianni/forge/results/night-shift-20261119/orch-C/c15-storage/child_op.ts "$@"
