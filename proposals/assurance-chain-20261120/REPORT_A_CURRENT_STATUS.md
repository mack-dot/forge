# Report A: what Forge establishes today

Base `origin/main` `058eabcb`, 2026-11-20. `end_to_end=false`. M1-B OPEN. No proof was replayed for this report. "Re-checked" means that I ran the named command on the base. A1, A2, A3 = Annex 1, 2, 3.

## 1. Implemented
| Component | Where | What it does | Proof link |
| --- | --- | --- | --- |
| CakeML refund binary | `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho` (SHA-256 `b8ed5ec2…7bb8`, 238,776 bytes) | decides one refund request from stdin; writes one frame on fd 1 | Line P |
| Native silicon sink | `src/silicon_sink/sink.rs` (248 lines, SHA-256 `1962af4a…`) | one charge; asks the binary BEFORE it takes the lock (`:192`); then, under `flock`: id fresh, CAS on tail/charge/original/remaining, amount ≤ remaining, reason ∈ 3 labels (`:163-171`); 64-byte record; `sync_all`; ratchet | none (`sink.rs:3` "NOT proved") |
| Airlock engine | `src/airlock/*.rs` (2,283 lines, 9 files; re-checked `wc -l`) | multi-tenant WAL; canonical refund through the same binary under the store lock (`store.rs:142`); money, saga, lease, BOOK, cosign | none (`main.rs:3`) |
| MCP proxy | `src/mcp_proxy/` | policy, ledger, signed evidence chain; independent Python checker `tests/mcp_proxy/verify_independent.py` (chain and signatures, not a spec) | none |
| Primitives v2 | `src/primitives_v2/` | rate windows, ledger/graph guards, taint, Farkas check | Rust: none; `FarkasCert.dfy` is a model |
| Dafny-to-JS paths | `impl/Refund.dfy` via `ts/refund.ts`; BOOK `model.cjs` via Node | decisions in JS | source proofs only; compiler and Node trusted |
| Proof gate | `gate/pr_check.py`, `gate/approval.py`, `gate/refund.py` | hash-bound approval; Dafny obligations on PRs | unproved Python |

## 2. Machine-checked (one machine unless stated; status from committed records)
| Statement | What it says | What it does NOT say |
| --- | --- | --- |
| `forge_refundLOut.refund_profile_a_sl_fd1` (`proposals/night-shift-20261119/orch-A/FINAL_STATEMENTS.txt:2399`) | under 11 premises, the L3 ARMv8 run ends in Success with fd-1 = render of `refund_fields …`, or in Resource_limit_hit with a prefix | real process, loader, `basis_ffi.c`, exit status, resource bound. Premise TBI0=SA0=F is false for the kernels' source defaults (A3) |
| `forge_refundModelFrame.refund_model_frame_meets_exported_contract` (`:2910`) | same premises; a strictly parsed output = `refund_fields …`; the three exported Dafny ensures hold in CakeML's Dafny semantics | same limits |
| PF-0004 `refund_render_fields_prefix_code` (∀f g. render g ≼ render f ⇒ g = f), `refund_strict_parse_no_strict_prefix`, `refund_strict_parse_complete`; PX-0001 `refund_frame_decision`, `refund_strict_parse_exact` (`FINAL_STATEMENTS.txt:1996-2062`) | at model level, the frame decision is exact and prefix-free: a strict parse of a prefix of a render succeeds only on the whole render of the same tuple | that the Rust `frame()` text (`sink.rs:63`, `verbs.rs:175`) equals `refund_render_fields (AcceptTuple a)` (tests only) |
| APEX-2 FC1 `refund_fields_flat_plain`, R1 `refund_route_a_flat_plain_shape` (`proposals/apex2-contract-link-20261119/README.md:61,79`) | FC1: `refund_fields … = (ok,a,r,c,q,n) ⇔ flat_plain (codes …) …`, no premise. R1: shape form, 12 premises | R1 has no Holmake build; `hol/` cannot be built from a clone (README:205-206) |
| `refund_file_code`, `refund_file_bitmaps` (`forge_refundImage`; `.dat` only on branch `backup/forge-local-2026-11-11`, re-checked `git ls-tree`) | the code slice of the HOL constant `refund_file` = compiled `code` | that `refund_file` = the file bytes (ML `BinIO` read and `extract_macho.py`, trusted) |
| CakeML chain `forge_refundWholeProg` … `forge_refundArm8Compile`, `compile_correct'` | ARMv8 bytes implement `refund_fields` in CakeML semantics | sources not on `main` |
| Dafny `LinkedRefund refines RefundSpec` (`proposals/m1b-mission-20261119/proofs/linked-refund/`) | three `AssessFlat` ensures ⇒ R1–R5 | the closure holds `@Axiom CharsConsistent` (`inputs/library/Std/Strings.dfy:185`; run2 log line 16) |
| `HolLink.dfy` D1–D4 | `FlatPlain` on `Codes` ⇔ `AssessFlat` contract | that the Dafny text means the HOL term (printer trusted) |
| `clearing/RefundExact.dfy` `PostIsExact`, `AcceptsAndRejects` (line 25) | Post has one result; it is not vacuous (two witnesses) | that the spec is the intended one |
| `module Refund refines RefundSpec` | source refinement | the JS that runs |
| `FinalityProtocol.dfy` (`8b70b6b4…7484`): `CommitPreservesInv` (231), `InvMeaning` (244), `ForgedTagRejected` (256), `StaleStateRejected` (268), `ReplayRejected` (274); "22 verified" | abstract protocol safety | holds under A1 ideal MAC, A2 sound minter, A3 atomic commit, A4 faithful state (lines 9-13). Line 1: "NOT an approved specification". No disk, crash or fsync; no Rust link. The silicon sink has no tag and no minter |
| `proofs/sink-core/inputs/sink/SinkCore.dfy` (56 verified; `TOP_LEVEL_GRAPH.md:212`) and `impl/finality-core/ShellCoreV5.dfy` (156 verified, exit 0; `proposals/night-shift-20261119/integration/dafny-proofs.tsv` row 36; `ROADMAP.md:603`) | one-charge sink core: ids once, remaining ≥ 0, sum of refunds ≤ original. `AuditV5SoundRelativeToSuppliedInitial` (`ShellCoreV5.dfy:317`): a streaming audit that re-evaluates the approved `Eligible` on the replayed state | about the TS token sink's rows, not the silicon WAL; drafts; "NOT gate evidence"; relative to a supplied initial charge; whole-database rollback not detectable (`ShellCoreV5.dfy:12-13`) |
| `impl/Ledger.dfy` vs `spec/LedgerSpec.dfy` C1–C5; booking B1–B4 | ledger and booking source proofs | off the refund chain; no durable engine runs them |

