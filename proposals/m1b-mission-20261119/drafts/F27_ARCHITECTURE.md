# F2.7 architecture: one machine-code theorem from request bytes to token bytes (SPECIFICATION DRAFT)

Worker W7, step IV of `proposals/m1b-mission-20261119/MISSION.md`
(Phase IV). Date 2026-11-19. Draft in a scratch folder. NOT in the
repository. NOT approved. Nothing here was built or run. No HOL,
Holmake, Poly/ML, Dafny or Docker process was started. Every theorem
name below that starts with `f27_` is a PROPOSED name: no such theorem
exists. `end_to_end=false`. M1 is open. F2.7 stays NOT STARTED.

Sources read (read-only): `FORGE_MASTER_IDEA.md` rows F2.0 to F2.7;
`proposals/forge2-pillar2-refund-finality/CAKEML_LINK.md`;
`proposals/forge2-pillar2-finality-protocol/DESIGN.md` and
`FinalityProtocol.dfy`; `impl/RefundFinality.dfy`;
`tests/refund-finality/Bindings.dfy`; `ts/refund-finality/*.ts`;
`spec/refund/RefundSpec.dfy` and `spec/refund/protocol.md`; the Slice 1
report and review; the conformance report (sections 5, 7, 8);
`docs/demo-gauntlet.md`; the M1 owner-review packet and the owner
decisions; the M1 replay sources on `origin/backup/forge-local-2026-11-11`;
the Profile A proof record
`proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/final-cases/e4-0001/`;
the pinned trees under `.toolchain/experiments/refund-cakeml-20261104/`
(CakeML `cd915569…`, HOL4 `9783a499…`).

Abbreviations: `CK` = `.toolchain/experiments/refund-cakeml-20261104/cakeml`;
`HOLT` = `.toolchain/experiments/refund-cakeml-20261104/HOL`;
`RS` = `proposals/refund-executable-feasibility/exception-compiler-20261105/records/replay-sources`
on the backup branch.

---

## 0. Facts from the present system that drive this design

| # | Fact | Source |
|---|---|---|
| D1 | The M1 program reads ALL of stdin (`TextIO.inputAllFrom None`), parses one S-expression, decodes nine atoms, decides, and prints one S-expression | `RS/forge_refundStdioProg.sml` lines 11-16; `RS/forge_refund_io.sml` lines 19-38 |
| D2 | On a decode error the M1 program raises `Fail`. The uncaught exception ends the run as `Terminate Success` with NO output | `RS/forge_refundWireProg.sml` lines 78-83; `RS/forge_refundRejectSemantics.sml` (`refund_raise_determ`, `refund_exception_semantics`); conformance report section 5 (132 of 192 changed inputs gave no output, exit 0) |
| D3 | The M1 integer reader takes `+40`, `-40`, `~40` and leading zeros. Cause: `mlint$fromString` accepts the prefixes `~`, `-`, `+` and any digit string | `CK/basis/pure/mlintScript.sml` lines 475-489; `toString` writes `~` for a negative number (line 332) |
| D4 | The M1 theorems cover only CANONICAL input: the premise is `stdin_content fs = SOME (explode (sexp_to_string (refund_request …)))` | `refund_profile_a_sl`, `e4-0001/stdout.log` lines 239-265; `refund_request_whole_prog_spec` in `RS/forge_refundWholeProg.sml` lines 25-37 |
| D5 | The machine-level conclusion is `machine_sem … ⊆ extend_with_resource_limit {Terminate Success io_events}`. That set also holds `Terminate Resource_limit_hit l` for EVERY prefix `l` of the output events | `e4-0001/stdout.log` line 258-259; definition `CK/semantics/proofs/semanticsPropsScript.sml` lines 219-226 |
| D6 | The pinned CakeML has `compile_correct_is_safe_for_space` (no resource limit if `is_safe_for_space` holds). No program in the pinned tree proves `is_safe_for_space`. Only four files mention it, all compiler files | `CK/compiler/backend/proofs/backendProofScript.sml` lines 2819-2827 and 5005-5020; `CK/compiler/backend/semantics/dataSemScript.sml` line 1778; grep over `CK` |
| D7 | The basis file model has a read that never fails on an open read descriptor, and returns 0 bytes only at end of file. Real `read` errors are not modelled | `CK/basis/fsFFIScript.sml` lines 187-197 (`read_def`), 307-327 (`ffi_read_def`); `CK/basis/TextIOProofScript.sml` lines 2020-2036 (`read_spec`: `nr = 0 ⇔ eof … ∨ n = 0`) |
| D8 | The real C code returns an error flag for every negative `read` or `write` result (`EINTR`, `EIO`, `EBADF`, `EPIPE`). It does not retry | `CK/basis/basis_ffi.c` lines 160-173 and 175-189 |
| D9 | `STDIO fs` includes `STD_streams fs`, which requires descriptor 0 to be the stdin stream in read mode. An absent stdin cannot be stated under `STDIO` | `CK/basis/fsFFIPropsScript.sml` lines 1310-1317; `stdin_content_def` `CK/basis/TextIOProofScript.sml` lines 6244-6249 |
| D10 | A bounded read exists in the basis with a CF spec: `TextIO.input` (buffer, offset, request count) and `TextIO.read` (count below 65,536) | `CK/basis/TextIOProofScript.sml` lines 5397-5415 (`input_spec`), 2020 (`read_spec`), 3200 (`input1_spec`) |
| D11 | The Slice 1 core copies a pre-state HASH given by its caller. "The hash in the token is the hash of the pre-state" is NOT proved | `impl/RefundFinality.dfy` lines 10-11; Slice 1 report section 2 |
| D12 | The approved refund spec has no stored state, no state update rule and no token. Slice 1 made three choices that are not ratified: the charge state, `remaining := remaining − amount`, and "request taken as open" | `spec/refund/RefundSpec.dfy`; `impl/RefundFinality.dfy` lines 6-10 |
| D13 | The approved protocol text has its own strict money spelling: `0`, or a nonzero ASCII digit and zero to eighteen digits; above MaxMoney is rejected | `spec/refund/protocol.md` lines 44-48 |
| D14 | M1 effort, used as the size unit below: `unsure.md` entries U258 to U409 = 152 entries, 2026-11-04 to 2026-11-17. The M1 chain is 95 theories; its replay took 8,423 s | `unsure.md` lines 7339-14507; replay report line 89 |

