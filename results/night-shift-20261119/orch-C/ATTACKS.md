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
