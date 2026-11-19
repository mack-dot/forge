# RUN PLAN EEx-0002 (worker A29). NOTHING HERE HAS RUN. All tactics UNCHECKED.

A = `/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001`, V = this folder.

| File | SHA-256 |
|---|---|
| `V/EEx-0002.sml` (859 lines) | `732103e1c3f85c7347748aeb266b9cd3e225a041be2eea34642a44e9e28a90a5` |
| `V/EEx-0002.vs-EEx-0001.diff` | `c19258afd10bb9738f788f0979cc3a0264a8cfb62311159181220d73d46d0942` |
| base `A/EEx-0001.sml` | `e47689d82b65429ccfa73aed632f7bf474799cdb9b31ea767cc1661b920c5458` |
| deps `A/deps-EE.txt` (129 lines, unchanged) | `a491450af990b2c0b96470fca3f343d7e70918603c6b17c745e4ecad128cb017` |

## Run (PLANNED; orchestrator only, single HOL slot)
```zsh
cd /Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cp /Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step/v4/EEx-0002.sml EEx-0002.sml
shasum -a 256 EEx-0002.sml   # must be 732103e1...90a5
./nightshift-run.sh EEx-0002 1500 deps-EE.txt ; echo "go exit $?"
grep -n "^EXPLORE_\|^VALIDATION\|^P6_\|^PRIM_RULE\|RESIDUAL_HEADS\|^LSS_LEMMA_HYPS\|^TACTIC_USED erase_\(LoadStore\|dfn_LoadStore\)\|^TACTIC_USED Run\|^TACTIC_USED Next\|^PROVED_NOT_STORED\|^DIAG_OK_UNDER\|^LEMMA_FAILED\|^STATEMENT_RESULT\|^WOULD_FAIL_LIST" EEx-0002/stdout.log | cut -c1-300
```

## Diagnosis (evidence: `A/EEx-0001/stdout.log`, sha256 c357c7a2...e5d1)
- One cause for all SP-class failures. HOL source `src/simp/src/Cond_rewr.sml` 457-463 (IMP_CANON): a rewrite whose
  antecedent is a disjunction becomes two rewrites, side conditions `~s.SCTLR_EL1.SA0` and `aligned 4 s.SP_EL0`.
  Under `DISCH_TAC` the context holds only `EL = 0w /\ (~SA0 \/ aligned 4 SP)`; neither disjunct alone is provable.
  Probe evidence: line 374 OPEN (DISCH_TAC) vs line 396-397 CLOSED, VALIDATION hyps 0 (`rpt strip_tac`).
- Statement NOT false. `erase_LoadStoreSingle/C_strip_pull` CLOSED (lines 1684-1685, VALIDATION aconv true hyps 0);
  same for LoadStorePair (3166-3167), LoadStoreAcquire (4560-4561), LoadStoreAcquirePair (6090-6091). The lemma
  attempts failed only because `e_tacs` uses `DISCH_TAC` (EEx-0001.sml line 430).
- Model: `CheckSPAlignment` runs once, on the INITIAL state, iff `n = 31w /\ memop <> MemOp_PREFETCH`
  (arm8Script.sml 1754-1760). The premise about `s` is the right premise; no intermediate-state SP premise is needed.
- Sampled residuals (A_pull_steps, 128 goals, lines 860-1083): #1 (861-883), #2, #3, #4 printed in full; #5-#8 are `F`;
  #9-#12 repeat #1-#4; the last goal (#128) was NOT printed (show_goals prints 40). Every non-F residual holds
  `CheckSPAlignment (erase s)` unrewritten. The `F` goals: probable split mismatch (every_case_tac takes different
  branches for a condition on `CheckSPAlignment (erase s)` and on `CheckSPAlignment s`). INFERENCE, UNCHECKED.
- Lines 1791 / 1873 (LSI / LSR A_steps): the goal is `LoadStoreSingle .. (erase s) = erase (..)`; the ASSUMEd LSS
  lemma has the same disjunctive antecedent. B_irule_LSS closed with hyps 1 (= the ASSUMEd LSS only).
- Line 162 (write'SP B_generic): `ARB = erase ARB` in the impossible row EL not in {0,1,2,3} (literal-case ARB
  row). Not false; A_el_split closed (95-96) and the lemma passed (TACTIC_USED erase_write_SP 3, line 261).
- Run_erase_pc / Run_pc: all 16 open leaves are the six SP-class instructions (6560-6624). Same cause.

## What the run should show (EXPECTATIONS, not results)
- `P6_COND_REWRS CheckSPAlignment_erase count 2` (two rules, one per disjunct); `CSA_imp_form count 1`.
- P1 OPEN, P5 CLOSED (controls). P3 CLOSED expected; P2, P4 OPEN expected.
- `TACTIC_USED erase_LoadStoreSingle 1`, same for dfn_LoadStoreImmediate/Register/Pair/Acquire/AcquirePair;
  `LSS_LEMMA_HYPS 0`; `TACTIC_USED Run_erase_pc 1`, `Run_pc 1`; Next chain and `NextStateARM8_erase`
  PROVED_NOT_STORED; `STATEMENT_RESULT NextStateARM8_erase hyps 0 concl_literal true`; `WOULD_FAIL_LIST` empty.
- D_pure_push: RESIDUAL_HEADS per step. If a head stays after `all_fixpoint`, that primitive lacks a rule;
  if only `srw_fallback` closes, bool_ss lacks a non-erase fact (word or pair arithmetic).
- If all this holds, the next PROOF run (EE-0001) can use `rpt strip_tac` before simp. Still UNCHECKED until run.
