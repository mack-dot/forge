# Audit 1: repository hygiene (pre-release)

- Subject: `origin/main` = `058eabcb` (16,537 tracked files, 176.8 MB).
- Mode: READ-ONLY. This file is the only change. No commit, push, PR or branch action.
- Scratch lists (not committed): `/private/tmp/claude-501/-Users-mackianni-forge/fb0fde47-8987-485d-a625-0e9fdb4facee/scratchpad/w-audit1/`.
- Limit: "pinned" means a tracked JSON record or a SHA256SUMS-style manifest holds the file path next to its sha256
  (script `pins.py`, 3,800 paths found). A record that hashes a file by another layout is not detected. The rules
  (results/, records/, protected paths) cover most of that gap.

## 1. Path, user and host scan

Patterns: `mackianni` / `Mack Ianni` (macOS user; also matches the GitHub login `mackiannii`), `/private/tmp/claude-<uid>`,
host `Macks-MacBook-Pro-3` (from `hostname`, `scutil --get LocalHostName`), `Mack's MacBook Pro` (ComputerName: 0 hits).

`/Users/USER` (90,359 hits) is an existing placeholder, not a leak. 957 files hold only the placeholder. They are not counted.
Other `/Users/` names: `/Users/forge-runner` (2), `/Users/runner` (1); both are CI runner paths.

Real hits: 2,065 files, 40,089 hits. Text-only scan; 3,345 non-text or empty tracked files were checked with `grep -a`: 0 hits.

| Folder | Files | Hits | Class |
|---|---:|---:|---|
| results/ | 2,009 | 39,853 | a |
| proposals/ | 28 / 8 / 1 | 68 / 32 / 1 | a / c / d |
| (root) ROADMAP.md, unsure.md | 2 | 6 + 101 | a |
| tests/ | 10 | 13 | b |
| scripts/ | 2 | 6 | b |
| demos/ | 2 | 2 | b |
| examples/ | 1 / 1 | 1 / 1 | b / c |
| src/ | 1 | 2 | b |

By file class: json 1,389; log 512; jsonl 49; stdout 40; trx 32; py 16; md 12; stderr 10; txt 3; sha256 1; sh 1.
By pattern: user 2,034 files; `/private/tmp/claude-` 1,486 files; host 39 files (all class a: results/stage8 26,
results/stage6-epoch1 6, proposals/night-shift-20261119 7).

### (a) MUST NOT change: 2,039 files (`class_a_keep.tsv`, one reason per file)

- 1,399 under `results/` (rule: files under results/ stay byte-identical).
- 610 pinned by a hash in a results/ record: `results/stage9/b-prep-0001/b1-publication-manifest.json` (331),
  `results/stage9/b1prime-0001/manifest.json` (140), `results/stage9/contract-adoption/before-identities.json` (107),
  `results/stage7/published/stage7-complete/records-index.json` (29), `results/stage6-epoch1/report*.json` (3).
- 28 under `proposals/night-shift-20261119/` (recorded run output of PR 64; 1 pinned by `orch-A/launch/SHA256SUMS`).
- 1 under a `records/` folder (`proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/scripts/driver.py`).
- `unsure.md` (101 hits): append-only (AGENTS.md). Old hashes of it are in 11 records (none match today).
- `ROADMAP.md` (6 hits, lines 2423, 2450, 2451, 2458, 2478, 2479: `git apply ... /Users/mackianni/forge/...`):
  recorded stage execution commands. Not byte-pinned today (old hashes only). A scrub would rewrite a record. Leave.
- 0 hit files under a protected path.

### (b) Source code with a machine path: 16 files (`class_b_source.txt`)

BREAKS on another machine (real portability defects):

| File:line | Value | Effect |
|---|---|---|
| src/primitives_v2/py/policy_to_dfy.py:59-60 | DAFNY, DAFNY_ROOT = owner checkout | product code; no env override; Dafny runs fail |
| scripts/exit_universal_primitives.py:62 | RUSTC = owner `~/.cargo/bin/rustc` | no `which` fallback; build fails |
| scripts/exit_universal_primitives.py:65-66 | DAFNY, DAFNY_ROOT | reports NOT RUN (line 202-203; fails closed) |
| tests/integration/receipt_authentication.py:119 | symlink to owner `.toolchain` | dangling link; test fails |
| tests/primitives_v2/test_policy_to_dfy.py:44-45 | DAFNY, DAFNY_ROOT | NOT RUN (line 94) |
| tests/primitives_v2/test_farkas.py:37-38 | DAFNY, DAFNY_CWD | Dafny step skipped (line 313) |
| tests/primitives_v2/mutants.py:138, mutants_p7.py:119, mutants_p8.py:113, mutants_p9.py:152, mutants_sdk.py:61 | `--rustc` default | fails unless `--rustc` is given |

