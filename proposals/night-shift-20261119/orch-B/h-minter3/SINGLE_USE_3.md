# The issuer's memory rule under owner decision D-2 (h-minter3; red team C-ATT-38, 39, 40; review r-issueauth)

This file corrects and extends SINGLE_USE_2.md (h-minter2). SINGLE_USE_2.md is not edited.

## 0. Corrections to SINGLE_USE_2.md
- Section 3, C-ATT-30: "NoStore mode: signed under its own key (its own pre-state hash), so it cannot block the
  victim." This is FALSE as a general statement (red team C-ATT-38). A spray over every possible pre-state includes the
  victim's real pre-state. Under rule 2 as built by h-minter2, a REFUSED request on that state closed the victim's key
  (about `original` requests, no knowledge of the state). A ZERO-AMOUNT request on that state is MINTED and takes the
  key (the same spray size). The proof SquatsThenVictim covers only calls on OTHER keys; a spray contains the victim's.
- Section 2 and section 5: the Dafny theorems treat the authoritative state, the settled flag (the Auth value), the
  pre-state hash text and the memory as FREE PARAMETERS of Issue. Binding them to the real store and to SHA-256 of
  canon(pre) is TypeScript glue in minter.ts (assumptions STORE-READ, G-H). The reviewer's probes ProbeFreeAuth and
  ProbeHashFree still verify. No cheap strengthening was found: no uninterpreted hash exists in SerModel.dfy or
  IssueBytes2.dfy (checked); a bodiless function is an audit finding; a hash-function parameter binds h only inside one
  RunSeq call and needs a rewrite of Issue (near its resource limit). NOT DONE. Stated in the headers of IssueAuth.dfy
  and minter.ts ("what the proof covers and what it does not").
- Section 5: the NODE_OPTIONS check inside minter.ts is NOT a defence. It runs after Node has run a --require or
  --import preload (from NODE_OPTIONS or the command line); such code has already run and can change what the check
  sees. It only reports a careless launch. The defence is the closed launch (minter-launch.sh, CLOSED-LAUNCH). The
  comment in minter.ts now says so.
- Section 3, U576 gap ("a refused pair could later sign": implemented as "the core's refusal closes the key"): REMOVED by
  owner decision D-2. Section 7 OQ-H2-1: answered by D-2.

## 1. The rule (owner decision D-2, verbatim)
"A minter refusal closes ONLY that attempt, NOT the whole request ID (closing C-ATT-38). Only an accepted/minted token
(and sink commit) closes the request ID, preserving <= 1 valid token and <= 1 effect per request ID."
There is NO switch. The earlier rule exists only as a Dafny model (OldAfter, OldRuleFreeze).

## 2. Order of the decision (IssueAuth.Issue; all in the proved method)
1. The core refuses (not authorized, or not a well-formed body) -> RefusedByCore. Memory unchanged.
2. The key holds Signed(exactly these bytes) -> Replayed (the same token; also after the store moved on).
3. Store mode, the request id is settled in the store -> RefusedCompleted.
4. The key holds Closed -> RefusedClosed (only a memory passed in can hold Closed; this rule never writes it).
5. The key holds Signed(other bytes) -> RefusedOtherCandidate ("stale candidate" / "other candidate").
6. Store mode, pre-state != stored state -> RefusedNotAuthoritative.
7. Otherwise (admitted, key new) -> Issued; key -> Signed(bytes). The ONLY memory change.
The core check is first (it was fourth). So RefusedByCore <==> !Issuable: it depends on the call alone.

## 3. Invariants and their proofs (IssueAuth.dfy; MACHINE-CHECKED: see the report for the run)
- I1 at most one valid token per (charge id, request id), Store mode: RunSeq postcondition "I1" (with S1). So another
  candidate for a minted pair is refused, and an identical request gets the identical bytes (WRetry, WStaleRetry).
- I2 a refusal records nothing: Issue postcondition m2 == After(m, k, o) with After(m, k, o) == m for every outcome other
  than Issued; lemma RefusalRecordsNothing; RunSeq postcondition "I2"; SprayHarmless (after ANY sequence of calls by
  anyone that were not Issued on the victim's key, the victim's honest call is Issued); witness WSpray.
- I3 a settled request id stays closed: Issue postcondition (o.Issued? ==> Admitted); RunSeq postcondition "I3".
- COMPOSED CLAIM, not proved as one theorem: at most one EFFECT per request id = I1 + the sink rule (settled.request_id
  UNIQUE; a token commits only on its stored pre-state; sink.ts, core/store.ts). TESTED end to end:
  m3_one_effect_per_request_id.ts.
