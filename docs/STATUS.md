# Where Forge is now

A one-page map for a reader who is new to the repository. It says what is done, what is in progress, what waits,
and which decisions only the owner can make. It links to the full records; it does not replace them.

Last updated: 2026-11-20, at `main` = `058eabcb` (release audit 3). The earlier version of this page described
`main` = `a5133c01` (2026-11-19).

## Formal state

- No stage is CURRENT. Stage 9 is deferred. Stage 12 is unauthorized. See [ROADMAP.md](../ROADMAP.md).
- M1-B (the refund slice from approved spec to committed effect) is OPEN.
- `end_to_end=false`. No result below changes that.
- Labels: PROVED CORE (Dafny, HOL4 or CakeML machine-checked statements only), NATIVE CHECK (unproved code that
  decides at run time), FINITE TEST, TRUSTED ASSUMPTION. The airlock engine, the native sink, the MCP proxy, the
  primitives engine and the SDKs are NATIVE CHECK and FINITE TEST: nothing proves them.
- Open questions and their history: [unsure.md](../unsure.md) (append-only).
- The idea behind all of this: [FORGE_MASTER_IDEA.md](../FORGE_MASTER_IDEA.md).

## Merged on 2026-11-20 (squash commits on `main`)

| PR | Commit | What it added | Main record |
|---|---|---|---|
| #65 | `9a9a8943` | Goal 20: the `forge-airlock` engine and the Python and TypeScript SDKs (NATIVE CHECK, FINITE TEST) | [REPORT.md](../proposals/forge2-goal20-sdk/REPORT.md) |
| #66 | `b2249ea2` | APEX-2: the Dafny and HOL4 contract link for the refund slice (translation tested, NOT machine-checked) | [README.md](../proposals/apex2-contract-link-20261119/README.md) |
| #67 | `33055a59` | Formal Ceiling v2: design and estimate only (NOT started) | [DESIGN.md](../proposals/forge2-v2-formal-ceiling/DESIGN.md) |
| #68 | `be9c1cc2` | README top and six claims corrected; licence and packaging decision note | [README.md](../proposals/review-20261120/README.md) |
| #69 | `0a84902a` | Isolation mode for the engine: design only (NOT started) | [DESIGN.md](../proposals/review-20261120-isolation/DESIGN.md) |
| #70 | `116f675f` | Gate F1: intent clearing (PROVED for the generated Dafny model only; generator trusted) | [REPORT.md](../proposals/forge2-goal21-intent/REPORT.md) |
| #71 | `c1490f92` | CI: a macOS arm64 workflow builds the engine and runs the airlock and SDK suites (FINITE TEST) | [README.md](../proposals/review-20261120-ci/README.md) |
| #72 | `cad68a5f` | Goal 21, phase 1: cosign check through `/usr/bin/ssh-keygen`, no Node (FINITE TEST) | [PROTOCOL.md](../src/airlock/PROTOCOL.md) |
| #73 | `7e5842d0` | Engine hardening: per-tenant namespaces, PENDING_COSIGN leases, ratchet rule, pin checks at every run | [README.md](../proposals/review-20261120-engine/README.md) |
| #74 | `f1d87032` | T19: the hardened Slice 1 sink, minter and dispatcher (TESTED level; owner items B-15 and B-16 applied) | [REPORT.md](../proposals/t19-hardened-sink-20261119/REPORT.md) |
| #75 | `ccdd8e5f` | Video cut: a 1-take runner and a storyboard (FINITE TEST of the engine) | [VIDEO_STORYBOARD.md](VIDEO_STORYBOARD.md) |
| #77 | `a2ef7c0a` | Archia MCP proxy (NATIVE CHECK, FINITE TEST) | [PROTOCOL.md](../src/mcp_proxy/PROTOCOL.md) |
| #78 | `e9e30a64` | ROADMAP repair: two sections restored | [ROADMAP.md](../ROADMAP.md) |
| #79 | `058eabcb` | V1.1 universal primitives pack (NATIVE CHECK, FINITE TEST; PROVED only for the named Dafny models) | [PROTOCOL.md](../src/primitives_v2/PROTOCOL.md) |

Merged on 2026-11-19: #59 (`b9f2831c`), #62 (`6d66a558`), #63 (`a5133c01`), #64 (`e2b8ba1d`).

How much of the chain is proved, assumed, tested, or missing:
[TOP_LEVEL_GRAPH_REFRESH_20261119.md](../proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261119.md), with
the rows that T19 changed in
[TOP_LEVEL_GRAPH_REFRESH_20261120_T19.md](../proposals/m1b-mission-20261119/TOP_LEVEL_GRAPH_REFRESH_20261120_T19.md).

## Open

- **#76**, Gate F2a: the Stage 9 lock rebind (protected files; needs the owner's exact approval). Stage 9 stays
  deferred until the owner decides.

## Waiting

1. Gate F2, Goal 22: after #76, a benchmark whose size the owner chooses.
2. Gate F3, Goal 23: the paper, a "Forge for Dummies" text and a one-command reproduction script. None of the
   three is on `main`.

The full text: [DIRECTIVE.md](../proposals/forge2-finish-line/DIRECTIVE.md).

## Known record gaps

- The tracked Goal 20 bundle record (`proposals/forge2-goal20-sdk/records/evidence.json`, `1e75ab47…`) is of the
  tree of #65. Later merges (#68, #72, #73) changed 20 of its 64 subject files, so it does not reproduce on
  `main`. No newer Goal 20 bundle is tracked.
- The Archia MCP proxy (#77) and the primitives pack (#79) have no committed bundle record; their EXIT tables
  are in [ROADMAP.md](../ROADMAP.md) only.

## Decisions only the owner can make

The list with exact proposed changes: [OWNER_REQUIRED.md](../proposals/night-shift-20261119/OWNER_REQUIRED.md).
B-15 and B-16 are approved and applied (#74). Items that no record shows as closed, among others:

- **B-3**: protect `main` and remove the owner's admin credential from agent sessions.
- **A-3**: the FFI premise of the machine-model theorem.
- A lock on the mint memory file (T19 review F1): two minter processes on one file are not excluded.
- The Goal 20 bundle record: refresh it or keep it as the record of #65.
- The isolation mode of the engine (#69 is a design; the build is NOT started).
- A licence ([decision note](../proposals/review-20261120/DECISION_NOTE_LICENCE_PACKAGING.md)).

## How work moves here

- Agents open pull requests. The owner reviews and merges every one. The hosted proof gate reports exit 3 on new
  claims. `main` has no branch protection (the GitHub API answers 403 for this private repository on its present
  plan; graph link E2 and blocker 5), so "only the owner merges" is a working rule, not an enforced one.
- Every result names its status: MACHINE-CHECKED, ASSUMPTION, TESTED-UNPROVED, or MISSING.
