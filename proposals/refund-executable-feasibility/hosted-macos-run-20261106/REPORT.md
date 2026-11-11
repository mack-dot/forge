# U324: Hosted temporary-file boundary passes; installation path denied

CURRENT none. M1 open. Stage12 unauthorized. end_to_end=false.

The one authorized hosted job completed. Its Python step exited78 after
mkdir("/Users/mackianni",0700) returned EACCES13. SAT did not start. This is an
installation-path permission failure on the hosted VM. It is distinct from the
local pinned runtime's /var/tmp EPERM. No theorem was attempted or refuted.

[Actual run](https://github.com/mack-dot/forge/actions/runs/42292059389)
and [job](https://github.com/mack-dot/forge/actions/runs/42292059389/job/128147719439).
Run attempt1; job128147719439. API status completed/failure agrees with the
log's actual exit78. The job is terminal; no second job or rerun was requested.

| Executed operation | Actual result |
| --- | --- |
| PolyML showParent inspections | Process exits0/0; five-state ancestry identified |
| Input packaging,extraction and workflow static checks | Process exits0 |
| Remote input and workflow publication | GitHub tools succeed; no process exit inferred |
| sw_vers,sysctl hw.memsize,/usr/bin/true | Process exits0/0/0 |
| access(/var/tmp,W_OK) | Return0; errno0 |
| mkstemp(/var/tmp/forge-m1-preflight-XXXXXX) | Descriptor3; errno0 |
| Temporary write/read |33 bytes; exact equality |
| Denied read of own mode000 file | EACCES13 as required |
| Memory touch |67108864 bytes |
| mkdir(/Users/mackianni,0700) | EACCES13; enclosing step exit78 |
| Pinned HOL/SAT execution | NOT RUN |
| Separate API/log/source readback and preservation checks | Process exits0 |

The actual runner is macos-15-arm64,image20261104.0514.1,macOS15.8.2 build24H232,
Darwin24.6.0,UID501. It reports7516192768 memory bytes and49423114240 free
/var/tmp disk bytes. The64MiB probe does not establish full HOL resource adequacy.
Python is3.9.6; executable SHA256
5c5950c62eee5fd227a67e4bdfcde81c9add59799bba0949635f3d5ba9661c26.
GitHub runner2.338.2; provisioner20261103.629,commit15dbd9ccb5dbf34fae002b6ed1a2670f52df37bc.
Token permissions were Metadata:read only. Provider isolation remains assumed;
this was not a separately controlled full-chain replay.

GitHub's timing API reports0 billable macOS milliseconds,one job,and12000ms run
duration. The standard public-repository runner class is documented as free:
[GitHub runner specification/pricing](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
The run-specific usage supports zero metered compute charge; no account invoice
or unrelated storage/account charges were inspected.

The input-only commit is ac05eaf972b8c98784466ae063fca505aaaf25f4.
It adds six files only: five archive chunks and INPUTS.json. Directory readback
matches every Git blob SHA and byte count. The archive is15372504 bytes and
contains18 necessary files totaling126126280 bytes. These are the pinned HOL
executable,five saved states,MiniSat,two dependent libraries,unchanged diagnostic,
startup configuration and notices. Seven files match U320 bindings. Additional
parent hashes pin current bytes; they do not establish independent bootstrap
provenance. INPUTS.json records every path,size,mode and SHA256.

Manifest SHA256:6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7.
Unchanged SAT source SHA256:bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108.
Workflow commit:a599bf6c1e8e568bc1705468754edf959b274b6a.
Workflow SHA256:f83eaada408fc4adf8f900a908b5b326440bff5a352323ef248c9300b4f2c88c.
Remote workflow bytes match local preparation. Its commit changes only the new
workflow file. Neither commit changes protected files or the default branch.
The VM failed before any input-bundle download or pinned-tool execution.

The complete retrieved log is job-128147719439.raw.log,24364 UTF-8 bytes,
SHA2563353e60dea84993945265b204c8cf9b52e0ebb400814c04cf9456f12c72a7c53.
It retains provider timestamps to preserve the requested exact log. The derived
normalized log removes provider timestamp prefixes and ANSI escapes; it is not
represented as the raw stream. The API metadata and raw log were fetched
separately. Their review is not an independent organization or proof replay.

Readback found a latent generation bug: INPUT_MANIFEST_BYTES became INPUT_8435.
The initial static check missed this key-binding error. It was not reached in
the hosted run and did not cause EACCES. A local revision fixes the key and
proposes exactly two privileged directory-setup commands. It has not run.
[Exact next action and approval boundary](NEXT-ACTION.md).

The first authorization covered one run; it is consumed. A second run and the
two privileged setup operations require new explicit approval. No broad
permission change,sandbox disabling,heap relocation,alternate solver,rebuild,
protected change,Stage12,release signing or deployment occurred. Source readback
matches50 protected paths,the frozen mission and all18 input sources.

Physical ffiread correspondence,full native I/O correctness and the21-snapshot
independent replay remain unestablished. Logical Success,modeled FFI events,
process exit and physical OS behavior remain distinct. Previous U310/U315
proof claims are not broadened by these observations.
