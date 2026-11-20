# Audit 2: smoke test of every public demo (2026-11-20)

`end_to_end=false`. Every result below is a FINITE TEST run on one shared, loaded machine. Times are wall times
and are indicative only (swap free was 0.7 to 1.7 GiB during the runs).

## Method

- Clone: `git clone` of the worktree HEAD `058eabcb` (= `origin/main`) into a scratch folder. Only
  `.toolchain` and `node_modules` were linked from the main checkout. No other file was copied.
- Tools: Node 24.3.0 (`/opt/homebrew/bin/node`, first in `PATH`), Python 3.10.11, `rustc` 1.92.0.
  `FORGE_AIRLOCK_NODE=/opt/homebrew/bin/node`.
- Heavy steps (Dafny, the 50-process demo, the gauntlet, the video take): run one at a time. Before each,
  three checks one minute apart found no `dafny/dafny`, `Holmake`, `z3-4.12.1` or `run_regression_copy`
  process. Each heavy step held `/private/tmp/claude-501/forge-locks/heavy.lock` (owner `AUDIT2`, or the video
  runner's own lock).
- Each demo ran with its documented command. Each demo that takes an engine or binary path also ran once
  with a path that does not exist.
- After the fixes: a second clean clone of HEAD, with the fix diff applied (`git apply`; nothing is
  committed), the documented build, and a rerun of the affected demo.

## Results

| # | Demo | Command (from the repository root) | Exit | Time | Headline | Verdict |
|---|---|---|---|---|---|---|
| 1 | Skeptic gauntlet | `python3 scripts/demo_gauntlet.py` (standard run, flood 600 MiB) | 0 | 118.2 s | Act 1: 4 of 4 verdicts (NO_CHOICE, EQUIVALENT, DIVERGES, CHOICE); Act 2: race 1 commit, 7 stale; flood 141 MiB peak, bound held; Act 3: 84 allocations committed, adversary 0 tokens, 0 prover processes seen | PASS |
| 1n | Gauntlet, no Node in `PATH` | same, `PATH` without `/opt/homebrew/bin` | 2 | 0.2 s | `JAVASCRIPT_TOOLCHAIN: Node executable differs from pin` | fails loudly |
| 1n | Gauntlet, no `.toolchain` (no Dafny) | `python3 scripts/demo_gauntlet.py --acts 1` | 1 (before fix) / 2 (after fix) | 0.9 s / 0.8 s | before: `GAUNTLET FAILED: act 1: the clearing tool gave no result`; after: `DAFNY_TOOLCHAIN: ... is missing` | FIXED (F3) |
| 2 | Unbreakable store | `bin/forge-airlock demo --json build/quickstart/demo.json` (quickstart step 7; it runs `examples/unbreakable_store/run_demo.py --engine-dir build/airlock --node <pinned>`) | 0 | 603.8 s | 8 of 8 disasters PASS, money leaked $0.00; 20 valid commits, 61 attacks blocked; fuzz 8 of 8 invariants HELD; Dafny starts seen 0 | PASS (slow: see F5) |
| 2 | same, before `build --checker` | same | 2 | 0.3 s | `NOT RUN: build/airlock/checker/model.cjs is missing` | fails loudly; doc gap (D1) |
| 2n | missing engine | `python3 examples/unbreakable_store/run_demo.py --engine-dir /nonexistent` | 2 | 0.4 s | `NOT RUN: /nonexistent/airlock-engine is missing` | fails loudly |
| 2n | missing Node | `python3 examples/unbreakable_store/run_demo.py --node /nonexistent/node` | 1 | 0.5 s | `FAIL: init: ... node /nonexistent/node cannot start` | fails loudly |
| 3 | HAL 9000 (`demos/hal_9000/run_discovery_one.py`) | — | NOT RUN | — | not present on `main` (`git ls-files` finds no `hal_9000`, `run_discovery_one`, `run_as_nobody`; the commits exist only on other branches, for example `backup/discovery-one-web-pre-rebase`) | NOT PRESENT |
| 4 | Archia MCP showcase | `python3 examples/archia_mcp_showcase/run_showcase.py --work <dir> --json build/archia.json --no-color` (default 10 GiB flood) | 0 | 17.4 s | 32 of 32 checks PASS; flood peak RSS 2496 KiB < 5120 KiB; evidence 25 + 4 + 32 records verified; tamper control exit 1 | PASS |
| 4 | `verify-evidence` before `bin/forge-mcp-proxy build` | `bin/forge-mcp-proxy verify-evidence <work>/fintech-proxy/store/evidence.wal --allowed-signers <work>/keys/allowed_signers` | 2 | 0.4 s | `build/mcp_proxy/mcp-proxy is missing: run forge-mcp-proxy build first` | fails loudly; doc gap (D2) |
| 4 | proxy build | `bin/forge-mcp-proxy build` | 0 | 3.8 s | one `rustc` build | PASS |
| 4 | `verify-evidence` (3 stores) | as above, for `fintech-proxy`, `healthcare-proxy`, `flood-proxy` | 0, 0, 0 | 0.6, 0.3, 0.7 s | `VERIFIED records=25/4/32 signatures=25/4/32 chain=OK continuity=OK` | PASS |
| 4 | `verify-evidence` tampered copy | `... <work>/tamper/evidence.tampered.wal ...` | 1 | 0.1 s | `FAILED at=0 ... frame check mismatch` | PASS (must fail) |
| 4n | missing proxy binary | `run_showcase.py --binary /nonexistent/mcp-proxy --no-color --no-pause --flood-gib 1` | 2 | 0.1 s | `SETUP ERROR: no proxy binary at /nonexistent/mcp-proxy` | fails loudly |
| 5 | Video cut (on `main`, unfixed) | `python3 demos/video_cut/run_recording_take.py --fast --lock-wait-min 20 --json build/vc.json` | 2 | 2.3 s | `CRASH: domain autonomy stopped: cosign keygen failed: forge-airlock: cosign-keygen <file> (no options; no Node is used)`; 0 shots | BROKEN (F1) |
| 5 | Video cut, F1 fixed only | same | 3 | 28.0 s | PARTIAL: `SIGKILL at a kill point: NOT IN TAKE (airlock-engine-kill is not built)` | BROKEN (F2) |
| 5 | Video cut, F1 + F2 fixed (first clone) | same | 0 | 30.6 s | full take, 68 shots, 0 failed checks; sabotage control: unsabotaged exit 0, sabotaged exit 1; live model call status 200 | PASS |
| 5 | Video cut, F1 + F2, SECOND clean clone | `python3 bin/forge-airlock build --checker` then `python3 demos/video_cut/run_recording_take.py --fast --lock-wait-min 20` | 0, 0 | 13.5 s, 46.9 s | full take, 68 shots, 0 failed checks | PASS (fix proved from a clean checkout) |
| 5 | Video cut test | `python3 demos/video_cut/test_video_cut.py` (fixed first clone) | 0 | 34.6 s | 39 checks, 0 failed | PASS |
| 5n | missing engine | `run_recording_take.py --fast --no-model --engine-dir /nonexistent --lock-wait-min 20` | 2 | 0.2 s | `TAKE NOT USABLE (exit 2): /nonexistent/airlock-engine is missing`; lock released | fails loudly |
| 6 | Web showcase (`demo/discovery-one-web`, `web_showcase/`) | — | NOT RUN | — | not present on `main` (no such folder; no tracked file); exists only on branch `backup/discovery-one-web-pre-rebase` | NOT PRESENT |
| 7 | Universal self-repair | `rustc --edition 2021 -D unsafe_code -C opt-level=3 src/primitives_v2/main.rs -o build/primitives_v2/primitives-engine` then `python3 examples/universal_self_repair/run_demo.py --json build/usr.json` | 0, 0 | 4.4 s, 1.3 s | `RESULT: ALL 16 CHECKS PASS` | PASS |
| 7 | self-test | `python3 examples/universal_self_repair/run_demo.py --self-test` | 0 | 13.6 s | 13 of 13 canaries FAILED their check as they must | PASS |
| 7 | demo test | `python3 tests/primitives_v2/test_demo.py build/primitives_v2/primitives-engine` | 0 | 21.9 s | canary coverage: each of the 16 checks FAILED under at least one canary; missing_engine PASS | PASS |
| 7n | missing engine | `run_demo.py --engine /nonexistent/primitives-engine` | 2 | 0.1 s | `FATAL: ENGINE MISSING ... nothing is canned` | fails loudly |
| 8 | Quickstart step 1 | `bin/forge-airlock build` | 0 | 7.2 s | engine, kill build, refund copy SHA-256 `b8ed5ec2…7bb8` | PASS |
| 8 | Quickstart checker build | `bin/forge-airlock build --checker` | 0 | 12.2 s | Dafny verify exit 0, 46 verified, 0 errors | PASS |
| 8 | Quickstart step 2 | `rm -rf build/quickstart && mkdir -p ... && bin/forge-airlock init ... --node "$FORGE_AIRLOCK_NODE"` | 0 | 1.0 s | `INITIALIZED quickstart <nonce>` | PASS |
| 8 | Quickstart step 3 | `python3 build/quickstart/hello.py` (heredoc copied byte for byte from the page) | 0 | 0.3 s | all 5 expected lines | PASS |
| 8 | Quickstart step 4 | `"$FORGE_AIRLOCK_NODE" build/quickstart/hello.ts` | 0 | 0.3 s | all 5 expected lines | PASS |
| 8 | Quickstart step 5 | `replay`; `leases`; `leases --sweep` | 0, 0, 0 | 0.1 s each | 4 effects; 1 open lease (`wh-2`); `SWEEP 1 0` (deadline not yet passed) | PASS |
| 8 | Quickstart step 6 | `bin/forge-airlock diff-policy ... refunds-v2.json --no-clearing` | 3 | 0.2 s | 4 rows CHANGED (rows 8 to 11); `CLEARING_NOT_RUN (exit 3)` as documented | PASS |
| 8 | Quickstart step 7 | see row 2 | 0 | 603.8 s | see row 2 | PASS after `build --checker` |
| 9 | `examples/binary/` | — | NOT RUN | — | not a demo: a Rocq proof record of a RISC-V Linux ELF; its README needs a prepared Linux volume (`scripts/stage7_build_own.py`, `exit_stage_7.py --case own-proof`) | NOT RUN (out of scope) |

## Findings

- **F1 (video cut broken on `main`).** `demos/video_cut/harness.py` called `bin/forge-airlock cosign-keygen <file> --node <node>`
  and `cosign-sign <file> --node <node>`. Pull request 72 (native cosign, `ssh-keygen -Y`) removed every option of
  these two commands (`cmd_cosign`: "no options; no Node is used"). Pull request 75 (video cut) was written
  against the old Node helper. Result on `main`: the take crashes at domain 1, exit 2, 0 shots.
  `test_video_cut.py` fails for the same reason.
- **F2 (video cut PARTIAL on `main`).** Pull request 73 moved the kill-points build from
  `build/airlock/airlock-engine-kill` to `build/silicon/test/airlock-engine-kill` (review F2). The video cut
  looked only in `<engine-dir>/airlock-engine-kill`. Result: domain 9 skipped its SIGKILL part, exit 3.
- **F3 (gauntlet exit code for a missing Dafny).** `docs/demo-gauntlet.md` says exit 2 for a missing tool. With no
  `.toolchain`, the script started Act 1, the clearing tool crashed, and the gauntlet exited 1 ("a required result
  was not observed"). It failed loudly; only the class of the exit code was wrong.
- **F4 (directive flags).** `scripts/demo_gauntlet.py` has no `--fast` and no `--no-color`; it has `--flood-mb N` and
  `--acts`. A flood below 512 MiB or a subset of acts is a REDUCED/PARTIAL run (exit 3), by design; the standard
  run (600 MiB) is the shortest full run. No flag was added: a "fast" pass would contradict the documented exit
  rules. `run_recording_take.py` has `--fast` and `--no-color`. `run_showcase.py` has `--no-color` and `--no-pause`.
  The HAL flags (`--fast --no-color`) cannot be checked: the demo is not on `main`.
- **F5 (time).** The unbreakable-store demo took 603.8 s here. No document states its duration. The machine had
  0.7 to 1.1 GiB free swap; Python p99 latency was 729 ms. This is a measurement on a loaded machine, not a defect
  that was shown.
- **F6 (minor, not fixed).** `.gitignore` has `.toolchain/` and `node_modules/` with a trailing slash. The linked
  symbolic links of the documented clone method show as untracked (`?? .toolchain`, `?? node_modules`). A form
  without the slash would match both. Not a demo fault; not changed.
- **Not shown by this audit.** HAL items (23 of 23 checks, zero Node on the `ssh-keygen -Y` path, the
  two-terminal `run_as_nobody.sh` command) and every web-showcase item: the files are not on `main`.
  No `run_as_nobody.sh` exists on `main`, so no command can be printed. OS user ID separation stays NOT TESTED.

## Fixes made (worktree, uncommitted)

| File | What | Why |
|---|---|---|
| `demos/video_cut/harness.py` | Remove `'--node', self.node` from the two `cosign-keygen` calls and the `cosign-sign` call; docstring of `sign` names the SSHSIG token, not "hex" | F1. The dispatcher refuses any option on these commands since pull request 72 |
| `demos/video_cut/domains/d9_crash_flood.py` | New `KILL_BUILD = build/silicon/test/airlock-engine-kill`; `kill_part` uses it when `<engine-dir>/airlock-engine-kill` is absent and the engine folder is the default `build/airlock`; the on-screen note prints the real path | F2. The kill-points build moved in pull request 73 |
| `scripts/demo_gauntlet.py` | In `main`, after the Node check: if the pinned Dafny file is missing, raise `DAFNY_TOOLCHAIN: ... is missing` (exit 2) before any act starts | F3. Match the documented exit code 2 for a missing tool |

Bundle check: no `scripts/exit_*.py` lists any of these three files as a subject. No committed record pins the
current SHA-256 of any of them (the old SHA-256 `a26cac63…` of `demo_gauntlet.py` in
`proposals/forge2-demo-gauntlet/records/regression.json` is of an earlier version; that record is unchanged).
No protected or frozen path was touched. No package was added. The full gauntlet was NOT rerun after F3: the new
lines run only when the Dafny file is missing (verified in the second clean clone: exit 2, no work folder made).

## Fixes NOT made (bundle subject or document; for the documents worker)

- **D1, `docs/quickstart-5min.md` step 7** (bundle subject of `scripts/exit_goal20_sdk.py`, and a document). On a
  clean checkout `bin/forge-airlock demo` exits 2 (`model.cjs is missing`) unless `build --checker` ran. The page
  calls the checker "for inventory bookings only"; the demo has an inventory disaster (D8). Proposed diff:

  ```diff
   ## 7. The demo
   
  +The demo needs the booking checker (disaster 8 books seats). Run `bin/forge-airlock build --checker` once
  +before it (Dafny; one Dafny job at a time). Without it the demo prints `NOT RUN: ... model.cjs is missing` and
  +exits 2.
  +
   ```sh
   bin/forge-airlock demo --json build/quickstart/demo.json
  ```

- **D2, `examples/archia_mcp_showcase/README.md`** (bundle subject: `examples/archia_mcp_showcase/**/*` in
  `scripts/exit_archia_mcp.py`). The showcase builds its proxy in the work folder, so `bin/forge-mcp-proxy
  verify-evidence` by hand exits 2 until `bin/forge-mcp-proxy build` ran. Proposed diff, after the `--json` item:

  ```diff
  +- Check an evidence file by hand (after the run): `bin/forge-mcp-proxy build` once, then
  +  `bin/forge-mcp-proxy verify-evidence <work>/fintech-proxy/store/evidence.wal --allowed-signers <work>/keys/allowed_signers`
  +  (also `healthcare-proxy`, `flood-proxy`). Exit 0 = every record signed and chained.
  ```

- **D3, `docs/VIDEO_STORYBOARD.md` line 483** (document): "also makes the kill-points build
  `build/airlock/airlock-engine-kill`" is out of date; the build makes `build/silicon/test/airlock-engine-kill`.
- **D4, `ROADMAP.md` video-cut rows (lines 238 to 242)** record exit 0 for `test_video_cut.py` and the takes.
  Those runs were before pull requests 72 and 73 reached `main`; on `058eabcb` the take exits 2 (F1). A note is
  due when the fix lands.

## NOT RUN

- HAL 9000 demo and the web showcase: not present on `main` (owner deleted them 2026-11-20). Not rebuilt.
- `examples/binary/`: a proof record, not a demo; needs a prepared Linux volume.
- `examples/unbreakable_store/run_demo.py` by its own path for the full run: it ran once through
  `bin/forge-airlock demo` (the same script, with `--engine-dir build/airlock --node <pinned>`); a second
  10-minute heavy run on the shared machine was not made. Its two negative runs used the script path directly.
- `diff-policy` without `--no-clearing` (Dafny; the page says that form was not run either).
- `demo_gauntlet.py --flood-mb 10240`.
