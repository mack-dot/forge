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
