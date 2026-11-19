# Step I.1d: the Dafny half of the contract link, verified by the pinned Dafny (W9, Opus)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W9 refine-proof: final report. This is the Dafny-side half only. It does not link Dafny to HOL, and M1-B stays open.

**What verified**
- I wrote `LinkedRefund.dfy`. It is non-abstract and does `module LinkedRefund refines RefundSpec`.
  - `Assess` encodes the inputs with the U262 `Encoded` and calls `F.AssessFlat`.
  - It builds `decision` and `plan` only through `Unflatten(ok, amount, reasonBytes, chargeBytes, requestBytes, count)`.
  - `Unflatten` uses a total, opaque `Decode`, built on the library `DecodeCodeUnitSequenceChecked`. It returns "" for a char >= 256 or for bytes that are not UTF-8. So a total decoder was possible, and I did not need the relational fallback.
- Final run: exit 0, "1489 verified, 0 errors", 41.3 s.
  - An unchanged repeat run also gave exit 0, 1489 verified, 43.5 s.
  - All 1489 CSV rows say Passed. `LinkedRefund.Assess (correctness)` has 25 batches, all passed. These cover the inherited R1–R5.
- Command: pinned `dafny verify LinkedRefund.dfy` with the gate options and an absolute solver path. The recorded U295 command lacked `--track-print-effects`; I added it as in the gate. I added no other option.
- I used 5 of 5 attempts:
  - 01: exit 4, out of resource.
  - 02: exit 4. My mistake: the witnesses could not see the approved ensures.
  - 03: exit 0, 1457 verified.
  - 04: exit 0, 1489 verified. This is final; it adds only `@IsolateAssertions` on `Assess`.
  - 05: repeat of 04, exit 0, 1489 verified.
  - All attempts are kept in `attempts/NN/`. The `dafny resolve` runs are not counted.

**Final statements** (full text in `STATEMENTS.md`)
- S3: for every context, response and every six values that satisfy the three flat ensures on the encoded inputs, `Unflatten(six)` satisfies every inherited ensures R1–R5. This is the `Assess` body.
- S4 `ApprovedFlattensToFlat`: any approved result and any flat-contract tuple satisfy:
  - `Flatten(d,p) == t`
  - `Unflatten(t) == (d,p)`
  - `Conforming(d,p)`
- S5 `Uniqueness`: two `Assess` results are equal.
- S5 in a non-abstract module `LinkedPost`, over the unchanged U410 `Post`:
  - `ApprovedImpliesPost`
  - `PostIsApproved`
  - `PostUnique`
- S6: `FlattenInjective`, `FlattenShapes`, `AuthorizedPreimage`, `UnflattenFlatten` (all on conforming pairs), and `FlatYieldsOnlyImages`.
  - The only images are `(false,0,"","","",0)` and `(true,a,Enc r,Enc c,Enc q,1)`.
- S7: witnesses for an accepted, a rejected and a non-ASCII case, through the contracts.
- Review findings closed (Dafny side): rows 10, 13–15, 17, D2, D7, C2, and C7 inside Dafny.
- Not closed: the cross-tool step, which needs the route-study HOL theorem. Also not closed: rows 1–4 and 18, C4 outside Dafny, C5, D6.

**Library axiom**
- The closure CONTAINS the axiom but does not USE it.
- `Std/Strings.dfy:185-187` has `@Axiom lemma CharsConsistent()` in `HexConversion`.
- Call path: my `Decode` → `UnicodeEncodingForm.dfy:310 Strings.OfInt` → `Strings.dfy:221-225 DecimalConversion.OfInt`. `DecimalConversion.CharsConsistent` has a body `{}` at `Strings.dfy:199-201` and it verified.
- A grep for `HexConversion` finds only its own declaration (line 174).

**Audit**
- `LinkedRefund.dfy` alone: exit 0, 0 findings. This is the known trap.
- All 33 reached files with `--compare-report` against `gate/expected-audit.md`: exit 2, 1 finding (`Std.Strings.HexConversion.CharsConsistent`, explicit axiom). So the full closure does NOT match the empty baseline.
- Grep over the 33 files: only that `@Axiom`, one comment, and the recorded `@ResourceLimit` lines. Those are in `UnicodeRelation.dfy` (20e6, five lemmas) and in five library files (up to 115e6). My file has none.

