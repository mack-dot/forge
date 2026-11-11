# Repository audit 2026-11-09: CI workflows and records (UNAPPLIED; awaiting owner approval)

Status: proposal only. No target file is changed. No workflow, build, proof,
install, network, git or hosted operation ran for this proposal.
`end_to_end=false`. Each check that would show a fix works is NOT RUN.

Scope: audit findings A31, A32, A33, A35, A47, A48, A49. The targets are
gate-protected (`gate/incremental.py` line 28 lists `toolchain` and `.github`
in `PROTECTED_DIRS`), proposal-gated (`.github/PULL_REQUEST_TEMPLATE.md`
lines 16-18) or recorded history. The project rule applies: exact diff, plain
reason, then stop for owner approval.

Common facts, re-checked on 2026-11-09:

- `gate/provenance/implementation.lock` has SHA-256
  `5f78da2142699d51f4b9b47c41ba3202919196af575fee3ae67bed7f7ad264b0`.
- That lock lists none of the seven workflow files named below. It lists
  neither `toolchain/linux-pins.json` nor `toolchain/install_ci.py`.
- `spec.lock`, `gate/`, `spec/`, `policy/`, `schemas/`, `toolchain/`, `ROADMAP.md`
  and `unsure.md` contain no SHA-256 or git blob SHA of the target files.
- The directory has no `.git`. All checks read the working tree, not a pushed
  commit. Git blob SHAs below are computed with `hashlib` (`blob <size>\0` +
  bytes), not with git.
- Diffs were built with `diff -u` on copies in the session scratch directory.
  The edited YAML copies load with PyYAML 6.0.1. The edited JSON copy loads.
  No Python file is changed by any diff here.

Summary:

| ID | Target | Kind | Recommendation |
| --- | --- | --- | --- |
| A32 | four Stage 9 dry-run workflows | design decision | Option A (delete), one reviewed change with A31 |
| A31 | `stage9-candidate-dry-run.yml` line 13 | design decision | delete with A32; never change the guard |
| A33 | `stage9-hosted-probe-2.yml` line 119 | design decision | Option A (keep, record as superseded) |
| A35 | `proof-gate.yml` line 43, `toolchain-inventory.yml` line 32 | exact diff, one value missing | apply after the owner supplies the pip wheel digest |
| A47 | U341 packet `records/COMMANDS.json` | corrective addendum | add addendum 1; do not edit the packet |
| A48 | U341 packet `REPORT.md` line 23 | corrective addendum | same addendum |
| A49 | `proposals/provenance-receipt-repair.md` line 132 | design decision | Option A (no edit; record only) |

---

## A32: four Stage 9 dry-run workflows cannot pass on the current tree

Files and lines:

- `.github/workflows/stage9-candidate-dry-run.yml` line 34 (header line 3)
- `.github/workflows/stage9-candidate-dry-run-v2.yml` line 34 (header line 3)
- `.github/workflows/stage9-private-dry-run-v31.yml` line 31 (header line 3)
- `.github/workflows/stage9-private-dry-run-v32.yml` line 31 (header line 3)

Defect: each workflow runs `git apply --check proposals/<dir>/proposed.diff`
on a copy of main. The candidates are installed on main, so the step must fail.
Each header still says "unapplied ... candidate". Each workflow keeps
`workflow_dispatch`.

Evidence re-checked today:

- Lines 34/34/31/31 hold the `git apply --check` commands as stated.
- I parsed the four `proposed.diff` files. Each has `new file mode` targets that
  exist in the tree: `gate/provenance/hosted_setup.py` (all four) and
  `gate/provenance/bootstrap.py` (v31, v32). `git apply` rejects a new-file
  patch when the file exists.
- `FORGE_STAGE9_IMPLEMENTATION` is `f9f09a2f...`, `30880e08...`, `6f3aafe6...`
  and `be23ec85...`. None equals the installed lock digest `5f78da21...`.
- I did not run `git apply --check` today. The task limits forbid git. The
  audit ran it and reports exit 1 for all four. My evidence is the existing
  new-file targets only.

