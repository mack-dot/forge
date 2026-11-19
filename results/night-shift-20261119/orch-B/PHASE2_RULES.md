# Phase 2 rules for Orchestrator-B workers (in addition to WORKER_RULES.md, which stays binding)

Mission (owner directive 2, stored at results/night-shift-20261119/DIRECTIVE-2.md): turn the discovered counterexamples into
permanent, executable, adversarially tested guarantees, and bind the proofs to the production implementation.
"Optimize for the number of real, independently verified attack classes eliminated", not for proofs or code volume.

Decided by the owner: the governing context of a refund is the approved, versioned policy plus the AUTHORITATIVE PERSISTED
CHARGE STATE (the charge the sink has stored). Still open (name them when you rely on them): OPEN-IS-UNSETTLED (a request is
open exactly while its id is not settled in the sink for that charge); POST-RULE (an authorized refund decreases `remaining`
by the amount and changes nothing else). Zero-amount refunds are legitimate and must keep succeeding.

How code reaches the branch: you do NOT commit. You work in a SMALL scratch export inside your evidence directory:
  mkdir -p <your dir>/tree && git -C /Users/mackianni/forge archive nightshift/B-trust ts tests impl scripts spec interop \
     proposals/forge2-pillar2-finality-protocol package.json tsconfig.json | tar -x -C <your dir>/tree
  ln -s /Users/mackianni/forge/node_modules <your dir>/tree/node_modules ; ln -s /Users/mackianni/forge/.toolchain <your dir>/tree/.toolchain
(no other copy of a tree; check `df -g /System/Volumes/Data`: stop below 30 GiB free). You deliver ONE diff against the branch
head for the paths you own (`git diff --no-index` or `diff -ruN` between a pristine export and your changed one, restricted to
your files), with `git -C <branch worktree> apply --check` evidence. The branch worktree (READ ONLY for you) is
/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/B-trust .
Protected paths stay untouched (gate/, policy/, spec/, toolchain/, schemas/, .github/, governance/, spec.lock, AGENTS.md,
scripts/javascript_env.py, scripts/build_model.py, interop/export.cjs, interop/model.ts, tests/ledger.property.ts,
tsconfig.json, package.json, package-lock.json). Never put a file under clearing/. State file ownership in your report.

Heavy steps (kill/race/concurrency stress, fuzz of more than a few hundred cases, any run over 20 s or 250 MB, the full test
suite): PREPARE a script that refuses while locks/hol.lock exists or `pgrep -f bin/hol` finds a process and that does not take
heavy.lock itself; do NOT run it; the orchestrator runs it in a window. Light single runs are allowed (pinned Node
/opt/homebrew/bin first; `env -i`; test keys generated in the process; no package install). Before every Dafny or Node run:
`pmset -g batt | head -1` must show AC power.

Every fix needs: a regression that FAILS on the unfixed code and PASSES on the fixed code (show both runs); positive controls
(legitimate transactions, zero amount included, still succeed); the trust assumptions it rests on, by name.
The red team (Orchestrator C) attacks what you build. Do not write attacks for C; do write the regressions for your own fix.
The harness refuses REPORT.md: your final message is the report.

POWER AMENDMENT (owner instruction relayed by the launcher; PROTOCOL.md): battery power no longer blocks Dafny runs or
heavy windows. Still log `pmset -g batt | head -1` before a run. The memory, swap and disk gates stay. The sentence above
that requires AC power before every run is replaced by this one.
