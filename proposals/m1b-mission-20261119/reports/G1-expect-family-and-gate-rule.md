# Step G1: all tiers of the present gate on the admitted wrong submissions; the expect family; an UNAPPLIED gate rule; termination wording (Z1, Opus; pinned Dafny and Node)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z1 report: all tiers of the present gate, the `expect` family, the proposed rule, and termination

**Findings**

1. **All tiers of the present gate, run on the 7 that were admitted** (mirror script `fullgate.py`, gate/refund.py lines 80–149, 153–194 and 254–260; pinned Dafny through the lock; Node 24.3.0):
   - A24, A25, A38 and A39 are refused at the hostile tier. The node run exits 1, so the gate gives HOSTILE_REJECTED (lines 178–179). The gate's seeds are fixed (8001–8003). Seed 8001 generates amount 7: T2 catches A24 and A39, and T3 catches A25. A38 fails at the first fixture.
   - A33 is refused. Node aborts with exit −6 ("JavaScript heap out of memory") after 12 s. The JS constant is a getter, so it builds the 10^9-element sequence on each call.
   - A18 gets no verdict. Node ran for 300 s and my watchdog killed it. The gate's `run()` has no timeout (line 66), so the gate hangs and never accepts. I did not run the effect of a hang on the gate lock (READ, GUESS).
   - A37 is ADMITTED by every tier, but it is not wrong. `dafny build` compiles `:|` to an enumeration that starts at 1, and the run returns.
   - **Answer:** from the original 7, only A37 is still admitted, and it is harmless.
   - New wrong submissions that ALL tiers admit:
     - `expect` halts on amount 61, 1000, 123456789 and 2^63−3 (Z24 ×4).
     - `:- expect` (E01).
     - `expect` inside a function's by-method body (E12).
     - An `expect` after a `//` comment that ends with a lone CR (S2).
     - Stack overflow (E06), out-of-memory (E07) and a 10^18-step loop (E08), each triggered by one amount only.
2. **The hostile tier is a finite test.** For an A24-type halt on one amount, over 50 other seeds:
   - amount 7: caught on 44 of 50 seeds (T2 22, T3 39);
   - amounts 61, 1000, 123456789 and 2^63−3: caught on 0 of 50 seeds.

   The control C1 passes on all 50. The ts/refund.ts host catches each exception and returns Rejected with no plan (lines 97–98). So in the host a halt fails closed, but a hang stops the synchronous event loop.
3. **Survey of other constructs** (all RAN):

| construct | verify | audit | present gate |
|---|---|---|---|
| `expect` | pass (assumed) | not reported | refused only if the test hits the input |
| `:- expect` | pass | not reported | admitted |
| array bounds, division by zero, `assert … by` | refused (exit 4) | — | refused |
| `{:test}` | — | — | refused by the byte rule |
| deep recursion, large allocation, slow loop | pass | clean | admitted if keyed to a rare input |

   - `decreases *` and `print` were refused already (Y5 A16 and A17).
   - Surprise: Dafny optimizes `1 + Deep(n-1)`, so there is no stack overflow. A non-tail method recursion is needed.
   - Surprise: `--warn-contradictory-assumptions` flags A38 only. It does not flag A25 or A24.
   - Dafny nests block comments (N1a admitted, N1b parse error). A lone CR ends a `//` comment (S1). Form feed and U+2028 do not end it (S3, S4).
