# Proposal: gate-core defects in protected and pinned files

Date: 2026-11-09. Source: repository audit, confirmed findings 0, 1, 2, 3, 4, 11
and the gate part of finding 6.

Status: PROPOSAL ONLY. No target file was changed. Each item needs owner approval
before any edit. All target files are under `gate/**`, which is protected.

## How to read this file

- Each diff is a real `diff -u` output. The author copied the target file to a
  scratch directory, edited the copy, and compared it with the repository file.
- Each edited Python copy passed `ast.parse` (actual exit 0). That is a syntax
  check only. No gate, test, proof or Dafny command ran.
- Every check in a "Check" section is NOT RUN. Its expected result is a
  prediction, not a result.
- Line numbers refer to the files as they are on 2026-11-09.

## Pins that a change invalidates

The author re-checked these pins today with `grep` and `shasum -a 256`. The
current digests match the pinned values.

| File | Current sha256 (first 16 hex) | `gate/provenance/implementation.lock` | `proposals/untrusted-swarm-20261104/FREEZE.json` |
| --- | --- | --- | --- |
| `gate/incremental.py` | `486456f8d190366c` | not listed | line 30 |
| `gate/core.py` | `bf8f0a54a149c052` | line 17 | line 26 |
| `gate/booking.py` | `cd7ec962a978ce46` | not listed | line 24 |
| `gate/refund.py` | `da370619a34d64d1` | line 30 | line 44 |
| `gate/pr_check.py` | `ff2f50b4943163ae` | not listed | line 32 |
| `gate/post_pr_report.py` | `afe7b82120f04c44` | not listed | line 31 |
| `gate/README.md` | `4d68715188cd0e2e` | not listed | line 17 |

Other effects that apply to every item:

- `FREEZE.json` has its own digest in
  `proposals/untrusted-swarm-20261104/FREEZE.sha256`. A new freeze needs a new
  `FREEZE.sha256`. The owner can instead keep the old freeze as history and
  record that the tree moved past it.
- Records under `proposals/refund-executable-feasibility/**` contain the current
  digests of all seven files. Those records are history. Do not rewrite them.
  They will no longer match the tree after a change.
- `gate/provenance/implementation.lock` has sha256 `5f78da2142699d51...`.
  The provenance workflows receive that value as the approved implementation
  digest. A change to `gate/core.py` or `gate/refund.py` needs a new lock, a new
  lock digest and a new owner approval of that digest. Earlier lock copies under
  `proposals/provenance*/` also hold the old digests; they are history.
- `gate/core.py` is in `framework_paths()` (`gate/core.py:42-49`). Its digest is
  a trusted input in each evidence bundle. `gate/booking.py` and `gate/refund.py`
  are trusted inputs of their own bundles (`gate/booking.py:116`,
  `gate/refund.py:52`). After a change, a `--check-evidence` replay of an older
  bundle will not match. The author did not list every stored bundle.
- `spec.lock` does not list any of these files (grep, no match).
- The author did not search `results/` or `build/` for digests. Uncertain: other
  records there can also hold these digests.

Items A2 and A3 change the same file. Items A1 and A11 change `gate/refund.py`.
The author confirmed that the separate diffs apply together with `patch`
(actual exit 0). Approve them together where possible. One re-pin per file is
then sufficient.

---

## A0: incremental gate does not reject Dafny `@` attributes

File: `gate/incremental.py`, line 81. Severity: medium.

Defect. The comment on line 79 says that the incremental scope has no
user-controlled tool or caching attributes. Line 81 rejects only the byte
sequence `{:`. Dafny 4.11 also accepts `@`-prefixed attributes, for example
`@ResourceLimit` or `@IsolateAssertions`. The gate does not reject them.

Evidence re-checked today.
- `gate/incremental.py:81` is `if b'{:' in implementation:`.
- `gate/booking.py:66` rejects `b'{:' in remaining or b'@' in remaining`.
- `gate/refund.py:104` rejects `... or b'@' in code`.
- `docs/stage4-change-loop.md:70-71` says "User attributes are excluded from
  this initial implementation scope."
- `grep -c '@' impl/Ledger.dfy` printed 0. The current baseline has no `@` byte.

