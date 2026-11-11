# Stage 10 gate benchmark

A controlled benchmark of Forge's existing gates. Plan: [proposals/stage10-benchmark.md](../proposals/stage10-benchmark.md).
Case list for review: [CASES.md](CASES.md).

This is an internally authored evaluation. The owner and the agent wrote both Forge
and these cases. It is not independent generalization and not a real-PR shadow
study. The real-repository shadow study stays a separate future milestone.

## Files

| File | Purpose |
| --- | --- |
| `cases/NN-<id>.json` | One case: gate, exact edits to the base checkout, supplied evidence, expected class, exit and reason prefix, rationale |
| `classes.json` | Frozen rules that map a gate exit code and reason prefix to an observed class |
| `run.py` | Runner: builds isolated case trees, calls the unchanged gate, records raw results |
| `freeze.py` | Writes `manifest.json`, which hashes every file above and `scripts/exit_stage_10.py` |
| `manifest.json` | The frozen benchmark; the owner approves its SHA-256 before the official run |

## Rules

1. No change to `gate/**`, `policy/**`, `spec/**` or locked files. Cases edit only their
   own isolated copies. Tool-failure cases damage the checker only in that copy.
2. Expected outcomes are frozen in `manifest.json` before any case runs. A mismatch is
   reported and may get a human adjudication record (`adjudications.json` in the run
   folder): gate wrong, label wrong or unclear. Labels never change after a run.
3. Each case runs in fresh APFS clones of a clean checkout of the base commit, under
   `sandbox-exec` with IP networking denied, with only `PATH`, `HOME`, a private
   `TMPDIR` and locale variables. `HOME` stays real because the pinned PyYAML package
   is in the user site-packages and the gates check its bytes.
4. Seed cases run first and write fresh evidence. Supplied-evidence cases derive their
   input from the seed of the same pass by the listed JSON edits.
5. One official run has two complete passes. Pass 1 gives the outcome tables; pass 2
   measures decision reproducibility. A rerun is a new, recorded run.

## Commands

```sh
python3 bench/freeze.py
python3 bench/run.py --manifest bench/manifest.json --dry-run \
    --out results/stage10/dry-run-0001 --work ~/forge-stage10-bench/dry-run-0001
python3 bench/run.py --manifest bench/manifest.json --approved-manifest-sha256 <SHA> \
    --out results/stage10/run-0001 --work ~/forge-stage10-bench/run-0001
python3 scripts/exit_stage_10.py --case report
```

A dry run builds and removes every case tree, checks Dafny starts and the network is
blocked inside the sandbox, and never starts a gate.