Impact: low. The workflows are one-shot, dispatch-only, `contents: read`, with
no secrets. They fail closed. The harm is dead, misleading entries in the
dispatch list. No recorded result is wrong.

This is a design decision. Options:

- Option A (recommended): delete the four files in one code-owner-reviewed
  change. Run records stay in `ROADMAP.md` (lines 3749-3874 per the audit) and
  `results/stage9/`. Do not edit any `proposals/provenance-hosted*/proposed.diff`.
  Exact operation: `git rm` of the four paths above. The diff is the full
  removal of each file; I did not reproduce it here.
- Option B: keep the files and change only the header comment. Exact diff:

```diff
--- a/.github/workflows/stage9-candidate-dry-run.yml
+++ b/.github/workflows/stage9-candidate-dry-run.yml
@@ -1,6 +1,9 @@
 name: Forge Stage 9 candidate dry run (probe 3)
 
-# Dry run of the unapplied hosted-runner candidate. No signing, no id-token,
+# HISTORICAL. The candidate is installed on main. Do not dispatch this workflow:
+# `git apply --check` now fails by design, and the pinned implementation lock
+# digest is superseded. Run records stay in ROADMAP.md and results/stage9/.
+# Was: dry run of the then-unapplied hosted-runner candidate. No signing, no id-token,
 # no secrets, no release. The installed gate on main is not changed.
 "on":
   workflow_dispatch:
--- a/.github/workflows/stage9-candidate-dry-run-v2.yml
+++ b/.github/workflows/stage9-candidate-dry-run-v2.yml
@@ -1,6 +1,9 @@
 name: Forge Stage 9 candidate dry run v2 (mack-dot)
 
-# Dry run of the unapplied hosted-runner candidate. No signing, no id-token,
+# HISTORICAL. The candidate is installed on main. Do not dispatch this workflow:
+# `git apply --check` now fails by design, and the pinned implementation lock
+# digest is superseded. Run records stay in ROADMAP.md and results/stage9/.
+# Was: dry run of the then-unapplied hosted-runner candidate. No signing, no id-token,
 # no secrets, no release. The installed gate on main is not changed.
 "on":
   workflow_dispatch:
--- a/.github/workflows/stage9-private-dry-run-v31.yml
+++ b/.github/workflows/stage9-private-dry-run-v31.yml
@@ -1,6 +1,9 @@
 name: Forge Stage 9 private dry run v3.1 (no signing)
 
-# Non-signing integration test of the unapplied v3.1 candidate. No OIDC token
+# HISTORICAL. The candidate is installed on main. Do not dispatch this workflow:
+# `git apply --check` now fails by design, and the pinned implementation lock
+# digest is superseded. Run records stay in ROADMAP.md and results/stage9/.
+# Was: non-signing integration test of the then-unapplied v3.1 candidate. No OIDC token
 # permission, no secrets, no signing service, no release, no production workflow.
 "on":
   workflow_dispatch:
--- a/.github/workflows/stage9-private-dry-run-v32.yml
+++ b/.github/workflows/stage9-private-dry-run-v32.yml
@@ -1,6 +1,9 @@
 name: Forge Stage 9 private dry run v3.2 (no signing)
 
-# Non-signing integration test of the unapplied v3.2 candidate. No OIDC token
+# HISTORICAL. The candidate is installed on main. Do not dispatch this workflow:
+# `git apply --check` now fails by design, and the pinned implementation lock
+# digest is superseded. Run records stay in ROADMAP.md and results/stage9/.
+# Was: non-signing integration test of the then-unapplied v3.2 candidate. No OIDC token
 # permission, no secrets, no signing service, no release, no production workflow.
 "on":
   workflow_dispatch:
```

  Option B leaves four dispatchable workflows that fail. A comment does not
  disable dispatch. `gh workflow disable` would, but it is a hosted action.

What a change invalidates:

- Local/remote byte equality. These records hold the current git blob SHAs as
  observed remote state: `proposals/refund-executable-feasibility/hosted-proof-run-20261109/records/PREFLIGHT.json`
  and `remote-workflows.json`, and `hosted-integrity-run-20261109/records/remote-workflow-list.json`.
  Blob SHAs: `5785e1c0...` (probe 3), `1ae412d6...` (v2), `5b76afb3...` (v31),
  `ff723e83...` (v32). Those records are history and must stay unchanged.
