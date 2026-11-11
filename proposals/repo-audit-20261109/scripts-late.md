# Repository audit 2026-11-09: proposals for pinned script files (scripts-late)

Status: PROPOSAL ONLY. No target file was changed. Each change needs owner approval.
This file covers audit findings A19, A20 (same defect as A62), A21, A22, A51 and A52.
It grants no authority. It does not change the stage, a lock, a manifest or a record.

All diffs were built from copies under the session scratchpad. Apply a diff from the
repository root with `patch -p1`. Each edited Python copy parses
(`python3 -B -c "import ast,sys;ast.parse(open(sys.argv[1]).read())"`, exit 0).
Parsing shows syntax only. It does not show that a fix works.

## Pin status, checked 2026-11-09

| Target | Current sha256 | Pinned by | Protected path |
| --- | --- | --- | --- |
| `scripts/benchmark_reuse.py` | `1220fca1ebc43375da4c11af67231cb69c20a05ad7c68b7ccf463828d2d292ec` | `gate/provenance/implementation.lock` line 50; `runner_sha256` in `results/stage6/benchmark.json`; `scripts/exit_stage_6.py` lines 57-58 | No |
| `scripts/exit_stage_10.py` | `d264d1e67afe010da8bc60204230f900b68ac83364c3ddcf20185728afdbf9b2` | `bench/manifest.json` line 179. Not listed in `gate/provenance/implementation.lock`. | No |
| `bench/README.md` | `eb3285587f990fca94af176b3973b320e1dc485ed499bf4625a51de333c7d96e` | `bench/manifest.json` line 124. Not listed in `gate/provenance/implementation.lock`. | No |
| `scripts/render_spec_report.py` | `dd6f4a9c856af315ad4e8bb6fd2170af4f7ac5e87e8435092e23ceda0c94070b` | `gate/provenance/implementation.lock` line 71; `renderer_sha256` in `results/stage5/spec-quality.json` | No |
| `proposals/incremental-verification/exit_stage_11.py` | `f277f3d8239ef5528caf8d1ef26e53afb1925af6738c573748213cc8e9e17182` | No lock file and no manifest in the working tree lists it. Recorded evidence holds its digest: `results/stage11/pr-open-0001.txt` line 29 (as `scripts/exit_stage_11.py`). | No |

Notes on the pin search:

- I searched `*.lock`, `MANIFEST*` and `manifest*.json` files outside `results/`, `build/`,
  `.toolchain/` and `node_modules/` for the five paths. Hits: `bench/manifest.json`,
  `gate/provenance/implementation.lock`, and eight `implementation.lock` copies under
  `proposals/` (approval-integrity/admission-v34, token-compat-v35 (two), deploy-perms-v36,
  provenance-hosted-v3, -v31, -v32, -v33). I did not open the eight copies. They are
  historical records and must stay unchanged.
- `exit_stage_11.py` is NOT pinned by a lock and is NOT under a protected path. The owner
  can approve a direct edit. I still recommend a new revision file (see A51), because the
  current bytes are the only local copy of the script that the Stage 11 records name.
- The audit verdict for A51 also cites source-lock outputs under
  `results/stage11/suites-0004-lock-50f56592/`. I did not re-check those files today.

## Recommended order for the owner

1. A51 and A52 need no lock change. Approve or reject them first.
2. A22 and A19 need one `gate/provenance/implementation.lock` change each. Batch them
   in one lock change if both are approved.
3. A20/A62 and A21 need a new frozen bench manifest and a new recorded run. Defer them
   to the next benchmark version.

---

## A19 — `scripts/benchmark_reuse.py` line 281: run can overwrite recorded Stage 6 files

**Defect.** After a passed run, line 281 writes `results/stage6/<label>.json` with no
existence check and no `stage_exit` check. The default label is `benchmark` (line 145).
Line 147 permits `--repetitions 1`. Line 148 permits any `[a-z0-9-]+` label.

**Evidence re-checked today.**

- Line 281 is `(ROOT / 'results/stage6' / (args.label + '.json')).write_bytes(canonical(report))`.
- Line 168 sets `stage_exit` to `args.repetitions == 5 and args.label == 'benchmark'`.
- `results/stage6/benchmark.json` holds label `benchmark`, repetitions 5, sample_count 75,
  `stage_exit` true, and `runner_sha256` equal to the current script digest.
