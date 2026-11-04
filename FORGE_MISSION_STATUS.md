# Forge mission tracker

Mission: [FORGE_MISSION.md](FORGE_MISSION.md), preserved byte for byte from the
owner's attachment. SHA256:
`7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c`.

CURRENT repository stage: **none**. Stage12 is unauthorized. `end_to_end=false`.
Active milestone: **M1 — executable behavioral correctness**.
This tracker uses the new mission's M1–M4 definitions. Older roadmap milestone
labels remain historical and must not be treated as the current priority order.

## Start here

Use this file for the current decision and unfinished work. Keep the full
instructions in [FORGE_MISSION.md](FORGE_MISSION.md), actual command results in
[ROADMAP.md](ROADMAP.md), and unresolved findings in [unsure.md](unsure.md).
Update these records after each experiment. Link each completed item to its
evidence. Keep failed attempts and mark work that has not run as `NOT RUN`.

## Current native FFI checkpoint — U285

[Two complete native captures and model-check status](proposals/refund-executable-feasibility/ffi-observation-20261104/REPORT.md).
Both captures return the expected output and exit0. All38 byte comparisons pass.
Each observed read/write returns to its saved address and preserves x19–x28/SP.
These are finite observations; the complete runtime relation remains unproved.

**Next:** poll existing model checker91810 and compiler proof47239. Both are live;
neither has a terminal proof result. The first model attempt failed1 on syntax.
The corrected attempt preserves the required equations. Its two negative controls,
reproduction and independent import remain NOT RUN. Do not start duplicate jobs.
Keep U284's source-event/initialization work separate. Complete-chain replay,
review, new provenance/admission and exact off-machine restore remain open.
M1 and strict integration EXIT remain NOT_ESTABLISHED. `end_to_end=false`.

## Entry-state checkpoint — U283

[Loaded-entry evidence](proposals/refund-executable-feasibility/entry-capture-20261104/REPORT.md)
now records three accepted captures. Loaded code and bitmap bytes match HOL
artifacts; each process returns the expected fixture output and exits0. Hardware
breakpoints are confirmed after launch. All34 recorded register values match
before/after the full-map inspection. Four adjacent rw- VM regions cover the
512MiB heap/stack span. These are finite observations, not complete correspondence.

| Priority | Smallest next action | Current evidence and remaining condition |
| --- | --- | --- |
| 1 | Finish the existing compiler behavior invocation | Runner47209/Holmake47239 live; no terminal theorem; inspect actual premises, then controls/reproduction |
| 2 | Connect applicable source/model and runtime conditions | Entry payloads and scalar bounds observed; full Unicode/model, physical control state, FFI/OS, resources and exit relations remain open |
| 3 | Complete concrete exception initialization and event replay | U284 all-oracle error/STDIO/event theorem PROVED under explicit premises; basis extraction and exact refund_prog initialization remain |
| 4 | Independently replay and review the exact complete claim | Full-chain replay and approved new assumption/profile still required |
| 5 | Bind authenticated Forge evidence and operational readiness | Upstream debugger provenance alone is insufficient; new admission authority and independent-copy hash/restore remain open |

All previous failures remain: three old debugger launch crashes, later read-only
crash diagnostics, a bitmap-address capture error and decoder-window failure.
The corrected capture source reproduces; altered captured code and wrong upstream
source identity are refused. No global tool installation or new service was added.
No protected policy change, executable rebuild or signing occurred.
M1 and strict integration EXIT remain NOT_ESTABLISHED. `end_to_end=false`.

## Historical action list — U279

The immediate objective remains one complete refund executable assurance chain.
The fixed RISC-V ELF is supporting evidence. M2 admission, M3 reuse and M4
usability remain later priorities. This checklist records completion criteria;
it does not grant approval or mark future commands as executed.

| Order | Next action | Current state | Completion evidence required |
| --- | --- | --- | --- |
| 1 | Finish the existing compiler behavior proof | IN_PROGRESS; runner47209 and Holmake47239 confirmed live | Actual terminal exit, exact theorem and every premise; then binding controls and reproducible exports |
| 2 | Resolve the concrete entry-observation failure | NOT_ESTABLISHED; three LLDB crashes, child -10 each | Isolate symbol-parser failure before another launch; preserve exact executable; capture and validate loaded state |
| 3 | Complete the exception proof on its separate branch | BLOCKED by builder EPERM; U278 | Identify and resolve the denied operation without bypass, then check the frozen repaired source |
| 4 | Close or explicitly bound the remaining correspondence gaps | NOT_ESTABLISHED | Full source/Unicode/model relation, installed memory, runtime/FFI/OS, resources and exit; no silent domain restriction |
| 5 | Independently replay and review the complete claim | NOT RUN for the complete chain | Clean replay, exact dependency closure, negative controls and independent claim/profile review |
| 6 | Complete operational and admission requirements | NOT_ESTABLISHED | Independent-copy archive hashes plus restore; authorized new provenance and admission; refresh protections at approval boundary |

[Latest observation report](proposals/refund-executable-feasibility/entry-observation-20261104/REPORT.md)
preserves the failed commands, numeric exits, identities and limitations.
No entry state or native process exit was recorded. A target-open diagnostic
passes0, but it executes no target. Saved-record readback passes0 after one
preserved diagnostic error1. The native executable and30 frozen inputs match.
The live compiler has no terminal proof result. Strict integration EXIT remains
NOT_ESTABLISHED. `end_to_end=false`; no Stage12 or policy change is authorized.

Latest proof result: **U284 — error contract to all modeled source behaviors PROVED**.
The [source semantics report](proposals/refund-executable-feasibility/exception-semantics-20261104/REPORT.md)
retains the exact event trace, FFI transition relation, exception value and
consumed-stdin postcondition for every pointer oracle. The declaration, lookup,
input/error and initial heap premises remain explicit. Logical Success is not
OS exit0. The final proof, replay and fresh import return0/0/0; four exports match.
An incorrect empty-trace target fails1. The closure has245 nodes, seven checked
theorems and four existing foundation axioms;1458 parent files match.

