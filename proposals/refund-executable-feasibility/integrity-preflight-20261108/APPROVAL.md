# Proposed integrity-only preflight: one job, no proof execution

Approval is pending. The current owner instruction explicitly forbids hosted
jobs or expanded scope without approval. No earlier proof-run grant is applied
to this new preflight. The existing published source files remain unchanged.

Approve publication of exactly this [11,609-byte workflow](records/proposed-workflow.yml)
as `.github/workflows/m1-input-integrity.yml` on a new
`proposal/m1-input-integrity-20261108` branch in public `mack-dot/forge`, based
on `8ad9de1e538edd48a2084796510e784913eaef8b`. That one branch push triggers
one job. No rerun,merge,existing-workflow edit or automatic follow-on is included.
Recheck the baseline and trigger definitions before publication.

Workflow SHA256:
`3e7c35a8b3a21a3645f8f966e6ba8058a2a605646c9eb3499d105eed2ed20e78`.
Embedded driver SHA256:
`a22b7aa7496739a189366f6178c1d041dd4dda354dc441cb255221ce3def6812`.
There are no dynamic placeholders or substitutions in this workflow.

The sole executable command is `/usr/bin/python3 -I -B -`, with the exact
embedded9,638-byte driver. The shell is
`bash --noprofile --norc -euo pipefail {0}`. No downloaded file is imported,
executed or extracted to executable paths. No HOL,Poly/ML,CakeML,native refund
binary,proof candidate,repeat,import,negative proof control or21-snapshot replay
runs. This job checks bytes and source quotations only.

Runner:`ubuntu-24.04`,non-root Linux,ImageOS=ubuntu24. It records actual image,
architecture,Python version and Python binary hash. Job token permissions:{}.
No token,secret,checkout action,package install,sudo,cache write,release signing,
deployment or security-setting change. Private0700 scratch directory only.
The standard public-repository runner and fresh-VM model are documented by
[GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Provider isolation,OS,Python/hash/TLS implementation remain explicit trust.
This is a separate hosted checker,not independent administrative control.

Limits:one5-minute job; driver180 wall seconds,90 CPU seconds,1 GiB address
space,32 MiB per file,zero core dumps. Each HTTPS operation has a15-second
timeout. No retries. Errors,mismatches,unexpected redirects,resource failures
or incomplete evidence produce NO-GO. Successful execution must supply actual
exit0 plus the complete expected record set; a marker alone is insufficient.

Network scope is only `api.github.com` and `raw.githubusercontent.com`,for
`mack-dot/forge` and these immutable commits:

- New inputs:`21c4bdf958627e6a24e8dee9a45d90568b3e3c20`,folder
  `proposals/m1-hosted-cf-inputs`:one manifest and three parts.
- Reused base:`ac05eaf972b8c98784466ae063fca505aaaf25f4`,folder
  `proposals/m1-hosted-sat-inputs`:one manifest and five parts.

Exact payload download:26,196,042 bytes. Eight commit/tree API responses each
have a1 MiB bound. No new proof/source payload is uploaded. The only new public
repository file is the reviewed workflow. Per-file identities,actual environment
and failures go to the job log. Complete logs must be preserved and checked.

The driver recomputes both Git commit hashes and six tree hashes,binds all ten
package files to those trees,checks both manifest and archive SHA256 values,
checks every one of1,475 additional and18 base file hashes/sizes/modes,refuses
duplicate or unsafe members,and checks the exact candidate/import quotation.
It treats archives as data and does not use the producer's workspace or cache.
The formal theorem and its actual dependency closure remain unproved by this job.

GO recommendation:authorize this exact bounded integrity preflight.
NO-GO:execute the hosted proof now. Only complete passing integrity evidence can
remove the byte-readback blocker; the frozen macOS proof job still requires a
separate explicit authorization. Native memory/frame,whole-program composition
and21-snapshot replay remain separate. Stage12 unauthorized; end_to_end=false.
