# Release audit 3 (2026-11-20): cross-document truth and number reconciliation

Base: `main` = `058eabcb` (branch `chore/release-cleanup-and-demo-audit`). CURRENT none; M1-B open; Stage 9
deferred; Stage 12 unauthorized; `end_to_end=false`. Documents only. No commit, no push, no Dafny, no HOL. No
protected, frozen or bundle-subject file changed. `unsure.md` NOT changed (the orchestrator adds the entry).

## 1. Method and scope

- Documents named by the directive: `README.md`, `ROADMAP.md` (status note, the top sections to line 500, every
  `CURRENT` line), `FORGE_MASTER_IDEA.md`, `docs/STATUS.md`, `docs/claims.md`, `docs/quickstart-5min.md`,
  `proposals/forge2-finish-line/ACCEPTED_ASSUMPTIONS.md`; also `docs/VIDEO_STORYBOARD.md` (it names absent
  documents and merge states).
- Each number was compared with a committed JSON record on `main` (path and key below), or, where no JSON
  exists, with the tracked file or text record that the number describes (marked "text" or "computed").
- Bundle subjects (read-only): every `.md` file whose current SHA-256 occurs in a committed file (102 such
  hashes; list in section 7), plus the subject lists of `scripts/exit_goal20_sdk.py` (`src/airlock/PROTOCOL.md`,
  `docs/quickstart-5min.md`, `proposals/forge2-goal20-sdk/{BRIEF,DESIGN,REVIEW}.md`),
  `scripts/exit_goal21_intent.py` (`proposals/forge2-goal21-intent/DESIGN.md`), `scripts/exit_archia_mcp.py`
  (`src/mcp_proxy/*`, `examples/archia_mcp_showcase/**`) and `scripts/exit_universal_primitives.py`
  (`src/primitives_v2/**`, `examples/universal_self_repair/**`, `sdk/py/forge_primitives.py`).
  `README.md`, `ROADMAP.md`, `FORGE_MASTER_IDEA.md`, `docs/STATUS.md` and `docs/VIDEO_STORYBOARD.md` are in
  none of them. `docs/claims.md` IS a hash subject (not edited).

## 2. Number ledger (summary)

| Document | Numbers checked | MATCH | MISMATCH (fixed) | NO JSON RECORD |
| --- | --- | --- | --- | --- |
| `README.md` (before the edit) | 33 | 30 | 2 | 1 (text record) |
| `README.md` (numbers added by this audit) | 13 | 13 | 0 | 0 |
| `docs/claims.md` (subject) | 4 | 4 | 0 | 0 |
| `docs/quickstart-5min.md` (subject) | 5 | 3 | 0 | 2 (text or run now) |
| `docs/STATUS.md` (merge commits, record counts) | 20 | 20 | 0 | 0 |
| `FORGE_MASTER_IDEA.md` (spot check of record-backed counts) | 16 | 16 | 0 | 0 |
| `ROADMAP.md` top sections (sampled) | 25 | 12 | 0 | 13 (ROADMAP-only rows) |
| total | 116 | 98 | 2 | 16 |

The 2 mismatches, in full:

| # | File:line (before) | Before | After | Record (path, key, value) |
| --- | --- | --- | --- | --- |
| M1 | `README.md:175` | "300 property runs and 4,131 state comparisons" | "300 property runs and 3,506 state comparisons" | `results/stage3.json`, `property_result.counters.compared_steps` = 3506 (also `results/stage3/typescript-evidence.json`; ROADMAP Stage 3 rows say 3,506). 4,131 occurs in no record |
| M2 | `README.md:184` | "Issuer, sink and dispatcher: 115 suite rows" | "126 suite rows (115 before T19)"; the 10-of-10 copies marked as run on the 115-row suite | `proposals/forge2-slice1-refund-finality/records/evidence.json`, `sink_controls.report.counts.rows` = 126 (record after pull request 74); `.../evidence-before-t19-c7f2f41c.json` = 115; `.../removed-check-copies.json` says "final version, 115 rows" |

### 2.1 README ledger rows