- No `implementation.lock` digest, no `spec.lock` and no ratification.
- A change under `.github/` passes through the protected-path gate
  (`gate/incremental.py` `PROTECTED_DIRS`), so it needs the protected-change
  approval route.

Steps the owner must authorize: the protected-change approval for `.github/`;
one commit and push to `mack-dot/forge` main; a new remote workflow listing
record after the push. No re-pin of a lock.

Check that would show the fix works (NOT RUN): after the push, list
`.github/workflows` on the remote and confirm the four paths are absent
(Option A) or carry the new header (Option B). Confirm `provenance.yml`,
`provenance-negative.yml` and `proof-gate.yml` blob SHAs are unchanged.

---

## A31: probe-3 workflow guard names the old repository slug

File and line: `.github/workflows/stage9-candidate-dry-run.yml` line 13.

Defect: `if: github.repository == 'superpowermentors-1/forge'`. The repository
is `mack-dot/forge`. The only job is always skipped. A skipped job gives a
green run with no artifact.

Evidence re-checked today: line 13 reads as stated. Every other
`github.repository ==` guard in `.github/workflows/` uses `mack-dot/forge`
(eight guards in seven files). The file has git blob SHA
`5785e1c020c7626eef4eaa74e7959a4d7768290d`, size 3212, which equals the
recorded remote blob. I did not re-read `ROADMAP.md` lines 3784 and 3797; the
audit cites them for the rename.

Impact: low. The workflow is superseded by `stage9-candidate-dry-run-v2.yml`.
The audit states the v1 candidate (lock `f9f09a2f...`) failed the
trust-boundary review (U096). The inert state is harmless.

This is a design decision. Options:

- Option A (recommended): delete the file together with A32 Option A.
- Option B: keep the file as an inert historical probe. Apply the A32 Option B
  header diff, or change nothing.
- Rejected: change the guard to `'mack-dot/forge'`. That re-enables a dry run
  of a rejected candidate. It would still fail at line 34 (A32). I give no
  diff for it.

What a change invalidates, owner steps and the check: the same as A32.

---

## A33: hosted probe 2 replay job pins a superseded implementation lock

File and line: `.github/workflows/stage9-hosted-probe-2.yml` line 119.

Defect: the step passes
`--implementation-sha256 9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76`.
The installed lock digest is `5f78da21...`. A new dispatch of the replay job
must fail.

Evidence re-checked today:

- Line 119 reads as stated. `workflow_dispatch` is enabled (line 5).
- `proposals/stage9-hosted-runner/replay_probe.py` line 30 calls
  `context(args.implementation_sha256)`.
- `gate/provenance/common.py` line 129 requires
  `digest(HERE / 'implementation.lock') == expected_lock`, else
  `UNAPPROVED_IMPLEMENTATION`.
- `cmp` shows the workflow is byte-identical to
  `proposals/stage9-hosted-runner/probe2.yml` (SHA-256 `07bd044b...`, git blob
  SHA `4fdbcf229ae8ee9d4e4584fdf5d9715edbe4eaea`).
- I did not execute `replay_probe.py`. The failure is derived from the code.
- The audit also noted `actions/setup-python` v7.1.0 here against v5.6.0 in
  other workflows. Both are SHA-pinned. That is not a defect.

Impact: low. The probe is a completed measurement instrument with no signing
and no secrets. A dispatch gives a failed run, not a wrong result.

This is a design decision. Options:

- Option A (recommended): keep the file unchanged. Record in a new `unsure.md`
  entry that the probe is superseded and that its replay job fails with
  `UNAPPROVED_IMPLEMENTATION` against lock `5f78da21...`. This keeps the byte
  identity with `probe2.yml` and with the recorded remote blob.
- Option B: delete `.github/workflows/stage9-hosted-probe-2.yml` in the same
  reviewed change as A32 Option A. Keep `proposals/stage9-hosted-runner/probe2.yml`.
- Rejected: update the digest on line 119. That makes a new probe run
  possible. A new run needs its own approval and the hash-checked Python
  archive that `provenance.yml` uses. I give no diff for it.