Impact. A PR candidate can carry `@` attributes that the stated scope excludes.
Not confirmed: that an unsound candidate passes. The author did not run Dafny.
The `dafny audit` step and the required-obligation check still apply. Tool
attributes such as `@ResourceLimit` probably pass those steps; that is a guess.

Proposed diff.

```diff
--- a/gate/incremental.py
+++ b/gate/incremental.py
@@ -78,7 +78,7 @@
         raise Rejected('SOURCE_SCOPE: exact approved include/refinement required; no other includes')
     # Initial incremental scope has no user-controlled tool or caching attributes.
     # This is a conservative byte restriction, not a Dafny parser or proof audit.
-    if b'{:' in implementation:
+    if b'{:' in implementation or b'@' in implementation:
         raise Rejected('SOURCE_SCOPE: user attributes are outside the incremental ledger scope')
     return result
 
```

Side effect. The check is a byte check. An `@` in a comment or string in a
candidate `impl/Ledger.dfy` also causes a rejection. `gate/booking.py` already
applies the same byte rule to `impl/Ledger.dfy`.

Invalidates. The digest of `gate/incremental.py` in `FREEZE.json` line 30. No
entry in `implementation.lock`. The hosted `proof-gate` workflow runs this file
through `gate/pr_check.py`, so the trusted base revision changes.

Owner steps to authorize. Approve the diff. Decide about the freeze (see
"Pins"). Add a negative control: a candidate whose `impl/Ledger.dfy` carries an
`@` attribute. The control location is the owner's decision; the Stage 4
scenario scripts are pinned or protected, so the author proposes no file for it.

Check (NOT RUN). Run `python3 -B gate/incremental.py --candidate <dir>` on a
candidate whose `impl/Ledger.dfy` has `@ResourceLimit("1e6")` before a lemma.
Expected: exit 1 and `SOURCE_SCOPE: user attributes are outside the incremental
ledger scope`. Then run the approved baseline candidate. Expected: the same
result as before the change.

---

## A1: a broken policy file exits 1 with a traceback, not exit 2

Files: `gate/core.py` lines 26-29, `gate/booking.py` line 123,
`gate/refund.py` line 229. Severity: low.

Defect. `yaml.safe_load` raises `yaml.YAMLError`. `Draft202012Validator.validate`
raises `jsonschema.ValidationError`. `check_schema` raises
`jsonschema.SchemaError`. All three derive directly from `Exception`. No gate
command line catches them. Python prints a traceback and exits 1.
`gate/README.md:40-41` says that exit 1 means rejection and exit 2 reports a
configuration or execution error.

Evidence re-checked today.
- The class hierarchy, printed by the local interpreter (jsonschema 4.21.1):
  `ValidationError -> _Error -> Exception`, `SchemaError -> _Error -> Exception`,
  `YAMLError -> Exception`.
- Handlers: `gate/gate.py:84-89`, `gate/incremental.py:315-322` and `331`,
  `gate/booking.py:201-206`, `gate/refund.py:307-312`. Each catches `Rejected`
  and `(OSError, ValueError, KeyError, RuntimeError, ImportError[, ET.ParseError])`.
- In `gate/incremental.py` the exception leaves `main()` before line 324, so
  `operation.json` is not written.

Impact. The path fails closed. A configuration error looks like a rejection.
`gate/pr_check.py` then fails on the missing `operation.json`. No acceptance
results.

Option A (recommended): convert the errors to `RuntimeError('POLICY_ERROR: ...')`
at the three load sites. `RuntimeError` already maps to exit 2 in all four
command lines. `gate/core.py` already uses the `POLICY_ERROR` prefix on line 35.

