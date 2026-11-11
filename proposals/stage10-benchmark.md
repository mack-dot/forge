# Stage 10 replacement: GATE BENCHMARK (proposal; nothing here has run)

Owner direction, 2026-10-29: "instead of shadow a repo we come up with benchmark
tests in here in another folder". This proposal replaces Stage 10 SHADOW MODE.
ROADMAP.md changes only after the owner approves this text.

## Purpose

Measure how Forge's existing gates classify a fixed corpus of PR-like changes,
with the expected outcome of every case fixed before any gate runs.

## What changes and what does not

- New folder `bench/`: cases, labels, a frozen manifest and a runner.
  Results go to `results/stage10/`.
- No change to `gate/**`, `policy/**`, `spec/**`, `spec.lock` or any locked
  file. The gate is the thing under test. The runner only calls existing gate
  entry points (`gate/gate.py`, `gate/booking.py`, `gate/refund.py`, …). It must
  not implement a verifier (EXIT command conventions).

## Case format

One folder per case: `bench/cases/<domain>/<id>/` with
- `case.json`: domain, base revision or fixture, the exact gate command, the
  expected class, the expected reason prefix, and a one-line rationale;
- the changed files (the "PR") and any supplied evidence.

## Expected classes

| Class | Meaning | Expected gate result |
| --- | --- | --- |
| `accept` | Legitimate change with valid evidence | exit 0 |
| `defect` | The change violates an approved claim | exit 1, checker rejection (for example Dafny exit 4) |
| `missing_evidence` | Required evidence is absent or unbound | exit 1, evidence or binding reason |
| `policy_reject` | Intentional policy rule (unapproved spec, forbidden assumption, wrong method) | exit 1, policy reason |
| `unsupported` | The change touches code with no claim | no acceptance; reported as "no claim", never as verified |
| `tool_failure` | Injected checker failure (missing tool, timeout) | exit 2; never a pass or a defect |

## Corpus (first version)

Domains Forge already gates: ledger, booking, refund, and a few binary/ELF
cases if their run time allows. Target about 36 cases, at least 4 per class.
The exact case list, with file hashes, comes as a second approval before any run.

## Integrity rules

1. Freeze first: `bench/manifest.json` hashes every case file and label. The
   owner approves its hash. The runner refuses a different manifest.
2. One recorded run of the whole corpus. Keep every failure. A rerun is a new,
   recorded run; never replace numbers.
3. A disagreement between the label and the gate gets a human adjudication
   record: gate wrong, label wrong, or unclear. Never change a label silently.
4. A tool failure is never counted as a pass or a defect.

## Measurements

- A confusion table: expected class against observed class, per domain.
- False accepts (most severe), false rejections and wrong-reason rejections.
- Wall time and verifier process seconds per case: p50 and p95.
- Compute cost per case (process seconds on the recorded host).
- Human effort: adjudications needed.

## EXIT

| Planned EXIT command | Required behavior |
| --- | --- |
| `python3 scripts/exit_stage_10.py --case report` | Checks the frozen manifest, reads the real run log, confirms every case ran once, and reproduces the confusion table and timings. Exit 0 means a complete, reproducible measurement. It does not require a perfect score: false accepts are reported as findings. |

## Limits (stated in the report)

- The corpus is synthetic and written by the same people (owner and agent)
  who built Forge. It is not a sample of real PRs and not independent.
- No operational data over time (the reason shadow mode existed) and no
  false-positive rate for real engineering work.
- The clean-room external verification challenge (owner's next experiment)
  is the later step that adds independence.
- `end_to_end=false`.
