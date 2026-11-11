# Exact refund closure installation check — U299

CURRENT stage: none. Active milestone: M1. Stage12 unauthorized.
`end_to_end=false`. M1 and integration EXIT: **NOT_ESTABLISHED**.

The exact refund program contains no `Install` operation after the published
source-to-closure pipeline, under the default ARM8 configuration. HOL checked
this statement. The result reproduces byte for byte. It is an early compiler
property. It does not prove that the native executable cannot reach its installer.

## Current claim and tracking

The immediate objective remains the approved refund R1–R5 decision/intent behavior
over the full approved integer and Unicode domain, connected to the exact native
executable under explicit assumptions. M2 admission, M3 reuse and M4 usability
remain later milestones. The fixed RISC-V example remains supporting evidence.

Use [FORGE_MISSION_STATUS.md](../../../FORGE_MISSION_STATUS.md) as the resume point.
[ROADMAP.md](../../../ROADMAP.md) records actual results.
[unsure.md](../../../unsure.md) preserves the append-only uncertainty history.
This packet records the new result, failures, exact inputs and remaining obligation.
It changes no approved specification, acceptance policy or authority boundary.

## Exact checked statement

`forge_refundClosureInstall.refund_closure_no_install` states:

```text
~closLang.has_install_list
  (SND (backend.to_clos arm8_config.arm8_backend_config
    forge_refundWholeProg.refund_prog))
```

[closure.sml](records/closure.sml) uses the existing CV translation and HOL kernel
computation primitive. It normalizes the configuration in the same way as the
published compilation driver. It adds no evaluator, semantics, axiom or verifier.
[expected.sml](records/expected.sml) checks the complete imported proposition.
The published predicate checks the complete closure syntax, including function
bodies and recursive definitions. This is not a sample-input execution test.

The exact local compiler script calls `eval_cake_compile_arm8` on `refund_prog_def`.
The published driver supplies the default ARM8 configuration, then sets a register
allocation oracle. This packet has not proved the configuration projection equality
for that oracle update. The statement above is the exact checked boundary.
The existing native digest is checked for identity only; it is not a conclusion
of this closure-language theorem.

## Executed checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run_hol.py closure-0001` | 1 | Configuration setup left an untranslated CV term |
| `run_hol.py closure-0002` | 0 | Predicate computes `F`; theorem exports |
| `run_hol.py closure-repeat` | 0 | Four exported files match byte for byte |
| `run_import.py exact-import` | 0 | Exact statement, no hypotheses or new tagged axioms |
| `run_hol.py injected-install` | 1 | Predicate computes `T`; `EQF_ELIM` refuses absence claim |
| `run_import.py wrong-program` | 1 | Exact statement mismatch for substituted program |
| `readback.py`, initial/corrected | 1/0 | Corrected error-text matcher; all evidence checks pass |
| New native/hosted run, independent full-chain replay, admission, restore | NOT RUN | No runtime or operational completion |

[COMMANDS.md](COMMANDS.md) gives the full commands, working directories, real
child exits and local elapsed durations. Those durations are observations, not
performance comparisons. Failed attempts and their original sources remain intact.

The initial proof failure is `cv_repLib.sml:119: NeedsTranslation`. Normalizing
the complete configuration resolves that setup failure. It is not a false theorem
or an adversarial rejection. The first readback expected a qualified exception
name that the log did not print. The corrected matcher checks the actual source
location and exception name. This did not change a proof or negative test.

The injected-operation control preserves the original program and prepends
`Op None Install []` to its closure code. The same pipeline computes `T` and
rejects the no-install assertion. This tests syntax rejection, not native reachability
or a well-typed installer invocation. The substituted-program control replaces
`refund_prog` with `[]` in the expected claim. It tests exact claim binding, not
a proof that the substituted program itself is unsafe.

