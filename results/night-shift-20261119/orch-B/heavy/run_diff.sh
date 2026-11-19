#!/bin/bash
# Orchestrator B. Differential TEST (not a proof) of sinks against compiled Dafny cores. HEAVY when counts are large.
# Usage: run_diff.sh OUTDIR N_PLAIN N_OTHER "MODES" [PAIR ...]   PAIR = core:sink
# Built from d-corebacked/heavy_differential.sh and d-reqid/heavy_differential.sh (both untested as written).
# The caller holds heavy.lock for a heavy run. Test keys are generated in the Node process. env -i.
set -u
OUT=$1; NP=$2; NO=$3; MODES=$4; shift 4
R=/Users/mackianni/forge; B=$R/results/night-shift-20261119/orch-B; D=$B/d-corebacked; Q=$B/d-reqid
H=$OUT; rm -rf $H; mkdir -p $H/db $H/results $H/sinks $H/patched $H/broken
cp $R/proposals/m1b-mission-20261119/drafts/sink-differential/{lib.ts,diff.ts} $H/
sed -i '' "s#<HOME>#/Users/mackianni#g" $H/lib.ts $H/diff.ts
cp $D/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
cp $D/build/shellcore-orig.cjs $H/sinkcore.cjs
cp $Q/copies/patched-reqid/sink.ts $H/patched/sink-reqid.ts
sed -i '' 's#from "./encoding"#from "/Users/mackianni/forge/ts/refund-finality/encoding"#' $H/patched/sink-reqid.ts
printf 'import { Sink as S } from "%s/sink_core_backed";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "reqid" }); } }\n' $D > $H/sinks/cb-reqid.ts
printf 'import { Sink as S } from "%s/sink_core_backed";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "orig" }); } }\n' $D > $H/sinks/cb-orig.ts
sed -i '' "s#^  real: ROOT + \"/ts/refund-finality/sink.ts\",#  real: ROOT + \"/ts/refund-finality/sink.ts\",\n  \"cb-reqid\": Z + \"/sinks/cb-reqid.ts\",\n  \"cb-orig\": Z + \"/sinks/cb-orig.ts\",#" $H/lib.ts
grep -q '"cb-reqid"' $H/lib.ts || { echo "lib.ts edit failed"; exit 2; }
shasum -a 256 $H/lib.ts $H/diff.ts $H/*.cjs $H/patched/*.ts $D/sink_core_backed.ts $R/ts/refund-finality/sink.ts > $H/inputs-sha256.txt
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
cd $R
for pair in "$@"; do
  core=${pair%%:*}; sink=${pair##*:}
  for mode in $MODES; do
    n=$NP; [ $mode != plain ] && n=$NO
    s=$(date -u +%FT%TZ)
    env -i PATH=$PATH HOME=$H NODE_PATH=$R/node_modules Z4_SEED=20261119 Z4_CORE=$core \
      node --import tsx $H/diff.ts $sink $mode $n > $H/results/$core-$sink-$mode.stdout 2>&1
    rc=$?
    echo "$core $sink $mode n=$n start=$s end=$(date -u +%FT%TZ) exit $rc" | tee -a $H/summary.txt
  done
done
