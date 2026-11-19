#!/bin/bash
# d-v3sink: prepares a differential harness folder (no Node run). Usage: setup_v3.sh OUTDIR
# Contents: harness copies lib.ts/diff.ts (d-v3sink/harness), compiled cores (v3 and reqid), patched sink copies,
# wrappers cb-v3/cb-reqid around d-v3sink/sink_core_backed_v3.ts. Records SHA-256 of every input.
set -u
H=$1; R=/Users/mackianni/forge; V=$R/results/night-shift-20261119/orch-B/d-v3sink
rm -rf $H; mkdir -p $H/db $H/results $H/sinks $H/patched $H/broken
cp $V/harness/lib.ts $V/harness/diff.ts $H/
sed -i '' "s#<HOME>#/Users/mackianni#g" $H/lib.ts $H/diff.ts
cp $V/build/shellcore-v3.cjs $H/sinkcore-v3.cjs
cp $V/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
cp $V/copies/sink-patched-reqid.ts $H/patched/sink-reqid.ts
cp $V/copies/sink-patched-reqid-chargeid.ts $H/patched/sink-reqid-chargeid.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v3";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "v3" }); } }\n' $V > $H/sinks/cb-v3.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v3";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "reqid" }); } }\n' $V > $H/sinks/cb-reqid.ts
shasum -a 256 $H/lib.ts $H/diff.ts $H/*.cjs $H/patched/*.ts $H/sinks/*.ts $V/sink_core_backed_v3.ts $V/build/*.cjs $R/ts/refund-finality/sink.ts $R/ts/refund-finality/encoding.ts > $H/inputs-sha256.txt
