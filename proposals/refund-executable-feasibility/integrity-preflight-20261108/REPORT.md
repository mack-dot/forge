# U333: DNS boundary diagnosed; integrity preflight ready for approval

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
Parent checkpoint:U332,commitbd37d71f509ab062dc86fd3be6db1b9514b35cb7.
No published input,theorem,old workflow or protected file was modified.
No hosted job or proof command ran. The requested integrity preflight is prepared
locally and awaits its own explicit approval.

## Actual results

| Executed operation | Actual exit/result |
| --- | --- |
| socket.getaddrinfo(localhost) |0; two results |
| socket.getaddrinfo(raw.githubusercontent.com),api.github.com,github.com |1/1/1; gaierror8 for each |
| scutil --dns |1; "No DNS configuration available" |
| curl --head of the pinned manifest URL |6; could not resolve host |
| DNS diagnostic recorder |0; all child failures retained |
| Connector commit/tree/manifest reads |Tool success; both exact manifests retrieved |
| Initial UTC-only commit reconstruction |0 matches; no identity claim from that diagnostic |
| Original-offset commit reconstruction |Both commit IDs and raw SHA256 values match; -0500 offset |
| Separate offline integrity verifier |0;2 commits,6 trees,10 package files,1,493 members checked |
| Altered commit / manifest / archive part controls |1/1/1; expected identity refusals |
| Workflow YAML/Python and embedded shell syntax |0; no workflow execution |
| Remote complete binary readback / hosted preflight / proof |NOT_ESTABLISHED / NOT RUN / NOT RUN |

The exact local failing operation is name resolution before HTTPS connection or
file download. Python and curl agree. The sandbox-visible DNS configuration is
unavailable; localhost resolution works and the remote connector succeeds.
This supports a local managed network/resolver-visibility boundary. It does not
identify the exact enforcing rule or prove a global host DNS misconfiguration.
No resolver,proxy,firewall,route,permission or sandbox setting was changed.

The diagnostic's summary boolean for scutil was overwritten when it processed
empty stderr. The preserved stdout and hash establish the actual text above.
`records/DNS-INTERPRETATION.json` corrects that annotation explicitly. Original
script,logs,exit codes and the flawed annotation remain intact. No failed route
was rerun to hide or replace that result.

The available binary connector routes failed in U332. Their limitations were
reviewed; the same large-binary calls were not repeated. The successful text
route now independently returns the complete new932,639-byte manifest and
base8,435-byte manifest. Both SHA256 values match the frozen local manifests:

- New:`6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105`.
- Base:`6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7`.

## Commit and input identity

Fresh GitHub API data reconstructs the complete unsigned commit bodies. API
timestamps are normalized; an initial UTC-header reconstruction did not match.
The original -0500 header offset produces the exact expected Git commit IDs.
Raw bytes are retained,with SHA256:

| Commit | Reconstructed raw commit SHA256 |
| --- | --- |
|21c4bdf958627e6a24e8dee9a45d90568b3e3c20|947a3fa64f0ff0908989a01f1388f44f407e79642ea18d7462564e5e89f1babc|
|ac05eaf972b8c98784466ae063fca505aaaf25f4|322245d0c39534c9be74f5dfa2ace4be2d856c1404ddc351f2087ab876d5e584|

A new standalone byte verifier recomputes all six intervening tree hashes and
binds the ten package-file blob IDs to their committed paths. It uses no producer
verification code. Its local positive run checks every archived file's name,
size,mode and SHA256:1,475 new files plus18 reused base files,with no overlap.
The full candidate source hash and its exact import quotation match. The
candidate remains7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6.

The three mutation controls fail at the intended commit,manifest and part hash
checks. These are finite checks of an integrity tool,not mathematical proofs.
Captured API data and local frozen archive bytes were used for this offline
run. It is a separate implementation check by the same agent,not independent
administrative control or remote binary readback. The local adapter explicitly
labels its output as offline. It cannot create a remote-readback passing claim.

## Exact proposed action and recommendation

[APPROVAL.md](APPROVAL.md) specifies the complete reviewed workflow. Publish one
11,609-byte workflow on a new proposal branch; one `ubuntu-24.04` job; token
permissions:{}; job5 minutes; driver180 wall seconds,90 CPU seconds,1 GiB
address space,32 MiB/file,zero core dumps. The sole command is
`/usr/bin/python3 -I -B -`. No install,checkout action,secret,sudo or input execution.
The host label and public-runner model are documented by
[GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

The job downloads26,196,042 bytes from the existing two immutable GitHub commits,
plus eight bounded API metadata responses. It uploads no new proof/source inputs.
It checks the full commit/tree/blob/manifest/archive/member chain and the exact
candidate quotation. Every mismatch,error,missing member,duplicate,unsafe member,
unexpected redirect or incomplete result prevents acceptance. Logs must contain
all1,493 member records,all10 package-file identities,both commits,statement
identity,completion and actual exit0. No marker alone establishes integrity.

GO recommendation:request authorization for this exact integrity-only preflight.
NO-GO:run the hosted TextIO.read proof now. Its smallest remaining execution
blocker is complete remote byte readback,with preflight authorization required
to use the prepared fallback. The workflow has not been published or run.

If integrity passes,read back and assess its complete evidence. Then bind the
existing unchanged macOS candidate workflow to the already published input
commit and request separate proof-run authorization. No rerun or proof job is
implicitly authorized by the integrity job. The original theorem,premises,
repeat,fresh import and two negative controls remain frozen at U329/U331.

The candidate's semantic theorem and actual closure remain unproved. A modeled
TextIO.read error result would not establish native buffer/frame/lifetime
correspondence or composition through inputAllFrom/refund_main. Those obligations,
the existing compiler/runtime premises,and21-snapshot independent replay remain
separate. No logical Success/native exit equivalence or new axiom is introduced.

## Local preservation limitation

During final preservation, the review worktree's .git pointer and its shared
HEAD/gitdir/commondir metadata were absent. git rev-parse exited128. The first
preservation script exited1 before tracker edits; a later Git diagnostic batch
exited129. Cause and issuer are unknown. No Git metadata repair was attempted.
This checkpoint is preserved as files without a new local commit. Root50
protected paths and the mission match their recorded hashes. Both copies of
the frozen U329 and U332 packets match their manifests. A current review Git
diff is NOT_ESTABLISHED. This does not replace remote byte verification.
