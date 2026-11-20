# Goal 20 brief (launcher, 2026-11-19). Copy this file into the branch as proposals/forge2-goal20-sdk/BRIEF.md in the first commit.

## Owner directive (5-layer "zero-babysitting" Goal 20), as pasted by the owner

VISION: Turn Forge's proved cores and native `F_FULLFSYNC` WAL engine into a 5-minute, zero-Dafny developer
experience in Python and TypeScript (`forge-airlock`). [The directive's "~98% of bugs" figure is NOT a claim the
PR may make: nothing measures it. Owner confirmed: no unmeasured "% of bugs" claim.]

HARD RULES
1. Branch `feat/zero-babysitting-sdk` from `e2b8ba1d` (clean origin/main). Do not touch untracked `.toolchain`,
   `node_modules`, or `results/`.
2. Zero protected/frozen edits: not `gate/`, `spec/`, `spec.lock`, `policy/`, `governance/gate-ratifications/`,
   `package.json`, `package-lock.json`, `tsconfig.json`; nothing under `clearing/`. Zero external npm/pip/Cargo
   packages (std only in Rust, Python, TS/Node).
3. Preserve prior evidence bundles byte-identical (Slice 1, Slice 2, Slice 3, M1 Conformance, Goal 19 Silicon Sink)
   and all 28/28 Stage EXITs.
4. Honesty: `end_to_end=false` explicit. Every result labelled PROVED CORE (CakeML ARM64 / Dafny / Spec Clearing)
   vs NATIVE CHECK (Rust WAL, not proved) vs FINITE TEST. Never mock, hardcode, or fake a block, crash, or commit.

PHASE 2: engine `src/airlock/` (`#![forbid(unsafe_code)]`, std-only Rust) + thin `bin/forge-airlock` (Python
stdlib dispatcher). Layers:
- L1 write airlocks: `money` (total cap, fact-bound reason sub-caps e.g. SHIPPING <= shipping_paid,
  REQUIRE_HUMAN_COSIGN threshold, epoch ratchet, pre_state_hash CAS, fresh request id, F_FULLFSYNC + directory
  sync; canonical refund profiles routed through the CakeML ARM64 binary b8ed5ec2…7bb8, exact scope stated for
  parametric configs); `inventory` (capacity bounds / NoDoubleBooking + Slice 3 integer LP-duality receipt,
  alpha bps); `saga` (allowed from->to transitions incl. PAID -> IN_FLIGHT(proc,key) -> SETTLED |
  CONFIRMED_REJECTED across processors).
- L2 `diff-policy old.json new.json`: concrete Before/After scenario table + ambiguity (NO_CHOICE) check.
- L3 Scoped Read Airlock: non-empty canonical tenant_id scope; block (TENANT_ISOLATION_BREACH, 0 rows leaked) if any
  returned record lacks or mismatches the caller's tenant_id.
- L4 Inbound Obligation Leases: durable WAL OPEN_LEASE(request_id, deadline_ms), closed ONLY by a terminal verdict
  (COMMITTED, REJECTED_POLICY, REQUIRE_HUMAN_COSIGN); `leases --sweep` surfaces DROPPED_OBLIGATION.
- L5 `forge-airlock fuzz`: boundary ints (0, -1, MaxMoney, +1), NUL/Unicode/oversized strings, cross-tenant tokens,
  injected mid-handler exceptions, 50-way TOCTOU bursts, duplicate-ID replay storms.
- SDKs `sdk/py/forge_airlock.py` and `sdk/ts/forge_airlock.ts` (stdlib only) exposing commit, read_scoped,
  with_lease with typed results (COMMITTED, REJECTED_POLICY, REQUIRE_HUMAN_COSIGN, STALE_STATE_HASH,
  DUPLICATE_REQUEST_ID, TENANT_ISOLATION_BREACH, DROPPED_OBLIGATION).

PHASE 3: `examples/unbreakable_store/run_demo.py` (exercising BOTH SDKs), `docs/quickstart-5min.md`,
`scripts/exit_goal20_sdk.py`. Eight disasters alongside valid traffic against real WAL state:
(1) 50-process concurrent double-refund race -> 1 commits, 49 CAS-blocked; (2) $50,000 prompt-injected refund on
$100 order -> blocked, 0 effects; (3) "$10 shipping ask proposed as $80" -> blocked by SHIPPING <= $10 cap;
(4) $75 unstructured goodwill -> REQUIRE_HUMAN_COSIGN; (5) timeout retry + Stripe->PayPal failover while IN_FLIGHT
-> blocked; (6) forgotten WHERE tenant_id -> blocked by read airlock, 0 cross-tenant bytes; (7) unhandled TypeError
mid-webhook before sink -> DROPPED_OBLIGATION; (8) untrusted solver swap with a buggy batch -> valid optima commit,
buggy batch rejected (0 Dafny starts), plus a `fuzz` pass.
Quality bar: >= 25 named mutations of airlock/SDK/lease/read-guard each FAIL exit_goal20_sdk.py for their exact
named reason; two evidence runs give byte-identical SHA-256 bundles; 1 fresh-context adversarial review (fix
FAIL-OPEN/HIGH/MEDIUM in one pass); clean scratch-clone regression (28/28 Stage EXITs, frozen-gate == 0, all 5
prior bundles byte-identical, 0 new dangling Markdown links). Push, open PR without admin bypass or self-merge,
confirm hosted pr_check.py == 3, print EXIT table + PR URL, and PAUSE.