What a change invalidates: Option A, nothing. Option B breaks equality with
the remote blob `4fdbcf22...` recorded in
`hosted-proof-run-20261109/records/PREFLIGHT.json` and, per the audit,
`hosted-integrity-run-20261109/records/TRIGGER-READBACK.json`. No lock,
`spec.lock` or ratification changes.

Steps the owner must authorize: Option A, one `unsure.md` append by the
recorder. Option B, the same steps as A32.

Check that would show the fix works (NOT RUN): Option A, the new `unsure.md`
entry exists and the file SHA-256 is still `07bd044b...`. Option B, the remote
listing has no `stage9-hosted-probe-2.yml`.

---

## A35: proof gate installs pip by version only

Files and lines:

- `.github/workflows/proof-gate.yml` line 43
- `.github/workflows/toolchain-inventory.yml` line 32
- `toolchain/linux-pins.json` (`"pip_version": "25.3"`, no digest)
- `toolchain/install_ci.py` line 36 (version-string check only)

Defect: both workflows run
`.toolchain/ci-python/bin/python -m pip install --disable-pip-version-check pip==25.3`
with no `--require-hashes`. The step in `proof-gate.yml` is named "Install and
authenticate the recorded toolchain bytes". pip is the one component in that
step with no digest. That pip then runs the hash-checked install of the
validator packages.

Evidence re-checked today: both lines read as stated. `linux-pins.json` holds
SHA-256 pins for the Python executable, the Dafny archive, Z3 and six wheels,
and only a version for pip. `install_ci.py` line 36 compares
`importlib.metadata.version('pip')` with `PINS['pip_version']`.
`toolchain/inventory_ci.py` lines 40-42 also check the version string only.
`stage9-hosted-probe-2.yml` lines 64-65 already pin pip by hash, so the
pattern exists in the repository.

Impact: low. A substituted pip 25.3 distribution could bypass the later hash
checks. Exploitation needs a compromised index path. The verify job has
`contents: read` only. The exposure is result integrity, not token theft.
`proof-gate.yml` runs this step in the trusted base checkout.

Exact diff. One value is missing: the SHA-256 of `pip-25.3-py3-none-any.whl`.
I did not fetch it; the task limits forbid network use. I did not write a
digest from memory. The placeholder is not a valid hash, so pip rejects it and
the step fails closed until the owner replaces it.

```diff
--- a/.github/workflows/proof-gate.yml
+++ b/.github/workflows/proof-gate.yml
@@ -40,7 +40,8 @@
         working-directory: trusted
         run: |
           python -m venv .toolchain/ci-python
-          .toolchain/ci-python/bin/python -m pip install --disable-pip-version-check pip==25.3
+          python -I -c "import json; p = json.load(open('toolchain/linux-pins.json')); print('pip==' + p['pip_version'] + ' --hash=sha256:' + p['pip_wheel_sha256'])" > "$RUNNER_TEMP/pip.txt"
+          .toolchain/ci-python/bin/python -m pip install --disable-pip-version-check --require-hashes --no-deps -r "$RUNNER_TEMP/pip.txt"
           .toolchain/ci-python/bin/python toolchain/install_ci.py
       - name: Check exact PR revisions with trusted code
         id: check
--- a/.github/workflows/toolchain-inventory.yml
+++ b/.github/workflows/toolchain-inventory.yml
@@ -29,7 +29,8 @@
       - name: Select the pinned installer
         run: |
           python -m venv .toolchain/ci-python
-          .toolchain/ci-python/bin/python -m pip install --disable-pip-version-check pip==25.3
+          python -I -c "import json; p = json.load(open('toolchain/linux-pins.json')); print('pip==' + p['pip_version'] + ' --hash=sha256:' + p['pip_wheel_sha256'])" > "$RUNNER_TEMP/pip.txt"
+          .toolchain/ci-python/bin/python -m pip install --disable-pip-version-check --require-hashes --no-deps -r "$RUNNER_TEMP/pip.txt"
       - name: Inventory and exercise the real toolchain
         run: .toolchain/ci-python/bin/python toolchain/inventory_ci.py
       - name: Save the inventory for review
--- a/toolchain/linux-pins.json
+++ b/toolchain/linux-pins.json
@@ -24,6 +24,7 @@
     "version": "4.12.1"
   },
   "pip_version": "25.3",
+  "pip_wheel_sha256": "OWNER_MUST_REPLACE_WITH_VERIFIED_SHA256_OF_pip-25.3-py3-none-any.whl",
   "verification_options": [
     "--solver-path",
     ".toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1",
```

