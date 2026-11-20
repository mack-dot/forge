# Forge: independent review (origin/main = 33055a59, 2026-11-20)

Reviewer method: read-only. I read files from `origin/main` (extracted with `git archive`), PR metadata through `gh`, and recorded evidence. I ran no test, build, Dafny or HOL job, so every "actual exit" below comes from the records and I did not reproduce it. Line numbers refer to `origin/main`.

## Verdict

1. The labelling is unusually honest. `end_to_end=false`, the evidence classes, and the BETA-PLAIN boundary hold up in the long-form records. The problem is in a few headline phrases (the "PROVED CORE" label, the "humans approve" tagline, "independent" reviews).
2. The machine-checked content is real but very small. The proved refund decision is about five comparisons (`spec/refund/RefundSpec.dfy` is 64 lines; `impl/Refund.dfy` is 15). The large HOL4/M1 effort proves the compiled bytes of that small function, and the chain is still open.
3. The product core (`src/airlock`, about 120 KB of std-only Rust plus two SDKs) is careful, fail-closed code. But no proof and no CI cover it. Its security rules hold only against a caller that cannot reach the store folder, the engine binary or the helper paths, and the shipped SDK does not provide that deployment.
4. The repository is about 1% product and 99% records: 16,261 tracked files, 172 MiB, `unsure.md` at 19,958 lines. There is no licence, and the README does not mention the SDK. An outside developer cannot adopt this today.
5. Net: this is a credible research artefact with good engineering habits. It is not yet a product. Move proof effort to the engine's WAL and fold, ship an isolated deployment mode, and split the archive from the product.

## Claims table

