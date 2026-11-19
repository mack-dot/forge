# Orchestrator C (red team) state

Started 2026-11-19T14:19:25Z. Branch nightshift/C-redteam from 4af09308 (B head). Worktree: /private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/wt.
Target with adoption-v6.diff applied (uncommitted, read-only use): /private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/target-v6. A target: dae1b93e.
unsure block U580-U619: none used yet. C holds no lock. HOL lock held by A at start (no heavy run by C).
Partner IDs: B a56d4886a49375909, A aabe04fa1c6495747.

## Wave 1 (started 14:19Z); workers: opus, light runs only
| Worker | Class | Evidence dir | State |
|---|---|---|---|
| c1-concurrency | parallel writers, crash, restart, retry | orch-C/c1-concurrency | DONE; re-run by C; see ATTACKS.md |
| c2-malformed | malformed inputs, serializer, decoder, value conversion | orch-C/c2-malformed | DONE: C-ATT-01 (known, open), C-NEG-01; re-run by C |
| c3-identity | identity substitution, cross-charge, replay, zero value | orch-C/c3-identity | DONE; re-run by C; see ATTACKS.md |
| c4-rollback | rollback, forged initial state, database tamper, dispatcher ledger | orch-C/c4-rollback | DONE; re-run by C; C-ATT-10..13 |
| c5-gate | gate rule 3: bypass and false rejection | orch-C/c5-gate | DONE; re-run by C; C-GATE-01..04 |
| c6-premises | A's theorem premises against the real executable | orch-C/c6-premises | DONE; re-run by C; see ATTACKS.md |

## 14:22Z B's reply (data)
- B head de538868 (pushed); sink, dispatcher, minter, gate rule unchanged on the branch; target 4af09308 + adoption-v6.diff stays valid.
- B's known limits (not new if found again): zero-amount row deletion/reorder/re-commit (U565); whole-file and prefix rollback; initial charge authentic only by configuration; key or pin rotation refuses a legitimate store; minter pre-state hash is one unchecked TypeScript line; rule 3 refuses 21 of 67 correct.
- B works on: h-sink (database-level safeguards, triggers, row-log chain head with expectedHead), h-regress (tests/refund-finality/regress/ with a runner that takes a sink module path), h-anchor, h-specdiff, h-gate. B sends SHA and diff path when each lands. NEXT for C: re-attack h-sink when it lands; run h-regress against the C checkout.
- B needs per counterexample: class; target SHA; exact command; expected vs actual; smallest input files with SHA-256.

