# Route A run plan (worker X7, step C1 preparation). NOTHING HERE HAS RUN.

All commands below are planned. No exit code in this file is an actual exit code.
Run one HOL process at a time. Do not start while another HOL job holds the slot.

X = `<session scratch folder>/m1b/X7`
S = `<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001` (the folder where e4-0001 and imp4-0001 ran)
A = `<HOME>/forge/results/m1b-routeA-20261119/attempt-0001` (new; `results/` is untracked in git)

## 0. Order

| # | Case | Source | Deps file | CPU estimate | CPU limit (4x, rounded) |
|---|---|---|---|---|---|
| 1 | `L1-0001` | `routeA-L1.sml` | `deps-L1.txt` = copy of `S/deps-imp4.txt` (125 lines; ends with the e4-0001 theory) | 150 s (imp4-0001 used 100 s CPU only to load the same parents; e4-0001 used 127 s) | 600 |
| 2 | `L1imp-0001` | `routeA-L1-imp.sml` | `deps-L1imp.txt` = `deps-L1.txt` + the two L1 theory lines | 120 s | 600 |
| 3 | `L2-0001` (only if 1 and 2 have exit 0) | `routeA-L2.sml` | `deps-L2.txt` = `deps-L1imp.txt` | 400 s (load 110 s; `Define` of the copy of `evaluate`; an induction with case splits over every branch of `evaluate`) | 1600 |

Start case 1 first (the owner's order: "beginning with `refund_ffi_contract_at_totalise`"; in my files that lemma is
`refund_ffi_contract_on_totalises`, see STATEMENTS.md S-L1).

## 1. Before each run (resource check, memory first)

```zsh
memory_pressure | tail -1            # need >= 25 % free (run_case.py refuses below 25 %)
sysctl vm.swapusage                  # record; project memory note: re-measure disk and swap first
df -h /System/Volumes/Data           # need >= 3 GiB free (run_case.py refuses below 3 GiB)
pgrep -fl 'cake_compile_heap|arm8-heap|cakeml-heap|poly' || echo "no HOL process"
```
If any HOL process runs: stop. Do not start. `run_case.py` also refuses (exit 3, `resource_guard_refused`).

## 2. Set up the attempt folder (once)

```zsh
X=<session scratch folder>/m1b/X7
S=<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001
A=<HOME>/forge/results/m1b-routeA-20261119/attempt-0001
mkdir -p $A
cp $S/run_case.py $A/run_case.py            # unchanged copy: pinned hol, heap cake_compile_heap, cwd, guard, CPU limit from FORGE_CPU_SECONDS
cp $S/deps-imp4.txt $A/deps-L1.txt
cp $X/go-routeA.sh $X/hash_parents.py $A/
chmod +x $A/go-routeA.sh
cp $X/routeA-L1.sml $A/L1-0001.sml
shasum -a 256 $A/run_case.py $S/run_case.py $A/deps-L1.txt $S/deps-imp4.txt $X/routeA-L1.sml $A/L1-0001.sml
```
`run_case.py` sets `HOLDIR`, `CAKEMLDIR`, `FORGE_P3_OUT` (= the case folder; the script `chDir`s there and
`export_theory` writes `<case>/.hol/objs/forge_refundRouteA1Theory.{sig,sml,dat}`), `FORGE_IMAGE`, puts
`poly-install/bin` first in `PATH`, runs `hol run --holstate=<TC>/cakeml/cv_translator/cake_compile_heap <deps...> <case>/proof.sml`
in the cwd of the recorded bridge-0005 command, with `RLIMIT_CPU = FORGE_CPU_SECONDS` and a wall limit of CPU + 300 s.
It asserts the executable hash `b8ed5ec2…7bb8` and records `inputs_unchanged_after`.

## 3. Case 1: L1

```zsh
cd $A
FORGE_CPU_SECONDS=600 ./go-routeA.sh L1-0001 L1-0001.sml deps-L1.txt ; echo "go exit $?"
```
Produces: `A/L1-0001/{invocation.json, command.json, proof.sml, stdout.log, stderr.log, .hol/objs/forge_refundRouteA1Theory.{sig,sml,dat}}`,
`A/L1-0001.run.json`, `A/L1-0001.hashes.json`.