Consequence. The present M1 program is NOT a good front end for an
untrusted wire: one value has several spellings (D3), malformed input
gives no output (D2), and no theorem covers a non-canonical input (D4).
F2.7 needs a new program with a new parser. The M1 decision function
`eligible_def` (`RS/forge_refund.sml` lines 56-64) can be reused as it
is.

---

## 1. The boundary

### 1.1 One program, one theorem

Program `f27` reads stdin, decides, writes stdout, and ends. It is ONE
pure HOL function `f27_run : word8 list -> word8 list` wrapped in a
fixed main:

```
fun f27_main () =
  let val bs = read_at_most (F27_MAX_IN + 1) stdin   (* bounded loop over TextIO.input *)
  in TextIO.print (f27_run_str bs) end               (* ONE print call, after the decision *)
```

Rules for the main:

- M-1. It never raises an exception that escapes `f27_main` in the
  model. (M1 raised `Fail`, D2. F2.7 must not.)
- M-2. It reads at most `F27_MAX_IN + 1` bytes. It never reads all of
  stdin. A longer input is REJECTED after `F27_MAX_IN + 1` bytes.
- M-3. It writes nothing before `f27_run` returns. It writes the whole
  answer with one `print`.
- M-4. Its FFI calls are `read` and `write` only, if the basis link
  permits that (M1 had four: `read`, `write`, `close`, `open_in`;
  `e4-0001/proof.sml` line 83). Fewer FFI entries make the environment
  contract smaller. Whether the basis start-up code adds others is
  NOT DETERMINED.

### 1.2 Request frame, version 1 (fixed order, length-prefixed binary)

All integers are unsigned, big-endian. `L(x)` is one length byte
followed by the bytes of `x`. `U64(n)` is 8 bytes. `B(b)` is one byte,
`0x00` for false and `0x01` for true.

| Offset | Size | Field | Rule (else REJECT) |
|---|---|---|---|
| 0 | 4 | magic `46 32 37 51` ("F27Q") | exact |
| 4 | 1 + c | `L(chargeId)` | 0 ≤ c ≤ 64; every byte in 0x21..0x7E |
| . | 1 + q | `L(requestId)` | 0 ≤ q ≤ 64; every byte in 0x21..0x7E |
| . | 8 | `U64(original)` | any value |
| . | 8 | `U64(remaining)` | any value |
| . | 1 | `B(refundEnabled)` | 0x00 or 0x01 only |
| . | 8 | `U64(amount)` | any value |
| . | 1 + r | `L(reason)` | 0 ≤ r ≤ 32; every byte in 0x21..0x7E |
| end | — | end of input | no byte after the last field |

`F27_MAX_IN = 4 + 65 + 65 + 8 + 8 + 1 + 8 + 33 = 192` bytes.

Why binary and fixed-order, not decimal text and not the S-expression:

- The S-expression reader gives one value several spellings (D3), and
  quoted and unquoted atoms decode the same (conformance report
  section 5). Canonicity there needs a new reader anyway.
- Fixed-width `U64` has exactly one spelling per value. A decimal rule
  (D13) also has one spelling, but it needs a proof about digit
  strings, a 19-digit bound and a separate MaxMoney compare. The
  binary rule needs only `n = Σ bytes·256^i`.
- No keys: duplicate fields, missing fields, field order and key
  escapes (all named in `spec/refund/protocol.md` line 41-43) cannot
  occur.
- Cost: the frame is not human-readable. Test tools need a printer.
  This is a trade for a smaller proof.

Why the parser accepts every `U64` and empty ids: the approved
relation already REJECTS `original > MaxMoney`, `amount > remaining`
and empty ids (`RefundSpec.dfy` lines 27-36). One rule in one place.
The parser does not repeat the policy.

What the frame does NOT carry, on purpose:

- `requestOpen`: fixed to true, as in Slice 1 (`RefundFinality.dfy`
  line 24). The sink decides freshness. NEW INTENT (D12).