Works elsewhere (fallback only), but leaks the user name or a session path:

- examples/archia_mcp_showcase/run_showcase.py:272, scripts/exit_archia_mcp.py:51, tests/mcp_proxy/test_proxy_e2e.py:49:
  `shutil.which('rustc') or <owner path>`.
- scripts/exit_archia_mcp.py:70 and tests/mcp_proxy/test_review_regressions.py:60: old binary in a Claude session
  scratch folder; guarded by `os.path.isfile`; the old-binary comparison silently does not run elsewhere.
- demos/video_cut/harness.py:214 and demos/video_cut/domains/d6_saas.py:16 (docstring): lock folder
  `/private/tmp/claude-501/forge-locks`; if absent, the lock is skipped (line 241-242): no cross-process lock elsewhere.

No class (b) file is hashed by a record. `policy_to_dfy.py` is named (not hashed) as `generator` in
`domains/compiled_policies/*.vectors.json`.

### (c) Documents that can be scrubbed: 9 files (`class_c_docs.txt`), all hits listed

None is hashed by a record. Some are named in link-check records (`regression.json`, `links-final.json`); those store
link results, not content. Keep links unchanged. Only 2 hits are home paths; 30 are the GitHub login `mackiannii`.

| File | Hits | Lines |
|---|---:|---|
| examples/universal_self_repair/README.md | 1 | 13 (rustc path in a command) |
| proposals/provenance-receipt-repair.md | 1 | 122 (`git apply --check /Users/.../forge/...`) |
| proposals/m1b-mission-20261119/reports/III-stage9-preparation.md | 1 | 27 (login) |
| proposals/approval-integrity/PROPOSAL.md | 2 | 6, 50 (login) |
| proposals/m1b-mission-20261119/reports/B5-admission-boundary.md | 2 | 34, 46 (login) |
| proposals/m1b-mission-20261119/reports/D8-enforcement-live-settings.md | 4 | 12, 14, 46, 72 (login) |
| proposals/m1b-mission-20261119/drafts/enforcement/LIVE_SETTINGS.md | 5 | 17, 25, 26, 45 (login) |
| proposals/m1b-mission-20261119/drafts/enforcement/OWNER_RUNBOOK.md | 7 | 10, 27, 30, 51, 52, 53, 69 (login) |
| proposals/m1b-mission-20261119/drafts/ADMISSION_BOUNDARY.md | 10 | 20, 47, 51, 53, 60, 115, 143, 261, 333 (login) |

Only README.md is public-facing; the other 8 are internal governance notes. There are 9, not 10, class (c) files.

### (d) Other: 1 file

- proposals/m1b-mission-20261119/drafts/zero-review/results.json:642: one session scratch path (user already `<user>`).
  A result file of a draft; not hashed. Treat as a record. Leave.

### E-mail addresses (domains and counts only)

superpowermentors.com 71 (4 files, results/stage9: GitHub API output); example.* 40; github.com 10;
users.noreply.github.com 5 (results/stage9 4, unsure.md 1); docker.com 5; gzip.org 4; anthropic.com 4
(results/stage9 3, proposals/round4-20261117 1); alumni.caltech.edu 4; gmail.com 2 (results/stage7, 2 files);
globex.example, acme.example, example.invalid 2 each. All non-example hits are in class (a) files except unsure.md and
proposals/round4-20261117 (1 file).

## 2. Secrets

Tracked files at `058eabcb`:

| Pattern class | Files | Verdict |
|---|---:|---|
| `BEGIN .* PRIVATE KEY` | 2 | src/airlock/py/cosign_tool.py:59 (`-----B...`), tests/airlock/test_cosign.py:111 (`-----B...`): armor header constants; no key body follows. The test creates a key at run time in a temp folder. |
| `sk-ant-`, `sk-`, `ghp_`/`gh?_`, `github_pat_`, `AKIA`, `xox[bapr]-`, `AIza`, `Bearer <20+>` | 0 | none |
| key/secret/token/password = 32+ char literal | 0 | none |
| `.env`, `.pem`, `.key`, `id_rsa`, `id_ed25519`, `.p12`, credentials file names | 0 | none |

Mentions only (no key): proposals/night-shift-20261119/integration/{B-code-notes.md, C-scan.md}, unapplied/hardening-code.diff,
tests/refund-finality/regress/m2_closed_launch.ts:66 (a check that a folder holds no private key).

History (`git log --all -G`, 526 commits; 88 on main; plus `-G` for 32+ char key/secret/token/password literals on main: 0):

