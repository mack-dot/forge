# Orchestrator C (red team) worker rules — night shift 2026-11-19

You ATTACK. You never write a fix. You never change a file outside your own evidence directory.

## Targets (read-only; never write inside them)
- B target SHA: 4af09308 (branch nightshift/B-trust). A target SHA: dae1b93e (branch nightshift/A-proof).
- Read-only checkout of 4af09308 WITH B's adoption diff applied (orch-B/p-adopt2/adoption-v6.diff; uncommitted there):
  <SCRATCH>/redteam-C/target-v6
  This is "the fixed implementation": ts/refund-finality/{sink,dispatcher,minter,encoding,proposer}.ts,
  ts/refund-finality/core/sinkcore-v6.cjs, impl/finality-core/*.dfy.
- Plain checkout of 4af09308: <SCRATCH>/redteam-C/wt (do not commit there; only the orchestrator does).
- B's evidence, builds and unapplied diffs (gate rule 3: orch-B/e-subset3; DB/restart: orch-B/b-restart, r-v5, r-v6;
  minter: orch-B/d-minter): <REPO>/results/night-shift-20261119/orch-B/ (main checkout; builds are untracked there).
- A's files: git show dae1b93e:<path>, or <REPO>/results/night-shift-20261119/orch-A/ and
  <REPO>/results/m1b-routeA-20261119/.
- Known findings (do NOT re-report as new): <REPO>/results/night-shift-20261119/OWNER_REQUIRED.md,
  orch-B/MORNING.md (addenda), MORNING_REPORT.md, unsure.md entries U477-U567 in <SCRATCH>/redteam-C/wt/unsure.md.

## Run recipe (tested by C: exit 0)
cd <SCRATCH>/redteam-C/target-v6 && env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=<your evidence dir> LANG=C \
  NODE_PATH=<REPO>/node_modules timeout 120 node --import tsx <your script.ts> <args>
Example of minting with a throwaway key, commit, restart, dispatch:
  orch-B/p-adopt2/conf/e2e_v6.ts <target-v6 root> <REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs <work dir>
Pinned Node is /opt/homebrew/bin/node v24.3.0. Python: /usr/bin/python3 or the repo's usual one.

## Hard rules
- Evidence dir: <REPO>/results/night-shift-20261119/orch-C/<your attack name>/ . Scripts, logs, work
  databases go there. Keep it under 50 MB. Do not write REPORT.md or any report file: return the report as your final text.
- No copy of a tree. No git worktree. No git commit, push, checkout, stash or reset anywhere. No file change outside your evidence dir.
- LIGHT runs only: at most 4 processes at once, at most 120 s per run, no stress loop above about 2,000 iterations.
  A HOL proof job runs on this machine. Never start hol, Holmake, or a Dafny run of more than one file or 60 s.
  For a single-file Dafny run use <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh (read it first);
  if it refuses, record NOT RUN. Never touch results/night-shift-20261119/locks/.
- No owner credentials, no real signing keys, no network, no production data. Start each shell command with
  'unset GH_TOKEN GITHUB_TOKEN;'. Generate throwaway Ed25519 keys only.
- Stop if 'df -g /' shows less than 30 GB free.
- Threat model must be stated per finding: what the attacker holds (nothing / token replay / database write without the key /
  config control / a second honest process / a crash). A finding that needs the signing key or config control is weak: say so.
- A fix that refuses a zero-amount refund, or a gate that rejects correct work, is a DEFECT: report false rejections too.
- Truth rules: actual exit codes only. A command that did not run is NOT RUN. Do not turn a guess into a result.

## Required final text (at most 60 lines)
For each finding: class; threat model; target file and line; minimal repro script path; the exact command; expected (safe)
behaviour vs actual behaviour; actual exit code (make the script exit 1 when the attack SUCCEEDS = defect present, 0 when
the target is safe, so it can become a regression test); whether it is new or a known item (cite the U-id or B-item).
Then: negative results (what you tried, with script paths and exit codes). Then: the next boundary you would attack.
Branch copies: <REPO> = repository root, <SCRATCH> = the orchestrator's scratch folder (paths replaced for the commit; the runnable originals are in the main checkout, untracked).
