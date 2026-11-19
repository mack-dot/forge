# Run plan: links S5 and S6 in HOL (worker Y2). DRAFT, NOT RUN

Every exit code below is EXPECTED. None was observed. Record actual codes
in a separate table. One HOL process at a time. Stop at the first result
that is not as expected and report it; do not edit a theorem to make it pass.

## 0. Preconditions (measure and record each time, before each case)

- No other HOL child: `pgrep -fl 'cakeml-heap|arm8-heap|cake_compile_heap'` is empty.
  (2026-11-19, while writing: the replay was running, so NOT met.)
- `memory_pressure` free ≥ 25 % (the runner guard); `sysctl vm.swapusage`
  recorded (2026-11-19: 8,578 of 9,216 MiB swap used; memory free 54 %).
  If swap use is above 85 %, wait.
- Disk free ≥ 3 GiB (the runner guard). Mains power.

## 1. Variables and inputs

```
F=<HOME>/forge
Y2=<session scratch>/m1b/Y2
B=origin/backup/forge-local-2026-11-11          # c003a982…
P=proposals/refund-executable-feasibility/source-model-binding-20261104/records
RUN=$F/results/m1b-exported-contract-20261119/attempt-0001   # proposed; the orchestrator decides
D=$F/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny
mkdir -p $RUN/inputs $RUN/u294 $RUN/stored/hol-0004/.hol/objs
git -C $F show $B:$P/hol-0004/input.sexp > $RUN/inputs/FlatCore.sexp
for f in proof-0004.sml relation.sml bridge.sml import-0001/audit.sml; do git -C $F show $B:$P/$f > $RUN/u294/$(basename $f); done
for x in dat sig sml; do git -C $F show $B:$P/hol-0004/.hol/objs/forge_refundSourceBindingTheory.$x > $RUN/stored/hol-0004/.hol/objs/forge_refundSourceBindingTheory.$x; done
printf 'load "sexp_to_dafnyTheory";\nload "forge_refundTheory";\n' > $RUN/u294/preload.sml   # = recorded preload.sml
cp $Y2/{forge_refundExportedContractScript.sml,forge_refundExportedRenderScript.sml,preload-render.sml,loadpath.sml,probe.sml,make_controls.py} $RUN/
python3 -I $RUN/make_controls.py $RUN/inputs/FlatCore.sexp $RUN/forge_refundExportedContractScript.sml $RUN/controls
shasum -a 256 $RUN/inputs/FlatCore.sexp $RUN/u294/* $RUN/stored/hol-0004/.hol/objs/* $RUN/*.sml $RUN/controls/*
```

Stop if a hash differs from: export `58154ddf…dd0d`; `proof-0004.sml` `a79edc4b…`;
`relation.sml` `a8f783a2…`; `bridge.sml` `e9d12e06…`; stored `.dat` `6f30ff5d…`,
`.sig` `eccb0dd4…`, `.sml` `b6f406a6…`; main script `89fee9c3…`; render
script `46a0055d…`; controls as in `controls/CONTROLS.json` (made by the
same tool in this folder; the sums must be equal).

## 2. Runner

Copy `$F/results/refund-profile-a-local-20261117/attempt-0001/run_case.py`
to `$RUN/run_case.py`. Record exactly three edits:

1. `CWD = os.environ.get('FORGE_CWD', str(ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundCertifiedProg_experiment'))`
   (U294 `bridge-0001` ran with this cwd and exit 0).
2. Add to `MARKERS`: `'SOURCE_BINDING_COMPLETE'`, `'SOURCE_RELATION_COMPLETE'`,
   `'SOURCE_BRIDGE_COMPLETE'`, `'SOURCE_IMPORT_COMPLETE'`, `'EXPORTED_CONTRACT_COMPLETE'`, `'EXPORTED_RENDER_COMPLETE'`.
3. none to the guard, the image assert or the heap path logic.

