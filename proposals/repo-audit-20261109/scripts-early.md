# Repository audit 2026-11-09: proposals for pinned scripts (A12, A13, A14, A15, A17, A18)

Status: PROPOSAL ONLY. Owner approval is necessary. No target file was changed.
Stage authority: none. This file adds no stage, no EXIT and no passing result.

## Common facts

All target files are pinned by SHA-256 in `gate/provenance/implementation.lock`
(a protected `gate/**` file). I re-checked each digest on 2026-11-09 with
`shasum -a 256`. Each current file matches its pin.

| File | Lock line | Pinned and current SHA-256 |
| --- | --- | --- |
| `scripts/audit_stage9_receipts.py` | 49 | `9b51aa0c91af0ff7d23f330d3434479a8ad19d64c3f2c641e5fa1e3d89d08d2c` |
| `scripts/check_stage_4_approval.py` | 53 | `6d3220ccc18d99baf837bdea0bcb2cbf49ea1734142eb4c97e48d9ffb7d3a931` |
| `scripts/check_stage_4_local.py` | 54 | `bf451b3b7c2c704f5ffe2b5c67540418e69d71a1bf1d444b735118ab02d942ae` |
| `scripts/exit_stage_1.py` | 57 | `bf85637155a63f48b737c20f6efdd4e4d9047afe3e1e5a252a3d31f9bc7f807f` |
| `scripts/exit_stage_5.py` | 61 | `048d8083c1e597cc81f076da1b6471acf94a9553bbc15d82bc68cd00bb69c77d` |
| `scripts/exit_stage_6.py` | 62 | `7217f399a6edae0131b1e22a8692c9ec984198b04c1b3e2150cf2c7f12675352` |
| `scripts/stage5_tools.py` | 72 | `b4b8c91223befb850748fe4f07f863065f36888620a90b3d7013842aaaeca781` |

Current `gate/provenance/implementation.lock` SHA-256:
`5f78da2142699d51f4b9b47c41ba3202919196af575fee3ae67bed7f7ad264b0`.

Every script edit below has the same base cost:

1. The file digest changes. `gate/provenance/common.py` `context()` (line 134)
   then rejects with `IMPLEMENTATION_INPUT:<path>` until the lock entry changes.
2. A lock edit changes the lock digest. Each caller that passes the lock digest
   to `context()` (for example `.toolchain/stage9/controller.json` through
   `scripts/exit_stage_9.py` line 41) then needs the new digest.
3. Eight lock copies under `proposals/` also name these scripts
   (`provenance-hosted-v3`, `-v31`, `-v32`, `-v33`, `approval-integrity/admission-v34`,
   `token-compat-v35/build`, `token-compat-v35/build-variant-a-visible-ascii`,
   `deploy-perms-v36/build`). They are historical candidates. I did not check
   whether a tool compares them with live scripts. Uncertain.

The owner must authorize: the script edit, the lock entry update through the
approved lock procedure, and the propagation of the new lock digest.

All diffs were built from scratch copies with `diff -u`. Each edited Python copy
parses (`ast.parse` exit 0). No edited copy was executed. All checks are NOT RUN.

Suggested order if the owner approves: A12 and A14 together (same file, one
re-pin), then A15, then A13. A17 and A18 need a design decision first.

---

## A12 — `scripts/exit_stage_5.py` line 214: a rerun overwrites recorded Stage 5 evidence

**Defect.** `main()` preserves only `build/stage5/<case>` (line 196). It then
writes `results/stage5/<case>.json` unconditionally (lines 212-214). The write
also occurs after the failure branch (line 206). `mutations()` rewrites
`results/stage5/mutants/<name>.dfy` at line 135 before any outcome is known.

**Evidence re-checked today.**
- Lines 195-196, 205-206, 212-214 and 130-135 read as stated.
- `scripts/stage5_tools.py` `preserve()` (lines 23-31) moves only the build folder.
- `results/stage5/vacuity.json`, `mutations.json` and `mutants/` exist.
- `docs/spec-quality.md` lines 45-50 list both commands under "Reproduce".
- `scripts/exit_stage_4.py` line 205 refuses a rerun when its report exists.
- Earlier records exist only as hand-named copies (`vacuity-attempt1.json`,
  `mutations-before-replay.json` and others).

