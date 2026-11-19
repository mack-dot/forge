# Rules for every Orchestrator-B worker (night shift 2026-11-19). Binding.

Repository: <REPO> (main checkout, branch docs/m1b-wave4, commit 985f5eaf). READ-ONLY for you,
except your own evidence directory under results/night-shift-20261119/orch-B/<task>/ (untracked). Write all
new files there. Use absolute paths. Do not use git to commit, push, merge, checkout, stash or reset.

Hard prohibitions:
- No merge, push, sign, deploy, release, tag. No change of GitHub settings. No `gh` write call.
- No change to protected files: gate/, policy/, spec/, toolchain/, schemas/, .github/, governance/, spec.lock,
  AGENTS.md, scripts/javascript_env.py, scripts/build_model.py, interop/export.cjs, interop/model.ts,
  tests/ledger.property.ts, tsconfig.json, package.json, package-lock.json. Never put a file under clearing/.
  A fix to such a file is an UNAPPLIED diff in your evidence directory, checked with `git apply --check` only.
- No edit of unsure.md or ROADMAP.md (the orchestrator does that). No edit of existing files under proposals/.
- No real keys, owner credentials, tokens or production data. Test keys are generated in your directory only.
  Run any generated or hostile program with a scrubbed environment (`env -i PATH=... HOME=<your dir>`).
- Do not touch HOL, the replay driver (results/round4-m1-replay-20261118), or any process you did not start.
- Do not spawn sub-agents.

Resources (the machine is under memory pressure; a HOL replay runs):
- Every Dafny run goes through
  <REPO>/results/night-shift-20261119/orch-B/tools/dafny_locked.sh OWNER WORKDIR LOGFILE TIMEOUT_S <dafny args>
  It holds dafny.lock, checks AC power and swap, records the command, time, memory and a last line `exit N`.
  Use the gate options: `verify --solver-path <REPO>/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1
  --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --track-print-effects FILE.dfy`
  (add `--log-format csv;LogFileName=...` for a per-obligation record). TIMEOUT_S <= 90 is a light check.
  Exit 75 = refused (battery or low swap), 76 = lock wait expired, 124 = timeout: record it as NOT RUN, wait a few
  minutes, retry at most 5 times, then go on with other work and report it.
  Never start Dafny directly. Keep each new log; never overwrite a failing log (number them).
- NO Node stress test, differential fuzz, kill/race run, or memory/CPU-exhaustion experiment while
  results/night-shift-20261119/locks/hol.lock exists or `pgrep -f 'bin/hol'` finds a process or swap free < 1 GB.
  A single short Node or Python run (seconds, small memory) is allowed. Pinned Node: put /opt/homebrew/bin first in
  PATH (Node 24.3.0); check `node --version`.
- Pinned Dafny 4.11.0 pitfalls: `module X refines SinkCore {}` crashes the resolver; `dafny verify` does not
  re-check inherited lemmas of a refinement instance (`dafny build` does).

Truth rules:
- Classify each claim: MACHINE-CHECKED / ASSUMPTION / TESTED-UNPROVED / MISSING. Actual exit codes only.
  A command that did not run is NOT RUN. Do not turn a guess into a pass.
- No `assume`, `{:axiom}`, bodiless lemma, `{:verify false}`, `expect` or `{:extern}` in a proof you claim. Run
  `dafny audit` (through the lock script) on claimed proofs and store its report.
- A proof needs controls: (a) a non-vacuity witness (the hypotheses hold in a concrete run where something
  commits), (b) mutants or weakened hypotheses that must FAIL, (c) a statement why a reject-all system would not
  pass. A false theorem with a minimal counterexample is a good result.
- Preserve zero-amount refunds: the approved spec/refund/protocol.md says zero is a legitimate authorization.
- Style of written text: short sentences, active voice, consistent terms.

Final report (your last message, at most 60 lines): what is MACHINE-CHECKED with the exact command, log path and
exit code; SHA-256 of each new source file; counterexamples; what is NOT RUN and why; open doubts; files written.
Also write the same text to REPORT.md in your evidence directory.

AMENDMENT 09:30Z (PROTOCOL.md): a heavy step (Dafny TIMEOUT_S > 90 included) may start if swap free >= 1024 MiB, OR (memory free >= 40 % AND swap free >= 512 MiB). The lock script applies it. heavy.lock items still never run while hol.lock exists.