Pass criteria (ALL must hold; else the run is a finding, not a pass):
- actual exit 0 (`command.json` `actual_exit`), marker `EXACT_COMPLETE` in `markers`, `inputs_unchanged_after` true;
- no `LEMMA_FAILED`, no `UNEXPECTED_CONTROL_ACCEPTANCE`;
- `CHECKED` lines for (16 theorems): `refund_ffi_tot_valid`, `refund_ffi_tot_invalid`, `refund_ffi_tot_all_valid_is_identity`,
  `refund_ffi_tot_shift_seq`, `refund_ffi_contract_on_totalises`, `refund_env_with_ffi_interfer_fields`,
  `refund_env_ok_sl_of_contract_on`, `refund_ffi_contract_on_all_valid_is_the_stored_contract`,
  `contract_on_without_totalisation_is_not_the_stored_contract`, `bad_return_ffi_totalised_with_empty_predicate_meets_contract`,
  `refund_close_call_valid_excludes_zero_alen`, `refund_close_call_valid_rejects_u393_witness`,
  `stored_contract_demands_return_at_u393_close_state`, `close_abort_model_satisfies_contract_on`,
  `close_abort_model_fails_stored_contract`, `close_abort_model_totalised_meets_stored_contract`;
  `STORED_THEOREMS 16` (`thm` is used 16 times; `tg` is a local `prove`, not stored), `STORED_DEFINITIONS 4`;
- `CONTROL_OK` lines: on-definition shape, N1 negation, N2 negation (two), L1 shape, L1 literal (6 lines);
- `TEXT_CHECK_OK refund_ffi_contract_on_def` (a `TEXT_CHECK_MISMATCH` does not stop the run: it means my literal
  transcription differs from the definition built from the stored term; record it; the printed `DEFINITION` line is the truth);