HOL tags (re-checked):
- 56 tracked `.dat` files. Each stored theorem's oracle field is exactly `DISK_THM`: 874 + 140 entries, matched by a regex on the field `)) "…")`. 0 files contain `MK_THM` or `cheat`.
- The scripts' own check (`…/final-cases/e4-0001.sml:17-19`) refuses any oracle other than `DISK_THM` and any axiom. I did not confirm the meaning of `DISK_THM` against the pinned HOL source.
- A literal grep for "oracle" hits 32 files. Those hits are the FFI type `oracle_result`, not tags.

## 3. Tested but not proven
- Binary vs Dafny spec: Wave Gate 1, 2,466 typed vectors, 192 wire inputs, 0 findings (`proposals/forge2-m1-conformance/REPORT.md:66`).
- Silicon sink: 13 cases, 220 kills, 49/49 changed copies killed. The record pins `sink.rs` `1962af4a…` (= `main`). Its own format transcription and a reference rule (`tests/silicon_sink/test_silicon_crash.py:42,346-348`) are "a third opinion", not a proof.
- Airlock: 33 cases, 114 killed, 3 survivors; the record is stale (section 5).
- MCP proxy, primitives v2: counts appear in ROADMAP/unsure text only; no JSON record pins their source (A2 F8).
- Hosted airlock-ci 44692795822 / 44693275108: 121 PASS on GitHub-hosted `macos-15` (`airlock-ci.yml:76`) with the runner's rustc 1.100.0 / 1.99.1 (`ROADMAP.md:80-82`). No rustc version is enforced in CI (`airlock-ci.yml:34`; `toolchain/pins.json` has no rustc). The local silicon EXIT script refuses any rustc other than `rustc 1.92.0 (ded5c06cf 2025-12-08)` (`scripts/exit_silicon_sink.py:49,213-215`).
- TS token sink against the compiled Dafny core: 4,000 + 1,500 sequences, 0 divergences (`proposals/m1b-mission-20261119/TRACKER.md:103`, worker run, not re-run).

## 4. Depends on assumptions
- Binary and its model: loader and entry state (`refund_entry_pre_sl`); FFI contract (`refund_env_ok_sl`, "probably false for the real C code", U393/U409); X8 native ⊆ `machine_sem` (no HOL statement); L3 = silicon (P6, CPU part only).
- Translations and tools: HOL-to-Dafny printer (BETA-PLAIN); ML reader and `extract_macho.py`; Dafny/Z3 soundness; Dafny JS compiler and Node; `rustc`.
- Storage and process: `F_FULLFSYNC` and the drive (`evidence.json` `os_kernel_assumption`); advisory `flock`; no joint restore of WAL and ratchet (`sink.rs:15`); same-uid MCP key custody (A2 F9).
- Records: the run records (JSON, logs) are written by the same agent that ran the step. Their authenticity is assumed.

