# Refund whole-program source semantics

CURRENT stage: none. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. Parent documentation commit: `cb68edf7`.
This is a local, unadopted proposal. It establishes source-program behavior in
the published CakeML semantics. It does not establish native artifact behavior.

## Exact theorem

`refund_semantics` covers the exact declaration list `refund_prog`, with its
actual `refund_main` call, under these explicit premises:

1. Modeled stdin contains the complete canonical serialization of the nine
   request fields: charge ID, request ID, original amount, remaining amount,
   enabled flag, opened flag, candidate flag, requested amount and reason.
2. The command-line list satisfies `wfcl cl`.
3. The modeled filesystem satisfies `wfFS fs` and `STD_streams fs`.

From the published primitive initial state and `basis_ffi ext cl fs`, every
behavior covered by `sem_satisfies` terminates with modeled `Success`. The
extracted filesystem equals the original filesystem after consuming stdin and
appending the complete rendered refund result to stdout. The result contains
authorization, amount, reason, charge ID, request ID and intent count.
Both authorized and rejected requests remain covered. No eligibility condition
was added as an entry premise. Integers and model byte strings stay unbounded.

The proof uses the existing `prove_sem_thm` bridge. It checks the exact main
name/value binding, unchanged FFI during declaration initialization, and the
required initialized library references. Two supporting theorems establish the
general wire-result contract and its specialization to every canonical request:
`refund_whole_prog_spec` and `refund_request_whole_prog_spec`.

The previous I/O error theorem remains separate. This whole-program theorem
covers canonical request input; it does not state a native malformed-input exit
code. Published `Success` is not a POSIX status guarantee. No refund payment,
retry state, physical I/O delivery or native termination is inferred.

## Actual checks

Commands ran from `/Users/mackianni/forge`. `OUT` denotes
`results/refund-stdio-composition-2026-11-04/attempt-0001`.

| Command or child check | Actual exit | Result |
| --- | --- | --- |
| `python3 -B "$OUT/run_whole.py" whole-0001` | 0 | Three own theorems checked; 12 published dependencies also built |
| Substituted main-entry child | 1 | Published bridge refuses the wrong function binding; no accepted export |
| `python3 -B "$OUT/run_whole.py" whole-repeat` | 0 | Six byte-identical exports |
| `python3 -B "$OUT/run_whole_controls.py"` | 0 | Required entry refusal and positive repeat checked |
| `python3 -B "$OUT/run_closure.py"` | 0 | Fresh closure import/inspection |
| `python3 -B "$OUT/dependency_snapshot.py"` | 0 | 242 theory file sets plus kernel/heap hashes |
| `python3 -B "$OUT/readback_whole.py"` | 0 | Exact exports, refusal reason, premises and dependency bytes checked |

The mutation selects `refund_dispatch` as the entry name while retaining the
required `refund_main_v` contract. The bridge reaches its namespace check and
fails on `SOME refund_dispatch_v = SOME refund_main_v`. This is the intended
binding refusal, not an infrastructure error. No theorem was accepted for it.

Exact argv, source snapshots, logs, exports and numeric exits are in `records/`.
The first build took 737.2824473340006 local elapsed seconds, including dependency
builds. This is an execution observation, not a hosted benchmark or savings claim.

## Identities and checking limits

Whole-program proof source SHA256:
`37d623cc2437f391d4a0e72afcc72ed0b541e82f985dc5a2dfbe73a29e3ef4d0`.
Repeated theory data SHA256:
`52b94fa448fa6de315cab80251ed5cdf46184a576e9478644b374e8071b19ded`.

The imported I/O source remains `6f7aa17a`, with data `8971cd15`. Wire source
remains `417b69d4`, with data `17482ed9`. Full hashes are in the command records.
The original method and wrapper remain unchanged. No protected implementation,
policy or workflow was adopted or changed.

Fresh closure inspection covers 243 theory nodes and 42 exported theorem tags
across the wire, I/O and whole-program theories. Their hypotheses are empty.
The only recorded import tag is `DISK_THM`. The closure retains the four existing
foundation axioms: `SELECT_AX`, `INFINITY_AX`, `ETA_AX` and `BOOL_CASES_AX`.
No new axiom was introduced. The remaining `min` node is the kernel seed.

The 12 dependency builds and fresh own proof builds are real executions.
The closure inspection does not replay every upstream source or authenticate
serialized imports merely by hashing them. Independent human review and an
accepted provenance profile remain open.

## Next executable link

The existing in-logic arm8 compiler has been invoked separately on this exact
`refund_prog_def`, after its controls and readback passed. Its record is under
`results/refund-arm8-compile-2026-11-04/attempt-0001/compile-0001/`.
The invocation and prepared source are evidence of a started operation only.
No compiler result, machine-code artifact or native run is claimed here.

Require the actual successful compile theorem, exact code/data/configuration
identities, compiler-correctness composition and reproduction. Then bind the
assembled/linked artifact and runtime to the modeled installation and FFI
premises. Preserve resource-limit behavior and the complete Unicode/source/model
binding as explicit obligations. Do not substitute a narrower input contract.

The separate audit thread owns local linking/ad-hoc signing and native controls
under U269's limited approval. Release signing, publication, deployment and
protected adoption remain separate boundaries. No signing or native execution
occurred in this proof work. Hosted refund measurements and new admission are
NOT RUN. Independent-copy archive hash/restore remains unverified. M1 and strict
integration EXIT remain NOT_ESTABLISHED. M2–M4 remain subsequent priorities.
