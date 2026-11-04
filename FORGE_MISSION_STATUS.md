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

Next authorized action: check the published verified Dafny-to-CakeML pipeline's
exact source, supported representations and reproducible build path against this
full contract. Check integer, string and input/output semantics before choosing
that route. Do not treat ordinary Dafny compilation as verified compilation.

Detailed claim, source hashes, commands and boundaries:
[M1 experiment report](proposals/refund-executable-feasibility/README.md).

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
| Compare established executable-verification routes | IN PROGRESS | Verified Dafny/CakeML publication found; exact artifact and representation support still need checks |
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
| Ledger and booking source claims | LOCALLY_VALIDATED, historical | Existing source evidence retained; not a new executable theorem or new source replay in this iteration |
| Fixed GCD executable model theorem | LOCALLY_VALIDATED, historical | Exact old ELF and kernel replay records retained; not a refund theorem or full QEMU/Linux correspondence |
| Hosted authenticated booking reuse | TESTED, historical | Actual authorized run and 13 cases; same-process reuse only; no cross-run claim |
| Stage9 signed release/admission | TESTED, historical | Authenticates its original artifact and claim; does not authorize the new refund claim |
| Refund compiler/binary/runtime correspondence | NOT_ESTABLISHED | No selected verified backend, exact compiled artifact or checked runtime relation yet |
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

## Executed checks in this iteration

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
