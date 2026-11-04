# Refund normalization attempt — incomplete

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
This packet preserves local candidate-construction failures. It establishes no
new refund behavior or native guarantee. Parent documentation commit:
`1afd924b206d05949319de3881c09f2a618ef728`.

## Purpose and boundary

U265 proves that the raw method's first match expression cannot satisfy the
direct CF rule's value premise. The existing CakeML normalizer is an unverified
syntax transformation. This experiment calls that published implementation
without changing it. Its output would require a direct full-result proof and
a checked observable-result relation to the original method. No preservation
theorem is assumed. The approved refund R1–R5 contract and domain are unchanged.

Neither attempt completed candidate construction. There is no normalized AST,
exported theory, behavioral proof, or native artifact to accept. This does not
prove that normalization cannot finish or that refund behavior is incorrect.

## Actual commands and outcomes

Commands ran from `/Users/mackianni/forge`. Let `OUT` denote
`results/refund-normalised-method-2026-11-04/attempt-0001`.

| Command | Actual exit | Observation |
| --- | --- | --- |
| `python3 -B "$OUT/run.py" construct` | 1 | Manually interrupted child, signal2; no exported theory |
| `python3 -B "$OUT/run.py" construct-0002` | 1 | Exact input preparation completed; normalization did not return before manual interruption, signal2 |
| `/usr/bin/sample 56629 1 1 -file "$OUT/construct-0002.sample.txt"` | 0 | Diagnostic stack sample; no named ML subroutine identified |
| First `python3 -B "$OUT/validate_records.py"` | 1 | Wrong manifest filename for the separate native audit; failed source and error preserved |
| Corrected `python3 -B "$OUT/validate_records.py"` | 0 | Both failures,30 unchanged protected inputs and329 prior packet members checked |

The second attempt uses exact definition rewriting instead of broad evaluation
and emits progress markers. Its last marker is `FORGE_INPUT_READY`. It does not
emit `FORGE_NORMALISED_AST_READY`. Thus the observed incomplete call is
`cfNormaliseLib.normalise_decl`. The precise internal cause is unresolved.
The interruption is a diagnostic action, not a proof rejection or acceptance
timeout. No time limit is used to declare a claim valid.

The saved command records contain exact argv, working directory, source hashes,
parent hashes, empty export sets and real exit codes. Recorded local elapsed
durations are184.03520208300324 and269.4683468750154 seconds. These are incomplete
construction runs, not verification benchmarks or hosted measurements.

## Identity and preservation

| Input | SHA256 |
| --- | --- |
| First candidate script | `a41d9fe995463ec2248c153f3cbd5c896d326ba5455cb092c81d3acd91a99cc2` |
| Second candidate script | `501afdae1901aad193b9d288ed41c70d88602647b0c0b6f6bda8462e4f57c9ff` |
| Unchanged actual wrapper source | `44ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22` |
| Unchanged wrapper theory data | `ecda3e2a6d3dfd8eb71c251f5a76f8f7634be849f24208c2f0a706188ab3100d` |

CakeML remains `cd9155694c16831373ab695a670794f23282ed62`; HOL remains
`9783a49979c94c401ff8c0e51b2eefae7ea95ae3`. Both tracked source diffs return0.
The full mission still matches the owner's attachment byte for byte. Prior
journal bytes remain unchanged. U265 guard/prefix results and the original U264
uncaught guard-removal mutation remain separate, preserved evidence.

## Next smallest check — NOT RUN

Localize the incomplete call using the published normalizer's existing
annotation-stripping and normalization operations, without changing semantics
or assuming output correctness. Preserve the exact raw term and any resulting
candidate. Two construction attempts have run; do not repeat an unchanged
failure. The old generic-heap route has used all five attempts. The old raw CF
route has used four and retains its checked applicability obstacle.

If construction succeeds, prove the candidate's complete six-field return
behavior over the same full model domain. Check its observable-result relation
to the original method. Then close the library heap/frame and whole-program I/O
obligations. Candidate construction alone closes none of these proof links.

Native compilation/execution, hosted refund measurements, new provenance and
independent admission are NOT RUN. M1 remains `NOT_ESTABLISHED`; M2–M4 remain
subsequent work. The owner reports an off-machine backup; exact archive hashes
and a restore on that copy remain unverified. GitHub controls were not refreshed.
No publication, protected adoption, merge, dispatch, signing or deployment ran.
Their corresponding approval and independent-review boundaries remain intact.

Raw records remain in the OUT directory. This review packet contains immutable
copies of the two attempt sources, logs, command records and diagnostic checks.
Its hash manifest checks byte identity only; it is not authenticated provenance.
