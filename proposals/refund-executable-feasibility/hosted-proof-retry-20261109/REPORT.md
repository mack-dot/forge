# U340: approved retry launches HOL; parent loader fails before the candidate

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Status: **HOL_PARENT_LOAD_ENOENT**. The candidate theorem remains unestablished,
not disproved. No theorem statement was tested by this attempt.

## Authorized action and actual result

Exactly one approved `rerun_workflow_job` call targeted job129312292711.
The owner confirmed U339's single retry; this was not treated as an additional
grant. GitHub accepted the request. [Run42661020831,attempt2](https://github.com/mack-dot/forge/actions/runs/42661020831/attempts/2)
contains one new job129430257438 at unchanged commit
`f1e4a080fd4c33aa1072c93fe4757e16805ab484`. No further trigger occurred.

Preflight confirmed the terminal first attempt,empty current queues and the exact
approved workflow,driver,manifests,candidate and conditional controls. Workflow
SHA256 `1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1`.
Driver SHA256 `2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8`.
No branch,workflow,input,theorem,premise,dependency or setting was modified.

| Executed command/check | Actual exit/result |
| --- | --- |
| `python3 -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/preflight.py` |0|
| Single approved GitHub rerun call | Tool success; attempt2 |
| Hosted sw_vers/sysctl/true/otool |0/0/0/0|
| Exact HOL child,case proof |1; wall_timeout=false; no exports |
| Hosted workflow step |1; first case gate rejects |
| Conditional repeat/import/wrong-exception/omitted-event |NOT RUN|
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/read_streams.py` |0|
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/validate_evidence.py` |1 initially;0 after timestamp-parser correction|
| Initial source lookup / corrected read-only source lookup |1 /0; guessed shell glob failed,then actual paths found|
| `python3 -I -B proposals/refund-executable-feasibility/hosted-proof-retry-20261109/records/finalize.py` |0;50 protected paths and journal prefix preserved|

The preflight record includes the exact approval-file hash. The old
`NOT_AUTHORIZED` wording in frozen proposals remains historical; the owner's
explicit confirmation authorized this single request. No automatic retry remains.

## Runner, inputs and limits

The assigned runner reported Darwin/arm64,UID501,macos15,
image `20261104.0514.1`,macOS15.8.2/build24H232. The required image check passed.
Python3.9.6 SHA256:
`5c5950c62eee5fd227a67e4bdfcde81c9add59799bba0949635f3d5ba9661c26`.
The job retained permissions{},15-minute cap,no secrets,sudo,installation or
settings changes. Its private0700 root and existing environmental controls passed.
mkstemp returned fd4/errno0; read/write matched; denied-read control returned
EACCES13;64MiB memory probe completed. Four saved states loaded. The frozen
original MiniSat path remained unavailable,as expected by the unchanged driver.

All ten package download records match the frozen manifests,including every
part size/SHA256. Total26196042 bytes. Both before/after checks report all1493
pinned input identities unchanged. The hosted driver checks archive/member
identities during extraction. The separate reader checks these complete records
against frozen manifests; it does not claim a second download of every member.
The private libpolyml/libgmp path gate passed after the child failure.

The exact invocation,environment and cwd are in [events.json](records/events.json).
It uses the private `HOL/bin/hol --maxheap 1536 run --poly outputs/proof/bootstrap.sml`,
with cwd at the private `cakeml/basis`. CPU120s,wall150s,4MiB/file and zero core
dumps remained in the frozen driver. No timeout was reported.

Observed capacity:7516192768 memory bytes and49431048192 free temporary-disk bytes.
Provider step timestamps span31 seconds. The provider-log interval from invocation
to child-result is approximately17.468184 seconds,including wrapper/log handling;
it is not a direct process-wall measurement. Provider run duration343000ms includes
the wait. Billing reports0 MACOS milliseconds across both attempt job IDs; the
reported job count2 is cumulative,not two jobs in attempt2. Actual child CPU time
and peak RSS were not instrumented and remain unavailable.

## Precise failure and smallest remaining issue

The emitted [bootstrap](records/decoded/proof/bootstrap.sml) calls:

```text
QUse.use "<private-root>/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/.hol/objs/forge_refundReadBoundaryTheory.sig"
```

The actual [stderr](records/decoded/proof/stderr.log) reports `TextIO.openIn`,
`SysErr("No such file or directory", SOME ENOENT)` at:

```text
<private-root>/results/refund-native-audit-2026-11-04/attempt-0010/model-0007/.hol/objs/.hol/objs/forge_refundReadBoundaryTheory.sig
```

The single `.hol/objs` path is present in the verified addon manifest; the doubled
path is not. HOL's virtual file loader resolves the supplied physical theory path
again. Earlier U282 and U291 record the same loader path convention. Read-only
source inspection finds QUse delegating to HOLSource and HOLFileSys's virtual
read translation. The hosted failure identifies an orchestration defect in the
frozen bootstrap,not missing transferred bytes or a mathematical counterexample.
The exception comes from host ML file loading.

Stdout stops after `PHASE basis-theory-load`. It never reaches
`PHASE cf-library-load`, `CF_LIBRARY_LOADED`, `PHASE unchanged-source` or
`CHECKED read_error_generic`. No candidate theorem export or new dependency
closure exists. [FROZEN-UNEXECUTED-STATEMENT.txt](records/FROZEN-UNEXECUTED-STATEMENT.txt)
preserves the intended quotation only; it is not theorem output.

Smallest next issue:review the bootstrap's theory-file addressing against HOL's
documented virtual paths,including parent loads and later import loads. U337/U339
static review did not catch this integration defect. No correction or new attempt
was made here. A changed orchestration and any further execution require a separate
decision. The theorem statement,premises and trusted dependencies need no change
on the evidence obtained. Native memory/frame,whole-program composition and
independent full-chain replay remain separate.

## Complete evidence and preserved failures

Full decoded job log67204 UTF-8 bytes,SHA256:
`7fea30873cceeb1b199bfa468ccb4dde56ad2a4f884b95ef902241185c7d7cca`.
The separate stream reader reconstructs all base64/zlib chunks and checks their
lengths and hashes before writing inert artifacts:

| Artifact | Bytes | SHA256 |
| --- | ---: | --- |
|bootstrap.sml|3054|`0a368ca0b0e9bd6b3949057e538ab7135cdd4fde9f7083dc763b9a0ad7858084`|
|stdout.log|699|`875f9a2bfd8807429a1a50aa7a098e304dd8d21ce82a2fe44437d73c872439aa`|
|stderr.log|96851|`8a66faefa79bbc1ec0c5661b29458a669fae464e86a06e8778e55d7c1f7c8674`|

The independent reader binds exact event counts,downloads,input checks,identity,
private runtime,invocation,exit1,stop condition and provider job/run records.
Its initial exit1 came from local Python's rejection of seven-digit timestamp
fractions. The initial source and error are preserved. The corrected reader
truncates only sub-microsecond precision for the approximate interval; raw logs
and timestamp strings are unchanged. Its exit0 validates this failed execution's
evidence,not a theorem. A guessed read-only source path also failed1 and is retained.

The three U335 integrity controls remain historical in-process rejections,with
no separate process exits. The two negative HOL controls did not run here.
Provider/control-plane,OS,Python/hash/TLS,connector and cached ancestry trust
remain explicit. Independent reader code is not independent administrative
control or full-chain replay. No Stage12,protected change,release signing,
deployment,local Git repair or local commit occurred.
