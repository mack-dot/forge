# Spec oracle: properties of a sink's durable behaviour (task h-specdiff)

Sources: `spec/refund/RefundSpec.dfy` (RS) and `spec/refund/protocol.md` (PR), with line numbers. No sink core
written on 2026-11-19 is a source. The approved text knows a "host" and an "integration". It does not know the
Slice 1 issuer or sink. The owner decided that the governing context is the approved policy plus the
AUTHORITATIVE PERSISTED CHARGE STATE. So the sink, which holds that state, is the host for the context.
Two unratified choices are used and named: OPEN-IS-UNSETTLED (a request is open exactly while its id is not
settled in the sink) and POST-RULE (an authorized refund decreases `remaining` by the amount, nothing else).

Setting: a store starts at the initial charge c0. Then the sink gets any sequence of deliveries.
"pre" is the charge state persisted immediately before a delivery. The request id of a delivery is the id that
the sink settles (the token's `body.requestId`). Context(pre, rid) = ChargeContext(pre.chargeId, rid,
pre.original, pre.remaining, pre.refundEnabled, rid not settled).

| Id | Property | Approved source | Responsible party |
|----|----------|-----------------|-------------------|
| P1 | Every outbox effect (charge id, request id, amount, reason) is the ONE intent of `Assess(Context(pre, rid), Candidate(amount, reason))`, which returns `Authorized(amount, reason)`. A commit releases exactly one effect. | RS 33-36 (Eligible); RS 48-58 (R3, R4, R5: `plan == [Intent(context.chargeId, context.requestId, ...)]`); PR 22-24; PR 68-70 ("dispatch only the checked plan, using its caller-bound IDs and exact amount/reason") | sink (host integration, PR 68-70). The issuer's Check is not named by the text. |
| P2 | At most one effect per (charge id, request id). | PR 61: "One attempt is active for a caller-bound (charge ID, request ID)." PR 63-65: "An identical repeated request returns its recorded decision without another executor call. Reusing the pair with different trusted context is rejected. A new attempt needs a new request ID." | sink (host: "durable payment idempotency", PR 89-90) |
| P3 | The persisted charge evolves only by POST-RULE. Every persisted charge has 0 <= remaining <= original <= MaxMoney. | Validity: RS 27-31 (ValidContext), PR 18. Evolution: SILENT (the approved spec has no stored state; POST-RULE is the unratified choice, also stated in impl/RefundFinality.dfy 6-10). | sink (host: "truthful charge/eligibility data", PR 89). Evolution rule: SILENT. |
| P4 | For each charge, the sum of effect amounts never exceeds its original amount. | DERIVED: R1 (RS 42-44) at each step plus POST-RULE. PR 89-92 gives the host "atomic reservation of the remaining balance" and says this boundary does not prove "a cumulative refund ledger". | sink (host, PR 89-90). A sum rule as such: SILENT. |
| P5 | NO EXTRA REJECTION: a delivery that is validly signed by the pinned key, carries the pinned ids, is fresh (rid not settled) and current (pre-state hash = hash of pre), and whose intent and post are exactly what Assess on Context(pre, rid) and POST-RULE give, is COMMITTED. Zero amount included. | PR 22-24: "Every such proposal must be accepted with that exact amount and reason. No extra heuristic may reject or modify it." PR 25-27 (zero is legitimate). PR 79: "Rejecting every proposal is a defect." RS 50-52 (R4). | The text binds the decision. Applying it to the sink's commit follows the owner's persisted-state decision. Signature, pins, freshness, currency, token text: Slice 1 constructs, SILENT. |
| P6 | A rejected (or replayed) delivery changes no durable state (state row, settled ids, outbox) and releases no effect. | PR 28-30: "Fallback ... authorizes no refund, changes no financial state, and does not call the refund executor." PR 63-64 (replay: no other executor call). PR 66-67 allow control bookkeeping; the oracle compares only state, settled and outbox. | sink |
| P7 | Every effect carries the persisted charge's id. | RS 53 ("its target is caller-bound"); RS 59-63 (`intent.chargeId == context.chargeId`); PR 15-17 ("The model cannot set or replace them"). | sink (host binds the charge, PR 13-17) |

## How the oracle decides (oracle.ts)
- The only decision procedure is the compiled approved `Refund.Assess` (impl/Refund.dfy refines RS). The oracle
  builds Context and Candidate with the module's own constructors and BigNumber. It calls no sink core.
- It replays the snapshots after each delivery. It checks P6 on non-commits, P1/P2/P4/P7 on each new outbox
  row, P3 on each changed state, and P5 on each non-commit that is not a driver-injected storage fault.
- P5 has a sub-class P5-SILENT: the token meets every P5 condition but is outside the encoding.ts domain
  (a text longer than 256 UTF-16 units, U+0000, a token text above 8,192 units, or non-canonical text). The
  approved text states no such limit for ids (PR 17 says only "IDs must be nonempty"; the 4,096-byte cap of
  PR 40 is on the model response, not on ids). These are QUESTIONS for the owner, not a verdict.
- A value outside the Dafny string domain (a lone surrogate) is not a Context or a Candidate. Its rejection is
  not a P5 case.

## Limits (honesty)
- This is a TEST against an executable form of the approved spec. It is not a proof. The compiled module rests
  on the Dafny-to-JavaScript compiler, its runtime and bignumber.js. The oracle and the driver are new,
  unproved code. Self-tests (selftest.ts) show that a known defect of each property is flagged.
- POST-RULE and OPEN-IS-UNSETTLED are unratified. A different ratified rule changes P1, P3, P5.
- P5 here requires the whole token to be consistent (intent = Assess plan, post = POST-RULE). The text does not
  say what a sink must do with a validly signed token that is authorized but carries another post: SILENT.
- "interleave" mode alternates two sink instances in ONE process. It is not a concurrency test.
