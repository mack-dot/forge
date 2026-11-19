#!/usr/bin/env python3
"""Generate ASSURANCE_LEDGER.json and ASSURANCE_LEDGER.md (night shift 2026-11-19, Orchestrator B, task f-binding).

Python 3 standard library only. It runs no prover. It reads stored logs, CSVs and records, recomputes digests and
include closures, and writes one ledger of the refund slice: approved spec -> durable committed state.

Fail closed: an edge is emitted as MACHINE-CHECKED only if its primary log exists inside the repository tree, its
last line is an accepted exit line with exit 0, its `# cmd:` header names the closure entry, the required lemma rows
of its CSV are present and Passed, and the closure recomputed now has the digest recorded for the run. Otherwise the
edge is emitted as "CLAIMED, log missing" with a `downgrade_reason`. HOL edges taken from Orchestrator A's files are
"UNKNOWN-TONIGHT" when A's files do not exist or state no exit code. No exit code is invented.

Usage: python3 make_ledger.py [--repo DIR] [--out DIR]
"""
import argparse, datetime, json, subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ledger_lib as L

NS = L.NIGHT + '/orch-B'
FR = L.F_RECORDS
PROP = 'proposals/m1b-mission-20261119'
M1R = 'proposals/refund-executable-feasibility/m1-chain-replay-20261118/records'
U294 = ('results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/'
        'source-model-binding-20261104/records')
RA = 'results/m1b-routeA-20261119/attempt-0001'
OA = L.NIGHT + '/orch-A'

APPROVED = ['spec/refund/protocol.md', 'spec/refund/RefundSpec.dfy', 'spec/refund/spec.lock', 'spec.lock']
# Approved digests as recorded by the Slice 1 evidence (approved_inputs_sha256); root spec.lock pinned at generation.
SLICE1 = 'proposals/forge2-slice1-refund-finality/records/evidence.json'
CONF = 'proposals/forge2-m1-conformance/records/evidence.json'
EXE = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
EXPORT_OUT = U294 + '/export-0003/output.sexp'
EXPORT_IN = U294 + '/export-0003/input.dfy'
EXPORT_REC = U294 + '/export-0003/command.json'

V2_REQ = ['SliceTheoremV2.SliceSafetyV2', 'SliceTheoremV2.UniqueAuthorizationV2', 'SliceTheoremV2.SliceSafetyV2Bytes',
          'SliceWitnessV2.MainWitness', 'SliceWitnessV2.DropAuthenticityBreaksApprovedSpec',
          'SliceWitnessV2.DropIssuanceBreaksApprovedSpec', 'SliceWitnessV2.DropA6BreaksFlatPath',
          'SliceWitnessV2.TwoZeroAmountCommits', 'SliceWitnessV2.TotalVerifierBreaksIdealMacCopy']
V2B_REQ = ['SliceTheoremV2B.SliceSafetyV2OnByteStrings', 'SliceTheoremV2B.A6ImpliesA6b',
           'SliceWitnessV2B.WideBrokenMeetsA6bNotA6', 'SliceWitnessV2B.WideBrokenStillCovered'] + V2_REQ
TOTAL_REQ = ['TotalReading.Total', 'TotalReading.NoIdealMac', 'TotalReading.ReadingHolds', 'TotalReading.RunInTotalInstance']
REQID_REQ = ['SinkCoreReqId.MismatchNeverCommits', 'SinkCoreReqId.RunKeepsGood', 'SinkCoreReqId.FromInitGood',
             'SinkCoreReqId.RejectedChangesNothing', 'SinkCoreReqId.StepExact', 'SinkCoreReqId.ZeroAmountStillCommits',
             'SinkCoreReqId.Witness', 'SinkCoreReqId.PatchedRefusesGapTrace', 'SinkCoreReqId.ChargeIdNotBound',
             'SinkCoreReqId.StepRefinesModelStep']
CONTRAST_REQ = ['ReqIdGapContrast.UnpatchedGap', 'ReqIdGapContrast.UnpatchedBreaksGood', 'ReqIdGapContrast.PatchedOnGapTrace']
ATTACK2_REQ = ['ReqIdAttack.CrossChargeWithReqIdPatch', 'ReqIdAttack.ForeignPostLocksStore',
               'ReqIdAttack.UpgradeAfterGapStillDuplicates', 'ReqIdAttack.GapTokenNotAuthorized']
SHELL_REQ = ['ShellCoreReqId.StepPAgrees', 'ShellCoreReqId.StepPRefinesModelStep', 'ShellCoreReqId.Witness']