**Impact.** Low, latent. A rerun on a host without the Dafny toolchain replaces a
passing record with a `result: failed` record. No record was lost so far.

**Recommended fix: refuse to run when the record exists.** This matches
`exit_stage_4.py`. The script never moves recorded evidence by itself.

```diff
--- a/scripts/exit_stage_5.py
+++ b/scripts/exit_stage_5.py
@@ -192,6 +192,14 @@
     parser = argparse.ArgumentParser(description=__doc__)
     parser.add_argument('--case', choices=('vacuity', 'mutations'), required=True)
     case = parser.parse_args().case
+    prior = [ROOT / 'results/stage5' / (case + '.json')]
+    if case == 'mutations':
+        prior.append(ROOT / 'results/stage5/mutants')
+    existing = [str(path.relative_to(ROOT)) for path in prior if path.exists()]
+    if existing:
+        print('STAGE_5_REFUSED: preserve the prior Stage 5 record before running again: '
+              + ' '.join(existing), file=sys.stderr)
+        return 1
     folder = ROOT / 'build/stage5' / case
     preserve(folder)
     session = None
```

Resulting SHA-256 (A12 alone): `3a07a21ffe44f3ec81a572b36cdc6e476bfd4988958d01963147b97ac0ff749d`.

**Alternatives.**
- Move the prior record to `results/stage5/history/<n>/` automatically. This keeps
  the documented commands runnable. It makes the script move evidence under
  `results/`, which I do not recommend without an owner rule for that folder.
- Write the new report under `build/stage5/` and make promotion a separate step.
  This is the cleanest design but changes where `render_spec_report.py` reads.

**What the change invalidates.**
- The pin at `implementation.lock` line 61, plus the base cost above.
- `runner_sha256` in `results/stage5/vacuity.json`, `mutations.json` and
  `spec-quality.json` names the old digest. The recorded evidence then describes
  the old runner. A rebind needs a Stage 5 rerun (Dafny) and a
  `render_spec_report.py` rerun. Alternatively the owner accepts the old records
  as historical for runner `048d8083…`.
- The "Reproduce" text in `docs/spec-quality.md` becomes incomplete: the two
  commands exit 1 until the reader moves the prior records. That text is generated
  by `scripts/render_spec_report.py` (line 52 area). That script is also pinned
  (`implementation.lock` line 71), so a text correction needs a second re-pin.

**Check that would show the fix works (NOT RUN).**
With the current records in place, `python3 scripts/exit_stage_5.py --case vacuity`
must exit 1, print `STAGE_5_REFUSED`, leave `results/stage5/vacuity.json`
byte-identical (compare `shasum -a 256` before and after), and create no
`build/stage5-history/vacuity/<n>` entry. The same check applies to `--case mutations`.
In a scratch checkout without the records, the command must proceed as before.

---

## A14 — `scripts/exit_stage_5.py` line 205: gate `Rejected` and `ParseError` are not caught

**Defect.** The handler catches `(OSError, RuntimeError, ValueError, KeyError)`.
`gate/common.py` line 10 defines `class Rejected(Exception)`. It is not in the tuple.
`xml.etree.ElementTree.ParseError` is a `SyntaxError` subclass. It is not in the tuple.

**Evidence re-checked today.**
- Line 200 `Session(folder)` calls `dafny.prepare('impl/Ledger.dfy')`
  (`scripts/stage5_tools.py` line 39). `gate/backends/dafny.py` imports and raises
  `Rejected` (line 14 import; line 205 is one raise site).
- `stage5_tools.py` line 92 calls `ET.parse(report)`.
- Line 196 `preserve(folder)` runs before the `try`.

**Impact.** Low. The process still exits nonzero through a traceback, so no false
pass results. The loss is the failure record: no `result: failed` report and no
`STAGE_5_RESULT` line. The prior build folder has already moved to history.

**Fix.** One file only. The audit proposed an edit to `stage5_tools.py` also. That is
not necessary: `stage5_tools` already puts `gate/` first on `sys.path` and imports
`common`, so `exit_stage_5.py` can import `Rejected` from `common` directly. No
`scripts/common.py` exists (checked). This keeps the `stage5_tools.py` pin intact.

