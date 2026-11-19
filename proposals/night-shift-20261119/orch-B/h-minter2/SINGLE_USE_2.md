# The issuer's memory rule, version 2 (h-minter2; red team C-ATT-29, 30, 31, 14; review U576)

Rule 1 (IssueOnce, h-minter, U575) is replaced in minter.ts by rule 2 (IssueAuth, impl/finality-core/IssueAuth.dfy).
IssueOnce.dfy is unchanged and stays as the record of rule 1.

## 1. The approved text (spec/refund/protocol.md, read only; line numbers of commit f08a21c1)
- 25-27: "Zero is a legitimate authorization, distinct from fallback. A valid zero proposal returns Authorized(0,
  reason) and one zero-valued intent."
- 61: "One attempt is active for a caller-bound (charge ID, request ID)."
- 61-62: "Completion, rejection, failure, or timeout closes that attempt."
- 62-63: "A late completion is ignored and cannot reopen it."
- 63-64: "An identical repeated request returns its recorded decision without another executor call."
- 64-65: "Reusing the pair with different trusted context is rejected. A new attempt needs a new request ID."
- Owner decision B-10 (PHASE2_RULES.md): the governing context is the approved, versioned policy plus the
  AUTHORITATIVE PERSISTED charge state. So the pre-state is trusted context, and only the stored state is trusted.

## 2. Rule 2
The shell reads the sink's store (read only, optional 4th argument of minter.ts) and passes Auth to IssueAuth.Issue.
- Store mode: Auth = Store(stored charge, request id settled?). Key = (charge id, request id).
- NoStore mode: Auth = NoStore. Key = (charge id, request id, pre-state hash text).
Order of the decision (all in the proved method):
1. key holds Signed(exactly these bytes) -> Replayed (same token; also after the store moved on; 63-64).
2. Store mode, pre-state != stored state -> "pre-state is not the authoritative stored state"; nothing recorded.
3. Store mode, request id settled in the store -> "attempt completed: use a new request id"; nothing recorded.
4. core refuses -> "core: Refuse"; a NEW key is recorded Closed (61-62).
5. key holds Closed -> "attempt closed: use a new request id".
6. key holds Signed(other bytes) -> "stale candidate: use a new request id" (the signed candidate is on another
   pre-state) or "other candidate: use a new request id" (64-65).
7. key new -> Issued; key -> Signed(bytes).
The refusal texts are fixed strings (machine-readable). "core: Refuse" is unchanged (suite.ts and scripts use it).

## 3. Decisions on the findings
- C-ATT-30 (squat on an invented pre-state): FIXED. Store mode: refused, not recorded. NoStore mode: signed under its
  own key (its own pre-state hash), so it cannot block the victim. Proved: SquatsThenVictim, WrongStateHarmless,
  OtherHashHarmless, WSquatStore, WSquatNoStore. NOT fixed: a caller who sends the REAL state with the victim's id
  first (WSquatRealState; red team f2 "zero" mode; class C-ATT-08). The issuer has no caller identity; 61 says
  "caller-bound". Owner question B-12(1) stays.
