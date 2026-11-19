#!/bin/bash
# HEAVY spec-conformance run (task h-specdiff). PREPARED; the orchestrator runs it in a window.
# Usage: heavy_spec.sh <compiledCoreModule> <outDir> <sinkModulePath>...
# Since task h-judges run.ts exits 1 when a property is violated (P5-SILENT excluded) or a run did not complete;
# a nonzero status of this script therefore also means "violations found": read results.jsonl (field violated).
#   For each sink: modes seq, fault, interleave; 5,000 sequences each (COUNT overrides); seed 20261119 (SEED overrides).
#   Typical sinks: ts/refund-finality/sink.ts (merged), the v6 draft sink, the hardened sink (any path).
# Refuses (exit 64) while results/night-shift-20261119/locks/hol.lock exists or a HOL process runs; refuses (75)
# when not on AC power. It does NOT take heavy.lock (the orchestrator holds it). Run from the repository root
# (the directory that holds ts/ and node_modules/). Pinned Node: /opt/homebrew/bin first in PATH.
set -u
CORE=${1:?core module}; OUT=${2:?out dir}; shift 2
[ $# -ge 1 ] || { echo "usage: heavy_spec.sh <core> <outDir> <sink>..." >&2; exit 2; }
LOCKS=${LOCKS:-<REPO>/results/night-shift-20261119/locks}
COUNT=${COUNT:-5000}; SEED=${SEED:-20261119}; TMO=${TMO:-1800}
refuse() { if [ -e "$LOCKS/hol.lock" ] || pgrep -f 'bin/hol' >/dev/null; then echo "refused: hol.lock or a HOL process" >&2; exit 64; fi
  pmset -g batt | head -1 | grep -q "AC Power" || { echo "refused: not on AC power" >&2; exit 75; }; }
refuse
mkdir -p "$OUT/work" || exit 65
ROOT=$(pwd); [ -f "$ROOT/tests/refund-finality/spec-conformance/run.ts" ] || { echo "run from the repository root" >&2; exit 2; }
P=/opt/homebrew/bin:/usr/bin:/bin
{ echo "# start=$(date -u +%FT%TZ) node=$(env -i PATH=$P node --version) count=$COUNT seed=$SEED"; shasum -a 256 "$CORE" "$@" tests/refund-finality/spec-conformance/*.ts; } > "$OUT/inputs.txt"
status=0; n=0
for S in "$@"; do
  n=$((n+1))
  for M in seq fault interleave; do
    refuse
    L="$OUT/sink$n-$M.log"
    ( /usr/bin/time -l env -i PATH=$P HOME="$OUT/work" TMPDIR="$OUT/work" LANG=C timeout "$TMO" \
        node --no-warnings --import tsx tests/refund-finality/spec-conformance/run.ts "$S" "$M" "$COUNT" "$SEED" "$CORE" "$OUT/work" ) > "$L" 2>&1
    c=$?; echo "exit $c" >> "$L"; [ $c -eq 0 ] || status=1
    grep '^{' "$L" | head -1 >> "$OUT/results.jsonl"
    echo "sink$n=$S mode=$M exit=$c" >> "$OUT/summary.txt"
  done
done
rm -rf "$OUT/work"
echo "# end=$(date -u +%FT%TZ) status=$status" >> "$OUT/inputs.txt"
exit $status
