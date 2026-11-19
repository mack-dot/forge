# Rollback and forged initial databases: the external anchor (h-anchor, 2026-11-19)

A database cannot authenticate its own history. Every input of an in-database counter or chain can be
recomputed by a database writer. A MAC with an outside key detects an edit, but not a return to an earlier
MAC'd snapshot. Only a record OUTSIDE the database that never goes back (an anchor) detects a rollback.
**Without an external anchor, Forge claims NO rollback resistance and NO forged-initial-database resistance.**

## (a) Threat model
| Adversary | Can do | Status |
|---|---|---|
| (i) token deliverer, no database access | replay, reorder, withhold tokens | Handled by the sink step (signature, fresh request id, matching pre-state). |
| (ii) database writer WITHOUT the signing key: buggy or old code, an operator, a restore from backup | replace the database file with any earlier snapshot; delete, swap or insert rows; set any initial charge; re-run the sink on it | THIS DESIGN. Proved facts tonight: a rewound store passes every audit and the dropped token commits again (AttackRestart.dfy); middle zero-amount deletion and swapped zero rows pass a true audit (AttackV5.dfy); the audit's initial charge is an unauthenticated input. |
| (iii) database writer WITH the issuer signing key | sign any transition | OUT OF SCOPE. No mechanism here helps. |
| (iv) the host that runs the sink | everything in (ii), plus read or change the sink process | In scope only for the database file. The sink process and its memory are trusted. If the same host also runs the dispatcher and holds its ledger, (iv) can roll back the anchor too: then ANCHOR-MONOTONE fails and nothing is claimed. |

## (b) The row-log head
`head = (n, h_n)`. With canonical JSON (an injective text, assumption ENC-INJ) and SHA-256:
- `h_0 = H(canon({domain:"forge-refund-sink-v1/genesis", initialState, specLockSha256, checkerSha256, issuerKeySha256}))`
- `h_{i+1} = H(canon({domain:"forge-refund-sink-v1/link", prev:h_i, token:<committed token text of row i+1>, intent:<its outbox intent text>}))`

The head commits to: the initial charge, the pinned ids, the issuer key, every committed row (zero amount
included), its position and the order. The genesis and link inputs are domain-separated. The forged-initial
answer: the initial charge is authenticated ONLY by being inside h_0, and h_0 must itself be anchored
(registered with the anchor before the first commit, by a party other than a database writer).
Model: Anchor.dfy, T1_Binding (equal head, NC => same config, initial charge, rows, order).

