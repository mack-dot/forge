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