- `candidate`: the frame IS a candidate. Every non-candidate case
  (`Missing`, `TimedOut`, `Failed`, `Malformed`, `Oversized`,
  `Unsupported`) has no frame and gets REJECT, the same as R3.
- A proposed post-state or intent: the program COMPUTES them (Slice 1
  received them and compared, `RefundFinality.dfy` lines 54-56).
  `NoChoice` in `Bindings.dfy` (lines 54-60) shows that only one
  transition can pass, so computing it loses no case and removes
  14 kinds of tampering from the input.

### 1.3 Output, version 1

Exactly one of two forms:

- `REJECT_BYTES` = `52 45 4A 45 43 54 0A` ("REJECT\n", 7 bytes).
- `ACCEPT_BYTES ++ T`, with `ACCEPT_BYTES` = "ACCEPT\n" (7 bytes) and
  the token `T`:

| Field | Size | Content |
|---|---|---|
| magic | 4 | "F27T" |
| `U16(len T)` | 2 | total length of `T` |
| domain `D` | 32 | a literal of the program: the SHA-256 of the approved F2.7 spec lock (computed at build time, not by the program) |
| `S(pre)` | 1 + c + 17 | `L(chargeId) ‖ U64(original) ‖ U64(remaining) ‖ B(enabled)` |
| `S(post)` | 1 + c + 17 | the same with `remaining − amount` |
| `L(requestId)` | 1 + q | |
| `U64(amount)` | 8 | |
| `L(reason)` | 1 + r | |

Maximum `len T` = 4 + 2 + 32 + 82 + 82 + 65 + 8 + 33 = 308. Maximum
output = 315 bytes.

Design choices in the token:

- BIND BY VALUE, NOT BY HASH. The token carries the full pre-state
  bytes. The sink compares them BYTE FOR BYTE with its stored state
  bytes. This removes the Slice 1 gap D11 and model assumption A4
  ("hash comparison is faithful", `DESIGN.md` line 49-51) for this
  binding. No hash function is in the proved program.
- The post-state is given in full so that the sink stores it verbatim
  and does no arithmetic.
- The intent is `(chargeId, requestId, amount, reason)`; every part is
  in `T`.
- `D` replaces the Slice 1 `specLockSha256` and `checkerSha256`. The
  checker identity (the hash of the binary) cannot be inside the binary.
  The signer's pinned key stands for it (section 3).

### 1.4 Canonical-form rule

"Exactly one byte string per value": for every well-formed request
`r`, `f27_encode_req r` is the only byte string that
`f27_decode_req` maps to `r`; every other byte string maps to NONE.
The same holds for tokens.

### 1.5 The boundary in one sentence

For the exact ARM64 code bytes of `f27`, under Profile-A-style
premises, for EVERY stdin content `text` (any finite length), every run
of the model machine either ends with stdout extended by exactly
`f27_run (TAKE 193 text)`, or stops at a resource limit with a prefix
of it; and `f27_run` returns REJECT_BYTES or ACCEPT_BYTES followed by a
token whose fields satisfy the approved refund relation.

---

## 2. Theorem statements to aim for (informal, precise)

### 2.1 Pure HOL layer (no I/O)

- `f27_req_roundtrip`: ∀r. `wf_req r ⇒ f27_decode_req (f27_encode_req r) = SOME r`.
- `f27_req_canonical`: ∀bs r. `f27_decode_req bs = SOME r ⇒ wf_req r ∧ f27_encode_req r = bs`.
  Together these give parse ∘ serialize = id on well-formed values and
  serialize ∘ parse = id on accepted frames.
- `f27_tok_roundtrip`, `f27_tok_canonical`: the same two for tokens.
- `f27_run_def`: `f27_run bs = case f27_decode_req bs of NONE => REJECT_BYTES | SOME r => if f27_eligible r then ACCEPT_BYTES ++ f27_encode_tok (f27_token_of r) else REJECT_BYTES`.
  `f27_eligible r` is `eligible` of `RS/forge_refund.sml` lines 56-64
  with `opened = T` and `candidate = T`.
- `f27_run_two_forms`: ∀bs. `f27_run bs = REJECT_BYTES ∨ ∃t. f27_run bs = ACCEPT_BYTES ++ t ∧ IS_SOME (f27_decode_tok t)`.
- `f27_run_safety`: ∀bs t. `f27_run bs = ACCEPT_BYTES ++ t ⇒ ∃k. f27_decode_tok t = SOME k ∧ f27_authorizes k`,
  where `f27_authorizes k` says: `eligible k.pre.chargeId k.requestId k.pre.original k.pre.remaining k.pre.enabled T T k.amount k.reason`,
  `k.post = k.pre with remaining := k.pre.remaining − k.amount`, and
  `k.domain = f27_domain`. (Slice 1 claims P1 and P4, at byte level.)
- `f27_run_exact_acceptance`: ∀r. `wf_req r ∧ f27_eligible r ⇒ f27_run (f27_encode_req r) = ACCEPT_BYTES ++ f27_encode_tok (f27_token_of r)`.
  (R4 and P2, INSIDE the wire domain.)
- `f27_run_reject`: ∀bs. `(∀r. f27_decode_req bs = SOME r ⇒ ¬f27_eligible r) ⇒ f27_run bs = REJECT_BYTES`.
  (R3: one fallback; no token, so no intent.)
