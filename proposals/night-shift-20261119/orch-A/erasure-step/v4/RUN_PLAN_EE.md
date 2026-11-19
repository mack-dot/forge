# RUN PLAN EE-0001 (worker A29). NOTHING HERE HAS RUN. Every tactic UNCHECKED as a stored proof.

| File | SHA-256 |
|---|---|
| `v4/erasure_step_v5.sml` (659 lines) | `931c0d4c0cd8fb1c1b9a3541ba4ead1058d334f0442b227dcbbe614f0f0daf05` |
| `v4/erasure_step_v5.vs-EEx-0002.diff` | `d2d712702c3a10d5a36cc099caf8e838219f58898da62e807974b0ddac7c2c40` |
| base `v4/EEx-0002.sml` | `732103e1c3f85c7347748aeb266b9cd3e225a041be2eea34642a44e9e28a90a5` |
| deps `A/deps-EE.txt` (129 lines) | `a491450af990b2c0b96470fca3f343d7e70918603c6b17c745e4ecad128cb017` |

## Run (PLANNED; orchestrator only, single HOL slot)
```zsh
cd /Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/mackianni/forge/results/night-shift-20261119/orch-A/erasure-step/v4/erasure_step_v5.sml EE-0001.sml
shasum -a 256 EE-0001.sml   # must be 931c0d4c...daf05
./nightshift-run.sh EE-0001 1500 deps-EE.txt ; echo "go exit $?"
grep -n "^EXACT_COMPLETE\|^REQUIRED_FAILED_LIST\|^UNEXPECTED\|^CLOSURE_AXIOM\|^STORED_\|^CONTROL_\|^CHECKED\|^LEMMA_FAILED\|^DIAG_OK_UNDER\|^TACTIC_ATTEMPT_FAILED\|^STATEMENT_RESULT\|^OLD_TEXT\|^NEW_TEXT" EE-0001/stdout.log | cut -c1-200
grep -c "^PROVED " EE-0001/stdout.log   # expected 101
```

## Pass markers (expectations, not results)
actual exit 0; `EXACT_COMPLETE`; no `REQUIRED_FAILED_LIST`, `LEMMA_FAILED`, `DIAG_OK_UNDER`, `UNEXPECTED_CONTROL_ACCEPTANCE`;
exactly 4 `CLOSURE_AXIOM`; `STORED_THEOREMS 101`; `STORED_DEFINITIONS 1` (NX_def); 101 `PROVED` lines;
8 `CHECKED` lines; 5 `CONTROL_OK` lines; 2 `CONTROL_NOT_ATTEMPTED` lines;
`STATEMENT_RESULT NextStateARM8_erase hyps 0 concl_literal true`.
Expected `TACTIC_ATTEMPT_FAILED`: none (used tactics are first). Any `TACTIC_USED <name> 2+` = a replay deviation.
