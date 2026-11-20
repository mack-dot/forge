#!/bin/bash
# APEX-2. Build the three theories with Holmake in a NEW copy of this folder.
# usage: run_hol.sh <tool-tree> <new-build-folder> [Holmake target ...]
#   <tool-tree> holds HOL/, cakeml/ and poly-install/ (the pinned tree; it is only read).
# The caller must hold the HOL lock: one HOL process at a time on this machine.
# Exit: the exit code of Holmake; 6 when the export bytes are not the pinned bytes; 2 usage.
set -u
[ $# -ge 2 ] || { sed -n 2,6p "$0"; exit 2; }
here=$(cd "$(dirname "$0")" && pwd); tc=$1; out=$2; shift 2
[ -e "$out" ] && { echo "the build folder exists already"; exit 2; }
got=$(shasum -a 256 "$here/FlatCore.sexp" | cut -d' ' -f1)
[ "$got" = 58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d ] || { echo "STOP: export SHA-256 $got is not the pin"; exit 6; }
mkdir -p "$out" && cp "$here"/Holmakefile "$here"/*Script.sml "$here"/FlatCore.sexp "$out"/ || exit 2
cd "$out" || exit 2
export CAKEMLDIR=$tc/cakeml
export PATH=$tc/HOL/bin:$tc/poly-install/bin:/usr/bin:/bin:/usr/sbin:/sbin
perl -e 'alarm shift; exec @ARGV' 900 Holmake --no_prereqs "$@" > holmake.stdout.log 2> holmake.stderr.log
rc=$?
echo "$rc" > holmake.exit.txt
echo "HOLMAKE EXIT $rc"
exit $rc