```diff
--- a/scripts/exit_stage_5.py
+++ b/scripts/exit_stage_5.py
@@ -6,9 +6,11 @@
 from pathlib import Path
 import shutil
 import sys
+from xml.etree.ElementTree import ParseError
 
 from stage5_tools import (ROOT, Session, canonical, claim_failures, contract_locations, dafny,
                          diagnostics, digest, message, preserve, require)
+from common import Rejected
 
 
 def replace_once(text, old, new):
@@ -202,7 +204,7 @@
         report.update(vacuity(session) if case == 'vacuity' else mutations(session))
         session.finish()
         report['exit_code'] = 0
-    except (OSError, RuntimeError, ValueError, KeyError) as error:
+    except (OSError, RuntimeError, ValueError, KeyError, Rejected, ParseError) as error:
         report.update(result='failed', exit_code=1, error=str(error))
         print(str(error), file=sys.stderr)
     if session:
```

Resulting SHA-256 (A14 alone): `c4ebbe46289ecea1c8a568f5971832ed9f4120120ad13f2554c1f85d147050c7`.
Resulting SHA-256 (A12 and A14 together): `a882ffe346bcdd9eaabf653e8db4115603759348b056c923331e16fc076800ff`.
The two diffs touch separate hunks. Apply both in one approved change for one re-pin.

**What the change invalidates.** Same as A12: lock line 61 and the `runner_sha256`
binding of the recorded Stage 5 reports. `scripts/stage5_tools.py` stays unchanged.

**Interaction with A12.** With A14 alone, a rejected run now overwrites
`results/stage5/<case>.json` with a failed report (today the traceback occurs
before the write). Apply A14 only together with A12.

**Check that would show the fix works (NOT RUN).** In a scratch checkout (not this
tree), append one byte to `spec/LedgerSpec.dfy` so that `dafny.prepare` raises
`SPEC_LOCK`. Run `python3 scripts/exit_stage_5.py --case vacuity`. Expected: exit 1,
no traceback, a `STAGE_5_RESULT` line with `"result": "failed"`, and a report whose
`error` starts with `SPEC_LOCK`. I did not confirm that this path needs no Dafny
binary before the lock check. Uncertain.

---

## A13 — `scripts/check_stage_4_approval.py` line 71 and `scripts/check_stage_4_local.py` line 114: pass conditions are bare `assert`

**Defect.** `python3 -O` and `PYTHONOPTIMIZE=1` remove `assert` statements.
`check_stage_4_approval.py` then reaches line 86 (`result='passed'`), copies
evidence into `results/stage4/` (line 88) and returns 0 for any gate exit code.
`check_stage_4_local.py` loses its reuse-count checks (lines 114-119).

**Evidence re-checked today.**
- `check_stage_4_approval.py`: asserts at lines 71, 74, 77-80, 82, 85. Handler at
  line 89 catches `AssertionError`.
- `check_stage_4_local.py`: asserts at lines 114-115 and 117-119. Its other checks
  raise `RuntimeError`. The handler at line 139 catches `RuntimeError`.
- `grep` for `PYTHONOPTIMIZE` and `python3 -O` in `scripts/`, `gate/`, `.github/`,
  `docs/` finds nothing.
- `build/stage4-approval` exists, so `check_stage_4_approval.py` refuses a rerun today (line 29-30).

**Impact.** Low. No repository command uses optimize mode. Both scripts are
historical Stage 4 controls. Behavior under plain `python3` does not change, so
the recorded Stage 4 evidence stays valid in content.