```diff
--- a/gate/core.py
+++ b/gate/core.py
@@ -4,7 +4,7 @@
 The CLI also requires a fresh backend run before accepting an imported bundle.
 """
 
-from jsonschema import Draft202012Validator
+from jsonschema import Draft202012Validator, SchemaError, ValidationError
 import yaml
 
 from common import ROOT, Rejected, digest, read_json, relative
@@ -23,10 +23,15 @@
 
 def load_policy(tier):
     path = ROOT / 'policy/tiers.yaml'
-    policy = yaml.safe_load(path.read_text())
     schema = read_json(ROOT / 'schemas/policy.schema.json')
-    Draft202012Validator.check_schema(schema)
-    Draft202012Validator(schema).validate(policy)
+    try:
+        policy = yaml.safe_load(path.read_text())
+        Draft202012Validator.check_schema(schema)
+        Draft202012Validator(schema).validate(policy)
+    except (yaml.YAMLError, SchemaError, ValidationError) as error:
+        # A broken policy or policy schema is a configuration error, not a rejection.
+        raise RuntimeError('POLICY_ERROR: invalid policy/tiers.yaml or policy schema: '
+                           + (getattr(error, 'message', None) or str(error))) from error
     if tier not in policy['tiers']:
         raise Rejected('POLICY_TIER: unknown code tier ' + tier)
     for name, rules in policy['tiers'].items():
```

```diff
--- a/gate/booking.py
+++ b/gate/booking.py
@@ -97,7 +97,7 @@
 
 def main():
     versions = check_dependencies()
-    from jsonschema import Draft202012Validator
+    from jsonschema import Draft202012Validator, SchemaError, ValidationError
     from core import framework_paths, snapshot, make_bundle, validate_evidence
     parser = argparse.ArgumentParser(description=__doc__)
     parser.add_argument('--evidence', default='build/booking-evidence.json')
@@ -120,7 +120,11 @@
     expected = identity()
     trusted = {name: value for name, value in before.items() if name not in SOURCES}
     policy = read_json(ROOT / 'policy/booking.yaml')
-    Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
+    try:
+        Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
+    except (SchemaError, ValidationError) as error:
+        raise RuntimeError('POLICY_ERROR: invalid policy/booking.yaml or policy schema: '
+                           + error.message) from error
     rules = policy['tiers']['critical']
     policy_id = {'id': policy['id'], 'version': policy['version'], 'tier': 'critical',
                  'sha256': digest((ROOT / 'policy/booking.yaml').read_bytes())}
```

```diff
--- a/gate/refund.py
+++ b/gate/refund.py
@@ -214,7 +214,7 @@
     try:
         versions = check_dependencies()
         from core import snapshot, make_bundle, validate_evidence
-        from jsonschema import Draft202012Validator
+        from jsonschema import Draft202012Validator, SchemaError, ValidationError
         pins, executables = prepare()
         expected = identity(args.tier)
         paths = [ROOT / name for name in (*APPROVED, *COMMON_INPUTS, *SOURCE_FILES)]
@@ -226,7 +226,11 @@
         source_names = {entry['path'] for entry in expected['source_manifest']}
         trusted = {name: sha for name, sha in before.items() if name not in source_names}
         policy = read_json(ROOT / 'policy/refund.yaml')
-        Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
+        try:
+            Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
+        except (SchemaError, ValidationError) as error:
+            raise RuntimeError('POLICY_ERROR: invalid policy/refund.yaml or policy schema: '
+                               + error.message) from error
         rules = policy['tiers'][args.tier]
         method = 'source_proof' if args.tier == 'critical' else 'property_tested'
         claims = CLAIMS if args.tier == 'critical' else TEST_CLAIMS
```

Option B: add a final `except Exception` that prints `GATE_ERROR` and exits 2 in
`gate/gate.py`, `gate/incremental.py`, `gate/booking.py` and `gate/refund.py`.
It covers unknown exception types but hides programming errors behind a short
message, and it changes four files. The author built no diff for option B.

Residual, not fixed by option A. `validate_schema` (`gate/core.py:15`) also calls
`check_schema` on the evidence schema without a handler. A broken
`schemas/evidence.schema.json` would still exit 1. The owner can extend the fix.

Invalidates. `implementation.lock` lines 17 and 30 and the lock digest.
`FREEZE.json` lines 24, 26 and 44. The framework trusted-input digest in each
new evidence bundle changes, so stored bundles do not replay byte-identically.

Owner steps to authorize. Approve the diff. Regenerate and approve
`gate/provenance/implementation.lock`. Pass the new lock digest to the
provenance workflows. Re-run the gates that produce the stored bundles the
owner still relies on, and record actual exit codes.

