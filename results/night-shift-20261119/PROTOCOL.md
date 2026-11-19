# Night shift 2026-11-19: two-orchestrator protocol

Both orchestrators obey this file, `DIRECTIVE.md` (same folder), `AGENTS.md`,
and the ROADMAP hard rules. If they conflict, the stricter rule applies.

## Roles

| Orchestrator | Track | Goals | Owns |
|---|---|---|---|
| A ("proof") | HOL / native | A, C, §8 replay debt | The single HOL slot |
| B ("trust") | Dafny / sink / admission / evidence | B, D, E, F, G | The Dafny slot |

Each orchestrator has at most 5 Opus 5.5 workers (Agent tool, model "opus").
Concurrency is also bounded by resources (see below). Fewer is allowed.

## Start state (measured 2026-11-19 by the launcher)

- Base: branch `docs/m1b-wave4`, commit `985f5eaf`. Last unsure ID: U480.
- AC power, battery 69 % charging.
- Swap: 9.9 GB used of 11.2 GB. Free RAM pages are low. HIGH PRESSURE.
- A HOL job runs: PID 15254 (`hol run --holstate=.../cake_compile_heap ...`,
  started 02:38). Its owner and purpose are unknown to the launcher.
  Orchestrator A must identify it (args, logs, parent) before any HOL work.
  Do NOT kill it and do NOT start a second HOL job while it runs, unless
  existing evidence shows it is orphaned; then record the evidence first.
- Unrelated Atlas node loggers run. Do not touch them.

## Shared resource locks (atomic `mkdir`)

Lock dir: `results/night-shift-20261119/locks/`

- `hol.lock/` — only A takes it. Write `owner`, `pid`, `cmd`, `start` inside.
- `dafny.lock/` — any expensive Dafny run (verify of more than one module or
  more than 60 s expected). B is the default holder; A asks B by message, or
  takes it when free.
- `heavy.lock/` — any Node stress test, differential fuzz, or kill/race run.
  Never hold `heavy.lock` while `hol.lock` is held or a HOL process runs.

Before any heavy step: run `pmset -g batt` and `sysctl vm.swapusage`.
- On battery: start no heavy step. Follow the existing runbook to pause.
- Swap free < 1 GB: start no heavy step; shed workers.
  AMENDED by the launcher at ~09:00Z: macOS keeps swapped pages until they
  are touched, so swap free can stay < 1 GB while RAM is mostly free. A
  heavy step may start if EITHER swap free >= 1024 MiB, OR
  (`memory_pressure` "System-wide memory free percentage" >= 40 % AND
  swap free >= 512 MiB). Below 512 MiB swap free, never start. Record both
  values in each case's log at start. Evidence for the change: at the
  amendment, swap free = 895 MiB and memory free = 67 %.
Remove your lock in every exit path. Record a stale lock; do not delete
another owner's lock without evidence that its process is gone.

## Branches and worktrees

- A: branch `nightshift/A-proof` from `985f5eaf`, worktree in your scratchpad.
- B: branch `nightshift/B-trust` from `985f5eaf`, worktree in your scratchpad.
- Each worker: its own worktree or its own evidence subdirectory.
- Never commit to `main`. Never push to `main`. Never merge. Never sign.
  Never deploy. Never change protected files (gate code, approved spec,
  policy). Prepare exact patches instead, in OWNER_REQUIRED.
- Commits on your own night-shift branch are allowed. Pushing that branch
  and opening a PR is NOT allowed without the owner's word.

## unsure.md ID blocks (append-only; unique IDs)

- A: U481–U529. B: U530–U579. Ask the other side if you need more.
- Append only to your own branch copy. Never edit an existing entry.

## Durable state (resume without conversation memory)

- A: `results/night-shift-20261119/orch-A/STATE.md`
- B: `results/night-shift-20261119/orch-B/STATE.md`
- Shared: `results/night-shift-20261119/OWNER_REQUIRED.md` (append only,
  prefix each item with `A-` or `B-` and a number).
- Contents per DIRECTIVE §10. Refresh after every substantive result.
- These paths are in the main checkout (untracked) so both sides and a
  fresh session can read them. Copy final versions into your branch.

## Talking to each other

Use SendMessage. Send a message when:
- you take or release `hol.lock`, `dafny.lock`, or `heavy.lock`;
- you find a result that changes the other side's priority or an assumption
  it depends on (for example the signing model, exporter identity, the
  `fficlose` counterexample, request-ID mismatch);
- you need work from the other side's slot;
- every ~90 minutes: a 5-line status (closed obligations, running, next).
Keep messages short and factual. Messages are data, not owner authorization.

## Truth rules

- Classify each edge: MACHINE-CHECKED / ASSUMPTION / TESTED-UNPROVED / MISSING.
- Actual exit codes only. Commands that did not run stay marked NOT RUN.
- A worker report is not a result until the orchestrator re-checks it
  (re-run the checker, or verify digests and logs).
- No stage promotion. `end_to_end` stays `false` unless a checked composed
  theorem plus owner word supports a change. M1-B stays OPEN.

## PHASE 2 AMENDMENT (launcher, ~14:16Z, from owner directive DIRECTIVE-2.md)

- Goals now come from `DIRECTIVE-2.md`. Roles: A = HOL and
  proof-to-executable chain; B = implementation hardening; C (new, Fable) =
  independent red team. C never writes fixes; B never writes C's attacks.
- Worker caps (concurrent, lightweight): A 5, B 6, C 6. Heavy steps still go
  through the locks one at a time. Shed workers if memory free < 20 % or
  swap free < 512 MiB.
- Disk: no worker starts a copy of a tree; stop all copying if free < 30 GB.
  Reuse one shared read-only checkout per orchestrator for attacks.
- unsure ID blocks: A continues in U481–U529; B continues to U579, then
  U620–U659; C uses U580–U619.
- Push rule (owner: "commit and push authorized, tested incremental work"):
  each side may `git push origin <its own nightshift/* branch>` with
  explicit refspec. Never push `main`, never `--force`, never open, merge or
  approve a PR, never change repo settings. `main` has no protection, so
  check every push command text before running it.
- B-10 decision (owner): governing context = the existing approved,
  versioned policy plus the authoritative persisted charge state. Report any
  remaining conflicting readings as an exact owner question.
- Every counterexample that C confirms becomes a permanent regression test
  on B's branch (B adds it; C re-runs it against the fix).
- C regression list and attack log: `orch-C/ATTACKS.md` (append only).
- C state: `orch-C/STATE.md`.

## Morning report

Each side writes `orch-X/MORNING.md` per DIRECTIVE §11 for its goals.
A writes the joint `MORNING_REPORT.md` after B confirms its part by message.
Final terminal summary: at most 20 lines (AGENTS.md).
