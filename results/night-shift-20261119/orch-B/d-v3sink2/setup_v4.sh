#!/bin/bash
# d-v3sink2: prepares a differential harness folder (no Node run). Usage: setup_v4.sh OUTDIR
# Based on d-v3sink/setup_v3.sh: the d-v3sink harness copies (lib.ts gets ONE more SINKS entry "cb-v4"), the compiled
# reference cores (v3, reqid) from d-v3sink/build, the patched sink copies, wrappers cb-v3 (d-v3sink draft, core v3)
# and cb-v4 (this folder's sink_core_backed_v4.ts). Records SHA-256 of every input.
set -u
H=$1; R=<REPO>; V=$R/results/night-shift-20261119/orch-B/d-v3sink; W=$R/results/night-shift-20261119/orch-B/d-v3sink2
rm -rf $H; mkdir -p $H/db $H/results $H/sinks $H/patched $H/broken
cp $V/harness/lib.ts $V/harness/diff.ts $H/
sed -i '' "s#<HOME>#<HOME>#g" $H/lib.ts $H/diff.ts
sed -i '' 's#^  "cb-v3": Z + "/sinks/cb-v3.ts",#  "cb-v3": Z + "/sinks/cb-v3.ts",\n  "cb-v4": Z + "/sinks/cb-v4.ts",#' $H/lib.ts
grep -q '"cb-v4"' $H/lib.ts || { echo "lib.ts edit failed"; exit 2; }
cp $V/build/shellcore-v3.cjs $H/sinkcore-v3.cjs
cp $V/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
cp $V/copies/sink-patched-reqid.ts $H/patched/sink-reqid.ts
cp $V/copies/sink-patched-reqid-chargeid.ts $H/patched/sink-reqid-chargeid.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v3";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "v3" }); } }\n' $V > $H/sinks/cb-v3.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v4";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c }); } }\n' $W > $H/sinks/cb-v4.ts
shasum -a 256 $H/lib.ts $H/diff.ts $H/*.cjs $H/patched/*.ts $H/sinks/*.ts $V/sink_core_backed_v3.ts $W/sink_core_backed_v4.ts $V/build/*.cjs $W/build/*.cjs $R/ts/refund-finality/sink.ts $R/ts/refund-finality/encoding.ts > $H/inputs-sha256.txt
