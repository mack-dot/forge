# Separate proposal: one hosted TextIO.read proof job

NOT AUTHORIZED. The current owner instruction explicitly forbids the hosted
HOL proof. This file prepares a later decision; it grants no execution authority.
The approved Ubuntu integrity run is complete and consumed its one-job scope.

Proposed action:replace only .github/workflows/m1-macos-preflight.yml on
proposal/m1-macos-preflight-20261106 in public mack-dot/forge. Expected branch
head8ad9de1e538edd48a2084796510e784913eaef8b. Recheck before any future publication.
One branch update triggers one job. No rerun,merge or automatic follow-on.
No new proof input upload:reuse21c4bdf958627e6a24e8dee9a45d90568b3e3c20 and
ac05eaf972b8c98784466ae063fca505aaaf25f4,whose full bytes passed U335 readback.

Exact proposed workflow:[records/proposed-proof-workflow.yml](records/proposed-proof-workflow.yml),
16385 bytes,SHA2561af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1.
Driver SHA2562667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8.
Only two changes from the U329 template:bind the verified addon commit and
refuse redirects before following them. All other driver code is byte-identical.
The frozen template,bound-only version and exact diff are preserved. Neither
the candidate,its theorem premises,nor any pinned toolchain/parent bytes changed.
Python/YAML/shell syntax checks exit0; these are not proof checks.

Sole shell command:/usr/bin/python3 -I -B - with the embedded driver,through
bash --noprofile --norc -euo pipefail {0}. Token permissions:{}; no secret,
checkout action,install,sudo,security-setting change,signing or deployment.
Reads existing public immutable inputs; creates private0700 temporary paths.
Records complete streams,actual child exits,input hashes and theory artifacts.

One standard macos-15 ARM64 job,15-minute cap; image must equal20261104.0514.1.
Fail if unavailable or environment/identity checks fail. No image substitution
or assumption change is authorized. Each HOL child:CPU120s,wall150s,maxheap1536MiB,
output-file cap4MiB. At most five serial children:unchanged candidate,conditional
identical repeat,fresh import,wrong-exception control,omitted-event control.
Stop at first unexpected result. Preserve failures; never weaken the statement.

The driver checks architecture,OS,resources,mkstemp,read/write,process,memory
and denied-read controls. It uses the existing public loadHierarchy/path APIs.
The frozen MiniSat binding remains unchanged; the existing HOL fallback is
permitted as previously recorded. This cached-parent experiment does not prove
independent full-chain provenance. Provider isolation and OS behavior remain trust.

Purpose:check read_error_generic or expose its exact residual. Even a passing
theorem will not close native C/memory/frame/lifetime or refund_main composition.
No native refund run,21-snapshot replay,Stage12,release signing or deployment.
Logical Success,modeled FFI events and OS exit remain distinct. end_to_end=false.