| Number | Record and key | Value | Result |
| --- | --- | --- | --- |
| `RefundSpec.dfy` 64 lines; `Refund.dfy` 15 lines | the files (`wc -l`) | 64; 15 | MATCH |
| Stage 1 four planted bugs | `results/stage1.json` `negative_controls` | 4 entries | MATCH |
| Stage 3 300 runs | `results/stage3.json` `property_result.num_runs` | 300 | MATCH |
| Stage 3 4,131 comparisons | `results/stage3.json` `property_result.counters.compared_steps` | 3506 | MISMATCH, fixed (M1) |
| Stage 4 checks 2, reuses 10 | `results/stage4-local.json` `cases[1].snapshots[1].checked_count`, `reused_count` | 2; 10 | MATCH |
| Stage 6 75 pairs | `results/stage6/benchmark.json` `sample_count` | 75 | MATCH |
| Stage 7 1,240 bytes; 579 modules; 86 assumptions | `results/stage7/accepted/own/assumption-audit.json` `build_provenance.binary_bytes`, `checked_module_count`, `independent_closure_assumptions` | 1240; 579; 86 | MATCH |
| Stage 8 9,000 cases; 68 fixtures | `results/stage8/completed/completion.json` `property_suite.generated_cases`, `fixture_cases` | 9000; 68 | MATCH |
| Stage 9 8 stale lock entries | computed: `gate/provenance/implementation.lock` `files` (100 entries) against `main` | 8 differ | MATCH (computed) |
| Slice 1 115 rows; 48 attempts; 10 of 10 | Slice 1 `evidence.json` `sink_controls.report.counts.rows`, `rejection_attempts`; `removed-check-copies.json` | 126; 48; 10 of 10 | rows MISMATCH, fixed (M2); others MATCH |
| Slice 2 11 of 11 | `proposals/forge2-slice2-spec-clearing/records/removed-check-copies.json` | 11 | MATCH |
| Slice 3 84 allocations; 26 of 26; 0 Dafny starts | Slice 3 `evidence.json` `runtime_certificate_checked.committed_allocations_in_the_recorded_runs`, `optimizer_swap.of_them_dafny_or_z3`; `removed-check-copies.json` | 84; 0; 26 | MATCH |
| M1 95 theories; 158 cases | `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/comparison.json` (71 theory rows + 1 import check) + `comparison-phase2.json` (24); `records/plan-phase2.json` `C.listed_cases` | 95; 158 | MATCH |
| M1 3 cases with no source | text only: `ROADMAP.md` (M1-B wave 5 row), `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md` section 8 | 3 | NO JSON RECORD (text record agrees) |
| Wave Gate 1 2,466; 24,039; 57; 25; 23 of 23 | `proposals/forge2-m1-conformance/records/evidence.json` `conformance.counts.typed_vectors`, `tampered_transitions_refused`, `record_controls` (len), `core_controls` (len); `removed-check-copies.json` | 2466; 24039; 57; 25; 23 | MATCH (equal in the T19 record `91b49423…` and the old `f55391da…`) |
| 70 copies (10, 11, 26, 23) | the four `removed-check-copies.json` | 70 | MATCH |
| `rustc` 1.92.0; Node 24.3.0; Dafny 4.11.0 | `proposals/forge2-goal20-sdk/records/evidence.json` `toolchain`; `toolchain/pins.json` `dafny.version` | equal | MATCH |
| ADDED: Goal 19 49 of 49; 10 GiB; 1,949,696 bytes | `proposals/forge2-native-silicon-sink/records/evidence.json` `mutations.suite_failed_on`, `suite.cases.flood.flood_bytes`; `records/measurements-run-1.json`, `-2.json` `suite.flood.sink_peak_rss_bytes` | 49; 10737418240; 1949696 | MATCH |
| ADDED: Goal 20 26, 137, 11, 19, 8, 114, 2 | Goal 20 `evidence.json` `counts` | equal | MATCH |
| ADDED: Goal 20 record 20 of 64 subjects changed | computed: `subject` list of the record against `main` | 19 changed, 1 missing (`src/airlock/node/cosign.cjs`) | MATCH (computed) |
| ADDED: Gate F1 23 of 23 | `proposals/forge2-goal21-intent/records/evidence.json` `mutations.killed`, `changed_copies` | 23; 23 | MATCH |

### 2.2 Other documents

- `docs/claims.md`: spec SHA-256 `2ad0742d…5940` equals `spec/LedgerSpec.dfy`; 227 / 6 / 221 equal
  `results/stage5/examples.json` `counts`. MATCH. No change needed.