## Approved Phase 1 plan (launcher's 15 lines, approved by the owner)
1 CLI: bin/forge-airlock thin Python dispatcher over std-only Rust src/airlock/; subcommands init, diff-policy,
  serve, fuzz, leases --sweep, replay. src/silicon_sink/sink.rs stays unchanged.
2 SDK: sdk/py (stdlib) and sdk/ts (Node 24 built-in type stripping; no package.json change). commit, read_scoped,
  with_lease; typed results.
3 Transport: one `serve` process per store over bounded line pipes (like sink.rs MAX_LINE), typed codes, canonical
  ids [A-Za-z0-9_-]{1,24}.
4 L1 store: generalize sink.rs design (64-byte CRC'd record, FNV-1a-128 chain + CAS, flock, F_FULLFSYNC + dir sync,
  epoch ratchet) to many keys + tenant field. NEW Rust, NOT proved: finite + kill tests.
5 money: proof scope = only the canonical refund profile through CakeML binary b8ed5ec2 (3 fixed reasons, 1 charge).
  Parametric JSON policies = NATIVE CHECK + FINITE TEST, no proof.
6 inventory: capacity + Slice 3 Accepts(A,c,w,x,y,z,alpha_bps) (proposals/forge2-pillar3-dual-certificate/
  BookingDualCert.dfy).
7 saga: JSON transition table; second processor refused while IN_FLIGHT; WAL CAS. NATIVE CHECK + tests.
8 diff-policy: concrete Before/After table from two JSON policies; NO_CHOICE via scripts/spec_clearing.py on Dafny
  emitted by a fixed generator.
9 read_scoped: refuse the whole result if any row lacks/mismatches tenant_id. LIMIT: sees only rows passed to it.
10 leases: durable OPEN_LEASE closed only by a terminal verdict; sweep reports DROPPED_OBLIGATION. LIMIT: only
  handlers that opened a lease.
11 fuzz: finite.
12 cosign: see decision 2.
13 demo: Stripe/PayPal are LOCAL FAKE processors, labelled as such; scoreboard (latency, peak RSS, attacks, $0 leaked).
14 exit script: >= 25 named mutations, byte-identical evidence x2, fresh review, scratch clone.
15 limits: end_to_end=false; no "% of bugs" claim; each result labelled.

## Owner decisions on the plan (verbatim)
1. Line 6 (inventory): Approved--call the Dafny-compiled checker through Node (proved source; Dafny compiler trusted).
2. Line 12 (cosign): Approved--require a `0600` human key file under D-1 rules (`O_NOFOLLOW`, `fstat`, owner-only)
   signing `(request_id, pre_state_hash, action)` verified against a pinned public key so the agent cannot
   self-cosign.
3. Line 8 (`diff-policy`): Approved--the small deterministic JSON-to-Dafny generator is accepted as an explicitly
   stated trusted assumption (with negative controls). Keep Line 15's strict honesty labels (no unmeasured "% of
   bugs" claim).

## Launcher notes on the decisions (must be reflected in code and docs)
- Rust std and Python stdlib have no Ed25519. Signature VERIFICATION of the cosign goes through Node's built-in
  `node:crypto` (Ed25519) in a bounded subprocess, the same trusted-Node route as decision 1. The airlock holds
  only the PINNED PUBLIC KEY. State "Node crypto is trusted" as an assumption.
- The private cosign key is read with the D-1 rules (O_NOFOLLOW, fstat on the opened descriptor: regular file,
  uid == euid, mode & 0o077 == 0) by the HUMAN's signing tool, not by the airlock. HONEST LIMIT to state in the PR
  and quickstart: if the agent runs as the same OS user as the key owner, it can read a 0600 file; "agent cannot
  self-cosign" holds only if the private key is outside the agent's reach (another OS user, hardware key, or a
  separate machine). Tests use temporary keys generated at test time; never commit a private key.
- Signed message = a canonical, domain-separated encoding of (request_id, pre_state_hash, action) so no field
  boundary collision is possible; add negative tests (wrong key, other request id, other pre_state_hash, altered
  action, replay on another store).