- `results/stage6/` also holds `report.json`, `accounting.json`, `controls-final.json`,
  `source-evidence.json`, `input-identities.json`, `preflight.json` and `report-replay.json`.
  Each name matches the label pattern.
- I did not run the script. The overwrite needs a full Dafny pass to reach line 281.

**Impact.** `python3 scripts/benchmark_reuse.py --repetitions 1` can replace the recorded
five-repeat `benchmark.json` with a 15-sample report that has `stage_exit` false.
`scripts/exit_stage_6.py` lines 54-56 then fail. A label such as `report` replaces another
recorded file. The per-run copy under `results/stage6/runs/run-NNNN/` survives. The hazard
is latent: an operator must start the run.

**Options.**

- Option A (recommended): fail before the measurement starts when the selected file
  exists, reserve the label `benchmark` for five repeats, and create the file exclusively.
- Option B: write the top-level file only when `stage_exit` is true. This also stops
  top-level files for preparation labels. I do not know if a later step reads such a file,
  so I do not recommend it without that check.
- Option C: no code change. The recorder adds an unsure.md entry and a warning in
  `docs/reuse-benchmark.md` (that file is not listed in `gate/provenance/implementation.lock`
  or `bench/manifest.json`; I did not search other pins for it).

**Exact diff (Option A).**

```diff
--- a/scripts/benchmark_reuse.py
+++ b/scripts/benchmark_reuse.py
@@ -146,6 +146,11 @@
     args = parser.parse_args()
     require(args.repetitions in (1, 5), 'Use one preparation repeat or the five-repeat experiment')
     require(re.fullmatch('[a-z0-9-]+', args.label), 'Invalid report label')
+    require(args.label != 'benchmark' or args.repetitions == 5,
+            'The label "benchmark" is reserved for the five-repeat experiment')
+    selected = ROOT / 'results/stage6' / (args.label + '.json')
+    require(not selected.exists(),
+            'Recorded evidence is immutable; choose a new label: ' + selected.relative_to(ROOT).as_posix())
     state = dafny.prepare('impl/Ledger.dfy')
     protected_before = protected_manifest(ROOT)
     original = {name: (ROOT / name).read_text() for name in SOURCES}
@@ -278,7 +283,8 @@
                     print(name + ': expected checker result observed', flush=True)
         report.update({'result': 'passed', 'exit_code': 0})
         save()
-        (ROOT / 'results/stage6' / (args.label + '.json')).write_bytes(canonical(report))
+        with selected.open('xb') as handle:
+            handle.write(canonical(report))
         print('REPORT ' + destination.relative_to(ROOT).as_posix(), flush=True)
         return 0
     except Exception as error:
```

Behavior notes for Option A:

- A preparation run with the default label now fails at once. The operator must pass a
  new `--label`.
- The two new `require` calls sit before the `try` block, as lines 147-148 do. A failure
  raises `RuntimeError` and creates no run directory.
- If another process creates the file during the run, `open('xb')` raises inside the
  `try` block. The run report then records `failed`. That is fail-closed, but it discards
  a completed measurement as a result. I judge the case rare.
- A planned re-measurement into `benchmark.json` is blocked too. The owner must define how
  to supersede the old file (for example a new label and a new EXIT reader).

**A change invalidates.**

- The pin at `gate/provenance/implementation.lock` line 50 (protected file).
- `scripts/exit_stage_6.py` lines 57-58: `runner_sha256` in `results/stage6/benchmark.json`
  no longer equals the script digest. The Stage 6 report recompute fails with
  "Benchmark driver changed after measurement".

**Steps the owner must authorize.**

1. The script edit.
2. An update of `gate/provenance/implementation.lock` line 50, plus the re-run of each
   check that reads that lock.
3. One of: (a) a new five-repeat measurement under a new label, with a matching change to
   the Stage 6 EXIT reader, or (b) acceptance that the Stage 6 report recompute no longer
   passes against the recorded `benchmark.json`. `results/stage6/benchmark.json` must not
   be edited. `scripts/exit_stage_6.py` is pinned too (lock line 62).

