# Approval requested: one retry of the unchanged hosted HOL job

NOT AUTHORIZED. The owner's latest instruction requires separate approval
before this retry. This document and request file do not trigger execution.
CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.

## Exact action

Authorize exactly one call to the connected GitHub tool:

```json
{
  "tool": "mcp__codex_apps__github_rerun_workflow_job",
  "arguments": {
    "repo_full_name": "mack-dot/forge",
    "job_id": 129312292711
  }
}
```

This targets the sole cancelled job of run42661020831. Current attempt1;
expected next attempt2. No dependent jobs exist. No branch write, new commit,
payload upload, workflow change, debug logging or subsequent automatic retry.
If the request fails or its response is ambiguous, inspect read-only status and
preserve the result. Do not issue another trigger or switch to a different route.

GitHub documents that a rerun retains the original SHA/ref and uses the initial
actor's privileges. A specific-job rerun includes dependent jobs, if any; this
workflow has only one job and no dependents. A disabled workflow cannot be rerun.
[Official rerun behavior](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).
The caller needs Actions write access for the rerun tool; no permission changes
are proposed. The job's token permissions remain `{}`.

## Frozen execution scope

Workflow commit: `f1e4a080fd4c33aa1072c93fe4757e16805ab484`.
Original ref: `refs/heads/proposal/m1-macos-preflight-20261106`.
Exact [published workflow](https://github.com/mack-dot/forge/blob/f1e4a080fd4c33aa1072c93fe4757e16805ab484/.github/workflows/m1-macos-preflight.yml),
16385 bytes, SHA256:
`1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1`.
Driver SHA256:
`2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8`.

| Input package | Immutable commit | Manifest SHA256 |
| --- | --- | --- |
|1475 addon files|`21c4bdf958627e6a24e8dee9a45d90568b3e3c20`|`6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105`|
|18 base files|`ac05eaf972b8c98784466ae063fca505aaaf25f4`|`6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7`|

The unchanged workflow downloads26196042 bytes across ten package files from
immutable public URLs. It checks the pinned manifest,part,archive and input
identities; refuses redirects; and checks inputs before and after each child.
The existing [proof approval](../hosted-integrity-run-20261109/PROOF-RUN-APPROVAL.md)
and [exact command review](../proof-approval-review-20261109/REPORT.md) supply
the full unchanged command and bootstrap scope. This approval adds one retry
only; it does not authorize modifying that scope.

Shell: `bash --noprofile --norc -euo pipefail {0}`.
Command: `/usr/bin/python3 -I -B -` with the exact embedded driver.
One `macos-15` job with a15-minute limit. The runtime must pass the ARM64 and
image `20261104.0514.1` checks. Fail closed if unavailable; no image substitution.
No secret use,checkout action,installation,sudo,repository settings change,
release signing or deployment. Private0700 payload root; existing environment
probes and their own temporary-file permissions remain unchanged.

At most five serial HOL children: proof, conditional identical repeat, fresh
import, wrong-exception control, omitted-event control. Each uses the exact
private `HOL/bin/hol --maxheap 1536 run --poly <case>/bootstrap.sml` invocation,
CPU120s,wall150s,4MiB/file and zero core dumps. The job limit is not a guarantee
of runner allocation or completion. Stop on the first unexpected result.
Expected child exits0/0/0/1/1 are requirements, not observed results.

Record complete streams,actual exits,theorem statement,closure,exports,input
hashes and available resource records. Validate the resulting evidence separately.
Preserve scheduling,environment,proof and transport failures without another try.
Do not infer missing CPU/RSS values from provider elapsed/billing fields.

## Conditions before the one call

Recheck the exact run/head/attempt and terminal job state. Stop if another attempt
has started or completed. Recheck conflicting queued/running repository work
and the frozen workflow identity. The current reads show no queued/running jobs
or pending deployment approvals; those observations are not future guarantees.
Workflow enabled state and account Actions restrictions were not observable
through the connector. Do not enable workflows,change settings or route around
a provider refusal. Preserve any refusal as the result of this single request.

No native memory/frame work,whole-program composition,21-snapshot replay,
Stage12,release signing or deployment. The theorem remains unestablished,
not disproved. A successful retry would not complete M1.
