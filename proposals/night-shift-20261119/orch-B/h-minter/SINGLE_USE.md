# The issuer's single-use rule: what it is for, and the rule that replaces it (h-minter, G1)

## 1. The old rule
- `minter.ts:86-89` (branch head de71cf4d): with argument `on`, the issuer keeps `pre-state hash -> body hash` in
  process memory and refuses "another transition is already signed for this pre-state". Default in the suite: `off`.
- Origin: U428 (Pillar II v2). Case D14: if the issuer signs two requests for one pre-state, a database writer can
  make the dispatcher send the one the sink did NOT commit. The rule removed the second claim (D13). U428 says: unproved,
  lost at restart, "owner decision whether the single-use rule is wanted". Slice 1 REPORT.md:294-297 and open
  decision 4 (REPORT.md:340) keep it an open owner decision.

## 2. What the approved text says
- spec/refund/protocol.md is SILENT on a per-pre-state rule.
- It is NOT silent on per-request attempts (protocol.md:61-65): "One attempt is active for a caller-bound (charge ID,
  request ID). ... An identical repeated request returns its recorded decision without another executor call.
  Reusing the pair with different trusted context is rejected. A new attempt needs a new request ID."
- protocol.md:25: "Zero is a legitimate authorization". The old rule breaks it in practice (C-ATT-03).

## 3. What the old rule stops that the sink does not
- The sink commits at most one token per request id, and only on its current stored pre-state. Two tokens for one
  pre-state can never BOTH commit, except two zero-amount tokens (the state does not change), which are both legitimate.
- The only extra thing the old rule stopped is D14: a SECOND SIGNED, UNCOMMITTED token exists, so a database writer
  without the key can swap it in for the committed one. That is a storage-integrity attack. The hardened sink (append-
  only, chained row log) and the external anchor (h-anchor) detect it: the row-log head changes. It is a sink/anchor
  matter. This work does NOT close D14 (red-team d14_swap_uncommitted.ts still exits 1 on my tree: section 6).
- Cost of the old rule: one zero-amount token, or one abandoned token, freezes the charge for the life of the
  process (C-ATT-03; t1_zero_singleuse.ts and z2_singleuse_zero_freeze.ts exit 1). Any caller can do it without the key.

## 4. The property wanted, and the rule chosen
- P-idem: the issuer never signs two DIFFERENT transitions for the same (charge id, request id).
- P-retry: the same request again returns the SAME token (byte-identical), so a crashed client can retry.
- P-live: a request with a new request id is never refused because of earlier tokens (no freeze).
- Rule (IssueOnce.Issue, impl/finality-core/IssueOnce.dfy): key = (pre.chargeId, request.requestId).
  core refuses -> refuse; key new -> issue and store the bytes; key holds the same bytes -> return them (replay);
  key holds other bytes -> refuse ("another candidate is already signed for this request id"). A different request id
  on the same pre-state is ALLOWED. The sink decides which token commits.
- "Same candidate" means the same signed body bytes: same pre-state hash, post, intent, spec lock and checker id.
  So a retry of rq_x against a NEWER pre-state is a different candidate and is refused. The client needs a new request
  id (protocol.md:65: "A new attempt needs a new request ID"). This is a deliberate, conservative choice.

## 5. What this gives up
- Two signed tokens for one pre-state can exist (different request ids). Only one can commit, unless both are
  zero-amount with distinct request ids: then both commit, and both are legitimate.
- D14 is no longer reduced by the issuer. It depends on the sink and the anchor.
- Mode `on` is still needed for P-idem. Mode `off` keeps no memory (P-retry still holds: Ed25519 is deterministic).

## 6. Durability (NOT implemented; design only)
- The memory is process memory. It is lost at restart. Today the key is lost at the same restart (C-ATT-05), so a
  token signed before the restart is useless with the new key. If the key becomes persistent (KEY_OPTIONS.md), the
  memory MUST become persistent at the same time, else after a restart the same request id can be signed with a
  different candidate (P-idem breaks).
- Design: a SQLite table `issued(charge_id TEXT, request_id TEXT, body_sha256 TEXT, body BLOB, PRIMARY KEY(charge_id,
  request_id))` in a file owned by the issuer; INSERT in the same step as the decision and BEFORE the signature leaves
  the process (fsync: `PRAGMA synchronous=FULL`); on a conflict re-read the row and apply IssueOnce with that memory.
  Alternative: an append-only file of `(charge, request, body sha)` lines, replayed at start. Growth is unbounded in
  both (as today with `on`): one row per request id ever signed.
- If the issuer forgets anyway: the hardened sink still commits at most one token per request id per charge, and only
  on its stored pre-state. What is lost is issuer-side P-idem only (two tokens for one request id can exist; one commits).

## 7. Status
- MACHINE-CHECKED (source level, pinned Dafny 4.11.0): P1 to P5 and the old-rule freeze (see the report).
- TESTED-UNPROVED: minter.ts, the compiled module, the regressions m_*.ts.
- OPEN: owner decision U428 (mode `on` as the deployment default); persistence of memory and key.