- `f27_prefix_complete`: ∀bs p. `p ≼ f27_run bs ∧ signer_accepts p ⇒ p = f27_run bs`.
  `signer_accepts p` is the signer's exact rule (section 3.3). This
  lemma joins the resource-limit outcome of D5 to the signer: a cut
  output never passes the signer.
- Link to the approved contract: the same mechanism that M1-B
  establishes for `eligible_def` (Q4 of the owner decisions). F2.7
  ADDS a new approved spec for state, update and token (section 5).
  Without that link, the theorems above are about the HOL model only.

Deviation from R4 that MUST be stated: an eligible request with an id
longer than 64 bytes, a reason longer than 32 bytes, or any id byte
outside 0x21..0x7E has no frame. It gets REJECT. Under the approved
R4 it would be authorized. Theorem `f27_out_of_domain` would state:
`¬wf_req r ⇒ ∀bs. f27_decode_req bs ≠ SOME r`. The owner must accept
this as "unsupported representation → fallback" (NEW INTENT).

### 2.2 Source program (CakeML semantics, basis I/O model)

- `f27_main_spec`: ∀fs text. `stdin_content fs = SOME text ⇒ app p f27_main_v [Conv NONE []] (STDIO fs) (POSTv v. &UNIT_TYPE () v * STDIO (add_stdout (forwardFD fs 0 k) (f27_run (TAKE (F27_MAX_IN+1) text))))`
  with `k = MIN (LENGTH text) (F27_MAX_IN + 1)`.
  The exact form of the stdin update depends on the read loop; NOT
  DETERMINED until the loop is written.
- `f27_whole_prog_spec` and `f27_semantics` (by `prove_sem_thm`, as
  `refund_semantics` in `RS/forge_refundWholeProg.sml` line 39-40):
  the source semantics is `Terminate Success` with that output, for
  EVERY `text`. This is totality over all finite stdin contents. M1
  has it only for canonical text (D4).

### 2.3 Machine code (model machine)

- `f27_compiled_behavior`: as `refund_compiled_behavior`
  (`RS/forge_refundArm8Proof.sml` lines 10-29), from `compile_correct`.
- `f27_profile_a_sl`: the shape of `refund_profile_a_sl`
  (`e4-0001/stdout.log` lines 239-265) with two changes: the stdin
  premise is `stdin_content fs = SOME text` for ANY `text`, and the
  output is `add_stdout … (f27_run (TAKE 193 text))`.

### 2.4 What the theorem does NOT say, and which extra theorem would say it

| Property | Status under the theorem | Extra theorem needed | In the pinned CakeML? |
|---|---|---|---|
| The run ends with the full output | NOT claimed. A stop at a resource limit with ANY prefix of the output (also empty) is allowed (D5) | `is_safe_for_space` for the compiled program with the actual stack and heap sizes, then `compile_correct_is_safe_for_space` | the composition theorem YES (D6); a proof of `is_safe_for_space` for any program NO. It is a proof about the data-language program (`data_lang_safe_for_space`). Size not estimated; I judge it research-level |
| Termination | The model machine run has only `Terminate` outcomes (the set has no `Diverge`), under the premises. Nothing about wall-clock time | a cost bound (no such theorem form found in the pinned tree) | NO |
| Memory | no claim | as row 1 | — |
| Partial writes | modelled: the basis `output` loop writes the rest after a short write (`write_def` takes `MIN n strm`, `CK/basis/fsFFIScript.sml` lines 214-226) | none for the model; the real C behaviour is under the FFI simulation assumption | — |
| Write errors (`EPIPE`, closed stdout) | NOT modelled (D7, D8). Real effect: an exception or a signal; output is a prefix | none possible in this model | — |
| Read errors (`EINTR`, `EIO`) | EXCLUDED, as owner decision Q2 for M1 | none possible in this model | — |
| Absent stdin | EXCLUDED: cannot be stated under `STDIO` (D9); as owner decision Q5 for M1 | a theorem without `STDIO`; NOT in scope | — |
| A stdin that never reaches end of file | outside the model (stdin content is a finite list) | none | — |
| Exit code | no claim; M1 exits 0 also after an uncaught exception (D2) | — | — |
| Timing, side channels | no claim | — | — |

The fail-closed rule that covers every row "not claimed": the signer
(section 3.3) signs ONLY an output that is exactly `ACCEPT_BYTES ++ T`
with a correct length. Every other observed output (empty, cut,
garbage, REJECT, a timeout) is a refusal. `f27_prefix_complete` shows
that a cut output never passes.

---

## 3. The signature question

### 3.1 What exists in the pinned trees

- SHA-256: a HOL DEFINITION exists, `SHA_256_def` and `SHA_256_bytes_def`
  (`HOLT/examples/Crypto/SHA-2/sha2Script.sml` lines 156-174), checked
  against two test vectors (lines 176-191). It is a transcription of
  FIPS 180-4; no theorem relates it to the standard text. It uses the
  `cv` translator (`cv_auto_trans`), not the CakeML translator. No
  CakeML program in `CK` uses it (grep for `sha2`, `SHA_256` in `CK`:
  0 files).
