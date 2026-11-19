# Step I.4c: plans for the clean replay and the independent replay (W4, Opus, read-only; nothing was run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## W4 replay-plan (I.4c): report

I wrote 3 draft files and 1 helper script, all in the scratch folder. Nothing was run: no HOL, build or network. No file in the repository changed: there are 0 tracked changes, and I used read-only git only.

### Files
- <session scratch folder>/m1b/W4/CLEAN_REPLAY_PLAN.md
- <session scratch folder>/m1b/W4/INDEPENDENT_REPLAY_PLAN.md
- <session scratch folder>/m1b/W4/MANIFEST_DRAFT.json
  - It has 95 theories with the recorded `.dat`, `.sig` and `.sml` SHA-256, the `imp4-0001` row, and 158 cases with their expected exit and reason.
  - It also has the pins, the heaps (for information only), the executable with 3 slices, the final theorem with its axioms and tags, and the `fs` hashes.
- <session scratch folder>/m1b/W4/make_manifest.py (generator; reads only tracked records)

### Clean replay plan
- **Definition of "clean":**
  - A fresh clone in a new folder outside `<HOME>/forge`.
  - The M1 sources are NOT on `main`. On `main` 8e772b55, 0 of the 259 restore sources exist. On `origin/backup/forge-local-2026-11-11` c003a982, 259 of 259 exist. The proposal is to freeze c003a982.
  - A new, empty tool tree built from the pins: Poly/ML `4557554…`, HOL `9783a49…`, CakeML `cd91556…`. Identity check: `rev-parse HEAD` equals the pin.
  - No file from the old tree or from the old `results/` is reused. Every source is checked against its recorded SHA-256.
- **Steps:**
  - P0–P2: preconditions, clone, source check.
  - T1–T7: `caffeinate -i -s python3 -I -B …/m1-rebuild/rebuild.py 41400 …`. It builds in the new tree, because its root is relative to the script.
  - T8: the 4 upstream Holmake targets that `rebuild.py` does not build (16 theories, 3 library objects). Each one gets a `-n` dry run first.
  - T9: tool identity.
  - R1–R2: restore with a path map, and the executable hash.
  - C1–C4: the 2026-11-18 `driver.py` commands (`run 1 72`; `FORGE_PLAN=phase2 … run 101 124`; `fs`; `check`).
  - C5: the 158 cases.
  - V1–V4: recheck, slices, tags, postflight.
- **Limits:**
  - Before each step: disk free ≥ 20 GiB, memory free ≥ 25 percent, swap used ≤ 6 GiB, no other HOL process, mains power.
  - Stop: disk free < 15 GiB, one HOL process above 7,168 MiB, or swap above 7.5 GiB.
  - Per HOL case: max(3 × recorded wall, recorded wall + 600 s).
  - The disk and memory thresholds are my estimates. The recorded peaks are 4,768 MiB in the chain and 4,337 MiB in the 158 cases.
- **Budget:**
  - Recorded awake seconds: tools 23,728.6, chain about 7,127, the `fs` run and its check 156.5, the 158 cases 11,144.0. Total about 42,156 s.
  - The ARMv8 step heap build time is not recorded. I took 7,200 s as an estimate.
  - Proposal (estimate, 1.5 × margin): 77,400 s in 3 windows. Tools 46,800 s, chain 12,600 s, cases 18,000 s.
- **Evidence:**
  - Untracked: `CLEAN/results/m1-clean-replay-<date>/`.
  - Tracked packet of small records: `proposals/refund-executable-feasibility/m1-clean-replay-<date>/`.
- **Acceptance:**
  - 95 of 95 theories exit 0, with SHA-256 equal to the manifest. Example: `4ff2a7e2…` for `forge_refundSlideProfileA.dat`.
  - `imp4-0001`: IMPORTED 15, MISMATCH 0.
  - Final theorem: exactly the 4 `bool` axioms, exactly the `DISK_THM` tag, 0 hypotheses, 542 closure nodes, 17 stored theorems.
  - `fs`: exit 0 and equal to the hashes of its one earlier run.
  - Each of the 158 cases has its recorded exit AND its recorded reason.
  - Executable `b8ed5ec2…`, the 3 slices and `refund.S` `4c750e4f…` are equal.
  - 0 tracked files changed.
- **Forbidden shortcuts:** reuse of any built file, heap or `.hol/` folder; any cache; `-j` above 1; any edit of a script, statement or control; skipping a case; network after T1; running in the present tree.

### Independent replay plan
- **Independent means:** another machine and another operator, who is not the proof author and ideally not the same agent family. The operator makes their own clone and builds the tools from upstream, with the pins confirmed on the upstream host. Their own statement checker compares terms, the four axioms, the `DISK_THM` tag and 0 hypotheses.
- **The package:** a link to the public repository plus the manifest and instructions. The project sends no heaps, built theories, caches or `results/` folders.
- **Hardware:** the records show only macOS arm64. The proofs are about models; the executable is only read as bytes and never run. So Linux x86-64 should work in principle, but no record shows this, and no record shows byte equality of theory files across platforms. Proposal: on another platform, byte equality is reported but not required, and statement equality is required.
- **Failure:** recorded as a new `unsure.md` entry that quotes the operator. No repair inside the run; a fix needs a new commit and a new run.

### Risks found in the records
- **Path dependence:** 121 of the 301 sources contain `<HOME>`: 67 `.txt`, 51 `.py`, 2 `.sml`, 1 `.json`. The two `.sml` files are `reject-0009.sml` and the ARMv8 preload. The replay copies of the scripts hold `<HOME>` and do not run unchanged. No record shows equal theory hashes after the tool-tree path changes.
- **Not listed by `rebuild.py`:** the upstream objects of T8. The 158 cases may need more.
- **Recorded workarounds:**
  - The empty folder `forge_refundProg_experiment` must be created again.
  - `run_arm8_case.py` refuses after a rebuild, so the ARMv8 cases need direct mode.
  - One preload file must be rebuilt from 2 lines of a stored file.
- **Machine conditions:** swap was 6.9 of 8 GiB today. There were battery incidents during earlier builds (U438, U440). The clean run must wait until I.4a ends.

### Open owner questions
- Q-C1 / Q-I7: which commit to freeze.
- Q-C2: path map (proposed) or same absolute path.
- Q-C3: a separate time limit per tool step, or the total budget only.
- Q6: approval of the limits, commands and evidence folders.
- Q-I1: who is the operator: a person, a second AI vendor, or both.
- Q-I2: budget.
- Q-I3: whether Linux is allowed, with statement equality only.
- Q-I4: form of the signed report.
- Q-I5: the theorem list for the checker.
- Q-I6: must the clean replay pass first.
- Q-I8: is the Dafny side (O1) included.

### Not found in the records
- Build time and peak memory of the ARMv8 step heap (the 2026-11-18 window skipped it because the heap existed); peak memory of any tool build.
- gmp version; the Dafny UTF-8 library commit of U262 (I did not read U262).
- Hashes of the 16 upstream theories.
- Any cross-platform result; upstream tarball digests.
- A machine-readable list of all theorem statements.
- How long a clone of the repository takes.
- The disk sizes in the plan are my `du` measurements of today, not records.

| step | status | evidence or blocker |
| --- | --- | --- |
| I.4c | REPORTED | the 3 draft files above in scratchpad/m1b/W4; no run; no run before owner approval (Q6) |