| # | Claim (location) | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | "Humans approve intent (specs), not code." (README.md:3) | OVERSTATED | The project's own assurance graph marks the approval link as missing: S1 "no approval channel exists that the agent cannot forge" (proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH.md:40). Row 5 says "Enforcement does not exist ... every merge since pull request 38" (same file:143). The repo is private, and the branch-protection API answers 403, so `main` is unprotected. |
| 2 | "Forge is a public research prototype" (README.md:9) | UNSUPPORTED (factually wrong today) | `gh repo view`: `"visibility":"PRIVATE"`, `licenseInfo: null`. README.md:202 says no licence is selected. |
| 3 | Stage 8: claims R1 to R5 for `impl/Refund.dfy` are `source_proof` (README.md:99) | SUPPORTED, but narrow | `impl/Refund.dfy` has 15 lines: `if Eligible(...) then Authorized else Rejected`. The spec is 64 lines. It has no `assume` and no `{:axiom}` (I grepped every impl/*.dfy). The proof is true, but it mostly restates the spec. |
| 4 | Slice 1: P1 to P4 `source_proof`; "Issuer, sink and dispatcher: 115 suite rows, 48 rejection attempts with 0 effects" (README.md:103) | Proof SUPPORTED; sink row OVERSTATED by omission | The project's own graph says the merged `ts/refund-finality/sink.ts` is "KNOWN DEFECTIVE on `main`". Red-team exploits E1 and E2 give two refunds for one request id (TOP_LEVEL_GRAPH_REFRESH_20261119.md:77, :232; proposals/night-shift-20261119/orch-C/c3-identity/e1_two_effects_one_reqid.ts). The file has not changed since PR #45, and the fix is an unapplied diff. The README row does not mention this. |
| 5 | Round 4: "a change to a protected path needs a ratification record ...; three independent reviews" (README.md:102) | OVERSTATED | Nothing enforces it. There is no branch protection, and graph row 5 (TOP_LEVEL_GRAPH.md:143) says so. The "independent" reviewers are "separate workers of the same model family on the same machine" (TOP_LEVEL_GRAPH_REFRESH_20261119.md, rules section). |
| 6 | Stage 7: every valid execution of one exact 1,240-byte RISC-V ELF terminates; 579 modules; 86 closure assumptions (README.md:98) | SUPPORTED by the record (not re-run) | docs/stage7-binary.md:131, :172. The claim is correctly scoped as a termination claim about a self-test, not a functional claim. |
| 7 | M1: HOL4 theorems about a machine model that holds the ARM64 bytes; "95 theories replay"; "Verified native execution is NOT established" (README.md:106) | SUPPORTED (honest) | m1-chain-replay-20261118/REPORT.md:89 ("95 theories replayed with exit 0, 95 equal"). The open premises (FFI, TBI0/SA0) are stated. |
| 8 | Goal 20: the CakeML binary is a "PROVED CORE" that "decides" canonical refunds (docs/quickstart-5min.md:197-200; src/airlock/main.rs:6; verbs.rs:162) | OVERSTATED | M1-B is OPEN, and two premises of the binary theorem are false for real machines (README.md:106). The quickstart's label list leaves out that caveat. Only proposals/forge2-goal20-sdk/REPORT.md:23-25 states it. Also, quickstart:197 says "only two decisions" and then lists three. The engine re-checks the amount and the reason natively after the binary (verbs.rs:169), so the "proved" gate adds almost nothing over the unproved one. |
| 9 | APEX-2: the Dafny to HOL4 link is "pinned and tested, NOT machine-checked" (PR #66; apex2 README §4) | SUPPORTED (exemplary wording) | proposals/apex2-contract-link-20261119/README.md section 4 names the BETA-PLAIN boundary as ASSUMPTION/TU. The graph refresh says "No row changed class". |
| 10 | "70 copies of the check scripts with one check removed each ... all fail" (README.md:117-119) | SUPPORTED by the records (arithmetic 10+11+26+23 = 70; not re-run) | Slice reports. |
| 11 | "Run it" gives the way to use Forge (README.md:133-163) | OVERSTATED as a product entry point | The README does not mention `forge-airlock`, the SDKs, the sink or `docs/quickstart-5min.md` (grep: zero hits). Only ROADMAP.md and proposals link the quickstart. |

## Defects (ranked by severity)

### D1. HIGH: in the shipped SDK flow, the engine runs inside the trust domain of the caller it is meant to constrain
- `sdk/py/forge_airlock.py:302` (and `sdk/ts/forge_airlock.ts:302`) start `python3 bin/forge-airlock serve <dir>` as a child process under the same OS user. `serve_argv` and `engine_dir` are caller-chosen (`forge_airlock.py:290-293`). Nothing pins the engine binary (PROTOCOL.md section 11, "the engine binary itself: by nothing in this repository").
- Scenario: an agent that uses the SDK as documented passes `serve_argv=[..., 'build/airlock/airlock-engine-kill', ...]` or a modified engine. Or it appends a `REFUND t k r1 returned_item 5000000 0` record straight to `airlock.wal` with a correct CRC-32 and FNV chain (neither is keyed; store.rs:5-6). `replay()` then lists it as a committed effect, and no check ran.
- The docs state this boundary honestly (PROTOCOL.md:504-514; quickstart "Trust boundary"). But no supported isolated mode exists: there is no socket server, no service user, and no setup script. So every safety claim in the demos holds only against a buggy caller, not a malicious one.

### D2. HIGH (in the deployment that the docs recommend): pins are checked once by path, and the pinned files stay writable by the agent's user
- `helpers.rs:87-97`: each pin is hashed once per process (`OnceLock`), and later runs exec the same path. Line 7-8 admits "a file swapped between the hash and the exec is not detected." The Node path comes from `FORGE_AIRLOCK_NODE` or `PATH` (`bin/forge-airlock:78-99`). The refund binary is `<repo>/build/airlock/refund-binary` (`bin/forge-airlock:45`), inside the developer's checkout.
- Scenario: the owner follows PROTOCOL.md section 11 and runs `serve` as a separate user, but uses the Homebrew Node (`/opt/homebrew/bin/node`, owned by the developer account that the agent shares). After the first cosign call passes the pin, the agent replaces that file with a script that prints `VALID\n` and exits 0. Every later `REFUND ... <any 128-hex>` then commits with `cosigned=1` (verbs.rs:176-180, helpers.rs:123-135). That bypasses human cosign completely.
- Related: `booking_check.cjs:168` resolves `bignumber.js` through `node_modules` paths that start at the caller-chosen `--checker` folder (main.rs:265-268). This one is lower impact, because the native `policy::accepts` (verbs.rs:249) gates first.
- Fix: copy each pinned file into an engine-owned, read-only location and verify that copy at every exec. Or open the file once, hash the open descriptor, and exec it through `/dev/fd`. Document ownership requirements for every path, not only for the store folder.

### D3. MEDIUM: one global key namespace and one global request-id namespace across tenants (squatting and existence oracle)
- `ledger.rs:72` (`!self.keys.contains_key(key)`), `verbs.rs:79-84`, `verbs.rs:266-269`. PROTOCOL.md:191 documents the shared request-id namespace. It does not discuss the shared key namespace.
- Scenario: tenant B opens `order-1001` first. Tenant A's legitimate `OPEN_MONEY t-A order-1001 ...` then fails with `TENANT_ISOLATION_BREACH` for good. B can probe whether any key or request id exists in another tenant (`KEY_OF_ANOTHER_TENANT` vs `UNKNOWN_KEY`, `DUPLICATE_REQUEST_ID`).
- Nothing authenticates the tenant field (PROTOCOL.md:300-304), so "tenant isolation" only prevents accidents. The code name `TENANT_ISOLATION_BREACH` suggests a security boundary. Use per-tenant keys (`tenant/key`) and authenticate callers per tenant.

### D4. MEDIUM: an O(N) full WAL re-fold on every request; no snapshot, compaction or bound
- Every verb calls `store::open` (verbs.rs:116, 154, 190, 200, 229, 239, 265), and that function scans the whole WAL from byte 0 (store.rs:137-140). A commit costs two `F_FULLFSYNC` calls. The exclusive lock stays held while a helper runs, for up to 10 or 30 s (PROTOCOL.md:541-543). Leases never consume a request id, and the ledger keeps every lease in memory forever (ledger.rs:54, 177-183), so any caller can grow the WAL without bound.
- Scenario: one million small records is about 100 MB of WAL. Each request then reads and parses 100 MB under a global lock. Throughput falls to a few requests per second, and a caller who floods `OPEN_LEASE` speeds that up. No throughput or latency figure exists in the Goal 20 report.

### D5. MEDIUM: a known duplicate-effect defect is still on `main`
- `ts/refund-finality/sink.ts` is unchanged since PR #45. The graph marks it "KNOWN DEFECTIVE on `main`" (TOP_LEVEL_GRAPH_REFRESH_20261119.md:77, :232). Exploit E1 (orch-C/c3-identity/e1_two_effects_one_reqid.ts): a token whose `body.requestId` differs from `intent.requestId` makes the dispatcher send two refunds for `rq_1`. The threat model is a faulty signer. The hardening sits only as an unapplied diff. The README still cites this sink's test counts (claim 4).

### D6. LOW-MEDIUM: `REQUIRE_HUMAN_COSIGN` closes an obligation lease while the action is still pending
- `verbs.rs:97-105` treats `REQUIRE_HUMAN_COSIGN` as terminal and writes `CLOSE`, and `ledger.rs:184-188` accepts that close. But a refusal leaves the request id fresh (PROTOCOL.md:191-192), so the signed retry is still expected.
- Scenario: a webhook opens a lease and gets `REQUIRE_HUMAN_COSIGN`. No human ever signs. `leases --sweep` never reports `DROPPED_OBLIGATION`, which is exactly the dropped work that leases exist to expose.

### D7. LOW: ratchet and WAL corruption handling
- A ratchet entry with a bad CRC is skipped silently, and the floor comes from the remaining valid entries (store.rs:145-155; sink.rs:114-117). Bit rot in the newest entry lowers the floor by one, and then a one-record WAL rollback passes the `EPOCH_REGRESSION` check.
- A full-length final WAL record with a bad CRC (for example zero-fill after power loss) gives `CORRUPT_WAL` with no repair tool. That fails closed, but the store becomes unavailable. Power loss is untested (stated).

### D8. LOW: hand-written primitives and minor SDK divergence
- The SHA-256 (pin.rs), JSON parser (json.rs), CRC-32 and FNV are all hand-written to keep "std only". Known-answer vectors and fuzzing are their only checks. That widens the trusted base, which the std-only rule was meant to shrink.
- The TS `readScoped` turns bigint into string (forge_airlock.ts:179), and `JSON.parse` loses precision above 2^53. The released rows can then differ in type and value from the caller's rows, and Python behaves differently. This does not break isolation, but the two SDKs do not have the same semantics.

What is good in the core: strict canonical grammars (single spelling for ids and amounts; printable ASCII only). Fail-closed helper wiring (exact frame, exit code, empty stderr, all stdin written, time limit). The write path is "fold check, then write" (store.rs:196). Truncate-on-failed-sync, with `OUTCOME_UNKNOWN` when the truncation fails. A ratchet against single-file restore. `init` builds the store in a temporary folder and renames it into place. The verdict picks the most restrictive matching rule, and no matching rule means reject (policy.rs:160-173). There are kill-point builds for crash tests and a mutation catalogue (PROTOCOL.md section 13). The SDK `read_scoped` serializes rows once and releases only rows parsed back from the sent text. This is good defensive code, written by someone who expects attacks.

## Proof-honesty notes

- What is machine-checked:
  - Dafny source proofs of small models (Ledger, Refund, RefundFinality, Booking, BookingDualCert, the spec-clearing lemmas).
  - HOL4 model-level theorems about the CakeML-compiled refund program inside a machine model, with open premises (M1-B OPEN). One premise is the FFI contract, which the project marks as false for the present C. The other is the processor bits TBI0/SA0, which are never observed on real hardware.
  - Rocq termination of one 1,240-byte RISC-V self-test.
- What is only tested or assumed: the whole airlock engine (WAL, fold, compare-and-swap, policies, saga, leases, read airlock), both SDKs, the dispatcher, the Rust sink, every TypeScript issuer, sink and dispatcher, Node and `node:crypto`, the Dafny-to-JS compiler, the HOL-to-Dafny translation (BETA-PLAIN), the loader and entry state, and deployment. The records say all of this. The graph rule "a row is as weak as its weakest part" is applied consistently.
- Where the wording blurs the line:
  1. "PROVED CORE" for the CakeML binary (quickstart:197-200; main.rs:6; verbs.rs:162). The binary has no native correctness theorem. A reader will read "proved" as "the binary is proved to implement the spec". A better label: "compiled by a verified compiler; model-level theorem; native link open".
  2. "source_proof" next to product claims. The paths that the demos actually use (parametric money rules, saga, cosign) have no proof at all. The proved refund function is a conjunction of five comparisons, and the native code re-checks it anyway (verbs.rs:169). Most of the formal budget goes to the part with the least risk.
  3. "independent reviews" (README.md:102) vs "same model family, same machine" (graph rules). Use "fresh-context review by the same model family".
  4. "TENANT_ISOLATION_BREACH" for an unauthenticated field (D3).
  5. The README tagline (claim 1) vs the missing S1 approval channel.
- Credit: APEX-2 section 4 ("NEVER call it machine-checked"), the README M1 row with its self-correction, and the "A test count is never a proof" rule are better than most commercial assurance material.

## Developer experience

Could an outside developer clone, understand and use the SDK in an hour? Mostly no.
- Legal: there is no licence (README.md:202), and the repo is private. Nobody may use it.
- Discovery: the README describes Stages 1 to 11 and three "slices". It never names `forge-airlock`, the SDKs or the quickstart. You need ROADMAP.md or the proposals to find `docs/quickstart-5min.md`, and that page is good and honest about time and tools.
- Platform: the canonical-refund profile needs macOS ARM64 (Mach-O CakeML binary). Node must be exactly 24.x (`bin/forge-airlock:93-98`), rustc 1.92, and Dafny 4.11 for inventory. The engine is std Rust and probably builds on Linux (`File::lock`, `sync_all`), but nobody has tested that. None of the 12 workflows builds or tests `src/airlock`, `sdk/` or `src/silicon_sink` (grep for airlock/rustc/silicon in `.github/workflows`: zero hits). Most workflows are Stage 9 probes.
- Packaging: the SDKs find the dispatcher relative to their own file (`forge_airlock.py:51-52`, `forge_airlock.ts:34-35`). There is no pyproject, no npm package and no Cargo.toml. To use the SDK you must keep a full clone: 216 MiB pack, 16,261 files.
- Readability: the controlled-English style with many internal IDs (U840, T13, X8, BETA-PLAIN, M1-B) is precise but opaque to newcomers. PROTOCOL.md alone is 50 KB.
- Realistic estimate: an Apple-silicon developer who already has rustc 1.92 and Node 24 can run the quickstart in 30 to 60 minutes. A Linux or Windows developer cannot run the documented flow.

## Focus and risk (sprawl)

- Tracked files: 16,261 (172 MiB). `results/`: 10,779 files in 26 top-level folders. `proposals/`: 5,113 files in 65 folders. 9,222 files are `.log`, `.json`, `.txt` or `.out`. There are 77 commits in 25 days.
- Product source: `src/airlock` + `sdk` + `bin/forge-airlock` + `src/silicon_sink` is about 20 files and about 370 KB including PROTOCOL.md. That is roughly 0.1% of files.
- `unsure.md`: 19,958 lines and 617 headed entries (to U840), append-only, and no current-state summary. `ROADMAP.md`: 2,624 lines. It says its own full record lives on branch `backup/forge-local-2026-11-11` "because 160 of its links have no target on `main`". Stage 9 locks are stale (8 entries).
- The work moves through goals, slices, waves, gates, night shifts and apexes faster than earlier records are consolidated. A newcomer cannot tell which artefacts are current.

Top 3 things that most limit adoption or credibility:
1. **Nothing enforces the security story in a deployable form** (D1, D2, D3, claim 1). The guarantees hold only in a deployment that the repo describes but does not ship. Human approval (S1) and branch enforcement are missing.
2. **The proof effort is aimed at the lowest-risk part.** Months of HOL4/Dafny work cover a five-comparison function. The engine that actually holds money state has no proof and no CI, and a known-defective sink stays on `main`.
3. **The repo is an archive with a product hidden in it.** No licence, no packaging, a README without the product, macOS-only for the flagship path, and 99% of files are records.

## Top 3 recommendations

1. **Ship isolation as a product feature, not a paragraph.**
   - Run `serve` as a service account behind a Unix socket or a local TCP endpoint with per-tenant credentials.
   - Install the engine, refund binary, Node and checker into a root- or service-owned prefix, and verify each by descriptor at every exec.
   - Scope keys per tenant. Make cosign keys hardware-backed or held by another user, and test that the agent's user cannot write any pinned path.
   - Add one end-to-end "malicious agent" test that runs as the agent's user against that deployment.
2. **Point formal methods at the engine, and put the engine under CI.**
   - Prove the WAL fold, compare-and-swap, at-most-once and crash recovery (the Formal Ceiling v2 item F2.7 is the right one; do it before more M1 premises). Candidates: a Dafny or TLA+ model of the record grammar and recovery with a differential harness, or Verus or Kani on `store.rs` and `ledger.rs`.
   - Add a Linux and macOS CI job for `tests/airlock` and the SDK suites.
   - Apply the U3 sink fix, or delete the Slice 1 sink from `main`.
   - Add snapshotting so that `open` is not O(N).
3. **Split the product from the archive and fix the front door.**
   - Pick a licence.
   - Rewrite the README around `forge-airlock`: what it stops, a 10-line Python example, and the honest "what is proved" table.
   - Package the SDKs (pyproject and npm) with a prebuilt engine.
   - Move `results/`, most of `proposals/` and the night-shift records into a separate evidence repo or release assets with digests.
   - Add a one-page current-state summary that replaces reading `unsure.md`.
   - Change "PROVED CORE" to a wording that states M1-B is open, and change "independent" to "fresh-context, same model family".