- 6 commits match. 5 touch the same cosign armor constants (`-----B...`): cea3fbae, 9a9a8943, 73758bda, 031e8f2b, cad68a5f.
- 05e243d5 (web showcase): `web/backend/tests/common.py` adds `FAKE_KEY = 'sk-ant...'`. The value says FAKE and
  DO-NOT-LEAK; it is a test fixture. Not on main and not on any remote branch (local branches only:
  `backup/discovery-one-web-pre-rebase`, `nightshift/*` locally).
- History file names: `web/frontend/.env.example` (05e243d5, not on main; one key `NEXT_PUBLIC_API_BASE`, a 21-char URL,
  no token pattern); `results/night-shift-20261119/orch-B/g-admission/live/secrets.json` (865730fd, not on main;
  18 bytes, only `total_count`); results/stage9 `*credential*` and `secret-scanning.out` files: no token pattern
  (one 40+ char string is a URL path).

Real secrets found: **0**.

## 3. Large files and leftovers

Tracked files > 1 MB: 11 files, 45.1 MB.

| Size | File | Depends |
|---:|---|---|
| 9.5 MB | results/stage7/published/stage7-complete/records.tar.xz | pinned (before-identities.json); .gitignore says full Stage 7 records live here |
| 9.3 MB | results/stage7/published/upstream-and-negative/records.tar.xz | pinned (same) |
| 4.0 MB x4 | results/stage9/{hosted-probe-0003,0005,0006, b2prime-dry-run-0001}/.../independent-kernel.log | results/ rule; probe-0006 pinned (b1-publication-manifest.json) |
| 3.4 MB | results/stage9/v33-audit-0001/evidence-manifest.json | results/ rule |
| 2.4 MB | results/stage9/v33-controls-0003/evidence-manifest.json | results/ rule |
| 1.6 MB | unsure.md | append-only record |
| 1.5 MB | proposals/night-shift-20261119/orch-A/x8-x11/static-tests/raw/llvm_objdump_slice.out | listed in that folder's SHA256SUMS.txt |
| 1.4 MB | proposals/night-shift-20261119/orch-A/x8-x11/static-tests/raw/otool_tV.out | same |

Removal candidates: none. Every large file is a record or is hashed by one.

Tracked leftovers: build/ 0, __pycache__/*.pyc 0, .DS_Store 0, *.sqlite*/*.db 0, images and video 0, node_modules 0,
target/ 0, object files 0. (4,139 `.log` files and 2 `.tar.xz` are records.)