Check (NOT RUN). In a scratch copy of the repository, make `policy/tiers.yaml`
malformed YAML. Run `python3 -B gate/gate.py --impl impl/Ledger.dfy --evidence
build/a1.json`. Expected: `GATE_ERROR: POLICY_ERROR: ...` and exit 2, with no
traceback. Repeat with valid YAML that violates the schema. Repeat for
`gate/booking.py` and `gate/refund.py` with a schema-invalid policy file. Then
run the unchanged tree and confirm that the accept path gives the same result
as before. Do not edit the real `policy/**` files for this check.

---

## A2: `pr_check.py` and `post_pr_report.py` let `Rejected` and `TypeError` exit 1

Files: `gate/pr_check.py` lines 13 and 113, `gate/post_pr_report.py` lines 10
and 91. Severity: low.

Defect. Both scripts catch `(OSError, RuntimeError, ValueError, KeyError)`.
`common.read_json` raises `Rejected` on a duplicate key or a non-JSON number.
`Rejected` derives from `Exception` (`gate/common.py:10`). A wrongly typed event
or receipt field raises `TypeError`. Both end the process with a traceback and
exit 1.

Evidence re-checked today. `gate/pr_check.py:113` and
`gate/post_pr_report.py:91` contain the clause above. `gate/pr_check.py:107`
returns the gate exit code, where 1 means that the gate rejected the candidate.

Impact. An internal error has the same exit code as a rejection. The path fails
closed: no `receipt.json` and no `report_ready=true` result. Reachability is
low, because the trusted gate writes the JSON inputs.

Proposed diff.

```diff
--- a/gate/pr_check.py
+++ b/gate/pr_check.py
@@ -10,7 +10,7 @@
 import subprocess
 import sys
 
-from common import ROOT, canonical, digest, read_json
+from common import ROOT, Rejected, canonical, digest, read_json
 
 
 def git_head(directory):
@@ -110,6 +110,6 @@
 if __name__ == '__main__':
     try:
         sys.exit(main())
-    except (OSError, RuntimeError, ValueError, KeyError) as error:
+    except (OSError, RuntimeError, ValueError, KeyError, TypeError, Rejected) as error:
         print(str(error), file=sys.stderr)
         sys.exit(2)
```

```diff
--- a/gate/post_pr_report.py
+++ b/gate/post_pr_report.py
@@ -7,7 +7,7 @@
 import sys
 import urllib.request
 
-from common import ROOT, digest, read_json
+from common import ROOT, Rejected, digest, read_json
 from backends.dafny import CLAIMS, claim_statements
 
 
@@ -88,6 +88,6 @@
 if __name__ == '__main__':
     try:
         sys.exit(main())
-    except (OSError, RuntimeError, ValueError, KeyError) as error:
+    except (OSError, RuntimeError, ValueError, KeyError, TypeError, Rejected) as error:
         print(str(error), file=sys.stderr)
         sys.exit(2)
```

Invalidates. `FREEZE.json` lines 31 and 32. No entry in `implementation.lock`.
`.github/workflows/proof-gate.yml` lines 48 and 85 run these files from the
trusted base, so the trusted base revision changes.

Owner steps to authorize. Approve the diff. Decide about the freeze. Authorize
one hosted `proof-gate` run after the change reaches the base branch.

Check (NOT RUN). Run `gate/pr_check.py` with `GITHUB_EVENT_PATH` set to a JSON
file that has a duplicate key. Expected: one error line and exit 2, no
traceback. Repeat with an event where `pull_request` is a string. Expected:
exit 2. Repeat both for `gate/post_pr_report.py`. No network call is reached in
these cases, because each fails before the first API request; confirm that in
the code before the run.

---

## A3: `pr_check.py` can read a stale `operation.json`

File: `gate/pr_check.py`, lines 56 and 69. Severity: low.

Defect. `pr_check.py` uses the fixed work path `build/pr/check` and does not
remove it. When that directory exists, `gate/incremental.py:302-304` raises
`Rejected('OUTPUT_SCOPE: ...')` before its `try` block. The handler on lines
331-333 exits 2 and writes no `operation.json`. `pr_check.py:69` then reads the
`operation.json` of the earlier run. Line 70 compares only `exit_code`. If the
earlier run also ended with exit 2, the comparison passes.

Evidence re-checked today. The lines above are as described. The author did not
run the scripts.

