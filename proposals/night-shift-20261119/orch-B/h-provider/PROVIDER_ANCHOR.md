# Provider anchor: the payment provider as the outside anchor against rollback (h-provider, 2026-11-19)

Status: TESTED-UNPROVED with a FAKE provider on the e65f9ec8 dispatcher. Nothing here is proved. No real provider
was contacted. Every property of a real provider below is an ASSUMPTION until the check in section 4 has run.

## 1. Assumptions (exact)
- PROVIDER-IDEMPOTENT-KEY: for a refund call with key K that the provider still remembers, and the same parameters
  as the first call with K, the provider moves no money and returns the first result.
- PROVIDER-PARAM-BINDING: for a call with a remembered key K and other parameters (charge id, amount, reason or
  currency), the provider refuses and moves no money.
- PROVIDER-KEY-RETENTION(W): the provider remembers K for at least W after its first use, and no longer is assumed.
  After W, a call with K is a NEW refund.
- PROVIDER-CEILING: the sum of refunds that moved money on one charge never exceeds the captured amount of the
  charge, whatever keys are used. The check and the movement are atomic at the provider.
- PROVIDER-DURABLE: the provider's key records and movements survive its own faults (a timeout or crash after the
  money moved still leaves the key record).
- ADAPTER-KEY = request id (emit_adapter.ts keyOf). Request ids must be unique per provider account; a reuse on
  another charge is refused by PARAM-BINDING (liveness loss, not money loss).
- CURRENCY-IMPLICIT: the intent has no currency field; the adapter sends none; the charge's currency applies.
- ZERO-LOCAL: a zero-amount refund makes NO provider call; the adapter records "zero-recorded" and succeeds.

## 2. What each assumption eliminates, and what it does not (TESTED-UNPROVED, logs/SUMMARY.txt)
| attack (regression) | a: KEY | b: KEY+CEILING | c: none (control) | d-a: KEY, expired | d-b: KEY+CEILING, expired |
|---|---|---|---|---|---|
| ledger-only restore, C-ATT-19 (p_ledger_restore) | 0 | 0 | 1 (1400) | 1 (1400) | 1 (r3 twice, total 1000) |
| database+ledger restore, same tokens (p_db_restore_retry) | 0 | 0 | 1 | 1 | 1 (r3 twice, total 1000) |
| database restore, NEW ids on the stale balance (p_db_restore_new_ids) | 1 (1500) | 0 | 1 | 1 | 0 |
| second ledger, C-HOST-05 (p_second_ledger) | 0 | 0 | 1 | 1 | 0 |
| timeout after money, retry now and retry later (p_timeout_retry) | 0 | 0 | 1 (1600) | 1 (r2 twice) | 0 |
| same id, other amount after restore (p_param_rebind) | 0 | 0 | 1 | 1 | 0 |
| crash before money, refusal (p_provider_faults; not an attack) | 0 | 0 | 0 | 0 | 0 |
| zero amounts z1 0, z2 0, r1 100 (p_zero_amount; positive control) | 0 | 0 | 0 | 0 | 0 |
Exit 0 = SAFE (no key moved money twice and total <= charge); 1 = DEFECT.
- KEY + PARAM-BINDING eliminate a SECOND MONEY MOVEMENT for a request id that the provider still remembers: re-emit
  after a ledger restore, after a database restore, from a second ledger, and a retry after a timeout.
- KEY does NOT stop the overpay route (p_db_restore_new_ids, mode a: 1500 on 1000). A restored older database holds
  a stale balance (remaining 600 where 100 is true). The sink commits, and the issuer signs, NEW request ids against
  it. No key repeats. Only CEILING stops it (mode b: provider refuses r4; 900 moved). The ceiling bounds money by
  the CHARGE, not by the true remaining balance of the local policy (a policy that allows less than the charge is not
  protected), and not per request id.
- After the retention window (d-a, d-b) a re-emit is a new refund. CEILING then bounds the total by the charge but
  does NOT stop a duplicate that still fits: r3 (100) moved twice in d-b (total 1000 of 1000). The task text
  expected "still stopped in mode (b)": that is FALSE for r3; it holds only for re-emits that exceed the ceiling.
- Nothing here protects the LOCAL RECORD. A restored store still starts (limit X6-P1), shows a wrong balance, and
  shows r4 as refunded although the provider refused it (p_db_restore_new_ids mode b: local remaining 0, 900 moved).
- Record truth: the dispatcher writes its ledger line BEFORE emit. A ledger line means "attempt started", not "paid".
  The adapter journal (own file) holds paid | replayed | zero-recorded | refused:<code> | unknown:<code>. After a
  refusal the next dispatcher run SKIPS that row (ledger_restore d-b: r2 refused, r3 sent next run): a person must
  reconcile from the journal. Without KEY, the reconcile step itself can double-pay (p_timeout_retry, mode c).
- Second-ledger finding (independent of the provider): h1 stops a plain new empty ledger, but a config that keeps
  cfg.newLedgerH0 = h_0 accepts any new empty ledger and re-emits every committed row (p_second_ledger).

## 3. Interface notes (dispatcher.ts at e65f9ec8)
- emit is synchronous and gets (effect {requestId, intent text}, intent). The adapter takes the key from
  intent.requestId and refuses if the three disagree. If h-dispatch adds an explicit key parameter, only keyOf
  changes. An asynchronous real provider client needs an asynchronous emit: a contract change (MISSING here).
- No test was impossible. Retry-after-timeout through the dispatcher alone is impossible by design (line before
  effect), so the delayed retry is a person's reconcile call of the adapter with the outbox row.

## 4. How to check each assumption against a real provider (NOT RUN; no outside service was contacted)
- Documentation: the idempotency section of the refund API (header name, scope of a key: account or endpoint,
  retention period, what counts as "same parameters", the answer to a reused key with other parameters, behaviour
  while the first call is still in flight); the refund rules (is the per-charge refund total capped at the captured
  amount; partial refunds; currency; is a zero amount refused).
- Sandbox plan (test-mode credentials of the owner only; never production): T1 same key, same body twice: one
  refund object, second answer identical. T2 same key, other amount: refused, no refund. T3 two keys whose sum
  exceeds the charge: second refused. T4 drop the connection after sending (client timeout), retry with the key: one
  refund. T5 reuse a key after the documented retention: record what happens (expect a new refund). T6 amount 0.
  T7 concurrent identical calls with one key. Record every response verbatim with time stamps.
- Pass criteria: T1, T2, T3, T4 as stated; T5 gives W for PROVIDER-KEY-RETENTION. Any other result voids the
  matching assumption.

## 5. Combination with the signed-checkpoint design (h-anchor ANCHOR_DESIGN.md, owner item B-14)
- With such a provider: CEILING bounds money per charge; KEY removes duplicates inside W. Use the checkpoint or
  monotonic counter for the local record (refuse to start a store older than the anchor), and for restores later
  than W. A reconcile step must compare the adapter journal and the provider's refund list.
- Without such a provider (no KEY or no CEILING): the checkpoint/counter outside the database is the only defence
  against all rows of the table above. Then the double money movement is bounded only by the anchor's freshness.
- Do not claim rollback resistance from this document. It gives: no second money movement per key inside W, and
  total refunds per charge <= the charge, both under the named assumptions, both TESTED with a fake only.