**Next at U284:** prove the [basis event extraction obligation](proposals/refund-executable-feasibility/exception-semantics-20261104/records/NEXT-OBLIGATION.md)
and discharge exact refund_prog initialization. That experiment is NOT RUN.
Physical runtime/FFI/resources/exit and independent complete-chain replay stay
NOT_ESTABLISHED. No approved specification or trace requirement changed.

Previous proof result: **U282 — exception declaration theorem PROVED**.
The [declaration report](proposals/refund-executable-feasibility/exception-declaration-20261104/REPORT.md)
records the unchanged theorem, direct substitution diagnosis and all failures.
Fresh standard-heap proof/repeat/import return0/0/0. Four exports match. The
wrong normal-result control fails1. The imported closure has244 nodes and the
four existing bool foundation axioms;1454 prior dependency files match.
No new semantic premise or axiom was added. U278's denied Holmake invocation
remains preserved; the already-used direct HOL interface checks the theorem.

**Next:** lift the exception declaration result to deterministic source semantics
and its FFI relation. Then establish all pointer oracles and initialized stdio.
Whole-program error, physical native execution and independent complete-chain
replay remain NOT_ESTABLISHED. `end_to_end=false`.

Previous proof diagnosis: **U278 — lookup lemma proved; full repair blocked by EPERM**.
The [focused exception report](proposals/refund-executable-feasibility/exception-focused-20261104/REPORT.md)
records the exact remaining case expression and its unused equality. A standalone
universal HOL lemma passes0. The full repaired statement is unchanged, but its
builder exits1 before theorem checking with Operation not permitted. No theory
export exists. All five prior failed checks and both heaps remain preserved.

**Next:** identify/resolve the denied builder operation within an authorized
environment, then check the frozen repaired source. Do not retry without that
change. The separate compiler behavior run retains its existing owner.
`end_to_end=false`. Native, whole-program error and independent replay claims
remain incomplete. No native rebuild, signing or protected change occurred.

Previous compiler audit: **U277 — closure checked; runtime premises mapped**.
The [detailed premise matrix](proposals/refund-executable-feasibility/arm8-assurance-audit-20261104/REPORT.md)
records every direct entry, memory, FFI, interference, resource and exit condition
of the proposed compiler composition. Fresh imported closure inspection passes0:
378 nodes,377 theory file sets,10 own tags and four foundation axioms. A separate
readback confirms2265 files unchanged. This is not a full independent replay.
The initial interrupted audit remains preserved.

**Next for this proof branch:** finish the original compiler behavior build,
then inspect its exact conclusion and run binding controls/reproduction.
The process remains live; no terminal proof exit is available. Physical ARM
control registers, loaded-state installation, universal runtime contracts and
full-domain resource sufficiency remain NOT_ESTABLISHED. The generic compiler
theorem permits resource-limit output prefixes. The exception diagnostic branch
below remains separate; no blind sixth full-lemma retry is authorized.

Previous native checkpoint: **U276 — exact native file payload and execution evidence checked**.
The [assurance matrix](proposals/refund-executable-feasibility/native-execution-20261104/REPORT.md)
classifies each claim as PROVED, TESTED, ASSUMED or NOT_ESTABLISHED. It retains
all compiler/runtime premises and exact hashes. `end_to_end=false`.

| Latest check | Actual exit | Evidence boundary |
| --- | --- | --- |
| Native link driver / two28-case drivers | 0;0/0 | Same exact signed file;56 finite executions, all exit0 |
| Corrected HOL extraction / embedded byte comparison | 0/0 |130436 code bytes and2531 bitmap words match both files |
| Fresh signature checks / code-byte mutation controls | 0/0;1/1 | Local integrity checks; no producer authentication |
| Chain-input readback | 0 |2727 files;378-node compiler closure;108 runtime inputs;50 protected files unchanged |
| Exception inspection | 0 | Residual declaration/heap goals only; no accepted theorem |

**Next smallest check:** trace the remaining declaration branch one existing
rewrite at a time. The exact prepared script is NOT RUN. Preserve U274's five
failures; no new full-lemma attempt is authorized by the diagnostic itself.
Finish the separate already-live compiler behavior composition without duplication.

**Blockers:** concrete loaded-state installation, actual linker/dyld dependency
identity, FFI/OS input/output and exit refinement, resource sufficiency, exception
whole-program behavior and full source-to-HOL binding. Clean independent replay
of the complete chain remains NOT RUN. Existing same-host copies/imports do not
satisfy that independence requirement. Stage12 stays unauthorized.

Previous checkpoint: **U275 — exact ARM64 compilation reproduced**.
The [compiler record](proposals/refund-executable-feasibility/arm8-compile-20261104/REPORT.md)
contains the actual equation, commands, complete hashes and open premises.
The compile and repeat both exit0. Six exported files and the assembly match.
This is a compilation result. The separate compiler behavior proof is running.
Its terminal exit and conclusion are not yet established.

| Latest check | Actual exit | Evidence boundary |
| --- | --- | --- |
| ARM64 compile / repeat | 0/0 | Exact compilation equation; six identical exports and assembly |
| Compiler identity validation | 0 | Both archives, live outputs, mission and30 frozen inputs checked |
| Separate native build / repeat, inspected here | 0/0 | Same executable SHA256b8ed5ec2; no universal native theorem |
| Separate native fixture runs, inspected here | 0/0 |22 typed outputs match; six malformed inputs also exit0 with no output |
| Native stream readback | 0 |84 streams match across both runs; malformed error contract remains open |
| Closure inspection / compiler behavior proof | IN_PROGRESS | Actual invocations started; no terminal exit available |

