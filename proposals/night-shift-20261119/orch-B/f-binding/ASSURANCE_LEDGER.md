# Assurance ledger, refund slice (generated; do not edit)

**IDENTITY AND RECORD CONSISTENCY ONLY — no proof was re-run.** Generated 2026-11-19T08:39:00Z from commit `985f5eaf9583` by `make_ledger.py`. Source of truth: `ASSURANCE_LEDGER.json`.

Counts: MACHINE-CHECKED 20, ASSUMPTION 8, TESTED-UNPROVED 9, MISSING 22, CLAIMED, log missing 1, UNKNOWN-TONIGHT 7

## Edges

| Id | Chain | From -> To | Class (claimed) | About | Evidence (log: exit; by) | Closure | Assumptions |
|---|---|---|---|---|---|---|---|
| S1 | S | owner's intent -> approved spec on main (R1-R5) | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| S2 | S | approved RefundSpec.Assess (R1-R5) -> impl/Refund.dfy | MACHINE-CHECKED (MACHINE-CHECKED) | DEPLOYED | `f-records/records/linked-refund/verify-linked-refund.1.log`: 0; worker f-records | 33 files `691547b169e3` | DAFNY-Z3-TCB |
| S3 | S | approved contract (R1-R5, datatypes, Unicode strings) -> flat contract (AssessFlat on UTF-8 bytes) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/linked-refund/verify-linked-refund.1.log`: 0; worker f-records | 33 files `691547b169e3` | DAFNY-Z3-TCB |
| S3a | S | Dafny library in the S3 closure -> no axiom needed | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.log`: 0; worker f-records | 33 files `c6d90bb35bc3` | DAFNY-Z3-TCB |
| S4 | S | flat contract text in Dafny -> exported S-expression (3,621 bytes) | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | EXPORTER-ID |
| S5 | S | exported bytes -> parsed HOL contract (source_decode, source_postconditions, source_full_result, source_compiled_fields) | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `command.json` actual_exit=0; `command.json` actual_exit=0 **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, BETA-DAFNY-HOL |
| S6 | S | exported contract -> HOL functions eligible, refund_fields | MISSING (MISSING) | MODEL | - | - | BETA-DAFNY-HOL |
| S7 | S | Dafny operator meanings -> HOL Dafny semantics | ASSUMPTION (ASSUMPTION) | MODEL | - | - | BETA-DAFNY-HOL |
| S8 | S | wire text -> nine typed fields | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | S8-CANONICAL-WIRE |
| X1 | X | HOL functions -> CakeML code | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `commands.json`; `T05-forge_refundCertifiedProg.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X2 | X | CakeML code -> code bytes | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `C32-source-0006.stdout.log`; `C34-real-0004.stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, CAKEML-CC-SCOPE |
| X3 | X | code bytes in the model at cml_main, 11 premises -> model's output | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `command.json` actual_exit=0; `stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, X5-ENTRY, X6-FFI-ALL-STATES, X11-KERNEL |
| X4 | X | premises of X3 -> satisfiable together | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `command.json` actual_exit=0; `stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X5 | X | entry state of the real process -> premises P1-P6 | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X5-ENTRY, A-LOADER |
| X6 | X | real C FFI code -> premise P7 at all call states | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X6-FFI-ALL-STATES |
| X7 | X | contract at all call states -> contract at reached calls | MISSING (MISSING) | MODEL | - | - | X6-FFI-ALL-STATES |
| X7-L1 | X | refund_ffi_contract_at -> totalised contract (L1) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L1-0001.go.log`: 0; Orchestrator A (reported by Orchestrator A; not re-checked by B) | 3 files `aa4b060c3890` | HOL-TCB |
| X7-L1imp | X | L1 theory -> import check | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.go.log`: 0; Orchestrator A (reported by Orchestrator A; not re-checked by B) | 3 files `7ddd84b20409` | HOL-TCB |
| X7-L2 | X | two machines -> agreement (L2) | MISSING (MACHINE-CHECKED) | MODEL |  **[attempt failed: A go log says exit 1]** | 3 files `38dc2e44c921` | HOL-TCB |
| X8 | X | real process -> model machine | MISSING (MISSING) | DEPLOYED | - | - | A-LOADER, X11-KERNEL |
| X9 | X | model I/O events -> bytes on descriptor 1 | MISSING (MISSING) | MODEL | - | - | - |
| X9-LO | X | model I/O events -> L-OUT attempt | MISSING (MACHINE-CHECKED) | MODEL |  **[attempt failed: A go log says exit 1]** | 3 files `43a4f0b0ce92` | HOL-TCB |
| X10 | X | model halt -> process exit status | MISSING (MISSING) | DEPLOYED | - | - | STRICT-FRAME |
| X11 | X | processor and kernel -> L3 model, interference_ok | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X11-KERNEL |
| X11e | X | real registers (TBI0, SA0 = 1) -> erased model state | MISSING (MISSING) | MODEL | - | - | X5-ENTRY |
| X12 | X | real executable runs -> model's output | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | A-LOADER |
| X13 | X | output bytes -> no strict prefix parses | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | STRICT-FRAME |
| X13-PF | X | output bytes -> prefix lemma attempt | MISSING (MACHINE-CHECKED) | MODEL |  **[attempt failed: A go log says exit 1]** | 3 files `7090cb88fcc2` | HOL-TCB |
| X14 | X | full output -> six fields | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `T06-forge_refundWireProg.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X15 | X | process result -> caller's decision | MISSING (MISSING) | DEPLOYED | - | - | STRICT-FRAME |
| X16 | X | M1 decision -> authorization token | MISSING (MISSING) | DEPLOYED | - | - | - |
| U1 | U | request and candidate transition -> RefundFinality.Check (P1-P4) | MACHINE-CHECKED (MACHINE-CHECKED) | DEPLOYED | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records | 5 files `8cc14980d23f` | DAFNY-Z3-TCB |
| U1c | U | impl/RefundFinality.dfy -> compiled JavaScript core | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | DAFNY-JS |
| U2 | U | Check result -> signed token (minter.ts) | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | A2-ISSUANCE, NODE-RT |
| U3 | U | token -> commit in sink.ts | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | H3a-SER-INJECTIVE, H3b-SINK-REBUILDS, B5-CRYPTO-BOOLEAN, NODE-RT |
| U4 | U | protocol model -> its invariant | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records | 5 files `8cc14980d23f` | A1-IDEALMAC, A2-ISSUANCE, A3-ATOMIC-COMMIT, A4-HASH |
| U5a | U | model -> Dafny sink core (merged shape) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records | 5 files `8cc14980d23f` | A1-IDEALMAC, A2-ISSUANCE, A5-VERIFIER-MATCH |
| U5a-W | U | sink core -> non-vacuity witness | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core-witness/verify-sink-core-witness.1.log`: 0; worker f-records | 5 files `694d49034427` | A1-IDEALMAC |
| U5a-ATTACK | U | IdealMac (A1) -> not realizable | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core-attack/verify-sink-core-attack.1.log`: 0; worker f-records; `smoke/attack.log`: 0; orchestrator B re-run (smoke) | 6 files `56dcd7d19dc8` | - |
| U5b | U | Dafny sink core -> ts/refund-finality/sink.ts | MISSING (MISSING) | DEPLOYED | - | - | - |
| U5r | U | model -> patched Dafny sink core with request-id check (DRAFT, not deployed) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-reqid/logs/v02-reqid-verify.log`: 0; worker d-reqid; `d-reqid/recheck/SinkCoreReqId.log`: 0; orchestrator B re-run; `r-reqid/logs/r01-reqid-verify.log`: 0; reviewer r-reqid | 5 files `a127eb22bc9f` | A5-VERIFIER-MATCH, GOODSTART |
| U5r-CONTRAST | U | merged-shape core -> request-id gap (counterexample) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `d-reqid/logs/v03-contrast-verify.log`: 0; worker d-reqid; `d-reqid/recheck/Contrast.log`: 0; orchestrator B re-run; `r-reqid/logs/r03-contrast-verify.log`: 0; reviewer r-reqid | 7 files `011708f09164` | - |
| U5r-REVIEW | U | patched core -> residual gaps (review) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `r-reqid/logs/r12-attack-verify.log`: 0; reviewer r-reqid | 7 files `3680fe8938e0` | - |
| U5r-JS | U | SinkCoreReqId.dfy -> compiled JS (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-reqid/logs/v04-reqid-build.log`: 0; worker d-reqid | 5 files `a127eb22bc9f` | DAFNY-JS |
| U5c | U | patched core -> core-backed shell step (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-corebacked/logs/v01-shellreqid-verify.log`: 0; worker d-corebacked | 6 files `4686d7dabdcd` | A5-VERIFIER-MATCH, GOODSTART |
| U5c-JS | U | ShellCoreReqId.dfy -> compiled JS used by sink_core_backed.ts (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-corebacked/logs/v03-shellreqid-build.log`: 0; worker d-corebacked | 6 files `4686d7dabdcd` | DAFNY-JS |
| U5c-CONF | U | compiled shell core -> draft sink_core_backed.ts behaviour | TESTED-UNPROVED (TESTED-UNPROVED) | DRAFT | - | - | DAFNY-JS, NODE-RT |
| U6 | U | Ed25519 and key secrecy -> H1 / H1B | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | H1-EUF-CMA, H1B-BYTES |
| U7 | U | commit -> durable committed state | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | A3-ATOMIC-COMMIT, NODE-RT |
| U8 | U | approved spec -> no second authorization | MISSING (MISSING) | DEPLOYED | - | - | - |
| T-V1 | T | slice -> Committed => ApprovedSpec /\ ValidArtifact /\ UniqueAuthorization (model) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/slice-theorem/verify-slice-theorem.1.log`: 0; worker f-records; `recheck-f/slice-theorem.log`: 0; orchestrator B re-run | 37 files `1f69ce69a331` | A1-IDEALMAC, A2-ISSUANCE, A5-VERIFIER-MATCH, A6-ALL-STRINGS, INITOK |
| T-V2 | T | slice -> same target without IdealMac | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-V2-01.log`: 0; worker b-signing; `r-signing/logs/rerun-V2.log`: 0; reviewer r-signing | 38 files `1260626ca6f9` | INITOK, A2-ISSUANCE, A5-VERIFIER-MATCH, H1-EUF-CMA, A6-ALL-STRINGS |
| T-V2B | T | slice -> same target with A6b (byte strings) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-V2OnBytes-01.log`: 0; worker b-signing; `recheck-b/SliceSafetyV2OnBytes.log`: 0; orchestrator B re-run; `r-signing/logs/rerun-V2OnBytes.log`: 0; reviewer r-signing | 39 files `1e56907165fe` | INITOK, A2-ISSUANCE, H1B-BYTES, H3a-SER-INJECTIVE, H3b-SINK-REBUILDS, H3c-VERIFYTAG-IS-BYTES, B5-CRYPTO-BOOLEAN, A6b-BYTES |
| T-TOTAL | T | total verifier reading -> hypotheses consistent without IdealMac | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-Total-01.log`: 0; worker b-signing; `recheck-b/TotalReading.log`: 0; orchestrator B re-run; `r-signing/logs/rerun-Total.log`: 0; reviewer r-signing | 5 files `e8e4ddf1d3e1` | - |
| T-V3 | T | slice -> layered theorem on the patched core with several charges (b-integrate) | MISSING (MACHINE-CHECKED) | DRAFT |  **[worker still running at generation time; no final log; log missing]** | 5 files `049953124384` | GOODSTART, A5-VERIFIER-MATCH |
| V1 | V | HOL constants for code and bitmaps -> two slices of the executable | UNKNOWN-TONIGHT (MACHINE-CHECKED) | DEPLOYED | prior: `C42-image-0001.stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, Q3C-READER |
| V2 | V | rest of the file, dyld, libSystem -> anything | MISSING (MISSING) | DEPLOYED | - | - | A-LOADER |
| V3 | V | final theorem -> 541 ancestor theories by content | TESTED-UNPROVED (TESTED-UNPROVED) | MODEL | - | - | HOL-TCB |
| V4 | V | final statement -> definitions under it | MISSING (MISSING) | MODEL | - | - | HOL-TCB |
| V5 | V | recorded hashes -> independently computed values | MISSING (MISSING) | GOVERNANCE | - | - | - |
| V6 | V | executable -> what is run or deployed | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | A-LOADER, ADMISSION |
| V7 | V | all of the above -> one answer | TESTED-UNPROVED (TESTED-UNPROVED) | GOVERNANCE | - | - | - |
| E1 | E | new code -> gate verdict | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E2 | E | gate verdict -> merge | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E3 | E | change of a protected file -> refusal | CLAIMED, log missing (MACHINE-CHECKED) | GOVERNANCE |  **[no stored log for this run]** | - | ADMISSION |
| E4 | E | checker, prover, deployer -> three trust domains | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E5 | E | merge -> protected state | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |

## Assumptions

| Id | Text | Real-world reading | Realizable | Used by |
|---|---|---|---|---|
| A1-IDEALMAC | IdealMac at each delivery: a tag verifies only if it was minted for exactly that claim, in every state. | No real signature or MAC scheme with a total verifier meets it in every state (U478; Attack.TotalVerifierBreaksIdealMac; TotalReading.NoIdealMac). | no | U4, U5a, U5a-W, T-V1 |
| A2-ISSUANCE | A2_MintOnlyOnCheck: every mint of one of our ids signs CheckedClaim(pre, t) for some pre, t with Authorizes(pre, t). | The issuer (ts/refund-finality/minter.ts) signs only after the compiled RefundFinality.Check returns true. minter.ts is TESTED only. | yes | U2, U4, U5a, T-V1, T-V2, T-V2B |
| A5-VERIFIER-MATCH | A5: the sink's sigOk boolean equals the model's VerifyTag on the delivered token at each delivery. | sink.ts calls Ed25519 verify on exactly the bytes that the model calls the claim. Decomposed into H3a, H3b, H3c, B5. | yes | U5a, U5r, U5c, T-V1, T-V2, T-V3 |
| H1-EUF-CMA | H1_SignatureAuthenticity (claim level, step-local): a delivered token whose tag verifies carries a claim signed earlier. | Ed25519 EUF-CMA AND secrecy of the signing key; holds up to a negligible forgery probability, only while the key is secret. | yes | U6, T-V2 |
| H1B-BYTES | H1B_ByteUnforgeability: byte string and tag that verify were signed earlier (symbolic EUF-CMA at byte level). | Same as H1, stated on bytes; with H3a/H3b/H3c/B5 it gives H1 and A5 (SliceTheoremV2.BytesGiveClaimAuthenticity). | yes | U6, T-V2B |
| H3a-SER-INJECTIVE | H3a: the claim serialization is injective. | ts/refund-finality/encoding.ts is canonical and injective; not proved. | yes | U3, T-V2B |
| H3b-SINK-REBUILDS | H3b: at each delivery the sink rebuilds exactly Ser(ClaimOf(tok)) from the parsed token. | sink.ts rebuilds the signed bytes; not proved. | yes | U3, T-V2B |
| H3c-VERIFYTAG-IS-BYTES | H3c: the model VerifyTag is the byte verifier applied to Ser(claim). | A definition choice of the model; no real-world content beyond H3a and B5. | yes | T-V2B |
| B5-CRYPTO-BOOLEAN | B5: the crypto layer boolean is the byte verifier on the rebuilt bytes. | Node OpenSSL Ed25519 verify returns the mathematical verifier value. | yes | U3, T-V2B |
| A3-ATOMIC-COMMIT | A3: Commit is one atomic, durable step. | One SQLite transaction in node:sqlite. Process crash: TESTED (486 kills, 0 violations, worker run). Power loss: SQLite defaults, no full fsync. | unknown | U4, U7 |
| A4-HASH | A4 faithful state: comparing state hashes equals comparing states. | SHA-256 collision resistance and a canonical state encoding. | yes | U4 |
| A6-ALL-STRINGS | A6: the artifact computes the flat contract on ALL FlatIn inputs (any Unicode chars). | The HOL side gives the flat contract only for byte strings (chars < 256) (Orchestrator A, 08:03Z). Not met by the M1 artifact as stated. | no | T-V1, T-V2 |
| A6b-BYTES | A6b_ArtifactComputesFlatContractOnBytes: the artifact computes the flat contract on byte-string inputs. | The M1 executable on byte inputs computes the exported flat contract. Needs S4, beta, S5, S6, X1 to X10: open. | unknown | T-V2B |
| INITOK | InitOk: the protocol starts in the initial state of the model. | A fresh store. | yes | T-V1, T-V2, T-V2B |
| GOODSTART | GoodStart: the store that the patched core serves satisfies the core invariant at start (fresh, or AuditStart passes). | A start-up audit (AuditStart, executable) runs before the core serves an old store. NoGoodStartDuplicates shows it is necessary. Not deployed. | yes | U5r, U5c, T-V3 |
| BETA-DAFNY-HOL | beta: the Dafny meaning of the exported flat-contract text equals the HOL meaning of the parsed S-expression (8 operators, 3 literals, 4 strings, strings as bytes). | No tool relates the two semantics; a Dafny mirror of the HOL rules agrees (report D12): a proof about a transcription. | unknown | S5, S6, S7 |
| EXPORTER-ID | The 3,621-byte S-expression is the output of the patched Dafny exporter on FlatCore.dfy. | Exporter build of 2026-11-04 no longer on this machine (build folder missing). Identity is a RECORD only: input digest = FlatCore digest; output digest recorded. | unknown | S4 |
| CAKEML-CC-SCOPE | Compiler correctness scope: the compile_correct instance holds with its premises discharged inside the scripts, for the code bytes in the MODEL machine. | Covers CakeML code -> code bytes in the L3 model only; not the C run-time, stubs, GOT binds, dyld (V2). | yes | X2 |
| DAFNY-JS | The Dafny 4.11.0 JavaScript back end compiles the verified Dafny module faithfully (RefundFinality; drafts SinkCoreReqId, ShellCoreReqId). | Slice 1 record: source_to_module_proved=false. Trusted compiler; bignumber.js runtime. | unknown | U1c, U5r-JS, U5c-JS, U5c-CONF |
| DAFNY-Z3-TCB | Dafny 4.11.0 with Boogie and Z3 4.12.1 is sound for the options used. | Trusted base; no proof certificate kernel. | unknown | S2, S3, S3a, U1 |
| HOL-TCB | The HOL4 kernel and Poly/ML are sound; the cached parent theories are the ones named (definitions, not only statements). | Trusted kernel; V4: the import check compares statement text only; parent .dat bytes are hashed (hash_parents) but not checked by HOL. | unknown | S5, X1, X2, X3, X4, X7-L1, X7-L1imp, X7-L2, X9-LO, X13-PF, X14, V1, V3, V4 |
| A-LOADER | Launcher integrity: the process runs the pinned executable with a scrubbed environment and the pinned dyld/libSystem. | DYLD_INSERT_LIBRARIES forges a complete frame (CE-3, Orchestrator A). Needs a controlled launcher; none exists. | yes | X5, X8, X12, V2, V6 |
| STRICT-FRAME | Strict single-frame parse: every consumer or issuer glue accepts exactly one complete result frame; exit status 0 alone is never success. | CE-1: exit 0 with truncated or empty stdout (Orchestrator A). No consumer in the repository (X15 MISSING). | yes | X10, X13, X15 |
| ADMISSION | Admission authority: only owner-approved code reaches main and the deployment. | main is NOT protected (protected:false; rulesets HTTP 403); the session can act as the owner (g-admission). Not met today. | no | S1, V6, E1, E2, E3, E4, E5 |
| X5-ENTRY | Entry state before cml_main satisfies P1 to P6 (owner text Q3a). | arm8_ok wording needs TBI0 = F and SA0 = F; real user space sets both to 1 (D11). False as worded. | no | X3, X5, X11e |
| X6-FFI-ALL-STATES | Premise P7 refund_env_ok_sl: the FFI contract at ALL call states. | Probably FALSE: fficlose with x3 = 0 aborts in basis_ffi.c (U393). | no | X3, X6, X7 |
| X11-KERNEL | The processor and the kernel between steps behave as the L3 model and interference_ok say (owner text Q1). | Trusted hardware and kernel. | unknown | X3, X8, X11 |
| S8-CANONICAL-WIRE | Canonical wire input only (owner Q1, Q5). | The reader accepts 040, +40, "40"; holds only with a strict reader. | unknown | S8 |
| Q3C-READER | The file reader and slice offsets of the executable (V1) outside HOL are correct. | Second extraction by the same model family on the same machine: not independent. | unknown | V1 |
| NODE-RT | Pinned Node 24.3.0 with its OpenSSL and built-in SQLite runs sink.ts, minter.ts and the compiled core as written. | Trusted runtime. | unknown | U2, U3, U5c-CONF, U7 |

## Nodes (250)

| Path | Kind | SHA-256 | Storage |
|---|---|---|---|
| `impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | tracked |
| `impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | tracked |
| `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho` | machine code | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` | tracked |
| `proposals/forge2-m1-conformance/records/evidence.json` | record | `f55391dad17a0a4ea707806c59dbac2419df51c692161704af71f0cfe0a11da9` | tracked |
| `proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | tracked |
| `proposals/forge2-slice1-refund-finality/records/evidence.json` | record | `c7f2f41c872b5c133d422ef881d36e6c09390f081d555d74761d4890283833f1` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | tracked |
| `proposals/m1b-mission-20261119/proofs/linked-refund/review-controls/S3a-remove-hex-module.diff` | proof source | `ec73d8a98d647a00a97d385696e5513dc2d50b3ec07cb5fa47aa7a4fbb06347c` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/inputs/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/inputs/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/inputs/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/inputs/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/inputs/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/review/Attack.dfy` | proof source | `0b660513c7b8342065d06444be6a4a823209c6303affe6587aa83c24ebfb18af` | tracked |
| `proposals/m1b-mission-20261119/proofs/sink-core/review/WitnessCore.dfy` | proof source | `36024a929fd04fd426758c4b276fa649d0e2237a8ee94db2a1653a330b9971d1` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/SliceTheorem.dfy` | proof source | `1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | tracked |
| `proposals/m1b-mission-20261119/proofs/slice-theorem/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/commands.json` | record | `91cc9f86a3a0377337e71b8a7cef53af069de0f4b04e34b4c23b10545732fe59` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/e4-0001/command.json` | record | `23ab7e42a9c332978fe7369d936df795020acac7ed14c9d4d8e1ac2aedcf6612` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/e4-0001/stdout.log` | record | `614dd1726f0a8a3ddf0531e48463301cf9cfac4541c31d514155d9a26e636b19` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/fs-r4-0001/command.json` | record | `d5a57da8cbcd391dd1a3cb801e39ee472f24d0e8cf383f01854e611ff7510845` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/fs-r4-0001/stdout.log` | record | `a0f80999f835cb73fbca59009a97fecefe6dd607f2a2162405439100abad6a46` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/logs/C32-source-0006.stdout.log` | record | `d010446a254a726e3f4b58452aba0abf413bf14b8aefe7b6ed60bcdcc5bb362a` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/logs/C34-real-0004.stdout.log` | record | `f1714179c7db05c0ad2c36cc6daa72d3bca1a5aaa4691744a6cbbadfa9e3dd44` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/logs/C42-image-0001.stdout.log` | record | `3d958f4a4e7ff24fe61f232e5c14a84d9bbe91b4218cc3bdb599aba2c212e185` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/logs/T05-forge_refundCertifiedProg.log` | record | `4f8bd1183ea3566ae85f9e6af347d222b036b1486776cdef21d632c63c357378` | tracked |
| `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/logs/T06-forge_refundWireProg.log` | record | `4a86463e7310b6733dde7f7018db90c27940db864d33795a277b0be03cde8af5` | tracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.go.log` | record | `7bb5e1ad9cb9706253498b6929cb33c519b4cdc848c3e6140ec0321fe0725bb4` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.hashes.json` | record | `d9ad96112a9c07d31c16fc530e82832673b44afeb502d3e24aa64ede6be42b65` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.run.json` | record | `9909dcf421537a66f756ecf529c76bdb7395f3f3b6d72093060fc9bfbcaaa84a` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.sml` | proof source | `9ddf674631a271f7cfd28ddc1d4255bc5146c106a8fe0f32e148e720c5e78830` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.go.log` | record | `b0fbbbdcf323e312527872cb66e0bc7df5d563a649741fe51d236e8a38cb0d94` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.hashes.json` | record | `4b226264dd38fc39e425c9487d08471dd64679ba54580436a7da2afa2fbdbadd` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.run.json` | record | `0b5d6a614014733a3c719230a557334261b9a5899f08b38d6c05ec0d2dc9bd47` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.sml` | proof source | `27a565ac7c7576d2d4af3a15628add426c3cd83cb0b3593f0e166c4686959c29` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0001.go.log` | record | `5d60d564db323b1aee8a4003c5cc21576737cf23d286e5800b40af13f84f56c3` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0001.hashes.json` | record | `f8c7438f2c5b1d16935c6391a4affc64a2775fbeec0af8b0b306944786ee7c30` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0001.run.json` | record | `94e53302173111dad198cc7e80a5ce1a8ee25ee1794c707ffa8aec505327c89d` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0001.sml` | proof source | `4e1c15426d32fdd2bc282654e29c7bf5fdb7e5552c14adcfd9a760198724a88e` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0001.go.log` | record | `ef9b5e53d34bf5b0eb941b193a7cf9a160e8fd6d21ad8780665229cae89c2957` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0001.hashes.json` | record | `582fe84d0dee70c27afe15b0a9bbf4f2fe67c7d7cb9c09059673229b52f7b7be` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0001.run.json` | record | `f007222c57987cc645ab33774254359b1e303d9ebd4f921eec98fdd64af9f66c` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0001.sml` | proof source | `553233ceb0754c9a499d9c992a5b503310d4e9152e1bf7724a8d896190a19a61` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0001.go.log` | record | `171819c52773303ce92a08051a1ef1ed97b5a0485bf26fd2436cfedd6592dcaa` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0001.hashes.json` | record | `4c1fd0134a959e29ff337f569789f438720e9c956da81f6b4a4c9cf9dae8e5f1` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0001.run.json` | record | `9bad983f09e32195d4cdd50fa74018359a7feba0fa98b1e897d8f58283fa52bf` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0001.sml` | proof source | `820de13438581538a9649db0e5d6e18b412c592abe4cb45498171882bb6095e8` | untracked |
| `results/night-shift-20261119/orch-A/STATE.md` | record | `795d6ab8a204f5d65cd77c3f1e08537bd2321f2108477e2cf69ca2705e996c66` | untracked |
| `results/night-shift-20261119/orch-A/review-L1/REPORT.md` | record | `0287ef0b4d5ab102db922f3232396581b16aba6052b38e39a3c4450b6f6d2bed` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/SinkCoreV3.dfy` | proof source | `1a65fab24b9cf3ff248007bdc20a4bb85a48d6840e24f6fd664edfd69065b5e8` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/SliceSafetyV2.dfy` | proof source | `1ed076d134f475c52302012cae532b1714ea204ea6bd668cfb150af93b03fa40` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/SliceSafetyV2OnBytes.dfy` | proof source | `7577af08f35e2e03f512935b0f8e8059f917705d0bfdec7a2e7ed50bede583d1` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/TotalReading.dfy` | proof source | `fcf9edd28c3b9e2b016d06850ec74f280e063204dfbd9e801600fc8aab89e269` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/SliceTheorem.dfy` | proof source | `1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-Total-01.csv` | record | `8796761397b4f9099c927ff4668ebbe56688e5480691bb11e0b09c2701a1a0ca` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-Total-01.log` | record | `700b085477780ba5810dc51ac8d65b9a211e941899e1e24179954d78c25b4eda` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-V2-01.csv` | record | `458b9b16a5e11fd25faa56ad4ed44998b7fbac0f5389a1094fa31efa53a5aec3` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-V2-01.log` | record | `5badd02a3a54dd5550da24f1a5eb05df95d4321a9ca308a9a2b20016546612a9` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-V2OnBytes-01.csv` | record | `2bff573bc7c197401a773fc9b8723a6d193994abbe6d9627e694976494943ae8` | untracked |
| `results/night-shift-20261119/orch-B/b-signing/logs/final-V2OnBytes-01.log` | record | `da83632831f39b285539031d41e8088c0f7a38a7f32e2d0b94096e04508a49da` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-reqid.cjs` | compiler artifact | `d57cabf5dac94ff0cf43038fde67c0908b163bdf9c0bd4727644523fa8d78111` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-reqid.js` | compiler artifact | `cffba74e31371d9dca8f0827ad164bc6275821a5bf8c59c3df37c17bc86455ca` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/sink/ShellCoreReqId.dfy` | proof source | `8bf11860f30adbf124d7829e7f93ba8d18bad4ab5d670b0190f42d05dc8c38b5` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/sink/SinkCoreReqId.dfy` | proof source | `287ffe325854b1df4075fa12da320d8d116fbd0780cd5b168e03c542b904f089` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/dafny/inputs/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/n02-conformance-1.log` | record | `28e363667cb0f70a2279eb3d970c49710c11f4613a03f2d7935beabbfb95b8a8` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/n03-conformance-2.log` | record | `fb316645946d069b40e6c06a0bb747eff51a0de1f9796967c74c81fc31001906` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/v01-shellreqid-verify.csv` | record | `c0e47075134d41d26eac32796db5c0ad341fd0835f3fd99acd9cd51a1d5eda1a` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/v01-shellreqid-verify.log` | record | `7b39cda2e0e644763cc7c71248acf6d8f607ce70cbef82e70d2b1dc352cd3b0d` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/v03-shellreqid-build.csv` | record | `6c3e62043d381b67eeba25a1ddcac3903e814e7923701052773a50dfc6ff1ba4` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/logs/v03-shellreqid-build.log` | record | `ed4e77f18f74d69d729fd17ca48d23423441a2587182f502dadf9307465e7166` | untracked |
| `results/night-shift-20261119/orch-B/d-corebacked/sink_core_backed.ts` | runtime code | `127e1044cb0e4994ebe354be41a51742c5d359c6623057332a987d4b7f39a0c7` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/build/sinkcore-reqid.js` | compiler artifact | `e8770fd83cf304e72ac9076fb6e2cd0b33a268aa8c5c039e5afb3236f3b2ea80` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/sink/Contrast.dfy` | proof source | `52609f5b03c923c65163cb3bd1f116b430dd0129a94b00540b7acc17333886cd` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/sink/SinkCoreReqId.dfy` | proof source | `287ffe325854b1df4075fa12da320d8d116fbd0780cd5b168e03c542b904f089` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v02-reqid-verify.csv` | record | `20ec5a6a2aa72b61790b3abf3cd84bb1959b6ae3681ce8a0aab23abfe5a2edd2` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v02-reqid-verify.log` | record | `1c7341250f2756e10e2b5bf75461b24821d24d356903764e44ea516be709609a` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v03-contrast-verify.csv` | record | `7f3558fb86df8887a30ccaa168613f3392f759350b4b95ae2cbd8062a1c8037e` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v03-contrast-verify.log` | record | `28161b009f370d4319e3105900157157b5114588dabf382a57245f7d1e026617` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v04-reqid-build.csv` | record | `0c97d9b1a1d8899f9260a7b3754e7ba0417db0eb2196a6c6805393e58e1aeb06` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/logs/v04-reqid-build.log` | record | `5068422d3c75365d67176d0c9b5df4c12dd7ae912f630398432fe9774594d6ed` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/recheck/Contrast.log` | record | `bf019cde94ae418328569e05429ce86f6b759257ca579cd50dba254e4b1c3cf0` | untracked |
| `results/night-shift-20261119/orch-B/d-reqid/recheck/SinkCoreReqId.log` | record | `dfea1b64ab081796e19ec448d142cb422297b6c246bd3729f76d7f70427ef436` | untracked |
| `results/night-shift-20261119/orch-B/f-records/PROOF_RECORDS.json` | record | `1ee7c90fffbb1a4bdc4158f61cfe2b81514cb9ff14cb1c75623317a82d2dff4d` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.csv` | record | `bc63bd40fa4df1c992644b24437c744e228bd55e1ba3f04c9ba84e76a4d3b080` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.log` | record | `0b401f0a1b1674d5d3242abd210854825c1657a48178153c16dc01ddffb7e10f` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/linked-refund/verify-linked-refund.1.csv` | record | `5ef1ac0d26db22faa397d185c831f0a4f8cb896c18a5588dbc30a89593966de2` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/linked-refund/verify-linked-refund.1.log` | record | `d1b09700a68e3d2f2f587233b6b67d539d3b2c9b9f6bdd31f27dbe4fd472f06d` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core-attack/verify-sink-core-attack.1.csv` | record | `b31c211542ae53f6a7d78fadd0594e9b1d7cfe1ea8a6369ba3ab10d3bda0e59b` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core-attack/verify-sink-core-attack.1.log` | record | `d70aae03afb9d77347e4b250b0c8cdece1e8331bfd0556037d513c026582fba0` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core-witness/verify-sink-core-witness.1.csv` | record | `b14181c15d2339d80c37af39b43dd41a7bd26050644f5d4302dd1483e3aa72dc` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core-witness/verify-sink-core-witness.1.log` | record | `7e0435ef8bf84a7f9f3442d950c50d96684a6674b4fac9438e58a44c356b57b7` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core/verify-sink-core.2.csv` | record | `bb5ecd2ba516f04536144291957d067291361bd4515175835c2090c82167edd1` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/sink-core/verify-sink-core.2.log` | record | `7c029d10bebf7a32852b828108f2657209f4d197005f0afbdcb0e419b6391996` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/slice-theorem/verify-slice-theorem.1.csv` | record | `1ca5a63109085e1747ae82be479dcc2f8ed842a28f1504ed3b1a7474274888b0` | untracked |
| `results/night-shift-20261119/orch-B/f-records/records/slice-theorem/verify-slice-theorem.1.log` | record | `5a61d07a5675410d3822bb30fc1e359c1e64d20597b23f19f31d2a9798ac0446` | untracked |
| `results/night-shift-20261119/orch-B/f-records/reproduce_dafny_proofs.py` | tool | `93f1e2192daf8b6c8363c525670f99e027cc963b34a1b587f4832fb65840e0ec` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/sink/Attack.dfy` | proof source | `081c7abc0d7c16dac14734eb9d4508a7d794b16ebfa8780b6fc90ed364844b1d` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/sink/SinkCoreReqId.dfy` | proof source | `287ffe325854b1df4075fa12da320d8d116fbd0780cd5b168e03c542b904f089` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r01-reqid-verify.csv` | record | `c558da4dc0410cd4a01303b9c25ce9497249803edff6cb922b413abe9f7fc644` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r01-reqid-verify.log` | record | `b858b8bbcb957c85b68741567a4ba394da213f1640dd25cba766afe0f3f3e7a2` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r03-contrast-verify.csv` | record | `4b32114305bbaa6e3bfce2289438eea6f85a07be355ee1757da2adc8f8a428d9` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r03-contrast-verify.log` | record | `4cfaa462ee8e4c8136f267458f1a61f051bdf3485273b4e507befdd6ce14f2a6` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r12-attack-verify.csv` | record | `f93b13a8b8b53702bcdd660972112851614506be1b8f7c00d88c9e774e291648` | untracked |
| `results/night-shift-20261119/orch-B/r-reqid/logs/r12-attack-verify.log` | record | `a096ea424d12a46d4bfa2e0d8e4e4810cf2a9cb4f6645023896aa08d1e0c5221` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-Total.csv` | record | `fb5aff78eda1722948ebe5a91950f309fdb81ce521110976614dd6ef8fbbb185` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-Total.log` | record | `ee2c4fbb11ede995563fa9bc049f0170d72844312be649d21182874165bfafd4` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-V2.csv` | record | `2b9584620e2212d474358ee8a964c70afbb1bf5f64212271bd98cb2c59f941e2` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-V2.log` | record | `bec3f7b8227d68cf41d684bcf3f264fc0cf083d7d0d52e88b689c2aabf678130` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-V2OnBytes.csv` | record | `600cbc3110802e9c6a70d637694009da8c002d499d99824ad0345b6e24232379` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/logs/rerun-V2OnBytes.log` | record | `d136715fa628f3995addc997385529d31dfaf7bb3f78ec2796bbf3227f0531fe` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/SliceSafetyV2OnBytes.csv` | record | `8694f3eecfa796892e35f2b3baffd28f093483c493ca1cd3ac4886284ad438df` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/SliceSafetyV2OnBytes.log` | record | `06b353463fa9bb648eea8a8811327cd122bbf729584f64b1706c79e000c4cb94` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/TotalReading.log` | record | `402d454b2df328c2c2202cd8caca56434bd27bf8aa0ad1a07d7fc75346621614` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/slice-theorem.log` | record | `239a28b57b9a3e0dafbf3fd1e00cbadc822f0fdab0e6650820bb1e9eca06de94` | untracked |
| `results/night-shift-20261119/orch-B/smoke/attack.log` | record | `213f813c594095f7c153399390aa556826c4ab4beadbdbbc4c4f1f0bcf95f102` | untracked |
| `results/night-shift-20261119/orch-B/tools/dafny_locked.sh` | proof source | `29960e08892071cdde9870bbeb209f8d9e70430a425a24f26d56e32cba6da9b9` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/bridge-0001/command.json` | record | `71881cdca9468e0c5f8729fb0a719f0d3cad72fd0f4f0dcb565c46dbd163a5e2` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/command.json` | record | `138aad5aacfdd0ed344f9282804e00470cf04eef4dee61a7e60587fb2f73c702` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/input.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/output.sexp` | exported contract | `58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/hol-0004/command.json` | record | `f9a364eaeb4c8a2dd15649f5b78f6eba7068a897f6c01ea8853c5832582874e8` | untracked |
| `spec.lock` | approved spec | `32cf117f5bcaec2fb0c072650ceb9b535576ab409579a56c00979ed151b03b69` | tracked |
| `spec/refund/RefundSpec.dfy` | approved spec | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | tracked |
| `spec/refund/protocol.md` | approved spec | `5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4` | tracked |
| `spec/refund/spec.lock` | approved spec | `8b131ab82d3d5bb8f284086e207fa4207c3599ffcae887aa70b13d225ce9375b` | tracked |
| `ts/refund-finality/dispatcher.ts` | runtime code | `5511cf68ba595da535324d1170dcec59d2ce368bb3efdd0470f3f6e0924ee605` | tracked |
| `ts/refund-finality/encoding.ts` | runtime code | `f96086b1838163e371b08fb3fd522e23b4def6b7d9c50fefce57c030b70526e7` | tracked |
| `ts/refund-finality/minter.ts` | runtime code | `714824d83fd660b4fa69d3bc8993a5b08cf79b396507cb026ce6563ef887e1df` | tracked |
| `ts/refund-finality/sink.ts` | runtime code | `0690a4269a38f49a9b053ab9a97a55d917b4a3758f39cbecd2edf91a78484de7` | tracked |
