#!/usr/bin/env python3
"""Generate ASSURANCE_LEDGER.json and ASSURANCE_LEDGER.md (night shift 2026-11-19, Orchestrator B, task f-binding;
refreshed by task f-binding-2 with the results of the night up to 09:24Z; rules unchanged, HOL checks extended;
refreshed by task f-binding-3 with the results up to 10:19Z: no rule removed or weakened; added [f3]: several closure
roots per run (the `# cmd:` .dfy set must equal the root set), exploration runs (EXPLORE_COMPLETE) never count, an
edge may name `superseded_by` only for a MACHINE-CHECKED edge, review-pending and source markers; refreshed by task
f-binding-4 with the results up to 11:10Z: no rule removed or weakened; added [f4]: review state as data (`reviewed`
true/false/pending; a reviewed edge names a REPORTED review directory), `rests_on` edge references, and the rule that a
superseded edge may not be the only support of another edge (generator refuses; verifier SUPERSEDED_SOLE_SUPPORT).

Python 3 standard library only. It runs no prover. It reads stored logs, CSVs and records, recomputes digests and
include closures, and writes one ledger of the refund slice: approved spec -> durable committed state.

Fail closed: an edge is emitted as MACHINE-CHECKED only if its primary log exists inside the repository tree, its
last line is an accepted exit line with exit 0, its `# cmd:` header names the closure entry, the required lemma rows
of its CSV are present and Passed, and the closure recomputed now has the digest recorded for the run. Otherwise the
edge is emitted as "CLAIMED, log missing" with a `downgrade_reason`. HOL edges taken from Orchestrator A's files are
"UNKNOWN-TONIGHT" when A's files do not exist or state no exit code. No exit code is invented.
[f2] A HOL edge is MACHINE-CHECKED only if its go log ends `go exit 0`, its run record says actual_exit 0 and
inputs_unchanged_after true, the record's case and source name match the edge (and the COMMAND line, where the log
has one), the source digest matches, every required theorem name appears as CHECKED/FORGE_THEOREM in the log, and
every listed control log ends with its expected `go exit N`. An edge may not name a retired assumption.

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
LINK = OA + '/link/run/attempt-0001'

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
     'sink.ts calls Ed25519 verify on exactly the bytes that the model calls the claim. Decomposed (RepairedBytes) into H3b, H3c, B5, H3d-B6 and the trace-local A4-NOCOLL-RUN; H3a is retired.', 'yes'),
    ('H1-EUF-CMA', 'H1_SignatureAuthenticity (claim level, step-local): a delivered token whose tag verifies carries a claim signed earlier.',
     'Ed25519 EUF-CMA AND secrecy of the signing key; holds up to a negligible forgery probability, only while the key is secret.', 'yes'),
    ('H1B-BYTES', 'H1B_ByteUnforgeability: byte string and tag that verify were signed earlier (symbolic EUF-CMA at byte level).',
     'Same as H1, stated on bytes; with H3b/H3c/B5/H3d-B6/A4-NOCOLL-RUN it gives H1 and A5 (RepairedBytes.RepairedGiveClaimAuthenticity). [f3] The hash core uses it DIRECTLY on BytesOf(token) (SliceSafetyBytesV3.H1B_ByteUnforgeability), with no H3 glue.', 'yes'),
    ('H3a-SER-INJECTIVE', 'H3a: the claim serialization is injective (on model claims that carry the full pre-state).',
     'FALSE for the real token: the token carries only SHA-256 of the pre-state, so two pre-states with one hash give one byte string (ByteAttacks.PreStateCollisionBreaksApprovedSpec; ByteAttacks.HashedPreSerNotInjective). RETIRED.', 'no'),
    ('H3b-SINK-REBUILDS', 'H3b: at each delivery the sink rebuilds exactly Ser(ClaimOf(tok)) from the parsed token.', 'sink.ts rebuilds the signed bytes; not proved.', 'yes'),
    ('H3c-VERIFYTAG-IS-BYTES', 'H3c: the model VerifyTag is the byte verifier applied to Ser(claim).', 'A definition choice of the model; no real-world content beyond H3a and B5.', 'yes'),
    ('B5-CRYPTO-BOOLEAN', 'B5 / B5_VerifierBoolean: at each delivery the sink boolean sigOk is the byte verifier on the signed bytes of the delivered token (value core: the rebuilt bytes; hash core: BytesOf(token)).', 'Node OpenSSL Ed25519 verify returns the mathematical verifier value; glue sink.ts:71-75 (sink.ts:74 signedBytes(token.body)). [f3] reworded for the hash core.', 'yes'),
    ('A3-ATOMIC-COMMIT', 'A3: Commit is one atomic, durable step.',
     'One SQLite transaction in node:sqlite. Process crash: TESTED (486 kills, 0 violations, worker run). Power loss: SQLite defaults, no full fsync.', 'unknown'),
    ('A4-HASH', 'A4 faithful state: comparing state hashes equals comparing states.', 'SHA-256 collision resistance and a canonical state encoding.', 'yes'),
    ('A6-ALL-STRINGS', 'A6: the artifact computes the flat contract on ALL FlatIn inputs (any Unicode chars).',
     'The HOL side gives the flat contract only for byte strings (chars < 256) (Orchestrator A, 08:03Z). Not met by the M1 artifact as stated.', 'no'),
    ('A6b-BYTES', 'A6b_ArtifactComputesFlatContractOnBytes: the artifact computes the flat contract on byte-string inputs.',
     'The M1 executable on byte inputs computes the flat contract. Equivalent in Dafny to A6x (SliceFromExport.A6xIffA6b). Needs X1 to X10 and A7-ART: open.', 'unknown'),
    ('INITOK', 'InitOk: the protocol starts in the initial state of the model (0 <= remaining <= original for the initial charge).',
     '[f4] Enforced only by the MODEL\'s checked create (KeyedStore/KeyedHash KCreate refuses remaining > original). NOT enforced by sink.ts: its init accepts remaining above original (review r-bytes3, r-top). Only the money conclusions need it.', 'yes'),
    ('GOODSTART', 'GoodStart: the store that the patched core serves satisfies the core invariant at start (fresh, or AuditStart passes).',
     'A start-up audit (AuditStart, executable) runs before the core serves an old store. It gives structural facts only: AttackCore.GoodStartDoesNotBoundMoney (a store passing the audit holds a refund of 500 on an original of 100). Not deployed.', 'yes'),
    ('BETA-DAFNY-HOL', 'beta (umbrella): the Dafny meaning of the exported flat-contract text equals the HOL meaning of the parsed S-expression.',
     'Split on 2026-11-19 into BETA-VALUES, BETA-OPS and BETA-ORDER (U539; b-export-bridge/BRIDGE_STATEMENT.md). RETIRED as an umbrella.', 'unknown'),
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
    # ---- added by f-binding-2
    ('A4-NOCOLL-RUN', 'A4_NoCollisionInRun (trace-local): for each mint and each delivery of ONE trace, equal hashes of the two pre-states imply equal pre-states (and the same for the two id hashes).',
     'SHA-256 collision resistance on the pairs of one run; holds except with negligible probability; global injectivity is NOT needed (RepairedBytes).', 'yes'),
    ('A4b-STORED-HASH', 'A4b_NoStoredStateCollision: the real sink compares the stored state with the token by SHA-256 of the canonical state text; equal hashes imply equal states.',
     'The real token carries only preStateSha256. Same collision argument as A4-NOCOLL-RUN, a second time, in the sink. Used by NO proof (named in RepairedBytes only).', 'yes'),
    ('H3d-B6-PARSEABLE', 'H3d_MintsParseable and B6_DeliveriesParseable: every minted claim and every delivered token parses under the canonical token grammar of SerModel.',
     'minter.ts builds only canonical bodies; sink.ts rejects non-canonical text (TESTED: 443 bodies, b-ser conformance). Not proved for the TypeScript.', 'yes'),
    ('EMPTY-START', 'Every trace lemma (L0 to L3, several charges) starts from the EMPTY store; a restart from a non-empty store is covered only as one trace from the empty store.',
     'A deployed sink restarts on an existing database. [f3] A restart theorem now exists for the V3 MODEL (T-RESTART, T-AUDIT; DRAFT) under NO-ROLLBACK and AUTHENTIC-INIT; the layered lemmas themselves still start empty. Scope limit, not a fact about the world.', 'yes'),
    ('WELLKEYED', 'WellKeyed / KeyedInits: no two databases (charge stores) hold one charge id.',
     'NOT enforced by sink.ts or the dispatcher; AttackMulti.NotWellKeyedDoubleRefund: one token commits in two databases. [f3] In the MODEL it is an invariant of checked creation (T-KEYED) under CREATE-AUTHORITY and NO-DELETE-RECREATE.', 'yes'),
    ('BETA-VALUES', 'BETA-VALUES: Dafny int and HOL int are both the mathematical integers; Dafny bool and HOL bool agree; a Dafny string whose chars are < 256 and the HOL string with the same code list denote the same value.',
     'ARGUED, not proved (two tools, no common semantics): b-export-bridge/BRIDGE_STATEMENT.md section 2; Orchestrator A FIELDS_FOR_B.md.', 'yes'),
    ('BETA-OPS', 'BETA-OPS: each of the nine export forms (Eq on bool/int/string, Neq, And, Or, Imp, Le, Not) and three literal forms has the same reading in Dafny (as written by gen_exported.py) and in the HOL Dafny semantics.',
     'ARGUED by a table of source line references (BRIDGE_STATEMENT.md section 2); gen_exported.py is an unproved reader cross-checked by a second reader (Mirror.dfy trees equal).', 'yes'),
    ('BETA-ORDER', 'BETA-ORDER: the export names bind the same argument and tuple positions on both sides (charge, request, original, remaining, enabled, opened, candidate, amount, reason).',
     'ARGUED: a charge/request swap on BOTH sides is invisible to both proofs (contract symmetric); a one-sided swap fails (A: NB1 go exit 1). BRIDGE_STATEMENT.md section 3.', 'yes'),
    ('A6x-EXPORT', 'A6x_ArtifactMeetsExportedContractOnBytes: the artifact flat function meets the three exported clauses on byte-string inputs.',
     'A hypothesis in Dafny; equivalent to A6b (A6xIffA6b). Real-world reading needs A7-ART and the HOL chain X1 to X10.', 'unknown'),
    ('A7-ART', 'A7-ART: the artifact function of the Dafny lemma is the HOL function refund_fields, and the run-time bytes are the UTF-8 encodings of its string fields.',
     'Names one function on two sides; no tool relates them (U539). The executable computes refund_fields only through X1 to X10 (open).', 'unknown'),
    ('OS-PROC', 'OS process contract of the launcher: the OS delivers the complete stdout of a terminated child, reports a signal or exit status truthfully, and enforces the launcher timeout.',
     'macOS process and pipe semantics; trusted. CE-1 and CE-2 (exit 0 with truncated or empty stdout) show why exit status alone is not success.', 'unknown'),
    ('NODE-RT', 'Pinned Node 24.3.0 with its OpenSSL and built-in SQLite runs sink.ts, minter.ts and the compiled core as written.', 'Trusted runtime.', 'unknown'),
    # ---- added by f-binding-3 (restart, keyed creation, hash core, issuer bytes)
    ('NO-ROLLBACK', 'NO-ROLLBACK: the durable store is never rolled back to an earlier state (for example an honest prefix of its own ledger).',
     'Review r-restart (HIGH): a rollback to an honest prefix passes AuditFull and AuditFullSpec, and the dropped token commits again (AttackRestart.RollbackPassesAuditAndReplays). NO audit over the database alone can detect it. Needs an external monotonic anchor; none exists.', 'unknown'),
    ('AUTHENTIC-INIT', 'AUTHENTIC-INIT: the initial charge state that the restart audit replays from is the authentic charge record.',
     'Review r-restart (HIGH): the audit init is an unauthenticated input; a forged init passes the spec audit (AttackRestart.ForgedInitPassesSpecAudit). AuditSpecMoney bounds money only RELATIVE to the supplied init.', 'unknown'),
    ('NO-DELETE-RECREATE', 'NO-DELETE-RECREATE: a charge store is never deleted and then created again with the same charge id.',
     'Review r-restart (MEDIUM): delete + re-create defeats the key invariant and gives a double refund (AttackRestart.DeleteRecreateDoubleRefund). KeyedStore has no Delete action.', 'unknown'),
    ('CREATE-AUTHORITY', 'CREATE-AUTHORITY: every charge store is created only through the checked Create (key == init.chargeId, key absent, 0 <= remaining <= original).',
     'Proved as an invariant for the MODEL (KeyedStore.KExecWellKeyed). sink.ts and the dispatcher do not enforce it: the TypeScript chargeKey check is opt-in and sits in an UNAPPLIED diff (b-restart sink-keyed-chargeid, 556b55fb...; r-restart MEDIUM).', 'yes'),
    ('A2P-ISSUEBYTES', 'A2p_MintsAreIssued: every mint of bytes with the pinned spec and checker ids signs bytes that IssueBytes produced from an authorized transition (IssuedFrom); the signing key is only in the issuer.',
     '[f4 reworded, review r-bytes3] THREE parts: (1) key custody: the signing key is only in the issuer (ONE-ISSUER-KEY); (2) minter glue: the TypeScript of the issuer signs ONLY the bytes the proved method returned (draft minter_issuebytes.ts, d-minter; TESTED 581 requests; one TypeScript line carries the hash text, r-drafts); (3) the Dafny-to-JavaScript compiler (DAFNY-JS). The proved IssueBytes is a MODEL of the issuer, not the issuer. The deployed minter.ts builds the body in TypeScript (not IssueTokenBytes).', 'yes'),
    ('A4-HASH-BINDS', 'A4_HashBindsInRun (trace-local, ONE hypothesis): at each delivery, the hash of the STORED charge equals the hash of an earlier mint pre-state only if the two states are equal.',
     'SHA-256 collision resistance on the pairs of one run. Covers both the signature binding (old A4-NOCOLL-RUN) and the sink hash compare (old A4b) for the hash-comparing core (SliceSafetyBytesV3).', 'yes'),
    ('SERMODEL-MIRRORS-ENCODING', 'SERMODEL-MIRRORS-ENCODING: SerModel (SerBody, SignedBytes, ParseExact, WfBody) computes what ts/refund-finality/encoding.ts computes (canon, signedBytes, isTokenBody).',
     'TESTED only: b-ser 443/443 bodies; r-ser 6,581 bodies + 4,736 malformed texts, 0 differences (r-ser/conf/result.2.json). Lone surrogates: separate run. Not proved.', 'yes'),
    ('DECODER-TYPES', 'DECODER-TYPES (type-level decoder glue): the sink decoder gives token fields of the model types (money fields as naturals, ids as hex texts); this replaces B6 for the hash core.',
     'The hash core needs no decoder fact beyond the types (SliceSafetyBytesV3 header). The real decoder (encoding.ts isTokenBody) is not proved to give those types; TESTED with SERMODEL-MIRRORS-ENCODING.', 'yes'),
    ('G-H-PREHASH', 'G-H: the issuer and the sink use the SAME hash function of the SAME canonical state text; the issuer shell passes preHashHex == lowercase hex SHA-256 of canon(pre) for the SAME pre that it passes to IssueTokenBytes, and the stored state text is always canonical.',
     '[f4 reworded, reviews r-bytes3, r-drafts, r-top] Glue that is true only by reading the code: not a listed hypothesis of SliceSafetyBytesV3 or SliceSafetyBytesTop (they take one HashFn H for both sides). The hash text is an unchecked input of the proved method; one TypeScript line in the draft minter carries it. A wrong hash with a reachable colliding state breaks the slice theorem.', 'yes'),
    ('A-R6', 'R6 (from Orchestrator A): every FFI event of every run of the totalised machine is a valid read/write event (refund_valid_event).',
     'MISSING at model level (program behaviour; A MORNING section 4 and 7). PLAUSIBLE in the model (review A26), NOT proved.', 'unknown'),
    ('A-FFI-NATIVE-VALID', 'Native FFI contract at valid calls (from Orchestrator A, owner item A-3): the C FFI meets the model contract at every call that satisfies VokY3.',
     'ASSUMPTION (NATIVE). Plausible for the present C code only at the program call shapes; TESTED-UNPROVED (A26, A23: the C code aborts where the model returns an error byte at other states).', 'unknown'),
    # ---- the 13 assumptions between MF-0002 and the real consumer (orch-A/review-MF/REPORT.md, A's wording)
    ('MF-01-X8', 'X8 (process refines model).', 'From Orchestrator A (review A26). Same content as edge X8.', 'unknown'),
    ('MF-02-FFI', 'The FFI premise (or R6 + contract).', 'From Orchestrator A (review A26). The all-states form is FALSE for the real C (U393); the reduced form is A-R6 + A-FFI-NATIVE-VALID.', 'no'),
    ('MF-03-NOEXT', '`no_ext`.', 'From Orchestrator A (review A26). Every MF/MG statement is at no_ext.', 'unknown'),
    ('MF-04-FD1WRITE', 'A-FD1-WRITE.', 'From Orchestrator A (review A26).', 'unknown'),
    ('MF-05-LOADER', 'A-LOADER/entry state.', 'From Orchestrator A (review A26). Same content as A-LOADER and X5-ENTRY.', 'unknown'),
    ('MF-06-PYPARSE', 'Python parser = HOL parser (TESTED).', 'From Orchestrator A (review A26). frame.strict_parse vs refund_strict_parse: 304,326 inputs, 0 wrong acceptances (A MORNING section 4).', 'yes'),
    ('MF-07-STDOUT-EMPTY', 'stdout starts empty.', 'From Orchestrator A (review A26).', 'unknown'),
    ('MF-08-BETA', 'BETA (clause meaning Dafny vs HOL).', 'From Orchestrator A (review A26). Ledger split: BETA-VALUES, BETA-OPS, BETA-ORDER (ARGUED).', 'yes'),
    ('MF-09-EXPORTER', 'exporter identity.', 'From Orchestrator A (review A26). Same content as EXPORTER-ID (build folder absent).', 'unknown'),
    ('MF-10-LINKEDREFUND', 'Dafny LinkedRefund.', 'From Orchestrator A (review A26). Ledger edge S3 (MACHINE-CHECKED, model) carries it on the Dafny side.', 'yes'),
    ('MF-11-INPUT-ENC', 'input encoding (stdin = `refund_request` of the nine values the caller means).', 'From Orchestrator A (review A26). Related: S8-CANONICAL-WIRE.', 'unknown'),
    ('MF-12-X16', 'X16 (the issuer does not use this binary today).', 'From Orchestrator A (review A26). Same content as edge X16 (MISSING).', 'no'),
    ('MF-13-KERNEL-IO', 'kernel I/O = oracle (no EPIPE/EAGAIN).', 'From Orchestrator A (review A26). CE-1 (non-blocking pipe, truncated stdout with exit 0) is a real case outside it.', 'unknown'),
    # ---- added by f-binding-4 (top-level composition, repaired drafts)
    ('A2Q-ISSUETOKENBYTES', 'A2q_MintsAreIssueTokenBytesOutputs: every mint of pinned-id bytes is an output of IssueTokenBytes(pre, t, sh, ch, H(pre)) for some pre, t, sh, ch (IssuerLink).',
     'Stronger than A2p (IssuerLink.A2qImpliesA2p, machine-checked); the WfBody guard only removes mints (NulMintIsA2pNotA2q). Real-world reading as A2P-ISSUEBYTES: key custody (ONE-ISSUER-KEY) + minter glue (an issuer that signs only the returned bytes; draft minter_issuebytes.ts; TESTED) + the Dafny-to-JavaScript compiler (DAFNY-JS).', 'yes'),
    ('ONE-ISSUER-KEY', 'ONE-ISSUER-KEY: exactly one signing key is trusted by the sink for the pinned spec and checker ids, and only the issuer process holds it.',
     'Key custody. No key-management code exists in the repository; the tests use generated test keys. Part of A2p/A2q and of H1B.', 'unknown'),
    ('CODEC-OK', 'CodecOk (Bridge2Model): the bridge codec dec undoes enc, and "" and the three reason texts are fixed points of enc.',
     'Hypothesis of every Bridge2 lemma. The real codec is UTF-8 in decide2.py (Python); TESTED only (x-bridge2 tests2.py 90 of 90).', 'yes'),
    ('NATIVE-OK-ON-INPUT', 'NativeOkOn(native, x): when the native side (launcher + strict parser + native program) returns a frame for the ONE encoded input x, that frame meets FlatContract on x.',
     'Hypothesis of Bridge2Model.SoundNative and Complete (not of SoundCheck). To be discharged for the MODEL machine by Orchestrator A\'s MF/MG theorems (X-MF, X-MG: exported clauses on the value of the only fd-1 frame) and, for the real process, by A\'s 13 items MF-01..MF-13 (X8, FFI, loader, kernel I/O, parser, exporter, input encoding, ...). Open.', 'unknown'),
    ('A-DB1', 'A-DB1 (ShellCoreV4): the rows the shell reads are the stored outbox in sequence order, and each `hit` is the membership of that row\'s request id in the settled set.',
     'What the database returns to the v4 shell (SQLite query results). Not proved; the v4 draft conformance and differential runs are tests.', 'unknown'),
    ('A-DB2', 'A-DB2 (ShellCoreV4): nSettled == |settled| (the count the database returns).', 'What the database returns to the v4 shell. Not proved.', 'unknown'),
    ('A-DB3', 'A-DB3 (ShellCoreV4): outboxDistinct == DistinctIds(outbox) (the distinctness answer the database returns).', 'What the database returns to the v4 shell. Not proved.', 'unknown'),
    ('DB-NO-FOREIGN-WRITER', 'DB-NO-FOREIGN-WRITER: no process other than the sink writes the sink database (no balance reset, no row rewrite, no schema change between runs).',
     'Review r-repairs (U553): with a hostile writer the v4 re-audit passes after a balance reset and a second refund commits (T-V4-ATTACK). The start-up audit is structural only. Needs file permissions, a single writer and, against rollback, an external anchor (NO-ROLLBACK).', 'unknown'),
    ('TS-LOOP-IS-FOLD', 'TS-LOOP-IS-FOLD: the TypeScript start-up loop of sink_core_backed_v4.ts computes the proved fold of AuditStep over the rows followed by AuditEnd, and its commit path applies exactly the StepQ result in one transaction.',
     'UNPROVED. The TypeScript is read and tested (heavy/v4-1 differential; d-v3sink2 conformance), not proved. Open for any adoption of the v4 draft (MORNING addendum 6).', 'unknown'),
]


# [f2] extra fields of assumptions: status (active|retired), group, basis (ARGUED for the beta parts), retirement data
ASSUMPTION_EXTRA = {
    'H3a-SER-INJECTIVE': dict(status='retired', retired_reason='False for the real token (hash of the pre-state only).',
                              counterexample=NS + '/recheck-b/ByteAttacks.csv', counterexample_lemma='ByteAttacks.PreStateCollisionBreaksApprovedSpec',
                              replaced_by=['A4-NOCOLL-RUN', 'H3d-B6-PARSEABLE'], replacement_edge='T-BYTES-R'),
    'BETA-DAFNY-HOL': dict(status='retired', retired_reason='Umbrella split into three named parts.', replaced_by=['BETA-VALUES', 'BETA-OPS', 'BETA-ORDER']),
    'BETA-VALUES': dict(group='BETA', basis='ARGUED'), 'BETA-OPS': dict(group='BETA', basis='ARGUED'), 'BETA-ORDER': dict(group='BETA', basis='ARGUED'),
    'A-LOADER': dict(group='OS-LAUNCHER'), 'STRICT-FRAME': dict(group='OS-LAUNCHER'), 'OS-PROC': dict(group='OS-LAUNCHER'),
    'X11-KERNEL': dict(group='OS-LAUNCHER'),
    'DAFNY-Z3-TCB': dict(group='TOOLS'), 'HOL-TCB': dict(group='TOOLS'), 'DAFNY-JS': dict(group='TOOLS'), 'NODE-RT': dict(group='TOOLS'),
    # [f3]
    'A4b-STORED-HASH': dict(status='retired', retired_reason='Superseded for the hash core: merged into A4-HASH-BINDS (SliceSafetyBytesV3); no edge uses it after U3 moved to the hash-core glue.',
                            replaced_by=['A4-HASH-BINDS'], replacement_edge='T-BYTES-V3'),
    'A4-NOCOLL-RUN': dict(superseded_for='the hash core (A4-HASH-BINDS, T-BYTES-V3); kept for the value-core edge T-BYTES-R'),
    'H3b-SINK-REBUILDS': dict(superseded_for='the hash core (BytesOf by definition); kept for the value-core edges'),
    'H3c-VERIFYTAG-IS-BYTES': dict(superseded_for='the hash core (no uninterpreted VerifyTag); kept for the value-core edges'),
    'H3d-B6-PARSEABLE': dict(superseded_for='the hash core (DECODER-TYPES; IssueTokenBytes refuses U+0000); kept for the value-core edge T-BYTES-R'),
    'A5-VERIFIER-MATCH': dict(superseded_for='the hash core (B5 on BytesOf); kept for the value-core and V3-core edges'),
    'NO-ROLLBACK': dict(group='RESTART'), 'AUTHENTIC-INIT': dict(group='RESTART'), 'NO-DELETE-RECREATE': dict(group='RESTART'),
    'CREATE-AUTHORITY': dict(group='RESTART'), 'SERMODEL-MIRRORS-ENCODING': dict(basis='TESTED'), 'DECODER-TYPES': dict(group='GLUE'),
    'G-H-PREHASH': dict(group='GLUE'),
    'A-R6': dict(group='FFI', source='from Orchestrator A'), 'A-FFI-NATIVE-VALID': dict(group='FFI', source='from Orchestrator A'),
    'MF-01-X8': dict(maps_to=['X8']), 'MF-02-FFI': dict(maps_to=['X6-FFI-ALL-STATES', 'A-R6', 'A-FFI-NATIVE-VALID']),
    'MF-05-LOADER': dict(maps_to=['A-LOADER', 'X5-ENTRY']), 'MF-06-PYPARSE': dict(basis='TESTED'),
    'MF-08-BETA': dict(maps_to=['BETA-VALUES', 'BETA-OPS', 'BETA-ORDER']), 'MF-09-EXPORTER': dict(maps_to=['EXPORTER-ID']),
    'MF-10-LINKEDREFUND': dict(maps_to=['S3']), 'MF-11-INPUT-ENC': dict(maps_to=['S8-CANONICAL-WIRE']), 'MF-12-X16': dict(maps_to=['X16']),
    # [f4]
    'A2P-ISSUEBYTES': dict(group='GLUE', maps_to=['ONE-ISSUER-KEY', 'DAFNY-JS']), 'A2Q-ISSUETOKENBYTES': dict(group='GLUE', maps_to=['A2P-ISSUEBYTES', 'ONE-ISSUER-KEY', 'DAFNY-JS']),
    'ONE-ISSUER-KEY': dict(group='KEY'), 'CODEC-OK': dict(group='GLUE', basis='TESTED'),
    'NATIVE-OK-ON-INPUT': dict(group='FFI', maps_to=['X-MF', 'X-MG', 'MF-01..MF-13']),
    'A-DB1': dict(group='DATABASE'), 'DB-NO-FOREIGN-WRITER': dict(group='RESTART'), 'A-DB2': dict(group='DATABASE'), 'A-DB3': dict(group='DATABASE'), 'TS-LOOP-IS-FOLD': dict(group='GLUE'),
}
for _i in [a[0] for a in ASSUMPTIONS if a[0].startswith('MF-')]:   # [f3] the 13 entries of review A26
    ASSUMPTION_EXTRA.setdefault(_i, {}).update(group='MF-TO-CONSUMER', source='from Orchestrator A (orch-A/review-MF/REPORT.md)')
MF13 = [a[0] for a in ASSUMPTIONS if a[0].startswith('MF-')]

# ------------------------------------------------------------------ edge table
# run: dict(log, csv, ran_by, root, entry, role); fr: f-records proof name; hol: dict(log, source, hashes, runjson)


def R(log, ran_by, root=None, entry=None, csv=None, role='verify'):
    """[f3] `entry` may be a list: one command line with several root files; stored as entry (first) + entries."""
    if isinstance(entry, (list, tuple)):
        return dict(log=log, csv=csv, ran_by=ran_by, root=root, entry=entry[0], entries=list(entry), role=role)
    return dict(log=log, csv=csv, ran_by=ran_by, root=root, entry=entry, role=role)


def fr_runs(name, recs, extra=()):
    p = recs['proofs'][name]
    v = p['verify']
    runs = [R(FR + '/' + v['log'], 'worker f-records', p['root_in_checkout'], p['entry'], FR + '/' + v['csv'])]
    # [f2] Orchestrator B's independent re-run (check_records.py --rerun; recheck-f/rerun.out: SAME for all six)
    rr = NS + '/recheck-f/rerun/records/%s/verify-%s.1' % (name, name)
    runs.append(R(rr + '.log', 'orchestrator B re-run (check_records --rerun)', NS + '/recheck-f/rerun/work/' + name, p['entry'], rr + '.csv'))
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
    dict(id='S5', chain='S', frm='exported bytes', to='parsed HOL contract (source_decode, source_signature, source_full_result, source_postconditions, mapped_operators)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='U294 theorems replayed tonight by Orchestrator A (link case R1, run u294-hol): the checker reports the whole stdout byte-equal to the recorded hol-0004 run. HOL-internal parse (mlsexp$parse, to_program).',
         hol=dict(folder=LINK, case='R1', run='u294-hol'),
         required_theorems=['source_decode', 'source_signature', 'source_full_result', 'source_postconditions', 'mapped_operators'],
         assumptions=['HOL-TCB', 'BETA-OPS']),
    dict(id='S5-REL', chain='S', frm='parsed HOL contract', to='source model result relation', claimed='MACHINE-CHECKED', about='MODEL', sub_of='S5',
         statement='Link case R2 (run u294-rel-2): source_model_result; CHECKED record equal to the recorded one after whitespace normalisation only (byte-equal: False, a printer line break).',
         hol=dict(folder=LINK, case='R2', run='u294-rel-2'), required_theorems=['source_model_result'], assumptions=['HOL-TCB']),
    dict(id='S5-BR', chain='S', frm='parsed HOL contract', to='compiled fields (refund_fields)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='S5',
         statement='Link case R3 (run u294-bridge-2): source_compiled_fields; CHECKED record equal after whitespace normalisation only.',
         hol=dict(folder=LINK, case='R3', run='u294-bridge-2'), required_theorems=['source_compiled_fields'], assumptions=['HOL-TCB']),
    dict(id='S5-IMP', chain='S', frm='U294 theory', to='import check (7 statements EXACT, 0 hypotheses, 0 tagged axioms)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='S5',
         statement='Link case I1 (run u294-import-2): 7 IMPORTED lines EXACT true; statement text only (V4).',
         hol=dict(folder=LINK, case='I1', run='u294-import-2'),
         required_lines=['IMPORTED %s EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0 ORACLES DISK_THM' % n for n in
                         ['source_full_result', 'source_postconditions', 'source_decode', 'source_signature', 'mapped_operators', 'source_initial_def', 'source_export_text_def']],
         assumptions=['HOL-TCB']),
    dict(id='S6', chain='S', frm='exported contract (3,621 bytes, 58154ddf...)', to='HOL function refund_fields (exported_contract_exact, exported_contract_on_refund_fields)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='Link case H1 (run contract-0001) and repeat H2: nine theorems; controls NC1-NC6, NS1-NS3, NB1 must end go exit 1 and PC1 go exit 0. MODEL level; A asked for BETA and EXPORTER-ID on this edge; EXPORTER-ID now sits on S4 only.',
         hol=dict(folder=LINK, case='H1', run='contract-0001', extra=[('H2', 'contract-repeat')], controls=[('NC1', 1), ('NC2', 1), ('NC3', 1), ('NC4', 1), ('NC5', 1), ('NC6', 1), ('NS1', 1), ('NS2', 1), ('NS3', 1), ('NB1', 1), ('PC1', 0)]),
         required_theorems=['exported_contract_decode', 'exported_contract_shape', 'exported_ens1_value', 'exported_ens2_value', 'exported_ens3_value',
                            'exported_contract_value', 'exported_contract_on_refund_fields', 'exported_contract_exact', 'exported_contract_witnesses'],
         assumptions=['HOL-TCB', 'BETA-VALUES', 'BETA-OPS', 'BETA-ORDER'], evidence=[LINK + '/control_reasons.txt', LINK + '/PASS_CRITERIA.md']),
    dict(id='S6-ELIG', chain='S', frm='exported contract', to='HOL eligible guard (eligible_link_guard_value)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='S6',
         statement='Link case E0 (run eligible-link-0001): the exported eligible guard equals the compiled guard.',
         hol=dict(folder=LINK, case='E0', run='eligible-link-0001'),
         required_theorems=['eligible_link_decode', 'eligible_link_shape', 'eligible_link_operators', 'eligible_link_guard_value', 'eligible_link_matches_compiled_guard'],
         assumptions=['HOL-TCB']),
    dict(id='S6-RENDER', chain='S', frm='exported contract', to='rendered output (exported_contract_on_rendered_output)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='S6',
         statement='Link case H4 (run render-0002, second run after a wrapper path fix); control NR1 (run ctl-NR1-2) must end go exit 1.',
         hol=dict(folder=LINK, case='H4', run='render-0002', controls=[('NR1', 1)]),
         required_theorems=['exported_contract_on_rendered_output'], assumptions=['HOL-TCB']),
    dict(id='S7', chain='S', frm='Dafny operator meanings', to='HOL Dafny semantics', claimed='ASSUMPTION', about='MODEL',
         statement='The Dafny-to-HOL bridge beta on the named fragment, now in three ARGUED parts (U539).', assumptions=['BETA-VALUES', 'BETA-OPS', 'BETA-ORDER'],
         evidence=[NS + '/b-export-bridge/BRIDGE_STATEMENT.md']),
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
         statement='refund_ffi_contract_at_totalise and the L1 theorems (16 theorems, model only; holds also for Vok = F). L1 alone does not remove the false FFI premise (orch-A/review-L1).',
         hol=dict(case='L1-0001'), required_theorems=['refund_ffi_contract_on_totalises', 'refund_env_ok_sl_of_contract_on', 'close_abort_model_fails_stored_contract',
                                                      'refund_close_call_valid_rejects_u393_witness'], assumptions=['HOL-TCB']),
    dict(id='X7-L1imp', chain='X', frm='L1 theory', to='import check', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L1 theorems import with IMPORTED_COUNT 9, MISMATCH_COUNT 0 (statement text only; 9 of 16 matched).',
         hol=dict(case='L1imp-0001'), required_lines=['IMPORTED_COUNT 9 MISMATCH_COUNT 0', 'EXACT_COMPLETE'], assumptions=['HOL-TCB']),
    dict(id='X7-L2', chain='X', frm='two machines', to='agreement (L2)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L2-0003 (after L2-0001 and L2-0002 go exit 1); repeat L2r-0001. Its two new premises (contract at valid calls; ffi_calls_ok Vok) are OPEN; no Vok shown with all premises (orch-A/review-L2).',
         hol=dict(case='L2-0003', extra=[('L2r-0001', 'L2r-0001')]),
         required_theorems=['refund_ffi_tot_evaluate_agree', 'refund_ffi_tot_machine_sem_agree', 'refund_profile_a_sl_reach'], assumptions=['HOL-TCB']),
    dict(id='X7-L2b', chain='X', frm='close predicate', to='third premise of L2R for close (L2b)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L2b-0003 (after L2b-0001, L2b-0002 go exit 1): ffi_calls_ok_of_returning_calls and the close premises; model only; review A18 running at generation time.',
         hol=dict(case='L2b-0003'), required_theorems=['ffi_calls_ok_of_returning_calls', 'refund_l2r_third_premise_close', 'refund_l2r_third_premise_close_and_rest',
                                                         'returning_call_premise_is_needed'], assumptions=['HOL-TCB']),
    dict(id='X8', chain='X', frm='real process', to='model machine', claimed='MISSING', about='DEPLOYED',
         statement='native_refines is not formalized.', assumptions=['A-LOADER', 'X11-KERNEL']),
    dict(id='X9', chain='X', frm="model I/O events", to='bytes on descriptor 1', claimed='MISSING', about='MODEL',
         statement='L-OUT at model level is sub-edge X9-LO (LO-0006), composed into X-MF (MF-0002). The edge stays MISSING: stored premises (X6), real descriptor not modelled (X8), kernel I/O = oracle (MF-13).', assumptions=[]),
    dict(id='X9-LO', chain='X', frm='model I/O events', to='L-OUT attempt', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X9',
         statement='LO-0006 (after LO-0001 to LO-0005 failed): refund_L_OUT, refund_L_OUT_prefix, refund_profile_a_sl_fd1; MODEL, no_ext, under the stored premises (X6 probably false); review running at generation (A, 09:38Z). Edge X9 stays MISSING until the review and the premises close.',
         hol=dict(case='LO-0006'), required_theorems=['refund_L_OUT', 'refund_L_OUT_prefix', 'refund_profile_a_sl_fd1', 'N_O1_free_ext_breaks'],
         assumptions=['HOL-TCB', 'X5-ENTRY', 'X6-FFI-ALL-STATES', 'X11-KERNEL']),
    dict(id='X10', chain='X', frm="model halt", to='process exit status', claimed='MISSING', about='DEPLOYED',
         statement='L-EXIT; exit status 0 does not imply success.', assumptions=['STRICT-FRAME']),
    dict(id='X10-LE', chain='X', frm='model halt', to='halt lemmas (L-EXIT, generic halt)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X10',
         statement='LE-0004 (A 09:38Z: model part only; the halt-value range and the real exit path stay open; LE-0003 also ends go exit 0, LE-0002 go exit 1). X10 stays MISSING.',
         hol=dict(case='LE-0004'), required_theorems=['evaluate_Halt_reg', 'machine_sem_of_evaluate_Halt', 'refund_halt_address', 'refund_profile_a_sl_halt'], assumptions=['HOL-TCB']),
    dict(id='X11', chain='X', frm='processor and kernel', to='L3 model, interference_ok', claimed='ASSUMPTION', about='DEPLOYED',
         statement='Every route ends at a named kernel assumption.', assumptions=['X11-KERNEL']),
    dict(id='X11e', chain='X', frm='real registers (TBI0, SA0 = 1)', to='erased model state', claimed='MISSING', about='MODEL',
         statement='Erasure soundness (E1) not run.', assumptions=['X5-ENTRY']),
    dict(id='X11e-E1', chain='X', frm='single functions on real register values', to='erased model (E1 lemmas)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X11e',
         statement='E1-0003 and repeat E1r-0001: 18 erasure theorems on single functions; mutant E1neg-0001 must end go exit 1. The lift to one step and to evaluate is MISSING.',
         hol=dict(case='E1-0003', extra=[('E1r-0001', 'E1r-0001')], controls=[('E1neg-0001', 1)]),
         required_theorems=['BranchTo_erase_untagged', 'CheckSPAlignment_erase', 'arm8_ok_erase'], assumptions=['HOL-TCB']),
    dict(id='X11e-ES', chain='X', frm='erased single functions', to='one erased machine step (step lift)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X11e',
         statement='Step-lift attempt ES-0002 (ES-0001 also failed).', hol=dict(case='ES-0002'), assumptions=['HOL-TCB']),
    dict(id='X12', chain='X', frm='real executable runs', to="model's output", claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='2,466 vectors, 0 findings (Wave Gate 1).', evidence=[CONF, EXE], assumptions=['A-LOADER']),
    dict(id='X13', chain='X', frm='output bytes', to='no strict prefix parses', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='8,011 strict prefixes, 0 accepted (worker run); HOL prefix lemma not proved.', assumptions=['STRICT-FRAME']),
    dict(id='X13-PF', chain='X', frm='output bytes', to='HOL prefix lemma on refund_strict_parse', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X13',
         statement='PF-0004 (after PF-0001 to PF-0003 go exit 1): about the HOL function refund_strict_parse defined in the script, not about frame.py.',
         hol=dict(case='PF-0004'), required_theorems=['refund_strict_parse_no_strict_prefix', 'refund_strict_parse_complete', 'refund_render_fields_prefix_code',
                                                        'N1_trailing_newline_breaks'], assumptions=['HOL-TCB']),
    dict(id='X13-PX', chain='X', frm='output bytes', to='exactly one frame (refund_strict_parse_exact, refund_frame_decision)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X13',
         statement='PX-0001: HOL model of the strict single-frame decision; not about any consumer program.',
         hol=dict(case='PX-0001'), required_theorems=['refund_strict_parse_exact', 'refund_strict_parse_accepts_only_one_frame', 'refund_frame_decision',
                                                        'refund_strict_parse_not_reject_all'], assumptions=['HOL-TCB']),
    dict(id='X14', chain='X', frm='full output', to='six fields', claimed='MACHINE-CHECKED', about='MODEL',
         statement='refund_render_fields_roundtrip (M1R-1 T06).', hol_prior=[M1R + '/logs/T06-forge_refundWireProg.log'], assumptions=['HOL-TCB']),
    dict(id='X15', chain='X', frm='process result', to="caller's decision", claimed='MISSING', about='DEPLOYED',
         statement='No consumer of M1 output in the deployed path. Draft candidate: x-bridge2 (launcher.py, frame.py, decide2.py; T-BRIDGE2 model, T-BRIDGE2-TEST tests); the first draft (X16-DRAFT, X16-TEST) is superseded (known defect, r-drafts). Not applied.', rests_on=['T-BRIDGE2', 'T-BRIDGE2-TEST'],
         assumptions=['STRICT-FRAME', 'OS-PROC'], evidence=[NS + '/x-bridge2/BRIDGE2_DESIGN.md', NS + '/x-issuer-bridge/BRIDGE_DESIGN.md']),
    dict(id='X16', chain='X', frm='M1 decision', to='authorization token', claimed='MISSING', about='DEPLOYED',
         statement='The deployed issuer (minter.ts) calls the compiled Dafny checker, not M1, and builds the token body in TypeScript. DRAFTS only: the single-input dual-check bridge (T-BRIDGE2 model with check and native as parameters; T-BRIDGE2-TEST 90 of 90 with the real native program) in place of the superseded first draft (X16-DRAFT, X16-TEST), and the IssueTokenBytes minter (T-ISSUEBYTES, T-ISSUEBYTES-CONF); not applied. Orchestrator A lists this as MF-12-X16.',
         rests_on=['T-BRIDGE2', 'T-BRIDGE2-TEST', 'T-ISSUEBYTES', 'T-ISSUEBYTES-CONF'],
         assumptions=[], evidence=[NS + '/x-bridge2/BRIDGE2_DESIGN.md', NS + '/x-issuer-bridge/BRIDGE_DESIGN.md', NS + '/x-issuer-bridge/OWNER_APPROVAL.md']),
    dict(id='X16-DRAFT', chain='X', frm='Dafny verdict and native frame (model)', to='issue decision (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='X16',
         statement='IssuerBridge.BridgeSound, BridgeComplete: the draft decision issues exactly when the Dafny verdict issues AND one complete frame with equal fields is read (8 verified). A model of decide.py, not decide.py.',
         runs=[R(NS + '/recheck-s/Bridge.log', 'orchestrator B re-run', NS + '/x-issuer-bridge/dafny', 'Bridge.dfy', NS + '/recheck-s/Bridge.csv')],
         required=['IssuerBridge.BridgeSound', 'IssuerBridge.BridgeComplete', 'IssuerBridge.FrameDeterminesVerdict', 'IssuerBridge.Witness'],
         superseded_by='T-BRIDGE2', superseded_reason='draft with a known defect (review r-drafts): the proof holds as stated, but the modelled draft compares no post-state and takes two inputs; replaced by the single-input Bridge2',
         known_defect='r-drafts: a miscompiled checker that accepts a wrong post-state is not caught (no post-state in the compared fields); the draft signed when the two sides got different inputs (three cases with the real native program).',
         assumptions=['STRICT-FRAME']),
    dict(id='X16-TEST', chain='X', frm='real M1 binary through the draft launcher', to='issue decision (DRAFT)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='X16',
         statement='tests.py on a copy, scrubbed environment, real M1 binary b8ed5ec2...: 64 of 64, exit 0 (B run); worker mutants 31 of 32 killed (1 equivalent); CE-3 dylib case gives the honest frame through the launcher.',
         evidence=[NS + '/recheck-xb/tests.log', NS + '/x-issuer-bridge/tests.py', NS + '/x-issuer-bridge/launcher.py', NS + '/x-issuer-bridge/decide.py', NS + '/x-issuer-bridge/frame.py'],
         superseded_by='T-BRIDGE2', superseded_reason='draft with a known defect, superseded by Bridge2 (review r-drafts); tests of the repaired bridge: T-BRIDGE2-TEST',
         known_defect='r-drafts: no post-state compare; signs with mismatched inputs (three cases with the real native program).',
         assumptions=['A-LOADER', 'OS-PROC']),
    # ---- chain U: token -> committed state
    dict(id='U1', chain='U', frm='request and candidate transition', to='RefundFinality.Check (P1-P4)', claimed='MACHINE-CHECKED', about='DEPLOYED',
         statement='The source of impl/RefundFinality.dfy verifies (inside the sink-core closure; copy equal to the repository file).',
         fr='sink-core', required=['RefundFinality.Check'], assumptions=['DAFNY-Z3-TCB'], evidence=[SLICE1]),
    dict(id='U1c', chain='U', frm='impl/RefundFinality.dfy', to='compiled JavaScript core', claimed='ASSUMPTION', about='DEPLOYED',
         statement='source_to_module_proved=false (Slice 1 record); generated JS digest 721b4d06... is regenerated, not stored.',
         assumptions=['DAFNY-JS'], evidence=[SLICE1]),
    dict(id='U2', chain='U', frm='Check result', to='signed token (minter.ts)', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Slice 1 suite, 115 rows. Draft pointers (not applied): T-ISSUEBYTES (method), T-ISSUEBYTES-CONF (draft minter), T-TOP (A2q at the top level).', evidence=[SLICE1, 'ts/refund-finality/minter.ts'],
         rests_on=['T-ISSUEBYTES', 'T-ISSUEBYTES-CONF', 'T-TOP'], assumptions=['A2-ISSUANCE', 'NODE-RT']),
    dict(id='U3', chain='U', frm='token', to='commit in sink.ts', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Slice 1 suite; sink.ts does NOT check intent.requestId against the token (d-reqid; Contrast.UnpatchedGap) and does not bind intent.chargeId. It compares the stored state by hash: the hash-core glue (A4-HASH-BINDS, B5, DECODER-TYPES) now names what links it to T-BYTES-V3; no proof that sink.ts implements HashCore. [f4] Draft pointers for the deployed sink: T-TOP (top-level byte lemma), the v4 draft (T-SHELLV4) and its differential (U5v4-DIFF).',
         rests_on=['T-BYTES-V3', 'T-TOP', 'T-SHELLV4', 'U5v4-DIFF'],
         evidence=[SLICE1, 'ts/refund-finality/sink.ts', 'ts/refund-finality/encoding.ts'],
         assumptions=['B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS', 'SERMODEL-MIRRORS-ENCODING', 'DECODER-TYPES', 'NODE-RT']),   # [f3] hash-core glue (was H3b, H3d-B6, A4b)
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
    dict(id='U5b', chain='U', frm='Dafny sink core (merged shape)', to='ts/refund-finality/sink.ts', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='No proof. B differential (heavy/diff-1): merged sink.ts against the compiled merged-shape core, 2,000 plain + 3 x 500 fault/interleave sequences, 0 divergences, exit 0; the three mismatched pairs exit 1 as they must. sink.ts keeps the request-id gap of the merged core. [f4] Draft candidate for adoption: the v4 sink (T-SHELLV4 proof of StepQ and the streaming audit; U5v4-DIFF differential, heavy/v4-1; T-V4SINK-CONF). The v3 draft (T-SHELLV3, T-V3SINK-CONF) is superseded (known defect, r-drafts). No change for the deployed sink.ts.',
         rests_on=['T-SHELLV4', 'U5v4-DIFF', 'T-V4SINK-CONF'],
         evidence=[NS + '/heavy/diff-1/summary.txt', NS + '/heavy/run_diff.sh', 'ts/refund-finality/sink.ts'], assumptions=['DAFNY-JS', 'NODE-RT']),
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
    dict(id='U5r-DIFF', chain='U', frm='patched compiled cores', to='patched sink copy and draft core-backed sinks (DRAFT)', claimed='TESTED-UNPROVED', about='DRAFT',
         statement='B differential (heavy/diff-1): sink.ts copy with the request-id diff against the compiled SinkCoreReqId, and sink_core_backed.ts against both compiled cores: 0 divergences, exit 0.',
         evidence=[NS + '/heavy/diff-1/summary.txt', NS + '/heavy/run_diff.sh', NS + '/d-corebacked/sink_core_backed.ts'], assumptions=['DAFNY-JS', 'NODE-RT']),
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
         statement='SliceSafetyV2OnByteStrings: V2 with A6b in place of A6. SUPERSEDED: its byte layer rests on H3a, which is false for the real token (retired); see T-BYTES-R.',
         runs=[R(NS + '/b-signing/logs/final-V2OnBytes-01.log', 'worker b-signing', NS + '/b-signing', 'SliceSafetyV2OnBytes.dfy', NS + '/b-signing/logs/final-V2OnBytes-01.csv'),
               R(NS + '/recheck-b/SliceSafetyV2OnBytes.log', 'orchestrator B re-run', NS + '/b-signing', 'SliceSafetyV2OnBytes.dfy', NS + '/recheck-b/SliceSafetyV2OnBytes.csv'),
               R(NS + '/r-signing/logs/rerun-V2OnBytes.log', 'reviewer r-signing', NS + '/r-signing/work', 'SliceSafetyV2OnBytes.dfy', NS + '/r-signing/logs/rerun-V2OnBytes.csv')],
         required=V2B_REQ, binds_approved=True, retired_hypotheses=['H3a-SER-INJECTIVE'], superseded_by='T-BYTES-R',
         assumptions=['INITOK', 'A2-ISSUANCE', 'H1B-BYTES', 'H3b-SINK-REBUILDS', 'H3c-VERIFYTAG-IS-BYTES', 'B5-CRYPTO-BOOLEAN', 'A6b-BYTES']),
    dict(id='T-TOTAL', chain='T', frm='total verifier reading', to='hypotheses consistent without IdealMac', claimed='MACHINE-CHECKED', about='MODEL',
         statement='TotalReading: under a total verifier the V2 reading holds and IdealMac is false (34 verified).',
         runs=[R(NS + '/b-signing/logs/final-Total-01.log', 'worker b-signing', NS + '/b-signing', 'TotalReading.dfy', NS + '/b-signing/logs/final-Total-01.csv'),
               R(NS + '/recheck-b/TotalReading.log', 'orchestrator B re-run', NS + '/b-signing', 'TotalReading.dfy'),
               R(NS + '/r-signing/logs/rerun-Total.log', 'reviewer r-signing', NS + '/r-signing/work', 'TotalReading.dfy', NS + '/r-signing/logs/rerun-Total.csv')],
         required=TOTAL_REQ, assumptions=[]),
    dict(id='T-V3', chain='T', frm='model', to='core with request-id AND charge-id checks (SinkCoreV3, DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SinkCoreV3 (70 verified): MismatchNeverCommits, ForeignChargeNeverCommits, ChargeIdNowBound, StepExact, RunKeepsGoodV3 with no signature assumption; StepRefinesModelStep under A5; AuditStartIsGoodStart; NoGoodStartDuplicates.',
         runs=[R(NS + '/recheck-i/SinkCoreV3.log', 'orchestrator B re-run', NS + '/b-integrate', 'SinkCoreV3.dfy', NS + '/recheck-i/SinkCoreV3.csv'), R(NS + '/b-integrate/logs/final-SinkCoreV3-01.log', 'worker b-integrate', NS + '/b-integrate', 'SinkCoreV3.dfy', NS + '/b-integrate/logs/final-SinkCoreV3-01.csv')],
         required=['SinkCoreV3.MismatchNeverCommits', 'SinkCoreV3.ForeignChargeNeverCommits', 'SinkCoreV3.ChargeIdNowBound', 'SinkCoreV3.StepExact',
                   'SinkCoreV3.RunKeepsGoodV3', 'SinkCoreV3.FromInitGood', 'SinkCoreV3.AuditStartIsGoodStart', 'SinkCoreV3.NoGoodStartDuplicates',
                   'SinkCoreV3.ZeroAmountStillCommits', 'SinkCoreV3.Witness', 'SinkCoreV3.RefusesReqIdGap', 'SinkCoreV3.StepRefinesModelStep'],
         assumptions=['A5-VERIFIER-MATCH', 'GOODSTART']),
    dict(id='T-V3-L0', chain='T', frm='slice on the V3 core', to='committed effects have the charge id and the core invariant (L0)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SliceTheoremV3.SliceSafetyV3_L0_NoAssumption: no requires clause; trace from the empty store.',
         runs=[R(NS + '/recheck-i/SliceSafetyV3.log', 'orchestrator B re-run', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/recheck-i/SliceSafetyV3.csv'), R(NS + '/b-integrate/logs/final-SliceSafetyV3-01.log', 'worker b-integrate', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/b-integrate/logs/final-SliceSafetyV3-01.csv')], required=['SliceTheoremV3.SliceSafetyV3_L0_NoAssumption'], assumptions=['EMPTY-START']),
    dict(id='T-V3-L1', chain='T', frm='slice on the V3 core', to='core related to the model; every outbox tag verifies (L1)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SliceTheoremV3.SliceSafetyV3_L1_A5.', runs=[R(NS + '/recheck-i/SliceSafetyV3.log', 'orchestrator B re-run', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/recheck-i/SliceSafetyV3.csv'), R(NS + '/b-integrate/logs/final-SliceSafetyV3-01.log', 'worker b-integrate', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/b-integrate/logs/final-SliceSafetyV3-01.csv')], required=['SliceTheoremV3.SliceSafetyV3_L1_A5'], assumptions=['EMPTY-START', 'A5-VERIFIER-MATCH']),
    dict(id='T-V3-L2', chain='T', frm='slice on the V3 core', to='committed effects meet the approved spec; no over-refund (L2)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SliceTheoremV3.SliceSafetyV3_L2_Authentic and SliceSafetyV3; MainWitness non-vacuous; dropping H1 or A2 breaks the approved spec.',
         runs=[R(NS + '/recheck-i/SliceSafetyV3.log', 'orchestrator B re-run', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/recheck-i/SliceSafetyV3.csv'), R(NS + '/b-integrate/logs/final-SliceSafetyV3-01.log', 'worker b-integrate', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/b-integrate/logs/final-SliceSafetyV3-01.csv')], required=['SliceTheoremV3.SliceSafetyV3_L2_Authentic', 'SliceTheoremV3.SliceSafetyV3', 'SliceWitnessV3.MainWitness',
                            'SliceWitnessV3.DropH1BreaksApprovedSpec', 'SliceWitnessV3.DropA2BreaksApprovedSpec'], binds_approved=True,
         assumptions=['EMPTY-START', 'INITOK', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'H1-EUF-CMA']),
    dict(id='T-V3-L3', chain='T', frm='slice on the V3 core', to='committed effects also equal the artifact output on byte strings (L3)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='SliceTheoremV3.SliceSafetyV3_L3_Artifact; dropping A6b breaks the flat path; A6 implies A6b.',
         runs=[R(NS + '/recheck-i/SliceSafetyV3.log', 'orchestrator B re-run', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/recheck-i/SliceSafetyV3.csv'), R(NS + '/b-integrate/logs/final-SliceSafetyV3-01.log', 'worker b-integrate', NS + '/b-integrate', 'SliceSafetyV3.dfy', NS + '/b-integrate/logs/final-SliceSafetyV3-01.csv')], required=['SliceTheoremV3.SliceSafetyV3_L3_Artifact', 'SliceWitnessV3.DropA6bBreaksFlatPath', 'SliceTheoremV3.A6ImpliesA6b'], binds_approved=True,
         assumptions=['EMPTY-START', 'INITOK', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'H1-EUF-CMA', 'A6b-BYTES']),
    dict(id='T-MULTI', chain='T', frm='V3 core per charge', to='several charges: no cross-charge commit (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='MultiCharge.MultiChargeSafety, CrossChargeClosed, MisroutedRejected (141 verified); contrast: without the charge check a foreign charge commits.',
         runs=[R(NS + '/recheck-i/MultiCharge.log', 'orchestrator B re-run', NS + '/b-integrate', 'MultiCharge.dfy', NS + '/recheck-i/MultiCharge.csv'), R(NS + '/b-integrate/logs/final-MultiCharge-01.log', 'worker b-integrate', NS + '/b-integrate', 'MultiCharge.dfy', NS + '/b-integrate/logs/final-MultiCharge-01.csv')],
         required=['MultiCharge.MultiChargeSafety', 'MultiCharge.CrossChargeClosed', 'MultiCharge.MisroutedRejected', 'MultiCharge.SameRequestIdInTwoCharges',
                   'MultiChargeContrast.CrossChargeOpenWithoutChargeCheck', 'MultiChargeContrast.ForeignChargeCommitsWithoutCheck'],
         assumptions=['WELLKEYED', 'EMPTY-START']),
    dict(id='T-MULTI-L', chain='T', frm='layered theorem', to='several charges (L0-L2 per charge)', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='MultiChargeLayered.MultiLayeredAll, MultiLayered, MultiL0 (1730 verified).',
         runs=[R(NS + '/recheck-i/MultiChargeLayered.log', 'orchestrator B re-run', NS + '/b-integrate', 'MultiChargeLayered.dfy', NS + '/recheck-i/MultiChargeLayered.csv'), R(NS + '/b-integrate/logs/final-MultiChargeLayered-01.log', 'worker b-integrate', NS + '/b-integrate', 'MultiChargeLayered.dfy', NS + '/b-integrate/logs/final-MultiChargeLayered-01.csv')],
         required=['MultiChargeLayered.MultiLayeredAll', 'MultiChargeLayered.MultiLayered', 'MultiChargeLayered.MultiL0', 'MultiChargeLayered.MExecIsExecPerCharge'],
         assumptions=['WELLKEYED', 'EMPTY-START', 'INITOK', 'H1-EUF-CMA', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH']),
    dict(id='T-NOLOSS', chain='T', frm='V3 core', to='no honest commit lost against the earlier core', claimed='MACHINE-CHECKED', about='DRAFT',
         statement='AttackTrace.NoHonestCommitLost, V3EqualsV2UnderHyps: under H1, A2, A5 the core with both checks commits exactly when the earlier core commits; zero amount included.',
         runs=[R(NS + '/recheck-s/AttackTrace.log', 'orchestrator B re-run', NS + '/r-integrate', 'work/AttackTrace.dfy', NS + '/recheck-s/AttackTrace.csv')], required=['AttackTrace.NoHonestCommitLost', 'AttackTrace.V3EqualsV2UnderHyps', 'AttackTrace.NoStutterOnHonest', 'AttackTrace.HonestPasses'],
         assumptions=['H1-EUF-CMA', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH']),
    dict(id='T-V3-LIMITS', chain='T', frm='V3 core', to='limits of GoodStart and of a committed attack (review)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='AttackCore: GoodStartDoesNotBoundMoney (an audited store with refund 500 on original 100); CommittedAttackBurnsRequestId; RejectedAttackBurnsNothing.',
         runs=[R(NS + '/recheck-s/AttackCore.log', 'orchestrator B re-run', NS + '/r-integrate', 'work/AttackCore.dfy', NS + '/recheck-s/AttackCore.csv')], required=['AttackCore.GoodStartDoesNotBoundMoney', 'AttackCore.CommittedAttackBurnsRequestId', 'AttackCore.RejectedAttackBurnsNothing',
                              'AttackCore.V3LosesNoHonestCommit', 'AttackCore.ZeroAmountCases'], assumptions=[]),
    dict(id='T-MULTI-LIMIT', chain='T', frm='several charges', to='WellKeyed is necessary (counterexample)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='AttackMulti.NotWellKeyedDoubleRefund: one token commits in two databases that hold one charge id; InjectiveSuffices.',
         runs=[R(NS + '/recheck-s/AttackMulti.log', 'orchestrator B re-run', NS + '/r-integrate', 'work/AttackMulti.dfy', NS + '/recheck-s/AttackMulti.csv')], required=['AttackMulti.NotWellKeyedDoubleRefund', 'AttackMulti.InjectiveSuffices', 'AttackMulti.CommitForcesChargeId'], assumptions=[]),
    dict(id='T-SER', chain='T', frm='token body model (SerModel)', to='round trip, canonical parse, injective serialization', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SerModel.RoundTrip, ParseExact, SerBodyInjective, SerStateInjective, SignedBytesInjective, Utf8Injective (96 verified). That SerModel mirrors encoding.ts is NOT proved (T-SER-CONF).',
         runs=[R(NS + '/recheck-s/SerModel.log', 'orchestrator B re-run', NS + '/b-ser', 'SerModel.dfy', NS + '/recheck-s/SerModel.csv')], required=['SerModel.RoundTrip', 'SerModel.ParseExact', 'SerModel.SerBodyInjective', 'SerModel.SerStateInjective',
                              'SerModel.SignedBytesInjective', 'SerModel.Utf8Injective', 'SerModel.WitnessZeroAmount'], assumptions=[]),
    dict(id='T-SER-CONF', chain='T', frm='compiled SerModel', to='ts/refund-finality/encoding.ts bytes', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='One Node run, 443 bodies: text and bytes equal 443/443, parse agrees 443/443 (worker run b-ser; result.2.json). Lone surrogates not tested.',
         evidence=[NS + '/b-ser/conformance/result.2.json', NS + '/b-ser/conformance/run.ts', 'ts/refund-finality/encoding.ts'], assumptions=['DAFNY-JS', 'NODE-RT']),
    dict(id='T-BYTES-R', chain='T', frm='slice on bytes', to='SliceSafety on the real token encoding (repaired byte layer)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='RepairedBytes.SliceSafetyV2BytesRepaired with ClaimInjective (lemma), trace-local A4_NoCollisionInRun, H3d, B6 in place of H3a; CollisionControl; Witness; IssueBytes (1790 verified).',
         runs=[R(NS + '/recheck-s/RepairedBytes.log', 'orchestrator B re-run', NS, 'b-ser/RepairedBytes.dfy', NS + '/recheck-s/RepairedBytes.csv')], required=['RepairedBytes.SliceSafetyV2BytesRepaired', 'RepairedBytes.ClaimInjective', 'RepairedBytes.CollisionControl', 'RepairedBytes.Witness',
                              'RepairedBytes.IssueBytes', 'RepairedBytes.RepairedGiveClaimAuthenticity'], binds_approved=True,
         superseded_by='T-BYTES-V3', superseded_reason='value-comparing core; the real sink compares hashes (review r-ser D3; RSerAttacks, T-RSER)',
         assumptions=['INITOK', 'A2-ISSUANCE', 'H3b-SINK-REBUILDS', 'H3c-VERIFYTAG-IS-BYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'H3d-B6-PARSEABLE', 'A4-NOCOLL-RUN', 'A6b-BYTES']),
    dict(id='T-H3A-CE', chain='T', frm='H3a (serialization injective)', to='false for the real token (counterexample)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='ByteAttacks.PreStateCollisionBreaksApprovedSpec, HashedPreSerNotInjective (B re-run of the r-signing file; 1636 verified).',
         runs=[R(NS + '/recheck-b/ByteAttacks.log', 'orchestrator B re-run', NS + '/r-signing/work', 'ByteAttacks.dfy', NS + '/recheck-b/ByteAttacks.csv')], required=['ByteAttacks.PreStateCollisionBreaksApprovedSpec', 'ByteAttacks.HashedPreSerNotInjective'], assumptions=[]),
    dict(id='T-EXPORT', chain='T', frm='stored export bytes (read by gen_exported.py)', to='Dafny FlatContract (ExportedIffFlat)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='ExportBridge.ExportedIffFlat: the generated predicate of the three exported clauses holds exactly when FlatContract holds; trees equal the Mirror trees; reject-all fails (1823 verified).',
         runs=[R(NS + '/recheck-x/ExportBridge.log', 'orchestrator B re-run', NS + '/b-export-bridge', 'ExportBridge.dfy', NS + '/recheck-x/ExportBridge.csv')], required=['ExportBridge.ExportedIffFlat', 'ExportBridge.ExportedIffMirror', 'ExportBridge.RejectAllFails', 'ExportBridge.ClausesAreMirrorSources',
                              'ExportBridge.ReaderTreesAreMirrorTrees'], assumptions=['BETA-OPS'], evidence=[NS + '/b-export-bridge/gen_exported.py', NS + '/b-export-bridge/BRIDGE_STATEMENT.md']),
    dict(id='T-EXPORT-SLICE', chain='T', frm='slice', to='SliceSafety from the exported clauses (A6x)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='SliceFromExport.SliceSafetyFromExport; A6xIffA6b; RejectAllFailsA6x; FromExportCoversMainRun (1892 verified).',
         runs=[R(NS + '/recheck-x/SliceSafetyFromExport.log', 'orchestrator B re-run', NS + '/b-export-bridge', 'SliceSafetyFromExport.dfy', NS + '/recheck-x/SliceSafetyFromExport.csv')], required=['SliceFromExport.SliceSafetyFromExport', 'SliceFromExport.A6xIffA6b', 'SliceFromExportWitness.RejectAllFailsA6x', 'SliceFromExportWitness.FromExportCoversMainRun'],
         binds_approved=True, assumptions=['INITOK', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'H1-EUF-CMA', 'A6x-EXPORT']),
    dict(id='J1', chain='T', frm='Dafny artifact function (A6x, T-EXPORT-SLICE)', to='HOL refund_fields (S6)', claimed='ASSUMPTION', about='MODEL',
         statement='Where the Dafny lemma and the HOL theorem meet: the same 3,621 bytes on both sides; the function and value identity is assumed, the operator readings are argued.',
         assumptions=['A7-ART', 'BETA-VALUES', 'BETA-OPS', 'BETA-ORDER'], evidence=[NS + '/b-export-bridge/BRIDGE_STATEMENT.md']),
    # ---- [f3] added by f-binding-3: restart, keyed creation, issuer bytes, shell V3, hash core, Orchestrator A model chain
    dict(id='U9', chain='U', frm='existing database at a restart', to='a store state the sink may serve', claimed='MISSING', about='DEPLOYED',
         statement='sink.ts opens an existing SQLite file with no audit. The V3 MODEL has a restart theorem and an executable audit (T-RESTART, T-AUDIT, DRAFT); the draft sink_core_backed_v3.ts refuses a store that fails AuditStart (not deployed). Review r-restart: a rollback to an honest prefix and a forged init pass every audit over the database.',
         rests_on=['T-RESTART', 'T-AUDIT', 'T-SHELLV4'], assumptions=['NO-ROLLBACK', 'AUTHENTIC-INIT', 'EMPTY-START'], evidence=['ts/refund-finality/sink.ts']),
    dict(id='U10', chain='U', frm='creation of a charge store', to='one store per charge id (WellKeyed)', claimed='MISSING', about='DEPLOYED',
         statement='No deployed code creates charge stores under a key check: the TypeScript chargeKey check is opt-in and sits in an UNAPPLIED diff (b-restart). The MODEL invariant is T-KEYED (DRAFT). Delete + re-create defeats it (T-RESTART-ATTACK).',
         rests_on=['T-KEYED', 'T-KEYED-HASH', 'T-SAMEBYTES-ONCE'], assumptions=['CREATE-AUTHORITY', 'NO-DELETE-RECREATE', 'WELLKEYED'], evidence=['ts/refund-finality/dispatcher.ts']),
    dict(id='T-RESTART', chain='T', frm='V3 core run from a NON-EMPTY durable core', to='L0-L3 conclusions for old and new effects (ExecAppend, Restart)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U9',
         statement='RestartV3: ExecAppend (Exec(init, a0 + a) == ExecFrom(Exec(init, a0), a)), ExecFromCore (the continuation depends only on the durable core), Restart and RestartL0 (with H1Cont over the FULL history), RestartFromSound (1686 verified). Model of the V3 core; not sink.ts or SQLite. Review r-restart: CONFIRMED as model theorems.',
         runs=[R(NS + '/recheck-r/Restart.log', 'orchestrator B re-run', NS + '/b-restart', 'Restart.dfy', NS + '/recheck-r/Restart.csv'),
               R(NS + '/b-restart/logs/final-Restart-01.log', 'worker b-restart', NS + '/b-restart', 'Restart.dfy', NS + '/b-restart/logs/final-Restart-01.csv'),
               R(NS + '/r-restart/logs/verify-Restart-01.log', 'reviewer r-restart', NS + '/r-restart/work', 'Restart.dfy', NS + '/r-restart/logs/verify-Restart-01.csv')],
         required=['RestartV3.ExecAppend', 'RestartV3.ExecFromCore', 'RestartV3.Restart', 'RestartV3.RestartL0', 'RestartV3.RestartFromSound',
                   'RestartV3.H1LocalGivesCont', 'RestartV3.ContinueIsExec'], review_done=['r-restart (CONFIRMED, model)'],
         assumptions=['INITOK', 'H1-EUF-CMA', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH', 'NO-ROLLBACK']),
    dict(id='T-AUDIT', chain='T', frm='durable ledger of committed tokens', to='Sound store; money bound RELATIVE to the supplied init (AuditSound, AuditSpecMoney)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U9',
         statement='RestartV3: AuditSound (AuditFull + A5 rows + H1/A2 => Sound, money bound, sum equation); AuditComplete (every reachable core passes, no hypothesis); AuditFullSpec and AuditSpecMoney (per-row re-check of the approved relation: money bound with NO signature hypothesis, but only RELATIVE to the supplied init); BadCoreRefusedBySpecAudit; DropHistoryBreaksMoney. Review r-restart: the init is an unauthenticated input; rollback is not detectable by any audit over the database.',
         runs=[R(NS + '/recheck-r/Restart.log', 'orchestrator B re-run', NS + '/b-restart', 'Restart.dfy', NS + '/recheck-r/Restart.csv'),
               R(NS + '/b-restart/logs/final-Restart-01.log', 'worker b-restart', NS + '/b-restart', 'Restart.dfy', NS + '/b-restart/logs/final-Restart-01.csv')],
         required=['RestartV3.AuditSound', 'RestartV3.AuditComplete', 'RestartV3.AuditFullSpec', 'RestartV3.AuditSpecMoney', 'RestartV3.AuditSpecComplete',
                   'RestartV3.BadCoreRefusedBySpecAudit', 'RestartV3.DropHistoryBreaksMoney', 'RestartV3.AuditFullAloneAcceptsForgedLedger', 'RestartV3.ZeroAmountRowPasses'],
         binds_approved=True, review_done=['r-restart (CONFIRMED, model; HIGH limits)'],
         assumptions=['AUTHENTIC-INIT', 'NO-ROLLBACK', 'A5-VERIFIER-MATCH']),
    dict(id='T-KEYED', chain='T', frm='checked Create of charge stores', to='WellKeyed is an invariant; MultiChargeSafety with no hypothesis (KeyedL0, KeyedTop)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U10',
         statement='KeyedStore: KExecWellKeyed (from the empty map, every run of Mint/Create/Deliver keeps WellKeyed), KeyedL0, KeyedTop, KeyedTopMoney, CreateRefusals; contrast UncheckedCreateDoubleRefund; witness KeyedWitnessMain (1820 verified). No Delete action in the model.',
         runs=[R(NS + '/recheck-r/KeyedStore.log', 'orchestrator B re-run', NS + '/b-restart', 'KeyedStore.dfy', NS + '/recheck-r/KeyedStore.csv'),
               R(NS + '/b-restart/logs/final-KeyedStore-01.log', 'worker b-restart', NS + '/b-restart', 'KeyedStore.dfy', NS + '/b-restart/logs/final-KeyedStore-01.csv'),
               R(NS + '/r-restart/logs/verify-KeyedStore-01.log', 'reviewer r-restart', NS + '/r-restart/work', 'KeyedStore.dfy', NS + '/r-restart/logs/verify-KeyedStore-01.csv')],
         required=['KeyedStore.KExecWellKeyed', 'KeyedStore.KeyedL0', 'KeyedStore.KeyedTop', 'KeyedStore.KeyedTopMoney', 'KeyedStore.CreateRefusals',
                   'KeyedStore.UncheckedCreateDoubleRefund', 'KeyedStore.KeyedThenMultiChargeSafety', 'KeyedWitness.KeyedWitnessMain'],
         review_done=['r-restart (CONFIRMED, model; MEDIUM: delete+re-create; TS chargeKey opt-in)'],
         assumptions=['CREATE-AUTHORITY', 'NO-DELETE-RECREATE', 'H1-EUF-CMA', 'A2-ISSUANCE', 'A5-VERIFIER-MATCH']),
    dict(id='T-RESTART-ATTACK', chain='T', frm='restart audit and keyed model', to='rollback, forged init and delete+re-create pass (counterexamples)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='AttackRestart (reviewer r-restart): RollbackPassesAuditAndReplays, ForgedInitPassesSpecAudit, DeleteRecreateDoubleRefund; LossyRefused, LossyNotSound, ZeroAfterRestart (1831 verified). These fix the wording of T-RESTART, T-AUDIT, T-KEYED and the assumptions NO-ROLLBACK, AUTHENTIC-INIT, NO-DELETE-RECREATE.',
         runs=[R(NS + '/recheck-m/AttackRestart.log', 'orchestrator B re-run', NS + '/r-restart/work', 'AttackRestart.dfy', NS + '/recheck-m/AttackRestart.csv'),
               R(NS + '/r-restart/logs/final-AttackRestart-01.log', 'reviewer r-restart', NS + '/r-restart/work', 'AttackRestart.dfy', NS + '/r-restart/logs/final-AttackRestart-01.csv')],
         required=['AttackRestart.RollbackPassesAuditAndReplays', 'AttackRestart.ForgedInitPassesSpecAudit', 'AttackRestart.DeleteRecreateDoubleRefund',
                   'AttackRestart.LossyRefused', 'AttackRestart.LossyNotSound', 'AttackRestart.ZeroAfterRestart'], assumptions=[]),
    dict(id='T-ISSUEBYTES', chain='T', frm='RefundFinality.Check + token body', to='signed bytes (IssueTokenBytes: Some iff Authorizes && WfBody)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U2',
         statement='IssueBytes2.IssueTokenBytes: returns Some exactly when Check authorizes AND the body is well-formed (SerModel.WfBody); the bytes are Utf8(SerBody(body)); U+0000 refused in proved code; witnesses for issue, unauthorized, NUL and zero amount (131 verified). About the METHOD only; not minter.ts.',
         runs=[R(NS + '/recheck-m/IssueBytes2.log', 'orchestrator B re-run', NS + '/d-minter/src', 'IssueBytes2.dfy', NS + '/recheck-m/IssueBytes2.csv'),
               R(NS + '/d-minter/logs/v05-verify.log', 'worker d-minter', NS + '/d-minter/src', 'IssueBytes2.dfy', NS + '/d-minter/logs/v05-verify.csv')],
         required=['IssueBytes2.IssueTokenBytes', 'IssueBytes2.IssueWhen', 'IssueBytes2.WitnessIssue', 'IssueBytes2.WitnessUnauthorized',
                   'IssueBytes2.WitnessNul', 'IssueBytes2.WitnessZero', 'IssueBytes2.WfBodyExecOk'],
         assumptions=['G-H-PREHASH']),
    dict(id='T-ISSUEBYTES-CONF', chain='T', frm='compiled IssueBytes2 in the draft minter', to='decisions and body bytes of the real minter (DRAFT)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U2',
         statement='Worker Node run (d-minter/conf/result.3.json): 581 requests, 0 decision differences, 55 issued, body text byte-equal. Draft minter_issuebytes.ts signs only the returned bytes; not applied.',
         evidence=[NS + '/d-minter/conf/result.3.json', NS + '/d-minter/conf/run.ts', NS + '/d-minter/minter_issuebytes.ts'],
         assumptions=['DAFNY-JS', 'NODE-RT', 'G-H-PREHASH', 'A2P-ISSUEBYTES']),
    dict(id='T-SHELLV3', chain='T', frm='SinkCoreV3', to='shell step on hash tokens (StepP with preOk; DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U5b',
         statement='ShellCoreV3: StepPAgrees (StepP with preOk := (core.charge == pre) IS SinkCoreV3.Step), StepPExact, StepPKeepsGoodV3 (no assumption, any preOk/sigOk), StepPRefinesModelStep (under A5 and A4\' PreOkMatches), AuditStartIsGoodStart, AuditStartRefuses, ForeignChargeNeverCommitsP, Witness (79 verified). The worker log v01-shellv3-verify.log ends exit 4 (first attempt; not counted).',
         runs=[R(NS + '/d-v3sink/logs/v01-shellv3-verify-2.log', 'worker d-v3sink', NS + '/d-v3sink/dafny', 'ShellCoreV3.dfy', NS + '/d-v3sink/logs/v01-shellv3-verify-2.csv'),
               R(NS + '/recheck-d/ShellCoreV3.log', 'orchestrator B re-run (no CSV)', NS + '/d-v3sink/dafny', 'ShellCoreV3.dfy')],
         required=['ShellCoreV3.StepPAgrees', 'ShellCoreV3.StepPExact', 'ShellCoreV3.StepPKeepsGoodV3', 'ShellCoreV3.StepPRefinesModelStep',
                   'ShellCoreV3.AuditStartIsGoodStart', 'ShellCoreV3.AuditStartRefuses', 'ShellCoreV3.ForeignChargeNeverCommitsP', 'ShellCoreV3.Witness'],
         superseded_by='T-SHELLV4', superseded_reason='the v3 draft sink built on it is quadratic per commit inside the write lock and its audit does not bind the initial charge (review r-drafts); the v4 StepQ equals this step (ShellCoreV4.StepQAgrees), so the proof stays valid and is carried by T-SHELLV4',
         assumptions=['A5-VERIFIER-MATCH', 'A4-HASH-BINDS', 'GOODSTART']),
    dict(id='T-V3SINK-CONF', chain='T', frm='compiled ShellCoreV3', to='draft sink_core_backed_v3.ts behaviour', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U5b',
         statement='Worker Node run: 28 conformance cases as expected (d-v3sink/ts/conformance-v3-1.json); the draft refuses to start on a store that fails AuditStart.',
         evidence=[NS + '/d-v3sink/ts/conformance-v3-1.json', NS + '/d-v3sink/ts/conformance_v3.ts', NS + '/d-v3sink/sink_core_backed_v3.ts'],
         superseded_by='T-SHELLV4', superseded_reason='draft with a known defect (review r-drafts): quadratic cost per commit (7.4 s at 20,000 settled ids; failure at 200,000); audit at construction only and not bound to the initial charge; superseded by the v4 draft',
         known_defect='r-drafts: quadratic per commit; audit does not bind the initial charge.',
         assumptions=['DAFNY-JS', 'NODE-RT']),
    dict(id='U5v3-DIFF', chain='U', frm='compiled SinkCoreV3', to='draft V3 sinks (core-backed and hand-patched; foreign-charge tokens)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U5b',
         statement='[f4] The v3 core-backed draft is superseded by the v4 draft (U5v4-DIFF); kept as tests of the compiled V3 core. B heavy window 2 (heavy/v3-1): sinkcore-v3 against cb-v3 and hand-v3, 2,000 plain + 3 x 500 fault/interleave sequences each, exit 0 (0 divergences); control pairs (real sink, request-id-only sink, request-id core) diverge (exit 3, or exit 1 with replay divergences). Tests, no proof.',
         evidence=[NS + '/heavy/v3-1/summary.txt', NS + '/d-v3sink/heavy_v3.sh', NS + '/d-v3sink/sink_core_backed_v3.ts'], assumptions=['DAFNY-JS', 'NODE-RT']),
    dict(id='T-BYTES-V3', chain='T', frm='slice on the REAL token shape (hash of the pre-state only)', to='SliceSafety on a hash-comparing core (SliceSafetyBytesV3)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='HashCore + SliceSafetyBytesV3 + ControlsBytesV3 + RefineHashV3, ONE command with TWO root files (ControlsBytesV3.dfy RefineHashV3.dfy), 1871 verified. L0 no hypothesis; L2 InitOk + A2p + H1B + B5 + A4_HashBindsInRun; L3 adds A6b. No H3a/H3b/H3c/H3d/B6/A4b, no VerifyTag reading. Controls: dropping A2p, A4 or H1B breaks approval; total verifier witness with real-shaped values. RefineHashV3.StepAgrees relates HashCore.Step to SinkCoreV3.Step. Supersedes T-BYTES-R (value-comparing core; review r-ser D3).',
         runs=[R(NS + '/recheck-m/BytesV3.log', 'orchestrator B re-run', NS + '/b-ser2', ['ControlsBytesV3.dfy', 'RefineHashV3.dfy'], NS + '/recheck-m/BytesV3.csv'),
               R(NS + '/b-ser2/logs/final-all-01.log', 'worker b-ser2', NS + '/b-ser2', ['ControlsBytesV3.dfy', 'RefineHashV3.dfy'], NS + '/b-ser2/logs/final-all-01.csv')],
         required=['SliceSafetyBytesV3.SliceSafetyBytesV3', 'SliceSafetyBytesV3.SliceSafetyBytesV3_L0', 'SliceSafetyBytesV3.SliceSafetyBytesV3_L2', 'SliceSafetyBytesV3.SliceSafetyBytesV3_L3',
                   'ControlsBytesV3.Witness', 'ControlsBytesV3.DropA2pBreaksApproval', 'ControlsBytesV3.DropA4BreaksApproval', 'ControlsBytesV3.DropH1BBreaksApproval',
                   'ControlsBytesV3.TotalVBIsTotalAndUnique', 'ControlsBytesV3.ValidSigStillRejected', 'ControlsBytesV3.NoNegativeTwinOfZeroClaim',
                   'HashCore.BytesInjective', 'HashCore.MismatchNeverCommits', 'HashCore.ForeignChargeNeverCommits', 'HashCore.WrongHashNeverCommits',
                   'HashCore.StepExact', 'HashCore.ZeroAmountStillCommits', 'HashCore.RunKeepsGoodV3', 'RefineHashV3.StepAgrees', 'RefineHashV3.SideConditionFromBinding'],
         binds_approved=True,
         assumptions=['INITOK', 'A2P-ISSUEBYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS', 'A6b-BYTES', 'DECODER-TYPES']),
    dict(id='T-RSER', chain='T', frm='value-comparing byte layer (RepairedBytes)', to='its limits (review r-ser counterexamples)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='RSerAttacks (reviewer r-ser; B re-run 1804 verified): IssueNotParseable (Authorizes holds for a charge id with U+0000), B6Control (amount -1 clamps to the zero-amount bytes), ClaimInjectiveMoneyOnly. Basis of SUPERSEDED on T-BYTES-R.',
         runs=[R(NS + '/recheck-s/RSerAttacks.log', 'orchestrator B re-run', NS + '/r-ser', 'src/RSerAttacks.dfy', NS + '/recheck-s/RSerAttacks.csv')],
         required=['RSerAttacks.IssueNotParseable', 'RSerAttacks.B6Control', 'RSerAttacks.ClaimInjectiveMoneyOnly', 'RSerAttacks.NUL1'], assumptions=[]),
    dict(id='T-SER-CONF2', chain='T', frm='compiled SerModel', to='ts/refund-finality/encoding.ts on more and malformed inputs', claimed='TESTED-UNPROVED', about='DEPLOYED',
         statement='Reviewer r-ser Node run (r-ser/conf/result.2.json): 6,581 bodies + 4,736 malformed texts, 0 differences. Basis of SERMODEL-MIRRORS-ENCODING (TESTED).',
         evidence=[NS + '/r-ser/conf/result.2.json', NS + '/r-ser/conf/conf.ts', 'ts/refund-finality/encoding.ts'], assumptions=['DAFNY-JS', 'NODE-RT', 'SERMODEL-MIRRORS-ENCODING']),
    dict(id='X-MF', chain='X', frm='machine model of the exact code (stored premises)', to='exported clauses on the value of the only frame on fd 1 (refund_model_frame_meets_exported_contract)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='MF-0002 (Orchestrator A, theory forge_refundModelFrame): ONE HOL theorem, one kernel: machine model -> every behaviour at no_ext -> fd-1 bytes -> strict parse -> value = refund_fields of the request -> the three exported ensures clauses. Stored premises include the all-states FFI premise (FALSE for the real C, U393). Review A26: holds; 13 assumptions stand between it and the real consumer (MF-01..MF-13).',
         hol=dict(case='MF-0002'), required_theorems=['refund_model_frame_meets_exported_contract', 'refund_model_frame_decision', 'refund_fd1_frame_of_run',
                                                     'refund_model_success_gives_frame', 'refund_frame_contract_key'], review_done=['A26 (holds)'],
         assumptions=['HOL-TCB', 'X5-ENTRY', 'X6-FFI-ALL-STATES', 'X11-KERNEL'] + MF13),
    dict(id='X-MF1', chain='X', frm='machine model', to='strict-parse decision of the fd-1 frame (refund_model_frame_decision)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X-MF',
         statement='MF-0001: the decision part without the exported contract (11 theorems). Review A26: holds.',
         hol=dict(case='MF-0001'), required_theorems=['refund_model_frame_decision', 'refund_model_success_gives_frame', 'refund_fd1_frame_of_run'],
         review_done=['A26 (holds)'], assumptions=['HOL-TCB', 'X6-FFI-ALL-STATES']),
    dict(id='X-MG', chain='X', frm='machine model with the REDUCED premises (native contract at valid calls + R6)', to='same conclusion as X-MF (refund_model_frame_decision_events)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X-MF',
         statement='MG-0001: refund_model_frame_decision_events (antecedent of refund_profile_a_sl_events at no_ext; conclusion term-identical to MF-0002 as A states), refund_model_success_gives_frame_events. R6 is MISSING (A-R6). [f4] Review A27 (orch-A/review-L2d): G1 and G2 hold; visibly conditional on R6 and on the contract at VokY3-valid calls.',
         hol=dict(case='MG-0001'), required_theorems=['refund_model_frame_decision_events', 'refund_model_success_gives_frame_events', 'refund_frame_contract_upgrade',
                                                     'refund_model_frame_contract_of_reach'],
         assumptions=['HOL-TCB', 'A-R6', 'A-FFI-NATIVE-VALID'] + MF13),
    dict(id='X7-L2c', chain='X', frm='Route A premises', to='native contract at valid calls + R6 (refund_profile_a_sl_events)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L2c-0001: refund_profile_a_sl_reach at Vok := VokY3 with premise 3 replaced by R6 (29 theorems). Review A26: holds; R6 plausible, NOT proved.',
         hol=dict(case='L2c-0001'), required_theorems=['refund_profile_a_sl_events', 'refund_calls_premise_VokY3', 'refund_events_premise_gives_l2r_third_premise',
                                                      'refund_valid_event_gives_VokY3'], review_done=['A26 (holds)'],
         assumptions=['HOL-TCB', 'A-R6', 'A-FFI-NATIVE-VALID']),
    dict(id='X7-L2d', chain='X', frm='basis FFI oracle', to='shape predicate on returning calls (L2d)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='L2d-0001: refund_profile_a_sl_shape, l2d_model_frame_contract_of_reach, shape_predicate_rejects_u393_and_zero_length_states (27 theorems). [f4] Review A27 (orch-A/review-L2d): holds at MODEL level; wording: the remaining premise is satisfiable in the model, but no envmc that describes the original C meets it (the C aborts at shape-valid states).',
         hol=dict(case='L2d-0001'), required_theorems=['refund_profile_a_sl_shape', 'l2d_model_frame_contract_of_reach', 'shape_predicate_rejects_u393_and_zero_length_states',
                                                      'refund_l2r_third_premise_shape'],
         assumptions=['HOL-TCB']),
    dict(id='X11e-EF', chain='X', frm='ARM8 next-state function', to='frame lemmas (Next_frame, NextStateARM8_frame)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X11e',
         statement='EF-0001 (theory forge_m1bErasureFrame): Next_frame, NextStateARM8_frame, W_nonvacuous. Review A26: holds; a separate no-fault fact is needed. The step lift (ES) stays failed; X11e stays MISSING.',
         hol=dict(case='EF-0001'), required_theorems=['Next_frame', 'NextStateARM8_frame', 'W_nonvacuous'], review_done=['A26 (holds)'], assumptions=['HOL-TCB']),
    dict(id='X10-LEg', chain='X', frm='model halt (generic)', to='evaluate_Halt_reg and status controls', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X10',
         statement='LE-0003 (theory forge_refundLExitGen): evaluate_Halt_reg, machine_sem_of_evaluate_Halt, refund_halt_address, negative facts N_E1_status_collision, N_E2_silent_stop. X10 stays MISSING (halt-value range not derivable; real exit path open).',
         hol=dict(case='LE-0003'), required_theorems=['evaluate_Halt_reg', 'machine_sem_of_evaluate_Halt', 'refund_halt_address', 'N_E1_status_collision', 'N_E2_silent_stop'],
         assumptions=['HOL-TCB']),
    dict(id='E6-DRAFT', chain='E', frm='gate COPY with the draft subset rule', to='halting submissions refused (DRAFT)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='E6',
         statement='B heavy window 3 (heavy/gate-subset): halting 0 of 8 accepted. COST: G1-correct 10 of 19 accepted, new-correct 16 of 17 accepted; new-hostile 3 of 7 accepted. A gate copy, not the deployed gate; not applied.',
         evidence=[NS + '/heavy/gate-subset/summary.txt', NS + '/heavy/gate_subset.sh'], assumptions=['ADMISSION']),
    # ---- [f4] added by f-binding-4: top-level composition (b-top, r-top), repaired drafts (d-v3sink2, x-bridge2), A's EE and R6base
    dict(id='T-TOP', chain='T', frm='slice on the real token shape, issuer = IssueTokenBytes, artifact on the export', to='SliceSafetyBytesTop: committed effects approved on the STORED charge, minted, money bounds (byte level)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='IssuerLink.SliceSafetyBytesTop (2236 verified; B re-run): under InitOk, A2q (mints are outputs of IssueTokenBytes), H1B, B5, A4_HashBindsInRun and A6x (the artifact meets the predicate generated from the export bytes): Shape, every outbox effect has a FullEntry (approved by R1-R5 on the stored charge, bytes minted earlier, artifact output), GoodV3, 0 <= remaining <= original, sum equation. A2qImpliesA2p; BothIssuers; DropA2qBreaksApproval; NulMintIsA2pNotA2q. Review r-top: CONFIRMED. Glue outside the lemma: G-H (one hash on both sides), minter glue, DAFNY-JS. InitOk is NOT enforced by sink.ts.',
         runs=[R(NS + '/recheck-t/IssuerLink.log', 'orchestrator B re-run', NS + '/b-top/src', 'IssuerLink.dfy', NS + '/recheck-t/IssuerLink.csv'),
               R(NS + '/b-top/logs/final-IssuerLink-01.log', 'worker b-top', NS + '/b-top/src', 'IssuerLink.dfy', NS + '/b-top/logs/final-IssuerLink-01.csv')],
         required=['IssuerLink.SliceSafetyBytesTop', 'IssuerLink.A2qImpliesA2p', 'IssuerLink.IssueTokenBytesExactlyOut', 'IssuerLink.BothIssuers', 'IssuerLink.OutIsIssuedFrom',
                   'IssuerLinkControls.WitnessTop', 'IssuerLinkControls.DropA2qBreaksApproval', 'IssuerLinkControls.NulMintIsA2pNotA2q', 'TopFromExport.SliceSafetyBytesFromExport'],
         binds_approved=True, evidence=[NS + '/b-top/logs/audit-btop-01.md'],
         assumptions=['INITOK', 'A2Q-ISSUETOKENBYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS', 'A6x-EXPORT', 'DECODER-TYPES', 'G-H-PREHASH']),
    dict(id='T-TOP-EXPORT', chain='T', frm='byte-level slice (SliceSafetyBytesV3)', to='the same with the artifact hypothesis stated on the EXPORT (A6x)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='TopFromExport.SliceSafetyBytesFromExport, A6xIffA6bV3, FlatContractsAgree, ToExpBijective; controls WitnessFromExport, RejectAllFailsA6x, FlatSpecFnMeetsA6x (2185 verified; B re-run). Review r-top: CONFIRMED; reviewer lemma RTopLemmas.ToExpFieldwise (ToExp maps each of the nine fields to the same-named field: the identity bijection). Reviewer mutants: one-sided charge/request swap and both-sides original/remaining swap exit 4; a both-sides enabled/requestOpen swap still verifies (exit 0; contract symmetric in those fields, as BETA-ORDER).',
         runs=[R(NS + '/recheck-t/TopFromExport.log', 'orchestrator B re-run', NS + '/b-top/src', 'TopFromExport.dfy', NS + '/recheck-t/TopFromExport.csv'),
               R(NS + '/b-top/logs/final-TopFromExport-01.log', 'worker b-top', NS + '/b-top/src', 'TopFromExport.dfy', NS + '/b-top/logs/final-TopFromExport-01.csv')],
         required=['TopFromExport.SliceSafetyBytesFromExport', 'TopFromExport.A6xIffA6bV3', 'TopFromExport.FlatContractsAgree', 'TopFromExport.ToExpBijective',
                   'TopFromExportControls.WitnessFromExport', 'TopFromExportControls.RejectAllFailsA6x', 'TopFromExportControls.FlatSpecFnMeetsA6x'],
         binds_approved=True, evidence=[NS + '/r-top/logs/mut-TopFromExport_M2b_swapEnabledOpen_bothSides-01.log', NS + '/r-top/logs/mut-TopFromExport_M1a_swapCR_oneSided-01.log'],
         assumptions=['INITOK', 'A2P-ISSUEBYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS', 'A6x-EXPORT', 'DECODER-TYPES', 'BETA-OPS']),
    dict(id='T-KEYED-HASH', chain='T', frm='checked creation of charge stores over the HASH core', to='KeyedL0Hash (no hypothesis) and KeyedTopHash (per charge)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U10',
         statement='KeyedHash (2325 verified; B re-run): KeyedL0Hash with NO hypothesis (WellKeyed invariant, a delivery changes only its routed store, every effect in store k has charge id k, no two effects share (charge id, request id)); KeyedTopHash per charge under InitOk-at-creation (enforced by the MODEL create check), A2pK or A2qK, H1BK, B5K, A4K. Contrast UncheckedCreateDoubleRefund; MisroutedNeverCommits; witnesses. Outside the model: no delete/re-create, authentic init at creation, no rollback. The keyed store has no TypeScript counterpart. Review r-top: CONFIRMED (reviewer mutants M3 no key-absent check, M4 route by token: exit 4).',
         runs=[R(NS + '/recheck-t/KeyedHash.log', 'orchestrator B re-run', NS + '/b-top/src', 'KeyedHash.dfy', NS + '/recheck-t/KeyedHash.csv'),
               R(NS + '/b-top/logs/final-KeyedHash-01.log', 'worker b-top', NS + '/b-top/src', 'KeyedHash.dfy', NS + '/b-top/logs/final-KeyedHash-01.csv'),
               R(NS + '/r-top/logs/v-KeyedHash-01.log', 'reviewer r-top', NS + '/r-top/src', 'KeyedHash.dfy', NS + '/r-top/logs/v-KeyedHash-01.csv')],
         required=['KeyedHash.KeyedL0Hash', 'KeyedHash.KeyedTopHash', 'KeyedHash.KExecWellKeyed', 'KeyedHash.KStepFrame', 'KeyedHash.TopAllKeys',
                   'KeyedHashControls.KeyedWitness', 'KeyedHashControls.UncheckedCreateDoubleRefund', 'KeyedHashControls.MisroutedNeverCommits',
                   'KeyedHashControls.CommitAllBreaksL0', 'KeyedHashControls.RejectAllFailsWitness'],
         binds_approved=True, evidence=[NS + '/r-top/logs/mut-KeyedHash_M3_noKeyAbsentCheck-01.log', NS + '/r-top/logs/mut-KeyedHash_M4_routeByTok-01.log'],
         assumptions=['CREATE-AUTHORITY', 'NO-DELETE-RECREATE', 'NO-ROLLBACK', 'AUTHENTIC-INIT', 'A2P-ISSUEBYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS']),
    dict(id='T-SAMEBYTES-ONCE', chain='T', frm='keyed hash model (any signature)', to='the same signed bytes commit at most once across all stores', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U10',
         statement='RTopLemmas.SameBytesCommitOnce (reviewer r-top; B re-run 2336 verified): NO hypothesis; also NoDoubleCommit, NoTwoStoresEqualCharges, CommitKey, Mono, ToExpFieldwise. Holds in the keyed MODEL, which has no delete, no re-create of a present key and no rollback action: the real-world reading needs NO-DELETE-RECREATE and NO-ROLLBACK. Reviewer-authored lemma: no separate review.',
         runs=[R(NS + '/recheck-t/RTopLemmas.log', 'orchestrator B re-run', NS + '/r-top/src', 'RTopLemmas.dfy', NS + '/recheck-t/RTopLemmas.csv'),
               R(NS + '/r-top/logs/v-RTopLemmas-01.log', 'reviewer r-top', NS + '/r-top/src', 'RTopLemmas.dfy', NS + '/r-top/logs/v-RTopLemmas-01.csv')],
         required=['RTopLemmas.SameBytesCommitOnce', 'RTopLemmas.NoDoubleCommit', 'RTopLemmas.NoTwoStoresEqualCharges', 'RTopLemmas.CommitKey', 'RTopLemmas.Mono', 'RTopLemmas.ToExpFieldwise'],
         evidence=[NS + '/r-top/logs/audit-RTopLemmas-01.md'], assumptions=['NO-DELETE-RECREATE', 'NO-ROLLBACK']),
    dict(id='T-REFINE-TRACE', chain='T', frm='HashCore traces (A2p, H1B, B5, A4)', to='a SinkCoreV3 value run with the same core step by step (store-level simulation)', claimed='MACHINE-CHECKED', about='MODEL',
         statement='RefineTraceV3.ValueRunExists, StepAgreesWeak, Sim/SimHolds/SimNext (1889 verified; B re-run): lifts RefineHashV3.StepAgrees to traces. LIMIT: a core-level simulation only; the restart lemma (T-RESTART) and other SinkCoreV3 trace theorems do NOT transfer, because their hypotheses (A2/A5/H1 over Claim and VerifyTag) are not derived on the constructed value trace. Review r-top: CONFIRMED.',
         runs=[R(NS + '/recheck-t/RefineTraceV3.log', 'orchestrator B re-run', NS + '/b-top/src', 'RefineTraceV3.dfy', NS + '/recheck-t/RefineTraceV3.csv'),
               R(NS + '/b-top/logs/final-RefineTraceV3-01.log', 'worker b-top', NS + '/b-top/src', 'RefineTraceV3.dfy', NS + '/b-top/logs/final-RefineTraceV3-01.csv'),
               R(NS + '/r-top/logs/v-RefineTraceV3-01.log', 'reviewer r-top', NS + '/r-top/src', 'RefineTraceV3.dfy', NS + '/r-top/logs/v-RefineTraceV3-01.csv')],
         required=['RefineTraceV3.ValueRunExists', 'RefineTraceV3.StepAgreesWeak', 'RefineTraceV3.SimHolds', 'RefineTraceV3.SimNext'],
         assumptions=['A2P-ISSUEBYTES', 'H1B-BYTES', 'B5-CRYPTO-BOOLEAN', 'A4-HASH-BINDS']),
    dict(id='T-SHELLV4', chain='T', frm='ShellCoreV3 step and AuditStart', to='constant-state step StepQ and a streaming start-up audit bound to the initial charge (v4 DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U5b',
         statement='ShellCoreV4 (105 verified; B re-run): StepQAgrees (applying the StepQ result IS ShellCoreV3.StepP when alreadySettled == (requestId in settled), so every V3 result transfers), StepQIsStep, StepQExact, StepQKeepsGoodV3, ForeignChargeNeverCommitsQ, SettledNeverCommits, zero amount commits; StreamIsAuditStartBound: under A-DB1..A-DB3 the fold of AuditStep plus AuditEnd IS AuditStart(core) && stored chargeId == initId (binds the initial charge id from the meta row); ReviewerD2cRefused; Witness. Worker mutants (no binding, ignore hit, reject all, ignore settled) exit 4. Not about sink_core_backed_v4.ts (TS-LOOP-IS-FOLD). Review r-repairs (STATE 11:20:08Z): the audit gives STRUCTURAL facts only; it does not conserve money against a hostile writer to the database (balance reset: a second refund, T-V4-ATTACK); the draft ignores cfg.initialState when the database holds one and does not check the schema. A v5 draft is in work (not in this ledger).',
         runs=[R(NS + '/recheck-d/ShellCoreV4.log', 'orchestrator B re-run', NS + '/d-v3sink2/dafny', 'ShellCoreV4.dfy', NS + '/recheck-d/ShellCoreV4.csv'),
               R(NS + '/d-v3sink2/logs/v-shellv4-verify-1.log', 'worker d-v3sink2', NS + '/d-v3sink2/dafny', 'ShellCoreV4.dfy', NS + '/d-v3sink2/logs/v-shellv4-verify-1.csv')],
         required=['ShellCoreV4.StepQAgrees', 'ShellCoreV4.StepQIsStep', 'ShellCoreV4.StepQExact', 'ShellCoreV4.StepQKeepsGoodV3', 'ShellCoreV4.StreamIsAuditStartBound',
                   'ShellCoreV4.ForeignChargeNeverCommitsQ', 'ShellCoreV4.SettledNeverCommits', 'ShellCoreV4.StepQZeroAmountCommits', 'ShellCoreV4.ReviewerD2cRefused',
                   'ShellCoreV4.ForeignStoredChargeRefused', 'ShellCoreV4.Witness'],
         evidence=[NS + '/d-v3sink2/logs/a-audit-1.log', NS + '/d-v3sink2/logs/mB-nobinding-1.log', NS + '/d-v3sink2/logs/mR-rejectall-1.log'],
         assumptions=['A-DB1', 'A-DB2', 'A-DB3', 'A5-VERIFIER-MATCH', 'A4-HASH-BINDS', 'AUTHENTIC-INIT', 'NO-ROLLBACK', 'DB-NO-FOREIGN-WRITER']),
    dict(id='T-SHELLV4-JS', chain='T', frm='ShellCoreV4.dfy', to='compiled JS used by sink_core_backed_v4.ts (DRAFT)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='U5b',
         statement='dafny build --target js verifies (worker run) and emits shellcore-v4.js; the JS is not proved (DAFNY-JS).',
         runs=[R(NS + '/d-v3sink2/logs/b-shellv4-build-1.log', 'worker d-v3sink2', NS + '/d-v3sink2/dafny', 'ShellCoreV4.dfy', NS + '/d-v3sink2/logs/b-shellv4-build-1.csv', role='build')],
         required=['ShellCoreV4.StepQAgrees', 'ShellCoreV4.StreamIsAuditStartBound'], artifacts=[NS + '/d-v3sink2/build/shellcore-v4.js', NS + '/d-v3sink2/build/shellcore-v4.cjs'],
         assumptions=['DAFNY-JS']),
    dict(id='U5v4-DIFF', chain='U', frm='compiled SinkCoreV3 core', to='draft v4 sink (sink_core_backed_v4.ts) and v3 drafts', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U5b',
         statement='B heavy window 4 (heavy/v4-1): sinkcore-v3 against cb-v4, cb-v3 and hand-v3, 2,000 plain + 3 x 500 fault/interleave sequences each: exit 0 (0 divergences); controls diverge (real sink.ts exit 3 or 1; request-id-only core against cb-v4 exit 3). Tests, no proof (TS-LOOP-IS-FOLD).',
         evidence=[NS + '/heavy/v4-1/summary.txt', NS + '/d-v3sink2/heavy_v4.sh', NS + '/d-v3sink2/sink_core_backed_v4.ts'],
         assumptions=['DAFNY-JS', 'NODE-RT', 'TS-LOOP-IS-FOLD']),
    dict(id='T-V4SINK-CONF', chain='T', frm='compiled ShellCoreV4', to='draft sink_core_backed_v4.ts behaviour and cost', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U5b',
         statement='Worker runs (d-v3sink2): conformance n01 exit 0 (conformance-v4-1.json); scaling s01 (1k-10k) and s02 (100k settled rows) exit 0, commit time flat (worker: about 1-2 ms); smoke h01 exit 0. Single worker runs; not B runs.',
         evidence=[NS + '/d-v3sink2/logs/n01-conformance-v4-1.log', NS + '/d-v3sink2/ts/conformance-v4-1.json', NS + '/d-v3sink2/logs/s01-scale-1k-10k-1.log',
                   NS + '/d-v3sink2/logs/s02-scale-100k-1.log', NS + '/d-v3sink2/ts/conformance_v4.ts'],
         assumptions=['DAFNY-JS', 'NODE-RT', 'TS-LOOP-IS-FOLD', 'A-DB1', 'A-DB2', 'A-DB3']),
    dict(id='T-BRIDGE2', chain='X', frm='compiled checker `check` and native side `native` (PARAMETERS), one input', to='issue decision Bridge2 (single-input dual check with post-state recomputation; DRAFT model)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='X16',
         statement='Bridge2Model (22 verified; B re-run): SoundNative (CodecOk + NativeOkOn on the ONE encoded input + Sign => Authorizes and the token is the authorized one), SoundCheck (CodecOk + check sound + Sign => the same), Complete (both right => Sign of the authorized token); AttackPostState and AttackSeparateInputs: the first bridge signs, Bridge2 refuses. So a wrong checker alone, or a wrong native program alone, cannot cause a signature for an unauthorized transition (MODEL level). Worker controls C1-C5 (drop post, drop intent, ignore native, ignore check, reject all) exit 4. Not about decide2.py, the launcher or the binary. Review r-repairs: holds; the codec link is an assumption (CODEC-OK); see T-BRIDGE2-ATTACK for its limits.',
         runs=[R(NS + '/recheck-xb/Bridge2.log', 'orchestrator B re-run', NS + '/x-bridge2/dafny', 'Bridge2.dfy', NS + '/recheck-xb/Bridge2.csv'),
               R(NS + '/x-bridge2/dafny/logs/verify-bridge2.2.log', 'worker x-bridge2', NS + '/x-bridge2/dafny', 'Bridge2.dfy', NS + '/x-bridge2/dafny/logs/verify-bridge2.2.csv')],
         required=['Bridge2Model.SoundNative', 'Bridge2Model.SoundCheck', 'Bridge2Model.Complete', 'Bridge2Model.AttackPostState', 'Bridge2Model.AttackSeparateInputs', 'Bridge2Model.Witnesses'],
         evidence=[NS + '/x-bridge2/dafny/logs/audit-bridge2.1.log', NS + '/x-bridge2/dafny/logs/control-C3-ignore-native.1.log', NS + '/x-bridge2/dafny/logs/control-C4-ignore-check.1.log', NS + '/x-bridge2/BRIDGE2_DESIGN.md'],
         assumptions=['CODEC-OK', 'NATIVE-OK-ON-INPUT', 'STRICT-FRAME']),
    dict(id='T-BRIDGE2-TEST', chain='X', frm='real M1 binary through the repaired draft launcher', to='issue decision of decide2.py (DRAFT)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='X16',
         statement='B run (recheck-xb/tests2.log): tests2.py 90 of 90 with the real native program, exit 0. Worker mutants2: 22 mutants, 16 killed, 6 survived. The Python code is tested, not proved.',
         evidence=[NS + '/recheck-xb/tests2.log', NS + '/x-bridge2/tests2.py', NS + '/x-bridge2/decide2.py', NS + '/x-bridge2/launcher.py', NS + '/x-bridge2/frame.py', NS + '/x-bridge2/logs/mutants2.1.log'],
         assumptions=['A-LOADER', 'OS-PROC', 'CODEC-OK', 'STRICT-FRAME']),
    dict(id='X11e-EE', chain='X', frm='real register values (TBI0, SA0 set)', to='whole-step erasure NextStateARM8_erase (for all s)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X11e',
         statement='EE-0001 (101 theorems): NextStateARM8_erase is the E1-0003 target text word for word, for all s; Next_erase_sp; W_nonvacuous. Review A31: HOLDS. MISSING: non-vacuity for an interesting state (TBI0 or SA0 set and a non-fault step); the lift to runs needs "the erased run never faults" and native facts N1-N5. X11e stays MISSING.',
         hol=dict(case='EE-0001'), required_theorems=['NextStateARM8_erase', 'Next_erase_sp', 'W_nonvacuous', 'BranchImmediate_erase_untagged', 'BranchRegister_erase_untagged'],
         assumptions=['HOL-TCB', 'X5-ENTRY']),
    dict(id='X7-R6base', chain='X', frm='FFI event traces of the totalised machine', to='R6 base facts (every_clock_events; replay cannot exclude error-return events)', claimed='MACHINE-CHECKED', about='MODEL', sub_of='X7',
         statement='R6base-0001 (11 theorems): every_clock_events, every_of_three_parts, refund_valid_event_implies_weak, and the NEGATIVE fact replay_cannot_exclude_error_return_events (the replay equation alone does not make every event valid). Review A31: HOLDS with limits (its bad event has an empty configuration; a stronger bad event is UNCHECKED). R6 itself stays MISSING (A-R6).',
         hol=dict(case='R6base-0001'), required_theorems=['every_clock_events', 'replay_cannot_exclude_error_return_events', 'every_of_three_parts', 'refund_valid_event_implies_weak'],
         assumptions=['HOL-TCB']),
    dict(id='T-BRIDGE2-ATTACK', chain='X', frm='Bridge2 model (unchanged copy)', to='limits: codec faults and two wrong sides sign (review counterexamples)', claimed='MACHINE-CHECKED', about='DRAFT', sub_of='X16',
         statement='AttackR (reviewer r-repairs; B re-run 30 verified): SoundCheckNoCodec (SoundCheck needs no CodecOk); SharedEncoderSignsWrongRequest and CaseFoldedReasonSigns (a codec fault on the native side plus an accept-all checker signs an unauthorized transition); BothWrongSigns; InvalidPreRefused; NoneRefuses. Reviewer-authored lemmas: no separate review. The reviewer EXPECTFAIL file ends exit 4 as it must.',
         runs=[R(NS + '/recheck-xb/AttackR.log', 'orchestrator B re-run', NS + '/r-repairs/b2', 'AttackR.dfy', NS + '/recheck-xb/AttackR.csv'),
               R(NS + '/r-repairs/logs/b2-attack.1.log', 'reviewer r-repairs', NS + '/r-repairs/b2', 'AttackR.dfy', NS + '/r-repairs/logs/b2-attack.1.csv')],
         required=['AttackR.SoundCheckNoCodec', 'AttackR.SharedEncoderSignsWrongRequest', 'AttackR.CaseFoldedReasonSigns', 'AttackR.BothWrongSigns', 'AttackR.InvalidPreRefused', 'AttackR.NoneRefuses'],
         evidence=[NS + '/r-repairs/logs/b2-expectfail.1.log'], assumptions=[]),
    dict(id='T-V4-ATTACK', chain='U', frm='hostile writer to the v4 draft database', to='second refund after a balance reset; cfg.initialState ignored; schema unchecked (review run)', claimed='TESTED-UNPROVED', about='DRAFT', sub_of='U5b',
         statement='Reviewer r-repairs Node run (attack_v4.1.log, exit 0 = the attack script ran): S1 balance reset: two commits, refunded 2000 on original 1000, the re-audit passed; S5 meta rewrite: cfg.initialState ignored, commit; S4 NOCASE schema: started and committed; S6 legacy store without the meta hash: refused. A counterexample shown by a run, against the v4 DRAFT; the deployed sink.ts has no audit at all.',
         evidence=[NS + '/r-repairs/logs/attack_v4.1.log', NS + '/r-repairs/attack_v4.ts'], assumptions=['DB-NO-FOREIGN-WRITER', 'AUTHENTIC-INIT']),
    dict(id='ADOPT-DIFF', chain='U', frm='p-adopt/adoption.diff (ab2ca0da...; v4 sink, issue-bytes minter, dispatcher check)', to='applies at 985f5eaf (git apply --check)', claimed='TESTED-UNPROVED', about='DRAFT',
         statement='Recorded `git apply --check` exit 0 at base 985f5eaf (worker log p-adopt/logs/make_diff-1.log; ADOPTION_PACKET.md section 1; Orchestrator B STATE.md 11:18:00Z states its own check exit 0, no stored log); 10 files, no protected or clearing/ path. NOT applied. Not re-run by this task. B heavy window 5: Slice 1 suite 115 rows, 0 failed, pristine and with the diff (p-adopt/suite/attempt-1/summary.txt). Review r-repairs: a tested candidate, not a finished one.',
         evidence=[NS + '/p-adopt/adoption.diff', NS + '/p-adopt/logs/make_diff-1.log', NS + '/p-adopt/ADOPTION_PACKET.md', NS + '/p-adopt/suite/attempt-1/summary.txt'],
         assumptions=['ADMISSION', 'TS-LOOP-IS-FOLD', 'DB-NO-FOREIGN-WRITER']),
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
    dict(id='E6', chain='E', frm='gate admission (expect rule + supervision diff, patched copy)', to='excludes run-time halts on rare inputs', claimed='MISSING', about='GOVERNANCE',
         statement='MISSING for the DEPLOYED gate. COUNTER-EVIDENCE (B run, heavy/hostile): seven submissions that halt or hang on one keyed amount (E06, E07, E08, H01b, H02, H03, H04) all get "ACCEPTED: T1 T2 T3", exit 0, through a patched gate copy. A DRAFT subset rule refuses halting 0 of 8 accepted at a cost of 9 of 19 G1-correct refused (E6-DRAFT, TESTED); not applied.',
         evidence=[NS + '/heavy/hostile/summary.txt', NS + '/heavy/hostile/heavy-H04-seq-length-2pow32-throws.log', NS + '/heavy/hostile_controls.sh'], assumptions=['ADMISSION']),
    dict(id='E1', chain='E', frm='new code', to='gate verdict', claimed='MISSING', about='GOVERNANCE', statement='Gate answered UNSUPPORTED for the new files.', assumptions=['ADMISSION']),
    dict(id='E2', chain='E', frm='gate verdict', to='merge', claimed='MISSING', about='GOVERNANCE', statement='main is not protected.', assumptions=['ADMISSION']),
    dict(id='E3', chain='E', frm='change of a protected file', to='refusal', claimed='MACHINE-CHECKED', about='GOVERNANCE',
         statement='Hosted run 44454558079 REJECTED: a ROADMAP sentence only; no stored log.', assumptions=['ADMISSION'], no_log=True),
    dict(id='E4', chain='E', frm='checker, prover, deployer', to='three trust domains', claimed='MISSING', about='GOVERNANCE', statement='One account with admin rights.', assumptions=['ADMISSION']),
    dict(id='E5', chain='E', frm='merge', to='protected state', claimed='MISSING', about='GOVERNANCE', statement='No admission check exists.', assumptions=['ADMISSION']),
]

MANDATORY = ['S1', 'S2', 'S3', 'S3a', 'S4', 'S5', 'S6', 'S7', 'X1', 'X2', 'X3', 'X5', 'X6', 'X7', 'X8', 'X9', 'X10', 'X12', 'X15',
             'X16', 'U1', 'U1c', 'U2', 'U3', 'U4', 'U5a', 'U5b', 'U6', 'U7', 'U8', 'V1', 'V2', 'V6', 'E1', 'E2',
             'T-V2', 'T-V2B', 'T-TOTAL', 'U5r', 'U5r-CONTRAST',
             # [f2]
             'S6-RENDER', 'X16-DRAFT', 'X16-TEST', 'T-V3', 'T-V3-L0', 'T-V3-L1', 'T-V3-L2', 'T-V3-L3', 'T-MULTI', 'T-MULTI-L', 'T-NOLOSS',
             'T-SER', 'T-SER-CONF', 'T-BYTES-R', 'T-H3A-CE', 'T-EXPORT', 'T-EXPORT-SLICE', 'J1', 'E6',
             # [f3]
             'U9', 'U10', 'T-RESTART', 'T-AUDIT', 'T-KEYED', 'T-RESTART-ATTACK', 'T-ISSUEBYTES', 'T-SHELLV3', 'T-BYTES-V3', 'T-RSER',
             'X-MF', 'X-MG', 'X7-L2c', 'X11e-EF', 'E6-DRAFT', 'U5v3-DIFF',
             # [f4]
             'T-TOP', 'T-TOP-EXPORT', 'T-KEYED-HASH', 'T-SAMEBYTES-ONCE', 'T-REFINE-TRACE', 'T-SHELLV4', 'T-BRIDGE2', 'T-BRIDGE2-TEST',
             'U5v4-DIFF', 'X11e-EE', 'X7-R6base', 'T-BRIDGE2-ATTACK', 'T-V4-ATTACK', 'ADOPT-DIFF']
# The order of the chain in COMPOSED_GUARANTEE.md: approved contract -> durable committed state.
CHAIN_ORDER = ['S1', 'S2', 'S3', 'S3a', 'S4', 'S7', 'S5', 'S6', 'S8', 'X1', 'X2', 'X5', 'X6', 'X7', 'X11', 'X3', 'X4', 'X8', 'X9', 'X10',
               'X13', 'X14', 'X15', 'X16', 'U1', 'U1c', 'U2', 'U6', 'U3', 'U5b', 'U5a', 'U4', 'U9', 'U10', 'U7']
CHAIN_ORDER_F2 = [x for x in CHAIN_ORDER if x not in ('U9', 'U10')]   # [f3] the 33 ids of f-binding-2, for comparison

# [f4] Review state as data. An edge listed here is `reviewed: true`; each directory must be REPORTED (REPORT.md inside it,
# or a `<folder> REPORTED` line in orch-B/STATE.md); the generator downgrades to `reviewed: false` (with the reason) when it
# is not. An edge with `review_pending` is `reviewed: 'pending'`; every other edge is `reviewed: false` (none).
def _rv(dirs, verdict, ids):
    return {i: (dirs, verdict) for i in ids}


REVIEWS = {}
REVIEWS.update(_rv([NS + '/r-signing'], 'confirmed (MORNING section 1 row 2)', ['T-V2', 'T-V2B', 'T-TOTAL']))
REVIEWS.update(_rv([NS + '/r-integrate'], 'confirmed (MORNING section 1 rows 3, 4)', ['T-V3', 'T-V3-L0', 'T-V3-L1', 'T-V3-L2', 'T-V3-L3', 'T-MULTI', 'T-MULTI-L']))
REVIEWS.update(_rv([NS + '/r-restart'], 'confirmed as model theorems, narrowed (row 6)', ['T-RESTART', 'T-AUDIT', 'T-KEYED']))
REVIEWS.update(_rv([NS + '/r-ser'], 'confirmed, narrowed (row 7)', ['T-SER', 'T-BYTES-R']))
REVIEWS.update(_rv([NS + '/r-export'], 'confirmed; 15 semantic export mutants break it (row 8)', ['T-EXPORT', 'T-EXPORT-SLICE']))
REVIEWS.update(_rv([NS + '/r-reqid'], 'confirmed, narrowed (row 11)', ['U5r', 'U5r-CONTRAST']))
REVIEWS.update(_rv([NS + '/r-bytes3'], 'CONFIRMED (U547); glue G-H; A2p class; InitOk not enforced by sink.ts', ['T-BYTES-V3']))
REVIEWS.update(_rv([NS + '/r-drafts'], 'proofs CONFIRMED (U548); drafts weaker than stated: first bridge, v3 sink, minter hash input', ['T-ISSUEBYTES', 'T-SHELLV3', 'U5c', 'X16-DRAFT']))
REVIEWS.update(_rv([NS + '/r-drafts'], 'review found a defect of the draft (U548)', ['T-ISSUEBYTES-CONF', 'T-V3SINK-CONF', 'X16-TEST']))
REVIEWS.update(_rv([NS + '/r-top'], 'CONFIRMED (U550); ToExpFieldwise; SameBytesCommitOnce', ['T-TOP', 'T-TOP-EXPORT', 'T-KEYED-HASH', 'T-REFINE-TRACE']))
REVIEWS.update(_rv([NS + '/r-repairs'], 'bridge model holds; codec link is an assumption (U553)', ['T-BRIDGE2', 'T-BRIDGE2-TEST']))
REVIEWS.update(_rv([NS + '/r-repairs'], 'proof not refuted; v4 audit structural only: over-refund after a hostile balance reset, cfg.initialState ignored, schema unchecked (U553)',
                   ['T-SHELLV4', 'T-SHELLV4-JS', 'U5v4-DIFF', 'T-V4SINK-CONF']))
REVIEWS.update(_rv([OA + '/review-link'], 'A17: MACHINE-CHECKED in HOL', ['S5', 'S5-REL', 'S5-BR', 'S5-IMP', 'S6']))
REVIEWS.update(_rv([OA + '/review-L1'], 'A7: machine-checked; L1 alone does not remove the false FFI premise', ['X7-L1', 'X7-L1imp']))
REVIEWS.update(_rv([OA + '/review-L2'], 'A12: MACHINE-CHECKED', ['X7-L2']))
REVIEWS.update(_rv([OA + '/review-L2b-PX'], 'A18: MACHINE-CHECKED', ['X7-L2b', 'X13-PX']))
REVIEWS.update(_rv([OA + '/review-LO'], 'A22: no false statement; within scope', ['X9-LO']))
REVIEWS.update(_rv([OA + '/review-PF'], 'A13: no defect', ['X13-PF']))
REVIEWS.update(_rv([OA + '/review-E1'], 'A10: no false theorem', ['X11e-E1']))
REVIEWS.update(_rv([OA + '/review-MF'], 'A26: holds (MODEL level)', ['X-MF', 'X-MF1', 'X7-L2c', 'X10-LE', 'X11e-EF']))
REVIEWS.update(_rv([OA + '/review-L2d'], 'A27: holds (MODEL level); one wording defect', ['X-MG', 'X7-L2d']))
REVIEWS.update(_rv([OA + '/review-EE'], 'A31: holds (R6base with limits)', ['X11e-EE', 'X7-R6base']))


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
        rp = L.cmd_roots_problem(cmd, run)   # [f3] the command's .dfy set must equal the closure roots
        if rp:
            probs.append(rp)
        if run.get('csv'):
            if self.tree.exists(run['csv']):
                run['csv_sha256'] = self.tree.sha(run['csv'])
            else:
                probs.append('csv missing')
        try:
            same = run['root'] == edge_closure.get('root')
            rows, missing = self.closure(run['root'], L.entry_arg(run), edge_closure.get('overlay') if same else None,
                                         edge_closure.get('derive') if same else None)
            run['closure_digest'] = L.set_digest(rows)
            if missing:
                probs.append('closure missing %s' % missing)
        except Exception as e:
            probs.append('closure error %s' % e)
            run['closure_digest'] = None
        try:   # [f2] advisory only: a closure file modified after the log start (not a gate; mtimes do not survive copies)
            st = L.header(text, 'start')
            if st:
                t0 = datetime.datetime.strptime(st, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()
                newer = [f for f, _ in rows if (self.repo / run['root'] / f).exists() and (self.repo / run['root'] / f).stat().st_mtime > t0 + 1]
                if newer:
                    run['advisory_newer_than_log'] = newer[:5]
        except Exception:
            pass
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
        if prim.get('entries'):   # [f3]
            clo['entries'] = list(prim['entries'])
        rows, missing = self.closure(prim['root'], L.entry_arg(prim), overlay, derive)
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
        """[f2] HOL case(s) of Orchestrator A. Folder RA (route A: run id = case id) or LINK (case id -> run id).
        Fail closed: see the module docstring. Classes: no log or no exit line -> UNKNOWN-TONIGHT; `go exit N`, N != 0
        -> MISSING (attempt failed); any other problem -> CLAIMED, log missing (with downgrade_reason)."""
        h = e['hol']
        folder = h.get('folder', RA)
        cases = [(h['case'], h.get('run', h['case']))] + list(h.get('extra', []))
        out['checker'] = dict(name='HOL4 (Poly/ML), run by Orchestrator A (go wrapper; run_case.py)',
                              version='HOL4 9783a499..., CakeML cd915569..., Poly/ML 5.9.2 as stated in orch-A/FIELDS_FOR_B.md (not re-derived)')
        out['ran_by'] = 'Orchestrator A (A ran it; B read the log and run record)'
        out['required_theorems'] = e.get('required_theorems', [])
        out['required_lines'] = e.get('required_lines', [])
        out['command'] = 'FORGE_CPU_SECONDS=<n> go wrapper %s (folder %s)' % (h['case'], folder)
        supporting, other, reasons, src_sha = [], [], [], None
        prim_state = None
        for i, (case, rid) in enumerate(cases):
            log, rjp = folder + '/%s.go.log' % case, folder + '/%s.run.json' % rid
            run = dict(log=log, case_id=case, run_id=rid, run_json=rjp, role='hol-case', ran_by=out['ran_by'])
            probs = []
            if not self.tree.exists(log):
                probs.append('go log %s absent' % log)
                state = 'nolog'
            else:
                text = self.tree.text(log)
                run['log_sha256'] = self.tree.sha(log)
                form, ex = L.parse_exit(text)
                run['exit_line_form'], run['exit'] = form, ex
                state = 'ok'
                rjt = self.tree.text(rjp) if self.tree.exists(rjp) else ''
                if L.is_explore(text, rjt):   # [f3] an exploration run proves nothing, whatever its exit line says
                    probs.append('exploration run (%s in the log or run record): proves nothing' % L.EXPLORE_MARK)
                    run['exploration_run'] = True
                if form != 'hol-go-wrapper':
                    probs.append('no `go exit N` last line (last line %r)' % L.last_line(text)[:60])
                    state = 'nolog'
                elif ex != 0:
                    probs.append('attempt failed: go exit %d' % ex)
                    state = 'failed'
                if self.tree.exists(rjp):
                    run['run_json_sha256'] = self.tree.sha(rjp)
                    d = json.loads(self.tree.text(rjp) or '{}')
                    run['source_sha256_in_run_json'] = d.get('source_sha256')
                    run['actual_exit_in_run_json'] = d.get('actual_exit')
                    srcp = folder + '/' + str(d.get('source'))
                    if not self.tree.exists(srcp) or self.tree.sha(srcp) != d.get('source_sha256'):
                        probs.append('source %s absent or digest differs from the run record' % srcp)
                    if i == 0:
                        src_sha = d.get('source_sha256')
                        rows = [(srcp, self.tree.sha(srcp))] if self.tree.exists(srcp) else []
                        hj = folder + '/%s.hashes.json' % case
                        for f in (hj, rjp):
                            if self.tree.exists(f):
                                rows.append((f, self.tree.sha(f)))
                        for f, _ in rows:
                            self.node(f)
                        out['closure'] = dict(kind='HOL case: source + parent-hash record (if any) + run record',
                                              files=[dict(path=p_, sha256=h_) for p_, h_ in rows], count=len(rows), digest=L.set_digest(rows))
                    elif d.get('source_sha256') != src_sha:
                        probs.append('source differs from the primary run source')
                    elif Path(str(d.get('source'))).name != Path(out['closure']['files'][0]['path']).name:
                        probs.append('same source digest but another file name (%s); the verifier pins the closure source name' % d.get('source'))
                    if d.get('actual_exit') != 0 and state == 'ok':
                        probs.append('run record actual_exit %r' % d.get('actual_exit'))
                    if d.get('inputs_unchanged_after') is not True:
                        probs.append('inputs_unchanged_after %r' % d.get('inputs_unchanged_after'))
                    if d.get('case') != rid:
                        probs.append('run record case %r is not %r' % (d.get('case'), rid))
                    cl = L.hol_command(text)
                    if cl is not None and (' %s ' % rid not in cl + ' ' or ' %s' % d.get('source') not in cl):
                        probs.append('COMMAND line does not name %s and %s' % (rid, d.get('source')))
                else:
                    probs.append('run record %s absent' % rjp)
                if state == 'ok':
                    probs += L.hol_check_names(text, out['required_theorems'], out['required_lines'])
            if i == 0:
                prim_state = state
            if probs:
                run['not_counted_because'] = probs
                other.append(run)
                if i == 0:
                    reasons = probs
            else:
                supporting.append(run)
                self.node(log)
                self.node(rjp)
        ctl = []
        for cid, want in h.get('controls', []):
            clog = folder + '/%s.go.log' % cid
            c = dict(id=cid, log=clog, expected_exit=want)
            if self.tree.exists(clog):
                c['log_sha256'] = self.tree.sha(clog)
                form, ex = L.parse_exit(self.tree.text(clog))
                c['exit'], c['exit_line_form'] = ex, form
                self.node(clog)
                if form != 'hol-go-wrapper' or ex != want:
                    reasons = reasons + ['control %s ends %r %r, expected go exit %d' % (cid, form, ex, want)]
            else:
                reasons = reasons + ['control %s log absent' % cid]
            ctl.append(c)
        if ctl:
            out['controls'] = ctl
        out['runs'] = supporting
        out['runs_not_counted'] = other
        if prim_state == 'nolog':
            out['class'] = 'UNKNOWN-TONIGHT'
        elif prim_state == 'failed':
            out['class'] = 'MISSING'
        elif reasons or not supporting:
            out['class'] = 'CLAIMED, log missing'
        else:
            out['class'] = 'MACHINE-CHECKED'
        if out['class'] != 'MACHINE-CHECKED':
            out['downgrade_reason'] = reasons or ['no supporting run']

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
                  NS + '/r-reqid/dafny/inputs/sink/Attack.dfy', OA + '/review-L1/REPORT.md',
                  NS + '/b-integrate/SinkCoreV3.dfy', NS + '/b-integrate/SliceSafetyV3.dfy',
                  NS + '/b-ser/SerModel.dfy', NS + '/b-ser/RepairedBytes.dfy', NS + '/b-export-bridge/ExportBridge.dfy',
                  NS + '/b-export-bridge/SliceSafetyFromExport.dfy', NS + '/x-issuer-bridge/dafny/Bridge.dfy', NS + '/recheck-f/rerun.out']:
            self.node(p)
        edges = []
        for i, e in enumerate(EDGES):
            out = dict(id=e['id'], chain=e['chain'], order=i, frm=e['frm'], to=e['to'], statement=e['statement'],
                       claimed_class=e['claimed'], about=e['about'], assumptions=e.get('assumptions', []))
            if e.get('sub_of'):
                out['sub_of'] = e['sub_of']
            if e.get('binds_approved'):
                out['binds_approved_spec'] = True
            for k in ('retired_hypotheses', 'superseded_by', 'superseded_reason', 'review_pending', 'review_done', 'tested_by', 'rests_on', 'known_defect'):   # [f2], [f3], [f4]
                if e.get(k):
                    out[k] = e[k]
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
            # [f4] review state as data (fail closed: a review that is not REPORTED never counts)
            if e['id'] in REVIEWS:
                if e.get('review_pending'):
                    raise SystemExit('REFUSED: edge %s is in REVIEWS and also lists review_pending' % e['id'])
                out['reviewed'], out['review_dirs'], out['review_verdict'] = True, list(REVIEWS[e['id']][0]), REVIEWS[e['id']][1]
            elif e.get('review_pending'):
                out['reviewed'] = 'pending'
            else:
                out['reviewed'] = False
            rp = L.review_problems(self.tree, out)
            if rp and out['reviewed'] is True:
                out['reviewed'] = False
                out['review_downgrade'] = rp
            elif rp:
                raise SystemExit('REFUSED: edge %s review data: %s' % (e['id'], rp))
            out['evidence'] = [p for p in e.get('evidence', []) if self.node(p)]
            out['evidence_missing'] = [p for p in e.get('evidence', []) if not self.tree.exists(p)]
            edges.append(out)
        used = {}
        for ed in edges:
            for a in ed['assumptions']:
                used.setdefault(a, []).append(ed['id'])
        assumptions = []
        for i, t, rw, rz in ASSUMPTIONS:
            a = dict(id=i, text=t, real_world=rw, realizable=rz, status='active', used_by=used.get(i, []))
            a.update(ASSUMPTION_EXTRA.get(i, {}))
            if a['status'] == 'retired' and a['used_by']:   # [f2] fail closed: never emit an edge that uses a retired assumption
                raise SystemExit('REFUSED: retired assumption %s is used by %s' % (i, a['used_by']))
            if a.get('counterexample'):
                self.node(a['counterexample'])
            assumptions.append(a)
        known = set(x[0] for x in ASSUMPTIONS)
        for ed in edges:
            for a in ed['assumptions']:
                if a not in known:
                    raise SystemExit('REFUSED: edge %s names unknown assumption %s' % (ed['id'], a))
        byid = {ed['id']: ed for ed in edges}
        for ed in edges:   # [f3] fail closed: `superseded_by` must name a MACHINE-CHECKED edge of this ledger
            s = ed.get('superseded_by')
            if s and (s not in byid or byid[s]['class'] != 'MACHINE-CHECKED'):
                raise SystemExit('REFUSED: edge %s is superseded_by %r, which is not a MACHINE-CHECKED edge' % (ed['id'], s))
        ssp = L.superseded_support_problems(edges)   # [f4] a superseded edge may not be the only support of another edge
        if ssp:
            raise SystemExit('REFUSED: %s' % '; '.join('%s %s' % x for x in ssp))
        counts = {c: sum(1 for ed in edges if ed['class'] == c) for c in L.CLASSES}
        led = dict(
            schema='forge.nightshift.assurance-ledger/1',
            what_a_pass_means=L.BANNER_IDENTITY + '. A pass of verify_ledger.py shows that the stored bytes, logs and records '
                              'agree with each other now. It does not show that a theorem is true, that it means what its statement says, or '
                              'that a reference value was computed by an independent party (V5).',
            repository_commit=subprocess.run(['git', '-C', str(self.repo), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip(),
            generated_utc=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            generator='results/night-shift-20261119/orch-B/f-binding-4/make_ledger.py',
            previous_ledger='results/night-shift-20261119/orch-B/f-binding-3/ASSURANCE_LEDGER.json',
            # [f2] live documents (rewritten by the orchestrators during the night): read, NOT pinned as nodes, because a pinned
            # digest goes stale within minutes. No edge rests on them; every edge rests on logs, records and sources.
            context_documents=[OA + '/FIELDS_FOR_B.md (A refresh 09:38Z read)', OA + '/STATE.md', OA + '/MORNING.md (interim)',
                               NS + '/STATE.md (up to 11:20Z)', NS + '/MORNING.md (addenda 1-8)', OA + '/review-*/REPORT.md'],
            reviews_pending=sorted(set(r for ed in edges for r in ed.get('review_pending', []))),
            review_rule='[f4] reviewed is true/false/pending; true needs review_dirs that are REPORTED (REPORT.md in the folder, or a "<folder> REPORTED" line in ' + L.STATE_B + ')',
            superseded_rule='[f4] an edge whose rests_on (or, without rests_on, whose sub-edges) are ALL superseded is refused (SUPERSEDED_SOLE_SUPPORT)',
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
        ev = '; '.join('`%s`: %s; %s' % (r['log'].split('/orch-B/')[-1].split('night-shift-20261119/')[-1], r.get('exit'), r.get('ran_by')) for r in e.get('runs', []))
        if not ev and e.get('runs_not_counted'):
            ev = 'not counted: ' + '; '.join('`%s`: %s' % (r['log'].split('/')[-1], r.get('exit')) for r in e['runs_not_counted'])
        if e.get('controls'):
            ev += '; controls ' + ', '.join('%s=%s' % (c['id'], c.get('exit')) for c in e['controls'])
        if not e.get('runs') and e.get('evidence'):
            ev = (ev + '; ' if ev else '') + 'evidence: ' + ', '.join('`%s`' % p.split('/')[-1] for p in e['evidence'][:3])
        if e.get('superseded_by'):
            ev += ' **[superseded by %s; %s]**' % (e['superseded_by'], ('retired hypotheses %s' % e['retired_hypotheses']) if e.get('retired_hypotheses')
                                                    else e.get('superseded_reason', ''))
        if e.get('review_pending'):   # [f3]
            ev += ' **[review pending: %s]**' % ', '.join(e['review_pending'])
        if e.get('reviewed') is True:   # [f4]
            ev += ' [reviewed: %s]' % ', '.join(d.split('/')[-1] for d in e.get('review_dirs', []))
        if e.get('known_defect'):
            ev += ' **[known defect: %s]**' % e['known_defect']
        if e.get('rests_on'):
            ev += ' [rests on: %s]' % ', '.join(e['rests_on'])
        if not ev and e.get('prior_records'):
            ev = 'prior: ' + '; '.join('`%s`%s' % (p['path'].split('/')[-1], ' actual_exit=%s' % p['recorded_actual_exit'] if 'recorded_actual_exit' in p else '') for p in e['prior_records'])
        if e.get('downgrade_reason'):
            ev += ' **[%s]**' % '; '.join(map(str, e['downgrade_reason']))[:220]
        clo = ('%d files `%s`' % (e['closure']['count'], e['closure']['digest'][:12])) if e.get('closure') else '-'
        o.append('| %s | %s | %s -> %s | %s (%s) | %s | %s | %s | %s |' % (
            e['id'], e['chain'], e['frm'], e['to'], e['class'], e['claimed_class'], e['about'], ev or '-', clo, ', '.join(e['assumptions']) or '-'))
    o += ['', '## Assumptions', '', '| Id | Status | Group / basis | Text | Real-world reading | Realizable | Used by |', '|---|---|---|---|---|---|---|']
    for a in led['assumptions']:
        st = a.get('status', 'active') + ('; %s; counterexample `%s` (%s)' % (a.get('retired_reason'), a.get('counterexample'), a.get('counterexample_lemma')) if a.get('counterexample') else
                                          ('; %s' % a.get('retired_reason') if a.get('retired_reason') else ''))
        if a.get('superseded_for'):   # [f3]
            st += '; superseded for %s' % a['superseded_for']
        if a.get('maps_to'):
            st += '; maps to %s' % ', '.join(a['maps_to'])
        o.append('| %s | %s | %s | %s | %s | %s | %s |' % (a['id'], st, ' / '.join(x for x in [a.get('group'), a.get('basis'), a.get('source')] if x) or '-', a['text'], a['real_world'],
                                                         a['realizable'], ', '.join(a['used_by']) or '-'))
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
