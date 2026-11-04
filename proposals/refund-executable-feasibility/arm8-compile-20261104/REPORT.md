# Refund ARM64 compilation checkpoint

CURRENT stage: none. Active milestone: M1. Stage12 is unauthorized.
`end_to_end=false`. This is a local proposal, not an adopted assurance profile.

The existing CakeML in-logic ARM64 compiler completed for the proposed refund
program. A fresh repeat produced the same six theory exports and assembly.
This establishes the recorded compilation equation. Compiler behavioral
preservation is a separate proof, now in progress. No terminal result for that
proof is available at this checkpoint.

## Exact claim and identities

The checked theorem is `forge_refundArm8CompileTheory.refund_arm8_compiled`.
Its full statement is in [the repeat log](records/compile-repeat/theory.log).
It establishes:

```text
backend$compile arm8_target$arm8_config
  (backend$set_oracle arm8_config$arm8_backend_config oracle) refund_prog
  = SOME (code, data, info)
```

The same conjunction binds FFI names, symbols, syntax validity and encoded
configuration. It states `LENGTH code = 130436`, `LENGTH data = 2531`, and no
extra shared-memory entries. The theorem has zero explicit hypotheses. Its
recorded import tag is `DISK_THM`. No explicit tagged axiom appears in the
printed theorem. That does not remove the imported kernel and theory trust.

| Artifact | SHA256 |
| --- | --- |
| Exact compiler source | `b7e12fcf2754d115eb80d0f49fb07c06d629b956ed2e9f0d1a6213b2be60202c` |
| Repeated theory data | `30076203f55c9f0fa85dec0ebcb62d5ee41961b46055727fe26c9299e55dd78a` |
| Repeated assembly | `4c750e4f9ecf75ff1f0bf5af7bfbdd0600ee2ca0e1564fcadc299db55c3a1757` |
| Source whole-program theorem data | `52b94fa448fa6de315cab80251ed5cdf46184a576e9478644b374e8071b19ded` |
| Separate task's repeated native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The assembly has755044 bytes. The executable hash identifies the native audit's
artifact. It does not establish semantic preservation or authenticated release
provenance. A local ad hoc signature does not authorize a release.

## Commands actually executed

Working directory: `/Users/mackianni/forge`.
Runner directory:
`results/refund-arm8-compile-2026-11-04/attempt-0001/`.

| Command or saved result inspected | Actual exit | Result |
| --- | --- | --- |
| `python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run.py 0001` | 0 | Compilation equation exported |
| `python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run.py repeat` | 0 | Six identical exports and identical assembly |
| `python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/validate_compile.py` | 0 | Saved results, exact artifacts, full mission and30 frozen inputs checked |
| Native build / repeated build, separate audit | 0/0 | Same exact executable; inspected here, not rerun |
| Native cases / repeated cases, separate audit | 0/0 |22 typed and six malformed observations per run |
| Native observation readback | 0 |84 input/output/error streams match across runs |

The two compiler runners invoke:

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/Holmake --no-cache -j 2 forge_refundArm8CompileTheory.uo
```

The exact working directory, parent source and object identities are in the
[first command](records/compile-0001/command.json) and
[repeat command](records/compile-repeat/command.json).
The [identity validation](records/compile-validation.json) checks both archived
outputs and the live parent files. The first compiler run took
2674.4407615409873 local seconds, including dependency builds. The repeat took
137.65932195901405 local seconds with those dependencies available. These are
different setup conditions. No speedup, hosted runtime or billed runner-minute
claim follows.

The pinned CakeML commit is `cd9155694c16831373ab695a670794f23282ed62`.
The pinned HOL commit is `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
The existing compiler checks the register-allocation witness. No new verifier,
machine semantics, axiom or signing service was added.

## Started checks with no final result

```sh
python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run_closure.py
python3 -B results/refund-arm8-compile-2026-11-04/attempt-0001/run_behavior.py 0001 repeat
```

These commands are **IN_PROGRESS**. Their terminal exit codes are unavailable.
The closure inspection uses the configured `cake_compile_heap`. It imports
existing theory objects. It is not a fresh source replay of every dependency.
The [partial logs](records/in-progress/) are explicitly incomplete snapshots.
The prepared dependency snapshot has NOT RUN at this checkpoint.

The proposed behavioral composition uses published `compile_correct` and the
ARM64 configuration theorems. It must retain installation, environment and
resource-limit premises. Compilation success is not its success criterion.
First inspect the actual theorem and all premises, then require adversarial
binding controls and exact reproduction. None of those future results is
claimed here. Do not restart either live check from an absent terminal record.

## Native observations and their limits

The [readback](records/native-observation-readback.json) checks the separate
native-audit task's recorded execution. Both runs include22 typed fixtures.
Each produced the exact modeled output and process exit0. The six malformed
inputs produced no stdout or stderr and also exited0. The latter is an
observation, not a proved native rejection or failure-status contract.
The six cases remain `INCOMPLETE_NO_NATIVE_ERROR_CONTRACT`.

No native run or signing command was executed by this checkpoint task. The
separate task owns its limited U269 local signing authorization. Its runtime
work remains distinct from release signing, admission and deployment.

## Remaining assurance links and next check

| Link | Status and smallest next action |
| --- | --- |
| Canonical whole-program source behavior | Checked locally in U271; unchanged |
| Exact compilation equation and reproduction | Checked locally here |
| Compiler behavior preservation | IN_PROGRESS; finish the existing invocation and inspect the actual conclusion |
| Malformed-input whole-program exception bridge | NOT_ESTABLISHED; U274 retains five unsuccessful checks; no further retry on that lemma |
| Complete Unicode/source/model binding | NOT_ESTABLISHED; preserve the full approved domain |
| Exact code installation and runtime correspondence | NOT_ESTABLISHED; bind loaded bytes, data, entry state and FFI to the required premises |
| Normal output despite resource limits | NOT_ESTABLISHED; published compiler semantics permit resource-limit trace prefixes |
| Native behavior over the full domain | NOT_ESTABLISHED; finite observations do not prove it |
| Independent review, new provenance and admission | NOT_ESTABLISHED; historical signatures do not cover this claim |
| Exact off-machine archive restore | NOT_ESTABLISHED; owner confirmation and local restores are insufficient |

Keep existing source rejection theorems and every failed exception attempt.
Do not replace the required error behavior with the observed exit0. The refund
claim remains a stateless decision and intent result, not actual payment effects.
No protected adoption, publication, merge, dispatch, release signing, admission
or deployment ran here. M1 and strict integration EXIT remain open. M2–M4 remain
later work. The full mission is unchanged.