- A precedent for the translation: `CK/examples/md5ProgScript.sml`
  translates the HOL MD5 theory to CakeML and proves CF specs
  (`md5_of_SOME`, `md5_of_NONE`, lines 109-166). MD5 is not usable for
  authentication.
- HMAC: none. Ed25519, Curve25519, EdDSA, SHA-512: none. Grep for
  `hmac`, `ed25519`, `curve25519`, `eddsa` over all `.sml` files of
  `CK` and `HOLT`: 0 files.
- Keccak: `HOLT/examples/Crypto/Keccak/keccakScript.sml` (4,761 lines);
  not used here.
- RSA: `HOLT/examples/Crypto/RSA/` (number-theory development); not a
  signature scheme implementation for byte strings (by file names
  only; not read in detail).

### 3.2 The three options

| | S1: sign inside the proved program | S2: proved program emits ACCEPT+T or REJECT; separate signer signs exactly T | S3: uninterpreted `sign` in the theorem |
|---|---|---|---|
| What is new proof | HMAC-SHA-256: translate SHA-256 to CakeML (pattern of md5Prog), define HMAC (new transcription), CF specs; a second input channel for the key (a file: `openIn`, a new FFI name, a larger FFI contract). Ed25519: field arithmetic mod 2^255−19, point arithmetic, SHA-512, all absent | none for cryptography | a new FFI entry `sign` with an uninterpreted model in the basis oracle; the FFI name list and the environment contract change |
| Proof size (my estimate, NOT measured) | HMAC route: +0.3 to +0.6 × M1 on top of F2.7. Ed25519 route: more than 1 × M1 | 0 | +0.2 to +0.4 × M1 (the FFI oracle and contract part of M1 was large: U386-U409) |
| Trusted base added | the key file and its OS isolation; the HMAC text = RFC 2104 (transcription); CakeML gives no constant-time property (general knowledge, not checked); with HMAC the sink holds the same key and can mint (`DESIGN.md` line 76) | the signer program (about 50-100 lines), the signing library, the key store, the process wiring | the C glue for `sign`, the signing library, a NEW simulation assumption "C `sign` = model `sign`" |
| What the theorem says about signatures | "the output tag = HMAC(k, T) for the key bytes read from file F". Not unforgeability; that stays an assumption (EUF-CMA) | nothing | "output = ACCEPT ++ T ++ σ, where σ is the oracle answer for T"; that σ is a valid signature is an assumption |
| What a skeptic can still attack | key secrecy; timing; the key-file model; the symmetric key at the sink; HMAC transcription | the signer: signs something else, signs a cut output, runs another binary, leaks the key | the C glue and library; the oracle assumption; the same key issues as S2 |

### 3.3 Recommendation: S2 for the first version

Reason: S2 adds NO proof and keeps the trusted signer small and
separately testable. S1 and S3 each add a large proof or a new
simulation assumption, and NEITHER removes the cryptographic
assumption (unforgeability) or key secrecy. The biggest residual risk
of S2 is the signer program; its rule is short enough to state in full
and to test exhaustively on the output grammar.

The signer rule (TRUSTED, NOT PROVED, assumption A-SIGN):

1. It runs only the pinned `f27` binary (SHA-256 of the file checked
   before each start), with a fresh pipe on stdin and stdout, one
   request per process.
2. It writes the request bytes, closes stdin, reads stdout to end of
   file with a byte limit of 315 and a time limit. A longer output, a
   timeout or a read error is a refusal.
3. It signs if and only if stdout = "ACCEPT\n" ++ T, T starts with
   "F27T", the `U16` length field equals `LENGTH T`, and the domain
   field equals the pinned `D`. This is `signer_accepts`.
4. It signs exactly the bytes T with Ed25519, with a fixed context
   prefix, and returns (T, σ). It does not parse or change T.
5. It holds the only copy of the private key. Nothing else reads it.

Exact words for the theorem about signatures: "The theorem states the
bytes that the program writes on standard output. It states nothing
about signatures. A signature exists only by the separate signer,
which is trusted and not proved (assumption A-SIGN). Unforgeability of
Ed25519 and secrecy of the key are assumptions."

---

## 4. Environment and resource assumptions (Profile A style)

Each row names: assumption, its M1 counterpart, and whether F2.7 can
reuse the M1 work. "Carry over" = the theorem or tool is used
unchanged. "Redo" = the same method, a new theorem, because it names
the exact code bytes or layout.