**Next:** finish the existing compiler behavior invocation. Inspect its exact
conclusion and installation, FFI and resource premises. Then check adversarial
bindings and reproduction. Do not start another copy of either live process.
Canonical records:
`results/refund-arm8-compile-2026-11-04/attempt-0001/`.

**Separate rejection gap:** U274 preserves three failed source builds and two
failed saved-goal diagnostics. No exception-to-main theorem was accepted.
[Failure evidence](proposals/refund-executable-feasibility/exception-bridge-20261104/REPORT.md).
Stop retries on that lemma under the five-check limit. The prior canonical-input
source theorem and application-level rejection theorems remain intact.
Do not treat the six observed malformed-input exits0 as proof of error behavior.

**Existing source result:** U271 proves the complete modeled output for canonical
typed requests under explicit source-environment premises. Its six exports
reproduce. Wrong entry substitution fails1. Fresh closure inspection covers243
theory nodes and four existing foundation axioms. The
[whole-program report](proposals/refund-executable-feasibility/whole-program-20261104/REPORT.md)
and [fixture report](proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md)
retain the exact claims. U273's live-compiler status is a historical checkpoint,
now superseded by the completed compile records.

Keep the full Unicode/source/model binding, malformed-input whole-program
path, resource bounds, code installation and physical I/O explicit. Native
observations are now available from the separate audit; full native correctness
is NOT_ESTABLISHED. Hosted refund measurements and new admission remain NOT RUN.
The separate task retains its limited U269 local signing authority.
Independent claim/profile review and exact off-machine archive hash/restore
remain open. Publication, protected adoption, release signing, merge and dispatch
require corresponding authority. M1 and strict integration EXIT remain open.

Previous checkpoint: **U270 — modeled I/O checked; five mutations refused**.
The [I/O contract record](proposals/refund-executable-feasibility/stdio-contract-20261104/REPORT.md)
contains the full output/error contracts, exact commands, five required theorem
failures and byte-identical wire/I/O repeats. Fresh closure inspection covers230
nodes with the same four foundation axioms. All30 frozen inputs remain unchanged.

**Next at U270:** complete the running whole-program source-semantics build, then check
entry substitution and reproduction. Its final result is not established at
this checkpoint. Native compilation/execution and new admission remain NOT RUN.
Keep Unicode, resource, installation, physical I/O and runtime premises explicit.
Modeled exceptions and checker exit codes do not establish native exit status.
U269 preserves the separate audit thread's local signing approval and its limits.

Previous checkpoint: **U268 — wire dispatcher checked; I/O proof incomplete**.
Parent local commit: `9b9747c6e3c7523b330898370a9ebba144ff9a2a`.
The [wire/I/O record](proposals/refund-executable-feasibility/wire-library-20261104/REPORT.md)
preserves the successful wire build and all three failed I/O builds. Seven
wire/dispatcher theorems checked locally. No I/O theory was exported. The new
wire repeat, adversarial controls and closure audit remain `NOT RUN`.
Saved evidence and 30 unchanged protected inputs were checked for this update.

**Next at U268:** inspect the saved third `refund_main_valid` goal. Identify the remaining
premise before another build. Then complete I/O, adversarial controls, positive
reproduction and the whole-program/compiler relation. Native execution remains
`NOT RUN`. The full mission and all prior failed results remain preserved.

| Latest saved check, U268 | Actual exit | Meaning |
| --- | --- | --- |
| `run.py wire-0001` | 0 | Strict wire computation and dispatcher proofs; six exports |
| `run_stdio.py stdio-0001/0002/0003` | 1/1/1 | I/O proof incomplete; no accepted export |
| HOL diagnostics 1/2/3/4 | 1/1/1/0 | Last result inspects subgoals only |
| `readback.py` | 0 | Saved records, identities and 30 frozen inputs checked now; no proof rerun |
| Effective rules / ruleset list / ruleset details | 0/0/0 | Saved read-only exports expose required review controls |
| Classic branch-protection endpoint | 1 | HTTP 404; active ruleset still applies |

The saved effective rules require one review, code-owner review, last-push
approval, stale-review dismissal and resolved threads. They contain no required
status-check or workflow rule. No setting or bypass was used. Main remains
`f9eb1cbc` in this snapshot; PRs 34/36/37 are open and unmerged. Review objects
were not fetched. Independent backup hash/restore remains unverified.

Previous checkpoint: **U267 — proposed full library contract checked and reproduced**.
Parent local commit: `341afa16e43b3783be3ac39136dfe403b35926a9`.
The [certified-library proposal](proposals/refund-executable-feasibility/certified-library-20261104/REPORT.md)
uses the existing translator. It proves the complete six-field result's relation
to the original method and a library application contract. Two new mutations
are refused. A repeat produces six identical exports. The proposal is not
adopted into the actual wrapper. Complete I/O and native correspondence remain open.
The [earlier normalization record](proposals/refund-executable-feasibility/normalisation-20261104/REPORT.md)
and the third diagnostic in the new packet preserve all incomplete attempts.
The new [guard/prefix record](proposals/refund-executable-feasibility/tail-guard-20261104/REPORT.md)
preserves exact theorems, controls, failures and the checked CF applicability gap.
The prior [wrapper record](proposals/refund-executable-feasibility/native-io-20261104/REPORT.md)
retains the original uncaught mutation; its historical exit is unchanged.
The [runtime audit](proposals/refund-executable-feasibility/native-audit-20261104/REPORT.md)
is separate. Neither establishes native refund behavior. Publication has not run.

