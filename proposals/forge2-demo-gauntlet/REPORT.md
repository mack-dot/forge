# Wave Gate 3: the skeptic gauntlet demo

CURRENT none. Stage 9 deferred. M1 open. Stage 12 unauthorized.
`end_to_end=false`. Not a stage. No protected file changed. No file of
Slices 1 to 3 or of Wave Gate 1 changed. Not gate evidence.

`scripts/demo_gauntlet.py` is a FINITE DEMONSTRATION on the real
components of Slices 1 to 3. A run of it is not a proof and adds no
evidence class. What it shows and its limits:
[docs/demo-gauntlet.md](../../docs/demo-gauntlet.md). Directive: text 1
in the [Wave Gate 1 owner texts](../forge2-m1-conformance/OWNER_TEXTS.md)
("Wave Gate 3"). Entries: `unsure.md` U465 to U467. Runs: 2026-11-19
(UTC), one machine (macOS, arm64).

## 1. Actual results

| EXIT command/check | Actual exit/result | Result |
| --- | --- | --- |
| `scripts/demo_gauntlet.py --acts 2 --flood-mb 64`, attempt 1 (before the review) |0|Act 2 as required |
| `scripts/demo_gauntlet.py`, attempt 2 (before the review; 600 MiB) |0|all three acts; 100 s |
| `scripts/demo_gauntlet.py --flood-mb 10240`, attempt 3 (before the review) |0|10,737,418,240 bytes in 3.67 s; 80 s |
| the one fresh-context review |0 attacks that succeed with exit 0 in the default run; 1 fail-open at a reduced flood size; 2 HIGH (hangs on failure paths); 2 MEDIUM; 5 LOW|repairs in one pass, not reviewed again ([REVIEW.md](REVIEW.md)) |
| after the repairs: `--acts 2 --flood-mb 64`, attempt 4 |3|NOT COMPLETE (partial and reduced), as the repaired script must answer |
| `scripts/demo_gauntlet.py`, attempt 5 |0|80 s |
| `--flood-mb 10240`, attempt 6 |1|Act 3: the sampler matched a shell command of mine whose text held the word "Dafny"; Acts 1 and 2 as required. Sampler changed to program names (no review of that change) |
| `--flood-mb 10240`, attempt 7 (final) |0|10,737,418,240 bytes in 4.03 s; issuer memory 42 to 159 MiB; token after 1.4 ms; 88 s |
| `scripts/demo_gauntlet.py`, attempt 8 (final, default 600 MiB) |0|78 s |
| scratch clone of `5fad5ce4` plus the Wave Gate 3 files (`proposals/forge2-m1-conformance/run_regression.py`), first try |1 (the runner itself)|my own interference: I renamed a record file while the runner copied the tree; no check had run |
| the same, second try: Stage EXIT cases 1, 2, 3, 5, 6, 8 (22); Stage 4 (3); Stage 11 (3) |0 each|28 of 28 |
| the same clone: `check_frozen_pr_gate.py HEAD`; `check_links.py` for `FORGE_MASTER_IDEA.md`, `ROADMAP.md`, `unsure.md`; for all 93 Markdown files outside `results/` |0; 0, 0, 0; 1|the 2 older Stage 9 links, and 1 link of the demo document to this report, which was written after the clone was made (checked again on the staged tree below) |
| the same clone: `exit_slice1.py`, `exit_slice2.py`, `exit_slice3.py`, `exit_m1_conformance.py`, each `--case evidence` |0; 0; 0; 0|bundles `c7f2f41c…`, `2721a293…`, `3cdfebfc…`, `f55391da…`: unchanged |
| the same clone: the unchanged demo with one component broken, 7 mutations (`run_broken_acts.py`) |1 for 7 of 7|unchanged clone: 0 before (74 s) and 0 after (73 s) |
| Stage 7; Stage 9; Stage 10; any HOL process; the EXIT scripts in the working tree |NOT RUN|the EXIT scripts ran in the clone only |
| the staged tree before the commit: `check_frozen_pr_gate.py`; `check_links.py` for `README.md`, `ROADMAP.md`, `unsure.md`, the demo document, this gate's report and review; for all 94 Markdown files outside `results/`; `tsc --noEmit` |0; 0 each (6); 1; 0|only the 2 older Stage 9 links; 0 protected paths among the 15 staged files; after the regression only documents and one expected text of the mutation runner changed |
| commit; push of branch `demo/skeptic-gauntlet`; pull request; hosted `gate/pr_check.py` |NOT RUN when this section was committed|expected hosted result: exit 3 (UNSUPPORTED) |

## 2. Measured values of the two final runs

Each value is from one run. They are measurements of that run, not
guarantees.