| # | Assumption of the F2.7 theorem | M1 counterpart | Carry over or redo |
|---|---|---|---|
| E1 | The published CakeML FFI oracle `basis_ffi` models the file calls | Profile A row 1 | carry over (library) |
| E2 | No OS read error on an open readable descriptor (`EIO`, `EINTR`) | row 2, owner Q2 | carry over as an exclusion; needs a new owner decision for F2.7 |
| E3 | No other thread, process or signal changes the descriptors | row 3 | carry over |
| E4 | `wfcl cl`, `wfFS fs`, `STD_streams fs`; stdin is open and at offset 0 (`stdin_content fs = SOME text`) | row 4 | carry over; the stdin premise becomes "any text" |
| E5 | Absent stdin is outside the theorem; the signer fails closed | owner Q5 | carry over as an exclusion |
| E6 | The machine state satisfies `installed` for the f27 code, data and heap; the loader and C run-time reach the entry with the image at a permitted slide | rows 6, 10; owner Q3a | REDO: `refund_image_mem`, `refund_entry_pre_sl`, `refund_heap_clear_sl`, `refund_mem_dm_sl` name the M1 layout |
| E7 | The native C code of the basis behaves as the model: ONE named simulation assumption | row 8, owner Q3b | the assumption TEXT carries over; the predicate instance (`refund_env_ok_sl`, `refund_ffi_contract_at`) is REDO, because it names the code base and the stub PCs (`e4-0001/proof.sml` lines 111-114 and 140-143: `PC = b − 48w`, …) |
| E8 | No interference between machine steps | row 9 | carry over |
| E9 | The processor is the L3 ARMv8 model | row 10 | carry over |
| E10 | HOL4 kernel, Poly/ML, published CakeML and L3 definitions | row 13 | carry over |
| E11 | The stack and heap of the run are large enough, OR the run may stop with a prefix of the output | not assumed in M1 (allowed outcome) | carry over: the same allowed outcome; the signer rule turns it into a refusal |
| E12 | The output pipe accepts all bytes (no `EPIPE`) | not stated in M1 | new exclusion; fail closed at the signer |
| E13 | The file reader and offset tool that extract the code bytes | owner Q3c | carry over, if validated as Q3c requires |

Theorems and tools that carry over UNCHANGED:

- `compile_correct` (`CK/compiler/backend/proofs/backendProofScript.sml`
  line 4952) and `arm8_compile_correct`, `arm8_backend_config_ok`,
  `arm8_init_ok` (`CK/compiler/backend/arm8/proofs/arm8_configProofScript.sml`
  lines 26-87).
- The basis TextIO CF specs (D10), `print_spec`
  (`CK/basis/TextIOProofScript.sml` line 1868).
- The decision function `eligible_def` and, after M1-B, its mechanical
  link to the approved R1-R5.
- The METHOD of the slide-generic chain (S1 to S6 of U405-U409), the
  replay scripts and the controls style.

Must be REDONE for the new program (everything that names the exact
code bytes, layout or FFI stubs): the compile instance
(`refund_arm8_compiled` analogue), the installed-state and entry
theorems, the FFI contract instance and the environment predicate,
the exclusion theorem (U298 analogue), the slide-generic chain
instance, the joint-premises satisfiability theorem
(`forge_refundInputSat` analogue), and the final Profile A statement.

x86-64: the pinned tree has `x64_compile_correct`
(`CK/compiler/backend/x64/proofs/x64_configProofScript.sml` line 83),
but it is not built locally (no `.hol` objects in that folder), and the
whole M1 machine-level chain is ARM64 and Mach-O. The F2.7 row asks for
both targets. The first version is ARM64 ONLY; x86-64 is a later item
with its own loader and entry chain.

---

## 5. Adversarial inputs and the rule that handles each

| Input | Rule | Result | Covered by |
|---|---|---|---|
| Empty input | decode fails | REJECT | `f27_req_canonical` (no frame of length 0) |
| Wrong magic, other version | exact magic | REJECT | decode definition |
| Truncated frame, early end of file | decode needs every field | REJECT | `f27_req_canonical` |
| Trailing bytes, a second frame, a newline after the frame | decode needs end of input | REJECT | `f27_req_canonical` (`encode r = bs` fixes the length) |
| Input longer than 192 bytes, up to any size (10 GiB) | read stops at 193 bytes | REJECT; rest of stdin not read | `f27_main_spec` (`TAKE 193`) |
| Length byte 65..255 (id) or 33..255 (reason) | length bound | REJECT | decode definition |
| Length byte larger than the rest | decode needs the bytes | REJECT | as truncated |
| Byte 0x00 (NUL) or any control byte in a text field | alphabet 0x21..0x7E | REJECT | `wf_req` |
| Non-ASCII bytes, UTF-8, overlong UTF-8, byte-order mark, Unicode lookalikes | alphabet | REJECT. Nobody normalizes. Bytes are compared exactly | `wf_req`; NEW INTENT (ASCII ids) |
| Space, tab, line ends inside or around fields | no separators exist; 0x20 not in the alphabet | REJECT | `wf_req` |
| Boolean byte 0x02..0xFF | exact `B` | REJECT | decode definition |
| Several spellings of one number (`040`, `+40`, quoted) | fixed 8-byte width; no text numbers | impossible by format | `f27_req_canonical` |
| Integer 0; MaxMoney; MaxMoney+1 = 2^63; 2^64−1 | parser accepts all `U64`; policy rejects above MaxMoney | as the approved relation | `f27_run_safety`, `f27_run_exact_acceptance` |
| amount = remaining; remaining = original; amount = 0 | policy | ACCEPT (zero is a legitimate authorization, `protocol.md` lines 25-27) | as above |
| Negative numbers | not representable | not needed: the approved relation rejects every negative value | `f27_out_of_domain` and R3 |
| Empty chargeId or requestId | parser accepts length 0; policy rejects | REJECT | `f27_run_reject` |
| Duplicate, missing or reordered fields | no keys, fixed order | impossible by format | decode definition |
| Reason that differs in case or whitespace | byte equality with three literals | REJECT | `eligible_def` |
| Same request twice | program is stateless; it issues the same token | the SINK rejects a settled request id with another token and answers "replayed" for the same token | sink requirement K2, K4 |
| Partial write of the output | modelled loop writes the rest | full output, or a prefix at a resource limit | `f27_main_spec`; `f27_prefix_complete` |
| Output cut by a crash, a kill or a resource limit | signer length check | no signature | `f27_prefix_complete` + A-SIGN |
| Stdin never closed by the writer | read blocks; outside the model | signer time limit → refusal | A-SIGN rule 2 |
| Absent stdin, read error | excluded (E2, E5) | signer sees no ACCEPT form → refusal | A-SIGN |

