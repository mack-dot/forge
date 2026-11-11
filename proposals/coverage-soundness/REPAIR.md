# Coverage-soundness repair of the ledger PR gate (candidate; not installed)

Owner authorization 2026-10-30. Contract: [COVERAGE.md](COVERAGE.md). Candidate tree:
`~/forge-coverage-v1`, branch `coverage-soundness-v1`, one commit on `624c9faf`.
Nothing in this folder changes the installed gate. `end_to_end=false`.

## Non-claims

- Not universal implementation soundness. The theorem below is about the model;
  implementation conformance is bounded testing over recorded traces.
- `VERIFIED` does not mean the PR is correct. It means: C1–C5 hold for the candidate's
  `impl/Ledger.dfy`, and the PR changes nothing that any established claim depends on.
- The original 51 Stage 10 cases are not a holdout after this repair: the four false
  accepts were used to design it. The 16 held-out cases were frozen before any run,
  but were written by the same authors.
- Coverage does not reach compiled artifacts, deployment or runtime.

## Changed files (exact digests in the PR)

| File | Change |
| --- | --- |
| `gate/coverage.py` | new: inventories, change set, Dafny include scan, lock pins, declared consumers, assessment |
| `gate/incremental.py` | outcomes VERIFIED/REJECTED/NOT_ESTABLISHED/UNSUPPORTED (exit 0/1/2/3); coverage assessed after the proof, before the final re-hash; `coverage.py` in the trusted snapshot; full candidate tree saved for replay; `spec_approval` recorded |
| `gate/pr_check.py` | accepts exit 3; cross-checks outcome, exit and coverage record; receipt carries `outcome` and `coverage` |
| `gate/post_pr_report.py` | publishes the outcome; UNSUPPORTED lists findings; untrusted paths rendered as JSON literals; failing status for every non-zero exit |
| `scripts/check_stage_4_local.py`, `scripts/check_stage_4_approval.py` | full-tree candidates; expectations for ledger and approved-spec edits become exit 3; new `uncovered-ts` case; results written to new files |
| `gate/provenance/implementation.lock` | `5f78da21…` → `4e2abe26…`: adds `gate/approval.py`, `coverage.py`, `incremental.py`, `pr_check.py`, `post_pr_report.py`; re-hashes the two scripts |

Trusted computing base growth: one module (about 190 lines) plus about 60 changed
lines in three gate files.

## Phase 1: the four false accepts reproduced

`results/coverage-repair/phase1-repro-0001/`: against the original gate at `624c9faf`,
all four `unsupported` cases exit 0, `ACCEPTED: C1 C2 C3 C4 C5; checked=0; reused=12`,
evidence written. Boundary: `gate/incremental.py` compares three ledger files and the
protected manifest only; `pr_check.py`/`post_pr_report.py` publish that as the PR result.

## Phase 3: independent adversarial review

18 findings, none critical or high. No path to VERIFIED for a non-identical tree.
Mediums: C-01 VERIFIED reachable only for an empty diff (sound, conservative); C-02
Stage 4 harness built partial trees (fixed in the scripts); C-03 the implementation
lock did not bind the PR gate (fixed: new lock); C-04 a dirty base tree is
NOT_ESTABLISHED (kept; message now names which tree). Fixed low items: report text
injection (C-05), TOCTOU between the dependent scan and the final re-hash (C-13),
size caps that dropped the status (C-14), `__pycache__` skip (C-12), missing readers
(booking gate, `tests/Basic.dfy`, Stage 5 tools and the model gate for spec and lock).

## Phase 6: formal model and conformance

`model/Acceptance.dfy`, pinned Dafny 4.11.0: **8 verified, 0 errors**. Proved about the
model: `Safety` (Verified ⇒ tools ∧ authorization ∧ proof ∧ artifact ∧ coverage),
`UnsupportedRestsOnProof`, `ToolFailureIsNotEstablished`, `Terminates`, the inductive
invariant (`InvInit`, `InvStep`) and `ExitCodesDistinct`.
`model/conformance.py` derives the model's facts from each recorded `operation.json`
(never from its outcome) and compares `Decide` with the recorded outcome, exit and
record shape: **49 records, 0 nonconforming** (held-out 32, Stage 4 local 11,
approval 6). This is evidence over recorded traces, not a proof.