```diff
--- a/scripts/check_stage_4_approval.py
+++ b/scripts/check_stage_4_approval.py
@@ -15,6 +15,11 @@
 WORK = ROOT / 'build/stage4-approval'
 
 
+def require(condition, message):
+    if not condition:
+        raise AssertionError(message)
+
+
 def checkout(destination):
     destination.mkdir(parents=True)
     for name in ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github', 'impl', 'proposals'):
@@ -68,21 +73,27 @@
             child = run(command, baseline, name)
             operation = json.loads((baseline / 'build' / name / 'operation.json').read_text())
             report['cases'].append({'name': name, 'operation': operation})
-            assert child.returncode == expected, child.stdout + child.stderr
+            require(child.returncode == expected, child.stdout + child.stderr)
             evidence = baseline / 'build' / (name + '.json')
             if expected:
-                assert not evidence.exists() and operation['error'].startswith('UNAPPROVED_PROTECTED_CHANGE:')
+                require(not evidence.exists() and operation['error'].startswith('UNAPPROVED_PROTECTED_CHANGE:'),
+                        name + ': rejection left evidence or named another error')
             else:
                 bundle = json.loads(evidence.read_text())
-                assert {c['spec_sha'] for c in bundle['claims']} == {
-                    '2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940'}
-                assert bundle['backend_details']['spec_approval']['record'] == 'gate/approvals/fees-v2.json'
-                assert 'Ledger.Apply (correctness)' in operation['snapshots'][1]['checked']
+                require({c['spec_sha'] for c in bundle['claims']} == {
+                    '2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940'},
+                    name + ': claims name another specification')
+                require(bundle['backend_details']['spec_approval']['record'] == 'gate/approvals/fees-v2.json',
+                        name + ': evidence names another approval record')
+                require('Ledger.Apply (correctness)' in operation['snapshots'][1]['checked'],
+                        name + ': Ledger.Apply correctness was not checked')
         first = (baseline / 'build/approved.json').read_bytes()
-        assert first == (baseline / 'build/approved-repeat.json').read_bytes()
+        require(first == (baseline / 'build/approved-repeat.json').read_bytes(),
+                'Evidence differs across identical approved runs')
         command = json.loads(first)['evidence'][0]['reproduce_cmd']
         replay = run(shlex.split(command), baseline, 'literal-replay')
-        assert replay.returncode == 0 and (baseline / 'build/change-evidence.json').read_bytes() == first
+        require(replay.returncode == 0 and (baseline / 'build/change-evidence.json').read_bytes() == first,
+                'The saved reproduction command did not reproduce identical evidence')
         report.update(result='passed', exit_code=0, byte_identical=True,
                       evidence_sha256=digest(first))
         shutil.copyfile(baseline / 'build/approved.json', ROOT / 'results/stage4/approved-local-evidence.json')
```

```diff
--- a/scripts/check_stage_4_local.py
+++ b/scripts/check_stage_4_local.py
@@ -111,12 +111,14 @@
             if name == 'sneaky-assume' and 'assume statement has no {:axiom} annotation' not in fresh.stdout:
                 raise RuntimeError('Missing expected diagnostic for the forbidden assumption')
         if name == 'unchanged':
-            assert case['snapshots'][1]['checked_count'] == 0
-            assert case['snapshots'][1]['reused_count'] == 12
+            if case['snapshots'][1]['checked_count'] != 0 or case['snapshots'][1]['reused_count'] != 12:
+                raise RuntimeError(name + ': unexpected checked/reused counts')
         elif name in ('apply-edit', 'apply-edit-repeat'):
-            assert case['snapshots'][1]['checked'] == [
-                'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']
-            assert case['snapshots'][1]['reused_count'] == 10
+            if case['snapshots'][1]['checked'] != [
+                    'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']:
+                raise RuntimeError(name + ': unexpected checked set')
+            if case['snapshots'][1]['reused_count'] != 10:
+                raise RuntimeError(name + ': unexpected reused count')
     first = (WORK / 'apply-edit-evidence.json').read_bytes()
     second = (WORK / 'apply-edit-repeat-evidence.json').read_bytes()
     if first != second:
```

Resulting SHA-256: `check_stage_4_approval.py`
`03e9362dc411703ddcc954e691e6603ae41422ac10e0e96e0ebd1470e5915879`;
`check_stage_4_local.py`
`d0c7c08a2878ecc351a7a886e021b3be59b64f964ed217008a437c78a95169b6`.

Note: the new messages replace empty `AssertionError` text. The `error` field of a
failed `results/stage4/approval-local.json` therefore changes from `""` to a
sentence. A passing report is unchanged.

**What the change invalidates.** Lock lines 53 and 54, plus the base cost. I found
no recorded Stage 4 result that stores these two script digests, but I did not
search `results/` fully. Uncertain.

**Acceptable alternative.** Make no change. Record the limit instead. The risk is low.

