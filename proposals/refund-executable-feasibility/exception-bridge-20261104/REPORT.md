# Refund exception-to-main proof attempt

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. Parent documentation commit: `14e2ccab`.
Verdict: **NOT_ESTABLISHED**. No new exception theorem was accepted.

## Missing relationship

The existing `refund_main_error` theorem proves that a malformed wire result
raises the modeled `Fail` exception. It consumes stdin and preserves the modeled
filesystem apart from that input position. This application-level result has
an exception postcondition, `POSTe`.

The published normal whole-program helpers require `POSTv` and a unit return.
The attempted lemma connects the exception contract to the actual declaration
call of `refund_main`. Under explicit declaration, namespace and heap premises,
it requires `evaluate_dec_list` to return `Rerr (Rraise exn)` and retain the
exception's heap postcondition. It does not change the program or its contract.

The experiment uses existing CakeML definitions and the proof structure of
`cfMain.call_main_thm1`. It introduces no machine semantics or verifier. The
required lemma remains unproved. Even a successful version would still require
the exact initialization, FFI-trace and filesystem composition for this program.
It would not establish a POSIX exit code.

## Actual checks

Commands ran from `/Users/mackianni/forge`. `OUT` denotes
`results/refund-exception-bridge-2026-11-04/attempt-0001`.

| Command | Actual exit | Observed result |
| --- | --- | --- |
| `python3 -B "$OUT/run.py" 0001` | 1 | Missing direct theorem imports; no proof result |
| `python3 -B "$OUT/run.py" 0002` | 1 | Tactic failure; diagnostic heap preserved |
| `python3 -B "$OUT/run_diagnostic.py" diagnostic-0001` | 1 | Fails at variable-renaming step |
| `python3 -B "$OUT/run_diagnostic.py" diagnostic-0002` | 1 | Renaming still fails; exact exception and heap hypotheses printed |
| `python3 -B "$OUT/run.py" 0003` | 1 | Same required theorem remains unproved after using the observed variable |
| Saved failure, parent and frozen-input readback | 0 | Five failures, two heaps, exact parent exports and30 frozen inputs checked |

The second diagnostic records `evaluate_to_heap ... (Exn v)` and `Q v h_f`.
The third build removes renaming and uses that observed `v`. It still fails.
The batch log does not identify the final failing tactic. The failed heap
remains available. No new retry was made after the five unsuccessful checks.

These were positive proof attempts, not successful adversarial controls.
No accepted export exists for any build. New negative controls and reproduction
are **NOT RUN**, because the required positive theorem did not pass.
No passing claim may be inferred from the successful integrity readback.

The last attempted source SHA256 is
`c9fb9137abfa8e614e76b39ed117d9558ef8d9e6a045904514544144524e9421`.
The prior sources, exact argv, local durations and full logs are in `records/`.
`failure-heaps.json` records the two preserved raw heap paths, sizes and hashes.
Large heaps are not duplicated into this packet. No evidence was deleted.

## Preserved evidence and next action

The earlier whole-program source theorem for canonical typed requests remains
unchanged. Its source is `37d623cc2437f391d4a0e72afcc72ed0b541e82f985dc5a2dfbe73a29e3ef4d0`.
All six exports still match the successful repeat. The approved source, original
wrapper and all30 frozen owner-workspace inputs match their saved hashes.
The approved domain and every required result field remain unchanged.

Stop retries on this failed lemma under the existing five-check limit. Continue
the independently running ARM64 compiler check. Inspect its terminal result,
then run the already prepared compiler-correctness composition if its exact
preconditions are met. Do not transfer normal-return proof results to the error
path. Preserve the missing whole-program rejection relation explicitly.

Native correspondence, full Unicode/source/model binding, resource and runtime
premises, independent claim/profile review, authenticated admission and exact
off-machine backup verification remain open. No signing, protected adoption,
publication, merge, workflow dispatch or deployment ran in this experiment.
M2–M4 remain subsequent priorities.