| Required assurance link | Tracked status | Evidence or completion condition |
| --- | --- | --- |
| Approved refund R1–R5 and source equivalence | LOCALLY_VALIDATED | [Source report](proposals/refund-executable-feasibility/README.md); full approved domain retained |
| Full return behavior in the published model | LOCALLY_VALIDATED | [Model proof](proposals/refund-executable-feasibility/verified-backend-20261104/REPORT.md); byte strings, mathematical integers and explicit trusted base |
| Exact generated expression and modeled caller | LOCALLY_VALIDATED | [Compiler relation](proposals/refund-executable-feasibility/compiler-relation-20261104/REPORT.md) and [caller proof](proposals/refund-executable-feasibility/caller-20261104/REPORT.md); all six fields checked |
| Full Unicode representation | LOCALLY_VALIDATED at source | [UTF-8 proof](proposals/refund-executable-feasibility/unicode-20261104/REPORT.md) preserves emptiness, exact reasons and ID round trips; native/model assurance binding remains open |
| Complete wire schema and model input/output binding | LOCALLY_VALIDATED at model level | [Schema proof](proposals/refund-executable-feasibility/io-schema-20261104/REPORT.md); full consumption, round trips and four adversarial controls |
| Actual wrapper input/output tuple patterns | LOCALLY_VALIDATED for matching only | [Wrapper proof](proposals/refund-executable-feasibility/native-io-20261104/REPORT.md); nested decoder pairs and flat method result checked; six identical repeat exports |
| Actual rejection guard and prefix namespace | LOCALLY_VALIDATED, conditional | [Guard/prefix proof](proposals/refund-executable-feasibility/tail-guard-20261104/REPORT.md); nonempty remainder raises the required error and preserves references/FFI under explicit entry conditions; guard removal and binding substitution refused |
| Proposed alternative library method | LOCALLY_VALIDATED; not adopted | [Complete contract](proposals/refund-executable-feasibility/certified-library-20261104/REPORT.md); all nine typed inputs and six result fields; original-method relation and CF frame contract checked |
| Proposed wire dispatcher | LOCALLY_VALIDATED | [Wire/I/O controls](proposals/refund-executable-feasibility/stdio-contract-20261104/REPORT.md); strict refusal, all six fields, three mutations and identical repeat |
| Proposed modeled I/O | LOCALLY_VALIDATED; not adopted | [I/O contract](proposals/refund-executable-feasibility/stdio-contract-20261104/REPORT.md); exact stdout and exception contracts, two mutations and identical repeat |
| Whole-program initialization and source semantics | LOCALLY_VALIDATED; not adopted | [Whole-program proof](proposals/refund-executable-feasibility/whole-program-20261104/REPORT.md); exact main, initialization, canonical input and complete modeled output; wrong-entry refusal and identical repeat |
| Exact ARM64 compile theorem | LOCALLY_VALIDATED | [Compilation record](proposals/refund-executable-feasibility/arm8-compile-20261104/REPORT.md); equation checked and six exports plus assembly reproduced |
| Compiler behavior preservation | IN_PROGRESS | Published compiler-correctness composition started; no terminal proof result |
| Frozen native fixture expectations | LOCALLY_VALIDATED | [Fixture proof](proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md); 22 typed cases, six malformed inputs, exact bytes and two refusal controls; separate native observations now recorded in U275 |
| Native input/output and exact executable | TESTED; universal relation NOT_ESTABLISHED | U275 reads two identical executables and repeated22-case typed output observations; six malformed-input exits0 do not establish the error contract |
| Runtime and concrete/model relation | NOT_ESTABLISHED | Establish applicable entry and execution conditions; disclose every environment assumption |
| Independent checking and reproduction | LOCALLY_VALIDATED for current model proofs | Extend the checked closure, reproduction and adversarial controls to the same native artifact |
| New authenticated claim and independent admission | NOT_ESTABLISHED | Independently review the exact claim/profile and authorize provenance/admission; historical signatures do not cover it |
| Operational readiness | NOT_ESTABLISHED | Effective rules visible in saved U268 export; exact independent-copy archive hashes and restore still missing; refresh controls at the relevant approval boundary |

The actual guard now has a conditional rejection theorem. Its unchanged
guard-removal mutation fails1. The actual main-call prefix and its namespace
bindings are checked; replacing the remainder binding also fails1. All three
new proof theories reproduce six identical exports each. The earlier U264
matrix failure remains a historical record. Actual stdin execution, the method
heap/frame contract and the accepted-output path are still unproved.

The raw method's CF obstacle remains. Three normalization attempts were
interrupted. The third completed annotation removal but not normalization.
The new route uses the existing translator's checked function relation instead.
It does not assume that normalization preserves behavior. Its explicit relation
covers the original method's complete output for every typed model input.
It is not arbitrary contextual equivalence or an adopted wrapper replacement.
The U270 modeled I/O contracts and U271 whole-program source theorem now pass
and reproduce. The unsigned ARM64 compiler build is running. Keep all input,
output and refusal obligations. Native execution remains NOT RUN. M1 is open.
M2 follows sufficient M1 evidence. M3/M4 stay deferred. Stage12 remains unauthorized.

| Recorded executed check, U267 | Actual exit | Boundary |
| --- | --- | --- |
| Third normalization diagnostic | 1 | Manual SIGINT after annotation removal; no accepted candidate |
| Library attempts0001–0004 / final | 1/1/1/1 / 0 | Import and Boolean representation proof failures preserved; complete final contract checked |
| Altered amount / swapped wrapper IDs | 1/1 | Required theorem failures; no accepted exports |
| Positive repeat / control dispatcher | 0/0 | Six identical exports and both refusal reasons checked |
| Fresh closure inspection / saved-record readback | 0/0 | 192 theory nodes, four foundation axioms;30 frozen inputs unchanged |
| Dependency snapshot attempts1/2/final | 1/1/0 | Loader-location mistakes fixed;191 theory file sets plus kernel/heap identities recorded |

These are local proof and identity checks. No native or hosted experiment ran.
The new proposal needs independent review and an approved assurance binding.

| Recorded checks, U266 | Actual exit | Boundary |
| --- | --- | --- |
| Candidate construction / instrumented construction | 1/1 | Manual SIGINT; no accepted AST, theory or behavior claim |
| Diagnostic process sample | 0 | No precise internal cause established |
| Initial / corrected record validation | 1/0 | Manifest filename fixed;30 protected inputs and329 prior packet members unchanged |

