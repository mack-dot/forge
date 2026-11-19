#!/bin/bash
# d-reqid: PREPARED, NOT RUN. A heavy step (about 5,500 sequences x 2 cores x several sinks). The orchestrator
# runs it later under heavy.lock, with no HOL process and swap free >= 1 GB. Each command is single-threaded.
# It copies the Z4 harness (proposals/m1b-mission-20261119/drafts/sink-differential) into this folder, fills the
# <HOME> placeholder, and makes two core modules from the compiled Dafny (this folder: build/sinkcore-reqid.js;
# the original core needs one `dafny build --target js` of inputs/sink/SinkCore.dfy through dafny_locked.sh).
# UNTESTED glue: the export wrapper below (the Z4 .cjs files are not in the repository).
set -u   # no -e: a divergence makes diff.ts exit 1, and that is an expected result for one pair
D=<REPO>/results/night-shift-20261119/orch-B/d-reqid
R=<REPO>
H=$D/heavy; rm -rf $H; mkdir -p $H/db $H/results $H/patched $H/broken
cp $R/proposals/m1b-mission-20261119/drafts/sink-differential/{lib.ts,diff.ts} $H/
sed -i '' "s#<HOME>#<HOME>#g" $H/lib.ts $H/diff.ts
cp $D/copies/patched-reqid/sink.ts $H/patched/sink-reqid.ts
sed -i '' 's#from "./encoding"#from "<REPO>/ts/refund-finality/encoding"#' $H/patched/sink-reqid.ts
# core modules: the patched core exported under the name SinkCore that lib.ts reads
{ cat $D/build/sinkcore-reqid.js; echo 'module.exports = { SinkCore: SinkCoreReqId, RefundFinality, Refund, runtime: _dafny };'; } > $H/sinkcore-reqid.cjs
# (original core: build it first, then the same wrapper with SinkCore)
# $R/results/night-shift-20261119/orch-B/tools/dafny_locked.sh d-reqid $D/dafny/inputs/sink $D/logs/heavy-orig-build.log 90 build --target js --output $D/build/sinkcore-orig.js <gate options> SinkCore.dfy
# { cat $D/build/sinkcore-orig.js; echo 'module.exports = { SinkCore, RefundFinality, Refund, runtime: _dafny };'; } > $H/sinkcore.cjs
export PATH=/opt/homebrew/bin:/usr/bin:/bin
cd $R
for core in sinkcore.cjs sinkcore-reqid.cjs; do
  for sink in real patched-reqid; do
    for mode in plain fault-1 fault-2 interleave; do
      n=2000; [ $mode != plain ] && n=500
      env -i PATH=$PATH HOME=$H NODE_PATH=$R/node_modules Z4_SEED=20261119 Z4_CORE=$core \
        node --import tsx $H/diff.ts $sink $mode $n > $H/results/$core-$sink-$mode.stdout 2>&1; echo "$core $sink $mode exit $?"
    done
  done
done
# Expected (NOT a result): real vs sinkcore.cjs 0 divergences; patched-reqid vs sinkcore-reqid.cjs 0; real vs
# sinkcore-reqid.cjs > 0 (the mismatch tokens). Z4 recorded exactly this pattern in its own run.
