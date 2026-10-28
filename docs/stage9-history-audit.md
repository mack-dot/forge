# Stage 9 public history audit

Scope: the six public branch heads observed with `main` at
`9679265c326d8d630e54c728f307891e5d6422ab`. This is a read-only inspection,
not a private account-security audit. No settings, refs or workflows changed
during the inspection.

## Contributors and ancestry

GitHub returned 26 commits reachable from `main` and four more on retained
Stage 4 demo branches. All parents are present in this 30-commit set, ending
at the root. GitHub associates every author with `mack-dot`. Committers are
`mack-dot`, except the Stage 4 fee merge
`08cae1c59f6c1b40354851b422070a1edb4dc39d`, committed by `web-flow`.
GitHub reports that merge's signature as verified; the other 29 commits are
reported unsigned. No local commit-signature verification ran.

No additional contributor account appears in this history. These metadata do
not prove human authorization for every push. An unsigned commit alone does
not establish an attack.

| Retained branch | Head | Existing record |
| --- | --- | --- |
| `demo/stage4-apply-edit` | `393f80e002c8a74e6d86c52866c0be2e40688b6f` | `results/stage4/pr-1-receipt.json`; valid implementation edit. |
| `demo/stage4-unapproved-spec` | `abd148c115dc2cf0f1454fbe2682ff1112846d72` | `results/stage4/pr-2-receipt.json`; rejected spec fixture. |
| `demo/stage4-weaken-c2` | `327a33eb7e5767197d7835d3a32793de4e1dcffa` | `results/stage4/pr-3-receipt.json`; rejected C2 fixture. |
| `demo/stage4-fee-c2-revision` | `7976efaebbe5dfee8128f44b610e71c3ce21f6cf` | `results/stage4/pr-5-receipt.json`; rejected post-approval revision. |
| `stage4/approved-fees` | `0f11517d368b6a0c7d2fa78ca9d79ec563f5023c` | Parent of the documented fee merge. |

The four extra demo commits change only the implementation or spec/lock named
in those records. They change no workflow. Known rejected fixtures on demo
branches are not unexpected accepted policy changes.

## Workflow changes

Workflow-path history contains four revisions. Directory snapshots show:

| Commit | Workflow change |
| --- | --- |
| `bafcd92533034dc342c53688f058ab8cfbc577a6` | Added `toolchain-inventory.yml`. |
| `0e6d48ca008695f0c8a89965264bd62f73fbd8b2` | Added `proof-gate.yml` and `stage4-exits.yml`; inventory unchanged. |
| `8751d3fdbc2705beaeed28a492bab983271a7b1c` | Changed only `stage4-exits.yml` among workflows. |
| `9679265c326d8d630e54c728f307891e5d6422ab` | Added the two approved Stage 9 workflows; all three old workflow blobs unchanged. |

The Stage 9 workflow bytes match the exact approved manifest at
`06b40caa6bf5fb6963756b39646413559f84c61d`. Both use manual-only dispatch.
Publication was the authorized file-adoption action, not a dispatch. Public
REST returned HTTP 200 and `total_count: 0` for both provenance run lists.
No unexpected workflow change appears in this inspected history. This does
not certify every workflow's design.

## Push observations and limits

The public events endpoint returned 30 events, including 15 PushEvents.
Every returned push actor is `mack-dot`. All target `main` and name commits in
the inspected history. The events omit recent commits, including the adoption
checkpoint. They are not a complete push audit.

No returned record identifies an unexpected pusher. **Public data cannot
establish that every past push was authorized**, or rule out deleted refs,
unrecorded force pushes, deleted runs, credential misuse or another actor using
the same account. Commit authorship differs from authenticated push identity.
A full review needs the owner's private security and applicable GitHub audit
records. None was accessed.

The adoption commit was created in this authorized session with an exact tree
check and an expected-head ref update from `06b40caa6bf5...`. The remote head,
all 59 intended file blobs and preservation of unrelated blobs were verified.
The next repair is a proposal only; publication does not apply it.

## Raw records

The [preserved records](../results/stage9/receipt-repair-published/README.md)
include `history-audit/connector-history.json`, workflow snapshots, branch refs,
events, run-list responses and exact GET URLs/statuses. The connector rejected
two per-workflow endpoints with tool error 400. Those errors remain recorded;
read-only public REST then returned the actual lists. Unsupported endpoints
were never counted as zero runs. No workflow was dispatched.

Commit/workflow revisions are fixed inputs. Events and run lists are observations
at query time and can be incomplete. `end_to_end=false`.