These checks do not rerun the prior proof matrix. Exact commands, sources and
failure records are in the linked normalization packet. No new assurance link
is complete. The mission and previous uncertainty entries remain unchanged.

| Recorded proof check, U265 | Actual exit | Boundary |
| --- | --- | --- |
| Guard attempts0001/0002/0003 | 1/1/1 | Two manual interruptions and one wrong theory qualifier preserved |
| Guard proof / repeat | 0/0 | Six identical exports; explicit clock/environment conditions |
| Removed-tail-check control / control dispatcher | 1/0 | New rejection theorem refuses the unchanged mutant |
| Entry attempt0001 / entry proof | 1/0 | Large closure expansion stopped; checked generic call lemma resolves it |
| Remainder-binding substitution / entry repeat | 1/0 | Intended namespace failure; six identical positive exports |
| CF applicability proof / repeat | 0/0 | Raw match-value premise is impossible; not a refund behavior failure |
| Fresh HOL closure inspection | 0 |231 nodes; eight own theorems; four existing foundation axioms |
| Record/source/postflight checks | 0 | Exact results and30 unchanged protected inputs; parent restored byte for byte |

Exact argv, logs, theorem statements and hashes are in the guard/prefix packet.
The wrapper source remains `44ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22`.
Hosted refund measurements and new provenance/admission remain NOT RUN.

## Current decision

Selected feasibility target: the existing refund decision component and its
complete approved R1–R5 contract. Its decision is stateless. Ledger and booking
also require reasoning about maps, retry state and state transitions. This makes
refund the smaller first experiment; it does not prove backend feasibility.
The GCD self-test remains supporting evidence, not the real-component target.

Highest-priority missing link: a checked connection between the selected
component's approved behavioral specification and its exact executable.
Current feasibility verdict: **BLOCKED_BY_CORRESPONDENCE**.
The approved refund source check passed. A new primitive-field representation
also passed a universal source-equivalence check, repeat check and negative
controls. No compiled refund artifact has a checked behavioral guarantee yet.
The full domain remains mathematical integers, finite strings and every response
constructor, with no new precondition. This is not a bounded toy replacement.

Next authorized action: complete the running ARM64 compiler build and inspect
its actual theorem and output identities. The whole-program source theorem,
wire and modeled I/O contracts pass, including their controls and repeats.
The original wrapper remains unchanged. Then establish compiler correctness
and the physical input/output boundary. The full Unicode/UTF-8 source
representation now passes. A particular model caller initializes and returns
all six values correctly for every typed model input. The exact native artifact,
runtime correspondence and admission binding remain open. Preserve the full
domain; upstream modeled `Print` does not prove observable output.

Detailed claim, source hashes, commands and boundaries:
[M1 experiment report](proposals/refund-executable-feasibility/README.md).

New backend results:
[HOL4 experiment report](proposals/refund-executable-feasibility/verified-backend-20261104/REPORT.md).
The guard and complete return result pass in the published Dafny model for
arbitrary integers and byte strings. Both implementation violations are refused.
A fresh rebuild produces six byte-identical exports. The approved Unicode
contract is unchanged and is not yet connected to this model or native code.

New compiler relation:
[conditional behavioral proof](proposals/refund-executable-feasibility/compiler-relation-20261104/REPORT.md).
Exact compilation equality, static premises and six CakeML output values are
checked. Final proof/repeat0/0; substituted compiled expression1 for the intended
equality failure. This is a conditional model theorem, not native correctness.

New caller result:
[entry and returned-tuple proof](proposals/refund-executable-feasibility/caller-20261104/REPORT.md).
Universal model-caller proof/repeat0/0; swapped IDs/missing argument1/1 for
the intended failures. Standard primitive initialization plus explicit typed
input bindings now produces the correct tuple. Native input decoding is open.

New source representation result:
[UTF-8 transport proof](proposals/refund-executable-feasibility/unicode-20261104/REPORT.md).
All Unicode strings map injectively to published UTF-8 byte representations.
Empty strings, approved reason equality and ID round trips are checked. The
full refund source behavior is preserved under this relation. Final/repeat0/0;
accepted-ID substitution, over-limit authorization and original truncation4/4/4.
The received conditional transport source was reverified with the library.
This is Dafny/Boogie/Z3 source verification, not a new HOL or native theorem.

## Milestone completion ledger

| Milestone | Current verdict | Required evidence before completion |
| --- | --- | --- |
| M1: executable behavior | NOT_ESTABLISHED | Approved nontrivial claim; exact component executable; applicable proof and correspondence; independent checking; reproduction and negative controls |
| M2: independent admission | NOT_ESTABLISHED | New target's authenticated evidence; independent ADMIT/REJECT/UNSUPPORTED decisions; exact artifact binding; no candidate-controlled authority |
| M3: continuous verification | NOT_ESTABLISHED for the selected target | Frozen supported corpus; safe reuse; execution actually skipped; correct invalidation; fresh-baseline equivalence; adversarial refusal |
| M4: independent developer use | NOT_ESTABLISHED | Clean developer reproduction; usable diagnostics; frozen benchmark and measured costs; no private-workspace dependency |

Existing hosted booking reuse and historical Stage9 admission are supporting
results. They do not automatically satisfy M2/M3 for a new executable claim.
M3/M4, general caching, interface work and new infrastructure remain deferred.

## First-action ledger