---

## 6. The trusted finality sink (separate requirements; NOT part of the machine-code theorem)

The machine-code theorem verifies a DECISION: bytes on stdout. It does
not execute an EFFECT. The effect (a state change, an outbox row, a
refund sent to a payment processor) happens in the sink and the
dispatcher. The payment processor is a third party and stays outside
every Forge proof. Its correct and honest behaviour is an assumption.

Today's sink is `ts/refund-finality/sink.ts`: TESTED (Slice 1 suite,
115 rows; one review and repairs, U445-U448), NOT PROVED. The protocol
logic is proved only as a MODEL: `FinalityProtocol.dfy`, 22 verified,
under assumptions A1-A4 (`DESIGN.md` lines 40-51).

| # | Requirement | Today (file, line) | Tested or proved | What a proved version needs |
|---|---|---|---|---|
| K1 | Signature and token validation | text only (`sink.ts` 77-78); size ≤ 8,192 (24, 79); JSON parse and exact shape (80-82); canonical text (83); pinned spec lock and checker (84-85); Ed25519 verify (71-76, 86) | tested | a proved decoder for the F2.7 token (the same HOL `f27_decode_tok`, translated, or a Dafny decoder with the roundtrip lemmas); verification = assumption A1 (EUF-CMA + correct library); domain check `D` |
| K2 | Binding to pre-state and request identity | request id settled? (91-96); SHA-256 of the stored text = token hash (102-105) | tested | F2.7: compare `S(pre)` bytes of the token with the stored state BYTES (no hash; removes A4 for this check); request id fresh. Model lemmas `StaleStateRejected`, `ReplayRejected` (`FinalityProtocol.dfy` lines 268-280) |
| K3 | Atomic state transition | `BEGIN IMMEDIATE` (90); three writes (106-108); `COMMIT` (109); `ROLLBACK` on error (111-114) | tested (races in the suite) | A3 stays an assumption on SQLite; a proof of the transaction code against the model step `Commit` |
| K4 | Durable idempotency | `settled.request_id` UNIQUE (38); same token → "replayed" (94); no `PRAGMA synchronous` set (only `busy_timeout`, line 35), so the SQLite default applies (default value: general knowledge, not checked) | tested; durability under power loss NOT tested (review section, F2 limits) | stated durability assumption on the store; explicit `synchronous` setting; the model has no crash |
| K5 | Concurrency safety | `busy_timeout` 30,000 ms (35); `BEGIN IMMEDIATE` serializes writers; dispatcher lock file (`dispatcher.ts` 74-79) | tested (common-start races; 4 dispatcher processes) | a model with interleaved steps or a proof that the code realises one atomic step (A3); the lock file assumes atomic exclusive create (`dispatcher.ts` 15-16) |
| K6 | Recovery from partial failure | transaction rollback (111-114); dispatcher writes and syncs the ledger BEFORE the effect: at most once; a crash between loses the effect, a person reconciles (`dispatcher.ts` 9-10, 19-20, 98-102) | tested in part; crash points not proved | an explicit crash model; a reconciliation protocol (F2.5 `IN_FLIGHT` is the planned form, NOT STARTED) |
| K7 | Prevention of bypass paths | sink holds only the public key (2, 17-18); the dispatcher re-checks signature, chain and its own ledger before each effect (`dispatcher.ts` 2-8, 57-73); `audit()` DETECTS tampering, does not prevent it (119-145); known limit D14 (`dispatcher.ts` 24-25) | tested (12 raw-database cases, 0 unauthorized effects) | OS isolation of the database, ledger and processor credentials (assumption); a proof that every effect path goes through the check; credentials of the third party outside Forge |
| K8 | Byte storage | text columns; NUL in ids broke a TEXT round trip (Slice 1 F3; `encoding.ts` 43-46) | tested | store `S(state)`, tokens and ids as BLOB; F2.7 ids have no NUL by the alphabet rule |

---

## 7. Staged plan (six steps)

Preconditions (none of them is a step of this plan):

- P-1. M1-B is closed: the machine-checked link from the approved R1-R5
  to `eligible_def` exists (owner text 2). F2.7 reuses that link.
- P-2. The owner approves a NEW spec proposal for F2.7 (section 8).
  The approved refund spec has no stored state and no token (D12); a
  wire format and a token format are new intent.
- P-3. Owner authorization for HOL runs, with limits, commands and
  evidence destinations shown first (as owner Q6).

Size unit: M1 = 152 `unsure.md` entries (D14). All sizes are MY
ESTIMATES, not measurements.