Design notes:

- The workflows read the digest from `toolchain/linux-pins.json`. The pin has
  one source. In `proof-gate.yml` that file comes from the trusted checkout.
- `python -I` runs the setup-python interpreter in isolated mode. It reads one
  JSON file and prints one requirement line.
- Optional, not in the diff: make `toolchain/install_ci.py` authenticate the
  installed pip, not only its version string. The wheel is not retained after
  install, so this needs a design choice (retain the wheel, or pin the
  installed `RECORD` digest). I give no invented diff for it.

Residual trust, stated plainly: the venv bootstrap pip from `ensurepip` in
Python 3.10.11 performs the hash-checked upgrade. The change narrows the gap.
It does not close it.

What a change invalidates:

- `toolchain/linux-pins.json` SHA-256 changes from `11128aa4...`.
  `gate/backends/dafny.py` reads this file for the `linux` profile and lists
  it at line 146 among the bound paths. Receipts that record the old digest
  stay valid as history (`results/stage4/pr-4-receipt.json` line 275,
  `results/stage9/v33-controls-0003/evidence-manifest.json`). New linux-profile
  receipts and incremental cache keys will differ. Uncertainty: I did not
  trace every consumer of that bound-path list.
- `proof-gate.yml` (`e3904deb...`) and `toolchain-inventory.yml` (`264a545b...`)
  SHA-256 values change. `evidence-manifest.json` of v33-controls-0003 records
  the old values as history. Recorded remote blob SHAs `c505b799...` and
  `247229d2...` no longer match after a push.
- `gate/provenance/implementation.lock`: not affected. It lists none of the
  three files. `spec.lock`: not affected. No ratification is affected.
- The header `"runner": "ubuntu-22.04"` and the `provenance` block in
  `linux-pins.json` describe the recorded inventory run 40397041174. That run
  did not observe a pip wheel digest. The owner should decide whether the new
  key needs a new inventory run as its provenance.

Steps the owner must authorize:

1. Obtain the SHA-256 of `pip-25.3-py3-none-any.whl` from PyPI. Verify it by a
   second path. Replace the placeholder.
2. Approve the protected change (`toolchain/` and `.github/` are in
   `PROTECTED_DIRS`; the PR template requires a proposal first).
3. Push, then re-run `toolchain-inventory.yml` and the proof gate on a PR.
4. Record the new file digests and run links in `ROADMAP.md`.

Check that would show the fix works (all NOT RUN):

- Positive: `toolchain-inventory.yml` run exits 0 and the log shows the
  `--require-hashes` install of pip 25.3.
- Negative control: the same run with one hex digit of `pip_wheel_sha256`
  changed must fail in the pip step with a hash mismatch.
- The proof gate on a no-op PR still reports its prior result.

---

## A47: `COMMANDS.json` holds an entry that the retained recorder cannot write

File and line:
`proposals/refund-executable-feasibility/proof-loader-fix-20261109/records/record_fix.py`
lines 100-105, and `records/COMMANDS.json` entry 5.

Defect: the retained `record_fix.py` writes four command entries. The recorded
`COMMANDS.json` has a fifth entry for `record_fix.py` with `actual_exit` 0. A
later step wrote it and recomputed the manifest. The packet does not retain
that step.

Evidence re-checked today:

- `record_fix.py` (SHA-256 `8cc69f0c...`) has four `'argv':` entries and does
  not contain the string `record_fix.py`.
- `COMMANDS.json` (SHA-256 `cf3d4e05...`) has five entries.
- `REPORT.md` line 28 and `ROADMAP.md` line 25 have a `record_fix.py` row. The
  `section` string in `record_fix.py` (lines 11-35) has no such row.