| Mission step | State | Evidence or next check |
| --- | --- | --- |
| Preserve and read the mission | DONE; exit0 | `results/mission-m1-feasibility-2026-11-04/attempt-0001/mission-preservation.json` |
| Inspect current main, PR34/36/37 and hosted booking run41523691535 | DONE | Live main and PR identities refreshed; held artifact hash matches live GitHub digest; historical results inspected |
| Audit ledger/refund/booking specifications and implementation | Source audit DONE; backend audit OPEN | Refund source gate rerun: exit0; protected inputs unchanged |
| Compare established executable-verification routes | IN PROGRESS | Exact CakeML/HOL4/PolyML sources pinned; tools built; model proof passes; Unicode and observable-output boundaries identified |
| Select target and freeze the exact claim | DONE for feasibility | Full approved refund R1–R5; no new input restriction; no new acceptance profile |
| Run the smallest component feasibility experiment | DONE: source step only | Primitive-field implementation equals original decision and intent for every typed input; Dafny exit0 |
| Run negative and reproducibility controls | DONE for source step | Repeat0, over-limit4, always-reject4; expected proof errors; identical positive output |
| Issue decisive feasibility verdict | BLOCKED_BY_CORRESPONDENCE | Source equivalence is checked; compiler/binary/runtime relation is missing |
| Connect sufficient M1 evidence to M2 | NOT RUN | Requires corresponding exact approvals and fresh authorized provenance |

## Recorded repository snapshot and supporting evidence

Main at the recorded GitHub inspection:
`f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
Tree: `624ef75c46cdd260b39308763cfdf27ed8ba99e5`.
The documentation update did not refresh GitHub. These identities and PR states
are recorded observations, not a claim about the current remote state.

| PR | Recorded exact head | State at inspection |
| --- | --- | --- |
| [34](https://github.com/mack-dot/forge/pull/34) | `46e5aa426bf7800df7c98c732a764337e716f6bb` | Draft, open, unmerged; historical booking experiment candidate |
| [36](https://github.com/mack-dot/forge/pull/36) | `705457e069abbe399128808b1efc7242d8eaeaa1` | Open, unmerged; keep upload repair separate |
| [37](https://github.com/mack-dot/forge/pull/37) | `fc85ecc2c7f12caa6c8991fa002410bdf78dd51d` | Draft, open, unmerged; fixed-ELF model theorem |

The latest eight PRs returned by GitHub were 37 through 30. This read does not
establish approval. No review, merge or workflow operation was performed.

| Capability | Classification | Supported scope and remaining boundary |
| --- | --- | --- |
| Original refund source contract | LOCALLY_VALIDATED | Fresh Dafny/Z3 source proof and existing rejection controls passed; compiler and runtime remain outside this proof |
| Primitive-field refund equivalence | LOCALLY_VALIDATED | Every typed input maps to the same decision and intent; Dafny/Boogie/Z3 remain trusted; no independent kernel certificate |
| Refund behavior in published HOL4 Dafny model | LOCALLY_VALIDATED | Guard, six returned fields and unchanged modeled heap; arbitrary integers and byte strings; fresh source replay and negative controls passed; Unicode and native transfer remain open |
| Ledger and booking source claims | LOCALLY_VALIDATED, historical | Existing source evidence retained; not a new executable theorem or new source replay in this iteration |
| Fixed GCD executable model theorem | LOCALLY_VALIDATED, historical | Exact old ELF and kernel replay records retained; not a refund theorem or full QEMU/Linux correspondence |
| Hosted authenticated booking reuse | TESTED, historical | Actual authorized run and 13 cases; same-process reuse only; no cross-run claim |
| Stage9 signed release/admission | TESTED, historical | Authenticates its original artifact and claim; does not authorize the new refund claim |
| Refund body to CakeML expression | LOCALLY_VALIDATED | Exact compilation equality and six output fields checked under explicit state/environment premises; retained unchanged |
| Exact generated method and model caller | LOCALLY_VALIDATED | Primitive state/constructors and typed input bindings are explicit; fixed call returns all six values for every typed model input; negative controls and repeat pass |
| Refund Unicode/UTF-8 source relation | LOCALLY_VALIDATED | Full-domain representation, inverse, exact reasons and source refund transport checked; no upstream wrapper axiom imported |
| Refund binary/runtime correspondence | NOT_ESTABLISHED | Checked physical calling/output interface, exact native artifact, source/model assurance binding and runtime relation remain open |
| Refund acceptance profile and release chain | NOT_ESTABLISHED | Need exact reviewed claim, checker, artifact/environment binding and authorized independent admission |

Hosted run [41523691535](https://github.com/mack-dot/forge/actions/runs/41523691535)
executed on November 2. This iteration inspected its records, not a new run.
Artifact13179905102 SHA256:
`372cd7781b1be493a13bbd4398cb6871cbf2effe6458810425dd25fcf49efbf1`.
Cold/warm/invalidation exits were 0/0/0; verifier launch counts were 1/0/1.
Recorded wall times were 28.525340852/9.931031468/28.552900072 seconds.
All 13 acceptance cases matched, including uncovered-change exit3 and
prior-process receipt exit1. These records contain no billed runner-minute
measurement. They do not establish a performance improvement or M3 for refund.

## Prior source checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Mission attachment byte/hash comparison | 0 | Full Markdown copy matches the attachment |
| `python3 -B scripts/exit_stage_8.py --case wrapper-proof` | 0 | Original source proof0; over-limit/reject-all gate1 with verifier4; forbidden assumption gate1 |
| Dafny `verify Bridge.dfy` with included files and pinned Z3 | 0 | Full source equivalence; 7 verified, 0 errors |
| Same verification in a fresh directory | 0 | Same source hashes and byte-identical verifier output |
| Removed amount upper bound | 4 | Expected postcondition failure |
| Always-reject implementation | 4 | Expected postcondition failure; non-vacuity retained |
| `python3 -B .../flat-bridge/run_controls.py` | 0 | Repeat and both negative controls matched explicit expectations |
| Initial Dafny audit invocation | 2 | Harness error: expected report file was missing; preserved |
| Audit using the existing zero-findings report baseline | 0 | Zero findings; no source or rule weakened |

No compiled refund proof, hosted refund execution or new admission ran.
The exact commands, raw outputs and hashes are in the linked experiment packet.
These checks do not complete a repository stage or M1.

## Backend checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Pinned Poly/ML and HOL4 local builds | 0 | Isolated tools built from exact source commits |
| Initial Unicode witness/control | 2/2 | Parser failures preserved; not passing negative controls |
| Corrected Unicode witness/truncation control | 0/4 | Full domain includes U+0100; low-byte identity claim rejected |
| HOL refund full-result attempts0001/0002 | 1/1 | Incomplete proof states preserved |
| HOL refund attempt0003 / fresh repeat | 0/0 | Guard and full modeled return checked; six identical exports |
| Removed-bound / always-reject model controls | 1/1 | Intended theorem failures; reason checks0 |
| Imported closure audit | 0 |112 theory nodes, four explicit HOL foundation axioms |
| Published Dafny-to-CakeML compiler proof replay | 0 | Actual source replay;267.9495331249782 local seconds |
| Frozen input hash postflight | 0 |30 original inputs unchanged |
| Local raw-archive validation | 0 |118 members checked; independent copy remains unverified |

The model theorem covers arbitrary integers and byte strings. It is one
sub-obligation toward the full approved Unicode contract, not a replacement
contract. The manually constructed AST still needs a checked representation
relation. The later compiler result below applies to this exact model body.
No native executable behavior or new authenticated admission is established.
The imported HOL foundation axioms are SELECT_AX, INFINITY_AX, ETA_AX and
BOOL_CASES_AX. No new axiom was introduced. This experimental checker and
closure are not adopted into Forge's protected acceptance policy.

Detailed records and reproduction instructions are in the linked backend
packet. All durations are local observations. Hosted refund metrics are NOT RUN.

## Compiler-relation checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run.py 0001` | 1 | Static proof left a trivial quantified goal; preserved |
| `run.py 0002` | 0 | Exact compiler relation checked |
| `run.py 0003` / `0004` | 1/1 | Projection name error and unresolved substitutions; preserved |
| `run.py 0005` / `final` | 0/0 | All six fields transferred; final source removes an unused bound variable |
| `run.py substitution ...` | 1 | Compiled-expression substitution refused at equality proof |
| `run.py repeat` / acceptance comparison | 0/0 | Fresh theorem execution; six identical exports; intended refusal checked |
| HOL closure inspection | 0 |139 theory nodes; nine own theorems; same four explicit foundation axioms |
| Initial input postflight | 1 | Compared the owner baseline against a different Git worktree; error retained |
| Postflight against original owner workspace | 0 |30 frozen inputs unchanged |

