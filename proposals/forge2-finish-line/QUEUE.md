# Work queue (record; not an authorization to merge or to change protected files)

Updated 2026-11-19 ("Clock 2", owner word: reorder pragmatically). Each item opens its own PR from clean
`origin/main` and pauses for the owner's squash-merge. Agents never merge. `end_to_end=false`.

| # | Item | Starts when | Owner text or decision |
|---|---|---|---|
| 0 | Goal 20: `forge-airlock` SDK (`feat/zero-babysitting-sdk`) | running | `proposals/forge2-goal20-sdk/BRIEF.md` (on the Goal 20 branch until it merges) |
| 0b | T19: the hardened sink, minter and dispatcher on `main` (B-15, B-16 APPROVED); new Slice 1 bundle digest | NOW, beside Goal 20 | Clock 2, item 2 |
| 0c | Accepted-assumptions list (six physical boundaries) | NOW: draft for the owner's sign-off | Clock 2, item 1: [ACCEPTED_ASSUMPTIONS.md](ACCEPTED_ASSUMPTIONS.md) |
| 1 | F1, Goal 21: intent clearing | Goal 20 merged | [DIRECTIVE.md](DIRECTIVE.md) |
| 2 | APEX-2: Dafny to HOL4 contract link (next bounded proof step; uses the HOL slot) | Goal 20 merged; beside F1 | Clock 2, item 4; [OWNER_TEXTS.md, Text 7](../forge2-native-silicon-sink/OWNER_TEXTS.md) |
| 3 | APEX-1 and the 7-domain showcase (Fintech, Quant Risk, Healthcare HIPAA MCP, SaaS, SRE, GPU Scheduling, Robotics): the product deliverable | F1 merged | Clock 2, item 3; APEX-1 text in OWNER_TEXTS Text 7 (the 7-domain scope is new and needs a brief) |
| 4 | F2, Goal 22: Stage 9 lock PR (protected; owner merges), then a benchmark of the owner's chosen size | APEX-1 and APEX-2 merged | [DIRECTIVE.md](DIRECTIVE.md) |
| 5 | F3, Goal 23: paper, README, reproduction script | F2 merged | [DIRECTIVE.md](DIRECTIVE.md) |
| FW | FUTURE WORK, time-boxed, not blocking the release: R6 FFI (T9, estimated 7 to 12 days) and APEX-3 (WAL fold in CakeML). The APEX-3 step 3A team brief stays ready: [APEX3_STEP3A_BRIEF.md](APEX3_STEP3A_BRIEF.md) | owner's word | Clock 2, item 5 |

Note for every later gate: after T19 merges, the Slice 1 bundle has a NEW digest. "Prior bundles byte-identical"
then means identical to the bundles recorded on `main` at that gate's start, not to the pre-T19 Slice 1 bundle.