## 5. Incomplete
- M1-B OPEN. The run lift ML-08/ML-09 for TBI0/SA0 is MISSING.
- Reproducibility:
  - The phase-1 M1 sources and the tool tree are not on `main`. No `forge_refundArm8Compile` script is tracked; the replay log runs Holmake in an untracked `.toolchain` tree.
  - Pins exist only in drafts (`drafts/CLEAN_REPLAY_PLAN.md:33-35`, which measured 0 of 259 restore files on `main` and 259 of 259 on the backup branch).
  - The top layer (LOut, ModelFrame, RouteAFlat, FlatContract) is in no restore list and in neither replay plan (0 grep hits in `plan*.json`/`summary*.json`).
  - Its case scripts are tracked (for example `hol-runs/routeA-attempt-0001/LO-0006.sml`, `apex2-contract-link-20261119/hol/forge_refundFlatContractScript.sml`). Its parents are not: RA-FLAT-0002's `command.json` names 34 `results/…` folders (my regex count), and none is tracked.
- 71-theory same-machine replay (2026-11-18): 4 of 15 recorded ARMv8 tool files differ after the tool rebuild. 10 cases ran in "direct mode" without the identity check (`records/arm8-tool-identity.json` note; `summary.json` notes).
- Mach-O step (`as`, `ld`, clang `basis_ffi.c`): never rebuilt (A1 F12).
- Goal 20 record: 64 pinned files; 19 differ and 1 is missing (`src/airlock/node/cosign.cjs`). No bundle pins the merged engine.
- Silicon sink, by reading (re-checked):
  - The flags are caller-chosen; only their spelling is checked (`sink.rs:133`).
  - The binary is never hashed (`sink.rs:14`).
  - The ratchet drops bad-CRC entries and takes the max (`sink.rs:114-115`). PR 73 fixed this shape only in the airlock.
  - A well-framed last record that fails the fold's checks is cut silently if no ratchet entry exists for its epoch (`:119-121`). If the entry exists, the sink refuses with EPOCH_REGRESSION (`:118`), a "restored file?" label. Either way the engine never reports a spec violation as one.

## 6. Planned only
- Stateful refund spec: draft `proofs/sink-core/SPEC_STATE_PROPOSAL_U8.txt`, "NOT approved".
- WAL fold F2.7 (`DESIGN.md:261-300`, NOT started).
- Airlock isolation mode (U894, NOT started).
- Clean or independent M1 replay (two drafts).
- Hardware H0–H3 (A3 section 5).

## 7. Independently reproducible
| Item | Second-run record | Verdict |
| --- | --- | --- |
| phase-1 and phase-2 M1 theories (71 + 24) | same machine, same pins, stored parents; "not a clean-room replay and not an independent replay" (`m1-chain-replay-20261118/REPORT.md:6`) | NOT independently replayed |
| LO-0006, MF-0002, PF-0004, PX-0001 | same-machine reproduction from the branch on stored older parents (`orch-A/repro/RESULT.json`, head `dae1b93e`) | NOT independently replayed |
| FC1, R1 | two same-machine runs each (Holmake 0001/0002; RA-FLAT-0001/0002) | NOT independently replayed |
| refund-line Dafny statements | scratch clones U765/U863 rebuilt bundles; "every HOL, Holmake and Dafny verify step" NOT RUN | NOT independently replayed |
| ledger C1–C5 | hosted Linux run 41516908347 (U225, `unsure.md:5615`). Ledger files unchanged since `f9eb1cbc`. The evidence folder `results/ops-readiness/…` is not tracked. The overall CI concluded FAILURE. The receipt was "recovered from … job-log chunks". In-run reuse is not excluded (`gate/incremental.py:118`) | MACHINE_CHECKED (hosted); the record does not support INDEPENDENTLY_REPLAYED |
| booking B1–B4 | same run, `reused=false`, but on candidate `46e5aa42`. That commit is not an ancestor of `main`, and `impl/Booking.dfy` differs from it by one line (`<=` vs `<`) (re-checked `git merge-base`, `git diff`) | applies to the candidate only; for `main`'s bytes I could not establish a replay |
| evidence bundles | U765, U863 | reproduce records, not proofs |
| Rust tests | hosted airlock-ci | TESTED_ONLY |

No refund-chain statement and no HOL theorem has a clean or independent replay record.

## 8. Counts: reported vs found
| Reported | Found (re-checked) | Method / note |
| --- | --- | --- |
| 1,223 `.dfy` | 1,223 files, 376 distinct | SHA-256 of contents; `RefundSpec.dfy` has 51 copies |
| 524 `.sml` | 524 files; 56 `*Theory.sml` (generated); 229 distinct overall; 194 distinct among non-`*Theory.sml`; 245 distinct basenames | SHA-256 of contents |
| `*Script.sml` | 10 files, 5 names, 6 distinct contents | `git ls-files`, SHA-256 |
| "71 of 71" | consistent; same machine; 10 rows in direct mode | `summary.json` |
| "95 theories" | 71 + 24 | same machine |
| "45-link graph" | 47 distinct ids | 3 links split (line 202) |
| "74 theorem rows" | rows include re-runs and controls | not distinct theorems |
| "1489" vs "1,486" | the difference is the axiom module | not re-run |
| primitives 97/97 vs 103/103 | two runs (bundles `30494fbc…`, `100476fe…`) | tests, not proofs |
| finality "22 verified" | one run, 2026-11-17 | no replay |