Impact. `pr_check.py` writes a receipt whose `operation` and `result` come from
the earlier run, with the revision and run ID of the current run. The result
stays `error` with exit 2, so no false acceptance is possible. The path needs a
reused workspace. The hosted workflow was not checked for workspace reuse.

Proposed diff.

```diff
--- a/gate/pr_check.py
+++ b/gate/pr_check.py
@@ -54,6 +54,10 @@
     folder.mkdir(parents=True, exist_ok=True)
     evidence = folder / 'evidence.json'
     work = folder / 'check'
+    if work.exists() or evidence.exists():
+        # incremental.py refuses an existing work directory before it writes
+        # operation.json. Do not read a record from an earlier run.
+        raise RuntimeError('RESULT_ERROR: stale build/pr state; use a fresh workspace')
     command = [sys.executable, 'gate/incremental.py', '--profile', 'linux',
                '--candidate', str(candidate), '--evidence', str(evidence.relative_to(ROOT)),
                '--work', str(work.relative_to(ROOT))]
```

The check fails closed and deletes nothing. That matches the fresh-directory
rule in `gate/incremental.py`. An operator must remove `build/pr` before a
local repeat run. Alternative: remove `build/pr` automatically. The author does
not recommend it, because it deletes records of an earlier run.

Invalidates. `FREEZE.json` line 32 (same file as A2). No entry in
`implementation.lock`.

Owner steps to authorize. Approve the diff, preferably with A2. Decide about
the freeze. Authorize one hosted `proof-gate` run.

Check (NOT RUN). In a local test checkout pair, run `gate/pr_check.py` two times
without removing `build/pr`. Expected second run: `RESULT_ERROR: stale build/pr
state; use a fresh workspace`, exit 2, and an unchanged `receipt.json`
timestamp. Then remove `build/pr` and run again. Expected: the same result as a
first run.

---

## A4: `gate/README.md` describes an older scope

File: `gate/README.md`, lines 48-59 and 135-137. Severity: low.

Defect. Line 137 says "Trusted PR baselines and signed provenance remain
later-stage work." The directory now holds `incremental.py`, `pr_check.py`,
`post_pr_report.py`, `approval.py`, `approvals/`, `booking.py`, `refund.py` and
`provenance/`. The Responsibilities list names none of them.

Evidence re-checked today. The author read lines 30-140 of the README and the
docstring and exit handler of each listed file.

Impact. A reader gets a wrong picture of the current gate files and of their
exit codes. No runtime effect.

Proposed diff. The wording states only what the author read in the code today.
It makes no claim about what `provenance/` establishes.

```diff
--- a/gate/README.md
+++ b/gate/README.md
@@ -58,6 +58,31 @@
 - `common.py` handles canonical JSON, hashes, paths, and duplicate-key rejection.
 - `dependencies.py` checks installed validator versions and pinned file content.
 
+Later stages added more files to this directory. The sections below do not
+describe them. Read each file's docstring and the linked document.
+
+- `incremental.py` checks a ledger candidate against the trusted checkout with
+  Dafny verification snapshots. Exit 0 means accepted, exit 1 rejected, exit 2
+  error. It writes `operation.json` in its work directory. An output-scope
+  error exits 2 before that file exists. See
+  [docs/stage4-change-loop.md](../docs/stage4-change-loop.md).
+- `approval.py` is a library with no command line. It binds a protected ledger
+  spec change to an exact record in `approvals/`. `incremental.py` calls it and
+  rejects a protected change that has no matching record.
+- `pr_check.py` runs `incremental.py` for an exact pull-request revision and
+  writes an operational receipt. It returns the gate exit code (0, 1 or 2). It
+  reports its own handled errors with exit 2.
+- `post_pr_report.py` publishes a bounded comment and commit status from that
+  receipt in a separate job. Exit 0 means that it published the report. It
+  reports handled errors with exit 2. Its exit code is not the gate result.
+- `booking.py` and `refund.py` are separate gates for the booking and refund
+  contracts. Each uses the exit 0, 1 and 2 convention above. See
+  [docs/booking.md](../docs/booking.md) and
+  [docs/stage8-refund.md](../docs/stage8-refund.md).
+- `provenance/` holds research provenance tooling with its own
+  `implementation.lock` and its own exit codes. This document makes no claim
+  about what that tooling establishes.
+
 The backend supplies the current artifact identity, approved claims, input file
 set, and checker results. The core does not accept artifact identity from the
 submitted evidence. Evidence data never selects executable Python code.
@@ -134,7 +159,10 @@
 
 This remains a trusted local gate with unsigned evidence. Its files and policy
 must be trusted inputs. Changing both a local spec and its lock is not human
-approval. Trusted PR baselines and signed provenance remain later-stage work.
+approval. `approval.py` and the records in `approvals/` bind an approved ledger
+spec change for the incremental gate. Later stages added a PR check and
+research provenance tooling; see Responsibilities. This section describes the
+local `gate.py` path only, and that path has no signed evidence.
 `end_to_end=false` is mandatory here. Source proof does not establish compiled
 binary behavior, deployment, storage, concurrency, or whole-service correctness.
 
```