- `docs/quickstart-5min.md`: refund binary `b8ed5ec2…7bb8` equals the copy that `bin/forge-airlock build`
  printed in this audit (MATCH); goodwill limit $20 to $50 equals the two policy files (2000 to 5000 cents,
  MATCH); "9 libraries" equals the text log `proposals/review-20261120-engine/logs/f1-node-dylibs.log` (MATCH,
  text); "4 rows change" and exit 3: NO JSON RECORD; run in this audit:
  `bin/forge-airlock diff-policy … --no-clearing` exit 3, "rows: 28, changed: 4". No change needed.
- `docs/STATUS.md`: the 14 squash commits equal `gh pr list --state merged` (exit 0) and
  `git log --oneline origin/main`. MATCH.
- `FORGE_MASTER_IDEA.md` spot check: 38 of 38 attacks (`proposals/forge2-pillar2-refund-finality/records/summary-attempt-0002.json`
  `attacks`), 25 solvers and 2,300 checks (`proposals/forge2-pillar3-dual-certificate/benchmark/records/summary-attempt-0001.json`),
  1,227 receipts and 299 refusals (`.../finality/records/summary-attempt-0002.json` `totals`), 21 wrong cores and
  104 control rows (Slice 3 record), 10 verified and 9 wrong cores (Slice 1 record), 2,466, 24,039, 192, 57, 25
  (M1 conformance record). All MATCH.
- `ROADMAP.md` top sections: MATCH for Goal 19 (7.95 / 11.08 / 45.2 to 48.2 ms; 13.0 to 15.3 ms; 1.86 MiB; 49),
  Goal 20 counts, Gate F1 (23 of 23), APEX-2 (32 controls, `records/controls/CONTROLS.json`), T19 bundle digests
  (the four tracked records hash to `756babc5…`, `6b21a487…`, `91b49423…`, `f8b85b97…`), `sink.rs` 248 lines.
  NO JSON RECORD (the ROADMAP EXIT table is the only record): every count of the V1.1 primitives section (81
  cases, 103 copies, bundle `100476fe…`), the CI section (121 of 193 cases), the Archia sections (RSS 1,808 KiB
  and 2,480 KiB, p50 17.08 ms, 44 of 47, bundle `13608d7e…`), the video cut (39 of 39, 68 shots), the engine
  hardening count "145 of 145 copies" (the regression JSON holds only the bundle digest `69fbd676…`), the cosign
  counts (122 of 122). These are exit rows, not cited elsewhere as results; not changed.
- Stage 9 benchmark cells: no audited document cites one (Stage 9 deferred). 45-link graph: 12 + 9 + 7 + 17 = 45
  in `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md` section 3 (text; MATCH).

## 3. Fixes made (editable living documents only)

