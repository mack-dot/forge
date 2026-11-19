# Provider anchor 3: corrected assumptions after C-ATT-41..44 (h-provider3, 2026-11-19, target 5d99be9d)

Status: TESTED-UNPROVED with a FAKE provider only. No real provider contacted. Nothing here is proved. Owner decision
D-3 (OWNER_REQUIRED.md) sets the order of the layers and the key fields.

## 1. Layers (decided order)
- Layer 1, THE rollback anchor: dispatcher cfg.ledgerFloor + sink cfg.outsideHead/onHead + dispatcher cfg.expectedHead,
  kept off the restored medium and fresh (ANCHOR-OUTSIDE, ANCHOR-FRESH, LEDGER-FLOOR-OUTSIDE, LEDGER-FLOOR-FRESH; see
  PROVIDER_ANCHOR_2.md section 3). It alone stops restores and rebinds that the provider key cannot see.
- Layer 2, the provider key: a SECOND layer only. It removes a second money movement for the SAME effect
  (store, charge, request id, amount) only inside the provider's key window (PROVIDER-KEY-WINDOW).

## 2. Assumptions the design still NEEDS (layer 2)
- PROVIDER-KEY-WINDOW(W): the provider remembers a key for at least W after its first use. Outside W the key gives nothing.
- PROVIDER-IDEMPOTENT-KEY: inside W, the same key gives no second movement (it replays, refuses, or answers in progress).
- PROVIDER-ANSWER-FIELDS (NEW): every success answer, the replayed one included, returns the refund id, the charge id and
  the amount of the refund that the key holds (reason and key if it returns them are compared too). Without charge id and
  amount the adapter cannot check; it then raises an ALARM (never "paid").
- PROVIDER-ACCOUNT-SCOPE: keys are scoped at most per provider account (wider is fine).
- PROVIDER-KEY-TEXT: the provider accepts a 64-character [0-9a-f] key.
- PROVIDER-DURABLE, PROVIDER-CEILING (optional third bound: per charge total <= captured amount), CURRENCY-IMPLICIT.
- PROVIDER-ANSWER-HONEST: the answer describes the refund that the provider holds for the key (see section 6).
## 3. Assumptions NO LONGER needed (the adapter checks them itself)
- PROVIDER-PARAM-BINDING: no longer assumed. Moved to "checked by the adapter for the fields the provider returns"
  (charge id, amount; reason and key when present). A replay-first provider (C-ATT-41, 42, 44) is handled.
- ADAPTER-KEY = request id and "request ids unique per account": gone. The key binds store, charge and amount.

## 4. Key derivation (emit_adapter.ts providerKey; exact bytes)
key = lower-case hex( SHA-256( F(ns) || F(chargeId) || F(requestId) || F(amount) ) ), 64 ASCII characters.
F(x) = 4-byte unsigned big-endian length of UTF-8(x), then UTF-8(x). ns = "forge-refund-provider-key/v1/" + storeH0.
storeH0 = the store's registered genesis h_0 (meta.genesis; core/store.ts genesisOf), a configured constant of the
deployment (AdapterOptions.storeH0; 64 lower-case hex, else the adapter refuses to start). A text with a lone surrogate is
refused (no lossy UTF-8). amount = the canonical decimal text of the committed intent. The intent has NO currency: none in
the key. Legitimate retry (adapter retry, or resolveInDoubt "retry"): the same effect gives the same key.
Cost of the amount in the key (D-3; measured): the same request id with another amount (only after a rollback or rebind)
is a NEW key. Layer 2 then gives nothing; layer 1 or the ceiling must stop it (section 7).

## 5. Answer classes (every answer; no other class; the call is built from the committed outbox row)
| provider answer | adapter class | journal outcome | emit |
|---|---|---|---|
| new result, charge+amount (+reason, key) equal | PAID | paid | returns |
| replayed result, fields equal | PAID BEFORE | replayed | returns |
| any result with other or missing fields | ALARM | alarm:answer-mismatch (both sides) | throws: in doubt |
| param_mismatch (key held with other parameters) | ALARM | alarm:param_mismatch | throws: in doubt |
| timeout, unavailable, in_progress | retry same key/call; after the last: IN DOUBT | unknown:<code>, in-doubt:<code> | throws |
| other code, non-provider exception | IN DOUBT | in-doubt:unknown-code / in-doubt:exception | throws |
| refused, ceiling, zero_amount, unknown_charge, invalid_request | REFUSED before movement | refused:<code> | throws |
| amount "0" | no call | zero-recorded | returns |
A throw makes the dispatcher write "failed" and keep the row IN DOUBT until a person calls resolveInDoubt.

## 6. What stays unprotected
- A restore older than W without layer 1 (C-ATT-43): pays again. Stated, measured (section 7).
- The same request id with another amount after a rollback, without layer 1 (cost of D-3): pays again.
- A provider that lies in its answer (returns the call's own fields for another refund): not detectable by the adapter.
- A refusal that a provider stores under the key: a resolveInDoubt "retry" with the same key may get the stored refusal
  again (liveness). NOT TESTED; real behaviour unknown.
- Another party that knows h_0 and sends our key first (C-ATT-44 derived): ALARM, the refund stays in doubt (liveness).

## 7. Evidence (TESTED-UNPROVED, fake provider; exit codes from logs/)
- p3 (logs/p3b, run_p3.sh; v3 = new adapter, v1 = frozen old adapter = control): scope_collide first/error 0/0 (v1 1/1);
  key_squat literal first/error 0/0 (v1 1/0), derived 0/0 (ALARM, in doubt); keytext long/nonascii 0/0 (v1 1/1);
  in_progress 0 (v1 1); rollback_rebind none first/error 1/1 (T2: r1 paid 600 and 100; booking true), full 0/0;
  v1 none 1/1. Measurement without the amount (P_KEY=noamount): rollback_rebind none 0/0.
- Red team copies (logs/rt, run_rt.sh; before = 5d99be9d, after = this tree): s1 collide first 1->0, squat 1->0,
  s4 first ceil1 none 1->0, s5 prefix (truncating client) 1->0, C-ATT-43 ret24 none 1->1 (stated), full 0->0.
- Matrix (logs/matrix3, 200 cells) vs h-provider2 matrix1: 2 cells changed. p_full_param_rebind none a: 0 -> 1
  (cost of D-3; with P_KEY=noamount: 0, logs/noamount). p_full_param_rebind none b: 0, layer key -> ceiling.