Always: `FORGE_HEAP=cakeml/misc/cakeml-heap` (the U294 heap path; its
SHA-256 is now `66b1654b…`, rebuilt 2026-11-17; the U294 runners pin the
old `36f7c254…` and therefore are NOT used). The runner passes the extra
arguments to `hol run` BEFORE the case script, in the given order.

`R=python3 -I -B $RUN/run_case.py` below; `cd $RUN` first.

## 3. Cases, in this order

| ID | Link | Command (env vars before `$R`) | CPU limit s | Expected (pass criteria) |
| --- | --- | --- | --- | --- |
| H0 | load | `FORGE_HEAP=cakeml/misc/cakeml-heap FORGE_CPU_SECONDS=300 $R probe-0001 probe.sml` | 300 | exit 0, marker `EXACT_COMPLETE`. If exit ≠ 0 with a `load` error: run H0′ = same with `loadpath.sml` as an extra argument (`$R probe-0002 probe.sml $RUN/loadpath.sml`); if H0′ passes, give `loadpath.sml` as FIRST extra argument in R1 to I1 |
| R1 | S5 | `FORGE_SOURCE_SEXP=$RUN/inputs/FlatCore.sexp FORGE_SOURCE_PROOF_OUT=$RUN/u294-hol FORGE_HEAP=… FORGE_CPU_SECONDS=900 $R u294-hol u294/proof-0004.sml` | 900 (recorded wall 166.5 s) | exit 0; `SOURCE_BINDING_COMPLETE`; five `CHECKED` lines byte-equal to the recorded `hol-0004/stdout.log` (`git show $B:$P/hol-0004/stdout.log`); record the new `.dat` SHA-1 and compare with `2677fe68…` (equal is expected but not required) |
| R2 | S5 | `FORGE_SOURCE_PROOF_OUT=$RUN/u294-rel … $R u294-rel u294/relation.sml $RUN/u294/preload.sml $RUN/u294-hol/.hol/objs/forge_refundSourceBindingTheory.sig $RUN/u294-hol/.hol/objs/forge_refundSourceBindingTheory.sml` | 300 | exit 0; `SOURCE_RELATION_COMPLETE`; `CHECKED source_model_result` equal to the recorded `relation-0001/stdout.log` |
| R3 | S5 | `FORGE_SOURCE_PROOF_OUT=$RUN/u294-bridge … $R u294-bridge u294/bridge.sml <same three extras as R2>` | 300 | exit 0; `SOURCE_BRIDGE_COMPLETE`; `CHECKED source_compiled_fields` equal to the recorded `bridge-0001/stdout.log` |
| I1 | S5 (stored objects) | `$R u294-import u294/audit.sml $RUN/u294/preload.sml $RUN/stored/hol-0004/.hol/objs/forge_refundSourceBindingTheory.sig $RUN/stored/hol-0004/.hol/objs/forge_refundSourceBindingTheory.sml` (with `FORGE_SOURCE_SEXP`, `FORGE_SOURCE_PROOF_OUT` as R1) | 300 | exit 0; `SOURCE_IMPORT_COMPLETE`; seven `IMPORTED … EXACT true` lines (the audit compares each stored statement with `aconv`): the STORED 2026-11-04 theory loads in the present tree. By reading, `audit.sml` writes nothing |
| H1 | S6 | `FORGE_CONTRACT_SEXP=$RUN/inputs/FlatCore.sexp FORGE_HEAP=… FORGE_CPU_SECONDS=1200 $R contract-0001 forge_refundExportedContractScript.sml` | 1200 (estimate 2–8 min; low confidence) | exit 0; `EXPORTED_CONTRACT_COMPLETE`; nine `FORGE_THEOREM` lines, each `FORGE_HYPOTHESES 0`, empty `FORGE_AXIOMS`, `FORGE_ORACLES DISK_THM`; objects `.hol/objs/forge_refundExportedContractTheory.{dat,sig,sml}`; then read `FORGE_STATEMENT exported_contract_on_refund_fields` and `…_exact` against STATEMENTS.md section 3 by eye |
| H2 | S6 | H1 again as `contract-repeat` | 1200 | exit 0; every `FORGE_STATEMENT` line byte-equal to H1 |
| H3 | S6 controls | for each `controls/NC*.sexp` and `PC1`: H1 with `FORGE_CONTRACT_SEXP=$RUN/controls/<file>`, case `ctl-<id>`; for each `controls/NS*.sml`: `$R ctl-<id> controls/<file>` with the real export | 900 each | exactly as `controls/CONTROLS.json`: NC1, NC5 stop after `FORGE_BEGIN exported_ens1_value`; NC2 after `…ens2_value`; NC3 after `…ens3_value`; NC4, NC6 stop in ML before any `FORGE_BEGIN`; NS1 to NS3 stop after `FORGE_BEGIN exported_contract_on_refund_fields`; every one exit ≠ 0 and no `EXPORTED_CONTRACT_COMPLETE`. **PC1: exit 0 (expected pass: the theorems do not read the body).** A CPU-limit stop (exit −24 or a signal) is NOT a rejection: run again or record as undecided |
| H4 | S6 → X14 | `FORGE_CWD=$D/forge_refundWireProg_experiment FORGE_HEAP=… FORGE_CPU_SECONDS=900 $R render-0001 forge_refundExportedRenderScript.sml $RUN/preload-render.sml $RUN/contract-0001/.hol/objs/forge_refundExportedContractTheory.sig $RUN/contract-0001/.hol/objs/forge_refundExportedContractTheory.sml` | 900 | exit 0; `EXPORTED_RENDER_COMPLETE`; no hypotheses, axioms or extra oracles |
| NR1 | H4 control | H4 with `controls/NR1-render-ids-swapped.sml`, case `ctl-NR1` | 900 | exit ≠ 0; no `EXPORTED_RENDER_COMPLETE` |
| E0 (optional) | S6 guard | W2's `drafts/link-eligible` H0/H1 with `loadpath.sml` as first extra argument (pre-flight P6) | 900 | as W2's RUN_PLAN |