- All 41 `MANIFEST.json` digests match the current bytes. No member is
  unlisted or missing.
- `records/tracking-after.json` matches the current SHA-256 of `ROADMAP.md`
  (`1f5a7bdf...`), `FORGE_MISSION_STATUS.md` (`4afb2591...`) and `unsure.md`
  (`60f00a1a...`) at the time of my check.
- mtimes: `record_fix.py` 16:32:19; `COMMANDS.json`, `REPORT.md`,
  `tracking-after.json` and `MANIFEST.json` 16:32:45.
- Refuted part of the audit title, as the verdict states: the absent `bash -n`
  entry is not a defect. `records/syntax-command.json` records it with exit 0.
- U341 is the last `unsure.md` entry. No later entry covers this gap.

Impact: low. The gap is provenance only. The exit 0 for `record_fix.py` and
the final manifest come from an unretained step. No test or proof result
depends on it.

Fix: a corrective addendum outside the packet, plus one `unsure.md` append by
the recorder. Do not edit any packet file. The packet `MANIFEST.json`
(SHA-256 `054e409a...`) pins every member. The addendum sits in a new sibling
directory, so no packet member list or digest changes. Exact diff (new file):

```diff
--- /dev/null
+++ b/proposals/refund-executable-feasibility/proof-loader-fix-20261109-addendum-1/ADDENDUM.md
@@ -0,0 +1,61 @@
+# Corrective addendum 1 to the U341 loader-fix packet
+
+Status: addendum only. It changes no file in
+`proposals/refund-executable-feasibility/proof-loader-fix-20261109/`.
+The packet `MANIFEST.json` (SHA256
+`054e409a2a75a5e8d64463d9987a6f939303b4c206aa7153b8bc914c1d193a7f`) stays valid.
+CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
+No proof, hosted run, publication or protected edit occurred for this addendum.
+
+## Correction 1: an unretained step wrote the final records
+
+- `records/record_fix.py` (SHA256
+  `8cc69f0c9cf47860113d88d2913c5daeff61646afa6bc7db1cfe684a0c8b4ba9`) writes
+  four entries to `records/COMMANDS.json`. It writes no entry for itself.
+- The recorded `records/COMMANDS.json` (SHA256
+  `cf3d4e055932d781489b6d8fbeccceb42f577ba5b0190724f1e2dc6261fd217c`) has a
+  fifth entry: `record_fix.py`, `actual_exit` 0.
+- `REPORT.md` line 28 and `ROADMAP.md` line 25 have a `record_fix.py` row. The
+  `section` text in `record_fix.py` has no such row.
+- `records/tracking-after.json` and `MANIFEST.json` match these later bytes.
+  A step after `record_fix.py` therefore wrote or recomputed them.
+- The packet does not retain that step. The exit 0 for `record_fix.py` has no
+  retained generator. Treat it as an unverified statement.
+- All 41 `MANIFEST.json` digests match the packet bytes on 2026-11-09. No test
+  result or proof claim depends on this gap.
+
+## Correction 2: the `prepare_fix.py` exit 0 belongs to the initial source
+
+- `REPORT.md` line 23 lists `prepare_fix.py` with exit 0 and no source note.
+- `records/COMMANDS.json` records `executed_source: prepare_fix.py.initial`
+  (SHA256 `1ec47cbc526267a33e8b98f8c64f8ea8a118db41df12ebb407ce31e4b82f0248`).
+- The retained `records/prepare_fix.py` (SHA256
+  `d3a77b43db6870d786630fb3b5b2395017b1a2699131e51c5cd581efb60c0007`) has no
+  recorded end-to-end run. Its line 31 asserts that `driver.py`, `workflow.yml`
+  and `shell.sh` do not exist. They exist, so a re-run fails that assertion.
+- The two scripts differ only in the regression SML text
+  (`HOLFileSys.toFS` to `HFS_NameMunge.HOLtoFS`).
+- No recorded command produced the corrected
+  `records/loader-path-regression.sml` (SHA256
+  `c2797e5234baa3d28defdf3acfef89f496546a2fe76a3ce8eedc6a4dcc2a17d1`).
+- The driver, workflow, shell and bootstrap outputs come from the initial run.
+- This addendum does not state that the corrected SML content is wrong. The
+  audit reports that an in-memory recomputation equals the file. This addendum
+  did not repeat that recomputation.
+
+## Not a defect
+
+`records/COMMANDS.json` has no `bash -n` entry. `records/syntax-command.json`
+records that command with `actual_exit` 0, and both stream logs are retained.
+
+## Rule for later packets
+
+1. Retain the outer wrapper that runs the recorder, records the recorder exit
+   and computes the final manifest.
+2. Regenerate a corrected file through a separate script with its own
+   recorded argv and exit code.
+
+| Check | Actual exit/result |
+| --- | --- |
+| Packet member digests against `MANIFEST.json` (read-only, 2026-11-09) | 0; 41 members, 0 mismatches |
+| Wrapper-retaining re-record of the packet | NOT RUN |
```

