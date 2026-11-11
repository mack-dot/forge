# Executable acceptance tests — planned, not executed

These scripts dispatch existing gates and inspect their recorded outcomes.
They do not implement proof semantics or create authoritative evidence. Current
validation covers syntax, patch preimages and fixture anchors only. No Linux
proof, new CI run, benchmark or savings result is claimed.

## Local or existing Linux runner checks

Use a fresh, authorized Linux/x86_64 checkout of the approved post-merge commit,
with its pinned Python/Dafny/Z3/validators already installed. Node and packages
must be installed for node and booking-abc (B invalidates the ledger model).
Ledger-source itself does not need Node. No new infrastructure is required.
Keep this reviewed harness outside the trusted/candidate source tree. Invoke it
with the pinned interpreter. Supply actual absolute paths and the approved
40-character commit, not a branch name or a guessed future merge SHA.

```sh
forge_trusted=/absolute/path/to/fresh/trusted-checkout
forge_harness=/absolute/path/to/reviewed/proposals/linux-ci-readiness
forge_commit=OWNER_APPROVED_40_CHARACTER_MERGED_COMMIT
"$forge_trusted/.toolchain/ci-python/bin/python" -I -S -B "$forge_harness/acceptance_linux.py" --trusted "$forge_trusted" --expected-commit "$forge_commit" --suite node --out "$forge_trusted/build/acceptance-node"
"$forge_trusted/.toolchain/ci-python/bin/python" -I -S -B "$forge_harness/acceptance_linux.py" --trusted "$forge_trusted" --expected-commit "$forge_commit" --suite ledger-source --out "$forge_trusted/build/acceptance-ledger"
"$forge_trusted/.toolchain/ci-python/bin/python" -I -S -B "$forge_harness/acceptance_linux.py" --trusted "$forge_trusted" --expected-commit "$forge_commit" --suite booking-abc --out "$forge_trusted/build/acceptance-booking"
```

The placeholder commit must be replaced. These commands are NOT RUN. Reuse a
checkout for the three suites only while its obligation cache is still absent
at the start of booking-abc. Never delete previous results to obtain a cold run;
use another fresh checkout. Raw checker codes/logs are retained even on failure.

| Test | Actual command behavior required | Expected result, not observed here |
| --- | --- | --- |
| Node | scripts/javascript_env.py checks executable version/hash, package-lock and package contents | 0, only with exact Linux pins |
| Node tampering | Prepend a directory holding a one-byte-altered copy of the real Node binary to the child's PATH | 1 with Node executable differs from pin, before that binary can execute; original installation unchanged |
| Ledger source | gate/gate.py proves C1–C5 twice on actual Linux; compare evidence bytes and profile | 0 twice; source_proof; Linux pin bindings; byte equality |
| Ledger defect | gate/gate.py on existing bugs/off_by_one.dfy | 1 with VERIFICATION_REJECTED; no evidence |
| Booking A cold | Incremental gate on the frozen `<`→`<=` implementation edit, empty receipt cache | 0; exact affected set ledger-proof + booking; booking fresh, all commands 0, complete coverage |
| Booking C warm | Same candidate and complete inputs in the same trusted checkout | 0; same key/evidence, reused=true, unchanged cache bytes, no fresh booking command log, canonical evidence unchanged |
| Booking B dependency invalidation | Keep A; rename ledger local variables (`debit`→`remaining`), leave committed macOS evidence unchanged | **2 overall** at the current contract; booking key changes, no stale reuse, booking runs fresh; EVIDENCE_PROFILE prevents full acceptance |
| Uncovered code | Add a new impl/Extra.dfy to the candidate without an approved covering obligation | 3 UNSUPPORTED with UNCOVERED_CHANGE; no evidence |

B establishes safe invalidation and refusal only. **It does not complete a
positive Linux ledger-change acceptance test.** After a separate approved
per-profile evidence design, freeze a positive B fixture with exact regenerated
Linux evidence and require exit 0 plus all ledger/booking/model/witness
obligations. Do not change B's expectation after seeing a result.