Dependencies and limits of this wording.
- The `pr_check.py` and `post_pr_report.py` entries say "handled errors". Until
  A2 is applied, some errors still exit 1.
- The author did not verify that the three linked documents are current.
- The statement about signed evidence covers the `gate.py` path only.

Invalidates. `FREEZE.json` line 17. No entry in `implementation.lock`. No
runtime digest: the README is not a trusted input of any gate the author read.

Owner steps to authorize. Approve or reword the text. Decide about the freeze.

Check (NOT RUN). Read the rendered file. Confirm that each relative link
resolves. Compare each entry with the module docstring and exit handler.

---

## A11: a killed refund gate run leaves a lock that blocks later runs

File: `gate/refund.py`, lines 209-213 and 300-301. Severity: low.

Defect. Line 212 creates `build/refund-gate.lock` with `open('x')`. The only
removal is `finally: lock_path.unlink()` on line 301. A SIGKILL, power loss or
host crash skips the `finally`. Each later run then raises `FileExistsError`.
Line 310 reports it as `GATE_ERROR` with exit 2. Line 209 has already deleted
the earlier output file of that run. The lock holds no PID and no time.

Evidence re-checked today. The lines above are as described. `grep` finds
`refund-gate.lock` in `gate/refund.py:211` and `unsure.md:4530` only (outside
`proposals/`, `results/` and `build/`). No document explains recovery.
`build/refund-gate.lock` is absent today (`ls`), so the defect is latent.

Impact. Fail-closed. No false `ACCEPTED` result is possible. Recovery is manual
removal of one file under `build/`. `unsure.md` line 4530 (F5) records a race on
the same lock between `refund-proof` and `refund-tests`.

This fix is a design decision. Options:

1. Documentation only. Tell operators to remove `build/refund-gate.lock` after
   a killed run. No gate change, no re-pin. The defect stays.
2. Write the PID into the lock file and report `GATE_LOCKED` with that PID.
   Never remove the lock automatically, because a PID can be reused. Recovery
   stays manual but becomes clear.
3. Hold an OS lock (`fcntl.flock`) on the open lock file for the whole run. The
   OS releases it when the process ends, including after a kill. The lock file
   stays in place and its presence alone blocks nothing.

Two separate decisions:

- Order. The finding proposes to take the lock before `output.unlink`. The
  author recommends no change of order. Line 208 states the rule "Never leave a
  stale passing bundle after a failed recheck." A run that is locked out exits
  2. If the lock came first, that run would leave an older passing bundle at
  its output path.
- Blocking. A blocking lock would remove the F5 race, but a run could then wait
  without limit. The diff below does not block. The F5 behavior stays: the
  second concurrent run exits 2.

Recommendation: option 3, same order, non-blocking. Candidate diff for that
option only:

```diff
--- a/gate/refund.py
+++ b/gate/refund.py
@@ -6,6 +6,7 @@
 """
 
 import argparse
+import fcntl
 from pathlib import Path
 import platform
 import re
@@ -209,8 +210,14 @@
     output.unlink(missing_ok=True)
     (ROOT / 'build').mkdir(exist_ok=True)
     lock_path = ROOT / 'build/refund-gate.lock'
-    with lock_path.open('x'):
-        pass
+    # The OS releases this lock when the process ends, including after a kill.
+    # The lock file stays in place; its presence alone does not block a run.
+    lock = lock_path.open('a')
+    try:
+        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
+    except BlockingIOError:
+        lock.close()
+        raise RuntimeError('GATE_LOCKED: another refund gate run holds build/refund-gate.lock')
     try:
         versions = check_dependencies()
         from core import snapshot, make_bundle, validate_evidence
@@ -298,7 +305,7 @@
         print('ACCEPTED: ' + ' '.join(claims) + '; ' + method + '; end_to_end=false')
         return 0
     finally:
-        lock_path.unlink()
+        lock.close()
 
 
 if __name__ == '__main__':
```