The imported theory has one theorem. Its dependency closure contains 379 nodes
and 1888 hashed files. The only closure axioms are `bool.SELECT_AX`,
`bool.INFINITY_AX`, `bool.ETA_AX` and `bool.BOOL_CASES_AX`. The checks use the
existing pinned heap and cached `DISK_THM` parents. A fresh same-host import is
not independent full-chain source replay or authenticated evidence production.

## Remaining correspondence gap and next action

| Link | Status |
| --- | --- |
| Exact refund closure syntax, default ARM8 configuration, contains no `Install` | PROVED locally by the statement above |
| Same closure projection under the exact register-allocation configuration | Source audit supports it; checked equality NOT_ESTABLISHED here |
| Live closure values satisfy the required no-install invariant | Existing published conditional invariant; exact specialization NOT_ESTABLISHED |
| Later compiler simulations preserve absence of installer events | NOT_ESTABLISHED |
| Every formal target prefix avoids `install_pc` | NOT_ESTABLISHED |
| U298 installer-handler bridge applies to the exact refund machine | NOT_ESTABLISHED |
| Full physical entry, memory, FFI, interference, OS and resource premises | Remain open; preserve U296 correspondence matrix |

The published `clos_interpProof.evaluate_change_oracle` requires more than syntax:
it also requires its exact state relation, valid captured values and a non-type-error
evaluation. It preserves results under a specific oracle transformation. It does
not itself export target installer exclusion. The inspected lower-pass simulations
preserve behavior and state relations; matching final results or unchanged oracle
functions do not alone prove absence of calls. The native installer stub remains.

**Next smallest authorized action:** bind this exact closure fact to the actual
compiler configuration. Then use the existing compiler simulation relations to
establish the installer-event exclusion needed by U298. Preserve every live-value,
resource and runtime premise. Do not replace event exclusion with matching final
outcomes. Do not retry the stopped U290 entry proof or U297 stub proof.

This check closes one concrete input to that argument. It does not remove U296's
universal installer contract from any accepted claim. No runtime permissions or
compiler flags changed. Full-domain behavior must remain the target.

## Identity, authority and operational state

Baseline local commit: `560a76f384c0c9389239a05bfbf475d84fe939f1`.
Baseline tree: `b568e43449354d199d6995f3bc85bc48ad8b1e90`.
The current GitHub state was not refreshed during this local check.

| Item | SHA256 |
| --- | --- |
| Proof source | `5353adb2d3069820578a740c25bcb03834b6843bd73f030be1ef4ac51ce2f845` |
| Exact expected statement | `c32b2b68937a314c7b2956272845603af2c3e54e56d980f31b7644886c49ab78` |
| Exported theory `.dat` | `ec471e2565b31a90c7bb288904c83946da1ef6b5b7b90f54ed072b7e72f4fa8f` |
| Existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Pinned HOL heap | `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247` |

CakeML pin: `cd9155694c16831373ab695a670794f23282ed62`.
HOL pin: `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.
[readback.json](records/readback.json) binds 14 published source snapshots, the
local compiler script, 50 unchanged protected paths and 456 unchanged prior packet
members. Hashes identify bytes; they do not authenticate a producer.

Independent review/replay, source interpretation, authenticated new provenance
and admission remain open. The owner reports a backup on another device. Exact
required archive hashes and a restore test on that copy remain unverified.
Effective branch protections are not newly verified by this work.

Local preparation and unsigned commits remain authorized. Protected adoption,
publication, push, merge, dispatch, signing, admission and deployment retain their
approval boundaries. No Stage12, Node integration, SPM work or new infrastructure.
No hosted runtime or runner-cost measurement ran. M1/integration EXIT remains
NOT_ESTABLISHED; `end_to_end=false`.

## Packaging checks

Full staged whitespace check: actual exit2. Authored-file check: actual exit0.
The full diagnostics concern preserved upstream sources, generated proof objects
and raw logs. Their original bytes remain unchanged. See
[packaging-check.json](records/packaging-check.json). No Git whitespace setting
or verification policy changed. Each negative result remains explicit.
