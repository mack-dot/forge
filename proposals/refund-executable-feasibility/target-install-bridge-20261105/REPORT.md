# Target installation bridge — U298

CURRENT stage: none. M1 open. Stage12 unauthorized. `end_to_end=false`.
M1 and integration EXIT: **NOT_ESTABLISHED**.

A new kernel-checked bridge gives a sufficient condition for replacing only the
installer handler in the published CakeML target model. The condition has **not**
been proved for the exact refund program. The existing refund theorem, runtime,
input domain, protected policy and acceptance decision remain unchanged.

## Exact result and boundary

[bridge.sml](records/bridge.sml) contains two theorems in
`forge_targetInstallBridge`. Their exact claims appear in
[expected-complete.sml](records/expected-complete.sml).

1. `evaluate_install_irrelevant`: for a clock bound `k`, suppose every earlier
   evaluator prefix that returns `TimeOut` has a program counter different from
   `mc.install_pc`. Replacing `mc.install_interfer` then preserves the complete
   evaluator result at `k`, including its machine and FFI states.
2. `machine_sem_install_irrelevant`: when that exclusion holds for every clock,
   replacing the installer handler preserves the full `machine_sem` behavior set.
   This includes success, resource-limit outcomes, failure and divergence.

The proof uses induction over the existing `targetSem.evaluate`. It changes no
semantics, defines no new evaluator, and adds no axiom. All machine-config fields
except `install_interfer`, and the initial machine/FFI states, remain identical.
The exclusion premise concerns formal execution prefixes, not sampled debugger
observations. It is sufficient; no claim of logical necessity is made for every
possible machine configuration.

[complete-prefix.sml](records/complete-prefix.sml) proves
`forge_completeInstallExclusion.complete_prefix_suffices`:

```text
  evaluate mc ffi k ms = (Halt outcome, final_ms, final_ffi)
  AND every TimeOut prefix with j < k avoids install_pc
  IMPLIES
  machine_sem (mc with install_interfer := handler) ffi ms
    = machine_sem mc ffi ms
```

The published `evaluate_add_clock` theorem supplies the tail argument: after a
formal halt at `k`, later clocks retain that halt result. A finite prefix without
the halt equation is insufficient for this corollary. A physical process exit or
a matching projected trace does not by itself establish that formal equation.
For the approved full input domain, a single fixed-input witness is insufficient.

## Adversarial and reproduction results

| Executed check | Actual child exit | Result |
| --- | --- | --- |
| Bridge attempts1–5 | 1/-2/1/1/0 | Fifth attempt proves both statements |
| Bridge repeat | 0 | Four identical exports |
| Counterexample attempts1–4; repeat | 1/-2/1/0;0 | Existing model permits success/error under different handlers |
| Complete-prefix attempts1–4; repeat | 1/1/1/0;0 | Formal halt plus bounded exclusion is sufficient |
| Three-statement / complete four-statement import | 0/0 | All explicit claims match |
| Wrong modeled success outcome | 1 | Kernel proof leaves false subgoal `F` |
| Missing exclusion / 21-step exclusion alone | 1/1 | Exact claim mismatch: machine_sem_install_irrelevant |
| Missing formal halt from complete-prefix claim | 1 | Exact claim mismatch: complete_prefix_suffices |
| readback.py | 0 |131 closure nodes,644 hashed dependency files,10 pinned source files |
| Exact refund exclusion, native/hosted run, independent replay/admission/restore | NOT RUN | No application or authority completion |

`-2` is the child process result for SIGINT; each dispatch wrapper returned254.
These interrupted broad rewrites are not theorem rejections. They remain intact.
Bridge failures: the base needed two bounded rewrites; broad expansion was
interrupted; byte-array reader equality and induction specialization needed exact
handling. Counterexample failures: wrong qualifier, interrupted broad rewrite,
then an unreduced set-membership guard. Complete-prefix setup failures: a wrong
object path, direct `use` bypassing HOL's file preprocessing, and an unavailable
arithmetic tactic name. Existing HOL loading and an existing arithmetic lemma
resolved those issues. No theorem statement was weakened.

The [counterexample](records/counterexample.sml) is a record-valued witness in the
published generic target model. It starts at the installer entry. One handler
returns to the halt address; another returns to an invalid address. The model
returns `Halt Success` and `Error` respectively. No processor instruction executes
in this witness. It is not the refund artifact, an ARM implementation, a new
machine semantics, or a physical runtime counterexample. Its purpose is to show
that handler replacement is unsafe without a justified exclusion condition.
The three altered-claim imports test exact binding, not physical counterexamples.

