# Step G10: adversarial review of the Dafny sink core proof (Z10, Opus; pinned Dafny on copies)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Z10 adversarial review of the SinkCore proof. M1-B stays OPEN. `end_to_end=false`. Stage 9 is still deferred. I approve nothing and I changed no repo file.

**Findings, ranked**
1. **HIGH: no real signature scheme can satisfy A1 (`IdealMac`).** `IdealMac(s)` says that every (claim, tag) pair that verifies is in the finite set `s.minted`. `VerifyTag` does not depend on the state. I proved `Attack.TotalVerifierBreaksIdealMac`: if every claim has at least one verifying tag, then `!IdealMac(s)` holds for every `s`. Every real scheme has this property, because the key holder can sign any message. I also proved `Attack.IdealMacAtInit`: `IdealMac` at the initial state of `InitInv`/`InitRel` (minted = {}) makes `VerifyTag` false everywhere, so no Commit ever happens. So A1 holds only for a verifier that accepts a finite set of pairs, with `minted` fixed in advance. Read in plain words, A1 means "no forgery is ever presented and `minted` already holds every tag that will ever be signed". The theorems are not unsound, but A1 as written describes no real verifier. Fix proved: `Attack.LocalA1Suffices` keeps `Inv` with the step-local premise `VerifyTag(c,t) ==> (c,t) in s.minted` for the presented pair only. That premise can be met.
2. **The hypotheses are not vacuous.** `SinkCoreW.WitnessRun` is a copy of the core where `VerifyTag` accepts exactly 3 pairs. It proves the following:
   - A reachable state satisfies `Rel`, `Inv`, `IdealMac` and `InitOk`.
   - It has 2 commits on charge c1, and the sum equals original = 100 (T5 is tight).
   - A replay is refused (`RequestSettled`, and the model's Commit leaves the state unchanged).
   - A forged tag is refused (`SignatureInvalid`).
   - `TwoCharges` proves that request id "r1" commits on both c1 and c2. Freshness applies per charge only.
   - Probe Z10, which tries to prove `false` from A5, `Rel`, `Inv`, `IdealMac` and `InitOk`, fails (a real error, not out of resource).
3. **MEDIUM: the D7 report's statement "inherited model lemmas verify again for this instance" is false.** The CSV has 56 rows, all "Passed". `CommitPreservesInv`, `InvMeaning`, `InitInv` and every other inherited lemma have rows only under `FinalityProtocol.*`. Nothing appears under `SinkCore.*`. The conclusions still hold for the instance by parametricity, because the model assumes nothing about its parameters. These are the parameter obligations:
   - The 4 types `(==, !new)`: Dafny checks them at refinement.
   - `SPEC`/`CHK`: given values.
   - `SpecRel`: given a body, no property is assumed.
   - `VerifyTag`: left bodiless, nothing checks it, and nothing needs to. `dafny audit` does not report it.
4. **MEDIUM: `CommitAt` is weaker than claimed.**
   - It ensures neither the outcome nor `Inv`.
   - It passes `init := stores[k].charge` (the current charge) to `SinkCommit`. So that call's `Inv` clause is useless once the log is non-empty.
   - T1–T5 are proved for a single charge only. `IdealMac` for each component needs every charge's tags in that component's `minted`.
5. **LOW: T1 is weaker than its wording.** T1 says "exactly one verifying token", but its token history `toks` exists only in the proof. The executable `Core` stores no tokens. Z11, which states that only one tag verifies for each claim, cannot be proved. T1 means one token per commit, not a unique tag. `StepRefinesCommit` (an "if and only if" under A5) rules out a commit that disagrees with that history.
6. **LOW: proofs run close to the resource limit.**
   - `RefundSliceShape` uses 647,061 of 1,000,000.
   - Mutants Z3/Z3b (the relation also accepts amount = remaining + 1) are refused only by out of resource in `ChainSum`. T4's sensitivity to a weaker relation is therefore not cleanly shown.
7. **Tool fault: the pinned Dafny 4.11 crashes on any refinement of SinkCore.** A 4-line file (`module W refines SinkCore { VerifyTag {false} }`) gives NullReferenceException in `PrecedenceLinter.PreResolve`, exit 1. That is why my witness is a renamed copy of the core.
8. **`sink.ts` compared with the core (read only):**
   - **Stricter in `sink.ts`:** size ≤ 8192, exact shape, canonical text, `domain`, hex64 ids, a fixed signature length, no NUL and no lone surrogate, and UNIQUE request ids in the settled and outbox tables. So the core's "if and only if" does not carry over to `sink.ts`, only the commit-implies-accept direction plausibly does. Z2 shows that a check stricter than the model breaks `StepRefinesCommit`.
   - **No core counterpart:** the "no stored state" path, the replayed/rejected status, and ROLLBACK on failure (A3).
   - **A5 hides A4 for `sink.ts`:** `sink.ts` verifies over `signedBytes(body)` with `preStateSha256`, but `ClaimOf` holds the full pre-state, so A5 for `sink.ts` also needs A4.
   - **Same order of checks:** ids, signature, settled request id, pre-state.
   - **Exact id comparison in both:** SQLite BINARY text comparison in `sink.ts`, exact `seq<char>` equality in the core.
   - **Neither checks `intent.requestId == requestId` or the post-state:** both rest on A1+A2.
   - **Minor:** the `MONEY` pattern allows 19 digits, which is more than MaxMoney (2^63−1). The minter's spec refuses such amounts. The sink does not look at amounts.

**What I ran**
| step | exit | result |
|---|---|---|
| main verify with CSV | 0 | 56 verified |
| `Attack.dfy` attempts 1–3 | 1 (crash), 4 (2 errors), 0 | 60 verified |
| `WitnessCore.dfy` attempts 1–3 | 4 (out of resource), 4 (out of resource), 0 | 67 verified |
| witness control (remaining == 1) | 4 | real error |
| crash reproduction | 1 | NullReferenceException |
| Z1 store id lower-cased | 4 | real error |
| Z2 case-insensitive check | 4 | real error |
| Z3, Z3b relation allows amount + 1 | 4, 4 | out of resource only (Z3 also has 1 real error, at line 375) |
| Z4 settle omitted | 4 | real error |
| Z5 other charge id accepted | 4 | real error |
| Z6 T5 strict | 4 | real error |
| Z7 Enc("ab") == Enc("b") | 4 | real error |
| Z8 signature ignored for empty id | 4 | real error |
| Z9 effect amount + 1 | 4 | real error |
| Z10 vacuity probe | 4 | real error |
| Z11 unique tag | 4 | real error |

All runs went through `dafny_locked.sh` with the gate options, one at a time, after a swap check.

**Files** (folder `<session scratch folder>/m1b/Z10/`)
- `base/sink/Attack.dfy` (`0b660513…`)
- `base/sink/WitnessCore.dfy` (`36024a92…`)
- `base/sink/CrashRepro.dfy`
- `mutate.py`, `v.sh`
- `logs/` (`main.csv`, `attack3.csv`, `wit3.csv`, one log for each run)
- `mutants/`
- `base/` copies of the five input files (SinkCore sha `198474e4…`, verified equal)

**Not determined**
- Whether Z3/Z3b would give a real refutation with a larger resource limit (not tried, to stay within the rules).
- Whether `sink.ts` really implements the core.

| step | status | evidence or blocker |
|---|---|---|
| (1) vacuity | hypotheses satisfiable; A1 cannot be met by a real scheme | `WitnessRun`, `TwoCharges`, `TotalVerifierBreaksIdealMac`, Z10 |
| (2) refines | inherited lemmas only under `FinalityProtocol.*`; still sound | `logs/main.csv` |
| (3) hidden assumptions | A1 too strong; A5 hides A4 for `sink.ts` | `Attack.dfy` |
| (4) strength | T1 relies on the proof-only token history; `CommitAt` has no T1–T5 | read and Z11 |
| (5) mutants | 10 of 12 real refutations, 2 out of resource only | `logs/Z*.log` |
| (6) `sink.ts` | 8 differences listed above | read only |

| link id | proposed class | evidence |
|---|---|---|
| U4 | MACHINE-CHECKED (model only) | verified once in the abstract module, not again for the instance |
| U5 | MISSING for `sink.ts`; core sub-link MACHINE-CHECKED under A1 (unrealizable as stated), A2, A3, A5 | Attack, WitnessCore |
| A1 | ASSUMPTION, needs a step-local form | `LocalA1Suffices` |