Draft `unsure.md` entry for the recorder (append only; the recorder assigns
the next free ID, shown here as U-NEXT):

```text
## U-NEXT — U341 packet: final records come from an unretained step; prepare exit belongs to the initial source

- References:U341. CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
- Evidence:record_fix.py (8cc69f0c...) writes four COMMANDS.json entries and no
  row for itself. COMMANDS.json (cf3d4e05...) has a fifth entry,record_fix.py
  exit0. REPORT.md line28 and ROADMAP.md line25 carry the same row.
  tracking-after.json and MANIFEST.json match those later bytes.
- Evidence:COMMANDS.json records executed_source prepare_fix.py.initial
  (1ec47cbc...) for the prepare exit0. REPORT.md line23 omits that note. The
  retained prepare_fix.py (d3a77b43...) asserts at line31 that its outputs do
  not exist;no recorded run of it exists. No recorded command produced the
  corrected loader-path-regression.sml (c2797e52...).
- Uncertainty:the step that wrote the final bytes is unknown. The record_fix.py
  exit0 is unverified. The corrected SML content is not disputed.
- Impact:provenance only. All41 MANIFEST digests match. No test or proof result
  depends on the gap. The packet stays unchanged.
- Evidence file:proposals/refund-executable-feasibility/
  proof-loader-fix-20261109-addendum-1/ADDENDUM.md.
- Next check:in later packets retain the outer wrapper and record each
  regeneration through its own script and exit code.
```

What a change invalidates:

- The addendum invalidates nothing in the packet. Uncertainty: I found no
  checker that enumerates sibling directories of the packet, but I did not
  search every script for one.
- The `unsure.md` append moves `unsure.md` past the `after_sha256` snapshot
  (`60f00a1a...`) in `records/tracking-after.json`. Every later journal entry
  does that. It is not a packet defect.
- No lock, `spec.lock` or ratification is affected.

Steps the owner must authorize: creation of the addendum directory and file;
one `unsure.md` append by the recorder. No re-run and no re-pin.

Check that would show the fix works (NOT RUN): after the addendum is added,
recompute the 41 packet digests against `MANIFEST.json` and confirm 0
mismatches and SHA-256 `054e409a...` for `MANIFEST.json` itself. Confirm the
`unsure.md` prefix up to U341 is byte-identical to the prior file.

---

## A48: `REPORT.md` lists `prepare_fix.py` exit 0 without the executed source

File and line:
`proposals/refund-executable-feasibility/proof-loader-fix-20261109/REPORT.md`
line 23 (the audit item says line 22; the row is on line 23).

Defect: the row lists `prepare_fix.py` with exit 0 and no source note. The
exit belongs to `prepare_fix.py.initial`. The retained `prepare_fix.py` has no
recorded end-to-end run and cannot re-run.

Evidence re-checked today:

- `REPORT.md` line 23 reads as stated. Line 25 labels the initial
  `test_loader.py` run; line 23 has no such label.
- `COMMANDS.json` entry 1 has `"executed_source": "prepare_fix.py.initial"`.
- `diff` of `prepare_fix.py.initial` (SHA-256 `1ec47cbc...`) and
  `prepare_fix.py` (`d3a77b43...`): one added line and three changed lines,
  all in the regression SML text (`HOLFileSys.toFS` to a `resolved` helper on
  `HFS_NameMunge.HOLtoFS`).
