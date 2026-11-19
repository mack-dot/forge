# Step IV: F2.7 architecture, a specification draft only (W7, Opus, read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W7 (f27-spec), step IV. This is a draft specification only. I did not build or run anything (no HOL, Dafny or Docker), and I did not change the repository. Every theorem name that starts with `f27_` is a proposed name; none of them exists. `end_to_end=false`. M1 is still open and F2.7 is still NOT STARTED.

Draft: <session scratch folder>/m1b/W7/F27_ARCHITECTURE.md

**Proposed boundary (15 lines)**
1. A new program `f27`, a pure HOL function `f27_run : word8 list -> word8 list` with a fixed main. The main reads at most 193 bytes with the bounded `TextIO.input` (`CK/basis/TextIOProofScript.sml:5397`), then calls `print` once, after the decision.
2. The main must not let any exception escape. Today M1 raises `Fail` on bad input and ends with no output (RS/forge_refundWireProg.sml:78-83).
3. The input frame is binary, in a fixed order, with no keys: "F27Q", then `L(chargeId)`, `L(requestId)`, U64 original, U64 remaining, one byte for enabled (0x00 or 0x01 only), U64 amount, `L(reason)`, then end of input.
4. Bounds: ids 0..64 bytes, reason 0..32 bytes, and text bytes only in 0x21..0x7E. So NUL, Unicode and whitespace are excluded. The maximum frame is 192 bytes.
5. A binary frame is used because the M1 reader is lenient: `mlint$fromString` accepts `+`, `-`, `~` and leading zeros (`CK/basis/pure/mlintScript.sml:475-489`), and quoted atoms read the same as unquoted ones. With fixed-width U64 and no keys, each value has exactly one spelling, and duplicate fields cannot occur.
6. The parser accepts every U64 value and empty ids. The approved relation, not the parser, rejects values above MaxMoney and empty ids.
7. The program computes the post-state and the intent itself; it does not receive a candidate transition (by `NoChoice`, only one transition can pass anyway).
8. There are exactly two outputs: "REJECT\n", or "ACCEPT\n" followed by the token T. T is "F27T", a U16 total length, a 32-byte domain literal D, the pre-state by value, the post-state, the requestId, the amount and the reason. The maximum output is 315 bytes.
9. The token binds the pre-state by value, not by hash. The sink compares the pre-state bytes directly. This removes the Slice 1 gap "the hash is not proved" and assumption A4 for this binding.
10. Canonicity theorems: `f27_req_roundtrip` (decode ∘ encode = id on well-formed values) and `f27_req_canonical` (decode bs = SOME r ⇒ encode r = bs), and the same two for tokens.
11. Policy theorems: `f27_run_two_forms`, `f27_run_safety` (an ACCEPT token satisfies `eligible_def` and has post = pre with remaining − amount), `f27_run_exact_acceptance` (inside the wire domain only) and `f27_run_reject`.
12. Totality: `f27_whole_prog_spec` holds for EVERY stdin content, with output `f27_run (TAKE 193 text)`. M1 has this only for canonical input.
13. Machine code: `f27_profile_a_sl`, in the shape of `refund_profile_a_sl`. Like M1, it allows a stop at a resource limit with any prefix of the output (`semanticsPropsScript.sml:219-226`). `f27_prefix_complete` would show that a cut output never passes the signer's length check.
14. Not claimed: completion, memory and time. Completion would need `is_safe_for_space`. The pinned tree has the composition theorem `compile_correct_is_safe_for_space` (`backendProofScript.sml:5005`), but no program in the tree proves `is_safe_for_space`.
15. Also not claimed: write errors and EPIPE (not modelled), read errors (excluded, as owner Q2), absent stdin (cannot be stated under `STD_streams`, `fsFFIPropsScript.sml:1310-1317`; excluded, as owner Q5), and the exit code. In each of these cases the signer fails closed.

