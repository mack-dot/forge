# Step P0: current-state audit (W1, Opus, read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W1 state-audit, step P0. The audit was read-only and changed no repository file. My only file is a codesign copy at <session scratch folder>/m1b/W1/refund-arm64-macho.copy. Times are UTC and come from `date -u` at about 05:03Z to 05:06Z on 2026-11-19.

**Repository**
- Active branch: `docs/m1-owner-decisions`. HEAD, `main` and `origin/main` are all `8e772b55`.
- Last 5 commits of `main`: `8e772b55` (#55), `5ec606eb` (#54), `982890e5` (#52), `b42c6ff8` (#51), `5fad5ce4` (#50).
- `git status --short` without the `results/` lines: `?? .hol/`, `?? goal18.md`, `?? proposals/m1-owner-review-20261119/OWNER_DECISIONS.md`, `?? proposals/m1b-mission-20261119/`. No tracked file is modified.

**1. The 95 HOL4 theories: REPLAYED, with exit 0 and hashes equal to the recorded ones (same machine; not a clean or independent replay)**
- Records: `proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/` on `main`, from commit `9d587c7e` (#42).
- My recount from the JSON:
  - Phase 1: `summary.json` has 74 rows, all `REPLAYED` with `actual_exit` 0. These are 71 theories plus 3 extra rows:
    - C72 is the import check imp4-0001.
    - FS-fs-r4-0001 is `forge_refundInputSat`. It has no stored statement to compare.
    - CHK-fs-imp-r4-0001 is an import check written during the replay.
  - Phase 1 comparison: `comparison.json` has 72 entries, all `equal`. For 71 of them the sig, sml and dat hashes (fresh against recorded) are equal; the 72nd entry is imp4.
  - Phase 2: `summary-phase2.json` has 24 rows, all exit 0. `comparison-phase2.json` has 24 of 24 with all three files equal.
  - Total: 71 + 24 = 95 theories with byte-equal exports.
- `commands.json` has 117 commands (92 + 25). 115 exit 0. One exits 1: `T01-forge_refund-dryrun`, a Holmake dry run. One has no exit: `C10-proof-0001`, `STOPPED_BY_OPERATOR`; it was run again and exited 0.
- No contradiction with M1R-1 or M1R-2.

**2. The 158 cases: PARTIAL, 32 of 158 run; the job is PAUSED on battery power**
- Source: `results/round4-m1-replay-20261118/phase3/results.json`, last written 04:58:43Z.
- 32 cases are in the file (indexes 0–31): 18 controls, 7 import checks, 7 repeats.
- Verdicts: 31 `AS_RECORDED`, 1 `EXIT_EQUAL_REASON_DIFFERS`. Exit pairs (recorded, actual): (1,1) ×17, (0,0) ×14, (−24,−24) ×1. No case needed a second attempt.
- The case that is not `AS_RECORDED` is `005-initial-stack-code-local-20261112-duplicate-label` (control, recorded exit 1, actual exit 1):
  - Fresh run: stdout is empty and `stderr.log` line 1 reads `Run out of store - interrupting threads`. The next lines are `error in load ... AstProgTheory : Interrupt` … `TheoryReader.sml:68: Interrupt`. Peak memory (child max RSS) was 1952 MiB.
  - Recorded run: it failed at `Tactical.sml:120 ... "unsolved goals"`, after `IMPORTED refund_lab_code ...` and the marker `AFTER_POSITIVE_AUDIT`.
  - So this control ran out of memory while loading theories and never reached its check. It is not a valid re-check of that control. Swap at 04:43Z was 8.9 of 10 GiB used.
- Note on case 028 `missing-memory`: it is "AS_RECORDED" with exit −24, which is a CPU limit both times. That is not a rejection of the wrong statement.
- Live state:
  - The driver (`scripts/driver3.py run`, pid 79903) still runs.
  - Its last event is `WAIT before 032-...-wrong-polarity-0002: power_ok=False` at 04:58:43Z.
  - `pgrep -fl "bin/hol|Holmake|poly"` exits 1: zero HOL processes are running now.
  - `results.json` records at most 1 HOL process at a time, and no foreign HOL process.
  - `pmset -g batt` at 05:05Z: "Battery Power", 67%, discharging.
  - `driver3.py` lines 102–106 stop the job with `NOT_STARTED_NO_MAINS_POWER` after 1800 s without mains power, so at about 05:28:43Z unless the Mac is plugged in. `power-poll.log` shows mains power at 04:28:47Z, which was later lost.
- Correction to the tracker: it says "29 of 158 at 04:56Z". The file now shows 32.
- Restore record: the replay restored 94 source files into the original `results/refund-*` folders (`restore-record-phase3.json` `count_created`), and it writes case outputs there.

**3. The 18-row review: the matrix shows 18 of 18 NOT REVIEWED; the I.2 review report exists**
- Matrix: `git show origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/m1-profile-a-slide0-20261117/A8_CONTRACT_REVIEW_MATRIX.md` (last commit `19696fd1`). `grep -c "NOT REVIEWED"` gives 18. The `main` copy in `REVIEW_PACKET.md` §3 also lists all 18 rows as NOT REVIEWED.
- Contradiction to the brief: the brief says the review is "running, not finished". But `proposals/m1b-mission-20261119/reports/I2-review-18-rows.md` (25,254 bytes) exists, and TRACKER lists I.2 as REPORTED.
- What that report says:
  - 8 rows HOLD and 8 HOLD WITH A CONDITION.
  - Row 17: does NOT hold.
  - Row 18: does NOT hold.
  - D3: `library/Std/Strings.dfy:185` is a bodiless `@Axiom` lemma.
- I did not check its findings.

**4. Workers: what the files show**
- TRACKER (last update 05:04Z) lists W1–W9, a reviewer (I.2) and the replay job.
- Scratch folders exist for W1, W3, W4, W5, W6, W8 and W9. None exists for W2 or W7.
- Reports exist only for I.1a and I.2.
- Processes: the replay driver only. I did not identify the other workers' processes.

**5. Profile A: decided only in an uncommitted file; nothing on `main` states the approval**
- `OWNER_DECISIONS.md` is untracked (`??`) on `docs/m1-owner-decisions`. Its decisions:
  - Q1: Profile A, with R1–R5 kept as they are.
  - Q2: EIO and EINTR are excluded; failure must be closed.
  - Q3a: the loader and entry-state assumption is accepted and marked unverified.
  - Q3b: one named C/FFI simulation assumption is accepted.
  - Q3c: the file reader and offset tool are trusted only with validation, pinned identity and negative controls.
  - Q4: closure needs a machine-checked link; a review gives only a conditional result.
  - Q5: absent stdin is excluded.
  - Q6: the 158 cases are authorized; the clean and independent replays are a plan only.
  - Text 2 defines two levels, M1-A and M1-B.
- It cites `unsure.md` U473, which does not exist: the last entry is U472.
- `main` still says the opposite:
  - `proposals/forge2-m1-conformance/REPORT.md:258` reads "Profile A, NOT approved".
  - `ROADMAP.md:386` lists "Profile A approval" as open.
  - `REVIEW_PACKET.md:58` still asks Q1.

**6. Compiler premises and slide obligations: the stored theorems exist; open items remain**
- Discharged inside scripts (the lines are confirmed on the backup branch, `m1-compile-correct-20261114/records/cc/`):
  - `real-0004.sml` lines 90–91: `mc_init_ok` and `backend_config_ok` come from `arm8_init_ok` and `arm8_backend_config_ok`, inside `refund_compile_correct_no_handler` (line 81).
  - `source-0006.sml` lines 58–61: the same two, plus `opt_eval_config_wf_def`, inside `refund_install_exclusion_compiled` (line 55).
  - Both theories were replayed with exit 0 and equal hashes (rows C34 and C32).
- Slide-0 result with the output equation (O3), U404: `forge_refundProfileA` has `refund_profile_a_slide0` and `refund_profile_a_slide0_every_machine_run`.
- S1, U405: `forge_refundCmlMainSlide` has `cml_main_run_sl`.
- S2, U405: `forge_refundSlideEntry` has `refund_entry_run_sl`, `refund_entry_pre_sl_IMP_cml_main_pre_sl` and `refund_shifted_domains_disjoint`.
- S3, U407:
  - `forge_refundSlideDomains` has `refund_end_state_sl_established`.
  - `forge_refundSlideInstalled` has `refund_installed_from_end_state_sl` and `refund_installed_from_entry_reduced_sl`.
- S4–S6, U409: `forge_refundSlideProfileA` has `refund_profile_a_sl`, `refund_profile_a_sl_every_machine_run` and `ffi_interfer_ok_iff_contract_sl`.
- Joint premises (O4), M1R-1: `forge_refundInputSat` has `refund_profile_a_sl_all_premises_satisfiable_at_0x4000`.
- All of these theories were replayed in M1R-1 with exit 0 and equal hashes (C64–C71, FS).
- Open:
  - Joint satisfiability is shown only at slide 0x4000, for one constructed state.
  - `refund_env_ok_sl` and the entry state are assumptions. `refund_env_ok_sl` is "probably false for the real C code" (U393 and U409, an analysis).
  - `interference_ok` and `ffi_interfer_ok` remain unproved (U407).
  - No clean replay. No independent replay.

**7. The ARM64 executable: IDENTIFIED**
- `shasum -a 256` (exit 0) gives `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` for both files.
- Both files are 238,776 bytes. `file` reports "Mach-O 64-bit executable arm64" for both. The artifact is tracked.
- `codesign --verify --strict` on the copy exits 0. The signature is ad hoc and linker-signed, with no team identifier.
- I did not execute the binary.

**8. Stage 9: the locks are STALE; Stage 9 is deferred**
- SHA-256:
  - `implementation.lock`: `76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9`
  - `spec.lock`: `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33`
  - Both equal `main`.
- Stale entries, recounted against the working tree:
  - `implementation.lock` `files`: 8 of 100 are stale. They are `gate/approval.py`, `gate/backends/dafny.py`, `gate/incremental.py`, `gate/refund.py`, `scripts/exit_stage_5.py`, `spec/refund/spec.lock`, `toolchain/linux-pins.json` and `toolchain/pins.json`. This matches U468.
  - `spec.lock` `locked_existing_files`: 8 of 47 are stale. They are `gate/backends/dafny.py`, `gate/common.py`, `gate/core.py`, `gate/dependencies.py`, `gate/refund.py`, `scripts/javascript_env.py`, `spec/refund/spec.lock` and `toolchain/pins.json`. This matches U469(b).
- Tracked code files that the implementation lock does not list (bootstrap rule in `gate/provenance/bootstrap.py`: lines 22–23 define the roots and suffixes, lines 59–74 apply them; the lock itself is excluded): `scripts/demo_gauntlet.py`, `scripts/exit_m1_conformance.py`, `scripts/exit_slice1.py`, `scripts/exit_slice2.py`, `scripts/exit_slice3.py`, `scripts/spec_clearing.py`. That is 6 files.
- Working-tree only: `scripts/__pycache__/` (3 `.pyc` files, ignored by git) would fail `BYTECODE_CACHE` in this tree. A clean clone does not have it.
- Pull request 53: closed without a merge (U470, and the ROADMAP row `gh pr close 53` exit 0). The local and remote branch `proposal/stage9-lock-rebind` exists. The unapplied proposal is on `main` at `proposals/stage9-lock-rebind-20261119/` (`PROPOSAL.md`, `proposed.diff`). I did not check GitHub (no network).

**Claims I could not confirm**
- That pull request 53 is closed on GitHub. My evidence is the records only.
- The I.2 review findings (row 17 and 18 failures, the `@Axiom` in the closure).
- That the replay records were not tampered with. I recounted the JSON; I did not recompute the theory-file hashes.
- The reason for the 1952 MiB out-of-memory in case 005. It may be the HOL heap size, swap pressure, or another process.
- Whether the replay will resume before about 05:28:43Z.
- That the stored theorem statements are the right ones. M1R-1 also says this is not shown.
- The other workers' processes.

| step | status | evidence or blocker |
| --- | --- | --- |
| P0 | REPORTED | 95 of 95 theories exit 0 with equal hashes (replay JSON); 158-case replay 32 of 158 run, 31 AS_RECORDED and 1 `EXIT_EQUAL_REASON_DIFFERS` (case 005, out of memory), paused on battery and auto-stops at about 05:28:43Z, 0 HOL processes; A8 matrix 18 of 18 NOT REVIEWED but the I.2 report exists; Profile A is only in the uncommitted `OWNER_DECISIONS.md` (cites U473, which does not exist); executable `b8ed5ec2…7bb8`, codesign exit 0; locks 8 of 100 and 8 of 47 stale, 6 unlisted scripts; pull request 53 closed per the records |