- `prepare_fix.py` line 31: `p=out/n;assert not p.exists();p.write_text(data)`
  for `driver.py`, `workflow.yml`, `shell.sh`. Those files exist, mtime
  16:28:39. `prepare_fix.py` and `loader-path-regression.sml` have mtime
  16:29:46.
- `diff` of `loader-path-regression.sml.initial` and
  `loader-path-regression.sml` shows the same four-line change. That is
  consistent with the script diff.
- I did not recompute the SML from `prepare_fix.py`. The audit reports a
  byte-equal in-memory recomputation. I did not run the script, because a run
  would write into the packet.

Impact: low. The provenance statement is imprecise. The packet partly
discloses it in `COMMANDS.json` and U341. The content is not shown wrong.

Fix: Correction 2 in the A47 addendum and the same `unsure.md` entry. No
separate diff. Do not edit `REPORT.md` (pinned at `714e60ac...`),
`COMMANDS.json`, `prepare_fix.py` or `record_fix.py`.

What a change invalidates, owner steps and the check: the same as A47.

---

## A49: broken link in a superseded draft

File and line: `proposals/provenance-receipt-repair.md` line 132.

Defect: the link target `../results/stage9/receipt-repair-published/README.md`
does not exist.

Evidence re-checked today: line 132 reads as stated.
`results/stage9/` has `receipt-repair-preparation` and no
`receipt-repair-published`. `receipt-repair-preparation/` has 11 entries and
no `README.md` at its top level. `proposals/provenance-integrity-repair.md`
lines 5-7 say this draft and its results "stay unchanged as history. See
U078." The file has git blob SHA `7806a1a4f300a340f4ae9eadd90d844b7f379feb`,
size 9505, which equals the blob recorded in
`proposals/refund-executable-feasibility/integrity-preflight-20261108/records/remote-base-tree-1.json`
and `remote-addon-tree-1.json`.

Impact: low. The draft is superseded. No script reads the link.

This is a design decision. Options:

- Option A (recommended): no edit. The recorder appends one `unsure.md` entry
  (reference U078) that states the target does not exist and that the records
  are in `results/stage9/receipt-repair-preparation/`.
- Option B: retarget the link to the directory. There is no README to link.
  Exact diff:

```diff
--- a/proposals/provenance-receipt-repair.md
+++ b/proposals/provenance-receipt-repair.md
@@ -129,7 +129,7 @@
 Both candidate Python files and the embedded collector code passed syntax
 compilation. The proposed producer's Docker path has not executed.
 
-The [preparation records](../results/stage9/receipt-repair-published/README.md)
+The [preparation records](../results/stage9/receipt-repair-preparation/)
 retain failures, commands, raw logs, reference digests, control manifests and
 mutated bytes. Reproduction needs Python 3.10.11, the original Stage 7 archive
 and a read-only collection from the preserved Stage 7 environment. Use new
```

  Option B contradicts the "unchanged as history" statement of U078.

What a change invalidates: Option A, nothing. Option B changes the file
SHA-256 (`6bd70fa1...`) and breaks equality with the recorded remote blob
`7806a1a4...`. No lock, `spec.lock` or ratification is affected.

Steps the owner must authorize: Option A, one `unsure.md` append. Option B, an
explicit exception to U078, a push, and a new remote tree record.

Check that would show the fix works (NOT RUN): Option A, the entry exists and
the file blob SHA is still `7806a1a4...`. Option B, a relative-link check over
`proposals/*.md` reports 0 unresolved links.

---

## Approval requested

Nothing in this file is applied. The owner decides per ID:

| ID | Decision needed |
| --- | --- |
| A32, A31 | Option A (delete four workflows) or Option B (header comment) or no change |
| A33 | Option A (keep, record) or Option B (delete) |
| A35 | Supply the verified pip 25.3 wheel SHA-256; approve the three-file diff and the hosted re-runs |
| A47, A48 | Approve addendum 1 and one `unsure.md` append |
| A49 | Option A (record only) or Option B (retarget link) |
