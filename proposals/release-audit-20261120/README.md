# Release audit 2026-11-20: release-readiness table

Base: `origin/main` `058eabcb`. Branch `chore/release-cleanup-and-demo-audit`. `end_to_end=false`. M1-B OPEN.
Stage 9 deferred. This audit proves nothing. A pass below is a FINITE TEST on one machine (a shared, loaded Mac;
every time is indicative). Expected results and commands that did not run are marked NOT RUN.

Reports: [AUDIT1_HYGIENE.md](AUDIT1_HYGIENE.md), [AUDIT2_DEMOS.md](AUDIT2_DEMOS.md),
[AUDIT3_DOCUMENTS.md](AUDIT3_DOCUMENTS.md).

## Pre-flight

| Check | Result |
| --- | --- |
| Open pull requests of the merge queue at the start | 76 (Gate F2a, Stage 9 lock rebind; protected files). The owner chose to start the audit after pull request 79 merged; 76 stays open |
| Protected or frozen paths changed by this branch | 0 |
| New packages | 0 |
| Tracked evidence record files changed | 0 |

## Audit 1: hygiene and privacy

| Check | Result |
| --- | --- |
| Real secrets in tracked files | 0 |
| Real secrets in the history reachable from `main` (526 commits) | 0 |
| Files with a local path, user name or host name | 2,065 files; 2,039 of them are records, hashed files or append-only logs and MUST NOT change |
| Source files with a machine path that broke on another machine | 9 V1.1 files: REPAIRED (lookups through `FORGE_RUSTC`, `FORGE_TOOLCHAIN_ROOT`, `FORGE_DAFNY`, or the repository's `.toolchain`) |
| Other source files with a machine path (7) and documents (9 files, 33 hits) | NOT changed; listed in AUDIT1_HYGIENE.md |
| Tracked files over 1 MB | 11 (45.1 MB); each is a record or hashed by a record; none removed |
| Tracked build leftovers | 0 |
| LICENSE on `main` | ABSENT (exists only in open pull request 14): owner's decision |

A scrub of the 2,039 record files is not possible without changing bundle digests. The repository is private.

## Audit 2: demos from a clean clone (actual exit codes)

| Demo | Command | Exit | Result |
| --- | --- | --- | --- |
| Gauntlet | `python3 scripts/demo_gauntlet.py` | 0 | all three acts as documented |
| Gauntlet, no Dafny | same, toolchain removed | 1 on `058eabcb`; 2 after the repair | documents promise exit 2 |
| Unbreakable store | `bin/forge-airlock demo --json …` | 0 | 8 of 8 blocked, $0.00 leaked (604 s) |
| Archia showcase | `examples/archia_mcp_showcase/run_showcase.py` | 0 | 32 of 32 checks |
| Archia evidence | `bin/forge-mcp-proxy verify-evidence` (3 stores; tampered copy) | 0, 0, 0; 1 | tampered copy refused |
| Video cut on `058eabcb` | `demos/video_cut/run_recording_take.py --fast` | 2 | BROKEN on `main` by the combination of pull requests 72 and 73 |
| Video cut after the repair, second clean clone | same | 0 | 68 shots, 0 failed; `test_video_cut.py` exit 0 (39 of 39) |
| Self-repair demo | `examples/universal_self_repair/run_demo.py`; `--self-test`; `tests/primitives_v2/test_demo.py` | 0; 0; 0 | 16 of 16 checks; 13 canaries |
| Quickstart steps 1 to 6 | as written in `docs/quickstart-5min.md` | 0 ×5; 3 | step 6 exits 3 as documented |
| HAL 9000; web showcase | — | NOT RUN | not on `main` (deleted on the owner's word, 2026-11-20). The 23-check count, the zero-Node check and `run_as_nobody.sh` cannot be checked. OS user separation stays NOT TESTED |

After the stale cosign label of the video cut was corrected (a later commit of this branch), the video take was
NOT RUN again; `py_compile` of the changed file gave exit 0.

## Audit 3: documents

| Check | Result |
| --- | --- |
| Numbers checked against committed JSON records | 116: 98 match, 2 mismatches corrected, 16 have no JSON record (they exist only in ROADMAP tables) |
| False statements corrected in living documents | 6 (CI, the Slice 1 sink state, the merge button, unmerged work, cosign through Node) |
| A paper, a "Forge for Dummies" document, `scripts/reproduce_paper.py`, a root `ACCEPTED_ASSUMPTIONS.md` | ABSENT on `main`; no link added; not written |
| Proposed renames not made (they touch bundle subjects) | the answer `INFEASIBILITY_PROVED` of an unproved Rust check; the folder name `unbreakable_store` |

## Audit 4: clean scratch clone of the audit branch (`e847e5ee`)

| Check | Exit / result |
| --- | --- |
| Stage EXIT cases 1 to 6, 8, 11 (28 cases) | 28 of 28 exit 0 |
| `check_frozen_pr_gate.py` | 0 |
| Bundles rebuilt in the clone and compared with the tracked records: Slice 1, Slice 2, Slice 3, M1 conformance, native silicon sink | exit 0 each; byte-identical each |
| Goal 20 SDK bundle | NOT RUN. Its tracked record does not reproduce on `main`: 20 of 64 subject files changed in pull requests 68, 72 and 73. A new record needs a Dafny run and the owner's word |
| Goal 21 intent bundle | NOT RUN (not in the regression runner) |
| Stage 7 (Docker), Stage 9 (deferred), Stage 10, any HOL process | NOT RUN |
| Link check over all 449 tracked Markdown files | exit 1: 2 missing targets, both older than this audit: `docs/stage9-history-audit.md` and `proposals/provenance-receipt-repair.md` link to `results/stage9/receipt-repair-published/README.md`, which is not tracked. NOT changed |
| `scripts/exit_archia_mcp.py --case build`; `scripts/exit_universal_primitives.py --case build`, `--case demo` (after the repair of their pre-merge checks) | 0; 0; 0 |
| V1.1 cases that need Dafny (`proofs`, `mutations`, `evidence`, two suite cases) after the tool-lookup repair | NOT RUN |

Two EXIT scripts changed (pre-merge checks are "not applicable" after their own merge; tool lookups). Both hash
themselves into their bundles, so the bundle digests in entries U744 (`13608d7e…`) and U912 (`100476fe…`) are not
reproduced by the changed scripts. No tracked record file holds those digests.

## For the owner's hands

- Merge of this pull request and of pull request 80 (assurance-chain investigation). Pull request 76: explicit word.
- Stale pull requests and merged branches: two commands as TEXT in AUDIT1_HYGIENE.md section 4 (close 34 and 36;
  delete 52 merged remote branches). Nothing was closed or deleted. Unsure items are left out of the commands.
- LICENSE; a new Goal 20 record; the two renames; whether the paper, the "Forge for Dummies" document and
  `reproduce_paper.py` are to be written.
- No `sudo` step and no signing step is pending from this audit. OS user separation has no artifact on `main` to test.
- One live model call was made by the video `--fast` take with the API key of the environment (the runner's design).