Budget: the limits add up to about 14,700 CPU seconds; the expected total is
well under one hour (estimate, low confidence; the CertifiedProg load is the
largest unknown).

## 4. Decision rules

- S5 may be called "replayed 2026-11-19, same machine" only if R1 to R3 pass.
  I1 alone shows "the stored theory loads", not a replay.
- S6 moves from MISSING to MACHINE-CHECKED (same machine, one run plus
  repeat) only if H1, H2 pass AND every control in H3 is as expected. If
  any NC/NS passes, the positive result does not count. If PC1 fails, stop:
  the theorems depend on something that the statement does not show.
- Main tactic fallbacks (each is a recorded new attempt, never a weaker statement):
  C3–C5 if a goal stays open: `EVAL_TAC >> rpt (IF_CASES_TAC >> gvs [] >> EVAL_TAC)`;
  C6 if `simp` loops or stops: `REWRITE_TAC [exported_ensures_def] >> ONCE_REWRITE_TAC [evaluate_exp_def] >> simp [exported_ens1_value] >> ONCE_REWRITE_TAC [evaluate_exp_def] >> simp [exported_ens2_value] >> ONCE_REWRITE_TAC [evaluate_exp_def] >> simp [exported_ens3_value, evaluate_exp_def]`;
  C9 if `EVAL_TAC` does not unfold `refund_fields`: `simp [forge_refundCertifiedProgTheory.refund_fields_def, eligible_def]`;
  H4 if `drule` fails: `metis_tac [exported_contract_on_refund_fields]`.
- Even when all pass: S6 is a HOL theorem about the EXPORT. S4 (exporter)
  and S7 (operator and string meaning) stay ASSUMPTION. M1-B stays OPEN.
