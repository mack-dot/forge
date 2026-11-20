# Refresh of the 45-link assurance graph after transition T19 (2026-11-20)

CURRENT none. Stage 9 deferred. Stage 12 unauthorized.
`end_to_end=false`. **Verdict: M1-B OPEN.**

This file changes FIVE rows of
[TOP_LEVEL_GRAPH_REFRESH_20261119.md](TOP_LEVEL_GRAPH_REFRESH_20261119.md).
That file is NOT edited. Every row that is not named here stays as that
file has it. Read this file after it. This file proves nothing. A row is
only as good as the evidence named in it.

State of this file: the rows describe the tree of the branch
`feat/t19-hardened-sink` (pull request to `main`). They describe `main`
only after the owner merges that pull request. The agent did not merge.

Evidence for every row:
[the T19 report](../t19-hardened-sink-20261119/REPORT.md); `unsure.md`
U760 to U765. Classes: MACHINE-CHECKED (MC), ASSUMPTION (AS),
TESTED-UNPROVED (TU), MISSING (MI).

## Changed rows

| # | Row | Class before | Class now | What changed | What stays open |
| --- | --- | --- | --- | --- | --- |
| T19 | the hardened sink, minter and dispatcher become the merged code | NOT APPLIED | **APPLIED on the branch, TU** (on `main` after the owner's merge) | `git apply` of the two unapplied diffs: exit 0, no hunk rebased. The owner approved the changed suite expectations B-15 and B-16. Slice 1 suite: 126 rows, 0 failed; regression runner 29 of 29; control on unchanged `main`: exactly the 8 known ids fail | T19 closes at the TESTED level. The sink is not proved (U5b, T17 stay MI) |
| U2 | minter | TU (hardened minter on a branch only) | TU | the hardened minter (D-1 key file and key id, D-2 refusal rule, per-request single use) is the code of the tree. 13 key-file tests and 15 minter tests exit 0 | zero-amount squat on the real state (exit 1, stated); a lost or restored mint record; NEW: two minter processes on one memory file can each sign a token for one request id (no lock; review F1); the red team's `c24` scripts do not run after D-1; the model's inputs stay FREE (STORE-READ, G-H, KEYID-GLUE) |
| U3 | sink | TU, and KNOWN DEFECTIVE on `main` | TU; **the two duplicate-effect counterexamples are closed in the tree** (regressions X1 to X6 PASS; they FAIL on unchanged `main`) | the hardened sink is the code of the tree; database triggers refuse raw writes; a writer that drops the triggers makes the sink halt | "at most one effect per request id" for the composed system is TESTED, not proved; no migration from the merged store format; the red team's `c21` scripts do not run after D-1; `db_safeguards` (69 rows, exit 0) ran from a file that is not in the repository |
| U6 | key custody | AS | AS (unchanged class) | D-1 is the code of the tree | the key-file check covers only the last path part; same-uid attacker out of the claims |
| U7 | crash | TU for a process crash | TU for a process crash (unchanged class) | real kill, 12 rounds, exit 0 on the tree (B ran 24) | power loss NOT TESTED; exactly-once NOT claimed (a failed emit is IN DOUBT) |

Rows that do NOT change, stated because a reader can expect a change:
T17 (deployed path, MI), U5b (sink against the approved specification as a
proof, MI), U8 and T20 (rollback: AS; both anchors needed), T21 (provider:
AS; a FAKE provider in every test), T22 (power loss: NOT TESTED), T13 / X8
(the smallest missing refinement boundary on the proof side).

## Bundles after T19

Slice 1 `c7f2f41c…` to `756babc5…`. Slice 3 `3cdfebfc…` to `6b21a487…`
(one reused input, `encoding.ts`). M1 conformance `f55391da…` to
`91b49423…`. Native sink `1f569fcf…` to `f8b85b97…` (it pins the M1
conformance record). Slice 2 `2721a293…` and the Goal 20 bundle
`1e75ab47…` are unchanged. The APEX-2 package is unchanged; its graph
file `TOP_LEVEL_GRAPH_REFRESH_20261119_APEX2.md` and this file change
different rows. The binding manifest draft
(`drafts/binding-manifest/`) names the Slice 1 record by path; it was
made before T19 and is NOT refreshed here.

## Owner decisions: state after T19

B-15 and B-16: approved and applied (this pull request). Open as before:
A-1, A-2, A-3, A-5, B-12, B-13, B-14, B-17, OQ-H2-2 of B-18, B-20.
New for the owner: a lock on the mint memory file (review F1); whether
`suite.ts` texts that still say "B-15 pending" get a wording fix.
