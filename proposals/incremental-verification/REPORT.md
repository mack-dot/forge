# Stage 11 report: incremental verification (candidate 8433ddc5, lock 4e9e7e54…)

Everything below is measured on the owner's Mac (Apple M1 Pro). `end_to_end=false`.
Contract: [CONTRACT.md](CONTRACT.md). Feasibility: [FEASIBILITY.md](FEASIBILITY.md).

## What changed, in one paragraph

PR #27 made the ledger PR gate sound and useless (VERIFIED only for an empty diff). The
Stage 11 candidate adds `gate/obligations.py`: the existing trusted gates (ledger
evidence replay, TypeScript model tests, booking proof, refund proof and hostile tests,
Stage 5 witness) are declared as obligations with the input sets they themselves hash.
For a PR the gate computes the changed paths, the affected obligations and re-runs them
inside an immutable copy of the candidate whose protected files equal the trusted
base's. VERIFIED now means: the ledger proof holds, every change is an input of some
obligation, every affected obligation was re-established on the candidate bytes, and no
reader of a changed file is left without an obligation. The PR report lists each
obligation's scope, claim methods and status.

## Soundness evidence

- Independent adversarial review, three passes. First pass: six blockers (candidate
  harness code executed; `tsconfig` redirect; planted bytecode; count-only witness;
  refund lock race; CI shape). Second pass: one critical (code under test runs inside
  the TypeScript harness process and can rewrite the verdict). Third pass: **no
  blockers**; consistency confirmed. Every exploit has a reproducing smoke case and a
  recorded closure (`results/stage11/smoke-attacks-*.txt`, U183–U186).
- Model `model/Acceptance.dfy` (pinned Dafny 4.11.0): **10 verified, 0 errors**
  (Safety, UnsupportedRestsOnProof, UncoveredNeverRunsObligations,
  StaleDependencyRejected, ToolFailureIsNotEstablished, invariant, exit codes). About the
  model only.
- Conformance of recorded gate traces to the model (`model/conformance.py`): 19 + 34
  records in the final runs, **0 nonconforming**. Bounded evidence, not a proof.
- Regression: Stage 4 local 13/13; Stage 4 approval 6/6; Stage 9 controls on the final
  lock 48/48, v3.1 14/14, F1 9/9, token 34/34, lineage 17/17; bootstrap accepts only
  the new lock.

## Frozen evaluation (18 cases, frozen before any candidate run; `results/stage11/eval-0007/`)

| Kind | Cases |
| --- | ---: |
| match | 12 |
| false accept | **0** |
| false reject | 0 |
| false unsupported | 0 |
| frozen expectation superseded by a design change (see below) | 5 |
| not constructible (frozen edit anchor absent; own authoring error) | 1 (e12) |

Correctly accepted legitimate non-empty changes: **e02** (ledger local-variable rename
with regenerated `evidence.json`: ledger-evidence, ledger-model, booking and
ledger-witness all re-established fresh), **e04** (booking alternative), **e05** (refund
alternative; both refund obligations). Under PR #27 all three are UNSUPPORTED
(`results/stage11/eval-pr27-0003/`). Rejections: e08 stale committed evidence
(`ledger-evidence`), e09 booking defect (`booking`), e11 unapproved spec. UNSUPPORTED:
docs, results records, mixed docs+code, a new Dafny reader (now with the
`UNKNOWN_DEPENDENCY` finding). NOT_ESTABLISHED: Dafny missing.

**Design change after freezing.** The second review showed that TypeScript code under
test runs inside its harness process and could rewrite the verdict, and that a rewritten
witness body could be vacuous. The fix binds `ts/ledger.ts`, `ts/types.ts`,
`ts/refund.ts` and the witness file to the trusted base and protects the harness files.
Consequently e03 (TS refactor), e07 (TS defect), e10 (refund wrapper defect) and e18
(TS change with `node_modules` missing) are UNSUPPORTED, and e06 (harness comment) is
REJECTED as a protected change. Their frozen expectations were **not** edited; the report
counts them separately. None is a false accept.

**Latency and cost** (cold = empty obligation cache; warm = same root, cache populated):

| | wall p50 | wall p95 | CPU p50 | CPU p95 | CPU total (18) |
| --- | ---: | ---: | ---: | ---: | ---: |
| cold | 13.6 s | 39.1 s | 10.5 s | 39.4 s | 258 s |
| warm | 7.4 s | 26.1 s | 7.1 s | 20.3 s | 133 s |

Warm reuse happened in 4 cases (e02, e04, e05, e08) and never changed a decision: 18/18
same decisions across the two runs. PR #27 cold/warm on the same cases are in the
baseline folder; its CPU per case is lower because it never runs dependent obligations.

**Trusted code growth** vs PR #27: `gate/obligations.py` (+~330 lines), `gate/coverage.py`
(assessment rewritten over the obligation graph), `gate/incremental.py` (+~90 lines:
verification tree, obligation run, outcome), `gate/post_pr_report.py` (claim-scope
table), two harness scripts, `scripts/exit_stage_11.py`, the lock.

## Known limitations (also in CONTRACT.md §5)

1. CI shape: dependent gates use macOS pins and need node; on Linux CI every affected
   sub-gate would be NOT_ESTABLISHED. The EXITs hold on the recorded host only.
2. TypeScript changes are UNSUPPORTED until the harnesses isolate the subject.
3. Documentation, tests, new modules, `results/` are UNSUPPORTED by contract.
4. The obligation registry is hand-declared per gate (checked against each bundle).
5. One frozen case (e12) was unconstructible; it is evidence of nothing.

## Incidents (all recorded in unsure.md)

- Four aborted evaluation runs (runner PATH, refund lock race, N1 fix, disk full) and one
  superseded run are kept under `results/stage11/`.
- The evaluation runner deleted the real pinned Dafny executable through a toolchain
  symlink (U188); restored from a byte-identical clone copy, pins verified, runner fixed
  and tested on a disposable fixture (U189).

## Stage 11 EXITs (actual)

| Command | Exit |
| --- | ---: |
| `python3 scripts/exit_stage_11.py --case legitimate-change --eval results/stage11/eval-0007 --baseline results/stage11/eval-pr27-0003` | 0 |
| `python3 scripts/exit_stage_11.py --case stale-dependency …` | 0 |
| `python3 scripts/exit_stage_11.py --case report …` (twice; byte-identical `report.json` `865f0000…`, `report.md` `15dd582f…`) | 0, 0 |