**Check that would show the fix works (NOT RUN).**
`grep -n "^\s*assert " scripts/check_stage_4_approval.py scripts/check_stage_4_local.py`
must print nothing. A full behavioral check needs a scratch checkout, real Dafny
runs and `python3 -O scripts/check_stage_4_approval.py` with one expectation
deliberately wrong; it must exit 1. That needs the toolchain and owner approval.

---

## A15 — `scripts/exit_stage_1.py` line 94: the named-claim check is a substring test

**Defect.** `require(expected in rejected.stderr, ...)` searches all of stderr for
a token such as `C1`. The gate dumps the full Dafny output to stderr before the
verdict (`gate/backends/dafny.py` line 204). When claim mapping returns nothing,
the verdict names every claim (line 205, `' '.join(claims or CLAIMS)`). The test
then passes for any expected claim. Lines 95-97 check only
`VERIFICATION_REJECTED` and `Dafny exit 4`.

**Evidence re-checked today.**
- Lines 77-78, 94-97 of `exit_stage_1.py` and lines 203-206 of `dafny.py` read as stated.
- `gate/gate.py` lines 84-85 print the `Rejected` text to stderr as one line.
- Local logs `build/stage1/planted-bugs/*-gate.log` (dated Oct 26; build output,
  not committed evidence) show real mappings: `self_transfer` → `C1 C5`,
  `off_by_one` → `C4`, `retry_double` → `C1 C3`, `sneaky_assume` →
  `AUDIT_REJECTED: C1 C2 C3 C4 C5 …`.

**Impact.** Low. The recorded result is not wrong. The check cannot detect a
regression of the claim mapping.

**Fix.** Parse the verdict line. Require the expected claim in the listed set.
Reject the all-claims fallback. For `sneaky_assume`, require a line that starts
with `AUDIT_REJECTED: ` (that verdict names all claims by design, so no set test).

```diff
--- a/scripts/exit_stage_1.py
+++ b/scripts/exit_stage_1.py
@@ -91,10 +91,18 @@
                 evidence = 'build/stage1/planted-bugs/' + name + '.evidence.json'
                 rejected = gate(name + '-gate', implementation, evidence)
                 require(rejected.returncode == 1, name + ': gate did not reject as expected')
-                require(expected in rejected.stderr, name + ': expected claim/rule was not named')
-                if name != 'sneaky_assume':
-                    require('VERIFICATION_REJECTED' in rejected.stderr and 'Dafny exit 4' in rejected.stderr,
-                            name + ': rejection was not the expected verifier result')
+                lines = rejected.stderr.splitlines()
+                if name == 'sneaky_assume':
+                    require(any(line.startswith(expected + ': ') for line in lines),
+                            name + ': expected claim/rule was not named')
+                else:
+                    prefix, suffix = 'VERIFICATION_REJECTED: ', ' not established; Dafny exit 4'
+                    verdicts = [line for line in lines if line.startswith(prefix) and line.endswith(suffix)]
+                    require(len(verdicts) == 1, name + ': rejection was not the expected verifier result')
+                    named = verdicts[0][len(prefix):-len(suffix)].split()
+                    require(expected in named, name + ': expected claim/rule was not named')
+                    require(set(named) != {'C1', 'C2', 'C3', 'C4', 'C5'},
+                            name + ': gate named every claim; claim mapping was not exercised')
                 require(not (ROOT / evidence).exists(), name + ': rejection left accepted evidence')
 
         elif case == 'spec-lock':
```

Resulting SHA-256: `e845026e3d4b272c178ab0562fc22e50cd3af6b036d92721ef61321c1b9846e7`.

**Risk.** The new check fails Stage 1 if a planted bug legitimately fails all five
claims, or if stderr holds two verdict lines. Neither occurs in the local logs.
A read-only simulation of the new parse on those four logs (run today, exit 0)
gave one verdict line each and the expected claim in each set. This is a
simulation on old build logs, not a Stage 1 run.

**What the change invalidates.** Lock line 57, plus the base cost.
`results/stage1.json`, `results/stage2.json` and `results/stage3.json` cite the
command `python3 scripts/exit_stage_1.py --case planted-bugs`. I did not check
whether they store the script digest. If they do, they describe the old script.