**Negative controls** (final runs)

| Control | Exit | What failed |
| --- | --- | --- |
| N1: charge/request swapped in `Unflatten` | 4 | `Assess`, RefundSpec.dfy:52 (R4 plan) |
| N1b: swap in `Flatten` | 4 | `FlattenShapes`, `AuthorizedPreimage`, `UnflattenFlatten`, `FlatYieldsOnlyImages`. `Assess` passes because it does not use `Flatten`. |
| N2: amount + 1 | 4 | R1 (:43, :44), R4 (:51) |
| N3a: flat ensures 1 dropped | 4 | R1, R2; some batches out of resource |
| N3b: flat ensures 2 dropped | 4 | R1, R2, R4 |
| N3c: flat ensures 3 dropped | 4 | R3 (:48) |
| N4: count 0 for an authorization | 4 | R4 (:52) |
| N5: decoder reads `response.reason` | 0 (passes) | Nothing fails. This hides a wrong `outputReason` field. |

- In N4 the flat body was changed too, so `AssessFlat` itself still verifies.
- In the first control runs (without isolation), `Assess` failed only as "out of resource" in N1, N2, N3b and N4. Those runs are kept in `negative-run01/`.

**Still trusted**
- Dafny, Boogie and Z3.
- That the library UTF-8 code is UTF-8.
- That Dafny does not turn a bodiless lemma into a global axiom.
- That the copies are the approved bytes. The hashes match the working tree.
- Everything on the HOL side and in the exporter.

**My own mistakes and things that do not count**
- Attempt 02 was my error: the witnesses relied on ensures that I had not exported.
- I first planned to reuse `RefundDeterminism` and `RefundExact` through concrete refinements. Dafny 4.11 did NOT verify those inherited bodies again for the new instance. So no claim rests on `RefundDeterminismLinked` or `RefundExactLinked`; `LinkedPost` proves the instance facts directly.
- On N1, Dafny reported only R4 line 52, not R5. I did not investigate why.
- `git status` shows three modified tracked files: `FORGE_MASTER_IDEA.md`, `README.md`, `REVIEW_PACKET.md`. I did not write them.

**Files**
- `<session scratch folder>/m1b/W9/proof/inputs/LinkedRefund.dfy` (SHA-256 `0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34`)
- `<session scratch folder>/m1b/W9/RESULTS.md`
- `<session scratch folder>/m1b/W9/STATEMENTS.md`
- `<session scratch folder>/m1b/W9/attempts/` (01–04, 05-repeat)
- `<session scratch folder>/m1b/W9/negative/` and `<session scratch folder>/m1b/W9/negative-run01/`
- `<session scratch folder>/m1b/W9/audit/` (logs, grep, the 33-file list, hashes)

| step | status | evidence or blocker |
| --- | --- | --- |
| W9.1 LinkedRefund refines RefundSpec (flat contract ⇒ R1–R5) | REPORTED | attempts/04 and 05: exit 0, 1489 verified; `LinkedRefund.Assess` 25/25 batches passed |
| W9.2 Uniqueness (approved ⇔ Post, at most one result) | REPORTED | `Uniqueness`, `LinkedPost.*` passed in the same run |
| W9.3 Flatten injective, two shapes, flat yields only images | REPORTED | `FlattenInjective`, `FlattenShapes`, `AuthorizedPreimage`, `UnflattenFlatten`, `FlatYieldsOnlyImages` passed |
| W9.4 Non-vacuity | REPORTED | 4 witnesses and `PostAcceptsAndRejects` passed |
| W9.5 Negative controls | REPORTED | N1–N4 exit 4 with named R-clauses; N5 exit 0, as predicted |
| W9.audit Closure audit against empty baseline | REPORTED (does not match) | 33-file audit exit 2: one library `@Axiom` (HexConversion), present but not used |
