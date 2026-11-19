#!/bin/bash
# d-corebacked: PREPARED, NOT RUN. A HEAVY step. The orchestrator runs it later under heavy.lock, with no HOL
# process (results/night-shift-20261119/locks/hol.lock absent, `pgrep -f bin/hol` empty) and swap free >= 1 GB.
# It copies the Z4 harness (proposals/m1b-mission-20261119/drafts/sink-differential/{lib.ts,diff.ts}) into
# ./heavy, fills <HOME>, and adds three sink entries: the draft with the patched core, the draft with the
# unpatched core, and the real sink. Each sink runs against the compiled core in the modes plain (2,000
# sequences), fault-1, fault-2, interleave (500 each). diff.ts compares a sink with the compiled SinkCore*.Step
# (decoder not modelled). "Draft against sink.ts" is the composition: both against the same core, same seed.
# Core modules: build/shellcore-reqid.cjs exports SinkCore = SinkCoreReqId; build/shellcore-orig.cjs exports
# SinkCore = SinkCore (unpatched). Both are this worker's light builds (logs/v03, logs/v04).
set -u   # no -e: diff.ts exits 1 on a divergence, which is an expected result for some pairs
D=/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked
R=/Users/mackianni/forge
H=$D/heavy; rm -rf $H; mkdir -p $H/db $H/results $H/sinks
[ -e $R/results/night-shift-20261119/locks/hol.lock ] && { echo "hol.lock exists: NOT RUN"; exit 75; }
cp $R/proposals/m1b-mission-20261119/drafts/sink-differential/{lib.ts,diff.ts} $H/
sed -i '' "s#<HOME>#/Users/mackianni#g" $H/lib.ts $H/diff.ts
cp $D/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
cp $D/build/shellcore-orig.cjs $H/sinkcore.cjs
printf 'import { Sink as S } from "%s/sink_core_backed";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "reqid" }); } }\n' $D > $H/sinks/cb-reqid.ts
printf 'import { Sink as S } from "%s/sink_core_backed";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "orig" }); } }\n' $D > $H/sinks/cb-orig.ts
# add the two draft sinks to the SINKS table of the copied lib.ts
sed -i '' "s#^  real: ROOT + \"/ts/refund-finality/sink.ts\",#  real: ROOT + \"/ts/refund-finality/sink.ts\",\n  \"cb-reqid\": Z + \"/sinks/cb-reqid.ts\",\n  \"cb-orig\": Z + \"/sinks/cb-orig.ts\",#" $H/lib.ts
grep -q '"cb-reqid"' $H/lib.ts || { echo "lib.ts edit failed"; exit 2; }
export PATH=/opt/homebrew/bin:/usr/bin:/bin
[ "$(node --version)" = "v24.3.0" ] || { echo "not the pinned Node"; exit 2; }
cd $R
for pair in "sinkcore.cjs real" "sinkcore.cjs cb-orig" "sinkcore-reqid.cjs cb-reqid" "sinkcore-reqid.cjs real" "sinkcore.cjs cb-reqid"; do
  set -- $pair; core=$1; sink=$2
  for mode in plain fault-1 fault-2 interleave; do
    n=2000; [ $mode != plain ] && n=500
    env -i PATH=$PATH HOME=$H NODE_PATH=$R/node_modules Z4_SEED=20261119 Z4_CORE=$core \
      node --import tsx $H/diff.ts $sink $mode $n > $H/results/$core-$sink-$mode.stdout 2>&1
    echo "$core $sink $mode exit $?"
  done
done
# Expected (NOT a result): exit 0 (0 divergences) for (sinkcore.cjs, real), (sinkcore.cjs, cb-orig),
# (sinkcore-reqid.cjs, cb-reqid). Exit 1 for (sinkcore-reqid.cjs, real) and (sinkcore.cjs, cb-reqid): the
# request-id mismatch tokens. Reason-text classes: diff.ts maps sink reason texts to core Why names (sinkOut);
# the draft returns the same texts as sink.ts plus "request id is not the intent's request id".
