# Step D5: the zero-code-review experiment at Dafny source level: 53 unread submissions against the gate's critical-tier refund checks (Y5, Opus; pinned Dafny)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Y5 report: the zero-code-review experiment at Dafny source level

**Answer.** No. The critical-tier admission rule does not admit exactly the correct ones. No admitted submission can return a wrong decision. But the rule does admit submissions that halt the program, or that never return in practice, on chosen inputs. It also refuses some correct ones because of its byte rules.

### Findings
1. **REAL HOLE: `expect` acts as an assumption for the verifier, and the audit does not report it.** Dafny assumes the condition after `expect`. At run time a false `expect` halts the program. The mirrored rule admitted all four `expect` variants, with exit codes audit 0, verify 0, audit 0, and all 6 required TRX rows "Passed":
   - A24 halts only when the amount is 7.
   - A25 has unreachable "Authorized(8)" code after `expect false`.
   - A39 hides the `expect` in a helper method.
   - A38 halts on every input.

   The smallest admitted file is `subs/A38-expect-always-halt.dfy`. It is the 3-line header, then this body:
   ```
   method Assess(context: Context, response: ModelResponse) returns (decision: Decision, plan: seq<RefundIntent>)
   { expect false; decision := Rejected; plan := []; }
   ```
   Negative control: the same file without `expect` (A38n) is refused (verify exit 4).

   The spec's ensures clauses hold only if Assess returns, so a halt satisfies them vacuously. The gate's source scan (gate/refund.py:99-105) checks only `include`, `{:` and `@`. It does not check `expect`. The `run_check.py` grep does ban `expect`, but the gate does not.
2. **Liveness and resource holes (admitted):**
   - A18 runs a loop of 10^18 steps before the correct answer.
   - A33 has `const Pad := seq(1000000000, i => i)`.

   The spec says nothing about time or memory.
3. **Probable compile gap (admitted at the critical tier):** A37 has `var k: int :| k > 0;` in compiled code. It verifies and its audit is clean. I guess `dafny build` refuses it, but I did not run a build.
4. **Correct but refused (4 cases):**
   - C9 has the word "include" in a comment.
   - C10 has `{:induction false}`.
   - C11 has `@` in a string.
   - C12 has a CRLF header.
5. **Dead code admitted (harmless to Assess):**
   - A11: a bodiless `ensures false` lemma in an abstract module in the impl file. This is the known trap. It cannot be called: a call from Refund gives "a compiled module is not allowed to use an abstract module", and an abstract import is refused.
   - A34: a nested comment.
6. **Refused as expected (29 wrong, 2 dishonest).** These were refused for the intended reason: assume, axiom, verify false, extern, bodiless function, lemma, forall or while, decreases * (also a dead `Main`), print, requires false, redefinition, shadow module, altered or second include, by-method mismatch, opaque, and `dfyconfig.toml` in cwd or in `impl/` (verify exit 4).

   Four were refused by a parse or resolution error, not by a check:
   - A08: unresolved name.
   - A21: a non-ASCII identifier is a parse error in Dafny 4.11.
   - A28: `{ :axiom}` with a space.
   - A13: refused, but at verification.

### What I RAN (pinned Dafny, gate options from `gate/backends/dafny.py:352-356`, one process at a time, memory checked first)
- `python3 admit.py` on the whole set: exit 0. Then three reruns on fixed or new entries: each exit 0.
- In total, 53 submissions. Each audit, verify and audit exit code is in `results.json`.
- Controls:
  - The repository `impl/Refund.dfy` copy (C0) is admitted.
  - A02 `assume false` is refused (audit exit 2).
  - The spec copy SHA-256 is `90a21c71…5fe57`, equal to the approved digest. The binding and audit baseline copies are also byte-equal.
- `git status`: no repository file changed.

### What the experiment does NOT show
- It is a finite set of 53 hand-made submissions. It is not a proof that the rule is complete.
- It covers only the critical tier.
- I did not run the hostile-tests tier (JavaScript build plus fast-check, gate/refund.py:153-194). That tier would probably catch A38 and maybe A24. That is a GUESS.
- Compiled code, the JavaScript runtime and the native executable are not covered.
- The PR-gate file rules (for example a new `dfyconfig.toml` at the repository root) are not covered.
- Dafny or Z3 soundness bugs were not searched.

### Files
All are under `<session scratch folder>/m1b/Y5/`:
- `admit.py`: the admission script, mirror checks M1–M8 with gate line citations.
- `gen.py`: writes the submissions.
- `subs/*.dfy`: the 53 submissions.
- `manifest.json`
- `results.json`
- `run1.out`
- `base/`: the copies of the approved files.
- `work/<name>/`: the logs, the `.trx` files and the audit `.expect` files.

| step | status | evidence or blocker |
|---|---|---|
| copy spec byte-equal | DONE | SHA-256 equal to the approved digest |
| ≥6 correct implementations | DONE (8 admitted + C0) | C1–C8, exit 0/0/0 |
| ≥12 adversarial submissions | DONE (40) | A01–A39, A38n |
| admit.py mirrors the gate | DONE (critical tier only) | gate/refund.py:80-149, 254-260 |
| wrong ones admitted | 7 FOUND | A18, A24, A25, A33, A37, A38, A39 |
| correct ones refused | 4 FOUND | C9–C12 |
| hostile tier, build | NOT RUN | rule 3; out of scope |

| link id | proposed class | evidence |
|---|---|---|
| refund source admission (critical tier) | TESTED-UNPROVED | finite set; `expect` halt is admitted |
| "verified Assess returns a decision" | MISSING | partial correctness only; `expect`/halt not excluded |

I did not map link ids to `TOP_LEVEL_GRAPH.md` by number. The caller must match these two rows to the graph's ids. M1-B stays OPEN; `end_to_end=false`.

**Proposal (not applied; it needs `gate/`, a protected area):** add `expect` to the refund source scan, or require that the audit flags it.
