# Revised U334 integrity-only preflight: one job, no proof execution

Approval is pending. The current owner instruction explicitly forbids hosted
jobs or expanded scope without approval. No earlier proof-run grant is applied
to this new preflight. The existing published source files remain unchanged.

Approve publication of exactly this [11,897-byte workflow](records/proposed-workflow.yml)
as `.github/workflows/m1-input-integrity.yml` on a new
`proposal/m1-input-integrity-20261109` branch in public `mack-dot/forge`, based
on `8ad9de1e538edd48a2084796510e784913eaef8b`. That one branch push triggers
one job. No rerun,merge,existing-workflow edit or automatic follow-on is included.
Recheck the baseline and trigger definitions before publication.

Workflow SHA256:
`213160ff1a6b09f1e7def8f2076b2e7abf73e24a6d0f982faac38192fbfe753d`.
Embedded driver SHA256:
`867ef586d6d1a5ed8a5f9efa7efd71c9ed60fcef150ad655c5938d5307c62e72`.
There are no dynamic placeholders or substitutions in this workflow.

The sole executable command is `/usr/bin/python3 -I -B -`, with the exact
embedded9,886-byte driver. The shell is
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

This copy replaces the U333 approval proposal. U333 remains preserved and must
not be published: its default urllib handler followed redirects before checking
the final URL. The revised driver refuses redirects before a follow-up request.
The local controlled HTTP302 case confirms the original defect without network
access. Revised positive control exits0;301/302/303/307/308 controls exit1 with
zero follow-up requests. Exit codes and exact request/rejection records agree.
Python3.10 rejects308 via HTTPError; the actual Ubuntu Python remains untested.
These controls are TESTED evidence only. The hosted preflight is NOT RUN.

The expected source identities are the two remote input commits listed above.
Their commit/tree/blob identities and actual downloaded bytes are checked by
the job. Missing local review Git metadata does not supply or substitute a
commit identity. The new workflow commit must also be read back before its
branch is published. No proof-run approval is included in this request.
