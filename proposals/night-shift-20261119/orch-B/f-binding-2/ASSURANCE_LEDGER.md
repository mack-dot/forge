# Assurance ledger, refund slice (generated; do not edit)

**IDENTITY AND RECORD CONSISTENCY ONLY — no proof was re-run.** Generated 2026-11-19T09:40:08Z from commit `985f5eaf9583` by `make_ledger.py`. Source of truth: `ASSURANCE_LEDGER.json`.

Counts: MACHINE-CHECKED 50, ASSUMPTION 9, TESTED-UNPROVED 13, MISSING 18, CLAIMED, log missing 1, UNKNOWN-TONIGHT 6

## Edges

| Id | Chain | From -> To | Class (claimed) | About | Evidence (log: exit; by) | Closure | Assumptions |
|---|---|---|---|---|---|---|---|
| S1 | S | owner's intent -> approved spec on main (R1-R5) | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| S2 | S | approved RefundSpec.Assess (R1-R5) -> impl/Refund.dfy | MACHINE-CHECKED (MACHINE-CHECKED) | DEPLOYED | `f-records/records/linked-refund/verify-linked-refund.1.log`: 0; worker f-records; `recheck-f/rerun/records/linked-refund/verify-linked-refund.1.log`: 0; orchestrator B re-run (check_records --rerun) | 33 files `691547b169e3` | DAFNY-Z3-TCB |
| S3 | S | approved contract (R1-R5, datatypes, Unicode strings) -> flat contract (AssessFlat on UTF-8 bytes) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/linked-refund/verify-linked-refund.1.log`: 0; worker f-records; `recheck-f/rerun/records/linked-refund/verify-linked-refund.1.log`: 0; orchestrator B re-run (check_records --rerun) | 33 files `691547b169e3` | DAFNY-Z3-TCB |
| S3a | S | Dafny library in the S3 closure -> no axiom needed | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.log`: 0; worker f-records; `recheck-f/rerun/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.log`: 0; orchestrator B re-run (check_records --rerun) | 33 files `c6d90bb35bc3` | DAFNY-Z3-TCB |
| S4 | S | flat contract text in Dafny -> exported S-expression (3,621 bytes) | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `input.dfy`, `output.sexp`, `command.json` | - | EXPORTER-ID |
| S5 | S | exported bytes -> parsed HOL contract (source_decode, source_signature, source_full_result, source_postconditions, mapped_operators) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/R1.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 2 files `f19fa4ba25d2` | HOL-TCB, BETA-OPS |
| S5-REL | S | parsed HOL contract -> source model result relation | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/R2.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 2 files `638e27ddda7b` | HOL-TCB |
| S5-BR | S | parsed HOL contract -> compiled fields (refund_fields) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/R3.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 2 files `ce2ca6340243` | HOL-TCB |
| S5-IMP | S | U294 theory -> import check (7 statements EXACT, 0 hypotheses, 0 tagged axioms) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/I1.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 2 files `8257a7ac289b` | HOL-TCB |
| S6 | S | exported contract (3,621 bytes, 58154ddf...) -> HOL function refund_fields (exported_contract_exact, exported_contract_on_refund_fields) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/H1.go.log`: 0; Orchestrator A (A ran it; B read the log and run record); `orch-A/link/run/attempt-0001/H2.go.log`: 0; Orchestrator A (A ran it; B read the log and run record); controls NC1=1, NC2=1, NC3=1, NC4=1, NC5=1, NC6=1, NS1=1, NS2=1, NS3=1, NB1=1, PC1=0 | 2 files `6fa55ba77d0e` | HOL-TCB, BETA-VALUES, BETA-OPS, BETA-ORDER |
| S6-ELIG | S | exported contract -> HOL eligible guard (eligible_link_guard_value) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/E0.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 2 files `84f62a870070` | HOL-TCB |
| S6-RENDER | S | exported contract -> rendered output (exported_contract_on_rendered_output) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `orch-A/link/run/attempt-0001/H4.go.log`: 0; Orchestrator A (A ran it; B read the log and run record); controls NR1=1 | 2 files `4dc28905a510` | HOL-TCB |
| S7 | S | Dafny operator meanings -> HOL Dafny semantics | ASSUMPTION (ASSUMPTION) | MODEL | evidence: `BRIDGE_STATEMENT.md` | - | BETA-VALUES, BETA-OPS, BETA-ORDER |
| S8 | S | wire text -> nine typed fields | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | S8-CANONICAL-WIRE |
| X1 | X | HOL functions -> CakeML code | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `commands.json`; `T05-forge_refundCertifiedProg.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X2 | X | CakeML code -> code bytes | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `C32-source-0006.stdout.log`; `C34-real-0004.stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, CAKEML-CC-SCOPE |
| X3 | X | code bytes in the model at cml_main, 11 premises -> model's output | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `command.json` actual_exit=0; `stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, X5-ENTRY, X6-FFI-ALL-STATES, X11-KERNEL |
| X4 | X | premises of X3 -> satisfiable together | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `command.json` actual_exit=0; `stdout.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X5 | X | entry state of the real process -> premises P1-P6 | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X5-ENTRY, A-LOADER |
| X6 | X | real C FFI code -> premise P7 at all call states | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X6-FFI-ALL-STATES |
| X7 | X | contract at all call states -> contract at reached calls | MISSING (MISSING) | MODEL | - | - | X6-FFI-ALL-STATES |
| X7-L1 | X | refund_ffi_contract_at -> totalised contract (L1) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L1-0001.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `aa4b060c3890` | HOL-TCB |
| X7-L1imp | X | L1 theory -> import check | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `7ddd84b20409` | HOL-TCB |
| X7-L2 | X | two machines -> agreement (L2) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L2-0003.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `aa303786a599` | HOL-TCB |
| X7-L2b | X | close predicate -> third premise of L2R for close (L2b) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/L2b-0003.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `ecd7a417e59a` | HOL-TCB |
| X8 | X | real process -> model machine | MISSING (MISSING) | DEPLOYED | - | - | A-LOADER, X11-KERNEL |
| X9 | X | model I/O events -> bytes on descriptor 1 | MISSING (MISSING) | MODEL | - | - | - |
| X9-LO | X | model I/O events -> L-OUT attempt | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/LO-0006.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `1826f1ba8924` | HOL-TCB, X5-ENTRY, X6-FFI-ALL-STATES, X11-KERNEL |
| X10 | X | model halt -> process exit status | MISSING (MISSING) | DEPLOYED | - | - | STRICT-FRAME |
| X10-LE | X | model halt -> halt lemmas (L-EXIT, generic halt) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/LE-0004.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `55135c0c093e` | HOL-TCB |
| X11 | X | processor and kernel -> L3 model, interference_ok | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | X11-KERNEL |
| X11e | X | real registers (TBI0, SA0 = 1) -> erased model state | MISSING (MISSING) | MODEL | - | - | X5-ENTRY |
| X11e-E1 | X | single functions on real register values -> erased model (E1 lemmas) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/E1-0003.go.log`: 0; Orchestrator A (A ran it; B read the log and run record); controls E1neg-0001=1 | 3 files `9fa54743439c` | HOL-TCB |
| X11e-ES | X | erased single functions -> one erased machine step (step lift) | MISSING (MACHINE-CHECKED) | MODEL | not counted: `ES-0002.go.log`: 1 **[attempt failed: go exit 1]** | 3 files `cc663bc9f83a` | HOL-TCB |
| X12 | X | real executable runs -> model's output | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `evidence.json`, `refund-arm64-macho` | - | A-LOADER |
| X13 | X | output bytes -> no strict prefix parses | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | - | - | STRICT-FRAME |
| X13-PF | X | output bytes -> HOL prefix lemma on refund_strict_parse | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/PF-0004.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `0f52b12ccdbc` | HOL-TCB |
| X13-PX | X | output bytes -> exactly one frame (refund_strict_parse_exact, refund_frame_decision) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `results/m1b-routeA-20261119/attempt-0001/PX-0001.go.log`: 0; Orchestrator A (A ran it; B read the log and run record) | 3 files `7f29c576ff9e` | HOL-TCB |
| X14 | X | full output -> six fields | UNKNOWN-TONIGHT (MACHINE-CHECKED) | MODEL | prior: `T06-forge_refundWireProg.log` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB |
| X15 | X | process result -> caller's decision | MISSING (MISSING) | DEPLOYED | evidence: `BRIDGE_DESIGN.md` | - | STRICT-FRAME, OS-PROC |
| X16 | X | M1 decision -> authorization token | MISSING (MISSING) | DEPLOYED | evidence: `BRIDGE_DESIGN.md`, `OWNER_APPROVAL.md` | - | - |
| X16-DRAFT | X | Dafny verdict and native frame (model) -> issue decision (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-s/Bridge.log`: 0; orchestrator B re-run | 1 files `ddf66e3238eb` | STRICT-FRAME |
| X16-TEST | X | real M1 binary through the draft launcher -> issue decision (DRAFT) | TESTED-UNPROVED (TESTED-UNPROVED) | DRAFT | evidence: `tests.log`, `tests.py`, `launcher.py` | - | A-LOADER, OS-PROC |
| U1 | U | request and candidate transition -> RefundFinality.Check (P1-P4) | MACHINE-CHECKED (MACHINE-CHECKED) | DEPLOYED | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records; `recheck-f/rerun/records/sink-core/verify-sink-core.1.log`: 0; orchestrator B re-run (check_records --rerun) | 5 files `8cc14980d23f` | DAFNY-Z3-TCB |
| U1c | U | impl/RefundFinality.dfy -> compiled JavaScript core | ASSUMPTION (ASSUMPTION) | DEPLOYED | evidence: `evidence.json` | - | DAFNY-JS |
| U2 | U | Check result -> signed token (minter.ts) | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `evidence.json`, `minter.ts` | - | A2-ISSUANCE, NODE-RT |
| U3 | U | token -> commit in sink.ts | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `evidence.json`, `sink.ts`, `encoding.ts` | - | H3b-SINK-REBUILDS, B5-CRYPTO-BOOLEAN, H3d-B6-PARSEABLE, A4b-STORED-HASH, NODE-RT |
| U4 | U | protocol model -> its invariant | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records; `recheck-f/rerun/records/sink-core/verify-sink-core.1.log`: 0; orchestrator B re-run (check_records --rerun) | 5 files `8cc14980d23f` | A1-IDEALMAC, A2-ISSUANCE, A3-ATOMIC-COMMIT, A4-HASH |
| U5a | U | model -> Dafny sink core (merged shape) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core/verify-sink-core.2.log`: 0; worker f-records; `recheck-f/rerun/records/sink-core/verify-sink-core.1.log`: 0; orchestrator B re-run (check_records --rerun) | 5 files `8cc14980d23f` | A1-IDEALMAC, A2-ISSUANCE, A5-VERIFIER-MATCH |
| U5a-W | U | sink core -> non-vacuity witness | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core-witness/verify-sink-core-witness.1.log`: 0; worker f-records; `recheck-f/rerun/records/sink-core-witness/verify-sink-core-witness.1.log`: 0; orchestrator B re-run (check_records --rerun) | 5 files `694d49034427` | A1-IDEALMAC |
| U5a-ATTACK | U | IdealMac (A1) -> not realizable | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/sink-core-attack/verify-sink-core-attack.1.log`: 0; worker f-records; `recheck-f/rerun/records/sink-core-attack/verify-sink-core-attack.1.log`: 0; orchestrator B re-run (check_records --rerun); `smoke/attack.log`: 0; orchestrator B re-run (smoke) | 6 files `56dcd7d19dc8` | - |
| U5b | U | Dafny sink core (merged shape) -> ts/refund-finality/sink.ts | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `summary.txt`, `run_diff.sh`, `sink.ts` | - | DAFNY-JS, NODE-RT |
| U5r | U | model -> patched Dafny sink core with request-id check (DRAFT, not deployed) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-reqid/logs/v02-reqid-verify.log`: 0; worker d-reqid; `d-reqid/recheck/SinkCoreReqId.log`: 0; orchestrator B re-run; `r-reqid/logs/r01-reqid-verify.log`: 0; reviewer r-reqid | 5 files `a127eb22bc9f` | A5-VERIFIER-MATCH, GOODSTART |
| U5r-CONTRAST | U | merged-shape core -> request-id gap (counterexample) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `d-reqid/logs/v03-contrast-verify.log`: 0; worker d-reqid; `d-reqid/recheck/Contrast.log`: 0; orchestrator B re-run; `r-reqid/logs/r03-contrast-verify.log`: 0; reviewer r-reqid | 7 files `011708f09164` | - |
| U5r-REVIEW | U | patched core -> residual gaps (review) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `r-reqid/logs/r12-attack-verify.log`: 0; reviewer r-reqid | 7 files `3680fe8938e0` | - |
| U5r-JS | U | SinkCoreReqId.dfy -> compiled JS (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-reqid/logs/v04-reqid-build.log`: 0; worker d-reqid | 5 files `a127eb22bc9f` | DAFNY-JS |
| U5c | U | patched core -> core-backed shell step (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-corebacked/logs/v01-shellreqid-verify.log`: 0; worker d-corebacked | 6 files `4686d7dabdcd` | A5-VERIFIER-MATCH, GOODSTART |
| U5c-JS | U | ShellCoreReqId.dfy -> compiled JS used by sink_core_backed.ts (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `d-corebacked/logs/v03-shellreqid-build.log`: 0; worker d-corebacked | 6 files `4686d7dabdcd` | DAFNY-JS |
| U5c-CONF | U | compiled shell core -> draft sink_core_backed.ts behaviour | TESTED-UNPROVED (TESTED-UNPROVED) | DRAFT | evidence: `n02-conformance-1.log`, `n03-conformance-2.log`, `sink_core_backed.ts` | - | DAFNY-JS, NODE-RT |
| U5r-DIFF | U | patched compiled cores -> patched sink copy and draft core-backed sinks (DRAFT) | TESTED-UNPROVED (TESTED-UNPROVED) | DRAFT | evidence: `summary.txt`, `run_diff.sh`, `sink_core_backed.ts` | - | DAFNY-JS, NODE-RT |
| U6 | U | Ed25519 and key secrecy -> H1 / H1B | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | H1-EUF-CMA, H1B-BYTES |
| U7 | U | commit -> durable committed state | ASSUMPTION (ASSUMPTION) | DEPLOYED | - | - | A3-ATOMIC-COMMIT, NODE-RT |
| U8 | U | approved spec -> no second authorization | MISSING (MISSING) | DEPLOYED | - | - | - |
| T-V1 | T | slice -> Committed => ApprovedSpec /\ ValidArtifact /\ UniqueAuthorization (model) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `f-records/records/slice-theorem/verify-slice-theorem.1.log`: 0; worker f-records; `recheck-f/rerun/records/slice-theorem/verify-slice-theorem.1.log`: 0; orchestrator B re-run (check_records --rerun); `recheck-f/slice-theorem.log`: 0; orchestrator B re-run | 37 files `1f69ce69a331` | A1-IDEALMAC, A2-ISSUANCE, A5-VERIFIER-MATCH, A6-ALL-STRINGS, INITOK |
| T-V2 | T | slice -> same target without IdealMac | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-V2-01.log`: 0; worker b-signing; `r-signing/logs/rerun-V2.log`: 0; reviewer r-signing | 38 files `1260626ca6f9` | INITOK, A2-ISSUANCE, A5-VERIFIER-MATCH, H1-EUF-CMA, A6-ALL-STRINGS |
| T-V2B | T | slice -> same target with A6b (byte strings) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-V2OnBytes-01.log`: 0; worker b-signing; `recheck-b/SliceSafetyV2OnBytes.log`: 0; orchestrator B re-run; `r-signing/logs/rerun-V2OnBytes.log`: 0; reviewer r-signing **[superseded by T-BYTES-R; retired hypotheses ['H3a-SER-INJECTIVE']]** | 39 files `1e56907165fe` | INITOK, A2-ISSUANCE, H1B-BYTES, H3b-SINK-REBUILDS, H3c-VERIFYTAG-IS-BYTES, B5-CRYPTO-BOOLEAN, A6b-BYTES |
| T-TOTAL | T | total verifier reading -> hypotheses consistent without IdealMac | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `b-signing/logs/final-Total-01.log`: 0; worker b-signing; `recheck-b/TotalReading.log`: 0; orchestrator B re-run; `r-signing/logs/rerun-Total.log`: 0; reviewer r-signing | 5 files `e8e4ddf1d3e1` | - |
| T-V3 | T | model -> core with request-id AND charge-id checks (SinkCoreV3, DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/SinkCoreV3.log`: 0; orchestrator B re-run; `b-integrate/logs/final-SinkCoreV3-01.log`: 0; worker b-integrate | 5 files `049953124384` | A5-VERIFIER-MATCH, GOODSTART |
| T-V3-L0 | T | slice on the V3 core -> committed effects have the charge id and the core invariant (L0) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/SliceSafetyV3.log`: 0; orchestrator B re-run; `b-integrate/logs/final-SliceSafetyV3-01.log`: 0; worker b-integrate | 37 files `5ea9384e873c` | EMPTY-START |
| T-V3-L1 | T | slice on the V3 core -> core related to the model; every outbox tag verifies (L1) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/SliceSafetyV3.log`: 0; orchestrator B re-run; `b-integrate/logs/final-SliceSafetyV3-01.log`: 0; worker b-integrate | 37 files `5ea9384e873c` | EMPTY-START, A5-VERIFIER-MATCH |
| T-V3-L2 | T | slice on the V3 core -> committed effects meet the approved spec; no over-refund (L2) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/SliceSafetyV3.log`: 0; orchestrator B re-run; `b-integrate/logs/final-SliceSafetyV3-01.log`: 0; worker b-integrate | 37 files `5ea9384e873c` | EMPTY-START, INITOK, A2-ISSUANCE, A5-VERIFIER-MATCH, H1-EUF-CMA |
| T-V3-L3 | T | slice on the V3 core -> committed effects also equal the artifact output on byte strings (L3) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/SliceSafetyV3.log`: 0; orchestrator B re-run; `b-integrate/logs/final-SliceSafetyV3-01.log`: 0; worker b-integrate | 37 files `5ea9384e873c` | EMPTY-START, INITOK, A2-ISSUANCE, A5-VERIFIER-MATCH, H1-EUF-CMA, A6b-BYTES |
| T-MULTI | T | V3 core per charge -> several charges: no cross-charge commit (DRAFT) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/MultiCharge.log`: 0; orchestrator B re-run; `b-integrate/logs/final-MultiCharge-01.log`: 0; worker b-integrate | 7 files `9ba05d646d1d` | WELLKEYED, EMPTY-START |
| T-MULTI-L | T | layered theorem -> several charges (L0-L2 per charge) | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-i/MultiChargeLayered.log`: 0; orchestrator B re-run; `b-integrate/logs/final-MultiChargeLayered-01.log`: 0; worker b-integrate | 40 files `e094f17d449f` | WELLKEYED, EMPTY-START, INITOK, H1-EUF-CMA, A2-ISSUANCE, A5-VERIFIER-MATCH |
| T-NOLOSS | T | V3 core -> no honest commit lost against the earlier core | MACHINE-CHECKED (MACHINE-CHECKED) | DRAFT | `recheck-s/AttackTrace.log`: 0; orchestrator B re-run | 38 files `950cf3a58584` | H1-EUF-CMA, A2-ISSUANCE, A5-VERIFIER-MATCH |
| T-V3-LIMITS | T | V3 core -> limits of GoodStart and of a committed attack (review) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-s/AttackCore.log`: 0; orchestrator B re-run | 6 files `b83989fc4514` | - |
| T-MULTI-LIMIT | T | several charges -> WellKeyed is necessary (counterexample) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-s/AttackMulti.log`: 0; orchestrator B re-run | 8 files `5c1eee3b9379` | - |
| T-SER | T | token body model (SerModel) -> round trip, canonical parse, injective serialization | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-s/SerModel.log`: 0; orchestrator B re-run | 1 files `69978825a8ca` | - |
| T-SER-CONF | T | compiled SerModel -> ts/refund-finality/encoding.ts bytes | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `result.2.json`, `run.ts`, `encoding.ts` | - | DAFNY-JS, NODE-RT |
| T-BYTES-R | T | slice on bytes -> SliceSafety on the real token encoding (repaired byte layer) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-s/RepairedBytes.log`: 0; orchestrator B re-run | 41 files `25efa338c55a` | INITOK, A2-ISSUANCE, H3b-SINK-REBUILDS, H3c-VERIFYTAG-IS-BYTES, H1B-BYTES, B5-CRYPTO-BOOLEAN, H3d-B6-PARSEABLE, A4-NOCOLL-RUN, A6b-BYTES |
| T-H3A-CE | T | H3a (serialization injective) -> false for the real token (counterexample) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-b/ByteAttacks.log`: 0; orchestrator B re-run | 40 files `df92f7631769` | - |
| T-EXPORT | T | stored export bytes (read by gen_exported.py) -> Dafny FlatContract (ExportedIffFlat) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-x/ExportBridge.log`: 0; orchestrator B re-run | 41 files `b6d7506ba0ab` | BETA-OPS |
| T-EXPORT-SLICE | T | slice -> SliceSafety from the exported clauses (A6x) | MACHINE-CHECKED (MACHINE-CHECKED) | MODEL | `recheck-x/SliceSafetyFromExport.log`: 0; orchestrator B re-run | 44 files `1802528c9ba6` | INITOK, A2-ISSUANCE, A5-VERIFIER-MATCH, H1-EUF-CMA, A6x-EXPORT |
| J1 | T | Dafny artifact function (A6x, T-EXPORT-SLICE) -> HOL refund_fields (S6) | ASSUMPTION (ASSUMPTION) | MODEL | evidence: `BRIDGE_STATEMENT.md` | - | A7-ART, BETA-VALUES, BETA-OPS, BETA-ORDER |
| V1 | V | HOL constants for code and bitmaps -> two slices of the executable | UNKNOWN-TONIGHT (MACHINE-CHECKED) | DEPLOYED | evidence: `refund-arm64-macho` **[HOL record of an earlier run (JSON actual_exit or a log without an exit line); Orchestrator A's files state no exit code for this case tonight]** | - | HOL-TCB, Q3C-READER |
| V2 | V | rest of the file, dyld, libSystem -> anything | MISSING (MISSING) | DEPLOYED | - | - | A-LOADER |
| V3 | V | final theorem -> 541 ancestor theories by content | TESTED-UNPROVED (TESTED-UNPROVED) | MODEL | - | - | HOL-TCB |
| V4 | V | final statement -> definitions under it | MISSING (MISSING) | MODEL | - | - | HOL-TCB |
| V5 | V | recorded hashes -> independently computed values | MISSING (MISSING) | GOVERNANCE | - | - | - |
| V6 | V | executable -> what is run or deployed | TESTED-UNPROVED (TESTED-UNPROVED) | DEPLOYED | evidence: `refund-arm64-macho` | - | A-LOADER, ADMISSION |
| V7 | V | all of the above -> one answer | TESTED-UNPROVED (TESTED-UNPROVED) | GOVERNANCE | - | - | - |
| E6 | E | gate admission (expect rule + supervision diff, patched copy) -> excludes run-time halts on rare inputs | MISSING (MISSING) | GOVERNANCE | evidence: `summary.txt`, `heavy-H04-seq-length-2pow32-throws.log`, `hostile_controls.sh` | - | ADMISSION |
| E1 | E | new code -> gate verdict | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E2 | E | gate verdict -> merge | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E3 | E | change of a protected file -> refusal | CLAIMED, log missing (MACHINE-CHECKED) | GOVERNANCE |  **[no stored log for this run]** | - | ADMISSION |
| E4 | E | checker, prover, deployer -> three trust domains | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |
| E5 | E | merge -> protected state | MISSING (MISSING) | GOVERNANCE | - | - | ADMISSION |

## Assumptions

| Id | Status | Group / basis | Text | Real-world reading | Realizable | Used by |
|---|---|---|---|---|---|---|
| A1-IDEALMAC | active | - | IdealMac at each delivery: a tag verifies only if it was minted for exactly that claim, in every state. | No real signature or MAC scheme with a total verifier meets it in every state (U478; Attack.TotalVerifierBreaksIdealMac; TotalReading.NoIdealMac). | no | U4, U5a, U5a-W, T-V1 |
| A2-ISSUANCE | active | - | A2_MintOnlyOnCheck: every mint of one of our ids signs CheckedClaim(pre, t) for some pre, t with Authorizes(pre, t). | The issuer (ts/refund-finality/minter.ts) signs only after the compiled RefundFinality.Check returns true. minter.ts is TESTED only. | yes | U2, U4, U5a, T-V1, T-V2, T-V2B, T-V3-L2, T-V3-L3, T-MULTI-L, T-NOLOSS, T-BYTES-R, T-EXPORT-SLICE |
| A5-VERIFIER-MATCH | active | - | A5: the sink's sigOk boolean equals the model's VerifyTag on the delivered token at each delivery. | sink.ts calls Ed25519 verify on exactly the bytes that the model calls the claim. Decomposed (RepairedBytes) into H3b, H3c, B5, H3d-B6 and the trace-local A4-NOCOLL-RUN; H3a is retired. | yes | U5a, U5r, U5c, T-V1, T-V2, T-V3, T-V3-L1, T-V3-L2, T-V3-L3, T-MULTI-L, T-NOLOSS, T-EXPORT-SLICE |
| H1-EUF-CMA | active | - | H1_SignatureAuthenticity (claim level, step-local): a delivered token whose tag verifies carries a claim signed earlier. | Ed25519 EUF-CMA AND secrecy of the signing key; holds up to a negligible forgery probability, only while the key is secret. | yes | U6, T-V2, T-V3-L2, T-V3-L3, T-MULTI-L, T-NOLOSS, T-EXPORT-SLICE |
| H1B-BYTES | active | - | H1B_ByteUnforgeability: byte string and tag that verify were signed earlier (symbolic EUF-CMA at byte level). | Same as H1, stated on bytes; with H3b/H3c/B5/H3d-B6/A4-NOCOLL-RUN it gives H1 and A5 (RepairedBytes.RepairedGiveClaimAuthenticity). | yes | U6, T-V2B, T-BYTES-R |
| H3a-SER-INJECTIVE | retired; False for the real token (hash of the pre-state only).; counterexample `results/night-shift-20261119/orch-B/recheck-b/ByteAttacks.csv` (ByteAttacks.PreStateCollisionBreaksApprovedSpec) | - | H3a: the claim serialization is injective (on model claims that carry the full pre-state). | FALSE for the real token: the token carries only SHA-256 of the pre-state, so two pre-states with one hash give one byte string (ByteAttacks.PreStateCollisionBreaksApprovedSpec; ByteAttacks.HashedPreSerNotInjective). RETIRED. | no | - |
| H3b-SINK-REBUILDS | active | - | H3b: at each delivery the sink rebuilds exactly Ser(ClaimOf(tok)) from the parsed token. | sink.ts rebuilds the signed bytes; not proved. | yes | U3, T-V2B, T-BYTES-R |
| H3c-VERIFYTAG-IS-BYTES | active | - | H3c: the model VerifyTag is the byte verifier applied to Ser(claim). | A definition choice of the model; no real-world content beyond H3a and B5. | yes | T-V2B, T-BYTES-R |
| B5-CRYPTO-BOOLEAN | active | - | B5: the crypto layer boolean is the byte verifier on the rebuilt bytes. | Node OpenSSL Ed25519 verify returns the mathematical verifier value. | yes | U3, T-V2B, T-BYTES-R |
| A3-ATOMIC-COMMIT | active | - | A3: Commit is one atomic, durable step. | One SQLite transaction in node:sqlite. Process crash: TESTED (486 kills, 0 violations, worker run). Power loss: SQLite defaults, no full fsync. | unknown | U4, U7 |
| A4-HASH | active | - | A4 faithful state: comparing state hashes equals comparing states. | SHA-256 collision resistance and a canonical state encoding. | yes | U4 |
| A6-ALL-STRINGS | active | - | A6: the artifact computes the flat contract on ALL FlatIn inputs (any Unicode chars). | The HOL side gives the flat contract only for byte strings (chars < 256) (Orchestrator A, 08:03Z). Not met by the M1 artifact as stated. | no | T-V1, T-V2 |
| A6b-BYTES | active | - | A6b_ArtifactComputesFlatContractOnBytes: the artifact computes the flat contract on byte-string inputs. | The M1 executable on byte inputs computes the flat contract. Equivalent in Dafny to A6x (SliceFromExport.A6xIffA6b). Needs X1 to X10 and A7-ART: open. | unknown | T-V2B, T-V3-L3, T-BYTES-R |
| INITOK | active | - | InitOk: the protocol starts in the initial state of the model. | A fresh store. | yes | T-V1, T-V2, T-V2B, T-V3-L2, T-V3-L3, T-MULTI-L, T-BYTES-R, T-EXPORT-SLICE |
| GOODSTART | active | - | GoodStart: the store that the patched core serves satisfies the core invariant at start (fresh, or AuditStart passes). | A start-up audit (AuditStart, executable) runs before the core serves an old store. It gives structural facts only: AttackCore.GoodStartDoesNotBoundMoney (a store passing the audit holds a refund of 500 on an original of 100). Not deployed. | yes | U5r, U5c, T-V3 |
| BETA-DAFNY-HOL | retired; Umbrella split into three named parts. | - | beta (umbrella): the Dafny meaning of the exported flat-contract text equals the HOL meaning of the parsed S-expression. | Split on 2026-11-19 into BETA-VALUES, BETA-OPS and BETA-ORDER (U539; b-export-bridge/BRIDGE_STATEMENT.md). RETIRED as an umbrella. | unknown | - |
| EXPORTER-ID | active | - | The 3,621-byte S-expression is the output of the patched Dafny exporter on FlatCore.dfy. | Exporter build of 2026-11-04 no longer on this machine (build folder missing). Identity is a RECORD only: input digest = FlatCore digest; output digest recorded. | unknown | S4 |
| CAKEML-CC-SCOPE | active | - | Compiler correctness scope: the compile_correct instance holds with its premises discharged inside the scripts, for the code bytes in the MODEL machine. | Covers CakeML code -> code bytes in the L3 model only; not the C run-time, stubs, GOT binds, dyld (V2). | yes | X2 |
| DAFNY-JS | active | TOOLS | The Dafny 4.11.0 JavaScript back end compiles the verified Dafny module faithfully (RefundFinality; drafts SinkCoreReqId, ShellCoreReqId). | Slice 1 record: source_to_module_proved=false. Trusted compiler; bignumber.js runtime. | unknown | U1c, U5b, U5r-JS, U5c-JS, U5c-CONF, U5r-DIFF, T-SER-CONF |
| DAFNY-Z3-TCB | active | TOOLS | Dafny 4.11.0 with Boogie and Z3 4.12.1 is sound for the options used. | Trusted base; no proof certificate kernel. | unknown | S2, S3, S3a, U1 |
| HOL-TCB | active | TOOLS | The HOL4 kernel and Poly/ML are sound; the cached parent theories are the ones named (definitions, not only statements). | Trusted kernel; V4: the import check compares statement text only; parent .dat bytes are hashed (hash_parents) but not checked by HOL. | unknown | S5, S5-REL, S5-BR, S5-IMP, S6, S6-ELIG, S6-RENDER, X1, X2, X3, X4, X7-L1, X7-L1imp, X7-L2, X7-L2b, X9-LO, X10-LE, X11e-E1, X11e-ES, X13-PF, X13-PX, X14, V1, V3, V4 |
| A-LOADER | active | OS-LAUNCHER | Launcher integrity: the process runs the pinned executable with a scrubbed environment and the pinned dyld/libSystem. | DYLD_INSERT_LIBRARIES forges a complete frame (CE-3, Orchestrator A). Needs a controlled launcher; none exists. | yes | X5, X8, X12, X16-TEST, V2, V6 |
| STRICT-FRAME | active | OS-LAUNCHER | Strict single-frame parse: every consumer or issuer glue accepts exactly one complete result frame; exit status 0 alone is never success. | CE-1: exit 0 with truncated or empty stdout (Orchestrator A). No consumer in the repository (X15 MISSING). | yes | X10, X13, X15, X16-DRAFT |
| ADMISSION | active | - | Admission authority: only owner-approved code reaches main and the deployment. | main is NOT protected (protected:false; rulesets HTTP 403); the session can act as the owner (g-admission). Not met today. | no | S1, V6, E6, E1, E2, E3, E4, E5 |
| X5-ENTRY | active | - | Entry state before cml_main satisfies P1 to P6 (owner text Q3a). | arm8_ok wording needs TBI0 = F and SA0 = F; real user space sets both to 1 (D11). False as worded. | no | X3, X5, X9-LO, X11e |
| X6-FFI-ALL-STATES | active | - | Premise P7 refund_env_ok_sl: the FFI contract at ALL call states. | Probably FALSE: fficlose with x3 = 0 aborts in basis_ffi.c (U393). | no | X3, X6, X7, X9-LO |
| X11-KERNEL | active | OS-LAUNCHER | The processor and the kernel between steps behave as the L3 model and interference_ok say (owner text Q1). | Trusted hardware and kernel. | unknown | X3, X8, X9-LO, X11 |
| S8-CANONICAL-WIRE | active | - | Canonical wire input only (owner Q1, Q5). | The reader accepts 040, +40, "40"; holds only with a strict reader. | unknown | S8 |
| Q3C-READER | active | - | The file reader and slice offsets of the executable (V1) outside HOL are correct. | Second extraction by the same model family on the same machine: not independent. | unknown | V1 |
| A4-NOCOLL-RUN | active | - | A4_NoCollisionInRun (trace-local): for each mint and each delivery of ONE trace, equal hashes of the two pre-states imply equal pre-states (and the same for the two id hashes). | SHA-256 collision resistance on the pairs of one run; holds except with negligible probability; global injectivity is NOT needed (RepairedBytes). | yes | T-BYTES-R |
| A4b-STORED-HASH | active | - | A4b_NoStoredStateCollision: the real sink compares the stored state with the token by SHA-256 of the canonical state text; equal hashes imply equal states. | The real token carries only preStateSha256. Same collision argument as A4-NOCOLL-RUN, a second time, in the sink. Used by NO proof (named in RepairedBytes only). | yes | U3 |
| H3d-B6-PARSEABLE | active | - | H3d_MintsParseable and B6_DeliveriesParseable: every minted claim and every delivered token parses under the canonical token grammar of SerModel. | minter.ts builds only canonical bodies; sink.ts rejects non-canonical text (TESTED: 443 bodies, b-ser conformance). Not proved for the TypeScript. | yes | U3, T-BYTES-R |
| EMPTY-START | active | - | Every trace lemma (L0 to L3, several charges) starts from the EMPTY store; a restart from a non-empty store is covered only as one trace from the empty store. | A deployed sink restarts on an existing database; no restart lemma exists (b-restart running at generation time). Scope limit, not a fact about the world. | yes | T-V3-L0, T-V3-L1, T-V3-L2, T-V3-L3, T-MULTI, T-MULTI-L |
| WELLKEYED | active | - | WellKeyed / KeyedInits: no two databases (charge stores) hold one charge id. | NOT enforced by the model, sink.ts or the dispatcher; AttackMulti.NotWellKeyedDoubleRefund: one token commits in two databases. Needs a creation rule for charge keys. | yes | T-MULTI, T-MULTI-L |
| BETA-VALUES | active | BETA / ARGUED | BETA-VALUES: Dafny int and HOL int are both the mathematical integers; Dafny bool and HOL bool agree; a Dafny string whose chars are < 256 and the HOL string with the same code list denote the same value. | ARGUED, not proved (two tools, no common semantics): b-export-bridge/BRIDGE_STATEMENT.md section 2; Orchestrator A FIELDS_FOR_B.md. | yes | S6, S7, J1 |
| BETA-OPS | active | BETA / ARGUED | BETA-OPS: each of the nine export forms (Eq on bool/int/string, Neq, And, Or, Imp, Le, Not) and three literal forms has the same reading in Dafny (as written by gen_exported.py) and in the HOL Dafny semantics. | ARGUED by a table of source line references (BRIDGE_STATEMENT.md section 2); gen_exported.py is an unproved reader cross-checked by a second reader (Mirror.dfy trees equal). | yes | S5, S6, S7, T-EXPORT, J1 |
| BETA-ORDER | active | BETA / ARGUED | BETA-ORDER: the export names bind the same argument and tuple positions on both sides (charge, request, original, remaining, enabled, opened, candidate, amount, reason). | ARGUED: a charge/request swap on BOTH sides is invisible to both proofs (contract symmetric); a one-sided swap fails (A: NB1 go exit 1). BRIDGE_STATEMENT.md section 3. | yes | S6, S7, J1 |
| A6x-EXPORT | active | - | A6x_ArtifactMeetsExportedContractOnBytes: the artifact flat function meets the three exported clauses on byte-string inputs. | A hypothesis in Dafny; equivalent to A6b (A6xIffA6b). Real-world reading needs A7-ART and the HOL chain X1 to X10. | unknown | T-EXPORT-SLICE |
| A7-ART | active | - | A7-ART: the artifact function of the Dafny lemma is the HOL function refund_fields, and the run-time bytes are the UTF-8 encodings of its string fields. | Names one function on two sides; no tool relates them (U539). The executable computes refund_fields only through X1 to X10 (open). | unknown | J1 |
| OS-PROC | active | OS-LAUNCHER | OS process contract of the launcher: the OS delivers the complete stdout of a terminated child, reports a signal or exit status truthfully, and enforces the launcher timeout. | macOS process and pipe semantics; trusted. CE-1 and CE-2 (exit 0 with truncated or empty stdout) show why exit status alone is not success. | unknown | X15, X16-TEST |
| NODE-RT | active | TOOLS | Pinned Node 24.3.0 with its OpenSSL and built-in SQLite runs sink.ts, minter.ts and the compiled core as written. | Trusted runtime. | unknown | U2, U3, U5b, U5c-CONF, U5r-DIFF, U7, T-SER-CONF |

## Nodes (531)

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
| `results/m1b-routeA-20261119/attempt-0001/E1-0003.go.log` | record | `53115c46ccc0e6354afda84d883939c2952d601bcdda195273648b9f32800440` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/E1-0003.hashes.json` | record | `4a71768418fd5745c0e7e1e922bb750dd88c13e524648eb20dc0555c1f453f9e` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/E1-0003.run.json` | record | `3123ac1c8cb9ed71c1ec8567e7f817c0e47af553ffb8e6f847e3a489cf3c36a1` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/E1-0003.sml` | proof source | `56a87088a16575be0370f53b315be9cf1adacfc59e480e9dc5589da372bdd37d` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/E1neg-0001.go.log` | record | `5a58c28a42620b5302c4a7668bbd53985c3a8eb5472aad36656506f3700e02eb` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/ES-0002.hashes.json` | record | `0e4ea248974a8195c3bd546286e85af99c4216d42b205fecb3728858ac57a618` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/ES-0002.run.json` | record | `dab8bbbcd6f6afc1e5fee99d0268271f42cd2e7c891474906d6f23bf7668f272` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/ES-0002.sml` | proof source | `7c0c3c512561709394eb9d55d03e89a571e61ea58585aacac3c10b69aa02a7e5` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.go.log` | record | `7bb5e1ad9cb9706253498b6929cb33c519b4cdc848c3e6140ec0321fe0725bb4` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.hashes.json` | record | `d9ad96112a9c07d31c16fc530e82832673b44afeb502d3e24aa64ede6be42b65` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.run.json` | record | `9909dcf421537a66f756ecf529c76bdb7395f3f3b6d72093060fc9bfbcaaa84a` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1-0001.sml` | proof source | `9ddf674631a271f7cfd28ddc1d4255bc5146c106a8fe0f32e148e720c5e78830` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.go.log` | record | `b0fbbbdcf323e312527872cb66e0bc7df5d563a649741fe51d236e8a38cb0d94` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.hashes.json` | record | `4b226264dd38fc39e425c9487d08471dd64679ba54580436a7da2afa2fbdbadd` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.run.json` | record | `0b5d6a614014733a3c719230a557334261b9a5899f08b38d6c05ec0d2dc9bd47` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L1imp-0001.sml` | proof source | `27a565ac7c7576d2d4af3a15628add426c3cd83cb0b3593f0e166c4686959c29` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0003.go.log` | record | `1e993f5fee263031ba041300a6e4ddb2dea273d2489e49b9d00ba5626b4a0e3a` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0003.hashes.json` | record | `edb6057777920d27accb127061e0d6b41fc46541bb2677b794c584a800cbbe36` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0003.run.json` | record | `f63fb7df5e8bd26332f93b18bd7261f597cb30e670926d1095d1953c67a33ae6` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2-0003.sml` | proof source | `7c93c62015b7c62ead336bf7dcbf5338efd962e5f6dd23b6c3e4bd9e186073ec` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2b-0003.go.log` | record | `b75cfaa90acfda6676fd31c6c677c6914065bebd2bca722d32e7fa2b415ec6e0` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2b-0003.hashes.json` | record | `3e30844ff554985de9d905db5e005f82763883c79cd522c7540d776cb98e2e50` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2b-0003.run.json` | record | `9b690ad95a302fce14f9096dd01ba2de9fd2023b1d64c96fa4d28ea54eb56c85` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/L2b-0003.sml` | proof source | `cb6efb52be217da178a5ac88dfcdc9989557c6501dfe927efd2f4acc727aaf95` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LE-0004.go.log` | record | `ffcfb3a3d7942292221434f8dcfcd9d54320983865c6111ba110bb8513dceb09` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LE-0004.hashes.json` | record | `75221c070c202648f77fbaaabbc7ec654a57aec68137bc18596032161a3bc117` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LE-0004.run.json` | record | `8ed2235a5444b192cde5b3a6655f3b5bdf53844e107304f5a68a6a3b3dfcdd04` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LE-0004.sml` | proof source | `3bd3cec5cb114b7682390e4e364a425c86b6cd038845d757313b5c9d91432c51` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0006.go.log` | record | `a67e82f3ab489170e0d15724e678ed2194092c21e0155c787eb956c1e137b409` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0006.hashes.json` | record | `d91f0f85638d067de6f9216cda1609c87f8d6f1f6ce78d46a3f0b10ad7529037` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0006.run.json` | record | `9215ae444e74b5aceb4c7339f7f0cc4d686bee0a4420ac542c58c94791d8345d` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/LO-0006.sml` | proof source | `644166686c78e36c2ca7c256d4d89fdaef6b082654a11d6872b3c2f64dd9051a` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0004.go.log` | record | `1f2c3afc55395f2475619cd8ba4521386a4ff65202e3f138334b6d8cae90fdcf` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0004.hashes.json` | record | `a037d10d1315a0c82b1e2cea496c53738c206741ed9e5200fd8c12b2c04b7034` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0004.run.json` | record | `6c4733f5dffe73bd0b28801b1760434b4b2dd21c65eb94ad47e4be52d1fa0f26` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PF-0004.sml` | proof source | `6dc46143de27fdd066077297027d18cc445c0a3509a6ca73a0218ccdafb5761c` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PX-0001.go.log` | record | `6e32940151a288e46f14c8267f458af43a83d0f234de2038c5a8b82fd89222ca` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PX-0001.hashes.json` | record | `8f2c582971f39c0dcc57060beb582146cf16d8678568aabe16a6b91cb4baacba` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PX-0001.run.json` | record | `fd30c13e2c2fc56ba2cb67525a6a35aeb6f52904096d86591838959986445308` | untracked |
| `results/m1b-routeA-20261119/attempt-0001/PX-0001.sml` | proof source | `c4cfd82c25829702d29344faf7fb027cf855526eb76ed69b83a46440a15d2122` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/E0.go.log` | record | `f8d315554d69c0a236e1e4a36ce57fa954034919151e427e70613ae8201580ef` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/H1.go.log` | record | `18a8ace44d6e1dc4d49f2cddcfa5cee267eb306667bb13e871bb64346562c7ac` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/H2.go.log` | record | `53b2cdeb5d559cdedd4a205852e6d0ca076772025fca5fc3ae0f05663c28d063` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/H4.go.log` | record | `79e52b55cbf58076e1cef42b93a594e2a7755db755b211e0079cf2c1f8b613c5` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/I1.go.log` | record | `5a17e105ca66b09c2c294e5e0abc8d58f400682692552fd397226cf22db2616c` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NB1.go.log` | record | `15229d960bd4715cf1cd52796769a6c28843dce4c5e9ac991127558669af3ce1` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC1.go.log` | record | `677f88228041ca7823263ceccee22b8fed2aee4b0881b64688894ad7d60ec535` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC2.go.log` | record | `8619b41937fb3e3d92f933e085ac057b3eeddc8f094e9fd24d6b105591180b5b` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC3.go.log` | record | `c740da33a7f5375a0f5b27d37d0e2fb7ba90b3fa68e0e9536e3e83c2707c77b6` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC4.go.log` | record | `c73f07a6ee47871bb7b6a2079f5bdced0761079e6c6757db4c3ae5c813e98881` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC5.go.log` | record | `d0ebc38292a5f99bb846d3c28daf7eb78d76cc2f23cb5e34d99415a16cf6f3a0` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NC6.go.log` | record | `d0ba65c9fa0a5c4a2f91ee148ac1e201dddc598ed5efa2755f66584de6e38e86` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NR1.go.log` | record | `c0298f68efb4e3dd362fd7f363fd5c5cea858d488ea6509b7a3aee2c19846cf1` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NS1.go.log` | record | `101c892f5e7304c1663b2b8729bbf65c24a0f0fc098b34b727104e9f8bb56cf5` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NS2.go.log` | record | `d4259b9418977b0fecf6470c0428655123353738af42df6cc6dfe82b5147c28d` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/NS3.go.log` | record | `77b99601d4ddd1d256634934db4ee4747ebb01a81cded2b710070a6bfcd73c01` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/PASS_CRITERIA.md` | record | `62aaff700422dbe44b8d4698e727831a829b8abf56aaa378d57fa70f49eda047` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/PC1.go.log` | record | `73a1a3b98d08563220b6f7623fd7b7cca3285aff616325e0da96d9bb83d5bbe2` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/R1.go.log` | record | `efc7fc482845f9c57c600bb973b2ba282801a2feeadc07da402ff8f773c392f3` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/R2.go.log` | record | `3e55a1e86456b9edf98e8bf7af6b90d1d5db0f8d39b828a0bb6525921dcc91fb` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/R3.go.log` | record | `e70630ac6c185f772384dd78d242e13cfebe26fe6d8df057d315c46ffb3baf58` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/contract-0001.run.json` | record | `0019ceba2a1ae44e8bea6f862a018603c5b6f4ddb6d983c2b3c9b1ecef647efc` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/contract-repeat.run.json` | record | `78276c25331c70a5d4b536352c1feb73452624e7d6633a8dfa57f5820d878239` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/control_reasons.txt` | record | `6632c51d576e267ec9a68f2d9d056df59a7281bc07bc420b00d8ad9a09ba54e4` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/eligible-link-0001.run.json` | record | `cbed6b611d770b6fa5739babb1a3d003eb70741ed4559497810654d607db6096` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/eligible/forge_refundEligibleLinkScript.sml` | proof source | `1e28be841f54224949b6e766c755e0efd6d41d8c3751b5acbe396d072e116d85` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/forge_refundExportedContractScript.sml` | proof source | `89fee9c35153d48d0114dde0f1781407b1ba5b46d4ddafde8fc5a740f2c81384` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/forge_refundExportedRenderScript.sml` | proof source | `46a0055df8af5d1ac8da52a85a40b6e0b6267c3601ac7bbeb365ffd27d496d3d` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/render-0002.run.json` | record | `4f5cd45dee1465abdc8c81203f1b77b53e11608822c3123f962b41e2b51028b2` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294-bridge-2.run.json` | record | `29c5be26bf53fdce4755604029a0477c58cd86e1fd47e2f92db2d0ad1a2ed9a9` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294-hol.run.json` | record | `9415df12b7975367a1606bf3fa8ca03fe9c89cf8d9df778b79986b6105745a9e` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294-import-2.run.json` | record | `e107375a4839d1b21fa6e960cbef51be5fcb0dde33e60324d9c3b4c6fabf6b79` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294-rel-2.run.json` | record | `58c4422eaf1861f3b8c2574701386a0dc09f3be71ff7cd5becd983f03c05287e` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294/audit.sml` | proof source | `3da7682c5680e5301c6199fa64f4aefd51a37267f472b8ead890426fe4e571f2` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294/bridge.sml` | proof source | `e9d12e06b1b70ed7ebf80d4551d430870a02225bc3271e00077461a2b9afc42e` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294/proof-0004.sml` | proof source | `a79edc4b607d40963661882fc926f71914724c742f96865832417111a4416d07` | untracked |
| `results/night-shift-20261119/orch-A/link/run/attempt-0001/u294/relation.sml` | proof source | `a8f783a22adbe53c28459b04ceeaaa9b89c3f1954b7944af54fe8a52afa6c884` | untracked |
| `results/night-shift-20261119/orch-A/review-L1/REPORT.md` | record | `0287ef0b4d5ab102db922f3232396581b16aba6052b38e39a3c4450b6f6d2bed` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/BRIDGE_STATEMENT.md` | record | `882d2da0894763ca6de9d635f59937825576b05de5d24653f1dfb2a9bff2a55b` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/ExportBridge.dfy` | proof source | `655534e05866b366c2177b0d04a29b2cca85d0140cd6b7779ddc26e28d992a55` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/SliceSafetyFromExport.dfy` | proof source | `9fbfd16e1604cd733d5721acf4e6a07ad50936f834fab727c22bfc43a3b084e2` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/SliceSafetyV2.dfy` | proof source | `1ed076d134f475c52302012cae532b1714ea204ea6bd668cfb150af93b03fa40` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/SliceSafetyV2OnBytes.dfy` | proof source | `7577af08f35e2e03f512935b0f8e8059f917705d0bfdec7a2e7ed50bede583d1` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/gen/ExportedContract.dfy` | proof source | `41329a00f16582ca355a7529f419d68e5be2c8b4cb270f483fdc20bef1068352` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/gen/ReaderTrees.dfy` | proof source | `c66c6b798b909d08c7c50ee47b3316600bad27160774253c01ffce6b90c0d4f8` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/gen_exported.py` | tool | `db2acbc0f73e8d0fa8e6d16389b9399e4cc5dfed4354ddd479b16e82a5ad101c` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/SliceTheorem.dfy` | proof source | `1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/b-export-bridge/mirror/Mirror.dfy` | proof source | `cc846331886b6ec855abb4a67006f1e7d77eece3d208f95dbb0f3296ebd3b25a` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/MultiCharge.dfy` | proof source | `7020448937ac38d988e65ecd555b0a2d87f3dc345d742357c26d62c8b6689dfe` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/MultiChargeLayered.dfy` | proof source | `e88d482d2c6f7993c32eb7e521b5e10359d72dd2e328bd3ac7cc48690b80796a` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/SinkCoreV3.dfy` | proof source | `1a65fab24b9cf3ff248007bdc20a4bb85a48d6840e24f6fd664edfd69065b5e8` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/SliceSafetyV3.dfy` | proof source | `e841d5700768c612a5bf03fa9dbf18744d1559dd449705a45a39af7c2c621619` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/sink/SinkCoreReqId.dfy` | proof source | `287ffe325854b1df4075fa12da320d8d116fbd0780cd5b168e03c542b904f089` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-MultiCharge-01.csv` | record | `4622578f01126b510a403faffa1723c0a6f30d8178573bace02a71972a34f41e` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-MultiCharge-01.log` | record | `2eb7a5cd68db814d76edc21dac8cbea64cbb7350642fc3d2c75131cb6fd37cde` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-MultiChargeLayered-01.csv` | record | `cba5fb839ea52067dd0ba5c0016322b54fb5ea80577d2249d7814332426fca2d` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-MultiChargeLayered-01.log` | record | `12fec1ecd74b2389e9e26f109182924b24833aa19c4e2b1aec114c999887b7cf` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-SinkCoreV3-01.csv` | record | `9fee427112d87025f4e44c566d829ef8f9f6d06a976edef79e0eb69f31cbf1ea` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-SinkCoreV3-01.log` | record | `2a9c43d3fa599a70a787a4babb61e0d2ec5b3f04ee302f26e66900f885a074bd` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-SliceSafetyV3-01.csv` | record | `3d175a36cf0767cc9c5f40dd7a787696a8b3b329c9a4ba4a6a79afd198c75816` | untracked |
| `results/night-shift-20261119/orch-B/b-integrate/logs/final-SliceSafetyV3-01.log` | record | `c85a171f1d1d3104976290a49a488046a3b6e08450773719df2f7b02dff66bf3` | untracked |
| `results/night-shift-20261119/orch-B/b-ser/RepairedBytes.dfy` | proof source | `0462a78c2c9d776ec8a00cc05619c96f75987cae6e4bf60458e5dd94ce741b29` | untracked |
| `results/night-shift-20261119/orch-B/b-ser/SerModel.dfy` | proof source | `a07f955846276e24d56ec76d1824d00322630de958dfa9dea31eec70a5df7429` | untracked |
| `results/night-shift-20261119/orch-B/b-ser/conformance/result.2.json` | record | `08edc27b7ce42e8441b9ef69e026273ba10a4eb0b70a582008145c8c74d096e9` | untracked |
| `results/night-shift-20261119/orch-B/b-ser/conformance/run.ts` | runtime code | `cb71d9cfbbcfab52a196314212ceec7605de85db3a895f82c2f38e14a6981736` | untracked |
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
| `results/night-shift-20261119/orch-B/heavy/diff-1/summary.txt` | record | `b4d00852764df87649c9da8e8a87b6121b6b1c595329ccd6d496fc414c1afbc2` | untracked |
| `results/night-shift-20261119/orch-B/heavy/hostile/heavy-H04-seq-length-2pow32-throws.log` | record | `4bb178dcda635b5dfd37290c988fdbfebf54d1c1f8207e8bb7890b44172c8f1a` | untracked |
| `results/night-shift-20261119/orch-B/heavy/hostile/summary.txt` | record | `6cf3a978b921547723f8c152ed6e07d79f5bb0c832610e2d0c929db64ae26ae3` | untracked |
| `results/night-shift-20261119/orch-B/heavy/hostile_controls.sh` | proof source | `19cc5b9affecd1b5f4b81ba8f2c5a2bc42df4080250d7ef037970d948b0601f7` | untracked |
| `results/night-shift-20261119/orch-B/heavy/run_diff.sh` | proof source | `fb6fd37a0b61cd5ee1a67dc4279d2254d2d6ccc7be761dec47fb1da6e5672aa6` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/MultiCharge.dfy` | proof source | `7020448937ac38d988e65ecd555b0a2d87f3dc345d742357c26d62c8b6689dfe` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/SinkCoreV3.dfy` | proof source | `1a65fab24b9cf3ff248007bdc20a4bb85a48d6840e24f6fd664edfd69065b5e8` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/SliceSafetyV3.dfy` | proof source | `e841d5700768c612a5bf03fa9dbf18744d1559dd449705a45a39af7c2c621619` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/sink/SinkCoreReqId.dfy` | proof source | `287ffe325854b1df4075fa12da320d8d116fbd0780cd5b168e03c542b904f089` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/src/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/work/AttackCore.dfy` | proof source | `8e47b237ddcabfe470820917bbdf6f00f1c4f6d4992e25a7868c34646c07a1ad` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/work/AttackMulti.dfy` | proof source | `d0adf5f92d78078d43c83fe51533f6c3be6429da5f7af42e1972a5b8db555aaa` | untracked |
| `results/night-shift-20261119/orch-B/r-integrate/work/AttackTrace.dfy` | proof source | `b2ab43c9d744d6879567fe1c554beab78c362446dc8a54d43289ddda27f0a083` | untracked |
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
| `results/night-shift-20261119/orch-B/r-signing/work/ByteAttacks.dfy` | proof source | `20abe569816982d2e4d9a7c980f59ce1aedbf9fda9c52fc13b0a993981288f59` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/SliceSafetyV2.dfy` | proof source | `1ed076d134f475c52302012cae532b1714ea204ea6bd668cfb150af93b03fa40` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/SliceSafetyV2OnBytes.dfy` | proof source | `7577af08f35e2e03f512935b0f8e8059f917705d0bfdec7a2e7ed50bede583d1` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/Library.dfy` | proof source | `20cd9f0d3455d693e8165db78446f30358d7489e1c344540e5cd8b6d759e5409` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/LinkedRefund.dfy` | proof source | `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/SliceTheorem.dfy` | proof source | `1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/UnicodeRelation.dfy` | proof source | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/DivMod.dfy` | proof source | `668a04ec1dfae3f41f3fc3952754900de605b022acbfc83243341f2f6cfa01d2` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/DivInternals.dfy` | proof source | `34332d774149f3cc4984f0d4931d1cf6b343907bc3da70c6a23dca72ab559d50` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/DivInternalsNonlinear.dfy` | proof source | `afe624f1d81ac82b95b9d90445931a444ca736c9d7865c539d4d0a47aa5d6913` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/GeneralInternals.dfy` | proof source | `c91f452c462c9e07231f8ad18a1de409c29345c40689fc9f4a2a4ea9a7c02972` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/ModInternals.dfy` | proof source | `775bcfbf5b168996e49c85ecc56e661e7136ab3fcc07aefd85e3402a7d96e7b0` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/ModInternalsNonlinear.dfy` | proof source | `8a58ee87babaad395519b49f8fbe7b57bacc8b8534b81dd672876067728603e3` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/MulInternals.dfy` | proof source | `7e4c589654853b740e72c950e526f15bee88cd76abeaf0ff94926867f1682f2c` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Internal/MulInternalsNonlinear.dfy` | proof source | `a9e4f91e111f8b085f35404ad3d5f9c445c084a0bf42455378fd417af5b0f81b` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/LittleEndianNat.dfy` | proof source | `c7a884f7c1a3d640ee54fdec6481e21659aa9f652a949ccc6983ae54181ea108` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Logarithm.dfy` | proof source | `08e65e363e5d0ac0bfb674cc8dcb50c0e9f18b42fae278d471e5835d0cee50e8` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Mul.dfy` | proof source | `318cdd74a34332cf14f03b0024f033ca8924d72ae0ba1959687fb439135e7d57` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Power.dfy` | proof source | `880dd391bce30c73afa22f303cc78d917bd8857f1cedf7046506df46ff070675` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Arithmetic/Power2.dfy` | proof source | `576960a554cfb9431a5fb760ec92f3f142d49d9859e72959c7c0f72c26a690ae` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Collections/Collections.dfy` | proof source | `906397b244e36de57b6d8d2205967a9e9f8a55f89d062dd54f6251713ea06a92` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Collections/Seq.dfy` | proof source | `9d2f1c72503d140ccd4f963c820594086dc1f9de06e37e439e8a5d7c909a1d2d` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Functions.dfy` | proof source | `b935ef711e73777d8155bf30469b4b7c5e98c714d65129b816050839c48d2189` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Math.dfy` | proof source | `d1e7acf438f766770f5038aa26bc23f4e49dd17b06b64ccef07d8150c6e2b2a9` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Relations.dfy` | proof source | `af31852c17c7d56af89ebf8464cb8338fc857b4931f98e871aa83e4ec8b8b477` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Strings.dfy` | proof source | `c2d5ad12b1a84d9089297215920ab7367dc4dcbd384649ce91c2938bccdf4b87` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Unicode/Unicode.dfy` | proof source | `db4477f9f789ea61a5265a17ca8299494cf1a4b09747801e1ecab57bc875c016` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Unicode/UnicodeBase.dfy` | proof source | `2650a664f171dcd8cc20d8abd98003135d33fd0f4fbc4bb11c3a0c674cac733e` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Unicode/UnicodeEncodingForm.dfy` | proof source | `09b635f174602b4e91d80ba03fa578ad2fbc3f892df507ae349c16f219615485` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Unicode/Utf8EncodingForm.dfy` | proof source | `9ad6deab2edab4e6402f43e8ba65c4d9fca925421a55b7eab10a192c0da42a78` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/library/Std/Wrappers.dfy` | proof source | `b0db6d1cfce218f358e01e0eed52fba5246f8b64e9b5113d8187620903dc4c08` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/FlatCore.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/Transport.dfy` | proof source | `a07fec89f746b0a67626c778f5b5376f5ae4660eb9514e30f4abcb3bdcd8efc8` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/clearing/RefundExact.dfy` | proof source | `58d354e91ce08468ec40c321fee9a1fcec441616c69a443173b4328213d53d85` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/impl/Refund.dfy` | proof source | `0416882492de095b59f3547a8df788193ec41952cf2d30a65df80b8ecd52a700` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/impl/RefundFinality.dfy` | proof source | `2326934559f467883be97bd644da6a02fda60c0fac86ef2b3da6a8fa0071d41c` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/model/FinalityProtocol.dfy` | proof source | `8b70b6b410683004403beeadf427ece42dd38b292f12a082917efe6272177484` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy` | proof source | `6902061697489a0e17ac5340eb0a02bc57d43e8c1067ea1ca295430f5fc9ae0c` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/sink/SinkCore.dfy` | proof source | `198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba` | untracked |
| `results/night-shift-20261119/orch-B/r-signing/work/inputs/transport/spec/refund/RefundSpec.dfy` | proof source (copy of spec/refund/RefundSpec.dfy) | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/ByteAttacks.csv` | record | `7fc13b70a952c6c3489fa819f002ef12b8bc1aece9335da84c50f3c518ee7f94` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/ByteAttacks.log` | record | `b114fbb203f22dcef1e03783f01c0eaf0cc622739d595a5e17043fcce3836e63` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/SliceSafetyV2OnBytes.csv` | record | `8694f3eecfa796892e35f2b3baffd28f093483c493ca1cd3ac4886284ad438df` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/SliceSafetyV2OnBytes.log` | record | `06b353463fa9bb648eea8a8811327cd122bbf729584f64b1706c79e000c4cb94` | untracked |
| `results/night-shift-20261119/orch-B/recheck-b/TotalReading.log` | record | `402d454b2df328c2c2202cd8caca56434bd27bf8aa0ad1a07d7fc75346621614` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun.out` | proof source | `5d2371b0a8f18961babd092c12e7742c894bce340ed966c7674156be87555501` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.csv` | record | `1dfe361065f2a92d0b8b64b052df1cdb1e642729215c4efe99e692c3ee96ed72` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/linked-refund-no-axiom/verify-linked-refund-no-axiom.1.log` | record | `973425108ae90650099099a799618c6ca7df7d713c305ae20f59b69c6cc81dcb` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/linked-refund/verify-linked-refund.1.csv` | record | `3dc9065ab82d672dbc7d57a5545abdefdf84fa4e4e341298ee68af824365416f` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/linked-refund/verify-linked-refund.1.log` | record | `8d4eec3ea5d0ae851bdedeadab6a445b8e486cb5b46681bb076650f6353d2ddc` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core-attack/verify-sink-core-attack.1.csv` | record | `06a3635c415d2bdec4c6f8dfefcce18a4410cdf6c7eb0e8e3e442440d9dead64` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core-attack/verify-sink-core-attack.1.log` | record | `cc0468b877640e0fa732e69b46cd1e6702e0c12ef37012c66ff34a70a1ff28ba` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core-witness/verify-sink-core-witness.1.csv` | record | `f904a9b67cc2c4f3102099468eb25c555582e53f51466ab3889fa6deff1774bc` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core-witness/verify-sink-core-witness.1.log` | record | `f79f1dcc40bc76f23cfbb8eac45ea7ac7ba26b5b5141ed59bf9c41c0ae9fc2a8` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core/verify-sink-core.1.csv` | record | `a3eeb626ac6acb575997353f9badfdf95735d5fec5100b5111d780a0843b14c4` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/sink-core/verify-sink-core.1.log` | record | `efa28693beee6b5f50e7fcfb3378a608eab7834357a5ac6b9a4e583c0e08699c` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/slice-theorem/verify-slice-theorem.1.csv` | record | `792093f7038a67f721909c47a9a7286494f876e86cb957facaa09f3545a9f050` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/rerun/records/slice-theorem/verify-slice-theorem.1.log` | record | `e6c7334f5cf9d5bccdc3dc9a7387e1f2f0755219fb9b671e9f66136377483465` | untracked |
| `results/night-shift-20261119/orch-B/recheck-f/slice-theorem.log` | record | `239a28b57b9a3e0dafbf3fd1e00cbadc822f0fdab0e6650820bb1e9eca06de94` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/MultiCharge.csv` | record | `bf987c6b29b644ebc0f201bc58d3d07afe27e8bf4d1bb19b199dcafbe201960e` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/MultiCharge.log` | record | `5dd5949e938d85e7694fc1f313dd1c38d25cf8939bdbe9b7803b8bb8329c8452` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/MultiChargeLayered.csv` | record | `44fbc1b850f28cc14ed78e332cf59a23fa4b30aa559568ed25a23f2bee0561f9` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/MultiChargeLayered.log` | record | `8b8f8680633ea18d9572e401547ee64c4a49b28bfdbc128fa392d7a8e3fa98e0` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/SinkCoreV3.csv` | record | `60763be67954a051cb321b4e13825044e26221c856a8053b9cdcaa68c7e6c802` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/SinkCoreV3.log` | record | `6e673b4bd82b846c5e04b5f7a995c65c2f783a7bae09f2dd2fb62e739ca784a3` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/SliceSafetyV3.csv` | record | `6fea196faffa8f55275c097fcf98127cb048fbf2cad794a0063bf461cae723eb` | untracked |
| `results/night-shift-20261119/orch-B/recheck-i/SliceSafetyV3.log` | record | `e26d5440b07b3af3dbae434e7f5fd98c0ec7bfe1afc17557eb47ffd87f0057b1` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackCore.csv` | record | `a227f4b42f23a5721bc222315ebee29f8f4897cad79899187a062bb0906a76c0` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackCore.log` | record | `62b1cde5a43d6aabf858ef2007371cd64b90d1f3a60656dbc982148b661b2e32` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackMulti.csv` | record | `2e0228b69bf370df3123fb55a165bb7c3e1a523831993054f679732c629ae048` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackMulti.log` | record | `915d54704743ced2bedd4b461ec08f58e78e92c842e496929a5278e35f8dd0a3` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackTrace.csv` | record | `73563891f475babe65f90a7e10893867018cd7605c8f350ef930cab34ba81b75` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/AttackTrace.log` | record | `85722e9bfdb81aac85ae71b643304b3f7822679cb185992de88a5433d71e7d2f` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/Bridge.csv` | record | `ac7d5074e6688421461c9c0f5ffd0c946bf516b834e52e140f1c5b0a7aeb8142` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/Bridge.log` | record | `908904deeeabaa7448821ed0e97313e32934244d35510c3082284b6f7a474dcd` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/RepairedBytes.csv` | record | `149b681f9fe7c6bf89c1f67a53aec0e2c584286e28ab1cd345aaa63ee5780ca7` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/RepairedBytes.log` | record | `6400d19520ea1762c0b37f2d11bef396c6697081643d8ea34c2bc566f1a3f06b` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/SerModel.csv` | record | `91b5a0a8e95f2d96c2a34ad9a254c3200d0d56f6f96f7eb03af73d278fe058cc` | untracked |
| `results/night-shift-20261119/orch-B/recheck-s/SerModel.log` | record | `6df09550e934c46379eabf66653e80f956d54c1c9ab03ad9988e84f36f727312` | untracked |
| `results/night-shift-20261119/orch-B/recheck-x/ExportBridge.csv` | record | `73f72341c72cc3d92e50503299485410639eaa5c3d2d9b1a5431d140736e43c5` | untracked |
| `results/night-shift-20261119/orch-B/recheck-x/ExportBridge.log` | record | `d8f9c469e8f77927b309fbf5234aacd655f2058bd1b01e1a04a8ee8959168e0b` | untracked |
| `results/night-shift-20261119/orch-B/recheck-x/SliceSafetyFromExport.csv` | record | `fa5e824c1281487dff528d4cff773475b0a9cf8de8b0b44fa2d7eaabeabba6af` | untracked |
| `results/night-shift-20261119/orch-B/recheck-x/SliceSafetyFromExport.log` | record | `25e1ba25ac18b493d9eccef4d2befb79d218b89c8fec3eb6b11f1505bac33c09` | untracked |
| `results/night-shift-20261119/orch-B/recheck-xb/tests.log` | record | `4a2196d889ca2837196882e1359c6c8df0f1c3829b6b523a1370b2221aedb324` | untracked |
| `results/night-shift-20261119/orch-B/smoke/attack.log` | record | `213f813c594095f7c153399390aa556826c4ab4beadbdbbc4c4f1f0bcf95f102` | untracked |
| `results/night-shift-20261119/orch-B/tools/dafny_locked.sh` | proof source | `fe71148e52c8d10d88fb868c8632827961ac335d77d31c9de8c893bae026d091` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/BRIDGE_DESIGN.md` | record | `ac1fddeb202226429fe27cf862cf373c4486d4a1fc16ca6696c10efae7f8687a` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/OWNER_APPROVAL.md` | record | `ed5e8da0439a5633daf6db1b1d6b0e784437b8163d56aa4d09915e86f549e4e3` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/dafny/Bridge.dfy` | proof source | `c49b724d722c5e8728ab8bf7978f85d016a390498b2f2f1f1d4f0a87782bee8d` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/decide.py` | tool | `56c9a5b7f5fcb1340307a01b2ef1f6c96e2aea0b36becf3cdd22b9ce8d46db5a` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/frame.py` | tool | `cf9390074435e74f4731c357a363e77a42c6887c74cd767ba0ef7a916eaa3e12` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/launcher.py` | tool | `7f87563c24bf9bc37267779f02133fefc1b349f30a2da84d5721f971ac42b971` | untracked |
| `results/night-shift-20261119/orch-B/x-issuer-bridge/tests.py` | tool | `6759f89c491d9246872fed22d6205cf69ec4c3f0e24d4675e8044acc2da6e387` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/command.json` | record | `138aad5aacfdd0ed344f9282804e00470cf04eef4dee61a7e60587fb2f73c702` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/input.dfy` | proof source | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` | untracked |
| `results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records/export-0003/output.sexp` | exported contract | `58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d` | untracked |
| `spec.lock` | approved spec | `32cf117f5bcaec2fb0c072650ceb9b535576ab409579a56c00979ed151b03b69` | tracked |
| `spec/refund/RefundSpec.dfy` | approved spec | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` | tracked |
| `spec/refund/protocol.md` | approved spec | `5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4` | tracked |
| `spec/refund/spec.lock` | approved spec | `8b131ab82d3d5bb8f284086e207fa4207c3599ffcae887aa70b13d225ce9375b` | tracked |
| `ts/refund-finality/dispatcher.ts` | runtime code | `5511cf68ba595da535324d1170dcec59d2ce368bb3efdd0470f3f6e0924ee605` | tracked |
| `ts/refund-finality/encoding.ts` | runtime code | `f96086b1838163e371b08fb3fd522e23b4def6b7d9c50fefce57c030b70526e7` | tracked |
| `ts/refund-finality/minter.ts` | runtime code | `714824d83fd660b4fa69d3bc8993a5b08cf79b396507cb026ce6563ef887e1df` | tracked |
| `ts/refund-finality/sink.ts` | runtime code | `0690a4269a38f49a9b053ab9a97a55d917b4a3758f39cbecd2edf91a78484de7` | tracked |