Untracked but not ignored (from the main checkout's status snapshot; this worktree is clean): `.hol/`, `KeyedStore`,
`Restart`, `goal18.md`, `goal19.md`, many `results/<name>-<date>/` run folders. Also not ignored: `target/`, `*.sqlite*`,
`.env`. Suggested `.gitignore` additions: `.hol/`, `/KeyedStore`, `/Restart`, `target/`, `*.sqlite`, `*.sqlite-*`,
`.env`, `.env.*`, `!.env.example`. NOT suggested: `goal*.md` and `results/*` (owner decides; results are records).

## 4. Pull requests and remote branches

Open pull requests (10):

| # | Title (short) | Draft | Last update | Checks |
|---|---|---|---|---|
| 76 | Gate F2a (Goal 22): Stage 9 lock rebind | no | 2026-11-20 | fail 2, pass 1 |
| 37 | Termination claim, fixed RISC-V ELF | yes | 2026-11-03 | fail 2, pass 1 |
| 36 | Fix proof report upload paths (review) | no | 2026-11-02 | fail 3, pass 2 |
| 34 | Booking verification demonstration | yes | 2026-11-02 | fail 2 |
| 15 | CODEOWNERS and contribution templates | no | 2026-10-28 | fail 2, pass 1 |
| 14 | Prepare Forge for outside contributors | no | 2026-10-28 | pass 3 |
| 5 | Negative fixture: fee approval / C2 | yes | 2026-10-26 | fail 2, pass 1 |
| 3 | Negative fixture: weaken C2 | yes | 2026-10-26 | fail 2, pass 1 |
| 2 | Negative fixture: unapproved spec | yes | 2026-10-26 | fail 2, pass 1 |
| 1 | Stage 4 demo: valid ledger edit | yes | 2026-10-26 | pass 3 |

Remote branches: 86 (85 + main). Full table: `branches.tsv`. Squash merges make only `stage4/approved-fees` an ancestor of main.

- 52: tip = head of a MERGED PR (checked with `headRefOid`); no open PR; list in `delete_merged_branches.txt`.
- 1: `nightshift/A-proof`: PR 59 merged, but the tip (1a53594d) differs from the merged head (744e1e4d). UNSURE.
- 10 with an OPEN PR (above; #76's branch is current work).
- 8 with a CLOSED (not merged) PR: docs/m1b-wave4, fix/proof-report-artifact-paths, governance/ratification-0001,
  integration/receipt-authentication-review, nightshift/B-trust, nightshift/C-redteam, proposal/stage9-lock-rebind,
  stage11/incremental-verification. UNSURE.
- 14 with no PR: backup/* (8), docs/finish-line-directive (queued directive), f2/stage9-benchmark-plan (2026-11-20),
  proposal/m1-cf-inputs-20261107, proposal/m1-input-integrity-20261109, proposal/m1-macos-preflight-20261106,
  proposal/v3b-print-effects. UNSURE.

Commands for the owner (TEXT ONLY; NOT run):

Close stale pull requests (only the two with no doubt: #36 duplicates closed #35 at the same commit 705457e0; #34 is a
one-line draft experiment):

    for n in 34 36; do gh pr close "$n" --comment "Closed in the pre-release cleanup (stale)."; done

Left out, UNSURE: #1, #2, #3, #5 (demo PRs cited in docs/stage4-change-loop.md:130-135 and docs/stage9-history-audit.md:24-27;
closing keeps the pages but changes the demo state); #14 (adds LICENSE, CONTRIBUTING, SECURITY; main has no LICENSE);
#15 (CODEOWNERS is on main via #21, the templates are not); #37 (3,162-line proposal); #76 (current Gate F2a).

Delete merged remote branches (52; each tip equals its merged PR head; GitHub keeps `refs/pull/<n>/head`):

    git push origin --delete apex1/native-cosign ci/airlock-macos demo/archia-mcp-showcase demo/skeptic-gauntlet demo/video-storyboard docs/closeout-sync docs/front-door-and-v2-horizon docs/goal19-records docs/isolation-mode-design docs/m1-owner-decisions docs/m1-owner-review docs/m1b-route-a docs/master-idea-pcf docs/master-idea-records docs/master-idea-v2-horizon docs/review-readme-claims docs/stage9-deferred-records docs/v2-formal-ceiling docs/wave-gate-records feat/airlock-review-hardening feat/intent-clearing-v2 feat/m1-contract-link-closure feat/native-silicon-sink feat/t19-hardened-sink feat/universal-primitives-v2 feat/zero-babysitting-sdk fix/roadmap-sections-68-69 gate/coverage-soundness-v1 governance/codeowners governance/ratification-0001-agent integration/booking-reuse-ci integration/receipt-authentication-contributor nightshift/consolidated-20261119-r1 ops/linux-profile-v1 proposal/v3a-gate-ratification-rule proposal/v3b-print-effects-on-main records/m1-chain-replay records/stage6-epoch2-main slice1/refund-finality slice2/spec-clearing slice3/runtime-certificates slice4/m1-finality-conformance stage11/incremental-verification-v2 stage4/approved-fees stage9/b1prime-v32 stage9/records-b3-v32-install stage9/records-v33 stage9/v33-install stage9/v34-install stage9/v35-token-compat stage9/v36-deploy-perms test/v32-candidate

Note: `docs/goal19-records` is the branch checked out in the owner's main checkout. Remote deletion leaves the local
branch; only its upstream goes. No tracked file links to `tree/<branch>` for these 52 branches.

## 5. Decisions

What must stay as it is, and why:

- results/ (2,009 hit files, 39,853 hits): results rule; 610 of them are also hashed by stage records.
- proposals/night-shift-20261119/ (28): recorded run output; SHA256SUMS manifests hash parts of it.
- unsure.md: append-only. ROADMAP.md: recorded execution commands.
- The 11 large files: each is a record or is hashed by one.
- Protected paths: no hit; nothing to report.

Recommended scrubs (class c), smallest first. None changes a bundle:

1. examples/universal_self_repair/README.md:13: use `rustc` (public-facing).
2. proposals/provenance-receipt-repair.md:122: use a repo-relative path.
3. The 8 governance notes: replace the login `mackiannii` with "the agent account" only if the repository goes public
   (a login is not a home path; the notes also describe token scopes and keyring layout, but hold no token value).

Recommended code fixes (class b; a code change, not a scrub): read Dafny, Dafny root and rustc from an environment
variable or `shutil.which`, with the repo `.toolchain/` as default (policy_to_dfy.py first: it is product code).

Alarming items: no LICENSE file on main (only in open PR #14); `src/primitives_v2/py/policy_to_dfy.py` hardcodes the
owner checkout.
