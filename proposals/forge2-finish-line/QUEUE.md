# Work queue after Goal 20 (record; not an authorization to merge or to change protected files)

Updated 2026-11-19. Each gate opens its own PR from clean `origin/main` and pauses for the owner's squash-merge.
Agents never merge. `end_to_end=false`.

| # | Gate | Starts when | Owner text |
|---|---|---|---|
| 0 | Goal 20: `forge-airlock` SDK (`feat/zero-babysitting-sdk`) | running | `proposals/forge2-goal20-sdk/BRIEF.md` (on the Goal 20 branch until it merges) |
| 1a | APEX-3 step 3A ONLY: read-only design and wall-time estimate for the WAL fold in HOL4/CakeML (item F2.7); stops before `cake_compile` | Goal 20 merged; runs alongside gate 1 | Owner word 2026-11-19: "yes queue it and get a team of subagents ready for it"; brief: [APEX3_STEP3A_BRIEF.md](APEX3_STEP3A_BRIEF.md) |
| 1 | F1, Goal 21: intent clearing | Goal 20 merged | [DIRECTIVE.md](DIRECTIVE.md) |
| 2 | APEX-1: MCP `stdio` airlock | F1 merged | [OWNER_TEXTS.md, Text 7](../forge2-native-silicon-sink/OWNER_TEXTS.md) |
| 3 | APEX-2: Dafny to HOL4 contract link, Profile A | APEX-1 merged | same |
| 4 | APEX-3 step 3B: prove, compile, torture-test | APEX-2 merged AND the owner's budget word on the 3A design | same |
| 5 | F2, Goal 22: Stage 9 lock PR (protected; owner merges), then a benchmark of the owner's chosen size | APEX-3 merged | [DIRECTIVE.md](DIRECTIVE.md) |
| 6 | F3, Goal 23: paper, README, reproduction script | F2 merged | [DIRECTIVE.md](DIRECTIVE.md) |

Order source: the APEX text places APEX-1 to APEX-3 after F1 and before F2. The only change is row 1a, on the
owner's word: step 3A (no `cake_compile`, no proof run) moves forward to run beside F1.
