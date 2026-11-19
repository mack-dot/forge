# Step G9: one composed Dafny theorem for the refund slice (Z9, Opus; pinned Dafny; a model-level result under named assumptions)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z9 report: the composed slice theorem in Dafny. A draft. M1-B stays OPEN. end_to_end=false.

### Findings
1. **The full composition is proved at the Dafny-model level.** File: `<session scratch folder>/m1b/Z9/work/SliceTheorem.dfy`, SHA-256 `1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87`. I ran the pinned Dafny with the gate options (`--verify-included-files`) and it gave exit 0, "1570 verified, 0 errors". The file has no `assume`, no `{:axiom}`, no bodiless lemma and no `expect` (grep exit 1).
2. **Tool defect.** `module X refines SinkCore {}` crashes the pinned Dafny 4.11.0 resolver (NullReferenceException in `PrecedenceLinter.PreResolve`). So `SliceTheorem` uses `import opened SinkCore` and does not refine it. As a result, `VerifyTag` cannot get a body, and the non-vacuity witness is **conditional** on a named reading `TagReading(tok)` (a tag verifies only for that one token's claim). That such a reading is consistent is a fact about uninterpreted predicates. Dafny does not check it.
3. **The theorem cannot exclude zero-amount commits.** Under all hypotheses, a zero-amount commit leaves the store unchanged. The lemma `ZeroAmountCommitKeepsStore` proves this (conditional on `TagReading`). This agrees with U8/D7.

### The theorem (exact text)
```dafny
lemma SliceSafety(init: State, acts: seq<Act>, art: FlatFn)
  requires InitOk(init)
  requires A1_IdealMacAtEachDelivery(init, acts)
  requires A2_MintOnlyOnCheck(acts)
  requires A5_VerifierMatchesAtEachDelivery(acts)
  requires A6_ArtifactComputesFlatContract(art)
  ensures forall e | CommittedEffect(init, acts, e) ::
    exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
      ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorization(init, acts, i))
  ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
  ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
```

**Committed.** `e in Exec(init, acts).core.outbox`. `Exec` runs any adversary sequence of `MintAct(claim, tag)` (no check) and `Deliver(tok, sigOk)` (the real `SinkCore.Step` plus the model's `Commit`).

**ApprovedSpec.** It requires three things:
- `R.Eligible(F.ContextOf(tok.pre, e.requestId), R.Candidate(e.amount, e.reason))`. This is the eligibility rule of the approved `RefundSpec`, inherited without change by `Refund`.
- `F.Authorizes(tok.pre, Transition(Request(e.requestId, e.amount, e.reason), tok.post, e))`.
- `HasCommitWitness`: some delivery k committed entry i, and the stored charge **at that moment** equals `tok.pre`. So `remaining` is the stored state at commit time.

Two helper methods tie this to the full approved `Assess` (R1–R5): `ApprovedResultRefund` and `ApprovedResultLinked`. They show that every result the R1–R5 ensures allow, in `Refund` and in `LinkedRefund`, is `(Authorized(amount, reason), [e])`.

**FlatResultAgrees.** `LinkedRefund.Unflatten(art(FlatInputsOf(pre, e)))` equals `(L.Authorized(e.amount, e.reason), [L.Intent(...)])`.

**UniqueAuthorization.** For entry i:
- the claim of `toks[i]` verifies and was minted;
- `requestId` is in `settled`;
- for every j ≠ i, the request id differs and the token differs.

### Assumptions as they appear in the theorem
- **A1** `A1_IdealMacAtEachDelivery`: the ideal MAC holds at the state before each delivery.
- **A2** `A2_MintOnlyOnCheck`: each minted claim with our ids is `CheckedClaim(pre, t)` with `F.Authorizes(pre, t)`. `CheckDecidesMint` proves that `F.Check` issues a token exactly when `Authorizes` holds.
- **A3**: structural only. Each `Deliver` is one `Next` step. It is not a predicate.
- **A5** `A5_VerifierMatchesAtEachDelivery`.
- **A6** `A6_ArtifactComputesFlatContract(art)`: the ValidArtifact conjunct. It is **not proved**. `FlatContract` restates the ensures of `AssessFlat`. Two methods, `FlatContractFromAssessFlat` and `FlatContractIsAssessFlat`, prove the restatement equal to the `AssessFlat` contract in both directions.
- **A7** (Dafny↔HOL): carried only by the meaning of the **parameter** `art`. Dafny cannot state it.
- **Uninterpreted symbol** `VerifyTag`: inherited without a body from the model into SinkCore. **The audit does not report it.** I confirmed this by reading. The model's `SPEC`, `CHK`, `SpecRel` and types are given values in SinkCore. `RefundSpec.Assess` has no body because its module is abstract.

### Coverage
- ApprovedSpec, UniqueAuthorization and T4/T5: proved in the Dafny model.
- ValidArtifact: only a hypothesis (A6).

**Not covered:** `sink.ts`, `minter.ts` glue, the signer, SQLite atomicity (A3), Ed25519 (A1), compiled code, the HOL theorem `refund_fields`/export link (S4–S7), native execution, per-charge maps (`CommitAt` is not used).

### Commands run (pinned Dafny through `dafny_locked.sh`)
| run | exit | summary |
|---|---|---|
| attempt 1 (refines SinkCore) | 1 | resolver crash |
| 5 resolve-only runs (bisect, warnings) | 0 / crash | not verification |
| attempt 2 (own modules only, no `--verify-included-files`) | 0 | 24 verified, 0 errors |
| attempt 3 (gate options + csv log) | 0 | 1565 verified, 0 errors |
| attempt 4, final (gate options + csv log) | 0 | 1570 verified, 0 errors |
| audit of all 38 files | 0 | 1 finding: `Std.Strings.HexConversion.CharsConsistent` (`{:axiom}`). By reading, it is not called. |
| audit of SliceTheorem.dfy | 0 | 0 findings |

Negative controls on the final text, gate options. Each was also run once on the attempt-3 text, with the same results.
| control | exit | where it fails |
|---|---|---|
| C1 drop A2 | 4 | line 258: the `:|` choice of the Check transition, in `ExecInv` |
| C2 drop the fresh-id guard (SinkCore copy) | 4 | `SinkCore.StepRefinesCommit` (172 and others) and `SliceTheorem` line 299 (`CommittedAt` `!in settled`) |
| C3 drop A6 | 4 | **out of resource** in `PerEntry`, not a definite error |
| C4 "every commit changes store" | 4 | **out of resource** in `SliceSafety` |
| C5 drop A1 | 4 | line 268: `IdealMac` |
| C6 witness without `TagReading` | 4 | precondition of `WitnessFor` |

C3 and C4 give only out-of-resource results. The definite evidence for them, and also for A2, is three proved refutations, each conditional on `TagReading`: `WrongArtifactBreaksFlatPath`, `ZeroAmountCommitKeepsStore` and `UncheckedMintBreaksApprovedSpec`. The positive witness is `Witness`: all hypotheses hold and the outbox is `[W_INTENT]`.

### Files and digests
- Inputs are byte-equal copies of the source files (`<session scratch folder>/m1b/Z9/inputs-sha256.txt`; I re-checked them after the runs):
  - `LinkedRefund.dfy` `0d67b483…`
  - `SinkCore.dfy` `198474e4…`
  - `RefundFinality.dfy` `23269345…`
  - `FinalityProtocol.dfy` `8b70b6b4…`
  - `Refund.dfy` `04168824…`
  - `RefundSpec.dfy` `90a21c71…`
  - `FlatCore.dfy` `a89484e3…`
- Logs and csv files: `<session scratch folder>/m1b/Z9/logs/`
- Controls and diffs: `<session scratch folder>/m1b/Z9/controls/`
- Attempt-3 controls: `<session scratch folder>/m1b/Z9/controls-attempt3/`

### Steps
| step | status | evidence or blocker |
|---|---|---|
| composed theorem | MACHINE-CHECKED (Dafny model) | attempt 4: exit 0, 1570 |
| non-vacuity | MACHINE-CHECKED, conditional on `TagReading` | `Witness`; refinement crash |
| ValidArtifact | ASSUMPTION A6 | HOL link not done |

### Proposed graph rows
| link id | proposed class | evidence |
|---|---|---|
| U1+U4+U5a+S3 composed (model) | MACHINE-CHECKED under A1, A2, A5, A6 | `SliceSafety` |
| U8 | MISSING (zero amount) | `ZeroAmountCommitKeepsStore` |
| U2, U3, U5b | unchanged (TESTED-UNPROVED / MISSING) | not touched |
| S5/S6 (A6/A7) | MISSING | parameter `art` only |

I did not run HOL or git, and I changed no repository file.

**Not determined:** whether the refinement crash also happens with other Dafny versions, and whether some other construct would let `VerifyTag` get a body without refining SinkCore.

