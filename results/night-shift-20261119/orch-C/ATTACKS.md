# Orchestrator C attack log and regression list (append only)

## C-ATT-01 (2026-11-19T14:32Z) proposer client: U+2028/U+2029 in a request id or charge id — CONFIRMED by C, KNOWN (unsure.md line 16105, review F5 LOW), STILL OPEN on target
- Class: malformed input; false rejection / liveness (no safety loss). Attacker: supplies an id text only.
- Target: 4af09308 + adoption-v6.diff; ts/refund-finality/proposer.ts:41-42 (node:readline splits at U+2028/2029; JSON.parse throws in the 'line' listener; the mint never resolves).
- Repro (cwd = target-v6; scrubbed env per WORKER_RULES): node --import tsx orch-C/c2-malformed/repro_proposer_u2028.ts <target-v6> <issuebytes2.cjs>
  SHA-256 958c02d9ec420ffdcb7dccbc5471cede352e3396ad96cd4974c5672ea1b9e879
- Expected: token delivered, sink commits. Actual (C's run): no answer, uncaught "Unterminated string in JSON"; EXIT 1. Control (`control` arg): EXIT 0. Logs: c2-malformed/recheck/f1.log, f1-control.log.
- Sent to B: 14:32Z. B regression: PENDING. Re-run against fix: NOT RUN.

## C-NEG-01 (14:32Z) malformed inputs, serializer, decoder, value conversion — NO counterexample (C re-ran: exit 0 each)
- c2-malformed/fuzz_mint_commit.ts 2000 cases seed 11: 204 issued = 204 committed (135 zero-amount), 0 defects; minter bytes == canon bytes; signedBytes injective on the cases. recheck/fuzz11.log.
- c2-malformed/variants.ts: 21 PASS 0 FAIL (Ed25519 S+L refused; 18 base64 variants refused; 12 non-canonical texts refused; zero-amount commits and dispatches; hostile ledger lines fail closed). recheck/variants.log.
- Worker runs only (not re-run by C): fuzz seeds 12 and 0, restart_boundary.ts 19/19.
- Note N4: ids that differ by NFC/NFD, case, trailing space are distinct refunds (spec: exact match). Not a defect.

Target for all entries below: 4af09308 + orch-B/p-adopt2/adoption-v6.diff ("v6"); "merged" = plain 4af09308. Exit 1 = defect present. All exit codes are from C's own re-runs (14:36Z-14:41Z); logs under <worker dir>/recheck/ or c3-identity/logs/ (worker logs kept in c3-identity/recheck/worker-logs/).

## C-ATT-02 (14:41Z) crash during the first open bricks the store — CONFIRMED, NEW, REGRESSION against merged
- Class: crash / partial commit; false rejection (permanent). Attacker: none (SIGKILL or power loss).
- v6 sink.ts:107: the DDL runs as four autocommit CREATE statements only when sqlite_schema is empty. A kill between statements leaves some tables; later opens never repair and refuse ("schema is not the sink's DDL" / "no such table: state").
- Repro: c1-concurrency/run.sh t2_ddl_crash.ts state -> EXIT 1. `kill 60` (real SIGKILL, random 0-12 ms): 9 of 60 files bricked, EXIT 1. SHA-256 t2_ddl_crash.ts 001fce20…9917.
- Expected: restart completes the schema (merged sink: CREATE TABLE IF NOT EXISTS at every open) or refuses only a foreign schema.
- Sent to B 14:42Z. Regression: PENDING. Re-run against fix: NOT RUN.

## C-ATT-03 (14:41Z) single-use minter rule + zero-amount refund freezes the charge — CONFIRMED, NEW (rule itself predates the diff; U428 does not record the lock-out)
- Class: zero value; false rejection. Attacker: none (honest use), or any minter caller without the key (a zero token that is minted and never committed also freezes), or a client crash between mint and commit.
- v6 minter.ts:94-97: rule keyed on the pre-state hash only. A zero-amount refund keeps the hash, so every later refund is refused: "another transition is already signed for this pre-state". Recovery needs a minter restart = new key = C-ATT-05.
- Repro: c1-concurrency/run.sh t1_zero_singleuse.ts on -> EXIT 1 (control `off` EXIT 0); t7_minter_concurrent.ts on -> EXIT 1; c3-identity/run.sh v6 z2_singleuse_zero_freeze.ts -> EXIT 1.
- Limit: only with single-use "on" (the D13 mitigation of D14). With "off" the freeze is absent and D14 is open (C-ATT-07). Both settings have a confirmed defect.
- Sent to B 14:42Z. Regression: PENDING. Re-run against fix: NOT RUN.

## C-ATT-04 (14:41Z) U+0000 appended to a stored request_id: start-up audit passes, the same zero-amount token commits twice — CONFIRMED, NEW mechanism (impact class of U565)
- Class: forged state / premise false for the real shell (A-DB1, A-DB2 of AuditV5SoundRelativeToSuppliedInitial; the settled flag of StepQ6). Attacker: database write without the key.
- v6 sink.ts:252 looks up settled ids in SQL (full value); the audit reads ids through node:sqlite, which cuts TEXT at U+0000 (:203-:219). COUNT(DISTINCT)=2 while node sees one id twice.
- Repro: node --import tsx c6-premises/p_adb2_nul.ts <target-v6> <work> -> EXIT 1. SHA-256 fa5ff030…726e. Money unchanged; the dispatcher's ledger deduplicated (1 effect).
- Sent to B 14:42Z and to A (premise). Regression: PENDING. Re-run against fix: NOT RUN.

## C-ATT-05 (14:41Z) minter restart = new key: no further refund on the charge — CONFIRMED, KNOWN as a B-10 duty; run shows a dead end; REGRESSION against merged
- Class: restart / key identity; false rejection. Attacker: none.
- minter.ts:76 makes a new key per process start; the sink pins ONE key and re-verifies every stored row with it. Old sink refuses new tokens; a sink with the new key refuses the legitimate store.
- Repro: c3-identity/run.sh v6 k1_key_rotation.ts -> EXIT 1.

## C-ATT-06 (14:41Z) the dispatcher does not evaluate the approved relation — CONFIRMED, WEAK (needs a faulty signer plus a database writer)
- Class: identity substitution at the effect point. dispatcher.ts:57-73 checks signature, pins, ids, intent text, chain; not amount == pre.remaining - post.remaining, not intent.chargeId. Rows with pre = post and amount 1000 keep the chain head: 3 x 1000 emitted on a 1000 charge, plus a ch_A refund from ch_B's ledger. The v6 sink refuses all of them, but the effects go out.
- Repro: c3-identity/run.sh v6 v1_dispatcher_trusts_signer.ts -> EXIT 1 (merged: worker run EXIT 1). The v6 claim "approval with no signing hypothesis" holds for sink commits, not for dispatched effects.

## C-ATT-07 (14:41Z) D14 on v6 with a writer WITHOUT the key — CONFIRMED, KNOWN (D14/U428); claim correction
- single-use off; two honest tokens for one pre-state; a database writer swaps the committed row for the uncommitted one; the dispatcher emits the other refund; the running sink re-audits and keeps serving. The v6 header (sink.ts:28-29) says such a writer "holds the signing key": a run contradicts that sentence.
- Repro: c3-identity/run.sh v6 d14_swap_uncommitted.ts -> EXIT 1.

## C-ATT-08 (14:41Z) request-id squat by a minter caller — CONFIRMED, KNOWN (owner question B-12(1))
- A zero-amount token for the victim's request id commits; the real refund for that id is refused for ever. Repro: c3-identity/run.sh v6 q_reqid_squat.ts -> EXIT 1.

## C-ATT-09 (14:41Z) one charge, two stores / two ledgers — CONFIRMED, KNOWN (B-8(c)); needs config control
- Repro: c3-identity/run.sh v6 c_config_identity.ts dup -> EXIT 1 (1200 refunded on a 1000 charge).

## C-CLOSED-01 (14:41Z) the two duplicate-effect exploits FAIL on v6 — C's independent repros
- E1 two effects for one request id: c3-identity/run.sh merged e1_two_effects_one_reqid.ts -> EXIT 1; v6 -> EXIT 0.
- E2 cross-charge double refund: merged e2_cross_charge.ts -> EXIT 1; v6 -> EXIT 0.
- 15-case substitution matrix: v6 m1_substitution_matrix.ts -> EXIT 0. Zero-amount honest flows: z1_zero_amount_honest.ts -> EXIT 0.
- Limit: closed at the SINK. C-ATT-06 shows the dispatcher is not covered.

## C-NEG-02 (14:41Z) concurrency — NO safety counterexample (C re-ran t3, t8: EXIT 0; worker runs only: t4 100 SIGKILLs, t5 ledger aliases, t6 dispatch while commit)
- 4 processes + 2 objects, 25 rounds: exactly one commit per round; replays answered "replayed". Availability note: dispatcher.ts:83 has no busy_timeout (about half the flushes throw "database is locked" in rollback-journal mode while a sink commits).
## C-NEG-03 (14:41Z) theorem premises — table in STATE.md; no undisclosed false premise on A's side (STATIC); p_b_premises.ts EXIT 0 (C's run).

Entries below: C's own re-runs 14:50Z; logs c4-rollback/recheck/; command form: node --import tsx c4-rollback/scripts/<S>.ts <work dir> [args], cwd = target-v6, scrubbed env. All scripts need c4-rollback/scripts/common.ts (SHA-256 e58e5e9c…1cc0).

## C-ATT-10 (14:50Z) index substitution: TWO committed effects for ONE request id (non-zero amounts); start-up audit and audit() pass — CONFIRMED, NEW
- Class: forged state / duplicate effect per request id at the sink. Attacker: database writer without the key and without config (writable_schema or a page edit), plus an ordinary host retry of r1 minted for the current state.
- v6 sink.ts:50-53: the schema check compares type, name, tbl_name, sql; not rootpage; no integrity_check. The prior lookup (:252), the UNIQUE checks (:259-260) and COUNT(DISTINCT) (:219) all read the substituted autoindex.
- Repro: a6_dup_reqid.ts <W> restart -> EXIT 1; `running` -> EXIT 1 (reaudits=1, re-audit passed). SHA-256 8779d206e8b48ed6250b1b276f9f9dffd6bf740461d189b487f822e2b6ce6c44.
- Expected: second r1 "already settled" (the control before the edit says so). Actual: committed; outbox holds 2 rows for r1; state 600; restart serves; audit()=[]. In the run the dispatcher refused all rows (paid 0): money not doubled there; the sink's uniqueness guarantee is broken.
- A row-log anchor that admits appends does not catch it: the sink itself appends the duplicate.
- Sent to B 14:51Z. Regression: PENDING. Re-run against fix: NOT RUN.

## C-ATT-11 (14:50Z) index root damage: audited store on which the dispatcher can never dispatch — CONFIRMED, NEW
- Same mechanism. a5_index_root.ts <W> -> EXIT 1. SHA-256 1d1c80ac…60c4. Sink starts, audit()=[], commits r3; flush refuses r1 ("no settled row") and all later rows. integrity_check would report it.

## C-ATT-12 (14:50Z) after a rollback the sink acknowledges refunds that the dispatcher never emits — CONFIRMED; consequence of the KNOWN rollback (U544, B-8(a)); the sink gives no signal
- a2_brick.ts <W> off -> EXIT 1. SHA-256 a49d07e0…279b. r1 600 emitted; rollback to genesis by a database writer; r2, r3, r4 "committed"; the dispatcher refuses all for ever ("token does not continue the dispatched chain"); re-audit passes.
- Packet section 6 sentence "a foreign change seen at commit HALTS the sink" is contradicted by this run and by C-ATT-10.

## C-ATT-13 (14:50Z) rollback + lost/new ledger = double external refund (1200 on 1000) — CONFIRMED, KNOWN (dispatcher header)
- a1_double_refund.ts <W> running newledger -> EXIT 1. Note: tests/refund-finality/suite.ts keeps the ledger in the database's directory.

## C-NEG-04 (14:50Z) rollback with an INTACT ledger: no second external refund — a1_double_refund.ts <W> running -> EXIT 0 (paid 600). The ledger is the de facto outside anchor; it has no freshness protection of its own.
## C-NEG-05 (14:50Z) a8_tamper_table.ts -> EXIT 0: state-only / settled-tail / outbox-tail rollback, reorder, BLOB-typed request_id or token, seq swap, unknown meta key: all refused. Zeroed sqlite_sequence, shifted seq, user_version, second state row, temp trigger, deleted meta: served with no effect on money.
## C-OBS-01 (14:50Z) a4_rawcounter.ts -> EXIT 1 (observation, low): a raw write that keeps the change-counter bytes is not seen by the writer guard (reaudits=0); exposure equals the known rollback window.
## Claims that a run contradicts (for B's wording): sink.ts:13 ("#distinct"), sink.ts:21-24 ("any other ... index ... is refused"), sink.ts:28-29 ("holds the signing key"), packet section 6 ("tampered store refuses to start; foreign change HALTS").

## C-ATT-01 RE-RUN (14:56Z) against B's fix de71cf4d (proposer.ts splits at 0x0A only) — PASS (closed)
- Overlay of de71cf4d (ts/, spec/refund, tests/refund-finality, impl) + v6 diff for ts/ and impl/: same command -> EXIT 0 ("answer":"ok", committed); control EXIT 0. Logs: orch-C/refix/c-att-01-de71cf4d*.log. B's permanent regression: tests/refund-finality/regress/c_att_01_line_separator.ts.
## B's regression runner on the v6 overlay (14:56Z, C's run): node --import tsx tests/refund-finality/regress/run.ts <sink.ts> <dispatcher.ts> -> EXIT 1: 13 PASS, 1 FAIL (X6-Z1 zero-amount row deleted and committed again; known U565). Log: orch-C/refix/regress-v6-de71cf4d.log.
- Note for B: X6-P1 prints PASS when the prefix rollback SUCCEEDS ("documented limit holds"). A PASS line for an unsafe outcome can mislead a reader of the exit code.

## CORRECTION of time stamps (written 14:40:39Z by `date -u`)
The times typed in the headings above (14:32Z, 14:41Z, 14:42Z, 14:50Z, 14:51Z, 14:56Z) were NOT read from a clock; they were my estimates and they are too late. All entries above this line were written between 14:19Z and 14:40:39Z (bounds from `date -u` and file times). The exit codes and commands are unaffected. From here on every time in this file is inserted by the shell.

Entries below: C's own re-runs at 14:40:39Z; logs c7-minter/recheck/. Command form: node --import tsx c7-minter/<S>.ts, cwd = target-v6, scrubbed env.

## C-ATT-14 (14:40:39Z) the checker identity does not bind the modules the minter loads — CONFIRMED, NEW; needs control of the minter's environment (NODE_PATH): config-level power, so WEAK as an attack, real as a claims gap
- encoding.ts:84-87 hashes the core module file, encoding.ts and minter.ts only; minter.ts:33 requires the core by path; bignumber.js and the resolution path are unbound. A benign shim bignumber.js first on NODE_PATH ran inside the minter process while the minter reported the pinned checkerSha256 61438653….
- Repro: p4_module_identity.ts -> EXIT 1. SHA-256 232cf39070e40346803282e8217c21b53b15ec81ea061ebb8c6d0434e2ab1602 (+ c7-minter/shadow/, raw.ts).
- Expected: the reported identity changes, or no foreign code runs. Reading: "checkerSha256 identifies the issuer" holds only under an unstated assumption: a closed, fixed launch environment and dependency tree.

## C-ATT-15 (14:40:39Z) the minter decodes stdin as lossy UTF-8 — CONFIRMED, NEW, MEDIUM (identity rewrite; no break of the signed-bytes property)
- minter.ts:126 Buffer.toString("utf8"): invalid bytes become U+FFFD and are signed. Request ids rq\xff and rq\xfe both give a token for "rq\uFFFD" (same body hash). Distinct wire requests collide to one signed id (impact class of C-ATT-08).
- Repro: p2_invalid_utf8.ts -> EXIT 1. SHA-256 9fc3c32bbb7d4be2c10f7e01458fdba02ff3f7e037af8ab0eb52e2553befa5fb. Expected: refusal of non-UTF-8 input. Attacker: writes raw bytes to the minter's stdin; no key.

## C-ATT-16 (14:40:39Z) MinterClient cross-delivery — CONFIRMED, NEW, WEAK (needs two callers on one client, one hostile)
- proposer.ts:23,51-52: a body key `id` overrides the client's counter; answers are matched by id only. Caller A receives caller B's token; B never gets an answer. The token is correctly signed; only delivery is wrong.
- Repro: p3_client_crossdelivery.ts -> EXIT 1. SHA-256 75bc1b5b399711f4ab3276640005ea3dc97a604692f8d39f01952b10d32524fe.

## C-NEG-06 (14:40:39Z) minter decision — NO counterexample: fuzz_diff.ts 2000 7 -> EXIT 0 (428 issued, 224 zero-amount, 208 full; 0 divergences from an independent oracle; raw 0x0A framing); p5_negatives.ts -> EXIT 0 (19 probes: duplicate keys, __proto__, number formats, booleans as strings). The hashed pre-state could not be split from the decided pre-state. p1_singleuse_zero.ts -> EXIT 1 = C-ATT-03 again.
- Worker note: it found a truncated p5_negatives.ts of unknown origin in its folder, discarded it and wrote its own. No other worker was assigned that folder; cause UNKNOWN (most likely the worker's own interrupted write).

## C-ATT-16 RE-RUN (14:42:34Z) against B's fix 216dfbe2 (proposer.ts writes its own id last) — PASS (closed)
- Overlay fix-216dfbe2 (git archive + v6 diff for ts/, impl/), C7_ROOT = overlay: p3_client_crossdelivery.ts -> EXIT 0 (A got its own token; B resolved). B's regression c_att_16_client_id_override.ts -> EXIT 0. C-ATT-01 on the same overlay -> EXIT 0 (still closed). Logs: orch-C/refix/c-att-16-216dfbe2.log, c-att-16-Bregress.log, c-att-01-216dfbe2.log.
## Open list at 14:42:34Z — with B's h-sink: C-ATT-02, 04, 06, 10, 11, 12. With h-minter: C-ATT-03, 15. Owner: C-ATT-05; C-ATT-14 (B's U572: assumptions CLOSED-LAUNCH, FIXED-DEPS; changing the id is an owner decision). Known/owner: C-ATT-07, 08, 09, 13.

## C-PREM-01 (14:44:14Z) A's X8/X11 draft argument (environment from one real run) — four STATIC findings (no run shows them); sent to A
- Not circular: the theorem quantifies over the environment; the run fixes only freedoms that are quantified away. HOLDS by reading.
- (4) NEW assumption A-F0-REAL: the model at EL0 also reads SCTLR_EL1.A (CheckAlignment) and PSTATE bits; the draft's fixed constant F0 must equal the real bits and they must stay constant over the run. X11 E14 names only E0E/EL/TBI/SA0.
- (5) interference-oracle indexing: off by the 27 entry instructions plus earlier FFI events as written; fixable.
- (11) "stdout = concat over reached write calls" is FALSE for killed runs: PIPE_BUF is 512 on this machine (getconf, C's run) and chunks go up to 2048; a SIGKILL inside a blocking write leaves bytes of a write that never returned. The TimeOut clause must say "prefix of fd1_written of an extension".
- (12) overclaim: the accept rule "strict parse => correct" needs an unstated fail-closed lemma for runs that violate an environment premise; the consumer cannot observe those premises after the fact.
- Proposed tests T4 and T2 cannot fail in the relevant direction (T4 compares memory, not pipe contents; T2's digest check is forced by r-x).
## C-NEG-07 (14:44:14Z) real refund executable under signals and truncated stdin — NO counterexample (C's re-runs, EXIT 0 each): c9-x8/sig_stop_cont.py (9 runs, stop/continue and four other signals while blocked in read or write: exact frame, rc 0), truncated_stdin.py (5 cut points: rc 0, empty stdout, no strict frame), threads_probe.py (one thread). Logs c9-x8/recheck/.

Entries below: target = B's judges at 1481d818 (tests/refund-finality/regress/, spec-conformance/). C's own re-runs at 14:49:11Z. Files: orch-C/c10-judges/ (mutants made by mutants/make_mutants.py; trees v6/ and enc/ are small extractions).

## C-JUDGE-01 (14:49:11Z) both judges pass 12 really defective mutants — CONFIRMED, NEW (judge blind spots)
- Repro: bash c10-judges/blindspots.sh -> EXIT 1 ("mutants passed by both judges: 12"). SHA-256 54afac42a735ad0a90a783bfab6887b143bf9ff9b31b5293d633a6c235eda2e2. Log c10-judges/recheck/blindspots.log.
- The 12: sink accepts a token signed by a foreign key; accepts non-canonical token text; skips the pre-state check; answers "rejected" to an identical retry; answers "replayed" to a different token for a settled id; commits anything for ids longer than 32 or non-ASCII; commits anything after 20 honest commits; wipes the store at open; dispatcher ignores the signature; dispatcher ignores the chain; dispatcher emits before the ledger line; a shared encoding.ts whose signed bytes omit post and intent.
- Defects shown real by C's runs of c10-judges/confirm.sh (mutant EXIT 1, plain v6 EXIT 0) for: bad_sig, wipe, d_ignore_sig, late20. The other 8 confirm cases: worker runs only.
- Causes: no case reaches restart, a bad signature, non-canonical text, ids of 33-256 units or non-ASCII, more than 10 deliveries per store; the oracle's committed branch does not check signature, pins or canonical text; "replayed" and "rejected" are treated alike; the spec judge loads no dispatcher; the oracle shares encoding.ts with the sink under test.
- m_wipe_on_open gets regress EXIT 0: an amnesia sink scores BETTER than v6 (EXIT 1).

## C-JUDGE-02 (14:49:11Z) X6-P1 FAILS a SAFER sink — CONFIRMED, NEW (false rejection by the judge)
- s_rollback_guard.ts (refuses to start when the settled count is below an outside high-water mark): regress EXIT 1, "FAIL X6-P1 ... differs from the documented limit (refused without an anchor)". A sink that resists the rollback is failed for it.

## C-JUDGE-03 (14:49:11Z) judge integrity and exit codes — CONFIRMED, NEW
- i_exit_early.ts (reject-all + process.exit(0)): regress prints 5 FAIL lines, 9 regressions never run, EXIT 0. No count check.
- i_forge_output.ts (reject-all + patched output): regress 14 PASS, EXIT 0.
- spec-conformance/run.ts exits 0 with violations (merged sink: worker run). The v6 baseline already fails X6-Z1, so regress exit 1 cannot show a NEW failure on v6.
- Threat reading: the sink under test runs inside the judge process. For a trusted sink this is about exit-code hygiene (early exit, missing count check), not about a hostile sink.

## C-NEG-08 (14:49:11Z) no false alarm and no v6 counterexample from B's oracle (worker runs: seeds 1-3, fault and interleave modes, 200 each: only P5-SILENT). 17 mutants are caught by at least one judge (reject-all, reject-zero, reject-full, reject-second, no outbox, outbox twice, and others).

Entries below: C's own re-runs at 14:52:11Z. Dispatcher command form: c8-dispatcher/run.sh <script> <work dir> <mode> (cwd = target-v6, scrubbed env). Logs c8-dispatcher/recheck/.

## C-ATT-17 (14:52:11Z) the dispatcher lock has no owner: one documented operator step gives two effects for one request id and a total above the original — CONFIRMED, NEW, HIGH
- Class: concurrency / retry at the effect point. Attacker: NONE. An honest operator follows the header's recovery step ("a person removes the lock file") for a run that is slow, not dead; a second honest run follows. No key, no database write, no config.
- dispatcher.ts:79 `finally { closeSync(lock); unlinkSync(lockPath); }` removes whatever lock file is at the path; the ledger (:82) and the outbox rows (:86) are read once per run.
- Repro (deterministic: a blocking emit waits for a control file): l1_lock_theft.ts <W> two -> EXIT 1 (effects A:r1 B:r2 A:r2; 1200 of 1000). `three` -> EXIT 1: ONE operator step; run A's finally deletes run B's lock; run C starts with no operator step; effects A:r1 B:r2 C:r3 B:r3; 1200 of 1000. `control` -> EXIT 0. SHA-256 l1_lock_theft.ts a99305a8eb1a2d6dcffa7a937001ed13e4d7b20c545344d0e9e7d4aa1e8c3167, dchild.ts 1be296a2…1a79.
- Expected: at most one effect per request id. Detection only afterwards: later runs stop with "ledger is not one chain".
- Sent to B 14:52:11Z. Regression: PENDING. Re-run against fix: NOT RUN.

## C-ATT-18 (14:52:11Z) a throwing emit loses the effect silently — CONFIRMED, NEW (claims gap, medium)
- The ledger line is written, emit throws before sending, the finally removes the lock; the retry counts the request in alreadyDispatched with refused=[]. A ledger line for a lost effect is identical to one for a sent effect. The header covers only "a process that dies". l2_silent_loss.ts <W> throw -> EXIT 1; ok -> EXIT 0. SHA-256 ce92836b…3716.

## C-ATT-19 (14:52:11Z) an OLDER ledger (restored backup) repeats emits: 1400 on 1000 — CONFIRMED; KNOWN class (C-ATT-13, B-8(a)); the header names only a MISSING ledger
- l3_ledger_restore.ts <W> ledger -> EXIT 1; none -> EXIT 0. Attacker: none (an operator restores a backup). Worker run only: mode `dir` EXIT 1.

## C-ATT-20 (14:52:11Z) a BLOB-typed outbox request_id hides a committed refund from the dispatcher — CONFIRMED, NEW, LOW (database writer without the key)
- dispatcher.ts:87 filters the row out before any check: not emitted, not refused, counted in alreadyDispatched. l7_rowtype.ts <W> blob -> EXIT 1; nul -> EXIT 0. SHA-256 cd8d60a6…3806.

## C-NEG-09 (14:52:11Z) dispatcher, honest histories — NO counterexample: 1554 histories of length 1-4 (zero and non-zero refunds, held tokens, dispatch at any point, restart): 0 bad (worker runs, 16 chunks EXIT 0); shared ledger for two charges: liveness cost only (l6: EXIT 0, C's run); U+0000 in outbox ids: deduplicated or refused (l7 nul: EXIT 0, C's run).

Entries below: target = B's gate rule 3 (orch-B/e-subset3/subset_rule3.py, diff/refund-subset3-combined-scope.diff). Logs c5-gate/recheck/.

## C-GATE-01 (14:52:11Z) rule 3: NO admitted submission that halts, throws or answers wrongly was found (worker: about 35 candidates; 13 refused; the admitted ones are blocked by Dafny or harmless, some by ARGUMENT only)
- C's run: python3.10 -I c5-gate/tools/task3.py -> EXIT 0: all seven known unsafe refused; halting 24 of 24 refused; hostile rows 20 of 177 admitted = B's record; correct 46 admitted, 21 refused; drift 0.

## C-GATE-02 (14:52:11Z) rule 3 recognizer is quadratic and unbounded in time inside the gate process — CONFIRMED, NEW (availability; attacker: the submitter)
- subset_rule3.py body_open (lines 302-306) with subset3_close per `{`. Nested braces in a ghost clause: C's run of regress.sh check D1: 18.6 s, verdict "pass W=209 T=6" (ADMITTED). Worker: 20,000 levels 104.9 s. Expected: a fast bounded refusal.

## C-GATE-03 (14:52:11Z) wiring: the rule checks bytes read BEFORE the input snapshot — CONFIRMED by static check only (regress.sh D2); the end-to-end swap is NOT RUN; WEAK (needs a second process that writes the submission file during the gate run)
- Gate copy with the combined-scope diff: read at line 1055, rule at 1073, re-read by identity() at 1081, snapshot at 1193; only the end state is compared with the snapshot.

## C-GATE-04 (14:52:11Z) rule 3 FALSE REJECTIONS of natural correct work: 5 of 10 new submissions refused — CONFIRMED (C's recognizer runs on G01, G02, G03, G08, G09; worker's Dafny verify exit 0 for all five: not re-run by C)
- G01 SUBSET3_TYPE (helper with a seq parameter); G02 SUBSET3_NAME (let-expression in a helper); G03 SUBSET3_GUARD_BRACE (`reason in {..}` in a guard); G08 SUBSET3_NAME (a local declared once in each of two branches); G09 SUBSET3_PRODUCT (amount times a named constant). G08 and G09 are classes not in B's reviewer list.
- With B's 21 of 67: the rule refuses about a third to a half of correct work. Not a reject-all gate; a high false-rejection rate.
- Regression for C-GATE-02/03: bash c5-gate/regress.sh [RULE_PY] [GATE_PY] -> EXIT 1 now. 04be9739902cf93f9958e0e2e0433c121c4f844dfc91353f13117f4d2f0b49fe  regress.sh

## RE-RUN (15:06:02Z) against B's commit 608b5165 (hardened sink b7fd6be8 + minter with the per-(charge id, request id) rule) — C's own runs
Overlay <SCRATCH>/redteam-C/fix-608b5165 (tree as committed); scripts = copies pointed at it (<SCRATCH>/redteam-C/retarget-608b5165; issuer module orch-B/h-minter/build/issueonce.cjs). Logs: orch-C/refix/608b5165/.
| Item | Command (script) | Exit | Verdict |
|---|---|---|---|
| C-ATT-03 zero-amount freeze | c1 t1_zero_singleuse.ts on; t7_minter_concurrent.ts on; c3 z2_singleuse_zero_freeze.ts; c7 p1_singleuse_zero.ts | 0, 0, 0, 0 | PASS (closed for these cases) |
| C-ATT-15 lossy UTF-8 | c7 p2_invalid_utf8.ts | 0 ("message is not UTF-8" for all three) | PASS (closed) |
| Minter decision (no false rejection) | c7 fuzz_diff.ts 2000 7; p5_negatives.ts | 0 (428 issued, 224 zero-amount, 0 divergences); 0 | PASS |
| C-ATT-02 first-open crash | c1 t2_ddl_crash.ts kill 60 | 0 (0 partial files in 60 kills) | PASS (no brick seen). Mode `state` exits 1 but is NOT VALID here: it builds a partial file of the OLD schema; the new DDL is one transaction |
| Concurrency | c1 t3_parallel_commit.ts 25 | 0 | PASS |
| C-ATT-14 module identity | c7 p4_module_identity.ts | 0 | NOT A PASS: the shim ran in the minter process again ("attackerCodeRan": true); the script's pin compare is not valid on this tree. OPEN as B's named assumption |
| C-ATT-05 key per start | c3 k1_key_rotation.ts | 1 | STILL PRESENT (owner item) |
| Substitution matrix | c3 m1_substitution_matrix.ts | 0 | PASS |
| C-ATT-04, 06, 07, 10, 11, 12, 20; E1, E2, zero-amount honest flows with the dispatcher | old scripts | throw | NOT VALID as they are: a new ledger needs cfg.newLedgerH0; raw hostile writes abort at triggers. Being ported and re-attacked by worker c16-hsink (attacker drops triggers, recomputes the unkeyed chain; with and without expectedHead) |
- Workers started: c16-hsink (hardened sink and dispatcher), c17-hminter (new minter rule: stale-token retry of the same request id, D14 in mode on, start-up guards).

Entries below: C's own re-runs at 15:06:02Z. Host-layer command form: bash c11-host/<script> [mode] (scrubbed env inside; target-v6 + the 216dfbe2 client). Logs c11-host/recheck/.

## C-HOST-01 (15:06:02Z) dispatch_cli exits 0 on every error path and hides refusals — CONFIRMED, NEW. Attacker: none
- tests/refund-finality/dispatch_cli.ts:16: the catch prints {"stopped":...} and sets no exit code; the success line prints only emitted.length (refused[] and alreadyDispatched dropped).
- h1_dispatch_exit.sh emitfail -> EXIT 1 (the effect write fails; ledger line kept; run 1 "stopped" rc 0; retry {"emitted":0} rc 0; effects file empty: the C-ATT-18 loss through the real CLI); lock -> EXIT 1; refused -> EXIT 1 (every committed row refused, CLI prints {"emitted":0} rc 0). Worker run only: chain. SHA-256 76e015b9…aed6.
## C-HOST-02 (15:06:02Z) SIGTERM during dispatch_cli leaves the lock; every later run exits 0 "stopped" — CONFIRMED. h2_signal_lock.sh TERM -> EXIT 1. The only documented recovery is the step that enables C-ATT-17.
## C-HOST-03 (15:06:02Z) lock removed during a slow run: effects sent, CLI prints "stopped" (ENOENT in unlink) rc 0, retry prints {"emitted":0} — CONFIRMED, NEW (reporting side of C-ATT-17). h5_lock_removed_report.sh -> EXIT 1. SHA-256 68af64be…55b7.
## C-HOST-04 (15:06:02Z) commit_cli exits 0 on a refusal; a mistyped database path creates a new empty store — CONFIRMED, LOW. h6_commit_exit.sh -> EXIT 1.
## C-HOST-05 (15:06:02Z) relative ledger path + another working directory: 2000 refunded on 1000, both runs rc 0 — CONFIRMED; known class (lost ledger), new host-level trigger; attacker: none. h7_relative_ledger.sh -> EXIT 1.
## C-HOST-06 (15:06:02Z) sink_tool init takes the anchor (initialState) from its argument when the config has none — CONFIRMED, WEAK. h3_tool_anchor.sh -> EXIT 1.
## C-HOST-07 (15:06:02Z) EPIPE after the effect: CLI exits 1 although the effect happened; retry cannot tell "sent" from "nothing to do" — CONFIRMED, LOW. h9_epipe.sh -> EXIT 1.
## C-NEG-10 (15:06:02Z) host layer (worker runs): the CLI flow commits and dispatches zero-amount and full refunds; no refund above the original; the demo gauntlet fails closed (it gives no v6 evidence); exit_slice1.py: no silent skip found (read only).

Entries below: target = native refund executable b8ed5ec2… and the consumer proposals/m1b-mission-20261119/drafts/fail-closed/{frame.py, m1_fail_closed.py}. Command form: /usr/bin/python3 -B -I c14-parser/<script>. Logs c14-parser/recheck2/.

## C-PREM-02 (15:06:02Z) "Python strict parser = HOL strict parser" is false as an identity — CONFIRMED by run (safe direction only), NEW as a precise statement
- frame.py:259 refuses negative integers; HOL refund_strict_parse accepts any rendered frame, incl. negative amounts and counts. diff_parsers.py 1 200000 -> EXIT 0 (0 frames that Python accepts and HOL refuses; 0 field differences); with --identity -> EXIT 1 (HOL-only frames exist; worker: all have a negative amount or count).
- A proof of the edge must state "HOL parser restricted to non-negative integers". No false rejection follows: the program prints non-negative values only.
## C-NEG-11 (15:06:02Z) native executable versus an independent oracle and the Python consumer — NO counterexample: C's runs: fuzz_oracle.py 1 2000 -> EXIT 0 (2000 real runs, 273 authorized incl. 76 zero-amount and 27 full, 0 mismatches, all frames strict); edges.py -> EXIT 0; probe_table.py -> EXIT 0. Worker runs: 9,400+ real runs in total, never a byte after a frame.
- Observation (known class): every request-reader error gives exit 0, empty stdout, empty stderr; the consumer maps it to REFUSED (fail closed). A trailing line feed after the request gives "no frame".

Entries below: C's own re-runs at 15:12:56Z; target-v6 (4af09308 + v6 diff). Command form: bash c15-storage/run.sh <script> <args>. Logs c15-storage/recheck/.

## C-ATT-21 (15:12:56Z) a planted hot journal rewrites the audited store; the attacker never writes the database file — CONFIRMED, NEW (weaker attacker than a database writer)
- Class: rollback / forged state below the SQL layer. Attacker: can create ONE file `<db>-journal` in the database directory and could read the database at an earlier time. SQLite inside the sink process applies it at the first lock, before the start-up audit.
- s1_hotjournal.ts restart -> EXIT 1 (acknowledged r2, r3 gone; audit passes; audit()=[]); running -> EXIT 1 (the running sink re-audits, passes, keeps serving; acknowledged r3 lost); nul -> EXIT 1 (the journal carries the C-ATT-04 page edit; the same zero-amount token commits twice). s2_planted.ts wal -> EXIT 1 (a planted -wal next to a rollback-mode database is applied; r3 commits twice); jinwal -> EXIT 1. Worker run only: mode uv.
- SHA-256 s1_hotjournal.ts ed863e5b20443c1f7b4bd1ca123a4ed37c58182f1a33285373766b4d1885d552; journal.ts 5b8c8b25…d511.
- Reading: sink.ts:25-29 lists its undetectable cases for a "database writer"; create-only access to the directory is enough. Triggers and CHECKs cannot stop a page-level journal. Sticky-directory case (second user): NOT RUN.
- Sent to B 15:12:56Z. Regression: PENDING. Re-run against fix: NOT RUN (also NOT RUN against 608b5165: next).

## C-ATT-22 (15:12:56Z) a short ledger write is not checked: the effect is sent with a torn ledger line — CONFIRMED, NEW. Attacker: none (disk full / file-size limit)
- dispatcher.ts:98-102 ignores writeSync's count, then fsync, then emit. s3_ledger_short.ts 200 -> EXIT 1 (all 6 effects emitted with torn lines; every later run throws; the obvious repair, dropping the bad line, re-sends: worker measured 1620 on 1000); control 351 -> EXIT 0. SHA-256 4e789420…2b8c.
- Worker run only (real ENOSPC on a 2 MB disk image, no sudo; image removed; C checked: no image attached): write returned 322 of 351 bytes with no error, the 300 refund was emitted, the next flush throws for ever.
- Contradicts the header sentence "a line is appended and synced BEFORE the effect".

## C-ATT-23 (15:12:56Z) two honest sinks through two hard-link names of one database lose acknowledged commits after one crash — CONFIRMED (known SQLite hazard; not stated in the sink's assumptions)
- s6b_killloop.ts hardlink 100 7 3000 -> EXIT 1; control `same` -> EXIT 0. Worker: 4 of 100 and 2 of 100 lost. Symbolic links are safe (s6_twonames.ts: worker runs EXIT 0).

## C-OBS-02 (15:12:56Z) durability (STATIC + measured by the worker): the sink sets no fullfsync; on macOS an acknowledged commit is durable to the drive cache only. Node's fsyncSync timing matches F_FULLFSYNC, so the ledger line is MORE durable than the sink row: a power loss can put the sink below the ledger head (C-ATT-12 class). No power cut was run.
## C-NEG-12 (15:12:56Z) storage: s5_paths.ts -> EXIT 0 (C's run): lock as a dangling symlink or a directory, ledger symlinked or replaced during a run: fail closed (denial of service only). Worker runs: junk journal ignored; commit under a file-size limit: 21 acknowledged and present, 36 rejected with no row.

## C-BLOCK-01 (15:12:56Z) worker c18-launch (native launch path) STOPPED EARLY: a safety classifier withheld part of its response; it ran NO test and wrote no file. Its table is STATIC (reading of proposals/m1b-mission-20261119/drafts/fail-closed/m1_fail_closed.py): child environment is a fixed dict (:23, :123): caller's DYLD_* do not reach the child (by reading); cwd is a private mkdtemp (:110); mkdtemp takes TMPDIR from the caller (:110; impact NOT RUN); stdout to a private file with a size limit, read after exit (:120-:134); hash of the copy before and after the run, exec by path (:114, :130). I do not retry the withheld work in another form. Reduced scope by C itself: control checks only (no injected code).

## C-BLOCK-01 addendum (15:13:51Z): my own attempt at control checks of the draft launcher was ALSO stopped by the safety classifier before any file was written or any command ran (orch-C/c18-launch/ is empty). Launcher priority 4 (native launch path: loader injection, truncated stdout, FFI abort) is therefore NOT DONE by C: no run, no result. I do not retry it in any form. What exists is the STATIC table of C-BLOCK-01 only (reading, by a worker; not re-checked by a run). A's own launch-path controls (orch-A/launch/, not ready) stay un-attacked by C unless the owner decides how this class of test may be run.

=========================================================================
RE-ATTACK OF B's HARDENED SINK + MINTER (608b5165). C's own re-runs at 15:39:19Z.
Overlay <SCRATCH>/redteam-C/fix-608b5165 (committed tree). Minter module orch-B/h-minter/build/issueonce.cjs.
Attacker for the sink cases = a database WRITER WITHOUT THE KEY (drops the 14 triggers, edits, recomputes the unkeyed chain, re-creates the identical trigger text). "head anchor" = cfg.expectedHead = sink.head() before the tamper; the dispatcher ledger stays intact. Scripts: c16-hsink/ (hport.ts c1cd776d…, hbound.ts c91d23c0…, hledger.ts d7ef1d70…), c17-hminter/ (f1,f2,f5,f9).

## CLOSED on 608b5165 (C's re-runs; exit 0 = the attack fails):
- C-ATT-10 index substitution (hport a6-equivalent) and C-ATT-11: closed by integrity_check (now run at start and before every dispatcher flush). C-ATT-04 U+0000 and the new x'7aff' invalid-UTF-8 variant: closed (typeof + hex read; integrity_check re-checks CHECKs). C-ATT-06 faulty signer at the dispatcher (hv1.ts faulty): exit 0 (the dispatcher now runs AuditStep and refuses all). C-ATT-20 BLOB id: closed (refusal visible). C-ATT-12 rollback: the running sink HALTS, the restart dispatcher ALARMS; with the head anchor it is refused.
- Honest flows on the hardened tree: port/fuzz_mint_commit.ts 2000 11 -> EXIT 0: 204 legitimate commits, 135 of them zero-amount, 0 defects. Zero-amount refunds still commit. C-ATT-03 and C-ATT-15 closed (C's earlier re-run on 608b5165).
- The old C-ATT scripts that abort at triggers are superseded by these ported cases (a trigger abort IS a defence against a writer that keeps the schema; a file writer drops the triggers, which is what these scripts do).

## C-ATT-24 (15:39:19Z) the hardened running sink accepts a change to an OLD row and commits a second effect for one request id; it does NOT halt — CONFIRMED, NEW, MEDIUM
- Attacker: database writer without the key, plus an honest retry of r1. sink.ts:138-142 foreignCheck and core/store.ts:314-323: headRowSame re-hashes ONLY the head row; auditFrom audits only rows after the saved count. A rename of an OLD row (r1 -> r1x in token and intent) is not seen while the sink runs.
- Repro: c16-hsink/rr.sh o1 hport.ts work/o oldrow running none -> EXIT 1 (reaudits=1; the retry of r1 commits; outbox = r1x,z,r2,r1). Restart control (oldrow restart): EXIT 0 (restart refuses "token_sha256 is not the token's hash"). cfg.expectedHead does not help: it is checked at start only.
- Money: the dispatcher refuses every row (paid 600), so no money is lost here; the SINK's one-effect-per-id guarantee and HARDENING_NOTES section 4 ("Anything else HALTS") are broken. Keeps the C-ATT-12 class open for this variant.
- Sent to B 15:39:19Z. Regression: PENDING.

## C-ATT-25 (15:39:19Z) D14 beats BOTH anchors on the hardened tree: an uncommitted refund is dispatched and a committed one is never sent — CONFIRMED; KNOWN class (D14/U428/C-ATT-07); B states it (dispatcher.ts:26-29)
- Attacker: database writer without the key. The minter's new per-(charge id, request id) rule signs two tokens for one pre-state (different request ids), so the swap token exists in mode on too.
- Repro: rr.sh d14h hport.ts work/d d14 restart head -> EXIT 1. The sink with expectedHead refuses to start and a running sink halts, but the dispatcher (DispatcherConfig has no expectedHead; dispatcher.ts:38, :133) still sends r2b 300; r2 100 is acknowledged and never sent. The dispatcher has no row anchor past its ledger.

## C-ATT-26 (15:39:19Z) FALSE REJECTION, regression against v6: a legitimate refund whose intent text exceeds 2048 characters is refused — CONFIRMED, NEW
- core/store.ts:56 outbox intent CHECK and :132: encoding.ts allows ids of up to 256 UTF-16 units with control characters; JSON escapes U+0001 to six characters, so a legal id pair overflows 2048.
- Repro: rr.sh hb hbound.ts work/hb -> EXIT 1 (2 of 12 cases: chargeId 200xU+0001 + requestId 200xU+0001 -> "rejected: transaction failed: h-sink S1/S2/S4"; the statement rolls back truthfully). v6 control: runv6.sh hbound.ts ... ctrl-both-200 -> EXIT 0 (v6 commits and dispatches). The other 10 boundary cases (MaxMoney=2^63-1, astral 256-unit ids, zero at remaining 0, amount=remaining) commit.
- Sent to B 15:39:19Z. A fix must not refuse a legal token.

## C-ATT-27 (15:39:19Z) the head anchor protects only rows up to its count; a STALE anchor lets the zero-row deletion through — CONFIRMED, claims gap (config)
- rr.sh z1s hport.ts work/zs z1del restart stale -> EXIT 1 (also genesis anchor count 0). Nothing in the sink refreshes the anchor; the host must save sink.head() after every commit, atomically with it. "extends, not equals" protects only rows up to anchor.count.

## C-ATT-28 (15:39:19Z) a host cannot tell a first run from a lost ledger; newLedgerH0 left set re-emits — CONFIRMED; KNOWN class (C-ATT-13)
- rr.sh lp hledger.ts work/l lost-policy -> EXIT 1 (1200 of 1000); lost-strict -> EXIT 0 (alarm). The first run with committed rows always needs newLedgerH0 (dispatcher.ts:130); a host that sets it on an empty ledger, or leaves it set, pays twice.

## MINTER (c17), new per-(charge id, request id) rule at 608b5165 (C's direct re-runs; command: node --import tsx c17-hminter/<f>.ts <work> <mode>):
## C-ATT-29 (15:39:19Z) FALSE REJECTION by honest concurrency (deliberate per SINGLE_USE.md section 4, but real and attacker-free) — CONFIRMED
- f1_stale_retry.ts stale -> EXIT 1: R1,R2 minted on S0; R2 commits; the sink refuses R1 as stale; the host re-proposes the SAME id R1 on the new state -> the minter REFUSES ("another candidate is already signed for this request id"). The honest refund R1 is frozen for the process life. Variant amount (a corrected amount on the same id) -> EXIT 1. Recovery needs a new request id from the host, or a minter restart = a new key (C-ATT-05). SHA-256 f1 7f9ff6ff…531e.
## C-ATT-30 (15:39:19Z) request-id squat at the MINTER with NO commit and NO sink state change — CONFIRMED, NEW (worse than C-ATT-08)
- f2_squat.ts fake -> EXIT 1: a caller without the key, knowing only (charge id, request id), mints a zero-amount token for an INVENTED pre-state (never commits); the victim's real request on the real state is then minter-refused for ever. zero mode -> EXIT 1. SHA-256 f2 07f0a29f…aff4.
## C-ATT-31 (15:39:19Z) foreign code in the key-holding minter via the tsx transform cache, pinned checkerSha256 unchanged — CONFIRMED, NEW door of the C-ATT-14 class; TMPDIR defeats the NODE_OPTIONS-only guard
- f9_tsx_cache.ts -> EXIT 1 twice (deterministic): start with TMPDIR=<dir>; tsx writes the compiled minter.ts to <tmpdir>/tsx-<euid>/<time>-<key>; prepend one statement; the second start RUNS it ("foreign code ran in pid ...") while ready reports the pinned checkerSha256 e9616ea7…. minter.ts refuses NODE_OPTIONS but not TMPDIR, so the NODE_OPTIONS refusal gives false closure (B's CLOSED-LAUNCH assumption, U572). Worker's stronger no-env variant (argued): the default cache dir os.tmpdir()/tsx-<uid> is user-writable and keyed by public inputs, so any same-uid process can plant the entry with no environment control. SHA-256 f9 967a6ac4…a260.
## C-ATT-32 (15:39:19Z) D14 reopened at the minter in mode on (same as C-ATT-25 mechanism; the fix for C-ATT-03 allows two tokens per pre-state) — CONFIRMED, KNOWN class
- f5_d14_on.ts on -> EXIT 1 (off -> EXIT 1): stopped only by cfg.expectedHead plus the external anchor. SHA-256 f5 123b49b6…9384.
## C-NEG-13 (15:39:19Z) minter, SAFE (C's re-runs exit 0): f3_replay_growth.ts replay (Replayed is byte-identical, also after 1000 other mints; a replay with another pre-state is refused); f6_key_framing.ts (16 probes: ("a","b|c") vs ("a|b","c") are distinct keys; strict UTF-8 refuses overlong, CESU-8, lone bytes, 1 MiB line; the stream stays in sync). Static: IssueOnce.dfy cone has no assume/axiom/extern/bodiless member; build digests match.
## C-NEG-14 (15:39:19Z) hardened sink, SAFE (worker runs; C re-ran the fuzz): hsql.ts 26 plain-SQL writes with triggers intact: 0 gaps (REPLACE/UPSERT/OR IGNORE/seq update/rowid update/DELETE refused; forged amounts '1e3',' 5','+5','05','0x10',2^63,20-digit,-1,5.0 refused). writable_schema and ignore_check_constraints caught by integrity_check. Upgrade: an honest v6 store is refused (C-ATT; in B's notes section 6).

## NOTE (15:46:52Z): my hand re-run of the OLD dispatcher scripts against B's new dispatcher (f08a21c1) threw ERR_MODULE_NOT_FOUND (the API changed: claim rule, owned lock, witness file). Those "exit 1" results are harness errors, NOT attack verdicts, and are DISCARDED. Worker c19-dispatch2 ports them to the new API and re-attacks; worker c20-launch-read does a READING-ONLY audit of A's launcher controls (the run-based launch attack stays blocked, C-BLOCK-01).

## C-READ-01 (15:51:25Z) static reading audit of A's launcher controls (orch-A/launch/launcher.py) — by worker c20; NOT re-checked by C (the safety classifier stops my own reading of the launcher too; see C-BLOCK-01). STATIC, NOT RUN. Relayed to A as the worker's analysis only.
- The worker reports (file:line are the worker's; I did not verify them): child environment is env={} with argv=[copy], cwd a private 0700 dir -> DYLD_* cannot inject into the CHILD (the only barrier; the binary is ad-hoc/linker-signed with no __RESTRICT, so dyld would honour DYLD_* without it). Pin: one O_NOFOLLOW open, hash in memory, same bytes written to the copy (no path re-read; stronger than the draft m1_fail_closed.py which re-reads by path). Accept rule D0-D12 logic complete (D11 implies D7-D10; NOT_AUTHORIZED needs the exact rejection bytes).
- Worker findings where A's CLOSED is judged too strong (STATIC): F1 the launcher does not reset its own SIGCHLD; if a caller sets SIGCHLD=SIG_IGN, Python's subprocess invents returncode 0 (ECHILD), so D2/D3 do nothing and a killed-after-full-frame or SIGABRT run could reach AUTHORIZED (caller-environment power; safety then rests on X8 C5 alone). F2 csops/CDHash binds the image of the pid at the check instant, not the exec'd image: a swapped image could keep the pipes in a descendant and execve the genuine file (same-uid writer into the 0700 dir; A's scope excludes that writer). F3 the request write has no deadline (availability). F4 is about the DRAFT launcher, not launcher.py.
- Words-only premises (no code enforces them): A-KERNEL-PRESERVE, A-FFI-EFFECT-AT-CALLS, A-F0-REAL, no-debugger, single-thread; CORRECTIONS_v2 already admits them. X8 v2 D11 still says the launcher is not implemented, so its ENFORCED rows are TESTED-UNPROVED, not proved.
- UNKNOWN by reading: whether xnu keeps SIGCHLD=SIG_IGN across the python shim's execve (settles F1); whether the F2 re-exec can beat csops; whether orig-rebuild/basis_ffi.c is the source of the pinned binary.
- C's status: I cannot independently confirm ANY of this; the classifier blocks my reading of the launcher. These are a single worker's static notes for A to check itself.

Entries below: target = B's gate rule 3 (orch-B/e-subset3/subset_rule3.py). C's own re-runs at 15:56:19Z. Logs c13-gate-js/recheck/.

## C-GATE-05 (15:56:19Z) rule 3 ADMITS a bodiless `lemma ... ensures false` (an axiom) when its last spec clause ends in a set display — CONFIRMED, NEW (rule defect; the gate is still safe by Dafny's warning default and the audit: defense in depth)
- Class: gate bypass at the recognizer. Attacker: the submitter only.
- subset_rule3.py Subset3Module.__init__ checks only the LAST token of a declaration (`texts[hi - 1] != '}'`). A bodiless lemma / ghost predicate / ghost method whose last clause ends in `{...}` (e.g. `ensures 1 in {1}`) is taken to have a body.
- Repro (C's run, pure Python): python3.10 -I orch-B/e-subset3/subset_rule3.py c13-gate-js/subs/A01-bodiless-lemma-brace-end.dfy -> "pass W=241 T=6" (ADMITTED). The file has `lemma Dead() ensures false ensures 1 in {1}` and calls Dead() to reach `Authorized(response.amount + 1000, "free_money")` (an amount above the request and an unapproved reason). A02 (bodiless ghost predicate): also "pass". bash c13-gate-js/regress.sh -> EXIT 1 (7 files admitted). 858711766d613a1219c2c5bfd6ced4d072784ebf0a174c60df91bb9b855d6356  subs/A01-bodiless-lemma- 41e592806742b9865fa39e30e90a2a780d7eb634f164907ed18a055b41965725  regress.sh 
- Why the gate is still safe (worker's Dafny runs, NOT re-run by C): verify exit 2 — the log says "6 verified, 0 errors" (the verifier ACCEPTED the axiom) and only "warnings were found and --allow-warnings is false" stops it; translate exit 3; audit --compare-report exit 2.
- Impact: defense in depth only TODAY. It is a critical soundness bypass if --allow-warnings or --allow-axioms ever enters the gate's Dafny options, or if the audit step is removed. The rule claims to refuse bodiless ghost members (it refuses B's A07 which has no `}`) but does not.
- Sent to B 15:56:19Z. Regression: PENDING.

## C-GATE-06 (15:56:19Z) rule 3 false rejection: `const Cap := 1_000_000` (digit separators) is refused (SUBSET3_LITERAL) though Dafny verifies it — worker run; natural money-literal style; by B's design (Y36) but the cost to correct work is unrecorded. Also G12 typed set<string> const (known, B F03).

## C-NEG-15 (15:56:19Z) gate, verified source vs compiled JavaScript — NO admitted submission halts or answers wrongly (worker: 23 single-file Dafny runs, none refused by the lock script; NOT re-run by C)
- Lone CR in a verbatim string: verifier and compiler both read it as LF (same scanner); answers the open question at unsure line 18267. 29-predicate probe: verify exit 0, Node 0 differences. Covers astral chars, U+2028/2029, 2^53±1, 10^19-1, Euclidean / and %, set cardinality with run-time duplicates, comparison chains.
- Input conversion exact (9007199254740993, MaxMoney, 2^53+1). Match flattening linear (scrutinee evaluated once). Worst admitted arithmetic 0.74 s / 10 MB. Name mangling injective. The rule refuses assume, {:axiom}, {:verify false}, {:only}, {:fuel}, {:extern}, opaque/reveal, decreases *; the gate refuses print and expect and treats a timeout as Rejected.

## RE-TEST BY C ITSELF (16:12:50Z) of B's newest dispatcher at 88ae6cbf70c5 (branch nightshift/B-trust) — C-ATT-17 and C-ATT-18
Overlay <SCRATCH>/redteam-C/fix-88ae6cbf (committed tree). Issuer module orch-B/h-minter/build/issueonce.cjs. Command form (cwd = overlay, scrubbed env): node --no-warnings --import tsx tests/refund-finality/regress/<test>.ts <overlay> <issueonce.cjs>. Logs orch-C/refix/88ae6cbf/B-*.log. These are B's regression files; each reproduces my attack scenario faithfully (I read d_att17_lock_theft.ts: it is my l1 "three" mode: A blocks in emit(r1), a person removes the lock, r2 and r3 commit, B blocks in emit(r2), A ends, C starts with NO operator step, B resumes). I ran them and inspected the recorded effects.
| Item | Command (test) | Exit | Recorded outcome | Verdict |
|---|---|---|---|---|
| C-ATT-17 lock has no owner | d_att17_lock_theft.ts | 0 | A emitted r1; run C STOPPED ("dispatcher lock is held ... pid ... alive"); B emitted r2, r3, refused r1. Effects A:r1 B:r2 B:r3; no duplicate; total 900 <= 1000 | PASS (closed) |
| C-ATT-17 claim race | d_att17_claim_race.ts | 0 | PASS line | PASS |
| C-ATT-18 lost emit | d_att18_throwing_emit.ts | 0 | run1 threw (nothing sent); run2 refused r1, already=0 (NOT counted as dispatched); run3 refused r1 | PASS (closed: the loss is now visible as refused/in-doubt) |
| positive controls | d_positive_controls.ts | 0 | PASS | honest flows work |
- Limit of this re-test: I ran B's regression files (which encode my scenarios) and inspected effects; an independent re-attack with fresh scripts (lock-owner race under SIGSTOP, non-atomic release window, APPEND-ATOMIC) is with worker c21-sink2. C-ATT-17 and C-ATT-18 are CLOSED for the tested scenarios on 88ae6cbf.