All three theories reproduce four exports each. Four explicit statements import
with zero hypotheses or new tagged axioms. The complete closure retains only
`bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX` and `bool.BOOL_CASES_AX`.
These are same-host checks with cached `DISK_THM` parents. They are not a clean
independent full-chain source replay or authenticated production.

## Exact next obligation

To use this bridge for the refund executable, independently check each item:

| Obligation | Current status |
| --- | --- |
| Reference configuration satisfies U296's full conditional theorem | Conditional theorem exists; physical premises remain unresolved |
| Exact refund reference execution excludes installer entry at every clock, or through a proved formal halt | NOT_ESTABLISHED |
| Concrete configuration differs from the reference only in installer handler, with the required initial-state relation | NOT_ESTABLISHED |
| All other ARM/memory/frame/FFI/interference/OS and resource premises apply | NOT_ESTABLISHED; retain U296 matrix |
| Source frontend/shared interpretation, authenticated new claim and independent admission | NOT_ESTABLISHED |

The smallest next action is to connect the exact refund program's no-install
behavior through the existing backend simulation relations to the prefix premise
above. Reuse U297's data-oracle result where applicable. It does not itself prove
this target-level exclusion. The static installer stub remains present. Do not
retry U297's stopped five-attempt stub bundle or U290's stopped entry-layout proof.
A complete formal execution can discharge the finite corollary for its inputs;
finite native observations cannot replace that proof or the full approved domain.

This bridge offers a possible way to avoid assuming a universal physical installer
contract for an unused handler. It does not yet justify removing that contract
from the accepted refund claim. The r-x code buffer/no-EVAL concern remains.
No runtime permissions or compiler flags were changed.

## Authority and operational state

Local baseline commit: `82d3ffb8de70427cfd38e6d48d5896ab8f4a564d`.
The previous goal turn made progress. No GitHub state was refreshed here.
Fifty protected paths and the mission bytes are unchanged. All223 members of the
U296/U297 packets match their manifests. The old failed paths remain untouched.
Owner-reported off-machine backup still lacks exact archive hash and restore
verification. Effective branch protection is not newly verified by this packet.

Local proposal work and unsigned commits remain authorized. Independent review
must cover these exact statements, dependency closure and applicability before
claim adoption. Publication, push, merge, dispatch, protected adoption, signing,
admission and deployment retain their authorization boundaries. Historical release
signatures do not authorize the new claim. No Stage12, Node, SPM or new infrastructure.
No hosted duration, runner cost or savings measurement ran.

## Identity and commands

[COMMANDS.md](COMMANDS.md) records actual commands, working directories, child and
wrapper exits, and local elapsed times. Those times are observations, not benchmarks.
The exact readback is [records/readback.json](records/readback.json).

| Item | SHA256 |
| --- | --- |
| bridge.sml | `92a86e046e3f9d92ac0065c0e4f3c75e26b3f326b54a2cc71db64c5345472ea0` |
| counterexample.sml | `2650ea3ed53ec47735158b8fb81aaa19478913bdfff69bbb50a61d2677a0e86f` |
| complete-prefix.sml | `003ce4db363e896c649384aa595c662b6bc8227e6b6cb7b165400021af285bc6` |
| expected.sml | `e512b34b4fb9d177c011f2a470718fd4ab29ef67aced21e6d3e1dc804d3687bd` |
| expected-complete.sml | `f60c6ce8058e3f952ddda4652d07788b45f7e2e14972ecac8c54e506e7c0e838` |
| forge_targetInstallBridgeTheory.dat | `593eece0559495b4976b6afca7bada1dad9eca54af6fec252b06aa3b04aa602e` |
| forge_installExclusionControlTheory.dat | `b358092523138015d5b5437108d286e53981aeb6318c6aee25e12c4f0e67d6ff` |
| forge_completeInstallExclusionTheory.dat | `e188326f1a31a7683ffaeb18862d9429ce0275835cd250fe0656958f67dd64b2` |
| Exact native | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Evidence readback | `2c3289646d81dd86eac74831cba307c93b2041da93c8c73d6d92d6f2b946d332` |

Source pins: CakeML `cd9155694c16831373ab695a670794f23282ed62`;
HOL `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`. Manifest hashes identify bytes;
they do not authenticate their producer. `end_to_end=false` remains mandatory.

## Packaging

Full staged whitespace exit: 2. Authored-file check exit: 0.
Pinned upstream sources, generated exports and raw logs retain their original
bytes. The full diagnostics are in `records/packaging-check.json`. No Git rule
or evidence bytes were changed to hide these diagnostics.
