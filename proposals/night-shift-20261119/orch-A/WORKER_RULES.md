# Rules for every Orchestrator A worker (binding)

Repository: `/Users/mackianni/forge` (main checkout, branch `docs/m1b-wave4`, commit `985f5eaf`).
Toolchain (read-only): `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/{HOL,cakeml}`.
M1-B drafts and reports: `/Users/mackianni/forge/proposals/m1b-mission-20261119/{drafts,reports}`, `TRACKER.md`,
`TOP_LEVEL_GRAPH.md`, `NEXT_OBLIGATIONS.md`.

## Forbidden
- Do NOT start `hol`, `Holmake`, `poly`, or any HOL/CakeML build. A replay job owns the single HOL slot.
  Do not touch, signal or wait on that job. Do not touch `results/round4-m1-replay-20261118/` (read only).
- No heavy job: no Dafny run longer than 60 s, no Node stress test, no full-disk hashing. Use `nice -n 15`
  for any scan. The machine has little free swap.
- No `git commit`, `push`, `merge`, `checkout`, `stash`, `worktree`. No signing, no deployment. No change to
  any tracked file. No change to `gate/`, approved specs, policy, `ROADMAP.md`, `unsure.md`.
- Write ONLY inside your evidence directory. To change a draft, copy it there first and record
  the SHA-256 of the original and of your copy, plus a unified diff.
- Do not spawn subagents.

## Truth rules
- A statement is a result only with evidence: a command with its ACTUAL exit code, a file path with a line
  number, or a digest. Mark every command that did not run as NOT RUN. Never write an expected exit code as actual.
- A tactic that you did not run in HOL is UNCHECKED. Say so. A static review cannot show that a proof passes.
- Do not weaken a theorem statement silently. If you propose a changed statement, give old text, new text, and why.
- Never add `cheat`, `mk_thm`, `new_axiom`, or an oracle.
- Classify: MACHINE-CHECKED / ASSUMPTION / TESTED-UNPROVED / MISSING.
- A counterexample or a validated blocker is a good result. A convincing explanation alone is not.

## Report
Write `REPORT.md` in your evidence directory (short sentences, active voice). Then give a final answer of at most
40 lines: files written (absolute paths, SHA-256), defects found (file:line), what is ready to run, what is not,
and every command you ran with its actual exit code.