**Check that would show the fix works — NOT RUN.**
`python3 scripts/benchmark_reuse.py --repetitions 1` must exit non-zero before any Dafny
call, create no `results/stage6/runs/run-NNNN` directory, and leave the sha256 of
`results/stage6/benchmark.json` unchanged. Done today: syntax parse of the copy only, exit 0.

---

## A20 and A62 — `scripts/exit_stage_10.py` line 192 and `bench/README.md` line 44: default run is the non-established run-0001

A20 and A62 report the same defect. This section covers both.

**Defect.** Line 192 sets the default `--run` to `results/stage10/run-0001`. The README
command at line 44 passes no `--run`. Lines 204-206 write `report.json` and `report.md`
when absent. The `not_run` check follows at lines 208-210.

**Evidence re-checked today.**

- Line 192 is `parser.add_argument('--run', type=Path, default=REPO / 'results/stage10/run-0001')`.
- `bench/README.md` line 44 is `python3 scripts/exit_stage_10.py --case report`.
- `results/stage10/run-0001/` holds `pass-1`, `pass-2`, `records.jsonl` and `run.json`.
  It has no `report.json` and no `report.md`.
- I counted record statuses from `records.jsonl` (read only). run-0001: pass 1 has 37
  `ran` and 14 `harness_error`; pass 2 has the same counts. run-0002: 51 `ran` in each pass.
- `ROADMAP.md` line 4010 already states the default names run-0001 (U174).
- I did not run the script against run-0001. The write into run-0001 follows from the code
  and from the 14 `harness_error` records, on the condition that `build()` does not raise
  first. The auditors report that an in-memory `build()` call returned `not_run` 14.

**Impact.** The documented command adds two files to the recorded run-0001 directory and
exits 1. No false pass results.

**Options.**

- Option A (recommended): apply the two diffs below together with the next frozen bench
  manifest. Until then, change nothing in place. The correct command stays
  `python3 scripts/exit_stage_10.py --case report --run results/stage10/run-0002`
  (`ROADMAP.md` line 4010).
- Option B: refreeze now. That needs a new `bench/freeze.py` run and a new recorded gate
  run, only to fix a default.
- Option C: no code change. The recorder adds an unsure.md entry that references U174.

**Exact diffs.** The script diff also holds the A21 hunk (the three `idle` lines in
`build()`). Remove that hunk if the owner approves A20/A62 without A21.

```diff
--- a/scripts/exit_stage_10.py
+++ b/scripts/exit_stage_10.py
@@ -1,7 +1,7 @@
 #!/usr/bin/env python3
 """Stage 10 EXIT: report the recorded gate benchmark run from its real records.
 
-  python3 scripts/exit_stage_10.py --case report [--run results/stage10/run-0001]
+  python3 scripts/exit_stage_10.py --case report --run results/stage10/run-NNNN
 
 Checks the frozen manifest and every bench file, requires each case to have run
 once in every pass, and computes the outcome tables, latency, cost and pass-to-pass
@@ -88,6 +88,9 @@
     for number, rows in passes.items():
         if [r['id'] for r in rows] != order:
             raise ValueError('pass %d does not hold every case exactly once in order' % number)
+        idle = [r['id'] for r in rows if r.get('status') != 'ran']
+        if idle and number != manifest['primary_pass']:
+            raise ValueError('pass %d has cases that did not run: %s' % (number, ', '.join(idle)))
     primary = passes[manifest['primary_pass']]
     for record in primary:
         record['outcome'] = outcome(record)
@@ -189,13 +192,16 @@
 def main():
     parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
     parser.add_argument('--case', choices=['report'], required=True)
-    parser.add_argument('--run', type=Path, default=REPO / 'results/stage10/run-0001')
+    parser.add_argument('--run', type=Path, required=True)
     args = parser.parse_args()
     run_dir = args.run.resolve()
     try:
         report = build(run_dir)
     except (OSError, ValueError, KeyError) as error:
         return fail(str(error))
+    counts = report['outcome_counts']
+    if counts['not_run']:
+        return fail('%d cases did not run in the primary pass' % counts['not_run'])
     outputs = {run_dir / 'report.json': (json.dumps(report, indent=1, sort_keys=True) + '\n').encode(),
                run_dir / 'report.md': markdown(report).encode()}
     for path, data in outputs.items():
@@ -205,9 +211,6 @@
         if not path.exists():
             path.write_bytes(data)
         print(path.name, sha256(data))
-    counts = report['outcome_counts']
-    if counts['not_run']:
-        return fail('%d cases did not run in the primary pass' % counts['not_run'])
     print('STAGE10_REPORT_ESTABLISHED: cases %d; match %d; wrong_reason %d; false_accept %d; false_reject %d; '
           'misclassified %d; end_to_end=false' % (report['case_count'], counts['match'], counts['wrong_reason'],
                                                  counts['false_accept'], counts['false_reject'], counts['misclassified']))
```

