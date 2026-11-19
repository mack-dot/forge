#!/bin/bash
# d-v5sink: prepares a differential harness folder (no Node run). Usage: setup_v5.sh OUTDIR
# Copy of d-v3sink2/setup_v4.sh (copies/setup_v4.sh), changed: lib.ts gets ONE more SINKS entry "cb-v5" (the test
# wrapper cb-v5-wrapper.ts around this folder's sink_core_backed_v5.ts). Records SHA-256 of every input.
set -u
H=$1; R=/Users/mackianni/forge; V=$R/results/night-shift-20261119/orch-B/d-v3sink; W=$R/results/night-shift-20261119/orch-B/d-v5sink
rm -rf $H; mkdir -p $H/db $H/results $H/sinks $H/patched $H/broken
cp $V/harness/lib.ts $V/harness/diff.ts $H/
sed -i '' "s#<HOME>#/Users/mackianni#g" $H/lib.ts $H/diff.ts
sed -i '' 's#^  "cb-v3": Z + "/sinks/cb-v3.ts",#  "cb-v3": Z + "/sinks/cb-v3.ts",\n  "cb-v5": Z + "/sinks/cb-v5.ts",#' $H/lib.ts
grep -q '"cb-v5"' $H/lib.ts || { echo "lib.ts edit failed"; exit 2; }
cp $V/build/shellcore-v3.cjs $H/sinkcore-v3.cjs
cp $V/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
cp $V/copies/sink-patched-reqid.ts $H/patched/sink-reqid.ts
cp $V/copies/sink-patched-reqid-chargeid.ts $H/patched/sink-reqid-chargeid.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v3";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "v3" }); } }\n' $V > $H/sinks/cb-v3.ts
cp $W/cb-v5-wrapper.ts $H/sinks/cb-v5.ts
shasum -a 256 $H/lib.ts $H/diff.ts $H/*.cjs $H/patched/*.ts $H/sinks/*.ts $V/sink_core_backed_v3.ts $W/sink_core_backed_v5.ts $V/build/*.cjs $W/build/*.cjs $R/ts/refund-finality/sink.ts $R/ts/refund-finality/encoding.ts > $H/inputs-sha256.txt