| File | Change | Basis |
| --- | --- | --- |
| `README.md` | M1, M2 above | records named above |
| `README.md` "What Forge is" | "No CI job builds or tests it" replaced: CI workflow of pull request 71 (`c1490f92`), a FINITE TEST | `.github/workflows/airlock-ci.yml` on `main`; hosted runs 44756122944 and 44767657892 on `main`: success |
| `README.md` | new "Four assurance labels" table (PROVED CORE, NATIVE CHECK, FINITE TEST, TRUSTED ASSUMPTION); `sink.rs`, `src/mcp_proxy`, `src/primitives_v2` named under NATIVE CHECK and "Nothing proves" | labels of the ROADMAP sections of pull requests 65, 62, 77, 79 |
| `README.md` "Use it from Python" | the 60-second path made self-contained: `bin/forge-airlock build`, `mkdir -p build/quickstart`, `bin/forge-airlock init … --policy …/refunds.json`, then the unchanged Python | run in this audit from a clean `git archive` of `058eabcb`: exit 0, 0, 0, 0; output `REJECTED_POLICY` |
| `README.md` "Limits", Slice 1 row | "KNOWN DEFECTIVE on `main`" and "Fix in pull request T19 (pending)" replaced by the T19 merge (`f1d87032`), TESTED level, new known limit (no lock against two minters) | `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261120_T19.md` row U3; T19 report |
| `README.md` Platform | `/usr/bin/ssh-keygen` (cosign, pull request 72) as trusted; money stores start no Node | ROADMAP Goal 21 phase 1; quickstart |
| `README.md` status line | 2026-11-19 to 2026-11-20 at `058eabcb`; pull request 76 OPEN | `gh pr list` |
| `README.md` evidence table | six rows added: Goal 19, Goal 20 (with the stale-record statement), Gate F1, APEX-2, Archia MCP proxy, V1.1 primitives | section 2.1 |
| `README.md` "Not done" | next-horizon items: state per item; paper, "Forge for Dummies" and `reproduce_paper.py` stated as not on `main` (no link) | sections 4 and 5 |
| `README.md` Documents | row for `docs/STATUS.md` | |
| `docs/STATUS.md` | rewritten to `058eabcb`: the 14 merges with squash commits, #76 open, known record gaps, owner items (B-15/B-16 applied); "blocks the merge button, so no agent can merge" replaced: `main` has no branch protection (GitHub API answers 403 on this plan; graph E2, blocker 5) | `gh pr list`; `gh api …/branches/main/protection` (exit 1, HTTP 403) |
| `FORGE_MASTER_IDEA.md` | rows F1.5, F1.6, F2.2, F2.3, F2.4, F2.5, F2.7, F3.3: "Update 2026-11-20 (release audit)" notes appended (original text kept); a dated note after the next-horizon paragraphs and above "Open decisions"; `FORGE_MASTER_MISSION.md` marked "not on `main`" | ROADMAP sections of pull requests 65, 67, 70, 72, 74, 79 |
| `docs/VIDEO_STORYBOARD.md` | "verified through Node" and "The native cosign is not on `main`" marked as written before pull request 72; MCP proxy on `main` since 77; branch merged as `ccdd8e5f` | `git log`; `src/airlock/py/cosign_tool.py` (ssh-keygen) |
| `ROADMAP.md` | new top section "Release audit 2026-11-20: merge state" (14 merges, squash commits, #76 open, the sections below written before the merges; actual exit codes separate from NOT RUN) | `gh pr list`; `gh run list` |

The historical sentences "NOT merged by the agent" in ROADMAP stage sections are NOT changed.

## 4. README top of page (directive item 3)

A cold visitor sees, in order: the aim (one bold sentence plus its limits), the research-prototype and
`end_to_end=false` line, "What Forge is", the four-label table, the Python quickstart, limits, platform.

| Directive item | State after this audit |
| --- | --- |
| 3-sentence universal thesis | PARTLY: the top has a one-sentence aim ("LLMs propose, checkers dispose, and humans approve intent") followed by its limits, and a 3-sentence "What Forge is" paragraph. No new thesis text was written: wording of a thesis is the owner's choice |
| 60-second quickstart, 3-line SDK | DONE and RUN: 3 shell lines + 6 Python lines (the Python is 6 lines, not 3); exit 0 each; `REJECTED_POLICY` |
| 1-command demo | NOT at the top. `python3 scripts/demo_gauntlet.py` (README, far below) and `bin/forge-airlock demo` (quickstart step 7) need Dafny (Slice cores; the booking checker): NOT RUN here. The demo code belongs to another worker |
| honest 4-badge assurance diagram | DONE as a table (not a picture) |
| links to Forge for Dummies, the Paper, `reproduce_paper.py` | NOT POSSIBLE: none of the three is on `main` (section 5). No dead link added; the README says they are not on `main` |

Commands NOT RUN (need Dafny or Docker): README `python3 gate/gate.py …`, `scripts/build_model.py`,
`node --import tsx app/main.ts`, the four `exit_*.py --case evidence` lines, `scripts/demo_gauntlet.py`.

## 5. Absent documents

| Document | State on `main` |
| --- | --- |
| `docs/FORGE_PAPER.md` (the Paper) | not present (named only in `proposals/forge2-finish-line/DIRECTIVE.md`, Gate F3) |
| "Forge for Dummies" | not present (no tracked file of that name) |
| `scripts/reproduce_paper.py` | not present |
| `ACCEPTED_ASSUMPTIONS.md` at the root | not present; the file is `proposals/forge2-finish-line/ACCEPTED_ASSUMPTIONS.md` (a signed owner record) |
| `FORGE_MASTER_MISSION.md` (named in `FORGE_MASTER_IDEA.md` line 6) | not present |
| `scripts/check_links.py` (named in the audit method) | not present; the checker is `proposals/round4-20261117/check_links.py` (reads files from a git revision, so a working-tree variant was used; section 8) |
| HAL demo, web showcase | not present; no living document presents them as available (`docs/VIDEO_STORYBOARD.md` says "The web demo was deleted") |

## 6. Findings that could not be fixed here

| # | Finding | Why not fixed | Proposed change |
| --- | --- | --- | --- |
| F1 | Goal 20 record `proposals/forge2-goal20-sdk/records/evidence.json` (`1e75ab47…`): 20 of 64 subjects differ on `main` (19 changed, `src/airlock/node/cosign.cjs` missing). No newer Goal 20 bundle is tracked (`69fbd676…` exists only as a digest in `proposals/review-20261120-engine/logs/regression-9a17c95d.json`, for tree `9a17c95d`, not `main`). No living document claims byte-identical reproduction on `main`; README and STATUS now say it does not reproduce | a record; needs a new `--case evidence` run (Dafny) and the owner's decision | owner: run `scripts/exit_goal20_sdk.py --case evidence` on `main` and track the new record, or keep the old one as the record of pull request 65 |
| F2 | `scripts/exit_archia_mcp.py:74,321-331`: pins `bin/forge-airlock` = `bd56d8b6…`; `main` has `8d9296ac…` (pull requests 72, 73). Its `--case build` must fail on `main`; also its `MAY_CHANGE_SINCE_MAIN` diff against `b2249ea2` now sees many files. Read from the script; NOT RUN | code; another worker's area | make the pin follow the merged `main` or drop the branch-time checks after the merge |
| F3 | `scripts/exit_universal_primitives.py:94`: the ADDITIVE check allows only `ROADMAP.md` and `unsure.md` against the merge base; on a branch with this audit's document changes `--case build` would fail | code | same as F2 |
| F4 | `proposals/forge2-finish-line/ACCEPTED_ASSUMPTIONS.md:37,58`: "T19 … in progress as its own PR" / "T19 is in progress"; T19 merged as `f1d87032` | signed owner record under `proposals/` | none in the file; STATUS states the merge |
| F5 | `proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md` row U3 still says "KNOWN DEFECTIVE on `main` until the owner applies a fix"; superseded by `TOP_LEVEL_GRAPH_REFRESH_20261120_T19.md` | historical record | none; README links the T19 refresh |
| F6 | `src/primitives_v2/PROTOCOL.md:63`: "`src/mcp_proxy` on branch `demo/archia-mcp-showcase`" — it is on `main` since `a2ef7c0a` | bundle subject (primitives) | replace with "`src/mcp_proxy` (on `main` since pull request 77, `a2ef7c0a`)" |
| F7 | `docs/quickstart-5min.md` and `src/airlock/PROTOCOL.md`: no stale number found; label text consistent | subjects | no change needed |
| F8 | The demo of "1 command" without Dafny does not exist at the top of README | demo code is another worker's | owner/worker: name one no-Dafny demo command, then README can show it |

## 7. Overclaim scan

Scope: all tracked `.md` files outside `results/` (phrases: formally proved, proved, PROVED CORE, verified,
guarantee, unbreakable, physically, impossible, zero, never) and code comments in `src/`, `sdk/`, `bin/`,
`examples/`, `demos/`. Every hit was read in context.

Fixed in documents: README "No CI job" (false after #71) and "KNOWN DEFECTIVE on `main`" (false after #74);
STATUS "blocks the merge button, so no agent can merge" (an enforcement claim with no enforcement); STATUS "Goal 20
… no PR yet" and "sink fixes are still UNAPPLIED diffs" (false after #65, #74); VIDEO_STORYBOARD "The native cosign
is not on `main`" (false after #72). No document labels `airlock-engine`, `sink.rs`, `mcp_proxy` or
`primitives_v2` as proved; README now labels them NATIVE CHECK.

Proposed code changes (not made):

| # | File:line | Bundle subject? | Text | Proposed |
| --- | --- | --- | --- | --- |
| C1 | `src/primitives_v2/farkas.rs:30,51,200`; `src/primitives_v2/PROTOCOL.md:642,758`; `sdk/py/forge_primitives.py:23,39,528,540-543`; `examples/universal_self_repair/README.md:48,67`, `run_demo.py:95,471,589-591,731` | yes (primitives) | the unproved native check answers `OK verdict=INFEASIBILITY_PROVED`; only the Dafny predicate is proved | rename the wire word to `INFEASIBILITY_CERTIFIED` (and `INFEASIBILITY_NOT_PROVED` to `INFEASIBILITY_NOT_CERTIFIED`), or at least add to each answer description: "the Rust check is NOT proved; PROVED refers to `FarkasCert.Soundness` for the Dafny predicate" |
| C2 | `examples/unbreakable_store/` (folder), `run_demo.py:2,56,116,549,555`, `ts_part.ts:1`, `bin/forge-airlock:301`, `demos/video_cut/domains/d6_saas.py:12` | yes (Goal 20) | "unbreakable" names a finite-tested demo | rename to `airlock_store` (or similar) with the next Goal 20 bundle refresh |
| C3 | `examples/unbreakable_store/run_demo.py:66` | yes (Goal 20) | `LBL_CANON = 'PROVED CORE decision (CakeML binary b8ed5ec2...7bb8) + FINITE TEST'` | `'PROVED CORE decision (CakeML binary b8ed5ec2...7bb8; model-level HOL4 theorem; M1-B OPEN) + FINITE TEST'` |
| C4 | `demos/video_cut/domains/d1_autonomy.py:13-14` and the take's label for shots 3, 4, 6 | no | "The signature check is Ed25519 through Node (trusted)" — false since `cad68a5f` | "The signature check is Ed25519 through `/usr/bin/ssh-keygen -Y verify` (trusted)". (`demos/video_cut/harness.py` is being changed by the demo worker in this tree) |
| C5 | `tests/refund-finality/suite.ts` (record field `owner_decisions_pending`: "B-15 … pending") | yes (Slice 1) | B-15 is applied | already listed by T19 as an owner wording decision |

Not overclaims (checked): `src/mcp_proxy/*` ("Nothing here is proved"), `src/silicon_sink/sink.rs` (no proof
words), `src/airlock/PROTOCOL.md:7-9,484` (PROVED CORE limited to the CakeML decision with "M1-B OPEN"),
`src/airlock/py/diff_policy.py` ("for the GENERATED Dafny model only"), `src/primitives_v2/taint.rs:46` ("NOT a
guarantee"), `FORGE_MASTER_IDEA.md:224` (quoted words of the source, disowned), README north star (stated as an
aim).

Bundle-subject `.md` files found by hash (not edited): `AGENTS.md`, `VISION.md`, `docs/booking.md`,
`docs/claims.md`, `docs/demo-gauntlet.md`, `docs/reuse-benchmark-epoch1.md`, `docs/spec-quality.md`,
`docs/stage4-change-loop.md`, `docs/stage7-binary.md`, `docs/stage8-refund.md`, `docs/stage9-*.md`,
`examples/binary/README.md`, `gate/*.md`, `toolchain/README.md`, `ts/README.md`, and 80 files under `proposals/`
and `spec/`.

## 8. Checks run (actual exit codes)

| Command/check | Exit/result |
| --- | --- |
| `gh pr list --state merged`; `gh pr list --state open`; `git log --oneline origin/main` | 0; 0; 0 (14 merges as listed; #76 OPEN) |
| `gh run list --workflow airlock-ci.yml --branch main` | 0 (2 runs, success) |
| `gh api repos/…/branches/main/protection` | 1 (HTTP 403: feature not on this plan) |
| clean `git archive` of `058eabcb`: `bin/forge-airlock build`; `mkdir -p build/quickstart`; `bin/forge-airlock init … --policy …/refunds.json`; the README Python | 0; 0; 0; 0 (`REJECTED_POLICY`) |
| same tree: `bin/forge-airlock diff-policy refunds.json refunds-v2.json --no-clearing` | 3 (`CLEARING_NOT_RUN`; rows 28, changed 4) |
| `proposals/round4-20261117/check_links.py HEAD` on the five documents (baseline, before the edits) | 0 |
| working-tree variant of that checker (scratch; same link rule, targets among tracked files plus this new file) on `README.md`, `docs/STATUS.md`, `FORGE_MASTER_IDEA.md`, `docs/VIDEO_STORYBOARD.md`, `ROADMAP.md`, this file | 0 (0 missing) |
| any test suite, EXIT script, Dafny, HOL | NOT RUN |
