# U338: authorized attempt ended before runner allocation

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Status: **HOSTED_RUNNER_NOT_ASSIGNED**. No mathematical result was produced.

The owner authorized one frozen hosted proof job and its conditional cases.
That job was triggered once. [Run42661020831](https://github.com/mack-dot/forge/actions/runs/42661020831)
finished with conclusion `failure`; its sole job129312292711 finished `cancelled`.
Both are attempt1. There is exactly one run at the published workflow head.
The full job response records `runner_id=0`, an empty runner name, and `steps=[]`.
Successive observations showed the job queued until that terminal result.
No environment probe, input download, HOL child or conditional case ran.

## Exact authorized publication

Workflow commit: `f1e4a080fd4c33aa1072c93fe4757e16805ab484`.
Parent: `8ad9de1e538edd48a2084796510e784913eaef8b`.
Tree: `0a789c996c8d1788e60d985565afd7cd83108db7`.
Only changed path: `.github/workflows/m1-macos-preflight.yml`.
Workflow16385 bytes, SHA256
`1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1`;
Git blob `c6bdbde3f8612de474d1423216efce545c813f25`.
The remote file matched the frozen approved file byte for byte before the branch
update. The branch update used the expected parent as a lease and did not force.
The final branch read still points to the exact published commit.

All12 other workflow identities and triggers were checked against the exact
parent tree. None triggers on this branch push. No other workflow was edited.
The approved manifest, driver, source and controls remain unchanged. Both input
commits remain `21c4bdf958627e6a24e8dee9a45d90568b3e3c20` and
`ac05eaf972b8c98784466ae063fca505aaaf25f4`. U335/U336's complete transfer-integrity
evidence remains intact. This failed attempt did not redownload those bytes.

The exact command remains `/usr/bin/python3 -I -B -`, under
`bash --noprofile --norc -euo pipefail {0}`. One `macos-15` job,15-minute cap,
permissions{},no secrets,privilege,installation,signing or deployment.
The frozen guard requires ARM64 and image `20261104.0514.1` before input execution.
No runner means that guard was not reached: no image identity or substitution
is claimed. Each proposed HOL child retains CPU120s,wall150s,maxheap1536MiB,
4MiB/file and zero core dumps. No limit measurement from a HOL child exists.

## Actual results, not expected proof exits

| Executed command/action | Actual exit/result |
| --- | --- |
| `python3 -B -` frozen-scope/branch/trigger preflight |0; [PREFLIGHT.json](records/PREFLIGHT.json)|
| Create tree and commit | Tool success; no runner trigger yet |
| `python3 -I -B -` remote workflow/commit readback |0; [PRE-TRIGGER.json](records/PRE-TRIGGER.json)|
| Lease-checked branch update | Tool success; one trigger |
| Hosted workflow / sole job | `failure` / `cancelled`; these are provider conclusions, not process exits |
| Environment probe / proof / repeat / import / two negative controls | NOT RUN; actual process exits unavailable |
| Complete job-log request | Tool error404, `BlobNotFound`; response preserved |
| Optional check-run reason request | Connector error400, endpoint not supported; response preserved |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/validate_terminal.py` |0; validates terminal failure evidence only |
| Local stream reader | NOT RUN; there is no hosted log to decode |
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/finalize.py` |0; tracking updated and journal prefix preserved |

The provider reports902000ms run duration and0 billable MACOS milliseconds,
one job with0 reported billable duration. This elapsed interval is not proof
CPU time or observed runner execution. CPU usage,peak RSS,actual runner image,
theorem statements,export hashes and dependency closures are unavailable because
no runner or execution steps are recorded. The artifact-list response is empty.
No host log SHA is invented. Raw API/error response hashes are in MANIFEST.json.

The published API's `started_at` equals its creation timestamp even though
`runner_id=0` and `steps=[]`. That field alone does not establish execution.
The902-second interval is close to the15-minute workflow limit; the precise
scheduler cancellation cause is not established. No capacity,account,billing,
image-availability or deliberate external-cancellation cause is asserted.

## Separate evidence validation and preservation

The local terminal reader imports no producer checker. It independently binds
the exact workflow bytes/blob,parent/change list,current branch,run/head/attempt,
one-run count,full job metadata,job-summary response,timing and empty artifacts.
It checks the preserved404 log failure and all217 manifest-listed files across
U333–U337, plus50 protected paths and mission bytes. This validates the report
under GitHub/connector/hash trust; it does not prove any HOL theorem or establish
independent administrative control. The earlier queued checkpoint is preserved
as history and is superseded by [TERMINAL-READBACK.json](records/TERMINAL-READBACK.json).

The three prior hosted integrity controls remain in-process ValueError
rejections with no separate process exit codes. Only their enclosing checker
had observed exit0. The two proposed negative HOL controls have no actual exits
in this attempt. Prior failures,proof statements,premises and dependencies remain.
No protected file,Stage12,native execution,21-snapshot replay,release signing,
deployment,local Git metadata repair or new local commit was involved.

## Smallest remaining issue

Obtain an assigned GitHub-hosted macOS ARM64 runner that passes the unchanged
pinned-image guard. This is an environmental execution issue before the theorem.
The exact generic `TextIO.read` error-behavior obligation is unchanged and untested
by this attempt. The one authorized job has ended; no retry was made or remains
authorized. Another attempt requires separate approval. Native memory/frame,
whole-program composition and independent full-chain replay remain separate.