# ------------------------------------------------------------------ assumptions (first-class entries)
ASSUMPTIONS = [
    ('A1-IDEALMAC', 'IdealMac at each delivery: a tag verifies only if it was minted for exactly that claim, in every state.',
     'No real signature or MAC scheme with a total verifier meets it in every state (U478; Attack.TotalVerifierBreaksIdealMac; TotalReading.NoIdealMac).', 'no'),
    ('A2-ISSUANCE', 'A2_MintOnlyOnCheck: every mint of one of our ids signs CheckedClaim(pre, t) for some pre, t with Authorizes(pre, t).',
     'The issuer (ts/refund-finality/minter.ts) signs only after the compiled RefundFinality.Check returns true. minter.ts is TESTED only.', 'yes'),
    ('A5-VERIFIER-MATCH', 'A5: the sink\'s sigOk boolean equals the model\'s VerifyTag on the delivered token at each delivery.',
     'sink.ts calls Ed25519 verify on exactly the bytes that the model calls the claim. Decomposed into H3a, H3b, H3c, B5.', 'yes'),
    ('H1-EUF-CMA', 'H1_SignatureAuthenticity (claim level, step-local): a delivered token whose tag verifies carries a claim signed earlier.',
     'Ed25519 EUF-CMA AND secrecy of the signing key; holds up to a negligible forgery probability, only while the key is secret.', 'yes'),
    ('H1B-BYTES', 'H1B_ByteUnforgeability: byte string and tag that verify were signed earlier (symbolic EUF-CMA at byte level).',
     'Same as H1, stated on bytes; with H3a/H3b/H3c/B5 it gives H1 and A5 (SliceTheoremV2.BytesGiveClaimAuthenticity).', 'yes'),
    ('H3a-SER-INJECTIVE', 'H3a: the claim serialization is injective.', 'ts/refund-finality/encoding.ts is canonical and injective; not proved.', 'yes'),
    ('H3b-SINK-REBUILDS', 'H3b: at each delivery the sink rebuilds exactly Ser(ClaimOf(tok)) from the parsed token.', 'sink.ts rebuilds the signed bytes; not proved.', 'yes'),
    ('H3c-VERIFYTAG-IS-BYTES', 'H3c: the model VerifyTag is the byte verifier applied to Ser(claim).', 'A definition choice of the model; no real-world content beyond H3a and B5.', 'yes'),
    ('B5-CRYPTO-BOOLEAN', 'B5: the crypto layer boolean is the byte verifier on the rebuilt bytes.', 'Node OpenSSL Ed25519 verify returns the mathematical verifier value.', 'yes'),
    ('A3-ATOMIC-COMMIT', 'A3: Commit is one atomic, durable step.',
     'One SQLite transaction in node:sqlite. Process crash: TESTED (486 kills, 0 violations, worker run). Power loss: SQLite defaults, no full fsync.', 'unknown'),
    ('A4-HASH', 'A4 faithful state: comparing state hashes equals comparing states.', 'SHA-256 collision resistance and a canonical state encoding.', 'yes'),
    ('A6-ALL-STRINGS', 'A6: the artifact computes the flat contract on ALL FlatIn inputs (any Unicode chars).',
     'The HOL side gives the flat contract only for byte strings (chars < 256) (Orchestrator A, 08:03Z). Not met by the M1 artifact as stated.', 'no'),
    ('A6b-BYTES', 'A6b_ArtifactComputesFlatContractOnBytes: the artifact computes the flat contract on byte-string inputs.',
     'The M1 executable on byte inputs computes the exported flat contract. Needs S4, beta, S5, S6, X1 to X10: open.', 'unknown'),
    ('INITOK', 'InitOk: the protocol starts in the initial state of the model.', 'A fresh store.', 'yes'),
    ('GOODSTART', 'GoodStart: the store that the patched core serves satisfies the core invariant at start (fresh, or AuditStart passes).',
     'A start-up audit (AuditStart, executable) runs before the core serves an old store. NoGoodStartDuplicates shows it is necessary. Not deployed.', 'yes'),
    ('BETA-DAFNY-HOL', 'beta: the Dafny meaning of the exported flat-contract text equals the HOL meaning of the parsed S-expression (8 operators, 3 literals, 4 strings, strings as bytes).',
     'No tool relates the two semantics; a Dafny mirror of the HOL rules agrees (report D12): a proof about a transcription.', 'unknown'),
    ('EXPORTER-ID', 'The 3,621-byte S-expression is the output of the patched Dafny exporter on FlatCore.dfy.',
     'Exporter build of 2026-11-04 no longer on this machine (build folder missing). Identity is a RECORD only: input digest = FlatCore digest; output digest recorded.', 'unknown'),
    ('CAKEML-CC-SCOPE', 'Compiler correctness scope: the compile_correct instance holds with its premises discharged inside the scripts, for the code bytes in the MODEL machine.',
     'Covers CakeML code -> code bytes in the L3 model only; not the C run-time, stubs, GOT binds, dyld (V2).', 'yes'),
    ('DAFNY-JS', 'The Dafny 4.11.0 JavaScript back end compiles the verified Dafny module faithfully (RefundFinality; drafts SinkCoreReqId, ShellCoreReqId).',
     'Slice 1 record: source_to_module_proved=false. Trusted compiler; bignumber.js runtime.', 'unknown'),
    ('DAFNY-Z3-TCB', 'Dafny 4.11.0 with Boogie and Z3 4.12.1 is sound for the options used.', 'Trusted base; no proof certificate kernel.', 'unknown'),
    ('HOL-TCB', 'The HOL4 kernel and Poly/ML are sound; the cached parent theories are the ones named (definitions, not only statements).',
     'Trusted kernel; V4: the import check compares statement text only; parent .dat bytes are hashed (hash_parents) but not checked by HOL.', 'unknown'),
    ('A-LOADER', 'Launcher integrity: the process runs the pinned executable with a scrubbed environment and the pinned dyld/libSystem.',
     'DYLD_INSERT_LIBRARIES forges a complete frame (CE-3, Orchestrator A). Needs a controlled launcher; none exists.', 'yes'),
    ('STRICT-FRAME', 'Strict single-frame parse: every consumer or issuer glue accepts exactly one complete result frame; exit status 0 alone is never success.',
     'CE-1: exit 0 with truncated or empty stdout (Orchestrator A). No consumer in the repository (X15 MISSING).', 'yes'),
    ('ADMISSION', 'Admission authority: only owner-approved code reaches main and the deployment.',
     'main is NOT protected (protected:false; rulesets HTTP 403); the session can act as the owner (g-admission). Not met today.', 'no'),
    ('X5-ENTRY', 'Entry state before cml_main satisfies P1 to P6 (owner text Q3a).', 'arm8_ok wording needs TBI0 = F and SA0 = F; real user space sets both to 1 (D11). False as worded.', 'no'),
    ('X6-FFI-ALL-STATES', 'Premise P7 refund_env_ok_sl: the FFI contract at ALL call states.', 'Probably FALSE: fficlose with x3 = 0 aborts in basis_ffi.c (U393).', 'no'),
    ('X11-KERNEL', 'The processor and the kernel between steps behave as the L3 model and interference_ok say (owner text Q1).', 'Trusted hardware and kernel.', 'unknown'),
    ('S8-CANONICAL-WIRE', 'Canonical wire input only (owner Q1, Q5).', 'The reader accepts 040, +40, "40"; holds only with a strict reader.', 'unknown'),
    ('Q3C-READER', 'The file reader and slice offsets of the executable (V1) outside HOL are correct.', 'Second extraction by the same model family on the same machine: not independent.', 'unknown'),
    ('NODE-RT', 'Pinned Node 24.3.0 with its OpenSSL and built-in SQLite runs sink.ts, minter.ts and the compiled core as written.', 'Trusted runtime.', 'unknown'),
]

# ------------------------------------------------------------------ edge table
# run: dict(log, csv, ran_by, root, entry, role); fr: f-records proof name; hol: dict(log, source, hashes, runjson)


def R(log, ran_by, root=None, entry=None, csv=None, role='verify'):
    return dict(log=log, csv=csv, ran_by=ran_by, root=root, entry=entry, role=role)


def fr_runs(name, recs, extra=()):
    p = recs['proofs'][name]
    v = p['verify']
    runs = [R(FR + '/' + v['log'], 'worker f-records', p['root_in_checkout'], p['entry'], FR + '/' + v['csv'])]
    return runs + list(extra)