| Value | Run with 10 GiB (attempt 7) | Default run, 600 MiB (attempt 8) |
| --- | --- | --- |
| Flood bytes written to the issuer's input, no line end | 10,737,418,240 | 629,145,600 |
| Time to write them | 4.03 s | 0.34 s |
| Answers to the flood | 1 (`message too long`) | 1 (`message too long`) |
| Issuer resident memory before the flood | 42 MiB | 42 MiB |
| Largest sample during and after the flood | 159 MiB | 138 MiB |
| Peak resident memory by the kernel (whole life of the issuer) | 159 MiB | 138 MiB |
| Time from the next valid request to its token | 1.4 ms | 0.9 ms |
| Attempts that did not commit; outbox rows from them | 35; 0 | 35; 0 |
| Outbox rows at the end (both for a committed token) | 2 | 2 |
| Race: processes; committed; rejected as stale | 8; 1; 7 | 8; 1; 7 |
| Act 3: allocations committed (v1 + v2); tokens for the adversary | 84; 0 | 84; 0 |
| Act 3: Dafny, Boogie or Z3 processes seen during the exchange (samples) | 0 (212) | 0 (205) |
| Wall time of the whole demo | 88 s | 78 s |

The name "90-second" in the directive is a name. The measured wall
times of the complete runs were 78 s to 100 s.

Records: `records/run-10gib.json`, `records/run-600mib.json`, and the
two runs before the review (`records/*-before-the-review.json`: 10 GiB
in 3.67 s, memory 59 to 171 MiB, token in 1.3 ms).

## 3. The demo fails when a shown component is broken

`run_broken_acts.py` changes one component file in a scratch clone and
runs the unchanged demo there (default flood).

| Broken component | Demo exit | Failure line of the demo |
| --- | --- | --- |
| clearing: the "rewritten" planted spec loses one approved reason (not equivalent any more) | 1 | `act 1: the clearing tool gave no result for refund-rewrite` |
| refund sink without the signature check | 1 | `act 2a: the sink did not reject an attempt without a valid token` |
| refund sink without the pre-state hash check | 1 | `act 2b: THE RACE DID NOT END WITH EXACTLY ONE COMMIT` |
| refund sink without the settled-request check | 1 | `act 2c: a replay or a stale token was not answered as required` |
| issuer without the line limit | 1 | `act 2: THE ISSUER PROCESS ENDED` |
| wrong checker core (it issues a token for everything) in place of impl/RefundFinality.dfy | 1 | `refund-core: CORE_MODULE: the compiled core is not the module of the evidence record` |
| booking sink without the signature check | 1 | `act 3: the swap run of v3-overbook ended with exit 1` |

7 of 7 mutations make the unchanged demo exit 1. The unchanged clone
exits 0 before and after. For 6 of 7 the failure line holds the text
that the runner expected. For the issuer without its line limit the
runner expected "act 2d" and the demo said "act 2: THE ISSUER PROCESS
ENDED" (the issuer ended during the flood): the right act, another
text. The record `records/broken-acts.json` is that run as it was (it
counts 6); the expected text in the runner is corrected after it. The
wrong checker core is refused by the identity check of the compiled
module, before any attack runs.

## 4. Review

One fresh-context review: [REVIEW.md](REVIEW.md). No path was found
where an attack succeeds and the default full run exits 0. One
fail-open at a reduced flood size (the memory bound meant nothing below
about 250 MiB), two hangs on failure paths, two MEDIUM and five LOW
findings. Repaired in one pass; the repairs were not reviewed again.

One change came after the review and has no review: the process
sampler of Act 3 now looks at the program name of a process. Before, it
matched the text "dafny" anywhere in a command line, and a shell
command of mine whose text held that word made the first 10 GiB run
after the review fail in Act 3 (attempt 6, exit 1). In that run the
attack results of Acts 1 and 2 were as required.

## 5. Limits

- Finite: the listed attacks, one race, one kind of flood, three of
  the sixteen adversary modes of Slice 3.
- Not proved: the issuer, the sinks, the compiled cores, the sandbox
  tool. The source proofs of the cores are not run by this script,
  except that the pinned Dafny verifies each core when it compiles it.
- The memory bound finds an issuer that keeps more than 256 MiB of the
  flood. It is not checked below 512 MiB (the run is then REDUCED,
  exit 3).
- "No Dafny during the exchange" rests on a sampler with ten samples
  per second. A shorter process can be missed. Another Dafny job on the
  machine makes Act 3 fail.
- macOS on arm64 only. `rustc` is the machine's, not pinned.
- The mutation runner and the regression runner are one-off tools.

## 6. Files

- `scripts/demo_gauntlet.py`; `tests/demo-gauntlet/sink_tool.ts` (a
  command-line door to the Slice 1 sink: `init` and `report`).
- `docs/demo-gauntlet.md`.
- `proposals/forge2-demo-gauntlet/run_broken_acts.py`, `records/`.
