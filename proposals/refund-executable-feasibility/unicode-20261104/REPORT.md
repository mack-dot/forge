# Refund UTF-8 representation — checked source transport

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
Source representation verdict: **LOCALLY_VALIDATED**.
Exact native refund assurance: **NOT_ESTABLISHED**. `end_to_end=false`.

## Assurance link closed

The approved refund contract permits every Dafny Unicode string. The published
CakeML/Dafny model uses byte strings. Low-byte truncation cannot connect them.
This experiment uses the existing Dafny 4.11 UTF-8 library and proves the
representation properties needed by the unchanged refund decision.

`RefundUtf8Transport.Equivalent` has no input precondition. For every approved
context and response constructor, it applies the existing flat refund method
to UTF-8 byte representations. It establishes the same eligibility, amount,
reason and intent count. It copies the encoded charge and request IDs exactly.
Rejected inputs return false, zero amount/count and empty output strings.
The approved mathematical integer domain and all response constructors remain.

The representation proofs establish:

- `ScalarCast.Int24RoundTrip` and `CharScalar`: every Dafny character maps
  losslessly to the library's scalar type, without an added axiom.
- `ScalarRoundTrip` and `SequenceRoundTrip`: the published decoder reverses
  the published encoder for every scalar and every finite scalar sequence.
- `EncodedIsBytes`: all representation characters have values below256.
- `EncodedInjective` and `EncodedEmpty`: identity and empty/nonempty status
  are preserved for all Unicode strings.
- `AsciiFixed` and `SameReasons`: the three exact approved reason strings
  remain unchanged, and no other string acquires an allowed reason identity.
- `StringRoundTrip` and `ByteViewIdentity`: the actual encoded byte values
  match the library encoding, and decoding recovers the original characters.

These results compose with the source transport proof. Caller-ID recovery is
justified by the inverse relation; it is not an assertion that encoded bytes
equal the original Unicode character sequence. Witnesses cover U+0100,
U+10FFFF, a NUL ID, an eligible amount and an over-limit refusal.

The encoder and decoder algorithms are unchanged published library functions.
Local helpers only project existing scalar, byte and character types. No custom
decoder, verifier, machine semantics or new axiom was introduced.

## Exact source and trusted base

Final proof source SHA256:
`804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990`.

The upstream library is pinned to Dafny commit
`fcb2042d6d043a2634f0854338c08feeaaaf4ae2` (v4.11.0). The24 selected library
files are byte-identical copies, with hashes in `library-identity.json`.
Verification uses the existing Dafny4.11.0 and Z3 4.12.1 binaries.
`tool-identities.json` records versions, binary and assembly hashes.