Do not treat repeated command records in reused receipts as fresh executions.
Record fixture file hashes, source tree, runtime/pin digests and actual child
exit codes. The harness emits environment.json, per-command logs and durations,
input manifests, gate operations, cache identities and result.json. Its result
explicitly does not claim a genuine GitHub PR demonstration or release admission.

## Genuine GitHub PR acceptance

After #30 merges, create a branch from the exact current approved main. Apply
booking-a.patch only; inspect and commit its one-file diff. Open a PR only after
authorization. No changes to gate, policy or workflows belong in that PR. The
existing pull_request_target workflow must use the approved base, check the
actual candidate commit and emit a fresh forge-proof-report artifact.

From authenticated GitHub GETs, save the run JSON, jobs JSON, artifact metadata
and original ZIP. Use the artifact ID from that run; do not accept a PR-provided
URL, digest or fabricated receipt. Check run attempt, base/head, expected
workflow, actor and branch scope. Then run:

```sh
python3 -I -S -B audit_ci_artifacts.py --zip forge-proof-report.zip --artifact-json artifact.json --run-json run.json --expected-head ACTUAL_PR_HEAD --expected-base ACTUAL_APPROVED_BASE --case A
python3 -I -S -B audit_ci_artifacts.py --zip forge-proof-report.zip --artifact-json artifact.json --run-json run.json --expected-head ACTUAL_PR_HEAD --expected-base ACTUAL_APPROVED_BASE --case C
```

NOT RUN. Use the script's full path and real values. The script binds ZIP bytes
to independently retrieved GitHub metadata, then checks run/receipt/evidence,
coverage, fresh booking execution and replay. It has no admission authority.
Before approving such a run, also verify the job's trusted workflow/base and
runner/toolchain logs; a local JSON file alone cannot authenticate GitHub.

**C must fail as unestablished under the current artifact layout**, because it
omits replay operation.json. The optional separately reviewed retention patch
makes that record observable. It preserves current report artifact layout.
Missing observation is not a failed proof and is not successful reuse.

For B with an old receipt actually present, execute the reviewed booking-abc
harness in the **same ephemeral trusted Linux job** as A/C, under a separately
reviewed workflow invocation, or on the existing authorized Linux environment.
Do not restore a cache from the PR, invent a trusted receipt, or call a cold run
in a second job an invalidation demonstration. A separate genuine ledger PR
still requires the per-profile evidence design. No persistent cache is proposed.

## Measurement contract

| Quantity | Source and rule |
| --- | --- |
| Correctness | Existing gate exits, actual Dafny/audit logs, expected claim methods, complete coverage, source/environment/policy digests; no method upgrade |
| Cold/warm/invalidated wall time | perf_counter_ns around each real gate process; A/C/B labelled separately; include replay separately from initial PR check |
| Job/run duration | GitHub job/step start/end timestamps and run attempt; distinguish queued time, runner setup, dependency setup, gate and upload/report overhead |
| Billed runner-minutes | Authenticated Actions billing/usage data with billing period, runner class and attempt; record returned units/multipliers. Zero billed usage is not zero execution. Missing billing data stays unknown |
| Observed runner-minutes | Sum job elapsed seconds / 60, separately labelled; not an estimate of billable usage or unobserved allocation overhead |
| Obligations considered | Registry IDs inspected for dependency selection; ledger snapshot members are a separate count |
| Executed/reused | From current operation status and fresh logs; exclude historical commands/duration inside reused records; record unaffected/not-selected separately |
| Cache adoption | Eligible affected obligations with a matching trusted prior receipt; hits/eligible, plus hits/affected. Report both denominators. No assumption of cross-job adoption |
| Invalidations | Prior key/receipt exists; relevant digest changes; new key differs; old receipt not used; fresh command log. Distinguish retained old bytes from discarded/expired entries |
| Evidence discovery/validation | Separate timers around lookup/key validation are not present today. Mark unknown; a separately reviewed observational change is required to isolate these costs |
| Provenance | Exact source/runner/pins, trusted workflow run and artifact digest; CI receipts do not confer merge approval or signed release admission |

No cost/savings comparison until the same workload, environment and scope have
real comparable measurements. No Stage 12 or SPM integration is part of this plan.