## (c) Anchor options
**Option 1 — the issuer as witness (token carries the expected head).** The issuer puts the head it expects
(the sink's head before this row) in each token; the sink commits only if its current head equals it.
Detects: after a rollback, the NEXT honest token does not match, so the rolled-back sink stalls.
Does NOT detect: a replay of a dropped token. Its expected head IS the rolled-back head, so it commits again.
What remains: the issuer must know the latest head (it becomes the anchor: it must store it, monotone, and
never re-issue for an old head); the dispatcher or payment side must key idempotency by (charge id,
request id). Cost: a token-format change (owner decision), and the issuer becomes stateful.

**Option 2 — a separate append-only witness** (second disk or host, hardware monotonic counter plus hash,
transparency log). Commit path: (1) commit the row locally (head n+1); (2) `publishHead(chargeId, expected
=(n,h_n), next=(n+1,h_{n+1}))`, a compare-and-swap; (3) only then mark the outbox row dispatchable. Start:
read `latestHead`; require the stored log to EXTEND it (rows 1..L.n chain to L.h); rows after L.n are the
unpublished tail: publish them (step 2) before any dispatch. Freshness: the witness is monotone and the
sink never releases an effect whose head is not published. A count-only monotone counter is NOT enough:
a rolled-back store that out-runs the count passes it (Anchor.dfy C3_CountOnlyAcceptsFork; mutant M4).

**Option 3 — the dispatcher's ledger as the anchor.** Downstream acts only with idempotency keyed by
(charge id, request id). Protects money: a rollback can re-emit, not re-pay. Does not protect the sink's
own state or audit trail.

**What the merged dispatcher pins today** (ts/refund-finality/dispatcher.ts; main = nightshift/B-trust for
this folder): a ledger file outside the database, synced before the effect, one run at a time by a lock
file; a chain of CHARGE STATE hashes from the pinned `initialStateSha256`; a set of dispatched request
ids. It does not pin the row log. A zero-amount refund leaves the state unchanged, so the state chain
cannot see zero rows or their order.

**Measured (one Node run, logs node/probe_run1.log, exit 0; sink store rolled back by a file copy,
dispatcher ledger untouched; honest test issuer):**
- A. Rollback after dispatch, re-commit the dropped token: sink `committed`, sink audit `[]`; dispatcher
  `alreadyDispatched 1`, no second effect.
- A2. Rollback, then a NEW token r2 from the rolled-back pre-state (same amount as r1): sink commits, audit
  `[]`; dispatcher refuses r2 ("does not continue the dispatched chain") but does NOT stop; the next token
  r3 (pre-state = post of r2 = post of r1, because the state has no history) IS dispatched. Sink history
  {r2, r3}; dispatched {r1, r3}. r2 is settled in the sink and never paid. (Minter single-use mode "on"
  would refuse to mint r2; the mode is an open owner decision, U428.)
- B. Rollback before dispatch: one effect. C. Forged initial charge (1000) with tokens signed from it: sink
  commits, audit `[]`; dispatcher refuses (pinned initial state hash). D. Zero row deleted: sink audit
  `[]`; dispatcher sends nothing new and does not notice. E. Control: dispatcher ledger deleted: r1 sent
  TWICE (a missing ledger is read as empty).

Conclusion: against a SINK rollback, money safety (no second effect per request id; effects on one signed
state chain from the pinned initial state) already holds in these cases, TESTED-UNPROVED, under
ANCHOR-MONOTONE for the dispatcher ledger, an authentic pinned initial state, and a secret issuer key.
Rollback DETECTION does not hold: the sink and its audit never notice; the dispatcher refuses row by row
and goes on; zero rows can vanish; the sink's record can claim a refund that was never paid.

**Recommendation (one minimal architecture): the dispatcher's ledger becomes the row-log witness.**
1. The sink stores (n, h_n) in `meta` and updates it in the commit transaction.
2. The dispatcher pins h_0 instead of (or beside) `initialStateSha256`; each ledger line adds `n` and `h_n`.
3. The dispatcher sends row n+1 only if the sink's rows 1..n chain to its recorded h_n and the request id
   is not done. A mismatch is not a per-row refusal: it STOPS the run and raises "sink is not an extension
   of the dispatched history" (fail closed until a person reconciles).
4. At start, the sink reads the dispatcher's latest (n, h_n) read-only and refuses to commit unless its log
   extends it. Dispatch is the publication: no separate publish step is needed for money safety.
5. A missing or shorter ledger is an error, not an empty ledger (register h_0 explicitly).
6. Keep the ledger on a different host or medium than the sink database (else adversary (iv) wins).
Model: T3_DispatchTrace, T4_StaleRefused, T4_HonestAccepted, T4_HonestDrain; controls C1, C2, M3.

## (d) Freshness and failure modes
- Witness unavailable: fail closed. No dispatch; the sink may commit (rows wait in the unpublished tail).
- Crash between local commit and publish: at start the tail rows after L.n are published, in order, by CAS.
  If CAS fails because the witness moved, the store is a fork: stop and reconcile.
- Committed rows lost before publish (a rollback inside the tail): undetectable and harmless for money (no
  effect left the system); a re-delivered token commits once. The issuer saw a signature it cannot tell
  apart from a lost one.
- The witness is rolled back too: OUT OF MODEL. Assumption ANCHOR-MONOTONE. Probe E shows the result.
- Key rotation: the issuer key is inside h_0. A new key starts a new segment: register a link row
  "key change" signed by the old key, or close the charge and register a new h_0 (owner decision).
- Multiple sink processes: one database holds one charge; the witness CAS serializes publishes; two sinks
  on two copies of one database form a fork: the second CAS fails. Two dispatchers: the lock file covers
  one host only.

## (e) Exact claims
- MACHINE-CHECKED (model only, Anchor.dfy): with an anchor whose record is never reset (ANCHOR-MONOTONE)
  and NC on the hash inputs of the trace (and ENC-INJ, modelled by a datatype): a store whose head equals
  the anchored head IS the true history, initial charge, zero rows and order included (T1, T2); a rollback
  to a prefix or a row deletion is detected at start with no hash hypothesis (count); a reorder or a forged
  initial charge is detected under NC; over ANY sequence of presented stores the dispatched effects form
  one chain from h_0 and each request id is dispatched at most once (T3); a stale sink's divergent rows are
  refused and its replays cause no effect; an honest sink is never refused (T4).
- NOT claimed: anything about the TypeScript code (the model is not bound to it); anything WITHOUT an
  external anchor; anything if the anchor's record is rolled back, if the issuer key leaks, or if the same
  host can rewrite both the sink database and the anchor.

## D4. What the owner must decide
1. Which anchor option: (2) separate witness, (3)+recommendation (dispatcher ledger as the row-log witness),
   or (1) issuer as witness. Recommended: the dispatcher ledger, extended as above.
2. Where the anchor lives and who operates it: a host or medium that a sink-database writer and the sink
   host cannot rewrite (and how it is backed up WITHOUT allowing a restore to an older head).
3. Whether the token format carries the expected head (option 1; a token-format change; the issuer becomes
   stateful).
4. What freshness means operationally: how old the anchored head may be before the dispatcher stops (time,
   or number of unpublished rows), and whether the sink may commit while the anchor is unreachable.
5. Who registers h_0 (the authentic initial charge) and from which source of truth.
6. Key rotation rule (new segment with a signed link, or a new charge registration).
7. Whether minter single-use mode is on (U428): with it on, case A2 cannot be minted.