## Checkpoint 14:32Z
- Branch nightshift/C-redteam at 4432fe1c, PUSHED (explicit refspec). unsure U580-U583 used; next U584.
- Confirmed and sent to B (14:32Z, 14:42Z): C-ATT-01..09, C-CLOSED-01 (see ATTACKS.md). B regressions: PENDING for all. No fix SHA received yet.
- Sent to A: premise audit. A's reply: T12 fixed in END_TO_END_GAPS.md; one non-vacuity witness theorem queued; new draft orch-A/x8-x11/X8_statement.txt offered for attack.
- Running: c4-rollback, c5-gate, c7-minter (wave 1); c8-dispatcher, c9-x8 (wave 2, started now).
- Branch copies have home paths replaced by <REPO>/<SCRATCH>; runnable originals are in the main checkout orch-C/ (untracked).
- To resume: re-run commands are in ATTACKS.md; when B sends a fix SHA, run each listed command against a checkout of it and append PASS/FAIL to ATTACKS.md.
- 14:34Z: c4 DONE (C-ATT-10..13 confirmed, sent to B). B fix de71cf4d for C-ATT-01: C re-run PASS (overlay <SCRATCH>/redteam-C/fix-de71cf4d, 516K: git archive of a few paths + v6 diff; make the same kind of overlay for later fix SHAs). B routes ATT-02/04/06 to h-sink, ATT-03 to h-minter; no SHA yet.
- 14:35Z: B head 1481d818: X6-P1 prints KNOWN-LIMIT; new tests/refund-finality/spec-conformance/ (oracle from compiled Assess). h-sink has batch 3 as acceptance tests (integrity_check, uniqueness from table rows, halt when the remembered head is not extended); no fix SHA. Started c10-judges (mutation attack on B's regress runner and spec-conformance oracle at 1481d818). Running: c5, c7, c8, c9, c10.
- 14:40:39Z: c7 DONE (C-ATT-14..16, C-NEG-06; re-run by C). TIME CORRECTION appended to ATTACKS.md (typed times before this line were estimates). Running: c5, c8, c9, c10.
- 14:41:50Z: POWER AMENDMENT read in PROTOCOL.md (line 123): battery no longer blocks heavy steps; log pmset at each heavy start; checkpoint STATE.md before each heavy step; memory, swap, disk gates unchanged. C's workers stay LIGHT while hol.lock is held (heavy.lock rule unchanged: never with a HOL process). C has started no heavy step so far.
- 14:42:34Z: B fix 216dfbe2: C-ATT-16 re-run PASS. Overlay tool: <SCRATCH>/redteam-C/mkoverlay.sh <sha>. Open list is in ATTACKS.md.
- 14:44:14Z: c9 DONE (C-PREM-01 static, C-NEG-07 re-run by C); sent to A. Running: c5, c8, c10.
- 14:44:47Z: A recorded C-PREM-01 in orch-A/x8-x11/CORRECTIONS.md (A-F0-REAL named; fail-closed overclaim withdrawn; indexing and killed-run clause go to A's trace-lemma worker). A will send theorem names with exit 0 (MT-0001, trace lemma, non-vacuity witness) for a premise audit: NEXT for C when they arrive.
- 14:49:11Z: c10 DONE (C-JUDGE-01..03 confirmed by C's re-runs; sent to B). Running: c5, c8 (c8 waits on its chain search).
- 14:49:41Z: branch nightshift/C-redteam at da4e7a4f, PUSHED. Branch copy excludes work dirs, extracted trees, c5-gate and c8-dispatcher (still running). TODO next commit: unsure entries U584+ for C-ATT-10/11, C-ATT-14/15, C-JUDGE-01..03, C-PREM-01; c5 and c8 results. Running: c5, c8.
- 14:50:23Z: U584-U587 written; branch pushed at d491a250. Next unsure id U588.
- 14:52:11Z: c8 DONE (C-ATT-17..20, C-NEG-09), c5 DONE (C-GATE-01..04); all re-run by C. No worker runs now. NEXT: wave 3.

## Wave 3 (started 14:54:12Z); memory free 46 %, swap free 775 MiB, disk 85 GB; hol.lock held by A: light runs only
| Worker | Class | Evidence dir | State |
|---|---|---|---|
| c11-host | host and CLI layer: exit-code truth, retries, config, environment | orch-C/c11-host | running |
| c13-gate-js | gate: verified source versus compiled JavaScript for admitted submissions; assume/axiom in skipped ghost code | orch-C/c13-gate-js | DONE; C-GATE-05 re-run by C (recognizer); C-NEG-15 |
| c14-parser | native refund executable versus the Python strict parser versus the HOL parser definition | orch-C/c14-parser | running |
| c15-storage | hot journal, symbolic links, ENOSPC/short writes, fsync, two path names | orch-C/c15-storage | running |
- Pending from B: fix SHAs for h-sink (C-ATT-02, 04, 06, 10, 11, 12, and now 17, 18, 20), h-minter (03, 15), h-judges (C-JUDGE-01..03), gate (C-GATE-02..04). On arrival: mkoverlay.sh <sha>, re-run the commands in ATTACKS.md, append PASS/FAIL.
- TODO next commit: unsure U588+ for C-ATT-17..20 and C-GATE-01..04; sync c5-gate and c8-dispatcher into the branch.
- 14:54:37Z: U588, U589 written; branch pushed at 2528d6e5. Next unsure id U590. c5 gatecopy (a patched copy of the protected gate file) is NOT in the branch.
- 15:06:02Z: re-run on 608b5165 recorded (table in ATTACKS.md): C-ATT-03, 15, 02 PASS; 14 open (assumption); 05 present; sink/dispatcher items need porting -> worker c16-hsink; c17-hminter attacks the new minter rule. c11 DONE (C-HOST-01..07), c14 DONE (C-PREM-02, C-NEG-11); all re-run by C. Running: c13, c15, c16, c17.
- 15:06:20Z: A recorded C-PREM-02: T14 in orch-A/END_TO_END_GAPS.md reworded in two UNPROVEN parts (parser equality restricted to non-negative values; the program prints non-negative values only).

## LAUNCHER PRIORITIES (received 15:09:43Z; metric = attack classes eliminated and independently confirmed)
1. Tight loop: when B sends a fix SHA for C-ATT-10/04/17/18/20, re-attack it FIRST, then vary (other non-canonical encodings, other index/trigger damage, lock-owner races, emit failures at each step).
2. When B proposes the provider-idempotency rollback anchor: attack its assumption with a fake provider (key reuse, key expiry window, a different key per retry).
3. Gate: after each new rule-3 version, re-run all known unsafe and all known-correct submissions; grow both sets; a fix that raises false rejections is a finding. (Sets so far: orch-B/e-subset3/subs + orch-C/c5-gate/bypass, fr; runner c5-gate/tools/task3.py, regress.sh.)
4. Then A's side: the native process boundary (DYLD injection, truncated stdout, FFI abort vs error byte): are A's premises excluded in words only or in the actual launch path. -> worker c18-launch started now.
5. Push nightshift/C-redteam after each wave.
- 15:10:48Z: U590 written; branch pushed at f5c0fc3f. Next unsure id U591. Running: c13, c15, c16, c17, c18.
- 15:10:52Z: A: all four C-PREM-01 points accepted (orch-A/x8-x11/ANSWER_C-PREM-01.md); restated draft X8_statement_v2.txt may be attacked (low priority: still a draft, 14 model lemmas MISSING). A builds launch-path controls in orch-A/launch/ (launcher.py, CONTROL_MATRIX.md) for AC-1 truncated/empty stdout, AC-2 DYLD, AC-3 FFI abort: NOT ready. When A sends the line: re-attack each control row (c18-launch attacks the existing draft launcher proposals/.../fail-closed/m1_fail_closed.py meanwhile; reuse its scripts on orch-A/launch/launcher.py).
- 15:12:56Z: c15 DONE (C-ATT-21..23; re-run by C). c18 STOPPED by a safety classifier (C-BLOCK-01): no result; C does control checks of the launcher itself (no injected code). Running: c13, c16, c17.
- 15:13:51Z: BLOCKER C-BLOCK-01: launch-path attack (priority 4) stopped twice by a safety classifier (worker c18, then C's own control script; nothing written, nothing run). NOT retried. Goes to OWNER_REQUIRED as C-1. Continue with priorities 1-3. Running: c13, c16, c17.
- 15:39:19Z: c16 and c17 DONE and re-run by C. Closed on 608b5165: C-ATT-04, 06, 10, 11, 12, 20; zero-amount commits. Still open/new: C-ATT-24 (old-row running), 25/32 (D14 past anchors), 26 (long-intent false rejection), 27 (stale anchor), 28 (lost ledger), 29 (stale-retry false rejection), 30 (minter squat), 31 (tsx cache). Running: c13.
- 15:40:13Z: U593 written; pushed at c7b1866d. Next id U594. Running: c13.
- 15:40:33Z: checkpoint. Branch pushed c7b1866d. One worker running (c13 gate-js). No HOL process. Pending B fix SHAs to re-attack: dispatcher lock C-ATT-17/18 (h-dispatch), test judges C-JUDGE-01..03 (h-judges), gate C-GATE-02..04, sink C-ATT-24/26 (long-intent + old-row), minter C-ATT-30 squat. On each SHA: mkoverlay.sh or retarget, re-run the listed commands, append PASS/FAIL. Holding worker count per launcher priority 1 (re-attack first, not volume). Confirmed-closed so far: C-ATT-01, 16; C-ATT-04,06,10,11,12,20 (by hardened sink); C-ATT-03,15 (by hardened minter).
- 15:43:08Z: U591, U592 written; branch pushed at c7b1866d. Next unsure id U593.
- 15:46:52Z: B sent f08a21c1 (new dispatcher + judges cf242303). My hand re-run of old scripts = module-not-found (API changed); discarded. Started c19-dispatch2 (port + re-attack dispatcher and judges) and c20-launch-read (reading-only audit of orch-A/launch, within safe scope). B's U577 recorded my 608b5165 table. B next: a second sink change (C-ATT-24,26,27,21,23,fullfsync) and second minter change (C-ATT-29,30,31). Running: c13, c19, c20.
- 15:51:25Z: c20-launch-read DONE (static reading only; worker found F1 SIGCHLD/returncode-0, F2 csops TOCTOU, F3 no write deadline; words-only premises). I CANNOT spot-check: the classifier stops my own reading of launcher.py (extends C-BLOCK-01). Relayed to A as the worker's analysis, unverified by C. Running: c13, c19.
- 15:51:39Z: pushed 0616e1b2. Running: c13 (gate), c19 (dispatcher+judges on f08a21c1). Pending: B's second sink/minter SHA.
- 15:56:19Z: c13 DONE. C-GATE-05 (rule 3 admits bodiless 'ensures false' lemma ending in a set display) CONFIRMED by C's recognizer run; gate still safe via Dafny warning default + audit (worker Dafny runs). Sent to B. Running: c19.

## RESUMED 16:08:12Z (launcher order after the handback). Loop continues.
- Branch nightshift/C-redteam pushed at 2b6afb88; unsure U580-U594; next id U595. B newest head origin/nightshift/B-trust = dd3bec6e (U578 suite record; no new sink/minter/dispatcher beyond f08a21c1 and judges cf242303).
- c19-dispatch2 did not deliver a report (it was waiting on its own background run); it left evidence files (hport.ts, judges/, logs/, a7_full_restore.ts, a8_paths.ts, a6_fsize.ts). I COLLECT its logs and re-run the key cases myself before recording anything; until a real exit code exists each is NOT RUN.
- Launch-path RUN test stays blocked (C-1); no retry, no rephrase. Static reading of the launch path is allowed but the classifier stops even my own reading, so c20's relayed audit is the only launch material and is unverified by me.
- 16:10:02Z: c19 re-run gave mixed exits but its scripts are UNVALIDATED (a4 TypeError, a5 config error, a2 empty): preliminary only, NOT recorded as confirmed. Striking: a8_paths link -> effects [r1,r1]; a7_full_restore nofloor -> recommit committed. B moved to newest head 88ae6cbf (h-sink2) for C-ATT-21,23,24,25,26,27. Building overlay; authoritative re-attack worker next.
- 16:11:34Z: swap recovered to 1613 MiB; started worker c21-sink2 (authoritative re-attack of 88ae6cbf h-sink2: C-ATT-21,23,24,25,26,27 + unchanged dispatcher C-ATT-17,18,19full,28; cross-checks B's adapted scripts for neutering; honest-flow fuzz). c19's exits are preliminary/unvalidated (scripts buggy): NOT recorded as confirmed. Overlay fix-88ae6cbf built. Running: c21.

## OWNER INSTRUCTION (launcher relay, received 16:12:03Z), in order:
1. STATE.md checkpoint repaired (this append; earlier sections untouched).
2. I run the re-test of B's newest dispatcher MYSELF: C-ATT-17 (lock/fencing) and C-ATT-18 (lost emit). Record SHA, command, exit.
3. Native launch path: static code audit, then defensive conformance tests for the launcher (test_process_lifecycle.py): refuse unless stdout complete, exit status checked, cleared environment, FFI abort -> specified error. Named plainly. If the classifier stops a command: record under C-1, no retry, no rephrase, next task.
Split kept: C writes tests that show a gap; B writes fixes.
- 16:12:50Z: TASK 2 done by C itself: C-ATT-17 (lock theft, claim race) and C-ATT-18 (throwing emit) on 88ae6cbf70c5: exit 0 each; effects inspected (no duplicate; lost emit now visible as in-doubt). PASS. Independent fresh-script re-attack continues in c21.
- 16:15:01Z: TASK 3 done: static audit + test_process_lifecycle.py (24 tests, exit 1: 22 ok, 2 FAIL). C-LAUNCH-01 CONFIRMED by run (SIGCHLD ignored -> launcher AUTHORIZES an aborted / non-zero child). Sent to A. C-1 addendum appended to OWNER_REQUIRED. Running: c21 (c19 still silent).
- 16:17:17Z: C-LAUNCH-01 re-run on A's launcher_v2.py (eec38a10…): 24/24 OK, exit 0 twice; v1 still exit 1 (2 FAIL). CLOSED. B sent the new gate proposal (h-gate/js_bound_check.cjs at 6775e46e; U620): next = worker c23 attacks it and grows the gate sets (launcher order item 5). Running: c21; c19 silent.
- 16:18:07Z: started worker c23-jsgate (attack on B's new JavaScript-tier gate checker h-gate/js_bound_check.cjs; grows the correct and unsafe sets; measures the false-rejection rate). Running: c21 (88ae6cbf sink2), c23 (gate). c19 silent.
- 16:21:58Z: re-run on B's minter rule 2 (370ff65c, NoStore): C-ATT-29 PASS, C-ATT-30 fake PASS, zero still present (stated limit), C-ATT-31 still present on the tsx path (closed launch script NOT tested), fuzz 0 divergences. Started c24-minter2 (Store mode, closed launch, STORE-READ). Running: c21, c23, c24.
- 16:22:53Z: worker c24-minter2 STARTED (Store mode honest flows, which refusals close a request id, STORE-READ, the closed launch script, model versus code by reading). A safety classifier stopped my response while I wrote its brief: the brief ends mid-sentence (the last line about the report format is missing; WORKER_RULES covers it). Recorded under C-1; the withheld text is NOT resent. Running: c21, c23, c24.
- 16:33:48Z: c19 and c21 DONE; key cases re-run by C (table in ATTACKS.md). New: C-ATT-33 (crash before COMMIT bricks the hardened store; HIGH false rejection), 34 (recover skips its one-row check), 35 (replaced inode in a commit), 36 (retry + ledger restore re-sends 1200/1000; HIGH), 37 (path cases). Closed on 88ae6cbf: C-ATT-17, 18, 23 hard link, 24, 25 with anchor, 26. blindspots2.sh re-run in background (b3p3kilen). Running: c23, c24.
- 16:34:54Z: U596 written; pushed 03644bd0. Next unsure id U597. Branch scrub tool: <SCRATCH>/redteam-C/scrub.py <branch orch-C dir> (run after each rsync; rsync overwrites the scrubbed copies). In zsh use explicit commands or ${=var}: an unquoted variable is NOT split. Running: c23, c24; background b3p3kilen (blindspots2.sh).