The upstream [character wrapper](https://github.com/dafny-lang/dafny/blob/fcb2042d6d043a2634f0854338c08feeaaaf4ae2/Source/DafnyStandardLibraries/src/Std/Unicode/UnicodeStringsWithUnicodeChar.dfy#L27)
contains an explicit axiom. That module is excluded. Its hash and finding are
in `excluded-wrapper.json`. The new character conversion proof discharges the
needed property without importing that wrapper. The unchanged
[UTF-8 encoding library](https://github.com/dafny-lang/dafny/blob/fcb2042d6d043a2634f0854338c08feeaaaf4ae2/Source/DafnyStandardLibraries/src/Std/Unicode/Utf8EncodingForm.dfy)
and its included source dependencies are reverified. Abstract encoding-form
interfaces are instantiated by the checked concrete refinement.

The received conditional transport source is also verified in this run.
Its independent local record is commit
`73728c2efa94b452637dfd10f36546f6f8a08d23`, on the separate proposal branch.
See [that report](../string-transport-20261104/REPORT.md).
`transport-identity.json` binds the exact copied source and unchanged approved
specification/implementation. That earlier result alone was conditional. The
new UTF-8 lemmas discharge its representation premises for all source inputs.

Dafny, Boogie, Z3, their runtime and the host remain trusted. This run produces
source verification, not a new independently checked HOL/Rocq certificate.
Hashes bind local identities; they do not authenticate an external producer.
No new checker profile or library is adopted into protected admission policy.

## Actual commands and results

Each runner command invokes pinned `dafny verify UnicodeRelation.dfy` with
`--verify-included-files --cores 1 --resource-limit 1000000
--verification-time-limit 0`. Named difficult lemmas use an explicit20million
resource limit. Exact argument arrays and source snapshots are retained.
No timeout, resource failure or zero-symbol diagnostic counts as a proof.

| Runner command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -B run.py 0001` / `0002` | 4/4 | Character/scalar proof resource exhaustion; retained |
| `python3 -B run.py 0003` / `0004` | 4/4 | Split scalar proof succeeds; integer-cast helper exhausts resources; complete result still fails |
| `python3 -B run.py 0005` | 0 | Isolated integer lemma and scalar proof succeed; no further attempt needed |
| `python3 -B run.py sequence-0001` | 4 | Inferred subset types and an omitted map projection cause three proof failures |
| `python3 -B run.py sequence-0002` | 0 | Explicit sequence types and map projections close those obligations |
| `python3 -B run.py transport-0001` | 4 | Reason lemma resource exhaustion; indentation warnings retained |
| `python3 -B run.py transport-0002` | 0 | Full source transport and string inverse properties pass |
| `python3 -B run.py final` / `repeat` | 0/0 |1426 assertion batches each; all included source obligations pass |
| `python3 -B run.py substituted-id ...` | 4 | Unconditional substitution violates rejected-output empty charge |
| `python3 -B run.py accepted-id ...` | 4 | Conditional substitution violates the accepted caller-charge identity |
| `python3 -B run.py over-limit ...` | 4 | Claim that61 is authorized against remaining60 is refused |
| `python3 -B run.py truncation ...` | 4 | Original U+0100 low-byte identity assertion is refused |
| Pinned `dafny audit UnicodeRelation.dfy ...` | 0 | Zero findings; this audit is separate from verification |
| Acceptance/source/repeat comparison | 0 | Exact negative reasons and30 identical input files checked |
| Original-input postflight | 0 |30 frozen owner-workspace inputs unchanged |

The first substitution control failed the rejected-output condition. It did
not establish the intended accepted-ID control. That result is preserved.
A separate mutation substitutes only on acceptance. Its diagnostic points to
`charge == Encoded(context.chargeId)`. Neither required postcondition changed.
The original truncation source is retained byte for byte.

Final/repeat local wall times are33.995498125 and32.948114625 seconds. These
are proof execution observations, not application latency or hosted savings.
All source bytes and per-symbol outcomes match. Timing-bearing CSV/log files
are not claimed to be byte-identical proof certificates.

The earlier translation diagnostic selected zero symbols and checked no proof.
A separate raw Z3 cast query returned `unsat`; it was only a diagnostic.
Acceptance rests on the later complete Dafny executions, not that query.

## Reproduction

Use the pinned Dafny/Z3 release and retained library/source bytes. Run in a
fresh copy of this packet. The runner's `ROOT` identifies the original local
tool installation; adjust only that installation path for another machine.
Run `python3 -B run.py replay-0001`, then another fresh positive attempt.
For each negative, pass its `negative-*/UnicodeRelation.dfy` source as the
second argument and use a new attempt name. Require exit4 and the exact
recorded assertion/postcondition failure. Parse failures or resource exhaustion
are not acceptable negative outcomes. Run the recorded Dafny audit separately.

The packet retains the shared24-file library once. Raw repeated copies and
generated Boogie translations remain in the local archive, with their hashes
in `raw-only-files.json`. Original failure records are not deleted or replaced.

## Remaining boundary and next action

This closes a source-level representation obligation. It does not by itself
prove that a physical caller supplies the modeled namespace, that native code
executes the method, or that an operating system exposes its returned tuple.
The prior HOL method/caller theorem remains unchanged. The source-to-model
representation argument still needs explicit review and binding in the final
assurance profile. No new native executable or runtime theorem is established.

Next: connect the same generated method to the existing whole-program compiler
and checked calling/I/O infrastructure. Inspect the required `prim_sem_env`,
program behavior, installed bytes and machine-entry premises. The existing
Marshalling helpers handle fixed-width values; they do not alone cover arbitrary
integers or strings. Do not narrow the approved domain to fit those helpers.
The pinned `mlsexp.fromString_sexp_to_string` theorem and `SexpProg.inputSexp_spec`
provide an existing parser/I/O route to check next. Their source was inspected;
their application to refund has NOT RUN. Use their established escaping and
integer representation before considering any new protocol implementation.
Preserve explicit resource-limit and runtime assumptions from the compiler proof.

Native artifact identity, concrete execution and authenticated independent
admission remain open. Hosted refund execution and measurements are NOT RUN.
Off-machine archive hash/restore validation remains open. No publication,
merge, dispatch, signing, admission, deployment or Stage12 occurred.
