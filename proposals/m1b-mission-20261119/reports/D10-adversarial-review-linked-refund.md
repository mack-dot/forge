# Step D10: adversarial review of the LinkedRefund proof (Y10, Opus; pinned Dafny on copies)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y10 report: adversarial review of `proofs/linked-refund` (links S3, S3a)

**Findings, ranked**
1. **S3a is now machine-checked. No defect.** I deleted the whole `HexConversion` module, which holds the only `@Axiom`, from a copy of `library/Std/Strings.dfy`. The copy still verifies: exit 0, "1486 verified, 0 errors". The base has 1489, and the base CSV has exactly 3 `HexConversion` rows. A `dafny audit` of all 34 files of that copy gives exit 0 and "0 findings", and its report is byte-equal to `gate/expected-audit.md`. So the result does not need the axiom.
2. **The result is not vacuous.** `AssessFlat` HAS a body, and the CSV row "FlatRefund.AssessFlat (correctness)" passed. That body is a witness for every input, so the flat contract can be met for every input. I tried to derive `false` from the contract for arbitrary inputs and for one accepted input. Both attempts fail as they should: exit 4, 2 errors. M1 adds `assert false` at the end of `LinkedRefund.Assess`. It also fails as it should: exit 4, error at line 77. The context of `Assess` is therefore not contradictory.
3. **No hidden input restriction.** Nothing on the path has a `requires`. I checked `LinkedRefund.Assess`, `AssessFlat`, `Encoded`, `Decode`, `DecodeEncoded`, `EncodedEmpty` and `SameReasons`. The approved spec has no `requires` either. `int` has no bound. The only input bounds are the ones in the approved `Money` and `Eligible`, and the flat guard copies them.
   - The `char` type limits strings to Unicode scalar values. There is no `dfyconfig.toml`, so the Dafny 4.11 default `--unicode-char` applies (read). The verified `CharScalar` relies on this (read).
   - So the result says nothing about lone surrogates (they cannot occur in the type). It also says nothing about HOL input bytes that are not the encoding of an approved input. That is the gap C5, which STATEMENTS.md already states.
4. **The result is weaker than its headline suggests (framing, not a soundness fault).** The flat contract repeats the approved guard over the encoded strings, and it fixes the six outputs uniquely. So S3 shows that "encoding commutes with the spec" inside Dafny. All link value toward M1 still depends on the cross-tool HOL step, which is not done.
5. **A comment in the proof is false.** `LinkedRefund.dfy:264-265` says "The inherited bodies are verified again for this instance". My base CSV has 0 rows for `RefundDeterminismLinked` and `RefundExactLinked`. This confirms the trap that RESULTS.md section 4 records. No claim depends on the comment, because `LinkedPost` proves the instance facts directly.
6. **Some negative controls fail only by "out of resource".** In M2 the R4 batch and in M5 the new ensures of `LinkedRefund.Assess` ran out of resource and were not refuted. M4 fails only by out of resource in `DecodeEncoded`. W9's N1b and N3a also contain such failures. An out-of-resource result gives exit 4, but it is not a refutation. Each control except M5 also has at least one real "could not be proved" error. For M5 the clean refutation came from `Refund.dfy(6,2)`, not from `LinkedRefund`.
7. **Minor inconsistency.** RESULTS.md says the audit covered 33 files. `run_check.py` audits all 34 files from `rglob`, which includes `Boundary.dfy` (not reached).

**The copies are byte-equal (step 6).** SHA-256 matches the working tree and `main` for `spec/refund/RefundSpec.dfy` (`90a21c71…`), `impl/Refund.dfy` (`04168824…`) and `clearing/RefundExact.dfy` (`58d354e9…`). `RefundDeterminism.dfy` (`69020616…`) is also equal. `FlatCore.dfy` (`a89484e3…`) equals the U294 `export-0003/input.dfy`. `LinkedRefund.dfy` is `0d67b483…f34`.

**Grep of all 34 files (step 3).** The only match is `Strings.dfy:185 @Axiom`. I found no `assume`, `{:axiom}`, `{:verify false}`, `@Verify`, `{:extern}`, `{:only}`, `decreases *` or `{:options}`. All bodiless declarations are in abstract modules, and a non-abstract module refines each of them with a body (read): `UnicodeEncodingForm` by `Utf8EncodingForm`, `LittleEndianNat.BASE` by `ParametricConversion`, `CharsConsistent` by `DecimalConversion {}`, and `RefundSpec.Assess` by `Refund` and `LinkedRefund`.

**Commands RAN (pinned Dafny with the gate options, one process at a time)**
| run | exit | summary |
|---|---|---|
| base (unchanged copy) | 0 | 1489 verified, 0 errors |
| S3a-noHex | 0 | 1486 verified, 0 errors |
| audit of the S3a copy, 34 files | 0 | 0 findings; equal to the empty baseline |
| M1 `assert false` in Assess | 4 | 1 error |
| M2 decision reason := Decode(chargeBytes) | 4 | R2 (Spec:46) not proved; R4 out of resource |
| M3 plan when `count >= 0` | 4 | R3 (Spec:48) not proved; 5 errors |
| M4 Decode accepts bytes <128 only | 4 | `DecodeEncoded` out of resource |
| M5 spec copy + `ensures Authorized ==> amount > 0` | 4 | `Refund.dfy` error; `LinkedRefund.Assess` out of resource at the new ensures (inheritance is live) |
| M6 flat guard `-1 <= amount` (ensures and body) | 4 | R1 (Spec:43) not proved; Transport:44 |
| FlatFalse (derive false from the flat contract) | 4 | 2 errors |

Memory: swap free was 318–1004M during the runs. Another process's HOL job was running; I did not touch it.

**Not determined:** what the HOL/M1 side does with non-UTF-8 bytes or with integers outside int64. I only READ STATEMENTS.md (C5, the cross-tool step).

**Files I wrote** (all under `<session scratch folder>/m1b/Y10/`):
- `run1.sh`, `mutate.py`, `bodiless.py`
- `base/`, `S3a-noHex/`, `M1-assert-false/` … `M6-flat-amount-minus1/` (each has `inputs/`; mutants also have `mutation.diff`)
- `V-flat-false/FlatFalse.dfy`
- `runs/<name>/{out.txt,exit.txt,verification.csv,mem-*.txt,sha.txt}`, `runs/S3a-noHex/audit.md`

No repository file changed. No HOL ran.

| step | status | evidence or blocker |
|---|---|---|
| 1 vacuity / preconditions | done | FlatFalse exit 4; M1 exit 4; no `requires` on the path |
| 2 AssessFlat shape | done | has a body (verified); called by contract only |
| 3 trap search | done | only `@Axiom` at Strings:185 |
| 4 S3a | done | exit 0, 1486; audit 0 findings |
| 5 new controls | done | M1–M6 all exit 4 (some by out of resource only) |
| 6 hashes | done | all equal |
| 7 Unicode / ranges | partly | Dafny side: scalar values only, unbounded `int`; HOL side not checked |

| link id | proposed class | evidence |
|---|---|---|
| S3 | MACHINE-CHECKED (Dafny half only) | base exit 0, 1489; 6 new controls exit 4; not vacuous |
| S3a | MACHINE-CHECKED | S3a-noHex exit 0, 1486; audit of the closure = empty baseline |

M1-B stays OPEN; `end_to_end=false`.