## Phase 5: validation

| Suite | Result |
| --- | --- |
| Stage 4 local (`results/coverage-repair/stage4-regression-0001/local-coverage-v2.json`) | 11/11; unchanged ×2 VERIFIED, byte-identical evidence, exact replay 0; apply-edit ×2 UNSUPPORTED (Apply re-checked); uncovered-ts UNSUPPORTED; 6 REJECTED with the original fresh-Dafny codes |
| Stage 4 approval (`approval-coverage-v2.json`) | 6/6; approved ×2 UNSUPPORTED with the bound approval recorded; 4 REJECTED |
| Stage 9 controls on the new lock (`suites-0001/`) | 48/48, v3.1 14/14, F1 9/9, token 34/34, lineage 17/17; bootstrap verifies only `4e2abe26…` |
| Held-out, frozen before any run (`heldout-0001/`) | 16 × 2 passes, 32/32 as expected; identical decisions and findings across passes |
| Frozen 51-case rerun (`bench-rerun-0001/`) | see below |

Held-out outcomes: 1 VERIFIED (identical tree), 11 UNSUPPORTED (docs, mode, symlink,
`__pycache__` payload, deletion, new reader, mixed, gitignore, newline path, valid
ledger alternative, symlinked directory), 3 REJECTED (defect + uncovered edit; weakened
spec; candidate edits the consumer list), 1 NOT_ESTABLISHED (Dafny missing).

Latency and cost, held-out pass 1, measured while two other runs shared the disk:
wall p50 81 s, p95 104 s; CPU p50 18.7 s, p95 20.5 s; total 237 s. The original gate
used about 4 s CPU per incremental case. The added cost is five full-tree inventories
(about 100 MB each) and one full candidate copy per run.

## Frozen 51-case rerun (before → after)

Same frozen manifest `98df0272…`, same case bytes and labels, candidate gate applied to
the base tree (the lock file excluded; the PR gate does not read it). Exit 3 is reported
as `unsupported`; the frozen `classes.json` predates exit 3 and would call it
`tool_failure`, so its numbers are not reused.

| Frozen expectation | Cases | run-0002 (original gate) | bench-rerun-0001 (candidate) |
| --- | ---: | --- | --- |
| accept (seeds, supplied evidence, booking/refund alternatives) | 10 | 10 accept | 10 accept, byte-identical evidence |
| accept (4 ledger valid alternatives) | 4 | 4 accept | **4 UNSUPPORTED** (ledger proof re-checked; dependents not re-established) |
| unsupported | 4 | **4 accept (false accepts)** | 4 UNSUPPORTED |
| defect | 8 | 8 | 8 (same reasons) |
| policy_reject | 11 | 11 | 11 (same reasons) |
| missing_evidence | 10 | 10 | 10 (same reasons) |
| tool_failure | 4 | 4 | 4 |

Exactly 8 of 51 decisions changed, all to UNSUPPORTED; 43 are identical in exit code and
reason. False accepts: 4 → 0. Frozen-label "accept" not met: 0 → 4 (the ledger
alternatives; conservative by contract, not REJECTED). Two passes: 51/51 same
decisions; 10/10 accepted evidence files byte-identical. Cost (pass 1, partly under
concurrent load): all cases wall p50 6.3 s, p95 88.5 s; CPU p50 3.6 s, p95 20.2 s,
total 317.5 s (run-0002: 148.8 s). Incremental gate only: CPU p50 9.3 s (run-0002:
about 4 s). Conformance over the 40 incremental records: 0 nonconforming.

## Remaining trusted assumptions

See COVERAGE.md §7: trusted base obtained outside the PR; git inventories list every
tracked path; the include scan is a regular expression; `DECLARED_CONSUMERS` is a
reviewed list of readers and the main residual risk; the gate reports stale dependent
claims and does not re-run their gates.

## Owner decision

Under this contract any PR that edits `impl/Ledger.dfy` is UNSUPPORTED today, because
booking, the model, the Stage 5 witness and the committed evidence read it. Making such
a PR VERIFIED needs the PR gate to re-run those gates (a scope expansion) or a narrower
claim. This repair chooses soundness and reports the limit.