```diff
--- a/bench/README.md
+++ b/bench/README.md
@@ -41,7 +41,7 @@
     --out results/stage10/dry-run-0001 --work ~/forge-stage10-bench/dry-run-0001
 python3 bench/run.py --manifest bench/manifest.json --approved-manifest-sha256 <SHA> \
     --out results/stage10/run-0001 --work ~/forge-stage10-bench/run-0001
-python3 scripts/exit_stage_10.py --case report
+python3 scripts/exit_stage_10.py --case report --run results/stage10/run-NNNN
 ```
 
 A dry run builds and removes every case tree, checks Dafny starts and the network is
```

The `main()` hunks make `--run` required and move the `not_run` check before the first
write. An incomplete run then gets no report files.

**A change invalidates.**

- `bench/manifest.json` `files` digests (lines 124 and 179). `build()` line 80 then raises
  "bench file changed after the run" for run-0002.
- After a refreeze, `manifest_sha256` changes. run-0002 then fails `build()` line 75-76
  ("used another manifest"). The recorded Stage 10 EXIT (exit 0, then 0) stays as history
  but no longer reproduces from the working tree.
- `gate/provenance/implementation.lock` does not list either file. No lock change is needed.

**Steps the owner must authorize.**

1. The two edits.
2. A new `python3 bench/freeze.py` run and approval of the new manifest sha256.
3. A new recorded benchmark run under the new manifest, then the Stage 10 EXIT command
   on that run. I do not know if `bench/freeze.py` has more preconditions; I did not read it.

**Check that would show the fix works.**

- DONE on the edited copy (argparse only, no file access):
  `python3 -I -B <copy>/scripts/exit_stage_10.py --case report` exits 2 with
  "the following arguments are required: --run".
- NOT RUN: after the refreeze, `--case report --run results/stage10/run-0001` must exit 1
  and must leave run-0001 with no `report.json` and no `report.md`.
- NOT RUN: the EXIT command on the new complete run must exit 0 twice with equal bytes.

---

## A21 — `scripts/exit_stage_10.py` lines 6-7 and 208-210: "every pass" claim, primary-pass check

**Defect.** The docstring states "requires each case to have run once in every pass".
The code requires only that each pass lists each case id in order (lines 88-90). The
`not_run` check (lines 208-210) reads `outcome_counts`, which line 128 computes from the
primary pass only.

**Evidence re-checked today.**

- Lines 6-7, 88-90, 128 and 208-210 read as described.
- `bench/manifest.json` has `primary_pass` 1 and `passes` 2.
- run-0002 has 51 `ran` records in pass 2 (counted today from `records.jsonl`). The
  recorded run-0002 result is not affected.
- `ROADMAP.md` line 4010 repeats the claim "run once in each of the two passes".
- I did not run the script on a crafted record set. The conclusion comes from the code.

**Impact.** A `harness_error` record in a non-primary pass gives only a
`reproducibility.differences` entry. The script still exits 0 and prints
`STAGE10_REPORT_ESTABLISHED`. The claim is stronger than the check. No recorded result is wrong.

**Options.**

- Option A (recommended): make the code match the claim. Apply the `idle` hunk in the
  A20/A62 script diff with the next frozen manifest. `build()` then raises `ValueError`
  for a non-primary pass with a case that did not run. `main()` prints
  `STAGE10_REPORT_NOT_ESTABLISHED` and exits 1. The report format does not change.
- Option B: make the claim match the code. Change the docstring to "requires each case to
  have a record in every pass and to have run in the primary pass". This is also a pinned
  edit.
- Until either: the recorder adds an unsure.md entry. Do not rewrite the `ROADMAP.md`
  line 4010 result row; add a note that references the new entry.

**Exact diff.** The `@@ -88,6 +88,9 @@` hunk in the A20/A62 script diff above:

```diff
+        idle = [r['id'] for r in rows if r.get('status') != 'ran']
+        if idle and number != manifest['primary_pass']:
+            raise ValueError('pass %d has cases that did not run: %s' % (number, ', '.join(idle)))
```

The primary pass keeps its existing path: `not_run` is counted and `main()` fails.

**A change invalidates, and steps to authorize.** The same as A20/A62: `bench/manifest.json`
line 179, a new freeze, a new run.

**Check that would show the fix works — NOT RUN.** Under the new manifest, copy a complete
run to a scratch directory, set one pass-2 record to `status` `harness_error`, and run the
EXIT on the copy. It must exit 1 with "pass 2 has cases that did not run". The unmodified
run must exit 0. Done today: syntax parse of the copy only, exit 0.

---

## A22 — `scripts/render_spec_report.py` lines 66-68 and 84-85: fixed numbers in rendered prose

**Defect.** The script emits literal text: "13 obligations, exit `0`", "verifier exit `0`",
"verifier exit `4`", and "The algebraic rewrite survived as expected. The print-effect
mutant also survived". It does not read these values from the records for the prose.

**Evidence re-checked today.**

- Lines 66-68 and 84-85 hold the literals.
- Line 16 requires `result == 'passed'` and `exit_code == 0` for both reports.
- Current records match the text: `len(vacuity['witness']['coverage'])` is 13;
  `vacuity_flagged` is true; `reject_all_verifier_exit` is 0; `witness_verifier_exit` is 4;
  `mutations['survivors']` is `['algebraic_rewrite', 'print_effect']`.
- The audit verdict states that `scripts/exit_stage_5.py` returns `passed` only with
  verifier exits 0, 0 and 4. I did not re-check that today.

**Impact.** `docs/spec-quality.md` is correct today. The count "13" and the survivor
sentence can drift if a later record differs. This is a latent risk, not a wrong statement.

**Exact diff.** The diff derives the count from the record and adds two guards.

```diff
--- a/scripts/render_spec_report.py
+++ b/scripts/render_spec_report.py
@@ -16,6 +16,11 @@
         require(report['result'] == 'passed' and report['exit_code'] == 0, 'A required real EXIT did not pass')
     require(vacuity['spec_sha256'] == mutations['spec_sha256'] == examples['spec_sha256'], 'Spec identities differ')
     witness = vacuity['witness']