**Recommended signature option: S2.** The proved program writes "ACCEPT\n"+T or "REJECT\n". A separate signer signs exactly T. The signer is trusted and not proved (assumption A-SIGN): it runs the pinned binary, applies byte and time limits, and signs only if the output is exactly ACCEPT+T with the correct length field and domain D.
- Reason: S2 adds no proof. S1 and S3 both add a large proof or a new FFI simulation assumption, and neither removes the unforgeability assumption or key secrecy.
- What the pinned trees contain: SHA-256 exists only as a HOL definition (`HOLT/examples/Crypto/SHA-2/sha2Script.sml:156-174`, checked against 2 test vectors, not translated to CakeML). The only translation precedent is MD5 (`CK/examples/md5ProgScript.sml`). HMAC, Ed25519, Curve25519 and SHA-512 are absent: a search of all `.sml` files found 0 matches.
- Exact words for the theorem: "The theorem states the bytes that the program writes on standard output. It states nothing about signatures. A signature exists only by the separate signer, which is trusted and not proved (assumption A-SIGN). Unforgeability of Ed25519 and secrecy of the key are assumptions."

**New intent that needs owner approval**
1. The request frame format.
2. The wire-domain bounds (ids ≤ 64 bytes, ASCII 0x21..0x7E only, reason ≤ 32 bytes). An eligible request outside these bounds gets REJECT. This is a stated deviation from R4.
3. `requestOpen` fixed to true, with freshness decided at the sink.
4. The charge state and the update `remaining := remaining − amount` (Slice 1 rules 1 and 2, not ratified).
5. The two output forms and the token format, with the pre-state by value.
6. The domain literal D.
7. S2 and the signer rule A-SIGN.
8. The sink change: binary token, byte comparison of the pre-state instead of a hash, BLOB storage.
9. The exclusions (read errors, absent stdin, EPIPE) and the resource-limit outcome, handled only by the signer's fail-closed rule.
10. ARM64 only for the first version. x86-64 is a later item: `x64_compile_correct` exists in the pinned tree, but the x64 proofs are not built locally, and the M1 machine-level chain is ARM64 and Mach-O.

**Staged plan.** Preconditions: M1-B is closed; the owner approves a new spec proposal; the owner authorizes HOL runs with limits shown first. Sizes are my estimates in M1 units (U258–U409 = 152 entries); they are not measured.
1. Dafny spec proposal with witnesses: 3–5% of M1.
2. Pure HOL codec, `f27_run` and the canonicity, safety and prefix theorems, with wrong-decoder controls: 7–13%.
3. CakeML translation, bounded read loop and whole-program spec for all inputs: 10–20%.
4. Compile to ARM64 and compose with `compile_correct`: 3–7%.
5. Machine-level chain redone for the new code bytes (entry, installed state, FFI contract, environment predicate, slide-generic chain, joint premises): 25–55%. This is the largest risk. The method and scripts carry over; the instances do not.
6. Signer, sink adapter, adversarial suite, conformance on HOL-written fixtures, replays: 7–13%.

Total: about 0.55–1.1 × M1. This excludes M1-B, x86-64, `is_safe_for_space` and any sink proof. Putting HMAC inside the program (S1) would add about 0.3–0.6 × M1.

What carries over unchanged: `compile_correct`, `arm8_compile_correct`, `arm8_backend_config_ok`, `arm8_init_ok`, the basis TextIO specs, `eligible_def` with its M1-B link, the slide-chain method, and the Q3c tools once they are validated.
What must be redone: everything that names the code bytes, the layout or the FFI stub PCs. That includes `refund_env_ok_sl` and `refund_ffi_contract_at` (`e4-0001/proof.sml:111-114, 140-143`).

The sink requirements K1–K8 are in the draft. Each has its `sink.ts` or `dispatcher.ts` lines, the note that the sink is tested and not proved, and what a proved version would need, mapped to the F2.0 model lemmas. A third-party processor stays outside every proof.

**What I could not determine**
- Which FFI names the basis start-up links for a program that uses only read and print (M1 has four: read, write, close, open_in). This sets the size of the FFI contract.
- The exact stdin-state form in `f27_main_spec`; it depends on the read loop.
- Whether the CakeML translator handles the U64 decode and the byte check without side conditions.
- The cost of an `is_safe_for_space` proof: there is no instance to measure against.
- Whether the M1-B link mechanism extends to a new spec without a second link proof of the same size.
- The SQLite default durability setting (general knowledge only, not checked).
- Whether a Slice 3 certificate check belongs here: Slice 3 is for booking, so for the refund first version it is not applicable.

| step | status | evidence or blocker |
|---|---|---|
| IV (F2.7 specification) | REPORTED | <session scratch folder>/m1b/W7/F27_ARCHITECTURE.md; nothing in the repository was changed; nothing was run |
| IV implementation | BLOCKED | needs M1-B closed, owner approval of the new spec (the 10 items above) and owner authorization for HOL runs |