EDGES = [
    # ---- chain S: approved contract -> HOL functions
    dict(id='S1', chain='S', frm="owner's intent", to='approved spec on main (R1-R5)', claimed='MISSING', about='GOVERNANCE',
         statement='No approval channel exists that the agent cannot forge.', assumptions=['ADMISSION']),
    dict(id='S2', chain='S', frm='approved RefundSpec.Assess (R1-R5)', to='impl/Refund.dfy', claimed='MACHINE-CHECKED', about='DEPLOYED',
         statement='Refund refines RefundSpec verifies (partial correctness only: a body `expect false` also verifies, D5); checked inside the linked-refund closure, whose copies equal spec/refund/RefundSpec.dfy and impl/Refund.dfy.',
         fr='linked-refund', required=['Refund.Assess', 'RefundSpec.Assess'], binds_approved=True,
         assumptions=['DAFNY-Z3-TCB'], evidence=[SLICE1]),
    dict(id='S3', chain='S', frm='approved contract (R1-R5, datatypes, Unicode strings)', to='flat contract (AssessFlat on UTF-8 bytes)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='LinkedRefund refines RefundSpec; Uniqueness; FlattenInjective; FlatYieldsOnlyImages (1489 verified).',
         fr='linked-refund', required=['LinkedRefund.Uniqueness', 'LinkedRefund.FlattenInjective', 'LinkedRefund.FlatYieldsOnlyImages',
                                       'LinkedRefund.WitnessAccepted', 'LinkedRefund.WitnessRejected'], binds_approved=True,
         assumptions=['DAFNY-Z3-TCB']),
    dict(id='S3a', chain='S', frm='Dafny library in the S3 closure', to='no axiom needed', claimed='MACHINE-CHECKED', about='MODEL',
         statement='With the module of the bodiless @Axiom CharsConsistent removed, the S3 proof verifies (1486 verified).',
         fr='linked-refund-no-axiom', required=['LinkedRefund.Uniqueness', 'LinkedRefund.FlattenInjective'], binds_approved=True,
         assumptions=['DAFNY-Z3-TCB']),
    dict(id='S4', chain='S', frm='flat contract text in Dafny', to='exported S-expression (3,621 bytes)', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Export input digest equals FlatCore.dfy; four readings agree with the Dafny text; the exporter build is missing (record only).',
         assumptions=['EXPORTER-ID'], evidence=[EXPORT_IN, EXPORT_OUT, EXPORT_REC]),
    dict(id='S5', chain='S', frm='exported bytes', to='parsed HOL contract (source_decode, source_postconditions, source_full_result, source_compiled_fields)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='U294 theorems of 2026-11-04 (not in the 2026-11-18 replay).',
         hol_prior=[U294 + '/hol-0004/command.json', U294 + '/bridge-0001/command.json'],
         assumptions=['HOL-TCB', 'BETA-DAFNY-HOL']),
    dict(id='S6', chain='S', frm='exported contract', to='HOL functions eligible, refund_fields', claimed='MISSING', about='MODEL',
         statement='eligible_link_guard_value / exported_contract_on_refund_fields: link package of Orchestrator A not run at generation time.',
         a_case=dict(note='orch-A/link/run/attempt-0001: no go log with an exit line found'), assumptions=['BETA-DAFNY-HOL']),
    dict(id='S7', chain='S', frm='Dafny operator meanings', to='HOL Dafny semantics', claimed='ASSUMPTION', about='MODEL',
         statement='The Dafny-to-HOL bridge beta on the named fragment.', assumptions=['BETA-DAFNY-HOL']),
    dict(id='S8', chain='S', frm='wire text', to='nine typed fields', claimed='ASSUMPTION', about='DEPLOYED',
         statement='refund_wire_roundtrip holds for the canonical text only.', assumptions=['S8-CANONICAL-WIRE']),
    # ---- chain X: HOL functions -> bytes a caller reads
    dict(id='X1', chain='X', frm='HOL functions', to='CakeML code', claimed='MACHINE-CHECKED', about='MODEL',
         statement='Translator certificate theorems (M1R-1 T05).', hol_prior=[M1R + '/commands.json', M1R + '/logs/T05-forge_refundCertifiedProg.log'],
         assumptions=['HOL-TCB']),
    dict(id='X2', chain='X', frm='CakeML code', to='code bytes', claimed='MACHINE-CHECKED', about='MODEL',
         statement='Instance of compile_correct (M1R-1 C32, C34).',
         hol_prior=[M1R + '/logs/C32-source-0006.stdout.log', M1R + '/logs/C34-real-0004.stdout.log'], assumptions=['HOL-TCB', 'CAKEML-CC-SCOPE']),
    dict(id='X3', chain='X', frm='code bytes in the model at cml_main, 11 premises', to="model's output", claimed='MACHINE-CHECKED', about='MODEL',
         statement='refund_profile_a_sl, refund_profile_a_sl_every_machine_run (e4-0001).',
         hol_prior=[M1R + '/final-cases/e4-0001/command.json', M1R + '/final-cases/e4-0001/stdout.log'],
         assumptions=['HOL-TCB', 'X5-ENTRY', 'X6-FFI-ALL-STATES', 'X11-KERNEL']),
    dict(id='X4', chain='X', frm='premises of X3', to='satisfiable together', claimed='MACHINE-CHECKED', about='MODEL',
         statement='refund_profile_a_sl_all_premises_satisfiable_at_0x4000 for one constructed state (fs-r4-0001).',
         hol_prior=[M1R + '/final-cases/fs-r4-0001/command.json', M1R + '/final-cases/fs-r4-0001/stdout.log'], assumptions=['HOL-TCB']),
    dict(id='X5', chain='X', frm='entry state of the real process', to='premises P1-P6', claimed='ASSUMPTION', about='DEPLOYED',
         statement='Everything before cml_main is outside every proof.', assumptions=['X5-ENTRY', 'A-LOADER']),
    dict(id='X6', chain='X', frm='real C FFI code', to='premise P7 at all call states', claimed='ASSUMPTION', about='DEPLOYED',
         statement='Probably false (fficlose x3 = 0).', assumptions=['X6-FFI-ALL-STATES']),
    dict(id='X7', chain='X', frm='contract at all call states', to='contract at reached calls', claimed='MISSING', about='MODEL',
         statement='L1 + L2 + L3 together; L1 replaces P7 by two unproved premises (A7 review); L2 attempt exit 1; L3 not attempted.',
         assumptions=['X6-FFI-ALL-STATES']),
    dict(id='X7-L1', chain='X', frm='refund_ffi_contract_at', to='totalised contract (L1)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='refund_ffi_contract_at_totalise and the L1 theorems (16 theorems, model only; holds also for Vok = F).',
         hol=dict(case='L1-0001'), assumptions=['HOL-TCB']),
    dict(id='X7-L1imp', chain='X', frm='L1 theory', to='import check', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L1 theorems import with IMPORTED_COUNT 9, MISMATCH_COUNT 0 (statement text only; 9 of 16 matched).',
         hol=dict(case='L1imp-0001'), assumptions=['HOL-TCB']),
    dict(id='X7-L2', chain='X', frm='two machines', to='agreement (L2)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L2 attempt 0001.', hol=dict(case='L2-0001'), assumptions=['HOL-TCB']),
    dict(id='X8', chain='X', frm='real process', to='model machine', claimed='MISSING', about='DEPLOYED',
         statement='native_refines is not formalized.', assumptions=['A-LOADER', 'X11-KERNEL']),
    dict(id='X9', chain='X', frm="model I/O events", to='bytes on descriptor 1', claimed='MISSING', about='MODEL',
         statement='L-OUT.', assumptions=[]),
    dict(id='X9-LO', chain='X', frm='model I/O events', to='L-OUT attempt', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X9',
         statement='L-OUT attempt 0001.', hol=dict(case='LO-0001'), assumptions=['HOL-TCB']),
    dict(id='X10', chain='X', frm="model halt", to='process exit status', claimed='MISSING', about='DEPLOYED',
         statement='L-EXIT; exit status 0 does not imply success.', assumptions=['STRICT-FRAME']),
    dict(id='X11', chain='X', frm='processor and kernel', to='L3 model, interference_ok', claimed='ASSUMPTION', about='DEPLOYED',
         statement='Every route ends at a named kernel assumption.', assumptions=['X11-KERNEL']),
    dict(id='X11e', chain='X', frm='real registers (TBI0, SA0 = 1)', to='erased model state', claimed='MISSING', about='MODEL',
         statement='Erasure soundness (E1) not run.', assumptions=['X5-ENTRY']),
    dict(id='X12', chain='X', frm='real executable runs', to="model's output", claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='2,466 vectors, 0 findings (Wave Gate 1).', evidence=[CONF, EXE], assumptions=['A-LOADER']),
    dict(id='X13', chain='X', frm='output bytes', to='no strict prefix parses', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='8,011 strict prefixes, 0 accepted (worker run); HOL prefix lemma not proved.', assumptions=['STRICT-FRAME']),
    dict(id='X13-PF', chain='X', frm='output bytes', to='prefix lemma attempt', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X13',
         statement='Prefix lemma attempt 0001.', hol=dict(case='PF-0001'), assumptions=['HOL-TCB']),
    dict(id='X14', chain='X', frm='full output', to='six fields', claimed='MACHINE-CHECKED', about='MODEL',
         statement='refund_render_fields_roundtrip (M1R-1 T06).', hol_prior=[M1R + '/logs/T06-forge_refundWireProg.log'], assumptions=['HOL-TCB']),
    dict(id='X15', chain='X', frm='process result', to="caller's decision", claimed='MISSING', about='DEPLOYED',
         statement='No consumer of M1 output in the repository.', assumptions=['STRICT-FRAME']),
    dict(id='X16', chain='X', frm='M1 decision', to='authorization token', claimed='MISSING', about='DEPLOYED',
         statement='The issuer calls the compiled Dafny checker, not M1.', assumptions=[]),
    # ---- chain U: token -> committed state
    dict(id='U1', chain='U', frm='request and candidate transition', to='RefundFinality.Check (P1-P4)', claimed='MACHINE-CHECKED', about='DEPLOYED',
         statement='The source of impl/RefundFinality.dfy verifies (inside the sink-core closure; copy equal to the repository file).',
         fr='sink-core', required=['RefundFinality.Check'], assumptions=['DAFNY-Z3-TCB'], evidence=[SLICE1]),
    dict(id='U1c', chain='U', frm='impl/RefundFinality.dfy', to='compiled JavaScript core', claimed='ASSUMPTION', about='DEPLOYED',
         statement='source_to_module_proved=false (Slice 1 record); generated JS digest 721b4d06... is regenerated, not stored.',
         assumptions=['DAFNY-JS'], evidence=[SLICE1]),
    dict(id='U2', chain='U', frm='Check result', to='signed token (minter.ts)', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Slice 1 suite, 115 rows.', evidence=[SLICE1, 'ts/refund-finality/minter.ts'], assumptions=['A2-ISSUANCE', 'NODE-RT']),
    dict(id='U3', chain='U', frm='token', to='commit in sink.ts', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Slice 1 suite; sink.ts does NOT check intent.requestId against the token (d-reqid; Contrast.UnpatchedGap).',
         evidence=[SLICE1, 'ts/refund-finality/sink.ts', 'ts/refund-finality/encoding.ts'],
         assumptions=['H3a-SER-INJECTIVE', 'H3b-SINK-REBUILDS', 'B5-CRYPTO-BOOLEAN', 'NODE-RT']),
    dict(id='U4', chain='U', frm='protocol model', to='its invariant', claimed='MACHINE-CHECKED', about='MODEL',
         statement='CommitPreservesInv, MintPreservesInv (FinalityProtocol, inside the sink-core closure; copy equal to the F2.0 file).',
         fr='sink-core', required=['FinalityProtocol.CommitPreservesInv', 'FinalityProtocol.MintPreservesInv'],
         assumptions=['A1-IDEALMAC', 'A2-ISSUANCE', 'A3-ATOMIC-COMMIT', 'A4-HASH']),
    dict(id='U5a', chain='U', frm='model', to='Dafny sink core (merged shape)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SinkCore refines FinalityProtocol: StepRefinesCommit, StepPreservesInv, ZeroAmountRepeats (56 verified).',
         fr='sink-core', required=['SinkCore.StepRefinesCommit', 'SinkCore.StepPreservesInv', 'SinkCore.ZeroAmountRepeats', 'SinkCore.InitRel'],
         assumptions=['A1-IDEALMAC', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH']),
    dict(id='U5a-W', chain='U', frm='sink core', to='non-vacuity witness', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SinkCoreW.WitnessRun: the hypotheses hold in a concrete run where a refund commits.',
         fr='sink-core-witness', required=['SinkCoreW.WitnessRun', 'SinkCoreW.WitMinterSound'], assumptions=['A1-IDEALMAC']),
    dict(id='U5a-ATTACK', chain='U', frm='IdealMac (A1)', to='not realizable', claimed='MACHINE-CHECKED', about='MODEL',
         statement='Attack.TotalVerifierBreaksIdealMac: a total verifier breaks IdealMac; A1 cannot be met by a real signature scheme.',
         fr='sink-core-attack', required=['Attack.TotalVerifierBreaksIdealMac', 'Attack.IdealMacAtInit', 'Attack.LocalA1Suffices'],
         extra_runs=[R(NS + '/smoke/attack.log', 'orchestrator B re-run (smoke)', NS + '/smoke/inputs', 'sink/Attack.dfy')],
         assumptions=[]),
    dict(id='U5b', chain='U', frm='Dafny sink core', to='ts/refund-finality/sink.ts', claimed='MISSING', about='DEPLOYED',
         statement='No proof and no generated sink; by reading sink.ts lacks the request-id check.', assumptions=[]),
    dict(id='U5r', chain='U', frm='model', to='patched Dafny sink core with request-id check (DRAFT, not deployed)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SinkCoreReqId: MismatchNeverCommits, RunKeepsGood, FromInitGood, StepExact with NO signature assumption; StepRefinesModelStep under A5 only.',
         runs=[R(NS + '/d-reqid/logs/v02-reqid-verify.log', 'worker d-reqid', NS + '/d-reqid/dafny/inputs', 'sink/SinkCoreReqId.dfy', NS + '/d-reqid/logs/v02-reqid-verify.csv'),
               R(NS + '/d-reqid/recheck/SinkCoreReqId.log', 'orchestrator B re-run', NS + '/d-reqid/dafny/inputs', 'sink/SinkCoreReqId.dfy'),
               R(NS + '/r-reqid/logs/r01-reqid-verify.log', 'reviewer r-reqid', NS + '/r-reqid/dafny/inputs', 'sink/SinkCoreReqId.dfy', NS + '/r-reqid/logs/r01-reqid-verify.csv')],
         required=REQID_REQ, assumptions=['A5-VERIFIER-MATCH', 'GOODSTART']),
    dict(id='U5r-CONTRAST', chain='U', frm='merged-shape core', to='request-id gap (counterexample)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='UnpatchedGap, UnpatchedBreaksGood: two intents with one request id both commit in the unpatched core; the patched core refuses the trace.',
         runs=[R(NS + '/d-reqid/logs/v03-contrast-verify.log', 'worker d-reqid', NS + '/d-reqid/dafny/inputs', 'sink/Contrast.dfy', NS + '/d-reqid/logs/v03-contrast-verify.csv'),
               R(NS + '/d-reqid/recheck/Contrast.log', 'orchestrator B re-run', NS + '/d-reqid/dafny/inputs', 'sink/Contrast.dfy'),
               R(NS + '/r-reqid/logs/r03-contrast-verify.log', 'reviewer r-reqid', NS + '/r-reqid/dafny/inputs', 'sink/Contrast.dfy', NS + '/r-reqid/logs/r03-contrast-verify.csv')],
         required=CONTRAST_REQ, assumptions=[]),
    dict(id='U5r-REVIEW', chain='U', frm='patched core', to='residual gaps (review)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='ReqIdAttack: cross-charge token and foreign post-state still pass the request-id patch; an upgrade after the gap still duplicates.',
         runs=[R(NS + '/r-reqid/logs/r12-attack-verify.log', 'reviewer r-reqid', NS + '/r-reqid/dafny/inputs', 'sink/Attack.dfy', NS + '/r-reqid/logs/r12-attack-verify.csv')],
         required=ATTACK2_REQ, assumptions=[]),
    dict(id='U5r-JS', chain='U', frm='SinkCoreReqId.dfy', to='compiled JS (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='dafny build --target js verifies (88 verified, inherited lemmas included) and emits sinkcore-reqid.js; the JS itself is not proved (DAFNY-JS).',
         runs=[R(NS + '/d-reqid/logs/v04-reqid-build.log', 'worker d-reqid', NS + '/d-reqid/dafny/inputs', 'sink/SinkCoreReqId.dfy', NS + '/d-reqid/logs/v04-reqid-build.csv', role='build')],
         required=['SinkCoreReqId.MismatchNeverCommits', 'SinkCoreReqId.RunKeepsGood'], artifacts=[NS + '/d-reqid/build/sinkcore-reqid.js'],
         assumptions=['DAFNY-JS']),
    dict(id='U5c', chain='U', frm='patched core', to='core-backed shell step (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='ShellCoreReqId: StepPAgrees, StepPRefinesModelStep, Witness (77 verified).',
         runs=[R(NS + '/d-corebacked/logs/v01-shellreqid-verify.log', 'worker d-corebacked', NS + '/d-corebacked/dafny/inputs', 'sink/ShellCoreReqId.dfy', NS + '/d-corebacked/logs/v01-shellreqid-verify.csv')],
         required=SHELL_REQ, assumptions=['A5-VERIFIER-MATCH', 'GOODSTART']),
    dict(id='U5c-JS', chain='U', frm='ShellCoreReqId.dfy', to='compiled JS used by sink_core_backed.ts (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='dafny build --target js verifies (92 verified) and emits shellcore-reqid.js; the JS is not proved.',
         runs=[R(NS + '/d-corebacked/logs/v03-shellreqid-build.log', 'worker d-corebacked', NS + '/d-corebacked/dafny/inputs', 'sink/ShellCoreReqId.dfy', NS + '/d-corebacked/logs/v03-shellreqid-build.csv', role='build')],
         required=['ShellCoreReqId.StepPAgrees'], artifacts=[NS + '/d-corebacked/build/shellcore-reqid.js', NS + '/d-corebacked/build/shellcore-reqid.cjs'],
         assumptions=['DAFNY-JS']),
    dict(id='U5c-CONF', chain='U', frm='compiled shell core', to='draft sink_core_backed.ts behaviour', claimed='TESTED-UNPROVED', about='DRAFT',
         statement='Two conformance runs (Node, single runs) agree with the expected outcomes.',
         evidence=[NS + '/d-corebacked/logs/n02-conformance-1.log', NS + '/d-corebacked/logs/n03-conformance-2.log', NS + '/d-corebacked/sink_core_backed.ts'],
         assumptions=['DAFNY-JS', 'NODE-RT']),
    dict(id='U6', chain='U', frm='Ed25519 and key secrecy', to='H1 / H1B', claimed='ASSUMPTION', about='DEPLOYED',
         statement='EUF-CMA and key secrecy.', assumptions=['H1-EUF-CMA', 'H1B-BYTES']),
    dict(id='U7', chain='U', frm='commit', to='durable committed state', claimed='ASSUMPTION', about='DEPLOYED',
         statement='Process crash TESTED (486 kills, worker run); power loss ASSUMPTION (SQLite defaults).', assumptions=['A3-ATOMIC-COMMIT', 'NODE-RT']),
    dict(id='U8', chain='U', frm='approved spec', to='no second authorization', claimed='MISSING', about='DEPLOYED',
         statement='The approved spec has no state; ZeroAmountRepeats shows two zero-amount claims commit (zero is legitimate).', assumptions=[]),
    # ---- composed theorems (tonight)
    dict(id='T-V1', chain='T', frm='slice', to='Committed => ApprovedSpec /\\ ValidArtifact /\\ UniqueAuthorization (model)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SliceTheorem.SliceSafety under A1 IdealMac (unrealizable) and A6 (all strings).',
         fr='slice-theorem', required=['SliceTheorem.SliceSafety', 'SliceWitness.Witness'],
         extra_runs=[R(NS + '/recheck-f/slice-theorem.log', 'orchestrator B re-run', FR + '/checkout/' + PROP + '/proofs/slice-theorem/inputs', 'SliceTheorem.dfy')],
         binds_approved=True, assumptions=['A1-IDEALMAC', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'A6-ALL-STRINGS', 'INITOK']),
    dict(id='T-V2', chain='T', frm='slice', to='same target without IdealMac', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SliceSafetyV2 and UniqueAuthorizationV2 under InitOk, A2, A5, H1 (claim level, step-local), A6; MainWitness non-vacuous; dropping H1, A2 or A6 breaks it.',
         runs=[R(NS + '/b-signing/logs/final-V2-01.log', 'worker b-signing', NS + '/b-signing', 'SliceSafetyV2.dfy', NS + '/b-signing/logs/final-V2-01.csv'),
               R(NS + '/r-signing/logs/rerun-V2.log', 'reviewer r-signing', NS + '/r-signing/work', 'SliceSafetyV2.dfy', NS + '/r-signing/logs/rerun-V2.csv')],
         required=V2_REQ, binds_approved=True,
         assumptions=['INITOK', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'H1-EUF-CMA', 'A6-ALL-STRINGS']),
    dict(id='T-V2B', chain='T', frm='slice', to='same target with A6b (byte strings)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SliceSafetyV2OnByteStrings: V2 with A6b in place of A6; A6 implies A6b; a wide artifact that meets A6b but not A6 is still covered.',
         runs=[R(NS + '/b-signing/logs/final-V2OnBytes-01.log', 'worker b-signing', NS + '/b-signing', 'SliceSafetyV2OnBytes.dfy', NS + '/b-signing/logs/final-V2OnBytes-01.csv'),
               R(NS + '/recheck-b/SliceSafetyV2OnBytes.log', 'orchestrator B re-run', NS + '/b-signing', 'SliceSafetyV2OnBytes.dfy', NS + '/recheck-b/SliceSafetyV2OnBytes.csv'),
               R(NS + '/r-signing/logs/rerun-V2OnBytes.log', 'reviewer r-signing', NS + '/r-signing/work', 'SliceSafetyV2OnBytes.dfy', NS + '/r-signing/logs/rerun-V2OnBytes.csv')],
         required=V2B_REQ, binds_approved=True,
         assumptions=['INITOK', 'A2-ISSUANCE', 'H1B-BYTES', 'H3a-SER-INJECTIVE', 'H3b-SINK-REBUILDS', 'H3c-VERIFYTAG-IS-BYTES', 'B5-CRYPTO-BOOLEAN', 'A6b-BYTES']),
    dict(id='T-TOTAL', chain='T', frm='total verifier reading', to='hypotheses consistent without IdealMac', claimed='MACHINE-CHECKED', about='MODEL',
         statement='TotalReading: under a total verifier the V2 reading holds and IdealMac is false (34 verified).',
         runs=[R(NS + '/b-signing/logs/final-Total-01.log', 'worker b-signing', NS + '/b-signing', 'TotalReading.dfy', NS + '/b-signing/logs/final-Total-01.csv'),
               R(NS + '/recheck-b/TotalReading.log', 'orchestrator B re-run', NS + '/b-signing', 'TotalReading.dfy'),
               R(NS + '/r-signing/logs/rerun-Total.log', 'reviewer r-signing', NS + '/r-signing/work', 'TotalReading.dfy', NS + '/r-signing/logs/rerun-Total.csv')],
         required=TOTAL_REQ, assumptions=[]),
    dict(id='T-V3', chain='T', frm='slice', to='layered theorem on the patched core with several charges (b-integrate)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SinkCoreV3 (worker b-integrate running at generation time); emitted only from a final log.',
         runs=[R(NS + '/b-integrate/logs/final-core-01.log', 'worker b-integrate', NS + '/b-integrate', 'SinkCoreV3.dfy', NS + '/b-integrate/logs/final-core-01.csv')],
         required=['SinkCoreV3.AuditStartIsGoodStart'], assumptions=['GOODSTART', 'A5-VERIFIER-MATCH'], pending=True),
    # ---- chain V: identity
    dict(id='V1', chain='V', frm='HOL constants for code and bitmaps', to='two slices of the executable', claimed='MACHINE-CHECKED', about='DEPLOYED',
         statement='forge_refundImage (M1R-1 C42); file reader and offsets outside HOL.', hol_prior=[M1R + '/logs/C42-image-0001.stdout.log'],
         evidence=[EXE], assumptions=['HOL-TCB', 'Q3C-READER']),
    dict(id='V2', chain='V', frm='rest of the file, dyld, libSystem', to='anything', claimed='MISSING', about='DEPLOYED',
         statement='C run-time, stubs, GOT binds, __LINKEDIT: whole-file hash only.', assumptions=['A-LOADER']),
    dict(id='V3', chain='V', frm='final theorem', to='541 ancestor theories by content', claimed='TESTED-UNPROVED', about='MODEL',
         statement='SHA-1 chain walk, 0 mismatches (worker run).', assumptions=['HOL-TCB']),
    dict(id='V4', chain='V', frm='final statement', to='definitions under it', claimed='MISSING', about='MODEL',
         statement='The import check compares statement text only.', assumptions=['HOL-TCB']),
    dict(id='V5', chain='V', frm='recorded hashes', to='independently computed values', claimed='MISSING', about='GOVERNANCE',
         statement='Every reference value is from the same agent family on the same machine (this ledger included).', assumptions=[]),
    dict(id='V6', chain='V', frm='executable', to='what is run or deployed', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='A SHA-256 assert in scripts.', evidence=[EXE], assumptions=['A-LOADER', 'ADMISSION']),
    dict(id='V7', chain='V', frm='all of the above', to='one answer', claimed='TESTED-UNPROVED', about='GOVERNANCE',
         statement='This ledger and its verifier: identity and record consistency only; controls in controls-result.json.', assumptions=[]),
    # ---- chain E: enforcement
    dict(id='E1', chain='E', frm='new code', to='gate verdict', claimed='MISSING', about='GOVERNANCE', statement='Gate answered UNSUPPORTED for the new files.', assumptions=['ADMISSION']),
    dict(id='E2', chain='E', frm='gate verdict', to='merge', claimed='MISSING', about='GOVERNANCE', statement='main is not protected.', assumptions=['ADMISSION']),
    dict(id='E3', chain='E', frm='change of a protected file', to='refusal', claimed='MACHINE-CHECKED', about='GOVERNANCE',
         statement='Hosted run 44454558079 REJECTED: a ROADMAP sentence only; no stored log.', assumptions=['ADMISSION'], no_log=True),
    dict(id='E4', chain='E', frm='checker, prover, deployer', to='three trust domains', claimed='MISSING', about='GOVERNANCE', statement='One account with admin rights.', assumptions=['ADMISSION']),
    dict(id='E5', chain='E', frm='merge', to='protected state', claimed='MISSING', about='GOVERNANCE', statement='No admission check exists.', assumptions=['ADMISSION']),
]

MANDATORY = ['S1', 'S2', 'S3', 'S3a', 'S4', 'S5', 'S6', 'S7', 'X1', 'X2', 'X3', 'X5', 'X6', 'X7', 'X8', 'X9', 'X10', 'X12', 'X15',
             'X16', 'U1', 'U1c', 'U2', 'U3', 'U4', 'U5a', 'U5b', 'U6', 'U7', 'U8', 'V1', 'V2', 'V6', 'E1', 'E2',
             'T-V2', 'T-V2B', 'T-TOTAL', 'U5r', 'U5r-CONTRAST']
# The order of the chain in COMPOSED_GUARANTEE.md: approved contract -> durable committed state.
CHAIN_ORDER = ['S1', 'S2', 'S3', 'S3a', 'S4', 'S7', 'S5', 'S6', 'S8', 'X1', 'X2', 'X5', 'X6', 'X7', 'X11', 'X3', 'X4', 'X8', 'X9', 'X10',
               'X13', 'X14', 'X15', 'X16', 'U1', 'U1c', 'U2', 'U6', 'U3', 'U5b', 'U5a', 'U4', 'U7']


def git_tracked(repo):
    try:
        out = subprocess.run(['git', '-C', str(repo), 'ls-files', '-z'], capture_output=True, check=True).stdout
        return set(out.decode().split('\0'))
    except Exception:
        return set()


class Gen:
    def __init__(self, repo):
        self.repo = Path(repo).resolve()
        self.tree = L.Tree(self.repo)
        self.fr = L.load_frecords(self.repo)
        self.recs = json.loads(self.tree.text(FR + '/PROOF_RECORDS.json'))
        self.tracked = git_tracked(self.repo)
        self.nodes = {}
        self.tmp = Path(__file__).resolve().parent / 'tmp'
        self.tmp.mkdir(exist_ok=True)
        self.dafny_version = self.recs['environment']['dafny_version_from_lock_logs'][0]
        self.approved = {}

    def kind_of(self, rel):
        if rel in APPROVED:
            return 'approved spec'
        if rel.endswith(('.log', '.csv', '.json', '.txt', '.md')) and not rel.startswith('spec'):
            return 'record'
        if rel.endswith('.sexp'):
            return 'exported contract'
        if rel.endswith(('.js', '.cjs')):
            return 'compiler artifact'
        if rel == EXE:
            return 'machine code'
        if rel.endswith('.ts'):
            return 'runtime code'
        if rel.endswith('.py'):
            return 'tool'
        return 'proof source'

    def node(self, rel, kind=None, **extra):
        if not self.tree.exists(rel):
            return None
        if rel not in self.nodes:
            n = dict(path=rel, sha256=self.tree.sha(rel), kind=kind or self.kind_of(rel),
                     storage='tracked' if rel in self.tracked else 'untracked')
            for a, h in self.approved.items():
                if n['sha256'] == h and rel != a:
                    n['copy_of'] = a
            n.update(extra)
            self.nodes[rel] = n
        return self.nodes[rel]

    def closure(self, root, entry, overlay=None, derive=None):
        rows, missing = L.closure_of(self.tree, self.fr, root, entry, overlay, derive, tmpbase=self.tmp)
        return rows, missing

    def check_run(self, run, edge_closure):
        """Fills run fields; returns a list of problems (empty = supporting run)."""
        probs = []
        log = run['log']
        if L.Tree(self.repo).safe_rel(log) is None:
            return ['log path outside the repository tree']
        if not self.tree.exists(log):
            run['log_present'] = False
            return ['log missing']
        text = self.tree.text(log)
        run['log_present'] = True
        run['log_sha256'] = self.tree.sha(log)
        form, ex = L.parse_exit(text)
        run['exit_line_form'], run['exit'] = form, ex
        if ex is None:
            probs.append('no exit line')
        elif ex != 0:
            probs.append('exit %d' % ex)
        cmd = L.header(text, 'cmd')
        run['cmd'] = ('dafny ' + L.relativize(cmd, self.repo)) if cmd else None
        ver = L.header(text, 'dafny')
        run['checker_version'] = ver
        if ver != self.dafny_version:
            probs.append('dafny version %r' % ver)
        if Path(run['entry']).name not in L.cmd_dfy_files(cmd):
            probs.append('# cmd: names %s, not %s' % (L.cmd_dfy_files(cmd), run['entry']))
        if run.get('csv'):
            if self.tree.exists(run['csv']):
                run['csv_sha256'] = self.tree.sha(run['csv'])
            else:
                probs.append('csv missing')
        try:
            same = run['root'] == edge_closure.get('root')
            rows, missing = self.closure(run['root'], run['entry'], edge_closure.get('overlay') if same else None,
                                         edge_closure.get('derive') if same else None)
            run['closure_digest'] = L.set_digest(rows)
            if missing:
                probs.append('closure missing %s' % missing)
        except Exception as e:
            probs.append('closure error %s' % e)
            run['closure_digest'] = None
        if edge_closure.get('digest') and run['closure_digest'] != edge_closure['digest']:
            probs.append('closure digest differs from the edge closure (bytes changed since the run, or another copy)')
        return probs

    def dafny_edge(self, e, out):
        if e.get('fr'):
            p = self.recs['proofs'][e['fr']]
            overlay, derive = {}, {}
            for d in p['derived_or_added_files']:
                if d['how'].startswith('copied from '):
                    overlay[d['path']] = d['how'][len('copied from '):]
                elif d['how'].startswith('classic diff '):
                    derive[d['path']] = dict(kind='classic-diff', diff=d['how'].split()[2], base_sha256=d['base_sha256'], result_sha256=d['result_sha256'])
            runs = fr_runs(e['fr'], self.recs, e.get('extra_runs', []))
            fr_digest = p['closure_digest']
        else:
            overlay, derive, runs, fr_digest = {}, {}, [dict(r) for r in e['runs']], None
        prim = runs[0]
        clo = dict(root=prim['root'], entry=prim['entry'], overlay=overlay or None, derive=derive or None)
        rows, missing = self.closure(prim['root'], prim['entry'], overlay, derive)
        clo.update(files=[dict(path=p_, sha256=h) for p_, h in rows], count=len(rows), digest=L.set_digest(rows), missing=missing)
        if fr_digest:
            clo['f_records_closure_digest'] = fr_digest
            clo['f_records_proof'] = e['fr']
        out['closure'] = clo
        for f in rows:
            rp = prim['root'] + '/' + f[0]
            if f[0] not in (overlay or {}) and f[0] not in (derive or {}):
                self.node(rp)
        for cpath, rpath in (overlay or {}).items():
            self.node(rpath)
        for cpath, d in (derive or {}).items():
            self.node(d['diff'])
        supporting, other, reasons = [], [], []
        for i, r in enumerate(runs):
            r = dict(r)
            probs = self.check_run(r, clo)
            if r.get('csv') and r.get('csv_sha256') and e.get('required'):
                bad = L.check_required(self.tree.path(r['csv']), e['required'])
                if bad:
                    probs.append('required lemmas: %s' % bad)
            if fr_digest and clo['digest'] != fr_digest:
                probs.append('closure digest differs from PROOF_RECORDS')
            if i == 0 and not r.get('csv'):
                probs.append('primary run has no CSV')
            if probs:
                r['not_counted_because'] = probs
                other.append(r)
                if i == 0:
                    reasons = probs
            else:
                supporting.append(r)
                self.node(r['log'])
                if r.get('csv'):
                    self.node(r['csv'])
        out['runs'] = supporting
        out['runs_not_counted'] = other
        out['checker'] = dict(name='Dafny (dafny_locked.sh, gate options)', version=self.dafny_version,
                              z3_sha256=self.recs['environment']['z3_sha256'], dafny_launcher_sha256=self.recs['environment']['dafny_launcher_sha256'])
        out['command'] = supporting[0]['cmd'] if supporting else (other[0].get('cmd') if other else None)
        out['required_lemmas'] = e.get('required', [])
        if reasons or not supporting:
            out['class'] = 'CLAIMED, log missing'
            out['downgrade_reason'] = reasons or ['no supporting run']
            if e.get('pending'):
                out['class'] = 'MISSING'
                out['downgrade_reason'] = ['worker still running at generation time; no final log'] + (reasons or [])
        else:
            out['class'] = 'MACHINE-CHECKED'
        for a in e.get('artifacts', []):
            n = self.node(a, 'compiler artifact')
            if n:
                out.setdefault('artifacts', []).append(a)

    def hol_edge(self, e, out):
        case = e['hol']['case']
        log, src, hashes, runj = RA + '/%s.go.log' % case, RA + '/%s.sml' % case, RA + '/%s.hashes.json' % case, RA + '/%s.run.json' % case
        out['checker'] = dict(name='HOL4 (Poly/ML), run by Orchestrator A through go-routeA.sh', version='as recorded in %s (not read by this ledger)' % (RA + '/' + case + '/command.json'))
        out['ran_by'] = 'Orchestrator A (reported by Orchestrator A; not re-checked by B)'
        if not self.tree.exists(log):
            out['class'] = 'UNKNOWN-TONIGHT'
            out['downgrade_reason'] = ['A go log %s absent' % log]
            return
        form, ex = L.parse_exit(self.tree.text(log))
        run = dict(log=log, log_sha256=self.tree.sha(log), exit=ex, exit_line_form=form, ran_by=out['ran_by'], role='hol-case')
        out['command'] = 'FORGE_CPU_SECONDS=<n> ./go-routeA.sh %s %s.sml deps-<x>.txt  (in %s)' % (case, case, RA)
        rows = []
        for f in (src, hashes, runj):
            if self.tree.exists(f):
                rows.append((f, self.tree.sha(f)))
                self.node(f)
        out['closure'] = dict(kind='HOL case: source + parent-hash record + run record (parents themselves: see hashes.json)',
                              files=[dict(path=p, sha256=h) for p, h in rows], count=len(rows), digest=L.set_digest(rows))
        if self.tree.exists(runj):
            rj = json.loads(self.tree.text(runj))
            run['source_sha256_in_run_json'] = rj.get('source_sha256')
            run['actual_exit_in_run_json'] = rj.get('actual_exit')
        if ex is None:
            out['class'] = 'UNKNOWN-TONIGHT'
            out['downgrade_reason'] = ['A go log has no exit line']
            out['runs_not_counted'] = [run]
        elif ex != 0:
            out['class'] = 'MISSING'
            out['downgrade_reason'] = ['attempt failed: A go log says exit %d' % ex]
            out['runs_not_counted'] = [run]
            self.node(log)
        else:
            out['class'] = 'MACHINE-CHECKED'
            out['runs'] = [run]
            self.node(log)

    def build(self):
        for a in APPROVED:
            n = self.node(a, 'approved spec')
            self.approved[a] = n['sha256']
        s1 = json.loads(self.tree.text(SLICE1))['approved_inputs_sha256']
        for a in APPROVED:
            if a in s1:
                self.nodes[a]['slice1_recorded_sha256'] = s1[a]
                self.nodes[a]['equals_slice1_record'] = (s1[a] == self.nodes[a]['sha256'])
        for p in [SLICE1, CONF, EXE, EXPORT_OUT, EXPORT_IN, EXPORT_REC, FR + '/PROOF_RECORDS.json', FR + '/reproduce_dafny_proofs.py',
                  'ts/refund-finality/sink.ts', 'ts/refund-finality/minter.ts', 'ts/refund-finality/encoding.ts',
                  'ts/refund-finality/dispatcher.ts', 'impl/Refund.dfy', 'impl/RefundFinality.dfy',
                  'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy', NS + '/tools/dafny_locked.sh',
                  NS + '/b-signing/SliceSafetyV2.dfy', NS + '/b-signing/SliceSafetyV2OnBytes.dfy', NS + '/b-signing/TotalReading.dfy',
                  NS + '/d-reqid/dafny/inputs/sink/SinkCoreReqId.dfy', NS + '/d-reqid/dafny/inputs/sink/Contrast.dfy',
                  NS + '/d-corebacked/dafny/inputs/sink/ShellCoreReqId.dfy', NS + '/d-corebacked/sink_core_backed.ts',
                  NS + '/r-reqid/dafny/inputs/sink/Attack.dfy', OA + '/STATE.md', OA + '/review-L1/REPORT.md']:
            self.node(p)
        edges = []
        for i, e in enumerate(EDGES):
            out = dict(id=e['id'], chain=e['chain'], order=i, frm=e['frm'], to=e['to'], statement=e['statement'],
                       claimed_class=e['claimed'], about=e['about'], assumptions=e.get('assumptions', []))
            if e.get('sub_of'):
                out['sub_of'] = e['sub_of']
            if e.get('binds_approved'):
                out['binds_approved_spec'] = True
            if e['claimed'] == 'MACHINE-CHECKED' and (e.get('fr') or e.get('runs')):
                self.dafny_edge(e, out)
            elif e.get('hol'):
                self.hol_edge(e, out)
            elif e.get('hol_prior'):
                out['class'] = 'UNKNOWN-TONIGHT'
                out['downgrade_reason'] = ['HOL record of an earlier run (JSON actual_exit or a log without an exit line); '
                                           "Orchestrator A's files state no exit code for this case tonight"]
                out['prior_records'] = []
                for p in e['hol_prior']:
                    n = self.node(p)
                    rec = dict(path=p, present=bool(n), sha256=n['sha256'] if n else None)
                    if n and p.endswith('command.json'):
                        rec['recorded_actual_exit'] = json.loads(self.tree.text(p)).get('actual_exit')
                    out['prior_records'].append(rec)
                out['ran_by'] = 'earlier run (M1R-1 or U294); not tonight'
            elif e['claimed'] == 'MACHINE-CHECKED':
                out['class'] = 'CLAIMED, log missing'
                out['downgrade_reason'] = ['no stored log for this run']
            else:
                out['class'] = e['claimed']
            if e.get('a_case'):
                out['a_note'] = e['a_case']['note']
            out['evidence'] = [p for p in e.get('evidence', []) if self.node(p)]
            out['evidence_missing'] = [p for p in e.get('evidence', []) if not self.tree.exists(p)]
            edges.append(out)
        used = {}
        for ed in edges:
            for a in ed['assumptions']:
                used.setdefault(a, []).append(ed['id'])
        assumptions = [dict(id=i, text=t, real_world=rw, realizable=rz, used_by=used.get(i, [])) for i, t, rw, rz in ASSUMPTIONS]
        counts = {c: sum(1 for ed in edges if ed['class'] == c) for c in L.CLASSES}
        led = dict(
            schema='forge.nightshift.assurance-ledger/1',
            what_a_pass_means=L.BANNER_IDENTITY + '. A pass of verify_ledger.py shows that the stored bytes, logs and records '
                              'agree with each other now. It does not show that a theorem is true, that it means what its statement says, or '
                              'that a reference value was computed by an independent party (V5).',
            repository_commit=subprocess.run(['git', '-C', str(self.repo), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip(),
            generated_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            generator='results/night-shift-20261119/orch-B/f-binding/make_ledger.py',
            closure_rule='include_closure() of orch-B/f-records/reproduce_dafny_proofs.py; set digest = SHA-256 of sorted "path<TAB>sha256<LF>" lines',
            exit_line_rule='last non-empty line `exit N` (dafny_locked.sh) or `go exit N` (Orchestrator A HOL wrapper)',
            checker_versions=dict(dafny=self.dafny_version, z3=self.recs['environment']['z3_version'],
                                  z3_sha256=self.recs['environment']['z3_sha256'], dafny_launcher_sha256=self.recs['environment']['dafny_launcher_sha256']),
            mandatory_edges=MANDATORY, chain_order=CHAIN_ORDER, counts=counts,
            nodes=sorted(self.nodes.values(), key=lambda n: n['path']), assumptions=assumptions, edges=edges)
        return led


def md(led):
    o = ['# Assurance ledger, refund slice (generated; do not edit)', '',
         '**%s.** Generated %s from commit `%s` by `make_ledger.py`. Source of truth: `ASSURANCE_LEDGER.json`.' % (
             L.BANNER_IDENTITY, led['generated_utc'], led['repository_commit'][:12]), '',
         'Counts: ' + ', '.join('%s %d' % (k, v) for k, v in led['counts'].items()), '',
         '## Edges', '', '| Id | Chain | From -> To | Class (claimed) | About | Evidence (log: exit; by) | Closure | Assumptions |', '|---|---|---|---|---|---|---|---|']
    for e in led['edges']:
        ev = '; '.join('`%s`: %s; %s' % (r['log'].split('/orch-B/')[-1], r.get('exit'), r.get('ran_by')) for r in e.get('runs', []))
        if not ev and e.get('prior_records'):
            ev = 'prior: ' + '; '.join('`%s`%s' % (p['path'].split('/')[-1], ' actual_exit=%s' % p['recorded_actual_exit'] if 'recorded_actual_exit' in p else '') for p in e['prior_records'])
        if e.get('downgrade_reason'):
            ev += ' **[%s]**' % '; '.join(map(str, e['downgrade_reason']))[:220]
        clo = ('%d files `%s`' % (e['closure']['count'], e['closure']['digest'][:12])) if e.get('closure') else '-'
        o.append('| %s | %s | %s -> %s | %s (%s) | %s | %s | %s | %s |' % (
            e['id'], e['chain'], e['frm'], e['to'], e['class'], e['claimed_class'], e['about'], ev or '-', clo, ', '.join(e['assumptions']) or '-'))
    o += ['', '## Assumptions', '', '| Id | Text | Real-world reading | Realizable | Used by |', '|---|---|---|---|---|']
    for a in led['assumptions']:
        o.append('| %s | %s | %s | %s | %s |' % (a['id'], a['text'], a['real_world'], a['realizable'], ', '.join(a['used_by']) or '-'))
    o += ['', '## Nodes (%d)' % len(led['nodes']), '', '| Path | Kind | SHA-256 | Storage |', '|---|---|---|---|']
    for n in led['nodes']:
        o.append('| `%s` | %s%s | `%s` | %s |' % (n['path'], n['kind'], ' (copy of %s)' % n['copy_of'] if n.get('copy_of') else '', n['sha256'], n['storage']))
    return '\n'.join(o) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=str(L.DEFAULT_REPO))
    ap.add_argument('--out', default=str(Path(__file__).resolve().parent))
    a = ap.parse_args()
    led = Gen(a.repo).build()
    out = Path(a.out)
    (out / 'ASSURANCE_LEDGER.json').write_text(json.dumps(led, indent=1) + '\n')
    (out / 'ASSURANCE_LEDGER.md').write_text(md(led))
    print('counts', led['counts'])
    for e in led['edges']:
        if e.get('downgrade_reason'):
            print('DOWNGRADED', e['id'], e['class'], e['downgrade_reason'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
