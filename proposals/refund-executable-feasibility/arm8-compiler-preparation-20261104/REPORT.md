# Refund ARM64 compiler checkpoint

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. Parent local documentation commit: `865b4239`.
This packet records a live check and prepared proof composition. It does not
claim a completed refund compilation or a native behavioral theorem.

## Actual execution state

The existing compiler invocation remains live in exec session60920. Fresh
session polls return that live handle. A separate process query confirms
runner94706 and Holmake94707. The terminal `command.json` does not yet exist.
No restart or second compile invocation occurred.

Exact command:

```sh
python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run.py 0001
```

The child command is pinned `HOL/bin/Holmake --no-cache -j 2
forge_refundArm8CompileTheory.uo`. Its exact argv, source identity and checked
whole-program parent are in `records/compile-start-invocation.json`.
The compiler uses the existing proof-producing `eval_cake_compile_arm8` on
`refund_prog_def`. It requests `refund.S`; no successful output is claimed.

Published backend definitions and ARM64 configuration have built. The current
dependency is `to_data_cvTheory`. Its log has advanced through further checked
translation lemmas. The copied log is an unfinished progress snapshot.
Neither dependency successes nor CPU activity establish the refund compile.

| Executed check | Actual exit | Boundary |
| --- | --- | --- |
| Live process query | 0 | Runner and Holmake observed; terminal compile exit unavailable |
| Nine pinned compiler/proof source comparisons | 0 | Exact committed source bytes; not a new proof |
| Tracked HOL / CakeML diff checks | 0/0 | No tracked tool source changes |
| Four boundary-source comparisons | 0 | Published resource, installation and main-call definitions inspected |
| `run_behavior.py` Python syntax inspection | 0 | Parser only; the proof composition has NOT RUN |
| Local bundle create / verify / restore / fsck | 0/0/0/0 | Exact865b4239 restored;356 files checked locally |

The recovery bundle SHA256 is
`37c6985dbdf0d6a8f6234e698599f8ec1027e3e3a336406e3cc3cae55e437e33`.
It is at `/Users/mackianni/forge-backups/forge-refund-whole-source-2026-11-04.bundle`.
It contains the committed record, not external toolchains or raw failed heaps.
The restore ran on this machine. Exact off-machine archive hashes and an
independent-copy restore remain unverified.

## Next executable check

`forge_refundArm8ProofScript.sml` composes the existing refund source theorem
with the published compiler and ARM64 configuration theorems. It follows the
published hello and ARM64 bootstrap composition methods. No new machine model,
verifier or axiom is proposed. This source is prepared, not kernel-checked yet.

The prepared command, **NOT RUN**, is:

```sh
python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run_behavior.py 0001 0001
```

Its runner first requires a terminal successful compilation and checks the
exact parent source, all six exports and assembly identity. It preserves prior
outputs and records actual exits. Run it only after inspecting the completed
compile result. Require positive reproduction and appropriate controls before
promoting either result to an assurance claim.

## Explicit boundaries

The published compiler theorem permits resource-limit outcomes with prefixes
of the source I/O trace. It does not promise complete output for every finite
machine allocation. The installed-code premise includes register alignment,
heap/bitmap separation, exact code/data and FFI bindings. Concrete installation
and physical runtime correspondence remain open.

The normal `call_main_thm2`, `whole_prog_spec` and `whole_prog_spec2` bridges
require a `POSTv` return contract. The existing refund error result is `POSTe`.
It does not instantiate those normal-return premises. A separate checked
exception-to-whole-program relation remains necessary. No program or theorem
was changed to hide this gap. Modeled Success is not a POSIX exit-status proof.

Full Unicode/source/model binding, independent claim/profile review and new
authenticated admission remain open. Native execution and hosted refund
measurements are NOT RUN. The separate audit task retains its limited local
signing authority. No signing, protected adoption, publication, merge, dispatch
or deployment ran here. M1 and strict integration EXIT remain NOT_ESTABLISHED.
M2–M4 remain subsequent priorities.
