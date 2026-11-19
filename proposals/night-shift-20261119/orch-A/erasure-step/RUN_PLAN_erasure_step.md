# Run plan: ARM8 step erasure, case ES-0001 (worker A11). NOTHING HERE HAS RUN.

Every command below is PLANNED. No exit code in this file is an actual exit code. Run it only in the single HOL slot,
by the orchestrator, after the usual resource check (`nightshift-run.sh` does it: swap, memory, battery, other HOL).

E = `/Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step` (source)
A = `/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001` (attempt folder; runner, deps, E1-0003 parent)

## Inputs (SHA-256, measured by A11 with `shasum -a 256`, exit 0)
| File | SHA-256 |
|---|---|
| `E/erasure_step_v1.sml` | see the worker report (the file changes digest on any edit; re-measure before the copy) |
| `A/deps-L1.txt` (125 lines) | `76bcd4909e81f7fc9a11144996e5b2f530e240afdb0cf62096aeff2e0209cc90` |
| `A/E1-0003/.hol/objs/forge_m1bErasureV2Theory.sig` | `a00181034f8d732c634e7ea7d98329c5bed89c65f3ae3d10509b04a43a9fb1d8` |
| `A/E1-0003/.hol/objs/forge_m1bErasureV2Theory.sml` | `b8ccbd128f5df1f28eb346a28fcef9813071fcdbe503f1162294499ca0338c93` |
| `A/E1-0003/.hol/objs/forge_m1bErasureV2Theory.dat` | `cf4c757a1036d3fbab7526f65035ab205172f0799cd129a5d4267dbc2fe6165e` |
The three E1-0003 digests are equal to `A/E1-0003.run.json` "objects". The parent `.sml` loads its `.dat` from its own
folder (`OS.Path.base (#(FILE)) ^ ".dat"`), and it opens `forge_refundSlideProfileATheory` (last theory of deps-L1).

## Setup (once)
```zsh
E=/Users/USER/forge/results/night-shift-20261119/orch-A/erasure-step
A=/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001
cd $A
cp $E/erasure_step_v1.sml ES-0001.sml
cp deps-L1.txt deps-ES.txt
print -r -- "$A/E1-0003/.hol/objs/forge_m1bErasureV2Theory.sig" >> deps-ES.txt
print -r -- "$A/E1-0003/.hol/objs/forge_m1bErasureV2Theory.sml" >> deps-ES.txt
wc -l deps-ES.txt                      # expected 127
shasum -a 256 $E/erasure_step_v1.sml ES-0001.sml deps-ES.txt
```

## Run (CPU limit 1500 s; the script stops all proof work at 1250 s script CPU, OPTIONAL work at 1100 s)
```zsh
cd $A && ./nightshift-run.sh ES-0001 1500 deps-ES.txt ; echo "go exit $?"
```
Expected time (guess, not a result): load about 110 s; stages W+S0 under 60 s; F 200-600 s; E1+E2 100-400 s;
E3 the rest of the budget.

## Pass markers (all are required for a REQUIRED pass; none is a result until it is in `ES-0001/stdout.log`)
- actual exit 0;
- `EXACT_COMPLETE`;
- no line `REQUIRED_FAILED_LIST`, no `UNEXPECTED_CONTROL_ACCEPTANCE`;
- `PROVED W_nonvacuous`, `PROVED Next_frame` and `CONTROL_OK Next_frame is the literal E1-0003 statement`;
- `PROVED NextStateARM8_frame`, `PROVED BranchImmediate_erase_untagged`, `PROVED BranchRegister_erase_untagged`,
  `PROVED erase_LoadStoreSingle`, `PROVED B1_dfn_BranchImmediate` (and the other 9 B1_/B2_ lines);
- `CONTROL_OK C1 is a proved negative`, `CONTROL_OK C2 is a proved negative`;
- exactly four `CLOSURE_AXIOM bool.*` lines.
Extra marker for the OPTIONAL whole-model stage: `FULL_E_COMPLETE` (else `FULL_E_NOT_COMPLETE` and
`OPTIONAL_FAILED_LIST` lines; that is a partial result, not a failure of the REQUIRED part).
Diagnostic lines to read on failure: `FOR_ind` (the printed shape of the induction theorem), `CASE_RAND_COUNT`,
`RULE_COUNTS`, `DEF_NAMES 130`, `FRAME_LEMMAS <n>`, `TACTIC_ATTEMPT_FAILED`, `TACTIC_TIMEOUT`, `LEMMA_FAILED`,
`DIAG_OK_UNDER`, `CPU_SECONDS_SCRIPT`.

## Mutant control (run only after ES-0001; short CPU limit on purpose)
The mutant makes the witness statement false (`SA0 /\ ~SA0`). Expected: `LEMMA_FAILED W_nonvacuous` within the first
minutes; no `EXACT_COMPLETE`; exit not 0 (either the final gate, or the CPU limit at 400 s). Any `PROVED W_nonvacuous`
in the mutant is a harness defect.
```zsh
cd $A
python3 -I -c 'import sys;s=open("ES-0001.sml").read();a="s.SCTLR_EL1.SA0 /\\ untagged t";assert s.count(a)==1;open("ESneg-0001.sml","w").write(s.replace(a,"s.SCTLR_EL1.SA0 /\\ ~s.SCTLR_EL1.SA0 /\\ untagged t"))'
diff ES-0001.sml ESneg-0001.sml        # expected: exactly one changed line (the W_text line)
./nightshift-run.sh ESneg-0001 400 deps-ES.txt ; echo "go exit $?"
grep -n "LEMMA_FAILED W_nonvacuous\|PROVED W_nonvacuous\|EXACT_COMPLETE" ESneg-0001/stdout.log
```

## After the run
Record the actual exit code, the markers, and `CPU_SECONDS_SCRIPT` in the orchestrator STATE table. Do not edit
ES-0001.sml in place; a repair is a new file (`erasure_step_v2.sml`) and a new case number.