4. **Proposed rule (UNAPPLIED):** no word `expect` in `impl/Refund.dfy` outside comments and literals.
   - A fail-closed lexer finds the words. It nests block comments. It ends a `//` comment at the earliest CR, LF, VT, FF, NEL, LS or PS. It splits words at `?` and `'`. It refuses non-UTF-8 input and unterminated comments or literals.
   - The pinned Dafny has no structured query for this. `--rprint` exists, but its output is text with printer comments that hold the desugared code. I ran it only as a cross-check: it agrees on every file that resolves.
   - Results over 75 submissions (53 from Y5 and 22 new):
     - It refuses A24, A25, A38, A39, the Z24 ×4, E01, E12, S1 and S2.
     - Correct submissions refused by the new rule alone: none (C0–C15, N1a, A11, A34).
     - C9–C12 are still refused by the unchanged byte rules. I do not propose to change those rules.
     - S3 and S4 are wrong submissions. The new rule refuses them because of its conservative line endings (the old tiers refuse them too). Side effect: a correct file with FF or U+2028 inside a `//` comment would be refused.
     - Still admitted after the rule: A37 (harmless) and E06, E07, E08 (the resource class).
   - Lexer unit controls: 29 of 29 pass for both copies, the standalone one and the code extracted verbatim from the diff.
   - **Diff:** `proposal/refund-expect-rule.diff`, SHA-256 `70910e2ec3f3139f5f0ea7635a0bba4cc2b571e3f4bbb9b0baf94be6811c9ce3`.
     - It touches only `gate/refund.py` (`git apply --check` exit 0, nothing applied).
     - That file is not one of the 8 frozen PR-gate modules.
     - It IS listed in `gate/provenance/implementation.lock`. Surprise: the lock records `9d91b754…`, but the file today is `bafc1b72…`. The lock was not updated after step B (#43). The `spec/refund/spec.lock` entry is also stale (`993dade8…` against `8b131ab8…`).
     - Approval needed: an exact-diff proposal and the owner's merge (the precedent is step B, ratification record 0001). Also an owner decision on the implementation.lock entry.
5. **Termination.** Without `decreases *` and `expect`, Dafny proves that each loop and recursion terminates in its mathematical model: unbounded integers and unbounded memory. So it proves total correctness in that model, only for programs with no `expect`. It proves nothing about time, memory, stack or target-runtime faults: A18, A33, E06, E07, E08 all verify.
   - Proposed wording: "R6 (TEST, not a proof): on the recorded fixtures and seeded corpus, each compiled Assess call returns within T ms and the test process stays below M MB. Untested inputs can still stall or halt."
   - This needs a per-call timeout in hostile.ts (worker thread) or a `timeout=` in `run()`. Both are protected paths. I wrote no diff for them.
   - I do not claim total correctness.

**Files** (all in `<session scratch folder>/m1b/Z1/`):
- Scripts: `fullgate.py`, `probe.ts` and `probe.sh` (scratch copy of the test with variable seeds; NOT the gate), `trigger.cjs`, `dafny_tokens.py`, `expect_rule.py`, `lexer_controls.py`
- New submissions: `subs/*.dfy` (22)
- Proposal: `proposal/refund-expect-rule.diff`, `proposal/gate/refund.py`
- Results: `rule_results.json`, `rule_table.md`, `rule_run.out`
- Run logs: `tree/<name>/logs/`

**Commands run**
- `scripts/javascript_env.py`: exit 0.
- `fullgate.py` on 39 submissions: each step exit is in `tree/*/logs/result.json`. Correct ones: 0/0/0/0/0. Refusals: verify exit 4, hostile exit 1 or −6. A18: watchdog kill (−9).
- Probe with 50 seeds on 6 models: exit 0.
- `expect_rule.py --rprint`: exit 0. `lexer_controls.py`: exit 0.
- Contradictory-assumptions verify: exit 2 (A38), 0 (A25, A24, C1).
- No repository file was changed.

**Could not determine:** whether Dafny's JS stack depth and memory limits are stable across hosts. The behaviour of other compile targets.

| step | status | evidence or blocker |
|---|---|---|
| (1) all tiers on 7 + controls | DONE | `tree/*/logs/result.json` |
| (1) seed measurement | DONE | `tree/*/logs/probe-report.json` |
| (2) construct survey | DONE | E01–E12, S1–S4, N1 |
| (3) diff + standalone rule | DONE (UNAPPLIED) | SHA `70910e2e…` |
| (4) termination wording | DONE (wording only) | no protected diff |

| link id | proposed class | evidence |
|---|---|---|
| S2 | MACHINE-CHECKED (partial correctness only; the `expect` admission stays open until the owner merges the diff) | D5 and Z1 runs |
| "Assess returns a decision" (no id) | TESTED-UNPROVED | hostile tier; misses keyed halts |
| resource bounds (no id) | MISSING | E06, E07, E08 admitted |

M1-B stays OPEN; `end_to_end=false`.
