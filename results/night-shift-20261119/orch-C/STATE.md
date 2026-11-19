# Orchestrator C (red team) state

Started 2026-11-19T14:19:25Z. Branch nightshift/C-redteam from 4af09308 (B head). Worktree: <SCRATCH>/redteam-C/wt.
Target with adoption-v6.diff applied (uncommitted, read-only use): <SCRATCH>/redteam-C/target-v6. A target: dae1b93e.
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
- 16:37:39Z: my first re-run of c19-dispatch2/judges/blindspots2.sh ended with exit 124 (my own 500 s time limit): NOT a result. Restarted in the background (b12wmi6em, limit 1700 s; log refix/f08a21c1/C-blindspots2.log ends with 'blindspots2 exit=N'). The judge result for cf242303 stays NOT CONFIRMED until then. Running: c23, c24.
- 16:39:20Z: c24 DONE; minter/store findings re-run by C (C-ATT-38 spray squat, 39 cached inode, 40 off-retry; C-NEG-16). s10 closed-launch tests NOT re-run (classifier stops the launch class, C-1); worker runs stand for those. Running: c23; background b12wmi6em (judge re-run).
- 16:40:18Z: U597 written; pushed e0178950. Next id U598. Running: c23 (gate); background b12wmi6em (judge re-run).
- 16:44:46Z: status sent to the launcher by SendMessage (to main): steps 1-3 done; C-1 stops listed; new C-ATT-33, 36, 38; running c23 + background judge re-run (b12wmi6em). Loop continues.
- 16:50:13Z: judge re-run DONE by C: blindspots2.sh exit 1 (3 defective inputs still pass both judges: md_ignore_sig, enc_unsigned_body, e_emit_twice_hidden2); 9 of 12 old mutants caught; C-JUDGE-02 and C-JUDGE-03 closed. Sent to B. Running: c23.
- 16:51:56Z: LAUNCHER ORDER (after my second end of run): (1) record c23 and the judge re-run; (2) ask B for repair SHAs for C-ATT-33/36/38; (3) attack the nearest unproved boundary; status to main after each wave (max 10 lines). Launcher's own check L-CHK-01: d_att17/d_att18 exit 0 on 88ae6cbf, exit 1 on 608b5165.
  - Done: judge re-run recorded (exit 1; 3 still pass). c23 NOT REPORTED yet (it waits in B's Dafny lock queue). Issuer module I used for the dispatcher re-test: orch-B/h-minter/build/issueonce.cjs, SHA-256 4cf78df8cb0651afcf1ff4b28ac1c96d2f20b4c47b81e14154f5d7f2e2c57842.
  - B's answer: repairs not landed. Worker h-sink3 (base 370ff65c) has C-ATT-33, 34, 35, 36, 37; notes will be orch-B/h-sink3/HARDENING_NOTES_3.md. C-ATT-38, 39, 40: no worker yet; C-ATT-38 is owner question B-19. Judges: worker h-judges2.
  - Started worker c25-provider on B's provider anchor at 74fb70eb (launcher priority 2): own fake provider; key scope, key expiry, key per retry, parameter mismatch, zero amount, freshness. Notes orch-B/h-provider2/PROVIDER_ANCHOR_2.md. Overlay fix-74fb70eb.
  - Running: c23 (gate), c25 (provider anchor).
- 16:53:20Z: c23 is alive and waits: A holds hol.lock, so orch-B/tools/dafny_locked.sh queues its single-file Dafny runs (B's r-jsbound waits too). No action; no heavy step by C while hol.lock is held. Running: c23 (waiting), c25.
- 16:56:31Z: c23 DONE. C's run: c23-jsgate/regress.sh exit 1 (checker ACCEPTS U01 and U02 in both forms). C's own bounded run of the two modules was STOPPED by the safety classifier: NOT RUN by C, not retried (C-1); the worker's run evidence stands (alarm exit 142). New: C-GATE-07, 08, 09, 10. Sent to B. Running: c25.
- 16:57:04Z: U598 written; pushed 5be5730a. Next id U599. Running: c25 (provider anchor).
- 17:03:32Z: c25 DONE; five cases re-run by C (C-ATT-41 to 44, C-NEG-17). Sent to B.
- 17:03:32Z: OWNER DECISION D-1 (launcher relay; end of OWNER_REQUIRED.md): persistent minter key from a file opened O_NOFOLLOW + fstat checks (regular file, uid == euid, mode & 0o077 == 0); no key from an environment variable; no test bypass; pinned key_id allowlist in the sink. B implements. WHEN B SENDS THE SHA, re-attack: symlink and rename races between open and use; hard links; file swap after the check; permission change after open; FIFO, device, directory; key_id substitution and retired ids; any leftover path that reads a key from the environment or argv. TEMPORARY TEST KEYS ONLY; never a real key.
- No worker runs now. Waiting on B: h-sink3, minter repairs, checker cost table, D-1 key file.
- 17:03:56Z: U599 written; pushed 8740dc03. Next id U600.
- 17:04:37Z: status sent to main. A's HOL job runs (hol.lock held): the Dafny queue is blocked, so the pending gate candidates (c23-jsgate subs U04-U11, K17: one run each with tools/vt.sh) stay NOT RUN. Started worker c26-read2: READING-ONLY audit of A's X8_statement_v3.txt, CONTROL_MATRIX_v2.md + launcher_v2.py, END_TO_END_GAPS.md. Running: c26.
- 17:07:46Z: B's f67c5c16 re-run by C: C-ATT-33, 34, 35, 36, 37 PASS (exit 0; outcomes read); C-ATT-19 nofloor still 1 (stated). Started c27-sink3 (variations). Running: c26 (reading audit), c27.
- 17:08:20Z: pushed 4c8767aa; status sent to main.
- OWNER DECISIONS D-2, D-3 (launcher relay; end of OWNER_REQUIRED.md). Re-attack plans, to run when B sends each SHA:
  - D-2 (a refusal closes only the attempt; only a minted token closes the request id): first re-run C-ATT-38 (c24-minter2/s11_nostore_spray.ts, s8_squat_search.ts close): must exit 0. Then try for two valid tokens or two effects for one request id: refusal/retry interleavings, concurrent attempts, restarts. Also keep f2_squat.ts zero (a zero-amount token on the real state still takes the id: B's stated limit) in view.
  - D-3 (provider key bound to (charge_id, request_id, amount); replay answers checked): re-run c25-provider s1_scope.ts collide and squat, s4_rebind.ts none with RP_REPLAY=first: must exit 0. Then vary: encoding collisions in the key derivation (separator inside an id; ids that contain the separator; Unicode forms), amount format variants (leading zeros, minor units, sign), key length limits.
  - D-1 (persistent minter key file): plan recorded above. Temporary test keys only.
- Running: c26 (reading audit of A), c27 (variations on B's sink 3 repairs).

## OWNER INSTRUCTION (17:12:04Z, launcher relay): STOP new red-team discovery. Finish only: (1) re-tests of B's D-1, D-2 (C-ATT-38), D-3 (C-ATT-41..44) commits as they arrive; (2) the final run of test_process_lifecycle.py on A's launcher_v2.py. Then write orch-C/FINAL.md (every finding: CLOSED with fix SHA and my re-run exit / OPEN-KNOWN-LIMIT / NOT RUN), push, message main "C done" with the final SHA, stop. Launcher's own check L-CHK-02: C-ATT-36 exit 0 on f67c5c16, exit 1 on f08a21c1.
- Workers stopped: c26 (reading audit of A: done; relayed to A as static, unverified by me), c27 (nothing run; reading leads relayed to B as unverified). No worker runs.
- Final launcher run: first attempt on launcher_v2.py gave exit 1 then exit 0 (unstable). Cause: MY test child ended before the launcher's image check, the launcher raised a refusal, my test counted it as an error. Test child now reads its input first (old file kept as test_process_lifecycle_before_stdin_fix.py). Re-run in the background (b4g5cu980): v2 five times, v1 twice; logs c22-launch-conformance/final2-*.log.
- Waiting on B: SHAs for D-1, D-2, D-3. Asked B to say if one will not land (then NOT RUN in FINAL.md).
- 17:12:18Z: FINAL launcher run recorded: launcher_v2.py exit 0 (5 of 5), launcher.py exit 1 (2 of 2). Drafting FINAL.md; D-1, D-2, D-3 rows wait for B's SHAs (B: all three in progress, none landed).
- 17:13:18Z: FINAL.md DRAFT written (orch-C/FINAL.md): all findings with status; rows D-1, D-2, D-3 are NOT RUN until B's commits arrive. To finish: re-test each of B's three commits (plans above), update section 1 and the rows C-ATT-05, 38, 41, 42, 44, push, message main 'C done' with the final SHA.
