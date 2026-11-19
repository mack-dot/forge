#!/bin/bash
# d-v6sink: prepares a differential harness folder (no Node run). Usage: setup_v6.sh OUTDIR
# Copy of d-v5sink/setup_v5.sh, changed: lib.ts/diff.ts patched by harness_patch_v6.py (cb-v6 sink, V6 core adapter,
# kind "signed-unauthorized", suffix "@disabled"); core sinkcore-v6.cjs (= this folder's build/shellcore-v6.js with
# harness exports); sink wrapper cb-v6.ts. Records SHA-256 of every input.
set -u
H=$1; R=/Users/mackianni/forge; V=$R/results/night-shift-20261119/orch-B/d-v3sink; W=$R/results/night-shift-20261119/orch-B/d-v6sink
rm -rf $H; mkdir -p $H/db $H/results $H/sinks $H/patched $H/broken
cp $V/harness/lib.ts $V/harness/diff.ts $H/
sed -i '' "s#<HOME>#/Users/mackianni#g" $H/lib.ts $H/diff.ts
python3 $W/harness_patch_v6.py $H || { echo "patch failed"; exit 2; }
cp $V/build/shellcore-v3.cjs $H/sinkcore-v3.cjs
cp $V/build/shellcore-reqid.cjs $H/sinkcore-reqid.cjs
{ cat $W/build/shellcore-v6.js; echo 'module.exports = { Shell6: ShellCoreV6, Shell: ShellCoreV3, C: SinkCoreV3, F: RefundFinality, R: Refund, rt: _dafny, BigNumber, SinkCore: SinkCoreV3, RefundFinality, Refund, runtime: _dafny };'; } > $H/sinkcore-v6.cjs
cp $V/copies/sink-patched-reqid.ts $H/patched/sink-reqid.ts
cp $V/copies/sink-patched-reqid-chargeid.ts $H/patched/sink-reqid-chargeid.ts
printf 'import { Sink as S } from "%s/sink_core_backed_v3";\nexport class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "v3" }); } }\n' $V > $H/sinks/cb-v3.ts
sed 's#d-v5sink/sink_core_backed_v5#d-v6sink/sink_core_backed_v6#; s#^// d-v5sink: TEST WRAPPER#// d-v6sink (copy of d-v5sink/cb-v5-wrapper.ts, pointed at v6): TEST WRAPPER#' $W/copies/cb-v5-wrapper.ts > $H/sinks/cb-v6.ts
grep -q "d-v6sink/sink_core_backed_v6" $H/sinks/cb-v6.ts || { echo "wrapper edit failed"; exit 2; }
shasum -a 256 $H/lib.ts $H/diff.ts $H/*.cjs $H/patched/*.ts $H/sinks/*.ts $W/harness_patch_v6.py $V/sink_core_backed_v3.ts $W/sink_core_backed_v6.ts $W/build/*.cjs $R/ts/refund-finality/sink.ts $R/ts/refund-finality/encoding.ts > $H/inputs-sha256.txt