**Check that would show the fix works (NOT RUN).**
1. `python3 scripts/exit_stage_1.py --case planted-bugs` must exit 0 (needs Dafny).
2. Negative control in a scratch checkout: make `failed_claims` in
   `gate/backends/dafny.py` return an empty list. The same command must then exit 1
   with "gate named every claim". The current script would exit 0 there.

---

## A17 — `scripts/audit_stage9_receipts.py` line 29: superseded lock digest; the script cannot run

**Defect.** Line 29 calls
`context('6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa')`.
The current lock digest is `5f78da21…d264b0`. `context()` raises
`Rejected('UNAPPROVED_IMPLEMENTATION')` (`gate/provenance/common.py` line 129).
Lines 27-28 create `--output` and `--work` before that call. A run leaves two
empty directories and an uncaught traceback.

**Evidence re-checked today.**
- Lines 27-29 and 85 of the script read as stated.
- `shasum -a 256 gate/provenance/implementation.lock` gives `5f78da21…d264b0`.
- `ROADMAP.md` line 3587 records the old digest as rejected (exit 1).
- `docs/stage9-signing-preparation-audit.md` lines 114-121 still give the command
  and call exit 1 "the expected current diagnostic result".
- I did not run the script.

**Impact.** Low. The exit code is still 1, but for a different cause: the lock
mismatch, not the three unexpected non-rejections recorded at `ROADMAP.md`
line 3530. The document therefore misleads a reader who reproduces.

**This is a design decision. No diff is given.**

- **Option A — make the script runnable.** Add a required
  `--implementation-sha256` argument (as `exit_stage_9.py` reads it from
  `controller.json`), call `context()` before the two `mkdir` calls, and update
  `reproduce_cmd` at line 85. Cost: lock line 49 re-pin plus the base cost. Note a
  deeper limit: line 35 asserts 579 checked modules against the current lock, and
  the audited validator (`gate/provenance/release.py`) has changed since the
  recorded audit. A run under the current lock audits a different validator. Its
  result would be new evidence, not a reproduction of the recorded exit 1.
- **Option B — declare the script historical (recommended).** Keep the script
  bytes. Add text only to `docs/stage9-signing-preparation-audit.md` after the
  sentence that ends "the exact approved files through `context`.":
  "The script pins implementation lock
  `6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa`. That lock is
  superseded, so the command now stops with `UNAPPROVED_IMPLEMENTATION` (exit 1)
  before it runs any case. The command is historical." Cost: none for the lock.
  The document is a point-in-time record; add text, do not rewrite it. No pin for
  this document was found in `gate/`, `governance/`, `policy/`, `proposals/` or
  `scripts/` by the audit; `results/` was not searched. Uncertain.
- **Option C — no change.** Record the limit in a new `unsure.md` entry only.

**Recommendation.** Option B. The recorded audit is bound to lock `6b43c193…`.
Option A produces a new audit of new code and needs its own approval and scope.

**What a change invalidates.** Option A: lock line 49 and all lock-digest users.
Option B: only a possible unseen pin of the document.

**Check that would show the fix works (NOT RUN).** Option B: read the added
sentence; confirm `shasum -a 256 scripts/audit_stage9_receipts.py` still gives
`9b51aa0c…8d2c`. Option A: with Python 3.10.11, a run with the current lock digest
must pass `context()` and create no directory when the digest is wrong.

---

## A18 — `scripts/exit_stage_6.py` line 63: no script produces `results/stage6/input-identities.json`

**Defect.** `--case report` requires `results/stage6/input-identities.json`
(lines 63-66) and requires its `benchmark_sha256` to equal the digest of
`results/stage6/benchmark.json` (lines 67-68). No checked-in script writes that
file. The same script emits a "Reproduce" text into `docs/reuse-benchmark.md`
(lines 243-247) that lists `python3 scripts/benchmark_reuse.py` and then
`python3 scripts/exit_stage_6.py --case report`. The first command replaces
`benchmark.json` on success (`benchmark_reuse.py` lines 145 and 281). The second
command then fails with "Input identity check names another experiment".