+    fixture = vacuity['negative_fixture']
+    require(vacuity['vacuity_flagged'] and fixture['reject_all_verifier_exit'] == 0
+            and fixture['witness_verifier_exit'] == 4, 'Vacuity record differs from the rendered text')
+    require(mutations['survivors'] == ['algebraic_rewrite', 'print_effect'],
+            'Survivor set differs from the rendered text')
     source_manifest = [{'path': name, 'sha256': value} for name, value in sorted(witness['inputs'].items())]
     artifact = {'kind': 'source', 'sha256': digest(canonical(source_manifest)), 'build_cmd': ''}
     summary = {
@@ -63,7 +68,8 @@
             'These results concern the approved fee spec `' + vacuity['spec_sha256'] + '`.',
             'They measure this fixture set. They do not establish complete intent coverage.', '',
             '## Successful-execution witness', '', witness['statement'], '',
-            'Dafny verified the actual refinement and the witness together: 13 obligations, exit `0`.',
+            'Dafny verified the actual refinement and the witness together: '
+            + str(len(witness['coverage'])) + ' obligations, exit `0`.',
             'An isolated spec with both validity predicates set to false admitted the reject-all',
             'implementation (verifier exit `0`). The same success witness failed (verifier exit `4`).',
             'The fixture is not an approved production spec. The production gate was not weakened.', '',
```

With the current records the rendered sentence is unchanged. I checked the string
expression with a 13-item list (exit 0). I did not run the renderer.

**A change invalidates.**

- The pin at `gate/provenance/implementation.lock` line 71 (protected file).
- `renderer_sha256` in `results/stage5/spec-quality.json`. The renderer rewrites that file
  on each run (line 60), so a re-render changes a file under `results/`. I found no script
  under `scripts/` or `gate/` that compares `renderer_sha256`; I did not search other paths.
- The eight `implementation.lock` copies under `proposals/` keep the old digest. They are
  history and stay unchanged.

**Steps the owner must authorize.**

1. The script edit.
2. An update of `gate/provenance/implementation.lock` line 71, plus the re-run of each
   check that reads that lock.
3. A decision on the re-render: either no re-render (the recorded `spec-quality.json`
   keeps the old `renderer_sha256`, and the edit acts only on a future render), or a
   re-render with a recorded procedure for the changed `results/stage5/spec-quality.json`.

**Check that would show the fix works — NOT RUN.** In a scratch copy of the Stage 5 inputs:
(1) the render output for `docs/spec-quality.md` is byte-identical to the current file;
(2) with `survivors` changed in the copied `mutations.json`, the renderer exits non-zero
with "Survivor set differs from the rendered text". Done today: syntax parse of the copy
only, exit 0.

---

## A51 — `proposals/incremental-verification/exit_stage_11.py` lines 82-85 and 93: skipped case counted in the PASSED line

**Defect.** `stale_dependency()` skips a case with status `harness_error` and then prints
`len(wanted)` (12) as the count of cases that passed. No allow-list limits which cases
may be skipped. If each wanted case were a `harness_error`, the function returns 0.

**Evidence re-checked today.**

- Lines 82-85 and 93 read as described. `wanted` has 12 entries.
- `results/stage11/eval-0007/records.json` has 18 records. One has status `harness_error`:
  `e12-stale-witness`, error `('anchor', 'tests/stage5/SuccessfulExecution.dfy')`.
- `results/stage11/exit-console.txt` shows the note for e12 and then
  "STAGE11_STALE_DEPENDENCY_PASSED: 12 cases rejected, unsupported or not established as required", exit 0.
- I ran the unchanged script copy read-only on eval-0007 (`--case stale-dependency`):
  same two lines, exit 0. So 11 cases were checked and 12 were printed.
- I ran the unchanged copy on a synthetic record set (eval-0007 with `e13-readme-only`
  set to `harness_error`, in the scratchpad): it printed the 12-case PASSED line, exit 0.
  This confirms the missing guard.

**Impact.** The EXIT line overstates the count by one. A new unconstructible case would
pass with no failure. `ROADMAP.md` line 4075 discloses the e12 exclusion, per the audit;
I did not re-read that line. The recorded run hides no false accept.

**Options.**

- Option A (recommended): add the fixed script as a NEW revision file, for example
  `proposals/incremental-verification/exit_stage_11_r2.py`, built from the current file
  plus the diff below. Keep the current file byte-identical (sha256 `f277f3d8...`).
- Option B: edit the file in place. No lock blocks this. The preserved copy then no longer
  matches the digest in `results/stage11/pr-open-0001.txt`.
- Option C: no change. The recorder adds an unsure.md entry.

**Exact diff.** The diff also holds the A52 hunks (docstring line 5, the `REPO` line, and
the two `add_argument` lines). The A51 hunks are `ALLOWED_UNCONSTRUCTIBLE` and the three
hunks in `stale_dependency()`. For Option A, apply the diff to a copy with the new name.

```diff
--- a/proposals/incremental-verification/exit_stage_11.py
+++ b/proposals/incremental-verification/exit_stage_11.py
@@ -2,7 +2,7 @@
 """Stage 11 EXITs: read the recorded evaluation of the incremental PR gate.
 
   python3 scripts/exit_stage_11.py --case legitimate-change|stale-dependency|report
-      [--eval results/stage11/eval-0001] [--baseline results/stage11/eval-pr27-0001]
+      --eval results/stage11/eval-NNNN --baseline results/stage11/eval-pr27-NNNN
 
 Every case reads the frozen case file and the recorded runs; nothing is rerun and no
 label changes. Exit 0 only when the required behaviour is present in the records.
@@ -15,7 +15,6 @@
 from pathlib import Path
 import sys
 
-REPO = Path(__file__).resolve().parents[1]
 # Cases whose frozen expectation predates the review fix that binds in-process TypeScript
 # subjects and the witness file to the trusted base (CONTRACT.md §2, §5). Under the current
 # rules they are UNSUPPORTED (NOT_REESTABLISHABLE). Their frozen expectations are kept and
@@ -26,6 +25,9 @@
                   'e18-node-modules-missing': 'UNSUPPORTED'}
 FROZEN_CASES = 'ceec69ca99000f1c6fb1313892895734d07239da94edbeeb3c8cb007e2da9e1f'
 DEPENDENTS = {'ledger-evidence', 'ledger-model', 'booking', 'ledger-witness'}
+# Stale-dependency cases that the harness could not build as frozen (eval-0007). They are
+# evidence of nothing and are reported as not checked. Any other unbuilt case fails the EXIT.
+ALLOWED_UNCONSTRUCTIBLE = {'e12-stale-witness'}
 
 
 def sha256(data):
@@ -78,10 +80,15 @@
               # the property harness is a protected file: editing it is rejected before anything runs
               'e06-property-test-comment': ('REJECTED', None)}
     bad = []
+    skipped = []
     for name, (outcome, obligation) in wanted.items():
         if rows.get(name, {}).get('status') == 'harness_error':
             # The frozen case could not be built (recorded error); it is evidence of nothing.
             print('note: ' + name + ' not constructible as frozen: ' + str(rows[name].get('error'))[:120])
+            if name in ALLOWED_UNCONSTRUCTIBLE:
+                skipped.append(name)
+            else:
+                bad.append(name + ' not constructible')
             continue
         cold = rows.get(name, {}).get('cold', {})
         if cold.get('outcome') != outcome or cold.get('evidence_written'):
@@ -90,7 +97,9 @@
             bad.append(name + ' obligation ' + obligation + ' not rejected')
     if bad:
         return fail('; '.join(bad))
-    print('STAGE11_STALE_DEPENDENCY_PASSED: ' + str(len(wanted)) + ' cases rejected, unsupported or not established as required')
+    print('STAGE11_STALE_DEPENDENCY_PASSED: ' + str(len(wanted) - len(skipped)) + ' of ' + str(len(wanted))
+          + ' cases rejected, unsupported or not established as required; not constructible, not checked: '
+          + (', '.join(skipped) or 'none'))
     return 0
 
 
@@ -178,8 +187,8 @@
 def main():
     parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
     parser.add_argument('--case', choices=['legitimate-change', 'stale-dependency', 'report'], required=True)
-    parser.add_argument('--eval', type=Path, default=REPO / 'results/stage11/eval-0001')
-    parser.add_argument('--baseline', type=Path, default=REPO / 'results/stage11/eval-pr27-0001')
+    parser.add_argument('--eval', type=Path, required=True)
+    parser.add_argument('--baseline', type=Path, required=True)
     args = parser.parse_args()
     try:
         if args.case == 'legitimate-change':
```

I left out a separate "zero cases checked" floor. With a one-name allow-list and 12
wanted cases, at least 11 cases are always checked or the EXIT fails.

**A change invalidates.**

- Option A: nothing. The PASSED line text changes in the new revision. I found no consumer
  of the old line outside `results/`; I did not search `results/` in bulk.
- Option B: byte identity with the digest in `results/stage11/pr-open-0001.txt` line 29
  and, per the audit, in the lock-50f56592 source-lock outputs.
- No lock file or manifest in the working tree lists this file.
- `results/stage11/exit-console.txt` and `ROADMAP.md` line 4075 stay unchanged. They are history.

**Steps the owner must authorize.** The new file (Option A) or the in-place edit (Option B),
and a new unsure.md entry that references the Stage 11 entries. A new recorded console for
the new revision is optional and needs separate approval, because it adds a record.

**Check that shows the fix works.** RUN today on the edited scratch copy, read-only on
`results/`, with `python3 -I -B`:

| Command (on the edited copy) | Actual exit | Output |
| --- | --- | --- |
| `--case stale-dependency --eval results/stage11/eval-0007 --baseline results/stage11/eval-pr27-0003` | 0 | "11 of 12 cases rejected, unsupported or not established as required; not constructible, not checked: e12-stale-witness" |
| `--case legitimate-change` with the same `--eval` and `--baseline` | 0 | Same PASSED line as the recorded console |
| `--case stale-dependency` on the synthetic set (e13 as `harness_error`) | 1 | "STAGE11_NOT_ESTABLISHED: e13-readme-only not constructible" |

NOT RUN: `--case report` on the edited copy. That case can write files into the evaluation
directory. The diff does not touch `build()` or `markdown()`. NOT RUN: any check of the
file at its final repository path.

---

## A52 — `proposals/incremental-verification/exit_stage_11.py` lines 18 and 181-182: defaults name directories that do not exist

**Defect.** Line 18 sets `REPO` to `parents[1]`. From `proposals/incremental-verification/`
that is `<repository>/proposals`, not the repository root. Lines 181-182 default to
`results/stage11/eval-0001` and `results/stage11/eval-pr27-0001`. The docstring (lines 4-5)
names the same defaults and the path `scripts/exit_stage_11.py`.

**Evidence re-checked today.**

- Lines 4-5, 18 and 181-182 read as described.
- `scripts/exit_stage_11.py` does not exist in the working tree.
- `results/stage11/` holds `eval-0001-aborted-node-path` and
  `eval-pr27-0001-aborted-disk-full`. It holds no `eval-0001` and no `eval-pr27-0001`.
  The final runs are `eval-0007` and `eval-pr27-0003`.
- `results/stage11/exit-console.txt` shows each recorded command with explicit `--eval`
  and `--baseline`.
- I did not run the script with defaults. The fail-closed result (`OSError` to
  `STAGE11_NOT_ESTABLISHED`, exit 1) follows from lines 184-191.

**Impact.** Small. A run with defaults fails closed. No false pass is possible. The file
is a preserved copy of a script written for `scripts/`, where `parents[1]` was correct.

**Recommendation.** Do not edit the file in place for this finding alone; the audit
verdict is "no fix". If the owner approves the A51 new revision, include the A52 hunks:
both arguments become required and the unused `REPO` line goes. Required arguments avoid
a new default that names a recorded run directory (the A20 defect class). The alternative
is `parents[2]` plus defaults `eval-0007` and `eval-pr27-0003`; I do not recommend it,
because `--case report` writes into the evaluation directory when the report is absent.

**Exact diff.** The A52 hunks are in the A51 diff above: `@@ -2,7 +2,7 @@`,
`@@ -15,7 +15,6 @@` and `@@ -178,8 +187,8 @@`.

**A change invalidates, and steps to authorize.** The same as A51.

**Check that shows the fix works.** RUN today on the edited scratch copy:
`python3 -I -B <copy> --case stale-dependency` with no `--eval` exits 2 (argparse usage
error, before any file access). `grep -n REPO` on the copy finds no remaining use of the
name as a variable. NOT RUN: any check at the final repository path.

---

## Commands run for this proposal

All commands ran on 2026-11-09. None changed a file outside the scratchpad and this
proposal file. Copies and diffs are under the session scratchpad `work/scripts-late/`.

| Command | Actual exit |
| --- | --- |
| Read seven audit items (`python3 -B`) | 0 |
| sha256, line counts and lock/manifest greps for the targets | 0 |
| Record counts for Stage 10, Stage 11 and Stage 5 (`python3 -B`, read only) | 0 |
| Copy five targets to `a/` and `b/` | 0 |
| Edit the `b/` copies (`python3 -B edit.py`) | 0 |
| `ast.parse` on four edited Python copies | 0, 0, 0, 0 |
| `diff -u` for five files | 1 each (differences found, as intended) |
| Unchanged Stage 11 copy, `--case stale-dependency`, eval-0007 | 0 |
| Edited Stage 11 copy, `--case stale-dependency`, eval-0007 | 0 |
| Edited Stage 11 copy, `--case legitimate-change`, eval-0007 | 0 |
| Edited Stage 11 copy, no `--eval` | 2 |
| Edited Stage 11 copy, synthetic set | 1 |
| Unchanged Stage 11 copy, synthetic set | 0 |
| Edited Stage 10 copy, `--case report`, no `--run` | 2 |
| Render-sentence string equality check | 0 |
| Post-check: sha256 of the five targets equals the table above | 0 |

NOT RUN: Dafny, any build, any benchmark, `bench/freeze.py`, `bench/run.py`,
`scripts/exit_stage_6.py`, `scripts/exit_stage_10.py` on a real run,
`scripts/render_spec_report.py`, `scripts/benchmark_reuse.py`, any lock check, git, network.
