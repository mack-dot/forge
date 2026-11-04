# Focused exception diagnosis — U278

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. The previous goal turn made progress through U276's native
identity checks. This turn identifies a concrete proof obstruction and checks
its isolated lookup lemma. The full exception theorem remains NOT_ESTABLISHED.

## Actual checks

`OUT` is `results/refund-native-audit-2026-11-04/attempt-0005`.
All commands ran from the owner workspace. Exact argv and raw output are in
`records/`. No native recompilation, signing or execution occurred here.

| Command | Actual exit | Result |
| --- | --- | --- |
| `python3 -B $OUT/diagnostic-branch/run.py` | 0 | Inspection completes; final case expression remains unsolved |
| `python3 -B $OUT/focused-lookup-0001/run.py` | 0 | HOL checks the standalone `lookup_result` lemma |
| `python3 -B $OUT/run_focused.py 0001` | 1 | Holmake reports EPERM before checking the repaired theorem; no theory exports |
| Saved-record, source and protected-input readback | 0 | Required statement, two old heaps, exact native file and50 protected files unchanged |

U274's five failures remain. U276's earlier successful inspection remains.
This turn adds one branch inspection, one successful focused lemma, and one
full repair invocation that fails before proof. The full invocation is recorded
as attempt6, under the owner's permission for a separately justified changed
approach. The attempt count is not reset. No further build retry ran.

## Exact obstruction

The old third proof reaches this residual expression:

```text
case do_opapp [refund_main_v; Conv NONE []] of
  NONE => ...
| SOME (env',e) => evaluate (st2 with clock := ck + ck2) env' [e]
```

Its hypotheses already contain:

```text
SOME (env,exp) = do_opapp [refund_main_v; Conv NONE []]
evaluate (st2 with clock := ck + ck2) env [exp] =
  (st' with clock := ck2 + st'.clock, Rerr (Rraise v))
```

Every individually traced operation in the old declaration branch completes.
The final simplification leaves this case expression unresolved. Thus the
branch is not closed; the old compound branch tactic cannot prove the required
result. The observation identifies an unused equality orientation. It does not
show a semantic counterexample or establish that this is the only remaining
problem in the full theorem.

The separate HOL check proves:

```text
SOME (env,exp) = do_opapp [fv; Conv NONE []] /\
evaluate st env [exp] = (st',r)
==>
(case do_opapp [fv; Conv NONE []] of
   NONE => (st,Rerr (Rabort Rtype_error))
 | SOME (env',e) => evaluate st env' [e]) = (st',r)
```

The proof uses an explicit `SYM` of the supplied lookup equality, then the
existing simplifier. It is a universal lemma, not a test. HOL reports DISK_THM,
zero explicit hypotheses and zero explicitly tagged axioms. The imported HOL
kernel, saved heap and dependency closure remain trust dependencies. No new
axiom or proof machinery was introduced. The full printed theorem is in
`focused-lookup-0001/stdout.log`.

Focused lemma source SHA256:
`591f0b814a3e013af9947124da351b8361692ef0897d46d8f1fb236c39a219de`.
Saved heap SHA256:
`7357572346bb83f5c807a96aa226a4e87160693d3a14c958c09bcf37d237034c`.

## Prepared repair and failed builder

`forge_refundRejectFocusedScript.sml` retains the exact statement of
`refund_call_main_exception`. It adds the explicit equality orientation at the
observed residual branch. A separate theory directory preserves all old failed
sources and heaps. The source-only statement comparison passes0.

Repaired source SHA256:
`0c6f989eeb0632bb4942f5161e73e1d94701b41d0b42dd0c51c4d826cef0026a`.
Original third source SHA256:
`c9fb9137abfa8e614e76b39ed117d9558ef8d9e6a045904514544144524e9421`.

Holmake prints the theory-builder linking message, then:

```text
Holmake: Exception: SysErr ("Operation not permitted", SOME EPERM)
```

The command exits1. It produces no `Created theory` message and no accepted
theory export. This is an execution-permission failure before theorem checking,
not evidence for or against the repaired proof. The pinned build source shows
the theory runner uses `hol run`; the log does not identify the denied syscall
or path. A temporary-directory explanation is NOT_ESTABLISHED. No proof-tool
patch, permission bypass, alternate-task reroute or new build retry was used.

## Claim changes and remaining work

| Claim | Status | Evidence |
| --- | --- | --- |
| Residual lookup case and its supplied equality identified | TESTED diagnostic | Exact saved-goal trace, exit0 |
| Given lookup/evaluation results imply the case result | PROVED | `lookup_result`, exit0, exact statement above |
| Repaired full `refund_call_main_exception` | NOT_ESTABLISHED | Builder exit1 before proof; zero accepted exports |
| Whole-program malformed-input semantics and heap/FFI composition | NOT_ESTABLISHED | Requires the full exception bridge and its remaining initialization/trace composition |
| Native malformed-input status and physical I/O correspondence | NOT_ESTABLISHED | Source-level exception reasoning does not prove POSIX process behavior |
| Native artifact and established parent evidence preserved | TESTED identity | Readback0; executable remainsb8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8 |
| Clean independent full-chain replay | NOT_ESTABLISHED; NOT RUN | The required final proof chain is incomplete |

The compiler behavior build remains owned by its existing task. This checkpoint
does not assert a terminal result for that process. U276/U277 retain the full
native identity and compiler/runtime premise matrices. Loaded-state, physical
CPU conditions, FFI/OS behavior, resource sufficiency, exact dynamic-library
identity and source-to-HOL correspondence remain open.

**Next smallest action:** identify and resolve the builder's denied operation
within an authorized environment, without changing proof machinery. Then run
the same frozen repaired source once and inspect the actual theorem result.
Do not rerun merely because time has passed. If that theorem passes, require
reproduction and a wrong-result negative control before composing whole-program
error semantics. No specification change or valid-input restriction is proposed.