**Evidence re-checked today.**
- Lines 63-68, 179-183 and 243-247 of `exit_stage_6.py` read as stated.
- `grep -rn input-identities scripts gate tests bench docs unsure.md` finds only
  `exit_stage_6.py` lines 63 and 182, `unsure.md` line 1169 (an evidence list) and
  an unrelated Stage 8 path in the lock.
- The recorded file has keys `all_match_frozen_fixture_bytes`, `benchmark_sha256`,
  `checked_input_files` (450), `exit_code` (0), `inputs` (450 entries of
  `{path, sha256}`; first path `build/stage6/run-0004/1-cold-unchanged/v0/All.dfy`),
  `kind` (`postrun_input_identity_check`), `proof_claim` (false), `stage` (6).
- Its `benchmark_sha256` is `18892aa7…c2d3`. `shasum -a 256 results/stage6/benchmark.json`
  today starts with `18892aa7fa93372d`. The recorded state is consistent.
- I did not run the benchmark.

**Impact.** Low for recorded evidence: the current recorded state is consistent.
The documented reproduce path is broken, and the identity file has no
reproducible origin in the repository.

**This is a design decision. No diff is given.**

- **Option A — add a generator and correct the text.** Add a new script, for
  example `scripts/check_stage6_input_identities.py`. It recomputes the 450
  materialized input hashes of the selected run against the frozen fixture bytes
  and writes the file with the schema above. Then change lines 243-247 of
  `exit_stage_6.py` to list the new command between the two existing commands.
  Unknowns that block an exact diff: which bytes count as "frozen fixture bytes"
  for each of the 450 paths, and how the original ad hoc command selected the run.
  I will not invent them. The generator must reproduce the recorded file
  byte-for-byte for run 0004, or it must write to a separate path.
- **Option B — correct the text only.** Change lines 243-247 to state that a fresh
  benchmark run invalidates the report recompute until the input identity check
  is repeated, and that no checked-in command repeats it.
- **Option C — no pinned change (recommended now).** A recorder adds a new
  `unsure.md` entry that states the limit and references the existing entry near
  line 1169. Do Option A later under its own approval if the owner wants a
  reproducible Stage 6.

**Recommendation.** Option C now. Option A is the real repair, but it adds evidence
tooling for a passed stage and has unknown inputs.

**What a change invalidates (Options A and B).**
- Lock line 62 (`exit_stage_6.py`), plus the base cost.
- `results/stage6/report.json` `input_sha256` includes `scripts/exit_stage_6.py`
  (lines 179-183). The recorded report then names the old script.
- The generated `docs/reuse-benchmark.md` changes. `results/stage6/report-replay.json`
  pins it (`output_sha256`, line 38, `db5a292b…`). The report and replay need a
  rerun (`--case report`; no Dafny is evident for that case, not confirmed).
- A hand edit of `docs/reuse-benchmark.md` is not safe: it breaks the replay pin
  and the next report run overwrites it.
- A new script is not in the lock. Whether it must be pinned is an owner decision.

**Check that would show the fix works (NOT RUN).** Option A: run the generator
against the recorded run with output to a scratch path; `cmp` with
`results/stage6/input-identities.json` must exit 0. Then, in a scratch checkout,
run the three documented commands in order; the last must exit 0. Option B:
`python3 scripts/exit_stage_6.py --case report` must exit 0 and the new text must
appear in `docs/reuse-benchmark.md`.

---

## Commands run for this proposal (actual exit codes)

| Command | Exit |
| --- | --- |
| `python3 -B` selection of audit items 12, 13, 14, 15, 17, 18 | 0 |
| `shasum -a 256` on the seven scripts and the lock; `grep -n` of each path in the lock | 0 |
| Read-only `cat`/`sed`/`grep` of the target scripts, `gate/` sources, docs, `ROADMAP.md` lines | 0 |
| `python3 -B work/edit.py` (edits scratch copies only) | 0 |
| `python3 -B -c "import ast,sys;ast.parse(open(sys.argv[1]).read())"` on six edited copies | 0 each |
| `diff -u --label a/<path> --label b/<path>` for six copies | 1 each (differences found, as expected) |
| `python3 -B` simulation of the A15 parse on four local `build/stage1` logs | 0 |
| Dafny, gate runs, stage EXIT scripts, benchmarks, proofs | NOT RUN |
