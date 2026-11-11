# U332: exact inputs published; proof execution held

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
Previous local checkpoint:U331,commit902511c1a6f27b0cc06bbfe39208e3db935559c0.

The owner first said "go ahead and try it" after the exact U329 approval scope
was presented. Under that grant,the four input files were published. During
readback,the owner then required the exact manifest report before execution
and explicit authorization. The workflow trigger is held. No new hosted run or
HOL proof command has executed. No prior failure or input was overwritten.

## Exact scope inspected

The governing [APPROVAL.md](../hosted-cf-candidate-20261107/APPROVAL.md) SHA256 is
`d17518d10fa1c5ba5c0219f002176da65b75e2f93a10ff04032fd76c04cb700e`.
It authorizes these specific actions when approved:

| Item | Exact proposed scope |
| --- | --- |
| New transfer |INPUTS.json932,639 bytes plus three archive parts4,194,304/4,194,304/1,493,856 bytes; total10,815,103 bytes |
| Contents |1,475 files;111,912,627 raw bytes. Pinned CakeML/HOL library files,saved-state and cached-proof dependencies,unchanged candidate,licenses,four prepared statement checks. Local source paths/hashes appear in the manifest. |
| Reused inputs |18 previously published files at ac05eaf972b8c98784466ae063fca505aaaf25f4; pinned HOL/PolyML/GMP and saved states. No new source transfer for this base. |
| Destination |Public mack-dot/forge; proposals/m1-hosted-cf-inputs on proposal/m1-cf-inputs-20261107 |
| Trigger |One replacement of .github/workflows/m1-macos-preflight.yml on proposal/m1-macos-preflight-20261106. Only ADDON_COMMIT_SHA may change in the reviewed template. No retry or merge. |
| Runner |macos-15; runtime must report Darwin/arm64,RUNNER_ARCH=ARM64,non-root,image20261104.0514.1. Any mismatch stops. |
| Job permissions |permissions:{}; public repository guard; no checkout/action step,secret,install,sudo,security change,release signing or deployment |
| Resources |Job15 minutes. Each HOL child CPU120 seconds,wall150 seconds,maxheap1536 MiB,file cap4 MiB,core dumps0. Environment requires RAM≥4 GiB and /var/tmp free space≥2 GiB; touches64 MiB during its probe. |
| Filesystem/solver |Private0700 root under RUNNER_TEMP; pinned files400/500; public saved-state/path APIs. Original native MiniSat binding remains unchanged and must be unavailable at its old absolute path. Existing HOL fallback permitted and disclosed. |

The [prepared workflow](../hosted-cf-candidate-20261107/records/proposed-workflow.yml)
starts `/usr/bin/python3 -I -B -` with the exact embedded driver. Environment
commands are `/usr/bin/sw_vers`, `/usr/sbin/sysctl -n hw.memsize`, `/usr/bin/true`
and `/usr/bin/otool -L` on the pinned HOL/PolyML/GMP binaries. The driver calls
libc mkstemp on `/var/tmp/forge-m1-cf-XXXXXX`,checks read/write and denied read,
and transfers only files selected by the two pinned manifests.

Each prepared HOL command is
`<private-root>/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol --maxheap 1536 run --poly <case>/bootstrap.sml`.
The bootstrap loads four exact states,registers private paths,loads the pinned
basis/parent theories and unchanged cfLib,then uses the unchanged candidate or
the prepared import/control source. It does not modify the runtime or theorem.

Expected checks below have NOT RUN:

1. Validate runner identity,resources,permissions,dynamic runtime paths and all
   1,493 input hashes before/after each child.
2. Run the exact `read_error_generic` candidate. Acceptance requires actual
   exit0,completion marker and four exports. A load or tactic failure stops.
3. Only after success,repeat the unchanged proof and require identical exports.
4. Fresh import:exact conclusion,zero hypotheses,zero tagged axioms,only
   DISK_THM tags,one theorem,printed ancestry/axiom inventory. Actual result
   still needs assumption/dependency review; a driver marker is not proof assurance.
5. Wrong-exception and omitted-event statement controls must actually exit1 at
   the expected mismatch and produce no success marker or export.

This scope concerns modeled TextIO.read error behavior. Even a checked theorem
would leave native read transition/buffer preservation,aliasing/lifetime/frame,
and inputAllFrom/refund_main exception/event composition open. Existing U310
premises remain. The21-snapshot independent replay is excluded and needs its own
validated scope. Logical Success,modeled events,OS exit and physical effects
remain separate. No silicon verification is required.

## Actual external and local results

[Published input commit](https://github.com/mack-dot/forge/commit/21c4bdf958627e6a24e8dee9a45d90568b3e3c20)
adds exactly the four approved files. GitHub's returned blob IDs match the
locally computed Git blob hashes. A separate commit read confirms their paths,
IDs and parent8ad9de1e538edd48a2084796510e784913eaef8b.
The workflow branch remains at that parent. GitHub lists only the old completed
U326 and U324 workflow runs. This attempt has consumed zero hosted runs.

| Executed action/check | Actual exit/result |
| --- | --- |
| Local approved-input hash/read helper |0; four exact file hashes |
| Initial large tool-buffer assembly |Tool script error at character524288; no upload in that failed call |
| Corrected262143-byte transfer reads |0;44 pieces assembled |
| Four blobs / tree / input commit / input branch |Tool success; identities recorded |
| First input commit call |Tool-catalog rejection before execution; refreshed tool then succeeded |
| Generic binary blob read |Tool error400:UTF-8 text only |
| Base64 file reader for4 MiB part |Expected blob ID but empty content; insufficient readback |
| Specific binary blob reader |UnicodeDecodeError; insufficient readback |
| Direct immutable-URL download |1; DNS getaddrinfo error8 before any file download |
| Post-publication commit/branch/run reads |Tool success; four files,unchanged workflow,no new run |
| New hosted proof / repeat / import / negatives / independent replay |NOT RUN |

The new manifest SHA256 remains
`6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105`.
Archive SHA256 remains
`1f7a009b866b18c8299aac5d36b6ad59e54bfb73d4bba568da98ebde3c2146e1`.
Candidate SHA256 remains
`7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6`.

## Smallest blockers

Remote complete byte readback remains unestablished. Matching uploaded and
committed blob IDs is recorded as identity evidence,not a completed byte download.
The approval document requires readback before the trigger. A binary-capable
read path for the already approved immutable commit is the smallest transport
need. No permission expansion,security bypass,extra upload,rechunked manifest,
changed proof or new external host has been introduced to force progress.

Execution is also held at the owner's latest review-before-execution instruction.
This report supplies the requested scope. No further hosted authority is inferred
from successful source publication. Preserve all failures; do not run the frozen
21-snapshot replay or treat this transport checkpoint as mathematical progress.