Premises of this earlier conditional theorem: the initializer and CakeML state satisfy `state_rel`; the
environments satisfy `env_rel`. They include clocks, heap/reference mapping,
namespace entries, constructor stamps and callable closures. The proof does
not itself construct a complete caller. The later caller theorem below checks
a particular model caller directly. Both use the internal compiler
Return convention. Observable API behavior and physical process exit are open.
All results are local. No hosted refund, signing or admission command ran.

## Current caller checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run.py 0001` | 1 | Universal proof incomplete; inconsistent conditional-Boolean case retained |
| Concrete valid-call diagnostic | 0 | Correct example tuple; does not replace universal proof |
| `run.py 0002` | 1 | Manually interrupted broad rewrite; child signal2; not an accepted result |
| `run.py 0003` | 0 | Universal method/caller result proved with narrow checked Boolean equalities |
| `run.py swapped-ids ...` | 1 | Caller ID equality obligation fails |
| `run.py missing-argument ...` | 1 | Missing input binding makes the return claim false |
| `run.py repeat` / acceptance comparison | 0/0 | Actual replay; all six exported files identical; refusal reasons checked |
| Fresh HOL closure inspection | 0 |156 theory nodes; three own theorems; same four foundation axioms |
| Original-input postflight | 0 |30 owner-workspace hashes unchanged |

This caller theorem checks the generated method and explicit initialization
directly in the existing semantics. It does not prove the earlier generic
`env_rel` premise for arbitrary callers. Its fixed program receives typed
values in a constructed namespace. A physical input decoder and native calling
interface remain unverified. Clock32 is model fuel, not a runtime bound.
The full approved Unicode contract remains unchanged. No restricted-domain
replacement, policy adoption, publication or release occurred.

## Current Unicode source checks

| Command/check | Actual exit | Result |
| --- | --- | --- |
| Character/scalar attempts0001–0004 | 4/4/4/4 | Resource failures preserved |
| Character/scalar attempt0005 | 0 | No-axiom conversion and scalar inverse checked |
| Sequence attempts0001/0002 | 4/0 | Explicit sequence types/map facts close the new obligations |
| Transport attempts0001/0002 | 4/0 | Full representation premises discharged |
| Final / fresh repeat | 0/0 |1426 assertion batches;30 identical input files and identical symbol outcomes |
| Unconditional / accepted-only ID substitution | 4/4 | Rejected output / accepted caller identity fail at the respective postcondition |
| False over-limit authorization / original truncation | 4/4 | Exact intended assertions refused |
| Dafny audit / acceptance readback | 0/0 | Zero findings; negative reasons checked |
| Local raw archive validation | 0 |848 members checked; no off-machine claim |

The approved Unicode domain remains intact. Source proof SHA256:
`804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990`.
The existing UTF-8 algorithms are unchanged. The axiom-bearing upstream
character wrapper is excluded; new checked lemmas supply the needed relation.
No protected source or policy changed. Native and hosted refund results remain
NOT RUN. Exact logs and trust limits are in the linked UTF-8 packet.

## Evidence record requirements

Every experiment must record source revision, approved contract and assumptions,
executable digest, exact checker command, actual numeric exit, proof identity,
dependency closure, decision/reason and reproduction instructions. Expected
outcomes must stay separate from actual results. An infrastructure error cannot
count as a successful negative control.