| Step | Content | Theorem(s) | Controls (each must FAIL) | Size estimate |
|---|---|---|---|---|
| 1 | Spec proposal: a Dafny abstract module for state, update rule, token fields, wire domain bounds; witness methods; the wire and token text | Dafny: the spec is well formed; issue and refusal witnesses exist | an always-reject and an always-accept refinement must fail the witnesses | 4-8 entries (3-5 %) |
| 2 | Pure HOL: `f27_decode_req`, `f27_encode_req`, token codec, `f27_run`, the M1-B link instance | `f27_req_roundtrip`, `f27_req_canonical`, `f27_tok_*`, `f27_run_two_forms`, `f27_run_safety`, `f27_run_exact_acceptance`, `f27_run_reject`, `f27_prefix_complete`, `f27_out_of_domain` | decoders that accept a padding byte, a boolean 0x02, a trailing byte, a length 65, a byte 0x20; a policy with `amount < remaining`; a run that writes a token on reject; a signer rule without the length check (`f27_prefix_complete` must fail) | 10-20 entries (7-13 %). Comparable code in M1: `forge_refund_io` + `forge_refundWireProg`, about 300 lines |
| 3 | CakeML: translate `f27_run`; write `f27_main` with the bounded read loop and one `print`; CF and whole-program semantics | `f27_main_spec`, `f27_whole_prog_spec`, `f27_semantics` (for every `text`) | a main that uses `inputAllFrom`; a main that prints before the decision; a main that raises on a bad frame (D2 behaviour) | 15-30 entries (10-20 %); the bounded read loop proof is new (M1 used `inputAllFrom_NONE_spec`) |
| 4 | Compile to ARM64; compose with `compile_correct` | `f27_arm8_compiled`, `f27_compiled_behavior` | a changed code byte must break the identity check | 5-10 entries (3-7 %) |
| 5 | Machine-level chain for the new code bytes: entry, installed state, FFI contract and environment predicate, exclusion, slide-generic chain, joint premises | `f27_profile_a_sl`, `f27_profile_a_sl_every_machine_run`, `f27_machine_premises_satisfiable` | the M1 controls in kind: a PC-changing environment (`pc_changing_environment_is_not_ok_sl` analogue), a stub-guard FFI at another base, the wrong slide | 40-80 entries (25-55 %). The M1 part U345-U409 was 65 entries; the method and scripts carry over, the instances do not. LARGEST RISK |
| 6 | Trusted signer (S2) and sink adapter for the binary token and byte-equal pre-state; finite adversarial suite (section 5); conformance of the binary against `f27_run` on HOL-written fixtures; replays (repeat, import check; then clean and independent, as Q6) | none new (tests; replays) | each signer rule removed in turn must make the suite fail; a cut output must be refused | 10-20 entries (7-13 %) plus replay time |

Total estimate: 84-168 entries, about 0.55 to 1.1 × M1. This excludes
P-1 (M1-B), x86-64, any `is_safe_for_space` proof, and any sink proof.
F2.7 with S1 (HMAC inside) adds 0.3-0.6 × M1 (section 3.2).

---

## 8. New intent that needs owner approval

1. The request frame (section 1.2): binary, fixed order, the magic, the
   field list, `U64` money.
2. The wire-domain bounds: ids ≤ 64 bytes, reason ≤ 32 bytes, id and
   reason bytes 0x21..0x7E only. An eligible request outside these
   bounds is REJECTED (a stated deviation from R4).
3. `requestOpen` fixed true in the program; freshness at the sink
   (Slice 1 rule 3).
4. The charge state `(chargeId, original, remaining, refundEnabled)`
   and the update `remaining := remaining − amount` (Slice 1 rules 1
   and 2).
5. The output forms "REJECT\n" and "ACCEPT\n" ++ T, and the token
   format (section 1.3), with the pre-state BY VALUE and no hash.
6. The domain literal `D` and how it is fixed at build time.
7. Option S2: the signer is trusted and not proved; rule A-SIGN.
8. The sink change: binary token; byte comparison of the pre-state
   instead of a SHA-256 comparison; BLOB storage.
9. The exclusions E2, E5, E12, and the resource-limit outcome E11
   handled only by the signer's fail-closed rule.
10. ARM64 only for the first version.

---

## 9. What I could not determine

- Whether the basis start-up code of a program that uses only
  `TextIO.input` and `print` still links `close` and `open_in` as FFI
  names (M-4). This decides the size of the FFI contract.
- The exact stdin state after the bounded read loop in `f27_main_spec`
  (`forwardFD` form); it depends on the loop.
- Whether the CakeML translator handles the `U64` decode and the byte
  alphabet check without side conditions; md5Prog needed side theorems
  (`CK/examples/md5ProgScript.sml` lines 58-75).
- The cost of `is_safe_for_space` for any program: no instance in the
  pinned tree to measure against.
- Whether the M1-B link mechanism (not yet built) can be extended to a
  NEW approved spec without a second link proof of the same size.
- The SQLite default durability setting used by `sink.ts` (general
  knowledge only).
- Whether a Slice 3 style certificate check belongs in this program:
  Slice 3 is for booking (`impl/BookingCertificate.dfy`), not refund.
  For the refund first version it is NOT APPLICABLE. A booking variant
  would be a second program.
