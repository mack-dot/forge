# Refund library wrapper: partial proof and failed coverage control

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
The wrapper acceptance matrix **fails with exit1**. The partial proof does not
cover its actual trailing-input branch. No native refund executable has been
compiled, linked or run. This packet does not authorize an acceptance profile.

## Exact scope

The program uses the existing published `Sexp.inputSexp` parser. It then reads
the remainder from the same stream with `TextIO.inputAll`. The proposed wrapper
requires that remainder to be empty before invoking the exact generated refund
method and printing its response. It introduces no custom parser, new axiom or
input-domain restriction. The refund remains a stateless decision and intent.

The translated decoder returns nested pairs. The generated method returns a
flat six-field tuple. An initial wrapper used the wrong input pattern. The
corrected wrapper has two kernel-checked pattern-matching theorems:

- `refund_decoder_bindings` relates the actual input pattern to all nine typed
  fields, using the published translator predicates and `pmatch` semantics.
- `refund_result_bindings` relates the actual output pattern to the six fields
  of the existing expected result, including both caller identities.

The patterns are extracted from the actual checked wrapper declaration. These
theorems establish pattern compatibility. They do not establish that execution
reaches those patterns, invokes the method correctly, completes I/O or produces
the required native result. Constructor lookup and the explicit main-call
declaration are also checked. They are not whole-program behavior proofs.

## Executed commands and outcomes

Raw directory:
`results/refund-native-io-2026-11-04/attempt-0001/`.
Run dispatchers there with `python3 -B`; each saved `command.json` records the
exact child argv, working directory, source digest, exit and local wall time.
The dispatchers invoke the existing HOL tools; they do not decide logical truth.
Reuse a new attempt name for reproduction, so prior attempts remain intact.

| Actual command/check | Actual exit | Result |
| --- | ---: | --- |
| `Holmake --no-cache -j 2 SexpProgTheory.uo` | 0 | Published parser/I/O source replay;62 theories rebuilt |
| Initial Sexp identity readback | 1 | Ambiguous `typeSoundScript.sml` basename; no manifest accepted |
| Corrected built-source identity readback | 0 | Actual built object and logged source directory disambiguated |
| `run_program.py program-0001` | 1 | Missing explicit decoder translation |
| `run_program.py program-0002` | 0 | Declaration construction only; incorrect flat input pattern still present |
| `run_program.py program-0003` | 0 | Nested input pattern, constructor and entry-call checks |
| `run_program.py program-0004` | 0 | Both actual pattern-binding theorems checked |
| `run_program.py program-flat-input negative-program-flat-input/forge_refundProgScript.sml` | 1 | Required refusal at `refund_decoder_bindings`; unsolved goal `F` |
| `run_program.py program-swapped-output negative-program-swapped-output/forge_refundProgScript.sml` | 1 | Required refusal at `refund_result_bindings`; unsolved goal `F` |
| `run_program.py program-no-tail-check negative-program-no-tail-check/forge_refundProgScript.sml` | **0** | **Failed control: required exit1; missing control-flow coverage** |
| `run_program.py program-repeat` | 0 | Six exports match program-0004 byte for byte |
| `run_program_controls.py` | **1** | Correctly reports the unmet negative expectation |
| `run_heap.py heap-0001` through `heap-0005` | 1 each | No general-heap theorem accepted |
| `run_method.py method-0001` through `method-0004` | 1 each | No library heap/frame theorem accepted |
| Saved-record and exact-byte validation | 0 | Confirms the failed matrix, identities and30 unchanged protected inputs |

The no-tail mutation changes only `if rest = "" then` to `if true then`.
Its successful theory export does not make the mutation safe. It proves that
the current selected theorems are insufficient to check that behavior. The
required negative exit remains1. The raw actual0 and exported objects remain.
The previous pure schema suffix-rejection proof does not close this wrapper gap.

The positive source replay took77.61299691599561 local seconds. Its repeat took
68.64351491699927 seconds. The published Sexp replay took2267.0141792919894
seconds. These are local proof-build observations, not application latency,
hosted runner-minutes or evidence of a performance improvement.

## Exact identities and checking boundary

CakeML: `cd9155694c16831373ab695a670794f23282ed62`.
HOL4: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
Poly/ML5.9.2: `4557554077078decce4ce5f90da00a713cfc32e4`.
The source trees remain unchanged. The selected local target is Darwin arm64
through the published arm8 Apple export. Native compilation is **NOT RUN**.

Final/repeat wrapper source SHA256:
`44ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22`.
Final/repeat theory data SHA256:
`ecda3e2a6d3dfd8eb71c251f5a76f8f7634be849f24208c2f0a706188ab3100d`.
Uncaught no-tail mutation source SHA256:
`f429b0150b6caadd13e17d578c46fd9c0c5ea3f048ef23be7b2dc2e84b6fa1e1`.

This packet retains exact scripts, command records, complete attempt logs and
the final, repeat and uncaught-mutant exports. Other intermediate exports and
saved proof heaps remain in the raw directory. Nothing was deleted. The sibling
schema packet remains unchanged. Its159-node closure and four HOL foundation
axioms are historical schema results, not a new complete wrapper closure audit.
No new independent human review or complete wrapper assumption audit has run.
Stored `DISK_THM` data and matching hashes are not self-authenticating proof.

## Preserved unsuccessful proof routes

Generic-heap EVAL attempts1/2/5 were manually interrupted; each HOL child ended
with signal2 and each dispatcher returned1. Attempts3/4 failed helper proofs.
All five attempts remain. Do not run a sixth attempt of that same route.

The characteristic-formula method proof failed four times: an untyped empty
AST list, unsupported automatic reference handling, then unresolved Boolean
reference-allocation obligations. Explicit framing reaches allocations0–3.
Allocation4 remains unresolved. One complete attempt remains under the existing
five-attempt limit. These failures are not successful adversarial controls.
The exact method remains unchanged. A fresh exception stamp must come from
the actual selected library state, not a different parent translation.

## Separate runtime audit

[Native boundary audit](../native-audit-20261104/REPORT.md) preserves two identical
runtime C objects, not a refund executable. Its46-member packet was checked
against the held bytes. Its Docker and fixture-proof permission errors remain
infrastructure failures. The refused operations were not rerouted through this
task. No native fixture result is accepted from its unexecuted expectations.

## Smallest next authorized check

Prove rejection for a nonempty remainder in the **actual wrapper continuation**
using existing CakeML semantics. Extract that continuation from the checked
`refund_main` definition. State its exact environment/state premises. Require
the unchanged no-tail mutation to fail for the intended theorem obligation.
This is proposed work: **NOT RUN**. Do not call a conditional continuation
theorem complete stdin or whole-program correctness.

Then discharge the generated method's library heap/frame contract and compose
the published stream I/O rules. Instantiate the native compiler only for that
same program. Preserve source/model representation, initial state, installed
machine image, FFI, resource-limit, assembler, linker, loader and OS premises.
Finite resource failure cannot count as successful refund output. The approved
unbounded input domain must not be narrowed to obtain a native guarantee.

New claim/profile adoption needs independent review and exact authorization.
Publication, merge, workflow dispatch, signing, admission and deployment remain
outside this local preparation. The owner reports an independent backup; exact
archive hashes and restore on that copy remain unverified. No GitHub state or
hosted experiment was refreshed by this documentation checkpoint.

Verdict: **NOT_ESTABLISHED** for the native/executable claim. M1 stays open;
M2–M4 remain subsequent work. `end_to_end=false`.
