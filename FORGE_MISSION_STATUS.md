# Forge mission tracker

Mission: [FORGE_MISSION.md](FORGE_MISSION.md), preserved byte for byte from the
owner's attachment. SHA256:
`7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c`.

CURRENT repository stage: **none**. Stage12 is unauthorized. `end_to_end=false`.
Active milestone: **M1 — executable behavioral correctness**.
This tracker uses the new mission's M1–M4 definitions. Older roadmap milestone
labels remain historical and must not be treated as the current priority order.

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

Next authorized action: apply the published Dafny-to-CakeML compiler relation
to the exact refund body now checked in HOL4. The upstream compiler proof replay
returned0. Its application to refund is still open. Preserve the full Unicode
domain through a justified representation relation and use a checked calling
or I/O interface. Upstream modeled `Print` does not establish observable output.

Detailed claim, source hashes, commands and boundaries:
[M1 experiment report](proposals/refund-executable-feasibility/README.md).

New backend results:
[HOL4 experiment report](proposals/refund-executable-feasibility/verified-backend-20261104/REPORT.md).
The guard and complete return result pass in the published Dafny model for
arbitrary integers and byte strings. Both implementation violations are refused.
A fresh rebuild produces six byte-identical exports. The approved Unicode
contract is unchanged and is not yet connected to this model or native code.

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

## Current repository and supporting evidence

Live main: `f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
Tree: `624ef75c46cdd260b39308763cfdf27ed8ba99e5`.

| PR | Exact head | Current state |
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
| Refund compiler/binary/runtime correspondence | NOT_ESTABLISHED | Published compiler proof replay passed; application to refund, full Unicode relation, exact native artifact and runtime relation remain open |
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

## Current backend checks

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
relation. The upstream compiler theorem has not yet been applied to this body.
No native executable behavior or new authenticated admission is established.
The imported HOL foundation axioms are SELECT_AX, INFINITY_AX, ETA_AX and
BOOL_CASES_AX. No new axiom was introduced. This experimental checker and
closure are not adopted into Forge's protected acceptance policy.

Detailed records and reproduction instructions are in the linked backend
packet. All durations are local observations. Hosted refund metrics are NOT RUN.

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