- What is LOST against the letter of protocol.md:61-62 and 64-65 (approved by D-2): after a rejection, the same request
  id can still be signed (WRefusalThenSameId); an identical repeat of a refused request is decided again, not answered
  from a record. The core refusal is a function of the call, so it gives the same answer. An authority refusal can
  change if the store later holds the caller's pre-state.

## 4. Modes
- PRODUCTION: memory rule "on" WITH the sink's store. Ready line "singleUse": true. The closed launch accepts only this
  (minter-launch.sh needs 5 arguments with "on"; minter.ts refuses any other mode in a closed launch).
- TEST modes (stderr warning line; ready line "singleUse": "none"):
  - "on" without a store: key = (charge id, request id, pre-state hash). Two tokens can exist for one request id on two
    pre-states: I1 does NOT hold. The sink still commits at most one (it only commits on its stored pre-state).
  - "off": no process memory. I1 does NOT hold at the issuer (two candidates for one request id can both be signed).
- Why (b) "test mode only" and not (a) "key (charge id, request id) without a store": (a) brings back C-ATT-30 (a mint on
  an invented pre-state takes the request id: the issuer cannot know the real state without the store). No way was found
  to keep I1 and "no squat on an invented state" without the store.

## 5. Refusal texts and the state oracle (C-ATT-38)
- One generic caller text "core: Refuse" for RefusedByCore AND RefusedNotAuthoritative. The outcome name goes to stderr
  for the operator ({"refusal": {...}}).
- "attempt completed" depends on the settled table for the caller's own request id; "stale/other candidate" on the
  memory for the caller's own key (checked before the state comparison).
- TESTED: m3_refusal_texts_generic.ts: 1000 unauthorized probes over all guessed states give ONE text.
- LIMIT (not closed): the answer to an AUTHORIZED zero-amount request on a fresh request id is a token for the right
  guess and "core: Refuse" for a wrong one. A caller without the key can still find the state, and can MINT a zero-amount
  token with the victim's request id on the real state (C-ATT-08 class, witness WSquatRealState, KNOWN-LIMIT regression
  m3_zero_squat_limit.ts: 364 probes in its run). The issuer has no caller identity. No money moves.

## 6. C-ATT-39 (store replaced by mv)
minter.ts opens the store at EACH request and closes it after the read (no connection kept). A path that does not exist
is refused with "store: the store path is gone". TESTED: m3_store_replaced_by_mv.ts.

## 7. C-ATT-40 ("off" mode, identical retry)
In mode "off" with a store, minter.ts reads the settled row's token for the request id and passes its body bytes as the
memory entry of the key (the only entry). IssueAuth.Issue returns Replayed only if these bytes are exactly the bytes it
computes for THIS authorized call (proved: Replayed ==> Issuable and bytes == Expected): the seed cannot make it sign
anything else. The exact rule is in the minter.ts header; the stated exception: a token minted but never committed, after
the store moved on by another request, gets "core: Refuse" (its old token cannot commit: stale pre-state).
TESTED: m3_off_identical_retry.ts.

## 8. Named assumptions (unchanged unless said)
STORE-READ (now read at each request), G-H, CLOSED-LAUNCH (now also: production mode only), FIXED-DEPS, SAME-UID,
SHA-256 collision resistance. New: SETTLED-ROW (mode "off" only: the settled table's token column is the committed
token; a wrong value can only cause a refusal or a Replayed of bytes that are authorized for the call).

## 9. Red team copies (orch-C c24-minter2, unchanged copies in rt/c24; ORIGINAL_SHA256 matches)
- s11_nostore_spray: before 1, after 0 (victim issued on the real and on a later state).
- s8_squat_search close: before 1, after 0. s8 zero: before 1, after 0. CAUTION: both "after" results come from the
  script's own search loop. It stops at the first answer that is not "pre-state is not the authoritative stored
  state", and that text no longer exists. So it stops at probe 1 ("core: Refuse") and then tries the victim. For
  "close" the result is real: refusals record nothing, whatever the probes are (m3_refusal_does_not_close.ts, 1000
  refusals). For "zero" the result is an ARTIFACT: a search that looks for a TOKEN still finds the state in 364 probes,
  mints the squat and blocks the victim (m3_zero_squat_limit.ts: exit 1; KNOWN-LIMIT with --expect-limit).
- s4 mv: before 1, after 0. s2 off: before 1, after 0. s1 honest: 0 and 0 (one text changed: "beforeFile" is now
  "store: the store path is gone"). s9 rollback: 0 and 0.