Capability inventory entries must use ESTABLISHED, TESTED, LOCALLY_VALIDATED,
PROPOSED, UNSUPPORTED or NOT_ESTABLISHED. Each established proposition must name
its exact artifact, method, closure, trusted base, assumptions, independent
reproduction status and remaining boundary. Do not use module counts as success
criteria. Preserve the more precise diagnostic reason behind each refusal.

## Approval and operational ledger

- Protected changes, independent review, publication, merge, dispatch, signing,
  release and deployment keep their existing exact approval boundaries.
- Local commit permission persists. The new mission itself grants no new
  publication or signing authority.
- Draft publication of the old fixed-ELF supplement at81255521 is pending.
  It is not a prerequisite for a separate authorized component feasibility test.
- The owner reports a backup on another device. Exact archive hashes and a
  restore from that independent copy remain unverified. Local bundles and local
  restore tests do not close that requirement.
- Last recorded protection inspection found independent review controls, no
  required status checks/workflows, and classic protection HTTP404. This
  iteration did not refresh those exports or change any protection settings.
- Preserve `unsure.md` by append only. Keep actual execution results in
  `ROADMAP.md`. Never rewrite old failures or expand an old signature's scope.

The mission's M3 paragraph ends with the literal fragment
`Report actual authentication overhead a--`. The attachment is preserved exactly;
no missing requirement is inferred from that fragment. This does not block M1.

## Iteration log

2026-11-04: Saved the complete mission and started the current-state/contract audit.
This is progress toward durable tracking, not mission or milestone completion.

2026-11-04: Refreshed repository identities and inspected hosted evidence. Reran
the approved refund proof. Checked full source representation equivalence,
repeatability and two adversarial controls. Preserved the audit harness failure.
Selected refund for the next correspondence experiment. M1–M4 remain open.

2026-11-04: Built the pinned published tools. Checked refund model behavior,
two implementation violations, fresh proof reproduction and imported assumptions.
Replayed the published compiler theorem. Recorded the Unicode and observable
output gaps. The next implementation step is the exact refund compiler relation.

2026-11-04: Applied the compiler theorem to the exact refund body and transferred
all six result fields. Final source/repeat0/0; substituted expression refused1.
Recorded139-node closure and preserved all failed attempts. Entry/calling, full
Unicode, native and admission obligations remain open. Parent report commit:
`d0269c051390ffe76b41ba1e522568870f3a4f83`, local and unpublished.

2026-11-04: Checked the generated refund method and a fixed model caller for all
typed model inputs. Preserved one incomplete proof and one manual interruption.
Swapped IDs and missing binding each fail1; valid proof/repeat0/0. Exact caller
and return behavior are now checked in the model. Full Unicode and native
interfaces remain open. Parent compiler record commit77ab7003 is local only.

2026-11-04: Added the compact assurance-link checklist requested by the owner.
Rechecked the saved mission identity and local research records. Clarified which
GitHub observations are historical and which caller premises remain open.
No new proof, hosted execution, publication or admission ran in this update.

2026-11-04: Checked the full Unicode/UTF-8 source relation and composed it with
the unchanged refund behavior. Preserved resource/proof failures and the first
substitution diagnostic. The targeted accepted-ID attack now fails the correct
identity postcondition. Final/repeat0/0; audit0; independent native/model binding
and release admission remain open. Separate transport record:73728c2, local only.


### Mission tracking preservation — actual local results

Local commit: `118b3d4d331ce513c92e1de3ee2cd9298572aa48` on
`docs/integration-readiness-20261103`. Commit exit0; staged whitespace check0;
committed readback0 for the exact mission and45 packet files; worktree clean.
The commit is local and unpublished. No research stage completed.

Local recovery bundle create/verify/clone-restore/fsck each returned0:
`/Users/mackianni/forge-backups/forge-mission-2026-11-04.bundle`.
SHA256 `d68852a498467f02fb1c8a6b841f60742da46a723b133546c00ee66688e237c1`.
24404340bytes; mode0600. Restored commit and mission bytes matched.
This is local recovery, not verification of the owner's off-machine copy.
Command records: `results/mission-m1-feasibility-2026-11-04/attempt-0001/`.


### Local native execution approval and independent audit — U269

The owner approved the local ad-hoc signature required to run the eventual
macOS arm64 refund executable in the resumed audit thread. That thread owns
local linking/signing and native controls under this approval. Release signing,
publication, deployment, protected changes and Stage12 remain unauthorized.
No native signing or execution has run; end_to_end=false.

[Follow-up audit](proposals/refund-executable-feasibility/native-audit-followup-20261104/REPORT.md),
local commit3c5bb8ca, preserves the approval scope and candidate identity/control
readback0. It does not constitute fresh independent kernel replay or release
admission. Whole-program/compiler, native runtime and actual executable controls
remain open. Native process exit codes require their own checked bridge.


## Independent native fixture evidence — U272

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
[Fixture report](proposals/refund-executable-feasibility/native-fixtures-20261104/REPORT.md).

| Check | Actual exit | Scope |
| --- | --- | --- |
| Pinned direct HOL batch / repeat | 0/0 |22 typed cases and44 identical byte files |
| Malformed-wire batch | 0 |Six exact error cases; no native exit claim |
| Wrong expected amount / swapped IDs | 1/1 |Required proof refusals |
| Corrected closure / record readback | 0/0 |229 nodes,228 theory file sets, four foundation axioms |
| Committed packet readback | 0 |300 files at32e3613d; local, unsigned, unpublished |

Initial library loading1, control preparation1, absent-script dispatch1 and
closure qualifier1 remain preserved. The standard direct HOL route does not
resolve or erase the earlier Holmake permission failures. No native executable
control or signature has run. Next: exact arm8 compiler/artifact binding, then
captured native I/O controls. Keep all runtime, resource, Unicode/model,
error-status and independent-assurance gaps explicit.
