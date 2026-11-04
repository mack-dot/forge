# Refund verified-backend investigation

CURRENT stage: none. Active milestone: M1. Stage12 remains unauthorized.
`end_to_end=false`. This is an isolated local experiment, not an accepted backend.

## Exact target and remaining link

Preserve the complete approved refund R1–R5 contract. The source domain includes
all mathematical integers, Unicode strings and response constructors. The prior
Dafny source-equivalence result remains valid. M1 still needs an exact executable
and a checked connection from that full behavior to the executable.

The current experiment uses the existing published Dafny semantics in HOL4.
It does not implement a new verifier, decoder, machine semantics or axiom.
New program ASTs and proofs are proposals, not additions to Forge's acceptance
policy. No protected implementation, policy, specification or workflow changed.

## Pinned upstream sources

| Source | Exact commit |
| --- | --- |
| [CakeML](https://github.com/CakeML/cakeml/tree/cd9155694c16831373ab695a670794f23282ed62/compiler/dafny) | `cd9155694c16831373ab695a670794f23282ed62` |
| [HOL4](https://github.com/HOL-Theorem-Prover/HOL/tree/9783a49979c94c401ff8c0e51b2eefae7ea95ae3) | `9783a49979c94c401ff8c0e51b2eefae7ea95ae3` |
| [Poly/ML 5.9.2](https://github.com/polyml/polyml/tree/4557554077078decce4ce5f90da00a713cfc32e4) | `4557554077078decce4ce5f90da00a713cfc32e4` |
| Dafny S-expression frontend, inspected only | `6eb1ed63544a2e22c151db9b575f4308b8f329b0` |

All three tool-source fetches, exact-head checks and Git object checks returned0.
Fifteen connector-fetched source files matched the exact CakeML checkout byte
for byte. `source-identity.json` records source trees and SHA256 identities.
The upstream license is retained with the source snapshots.

## Findings from actual source

1. The Dafny subset supports integers, booleans, strings, arrays and multiple
   method outputs. The primitive-field refund representation is a plausible
   method-level target. This is source inspection, not proof of full support.
   See `upstream/compiler/dafny/dafny_astScript.sml`.
2. `vc_ok_imp` connects checked method conditions to CakeML evaluation and a
   relation between resulting states. The upstream example
   `mccarthy_appreturns` exposes a method return-value theorem. This is the
   relevant route for functional behavior, not just successful termination.
   See `upstream/compiler/dafny/proofs/dafny_compilerProofScript.sml` and
   `upstream/compiler/dafny/vcg/examples/dafny_vcg_exampleScript.sml`.
3. `evaluate_program` invokes a zero-input, zero-output `Main`. `Print` checks
   the value type and otherwise does nothing in the modeled state. The source
   explicitly leaves I/O modeling open. The example driver implements printed
   output by changing an empty external function. Matching printed text does
   not establish an observable-output theorem under those definitions.
   See `upstream/compiler/dafny/semantics/dafny_evaluateScript.sml:365` and
   `upstream/compiler/dafny/examples/README.md`.
4. CakeML `mlstring` wraps HOL strings whose characters are 8-bit values.
   The approved Dafny model uses Unicode characters. A byte-string theorem
   needs a justified representation relation before it can cover all approved
   source inputs. Restricting legitimate inputs to ASCII is not permitted.
   Relevant exact sources: `basis/pure/mlstringScript.sml` in CakeML and
   `src/string/stringScript.sml` in HOL4 at the commits above.
5. The C# frontend is an unverified translation boundary. Its module/type
   restrictions and literal conversion must not be treated as a proof. The
   candidate must not choose its own checker, approved claim or expected hash.
   Inspected source is retained under `frontend/`.

The source scan found no `new_axiom`, `CHEAT_TAC`, `cheat` or `mk_oracle_thm`
tokens in the upstream Dafny SML directory. Search exit1 means no matches.
It is not a substitute for an actual theorem-tag and dependency-closure audit.

## Actual tool build

The tools were built under an isolated `.toolchain/experiments/` prefix using
the existing GMP6.3.0 installation. No global tool installation or production
gate pin changed. Darwin/arm64 host identities and linked-library output are
recorded in `built-tool-identities.json`.

| Command | Actual exit | Local wall seconds |
| --- | --- | ---: |
| Poly/ML configure, exact options in command record | 0 | 28.326 |
| `make -j2` | 0 | 150.504 |
| `make compiler` | 0 | 7.112 |
| `make install` into isolated prefix | 0 | 0.870 |
| Installed `poly --version` | 0 | 0.150 |
| `poly --script tools/smart-configure.sml` | 0 | 20.973 |
| HOL4 `bin/build` | 0 | 669.968 |

Complete commands, output and actual durations are in `tool-build/`. These
durations measure local setup, not refund verification or hosted runner cost.

## Unicode correspondence control

The original approved refund implementation accepts a valid caller ID containing
`Ā` (code point256) and preserves it in the returned intent. The actual Dafny
witness returned0:5 verified,0 errors. A proposed low-byte truncation would not
preserve that identity. Its deliberately false equality returned verifier4 with
`assertion might not hold` at the intended assertion. Both outcomes matched.

The first attempt used an escape form disabled in Dafny's Unicode mode; both
checks returned parser2. These were harness failures, not security rejections.
They remain under `unicode-witness/`. The retry uses the literal same code point
and is under `unicode-witness-0002/`. No domain or claim was weakened.
This control does not allege that the published compiler performs truncation.

## HOL4 refund experiment

The new AST implements the refund decision in the published semantics. It
retains arbitrary integers and exact byte-string IDs, reasons and outputs.
Its proof must show eligibility, all six returned fields, normal modeled return
and unchanged heap. It is a sub-obligation toward the full Unicode contract.
It cannot replace that contract or establish native behavior on its own.

The first two full-proof attempts returned1. Both checked the guard theorem,
but the full-result proof retained unresolved assignment expressions. No failed
attempt counts as a passing full theorem. Complete sources, proof states and
logs are retained under `refund_kernel/attempt-0001` and `attempt-0002`.
Attempt0003 reevaluated the expressions exposed by conditional case splits.
It returned0. A fresh repeat also returned0 after removing the local exported
outputs from the build directory and disabling build caching. Both runs report
actual execution of the theorem script. All six exported files reproduced byte
for byte. This is replay of the proof source through HOL4; the exported `.dat`
file is not a self-authenticating proof certificate.

| Check | Actual exit | Result |
| --- | --- | --- |
| `run_kernel.py 0001` | 1 | Full-result proof incomplete; preserved |
| `run_kernel.py 0002` | 1 | Same unresolved computation; preserved |
| `run_kernel.py 0003` | 0 | Guard and complete modeled return result checked |
| `run_kernel.py negative-bound ...` | 1 | Expected refusal; missing `amount ≤ remaining` premise |
| `run_kernel.py negative-reject ...` | 1 | Expected refusal; full-result goal reduced to false |
| Negative-control reason and output checks | 0 | Both intended proof failures; no accepted proof output |
| `run_kernel.py repeat-0001` | 0 | Fresh theorem execution; six byte-identical exports |
| Object byte comparison | 0 | Exact SHA256 comparison, not an inferred reproduction |
| HOL theorem/dependency inspection | 0 |112 imported theories; no unresolved parent edge |

Final proof source SHA256:
`381eeac200322362afc5436db742aed3714c72bb39cd70363336f7b7ac525dd9`.
Exported theorem data SHA256:
`8001b59be234763706df25ba09a194d707ff04d147c7e103621f6e5e04d85cd9`.
The exact propositions are `forge_refund.refund_guard_value` and
`forge_refund.refund_full_result`; see the source and `closure-audit.log`.

Both theorem tags contain `DISK_THM`, zero explicit hypotheses and no separately
tagged axioms. The complete imported theory graph includes HOL's four foundation
axioms: `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
These must remain explicit. `min` is built into the kernel; it has no separate
disk theory data file. Source references and artifact hashes are recorded in
`closure-manifest.json`. This does not adopt those foundations into Forge's
protected assurance policy. No new axiom was added by this experiment.

The trusted base includes the standard HOL4 kernel, source elaboration and
fresh rebuilding/loading of its pinned libraries, Poly/ML, GMP and the host.
Do not accept candidate-supplied theorem data merely because its hash matches
self-reported metadata. A future acceptance profile must bind trusted producer
identity and the approved exact checker/closure.

The published `dafny_to_cakemlProof` replay also returned0. Its dependency build
and proof took267.9495331249782 local seconds. The exact command and full output
are in `upstream-compiler-proof-command.json` and `upstream-compiler-proof.log`.
This checks the upstream compiler theorem. Applying it to the refund body and
then to an exact native artifact remains unfinished.

## Required next obligations

- Apply the published compiler relation to the exact method and compiled code.
- Preserve the complete Unicode input domain with a justified encoding relation.
- Use an established checked I/O/calling interface for observable results.
- Bind the exact native artifact, runtime assumptions and checker configuration
  to a separately reviewed claim/profile and authorized admission chain.

No native refund executable, hosted refund run, signing or admission has run.
Publication, protected adoption, merge, dispatch and release remain separate
approval boundaries. The overall M1 verdict remains NOT_ESTABLISHED.