Notes on the candidate diff.
- Python opens files as non-inheritable, so the Dafny and Node child processes
  do not hold the lock. The author did not test that here.
- `flock` is advisory. It can behave differently on some network file systems.
- `fcntl` does not exist on Windows. The author did not check whether any
  supported platform is Windows.
- A lock file left by the old code no longer blocks a run.
- The error text is `GATE_ERROR: GATE_LOCKED: ...` with exit 2.

Invalidates. `implementation.lock` line 30 and the lock digest. `FREEZE.json`
line 44. `gate/refund.py` is a trusted input of the refund bundles
(`gate/refund.py:52`), so stored refund evidence does not replay
byte-identically. If a ratification record binds the current refund gate
digest, it needs a new record; the author did not search for one.

Owner steps to authorize. Choose the option, the order and blocking behavior.
Approve the final diff. Regenerate and approve `implementation.lock` and pass
the new digest to the provenance workflows. Re-run both refund tiers and record
actual exit codes. Add a new `unsure.md` entry that refers to F5.

Check (NOT RUN). (1) Start `python3 -B gate/refund.py`, send SIGKILL during the
Dafny step, then start it again. Expected: the second run does not report
`GATE_LOCKED`. (2) Start two runs at the same time with different `--evidence`
paths. Expected: one continues, the other prints `GATE_LOCKED` and exits 2.
(3) Run each tier one time alone. Expected: the same result as before the
change.

---

## P6: remove generated bytecode under `gate/` (gate part of finding 6)

Paths: `gate/__pycache__/` and `gate/backends/__pycache__/`.

State re-checked today with `ls -la`:
- `gate/__pycache__/`: `common.cpython-310.pyc` (1639 bytes),
  `core.cpython-310.pyc` (6157 bytes), `dependencies.cpython-310.pyc`
  (1502 bytes). All dated Oct 30 00:12.
- `gate/backends/__pycache__/`: `__init__.cpython-310.pyc` (509 bytes),
  `dafny.cpython-310.pyc` (11290 bytes), `typescript.cpython-310.pyc`
  (5892 bytes). All dated Oct 30 00:12.

Reason. These are generated files, not source and not evidence. `.gitignore`
line 3 ignores `__pycache__/`. `implementation.lock` has no `__pycache__` entry.
`unsure.md` line 4525 (F3) records planted `gate/__pycache__` bytecode as a
local way to replace protected modules. The author did not check whether these
`.pyc` files match their sources. The paths are under protected `gate/**`, so
the author did not delete them.

Proposed action, after owner approval:

```sh
rm -r gate/__pycache__ gate/backends/__pycache__
```

Then run repository Python with `python3 -B` or `PYTHONDONTWRITEBYTECODE=1`.
`gate/booking.py`, `gate/refund.py` and `gate/incremental.py` set
`sys.dont_write_bytecode = True` (grep). `gate/gate.py`, `gate/pr_check.py`
and `gate/post_pr_report.py` do not.

Invalidates. Nothing that the author found. No lock or freeze lists these
paths. If the history of which process wrote them matters, the list above
records names, sizes and times.

Check (NOT RUN). `ls gate/__pycache__ gate/backends/__pycache__` after the
removal. Expected: both paths absent. Run one gate command with `-B` and
confirm that the directories do not return.

---

## Commands the author ran for this proposal

Read-only commands on the repository, plus edits to scratch copies only:
`nl`, `sed -n`, `grep`, `ls`, `shasum -a 256`, `cp` to scratch, `diff -u`,
`patch` on scratch copies, and `python3 -B -c "import ast,..."`. `diff -u`
exited 1 for each diff, which means that the files differ. All other commands
that matter exited 0. No gate, proof, test, build or network command ran.