- exactly four `CLOSURE_AXIOM` lines: `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.

## 4. Case 2: import check of L1 (only after case 1 exit 0)

```zsh
cd $A
cp deps-L1.txt deps-L1imp.txt
print -l $A/L1-0001/forge_refundRouteA1Theory.sig $A/L1-0001/forge_refundRouteA1Theory.sml >> deps-L1imp.txt
cp $X/routeA-L1-imp.sml $A/L1imp-0001.sml
FORGE_CPU_SECONDS=600 ./go-routeA.sh L1imp-0001 L1imp-0001.sml deps-L1imp.txt ; echo "go exit $?"
```
Pass: exit 0, `EXACT_COMPLETE`, `IMPORTED_COUNT 9 MISMATCH_COUNT 0`, two `CONTROL_OK`, four `CLOSURE_AXIOM`.
This is the same machine and cached parents. It is NOT a clean or independent replay.

## 5. Case 3: L2 (only after cases 1 and 2 have exit 0)

```zsh
cd $A
cp deps-L1imp.txt deps-L2.txt
cp $X/routeA-L2.sml $A/L2-0001.sml
FORGE_CPU_SECONDS=1600 ./go-routeA.sh L2-0001 L2-0001.sml deps-L2.txt ; echo "go exit $?"
```
Pass: exit 0, `EXACT_COMPLETE`, `CHECKED` for `refund_ffi_tot_evaluate_agree`, `refund_ffi_tot_machine_sem_agree`,
`refund_mc_totalised_record`, `refund_mc_totalised_record_fields`, `refund_profile_a_sl_reach`; three `CONTROL_OK` lines
(conclusion term-identical to the stored `refund_profile_a_sl`; no `refund_env_ok_sl` or `refund_ffi_contract_at` in the
premises; premise count + 2); four `CLOSURE_AXIOM`. Expect failures here on the first attempts (see routeA-L2.md, risks).

## 6. What to record for each run (for ROADMAP.md / TRACKER.md; the orchestrator writes those files)

From `A/<case>.hashes.json` (made by `hash_parents.py`) and `A/<case>/command.json`:
1. actual exit code (`actual_exit`; and the `exit` line printed by `go-routeA.sh`), wall and CPU seconds, max RSS, markers;
2. every theorem statement exactly as printed (`statements` field: the lines after each `CHECKED <name>`), and every
   `DEFINITION` line;
3. the premises: for L1 they are inside the statement (the antecedent of each implication); list them per theorem;
4. tags: the run raises `Fail` before export if any stored theorem has a hypothesis, an axiom tag, or an oracle other than
   `DISK_THM`; the four `CLOSURE_AXIOM` lines;
5. dependency hashes: `parents` = SHA-256 of the `.sig`, `.sml` and `.dat` of each of the 61 (L1) / 62 (L2) parent theories as
   HOL loads them (from `<dir>/.hol/objs/`), plus `preload.sml`; `produced_objects` = SHA-256 of the produced theory files;
   `tools_and_logs` = SHA-256 of the `hol` binary, the heap `cake_compile_heap`, `stdout.log`, `stderr.log`, `proof.sml`;
6. the SHA-256 of the source `.sml` (`command.json` `source_sha256`) and confirm it equals the SHA-256 of the scratch draft
   (or record the difference and why).

Helper self-test (read-only, done by me): `python3 -I -B hash_parents.py S/deps-e4.txt S/e4-0001` gave exit 0, 61 parent
theories, 0 missing, and produced-object hashes equal to `e4-0001/command.json` (`.dat` 4ff2a7e2…12a1). Output kept as
`X/test-e4.hashes.json`.

## 7. What a failure means and what to do

- `resource_guard_refused` (exit 3): nothing ran. Wait. It is not an attempt.
- `LEMMA_FAILED <name>`: a tactic failed. It is a FINDING about my tactic, not evidence that the statement is false.
  Keep the whole case folder. Read the `SHOW` / `GOAL` lines printed just before it. No theory is exported (the script
  raises `Fail` before `export_theory`).
- `UNEXPECTED_CONTROL_ACCEPTANCE`: a structural control did not hold. Treat as a failed run. Keep the output.
- CPU limit reached (`actual_exit` negative or SIGXCPU, no `EXACT_COMPLETE`): a finding; record the CPU used.
- At most FIVE attempts per proof (project rule). Each attempt is a new case name (`L1-0002`, …) and a new source copy
  (`run_case.py` refuses an existing case folder). Record the diff between attempts.
- Never change a theorem STATEMENT or a DEFINITION between attempts without recording the old text, the new text, and why.
  Tactic-only changes are allowed and must be recorded as tactic-only. A weaker statement is a different result.
- Never add `cheat`, `mk_thm`, `new_axiom`, or an oracle. The `thm` helper in these files has no `mk_thm` (it returns
  `TRUTH` after a failure only so that later lines print; the run then fails before export).

## 8. Likely failure points (my reading; not checked by running)

L1 (low to medium risk):
- `Cases_on `Vok index new_bytes ms2``: I rely on it giving the assumptions `Vok index new_bytes ms2` and
  `¬Vok index new_bytes ms2`, positive case first. If not, `MATCH_MP TOT_T` fails in the first branch.
  Fix (tactic only): replace by `ASM_CASES_TAC` on the same term, or swap the branches.
- `S1` and the `impl_tac` of `N1`: if `rewrite_tac` does not beta-reduce the instantiated predicate, the `BETA_TAC` that
  follows does it; if the goal is not closed, add `simp_tac bool_ss []` (tactic only).
- `N2b`: the hypotheses at index 2 are closed by the tactic copied from the stored `refund_ffi_contract_at_witness`
  (index 0); the address arithmetic `0x1000040D0w − n2w ((3 + 2) * 16) = 0x100004080w` is left to `EVAL_TAC`.
- The text check literal may not parse or may differ (non-fatal, printed).
L2 (medium to high risk): see `routeA-L2.md` §5.
