# W-repro plan: reproduce tonight's Route A HOL chain from branch `nightshift/A-proof`

Status: PREPARED. NOT RUN. No HOL process was started while preparing.

## Scope and limits
- Source: branch `nightshift/A-proof`, head `dae1b93e0e5ce5c59feefd699497c125d355d3ee`. Every file came from `git show <head>:<path>`.
- Kind: same-machine reproduction from committed sources. It is NOT a clean replay and NOT an independent-machine replay.
- The same toolchain is used (HOL binary, heaps, image under `.toolchain/...` and `results/refund-native-audit-...`).
  The runner checks their digests (`input_sha256`). Before the run, all of them equal the committed `input_sha256` values.
- Older parents are NOT reproduced: 62 older theories (plus `refund-loader-memory-local-20261115/attempt-0001/preload.sml`)
  are read from the stored folders under `/Users/mackianni/forge/results/**`. Their current digests equal the committed
  `input_sha256` values for all 17 Route A cases (checked 2026-11-19, 0 mismatches). This covers tonight's theories
  on top of the stored parents.
- The original run folder `results/m1b-routeA-20261119/attempt-0001/` is not read and not written by the runs.

## Files (all in `repro/run/`)
- Runner copies, byte-equal to the branch: `queue.sh`, `nightshift-run.sh`, `go-routeA.sh`, `run_case.py`, `hash_parents.py`,
  `preload-mf.sml` (digest b9dff759... equals the committed MF-0002 input digest).
- Case sources: `<case>.sml`. 15 of 17 equal the committed `source_sha256`. `R6ffi-0002.sml` and `R6w-0004.sml` differ in ONE
  line each: the directory string of the shared `use` files (`orch-A/r6/round5/` and `round9/` -> `repro/run/r6/round5/`, `round9/`).
  Diffs: `R6ffi-0002.source.diff`, `R6w-0004.source.diff`. Branch originals: `branch-src/`. Shared files `r6/round5/*`,
  `r6/round9/*` equal the committed `*.used-files.pre.txt` digests.
- `MF-0002.sml` is unchanged. It still names the original contract folder in `CONTRACT_DIR` (loadPath only). That path is used only
  when the contract theory is not already in the session. The deps line gives the reproduced contract theory, so the
  stdout line `CONTRACT_LOAD already in the session (deps line)` must appear; compare.py checks it through the stdout diff.
- Link case: `link/run_case.py` (byte-equal to the branch link runner), `link/check.py`, `link/forge_refundExportedContractScript.sml`
  (89fee9c3... equal), `link/inputs/FlatCore.sexp` (58154ddf...dd0d equal; go.sh checks it again before the run).
  `link/go.sh` differs from the branch only in `RUN=` (diff `link/go.sh.diff`).
- Deps files: branch originals in `branch-deps/`; rewritten copies `deps-*.txt`. Table of all 27 rewritten lines (old -> new):
  `DEPS_REWRITE.json`. Rule: `results/m1b-routeA-20261119/attempt-0001/<X>` -> `repro/run/<X>`;
  `orch-A/link/run/attempt-0001/contract-0001/<X>` -> `repro/run/link/contract-0001/<X>`. Older-parent lines are unchanged.
  Each case uses the deps file whose content equals its committed argv (checked).
- `SOURCES.sha256`: digests of every prepared file.

## Order, CPU limits (from committed `cpu_seconds_limit`), deps
| # | case | theory | cpu s | deps |
|---|------|--------|-------|------|
| 1 | L1-0001 | forge_refundRouteA1 | 600 | deps-L1 |
| 2 | L2-0003 | RouteA2 | 1600 | deps-L2 |
| 3 | L2b-0003 | RouteA2b | 1500 | deps-L2b2 |
| 4 | L2c-0001 | RouteA2c | 1500 | deps-L2c |
| 5 | PF-0004 | PrefixFree | 600 | deps-L1 |
| 6 | PX-0001 | PrefixExact | 600 | deps-PX |
| 7 | LO-0006 | LOut | 900 | deps-L1 |
| 8 | LE-0004 | LExit | 1200 | deps-LE |
| 9 | contract-0001 | ExportedContract | 1200 | link/go.sh H1 (cakeml-heap, CertifiedProg cwd) |
| 10 | MF-0002 | ModelFrame | 900 | deps-MF2 |
| 11 | MG-0001 | ModelFrameEvents | 900 | deps-MG |
| 12 | L2d-0001 | RouteA2d | 1500 | deps-MG |
| 13 | E1-0003 | m1bErasureV2 | 600 | deps-L1 |
| 14 | EF-0001 | m1bErasureFrame | 600 | deps-ES |
| 15 | EE-0001 | m1bEraseStep | 1500 | deps-EE |
| 16 | R6base-0001 | R6Base | 900 | deps-R6x |
| 17 | R6ffi-0002 | R6Ffi | 3600 | deps-R6ffi |
| 18 | R6w-0004 | R6Write | 3600 | deps-R6w |

## Run (only after the orchestrator says "slot is yours")
`cd repro/run && ./repro.sh` (foreground). Each Route A case goes through `./queue.sh repro-<case> "<case> <cpu> <deps>"`
(AC power + swap rule; nightshift-run.sh refuses when another HOL runs). The link case waits for the same rule, then runs
`link/go.sh H1 contract-0001`. The driver stops at the first case with actual exit != 0 or a missing marker. No source edits.
Resume: `./repro.sh <case>`.

## Compare (after the runs; starts no prover)
`python3 -I -B compare.py > ../RESULT.json`. Per case: source digest, exit, marker, every CHECKED/FORGE_STATEMENT/STATEMENT
block (paths mapped back, BEGIN/END timing lines ignored), `.sig/.sml/.dat` digests; a `.sml/.dat` difference counts as
explained only if it vanishes after the repro paths are mapped back to the original paths. Diffs go to `../diffs/`.
Classification: REPRODUCED-FROM-BRANCH / DIFFERS (what) / NOT RUN.
