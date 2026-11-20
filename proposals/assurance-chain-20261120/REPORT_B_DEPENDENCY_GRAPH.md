# Report B: the assurance graph

Nodes:
- N1 HUMAN AUTHORIZATION, N2 FORMAL SPECIFICATION, N2' STATEFUL SPECIFICATION (new; needed by every durable conclusion), N3 MACHINE-CHECKED PROOF, N4 VERIFIED IMPLEMENTATION, N5 VERIFIED COMPILATION, N6 EXACT EXECUTED ARTIFACT, N7 RUNTIME ENFORCEMENT, N8 ACTUAL STATE TRANSITION, N9 DURABLE EFFECT, N10 RECEIPT.
- Arrows: A1 (N1→N2/N2') … A9 (N9→N10).

Lines:
- Line P = the proved refund binary.
- Line R = the Rust engines.
- Line V = the planned recheck verifier (Report D-1).

Levels: [S] source/model; [M] machine code in a model; [RT] runtime.

Rules:
- Status order for "weakest decides": MISSING < INCOMPLETE < ASSUMED < TESTED_ONLY < MACHINE_CHECKED < INDEPENDENTLY_REPLAYED.
- A check by an unproved script is TESTED_ONLY.
- No edge has a clean or independent replay record.
- "Same-machine repro" = `proposals/night-shift-20261119/orch-A/repro/RESULT.json` (head `dae1b93e`; "NOT a clean or independent-machine replay").

| id | source | destination | required invariant | proof (file, theorem) | checker (command / record) | env assumptions | status | remaining work |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1.1 | human intent | `spec/refund/RefundSpec.dfy` text | R1–R5 express the intent | none | human reading; 18 correspondence rows NOT REVIEWED (REVIEW_PACKET s.3) | approver understood R1–R5 | ASSUMED | owner review of the 18 rows, recorded |
| A1.2 | approved revision | gated bytes (refund) | bytes = approved bytes (`90a21c71…`) | none | `gate/refund.py` `APPROVED` (lines 23-28) | trusted base checkout; owner merge | TESTED_ONLY | put refund under `gate/approvals` (`SPEC_PATHS`) |
| A1.3 | approved ledger spec | gated bytes | old/new hashes + proposal hash | none | `gate/approval.py`, `gate/approvals/fees-v2.json`; hosted refusal run | as A1.2 | TESTED_ONLY | — |
| A1.4 | approval | approver identity | the "yes" came from the owner | none | none ("yes" is conversation text) | | MISSING | signed approval over the spec hash |
| A1.5 | owner intent | stateful spec N2' (`StoredCharge`, `ContextAt`, commit step, at-most-once, `refundEnabled` at genesis, meaning of the 64-byte record) | the stored-state rules are the owner's | none | draft `proofs/sink-core/SPEC_STATE_PROPOSAL_U8.txt` ("NOT approved"); `DESIGN.md:281` "NEW intent" | — | MISSING | owner approval; spec-lock rebind is a separate protected change (U8 text lines 2-4) |
| A1.6 | approved spec constants (`AllowedReason`, `MaxMoney`; `RefundSpec.dfy:3,24`) | engine constants (`sink.rs:24-25`; `policy.rs:9`) | equal sets and bound | none | `test_silicon_crash.py:274` (each reason), `:294` (suffix refused); conformance vectors | — | TESTED_ONLY | a check that derives the constants from the spec file, or V1 checks them per record |
| A1.7 | approved intent | airlock choice of the canonical profile (`m.canonical`, `verbs.rs:168`; a policy registered in the WAL) | refunds that must use the proved binary do | none | none | operator registers the right policy | MISSING | bind the profile to approved intent; non-canonical refunds go through the unproved `eval_money` (`policy.rs:160`) |
| A2.1 | RefundSpec | spec quality | Post deterministic, not vacuous | `clearing/RefundExact.dfy` `PostIsExact`, `AcceptsAndRejects` [S] | Dafny 4.11.0, Slice 2 bundle `2721a293…` | Dafny/Z3 sound | MACHINE_CHECKED | clean replay |
| A2.2 | LedgerSpec; BookingSpec | `impl/Ledger.dfy`; `impl/Booking.dfy` | C1–C5; B1–B4 [S] | Stage 1 obligations | hosted run 41516908347 (U225, `unsure.md:5615`): prose record, evidence folder untracked, overall CI FAILURE, reuse not excluded. Booking ran on candidate `46e5aa42`, not on `main`'s bytes (one line differs) | Dafny/Z3 | MACHINE_CHECKED (ledger); booking: candidate only | commit the job log hash; re-run on `main` from a clean runner |
| A3.1 | RefundSpec | `impl/Refund.dfy` | refinement [S] | `module Refund refines RefundSpec` | `gate/refund.py`, Stage 8 | `expect` = partial correctness | MACHINE_CHECKED | clean replay |
| A3.2 | `AssessFlat` contract | RefundSpec R1–R5 | three ensures ⇒ R1–R5 [S] | `LinkedRefund refines RefundSpec` | run2 log exit 0 | `@Axiom CharsConsistent` in the closure | MACHINE_CHECKED | drop the HexConversion module; replay |
| A3.3 | `FlatPlain` | `AssessFlat` contract | equivalence on `Codes` [S] | `HolLink.dfy` D1–D3, `HolSlice.dfy` D4 | `check_link.py` exit 0 | | MACHINE_CHECKED | replay |
| A3.4 | HOL `flat_plain` | Dafny `FlatPlain` text | same meaning | none (printer `dafny_of_term`) | pin + text compare; 32 controls | BETA-PLAIN, 4 parts | ASSUMED | in-HOL semantics of the 10-constructor fragment, or a verified printer |
| A3.5 | `refund_fields` | `flat_plain` | equivalence [S] | FC1 `refund_fields_flat_plain` | Holmake runs 0001/0002, same machine | HOL kernel | MACHINE_CHECKED | clean replay (needs M1-R) |
| A3.6 | any spec | Rust engine logic (`sink.rs` `scan`/`commit`; airlock `verbs.rs`, `policy.rs`) | engine implements the spec | none | suites, mutants | | MISSING | prevention: D-2 (WAL model + H_WAL); detection: not needed (D-1) |
| A3.7 | finality protocol model | its invariant | `InvMeaning` under A1–A4 [S, model] | `FinalityProtocol.dfy:231-274` | `records/summary-attempt-0002.json` | A1 ideal MAC, A2 sound minter, A3 atomic commit, A4 faithful state | MACHINE_CHECKED | instantiate for the silicon sink (Report D-2, M-i) |
| A3.8 | approved `Eligible` + U8-style state | a fold audit over stored rows | audit accepts ⇒ every row authorized on the replayed state; money conserved | `ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial` (`impl/finality-core/ShellCoreV5.dfy:317`), `AuditV5CompleteForHonestCommits` (:452) [S] | `dafny-proofs.tsv` row 36: 156 verified, exit 0, pinned Dafny 4.11.0, same machine | supplied initial charge; A-DB2 | MACHINE_CHECKED (TS token sink rows; not the silicon WAL) | reuse for V1 (Report F) |
| A4.1 | `refund_fields` | ARMv8 `code` | `code` computes `refund_fields` [M, model] | `forge_refundWholeProg` … `forge_refundArm8Compile`, `compile_correct'` | replay M1R-1, 2026-11-18, same machine; 10 ARMv8-step cases in direct mode, without the tool identity check (4 of 15 tool files differ) | CakeML proofs, HOL kernel | MACHINE_CHECKED | M1-R (Report F, second task) |
| A4.2 | sources + tools | the same theories, rebuilt | reproducible | none | `refund.S` byte-equal on replay; nothing from a clone | one machine, untracked tool tree, 34 untracked parent folders | INCOMPLETE | M1-R, starting with an inventory |
| A4.3 | `refund.S` + `basis_ffi.c` | Mach-O `b8ed5ec2…` | link keeps the code bytes | none | never rebuilt (A1 F12) | `as`, `ld`, clang | ASSUMED | rebuild twice, compare |
| A4.4 | `impl/Refund.dfy` | JS | semantics preserved | none | Dafny compiler | Dafny JS backend, Node | ASSUMED | keep as a named assumption |
| A4.5 | Rust source | engine binaries | binary = `rustc` output of the recorded source | none | no binary hash recorded. The silicon EXIT script refuses rustc ≠ 1.92.0 (`exit_silicon_sink.py:49,213-215`). Hosted CI uses the runner's rustc 1.100.0/1.99.1 with no pin (`airlock-ci.yml:34`). `pins.json` has no rustc | `rustc` | MISSING | reproducible build with a recorded hash |
| A5.1 | file `b8ed5ec2…` | HOL `refund_file`, `code` | code slice equal [M] | `refund_file_code`, `refund_file_bitmaps` (HOL constant ↔ code) | image-0001; replay row 42 | the file ↔ HOL constant step is the ML `BinIO` read plus `extract_macho.py` (H_READ) | ASSUMED (the HOL part is MACHINE_CHECKED from the read) | hash the byte literal in the `forge_refundImage` `.dat` (on the backup branch only) and compare with `b8ed5ec2…`; a second extractor |
| A5.2 | built file | file exec'd by the airlock | exec'd bytes hash to `b8ed5ec2…` | none | `helpers.rs:41,157-162`; tests `pin`, `pin_window` | no root/same-uid swap between hash and exec | TESTED_ONLY | read-only copy under another uid |
| A5.3 | built file | file exec'd by the silicon sink | same | none | none (`sink.rs:14`) | the caller passes the right path | MISSING | pin as in `helpers.rs` |
| A5.4 | engine binary | what runs | identity of the checker | none | none | launcher choice | MISSING | hash in genesis/receipts; H0/H1 for evidence |
| A6.1 | file on disk | process memory, entry state | `refund_image_mem sl m`, slots, EL0, PC [RT] | none | none | `dyld`, XNU, C runtime | ASSUMED (premise) | ML-10 model part; name the rest |
| A6.2 | real register state | erased state | TBI0=TBI1=SA0=E0E=F behaviour-equal | step lemmas E1-0003, EF-0001, EE-0001 (same-machine repro) | apex2 README s.6 | kernel defaults set TBI0/SA0 (source reading) | INCOMPLETE | ML-08, ML-09 run lift |
| A6.3 | real CPU step | `NextStateARM8` step | ISA fidelity [RT] | none possible for Apple silicon | none | HW-1, HW-3, HW-9, HW-10 | ASSUMED (P6) | only H2 on an FPGA core |
| A6.4 | `basis_ffi.c` + kernel | FFI oracle | `refund_ffi_contract_on`; `ffi_calls_ok` | L1–L2d trade the all-states premise; no witness `envmc` | review-L2d: none exists for the present C | | ASSUMED ("probably false") | fix the C, build a witness, or sign the assumption |
| A6.5 | native process | `machine_sem`/`basis_ffi` | refinement (X8) [RT] | none; no HOL statement | 2,466 vectors | kernel, silicon | MISSING (tests only) | one owner-signed assumption text |
| A6.6 | `code` in the L3 model | fd-1 bytes | Success ⇒ render; Resource ⇒ prefix [M, model] | LO-0006 `refund_profile_a_sl_fd1`; MF-0002 `refund_model_frame_meets_exported_contract`; R1 | first runs + same-machine repro (LO, MF); RA-FLAT-0001/0002 (R1) | 11–12 premises | MACHINE_CHECKED (conditional) | non-vacuity of the shape form; clean replay |
| A6.7 | engine request | binary stdin | wire = `sexp_to_string (refund_request args)`; flags as the spec defines them | none | conformance: 192 wire inputs. Airlock sends constant `True True True` (`verbs.rs:174`) after its checks. Silicon: flags caller-chosen, spelling only (`sink.rs:133`) | Rust `format!` | TESTED_ONLY (airlock); INCOMPLETE (silicon) | wire lemma M-a (prevention only) |
| A6.8a | binary stdout (model) | frame decision (model) | strict parse of a prefix of a render succeeds only on the full render of the same tuple | PF-0004 `refund_render_fields_prefix_code`, `refund_strict_parse_no_strict_prefix`; PX-0001 `refund_frame_decision`, `refund_strict_parse_exact` (`FINAL_STATEMENTS.txt:1996-2062`) | first run + same-machine repro | HOL kernel | MACHINE_CHECKED | clean replay |
| A6.8b | Rust accept text | HOL render | `frame(a)` (`sink.rs:63`; `verbs.rs:175`) = `refund_render_fields (AcceptTuple a)` | none | exact-frame tests; mutants | Rust `format!` | TESTED_ONLY | a string lemma over the Rust format, or a differential over all field ranges |
| A6.9 | Rust native checks | enforced rule | under the lock: id fresh, CAS, `amount ≤ remaining`, reason ∈ 3 labels (`sink.rs:163-171`; `verbs.rs:72-73,173,177`) [code] | none | suites + mutants | single writer | TESTED_ONLY | prevention: D-2; detection: V1 rechecks the same rule from the log |
| A7.1 | enforced decision | WAL record | one record iff the checks pass; the record encodes q | model: `FinalityProtocol` under A1–A4; code: none | model run; code tests | A3; `flock` | MISSING (model→code) | D-2 M-f, M-i, H_WAL differential |
| A7.2 | engine | sole writer | no other writer | none | advisory `flock`; tests `race`, `lock` | | ASSUMED | uid separation (U894) |
| A8.1 | acked record | after crash | present after SIGKILL | none | 220 kills; interposer faults | | TESTED_ONLY | — |
| A8.2 | acked record | after power loss | present | none | none | `F_FULLFSYNC`, APFS, SSD | ASSUMED | power-loss rig (evidence only) |
| A8.3 | WAL bytes | crash model | any torn prefix recovers to the old or the new state | none | none | | MISSING | D-2 M-g |
| A8.4 | durable WAL | no rollback | used ids never forgotten | none | silicon `rollback`, airlock `ratchet_entry` | no joint restore | TESTED_ONLY (WAL-only restore); MISSING (joint); INCOMPLETE (silicon D7 shape, `sink.rs:114-115`) | V3 anchor; port D7 |
| A8.5 | durable WAL | external effect | at most once, after durability | none | `dispatch` case | provider idempotence | TESTED_ONLY | V4 reconciliation (idempotency key = request id) |
| A9.1 | durable record | receipt line | receipt only after sync | none | ordering tests | | TESTED_ONLY | — |
| A9.2 | receipt | integrity | keyed by a separate principal | none | silicon/airlock/primitives: no key; MCP: same-uid key | | MISSING (silicon, airlock); ASSUMED (MCP trust root) | V2 witness under a second uid |
| A9.3 | receipt | content | binds request, spec hash, decision frame, artifact hashes, store id | none | none | | MISSING | evidence package (V1) |
| A9.4 | receipt | third-party verdict | A2 s.3.3 checks | none | MCP only: `tests/mcp_proxy/verify_independent.py` (chain, signatures; not the spec) | | MISSING (refund) | V1 |
| A9.5 | chain head | outside anchor | rollback/fork visible | none | none | | MISSING | V3 |
| A9.6 | owner | verifier trust root | the verifier gets `pk_W`, the spec hash `90a21c71…` (+ N2' hash), the expected artifact hashes out of band | none | none | | MISSING | a signed trust-root file outside the store |
| A9.7 | requester | record/receipt | who asked, and the human authorization of THIS request, are bound | none | none; the 64-byte record has no requester field (`sink.rs:7-11`); the airlock cosign record stores a flag, not the signature (A2) | | MISSING | requester signature in the evidence package |
| A9.8 | record | time | when the transition happened; freshness | none | none; no time in the record | | MISSING | V3 anchor gives an upper bound only |
| A9.9 | run records (JSON, logs) | evidence | records are authentic outputs of the named runs | none | written by the same agent that ran the step | | ASSUMED | hosted or third-party runs with stored log hashes |
| A9.10 | durable WAL (bytes) | spec verdict | V accepts ⇒ every record is a commit step of N2'; ids once (D-1) | none | none | H_LOG | MISSING | V1 |

## Per-arrow verdicts (the weakest sub-edge decides)
| Arrow | Line P | Line R | Line V (planned) | decided by |
| --- | --- | --- | --- | --- |
| A1 N1→N2/N2' | MISSING | MISSING | MISSING | A1.4, A1.5, A1.7 |
| A2 N2→N3 | MACHINE_CHECKED (refund) | n/a | MISSING (V1 proof) | A2.1 / A9.10 |
| A3 N3→N4 | ASSUMED | MISSING | MISSING | A3.4 / A3.6 / A9.10 |
| A4 N4→N5 | INCOMPLETE | MISSING | (Dafny compiler, ASSUMED once built) | A4.2 / A4.5 |
| A5 N5→N6 | ASSUMED (A5.1); airlock exec TESTED_ONLY; silicon MISSING | MISSING | n/a | A5.1, A5.3, A5.4 |
| A6 N6→N7 | MISSING | INCOMPLETE (silicon) / TESTED_ONLY (airlock) | n/a | A6.5 / A6.7 |
| A7 N7→N8 | — | MISSING | n/a (V reads the result) | A7.1 |
| A8 N8→N9 | — | MISSING | n/a | A8.3 |
| A9 N9→N10 | — | MISSING | MISSING | A9.2–A9.10 |

## Three lines
```
Line P (proved, model):  RefundSpec ==A3.2==> AssessFlat ==A3.3==> FlatPlain(Dafny)
                         ~~A3.4 printer ASSUMED~~> flat_plain(HOL) ==A3.5==> refund_fields
                         ==A4.1==> code ~~A5.1 read ASSUMED~~> file b8ed5ec2 ~~A6.1, A6.5 MISSING~~>
                         L3 run ==A6.6==> fd-1 bytes ==A6.8a==> exact frame decision   [ends at stdout]
                                         |  meeting point: A6.7 wire, A6.8b Rust frame text (TESTED_ONLY)
Line R (unproved):  request -> Rust parse -> [binary] -> under lock: id, CAS, amount, reason (A6.9)
                    -> WAL append (A7.1 MISSING) -> sync_all (A8.1 TESTED / A8.2 ASSUMED)
                    -> COMMITTED line = dispatch (A9.1) -> unkeyed assertion (A9.2 MISSING)
Line V (planned):   WAL bytes (+ ratchet, + dispatch transcript) -> V (Dafny-proved fold against N2')
                    -> verdict (A9.10 MISSING) ; then witness (A9.2), anchor (A9.5), reconciliation (A8.5)
Off-line: FinalityProtocol.dfy (A1–A4); SinkCore / ShellCoreV5 (TS token sink).
```
Line P ends at stdout bytes and has no durable state. Line R makes the durable transition. Its safety for `Eligible` rests on its own native checks (A6.9), not on Line P (Report D-2). Line V does not pass through Line P or through the Rust code. It needs N2' (A1.5) and H_LOG.
