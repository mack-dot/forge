# Where Forge is now

A one-page map for a reader who is new to the repository. It says what is done, what is in progress, what waits,
and which decisions only the owner can make. It links to the full records; it does not replace them.

Last updated: 2026-11-19, at `main` = `a5133c01`.

## Formal state

- No stage is CURRENT. Stage 9 is deferred. Stage 12 is unauthorized. See [ROADMAP.md](../ROADMAP.md).
- M1-B (the refund slice from approved spec to committed effect) is OPEN.
- `end_to_end=false`. No result below changes that.
- Open questions and their history: [unsure.md](../unsure.md) (append-only).
- The idea behind all of this: [FORGE_MASTER_IDEA.md](../FORGE_MASTER_IDEA.md).

## Recently merged (2026-11-19)

| PR | What it added | Main record |
|---|---|---|
| #59 | Night shift, proof track: HOL results on the ARM64 refund path | [MORNING_REPORT.md](../proposals/night-shift-20261119/MORNING_REPORT.md) |
| #62 | Goal 19: native silicon sink (std-only Rust, `F_FULLFSYNC` WAL, CakeML refund binary) | [REPORT.md](../proposals/forge2-native-silicon-sink/REPORT.md) |
| #63 | Goal 19 records: hosted results of #62 | [ROADMAP.md](../ROADMAP.md) |
| #64 | Night shift, consolidated: Dafny models, red-team re-tests, refreshed 45-link graph | [integration/README.md](../proposals/night-shift-20261119/integration/README.md) |

How much of the chain is proved, assumed, tested, or missing:
[TOP_LEVEL_GRAPH_REFRESH_20261119.md](../proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md).

## In progress

- **Goal 20: the `forge-airlock` developer SDK** (branch `feat/zero-babysitting-sdk`, no PR yet). A Python and
  TypeScript SDK that puts the checked refund, inventory and state-machine rules in front of an app's writes, plus
  a tenant check on reads, a dropped-work detector, and a fuzzer. The demo runs eight classic AI coding mistakes
  against it. Each result will say whether it rests on a proved core, a native check, or a finite test.

## Waiting (in this order)

1. Goal 20 PR: the owner reviews and merges it.
2. Gate F1, Goal 21: intent clearing (boundary tables, solver queries checked by Dafny, a blind restatement of
   the spec).
3. Gate F2, Goal 22: the Stage 9 lock PR (protected files; the owner merges it), then a benchmark whose size
   the owner chooses.
4. Gate F3, Goal 23: the paper, the README, and a one-command reproduction script.

The full text of 2–4: [DIRECTIVE.md](../proposals/forge2-finish-line/DIRECTIVE.md).

## Decisions only the owner can make

The list with exact proposed changes: [OWNER_REQUIRED.md](../proposals/night-shift-20261119/OWNER_REQUIRED.md).
The largest items:

- **B-15, B-16**: changed expectations in the Slice 1 suite. Without them the merged suite stops (exit 2) on the
  hardened sink, so the sink fixes are still UNAPPLIED diffs and `main` keeps the older sink.
- **B-3**: protect `main` and remove the owner's admin credential from agent sessions.
- **A-3**: the FFI premise of the machine-model theorem.

## How work moves here

- Agents open pull requests. The owner reviews and merges every one. The hosted proof gate reports exit 3 on new
  claims and blocks the merge button, so no agent can merge.
- Every result names its status: MACHINE-CHECKED, ASSUMPTION, TESTED-UNPROVED, or MISSING.