- C-ATT-29 (honest retry of one request id on a new state): the refusal is REQUIRED by 64-65 ("different trusted
  context is rejected. A new attempt needs a new request ID."). Kept in Store mode, with the text "stale candidate:
  use a new request id" (WStaleRetry; m2_stale_retry_store_mode.ts). In NoStore mode the issuer cannot know the
  trusted state; it signs the retry (new key), and the sink commits at most one token per request id. This is a
  DIFFERENCE from 64-65 in NoStore mode (owner question OQ-H2-2).
- f1 "amount" variant (same pre-state, corrected amount, same id): refused. Reading of 64-65: the request is not
  identical, so it is a new attempt, and "A new attempt needs a new request ID."
- U576 gap (a refused pair could later sign): IMPLEMENTED per 61-62: the core's refusal at the first use of a key
  closes it (S3 of RunSeq; WClosed; m2_refused_pair_stays_closed.ts). Completion closes it durably through the
  store's settled table (Store mode). Failure and timeout are not visible to the issuer (no transport state). Owner
  question OQ-H2-1 names the cost.

## 4. What survives of U575 (P1 to P5)
- P1 "one byte string per key" CHANGES to: Store mode: one byte string per (charge id, request id) over the life of
  the process (unchanged meaning; new bytes only on the stored state with an unsettled id). NoStore mode: one byte
  string per (charge id, request id, pre-state hash text); one request id can have tokens on several pre-states;
  the sink commits at most one token per request id per charge, and only on its stored pre-state.
- P2 retry: survives and is stronger (Replayed also after the store moved: WRetryAfterMove).
- P3 other candidate refused: Store mode: survives (also across pre-states). NoStore: only within one pre-state hash.
- P4 no freeze: survives (Live, L3 of RunSeq, WZeroZeroPositive); plus SquatsThenVictim. Limit: WSquatRealState.
- P5 safety: survives (every signing outcome is authorized and well-formed; bytes = canonical body bytes).
- NEW: S2 Issued only on the stored state with an unsettled id (Store mode); S3 closed stays closed; S4 an
  un-admitted call does not change the memory.

## 5. Start-up environment (C-ATT-31, C-ATT-14)
Inputs that can change which code runs in `node --import tsx minter.ts`: NODE_OPTIONS (--require, --import, loaders);
NODE_PATH; the tsx transform cache (os.tmpdir()/tsx-<uid>: TMPDIR, or the default directory, writable by the same
user, keyed by public inputs, read without an integrity check); TSX_TSCONFIG_PATH and tsconfig.json "paths" (tsx);
NODE_COMPILE_CACHE (Node's code cache directory); NODE_ICU_DATA (data, not code); OPENSSL_CONF / OPENSSL_MODULES and
the default openssl.cnf (can load providers = native code); DYLD_INSERT_LIBRARIES / DYLD_LIBRARY_PATH (macOS) and
LD_PRELOAD (Linux); HOME (~/.node_modules and ~/.node_libraries as fallback folders); the working directory
(tsconfig search, relative paths); every node_modules directory up the tree and symbolic links in it; the Node binary
and its libraries (/opt/homebrew: writable by the same user). NODE_EXTRA_CA_CERTS and NODE_TLS_* change TLS trust only
(the issuer makes no TLS connection): not a code input.
Implemented (TESTED-UNPROVED, m2_closed_launch.ts): ts/refund-finality/launch/minter-build.sh (esbuild bundle, no
transform at run time; core, bignumber.js and the source copies inside one directory; MANIFEST.sha256) and
minter-launch.sh (pin of the manifest digest; /usr/bin/shasum check of every file and no extra file BEFORE Node;
`env -i` allow-list; fixed Node path and version; fixed options --no-addons --disallow-code-generation-from-strings);
minter.ts re-checks environment, options, manifest and the loaded module set after loading, and reports
closedLaunch on stderr. The tsx launch (tests, red team f9) is NOT closed and stays exit 1 on f9.
Named assumptions:
- CLOSED-LAUNCH: the issuer is started only by minter-launch.sh with the pinned manifest digest from the operator's
  configuration. Excludes: caller environment variables, node options, the tsx cache, foreign files in the directory.
- FIXED-DEPS: /opt/homebrew/bin/node v24.3.0, its libraries, OpenSSL and its default configuration, and /usr/bin
  tools are the intended ones. Excludes: a replaced Node binary or library (not checked by any digest here).
- SAME-UID: no hostile process runs as the issuer's user (or root). NOT excluded by any check here: such a process
  can change files between the check and the read, ptrace or attach a debugger, read the key from memory, or
  replace Node. No claim of closure against it.
- STORE-READ: the store path is the sink's store; a writer of that file can steer the issuer (and can do worse).
- G-H (unchanged) and SHA-256 collision resistance (NoStore key separation).

## 6. Memory durability and bound (U575 uncertainty; item 5)
- Money safety does not depend on the memory: the sink commits at most one token per request id per charge and only
  on its stored pre-state. In Store mode, completion is durable through the store's settled table (read per call).
- What the memory is still for: the text rule 64-65 for tokens that never commit, the closed state after a core
  refusal (61-62), and fewer signed uncommitted tokens (D14 surface: C-ATT-32 stays a sink/anchor matter).
- Restart: the memory and the key are lost together (C-ATT-05: owner item; key handling unchanged). An old token
  cannot commit at a sink pinned to the new key. KEY_OPTIONS.md (h-minter) stays valid with one correction: the
  memory that must persist WITH a persistent key is now IssueAuth's (Signed and Closed records, keyed as in section 2).
- Design (NOT implemented): an append-only file of one line per new record (key canon, Signed sha256 + bytes, or
  Closed), written and fsynced BEFORE the answer leaves the process; loaded at start; start refused on a malformed
  line. Bound: one line per key admitted; in Store mode only calls on the stored state add lines, but fresh request
  ids still add lines without limit (any caller who knows the state). A cap ("issuer memory full") bounds it at a
  liveness cost: owner choice.

## 7. Owner questions (text for OWNER_REQUIRED; not edited here)
- OQ-H2-1: "Rule 2 closes a (charge id, request id) at the issuer when the proved core refuses its first candidate
  (protocol.md:61-62, 'rejection closes that attempt'). A host that sent a wrong amount must then use a new request
  id, and a caller who knows the stored state can close a victim's request id with one unauthorized request (the
  same power as the zero-amount squat C-ATT-08). Keep closing on refusal, or close only on completion (settled in
  the sink's store)?"
- OQ-H2-2: "Without a store path the issuer cannot know the authoritative state; it keys its memory on the
  pre-state hash and signs the same request id again on another pre-state (a difference from protocol.md:64-65; the
  sink still commits at most one token per request id). Must a deployment run the issuer in Store mode only (refuse
  'on' without a store)?"
