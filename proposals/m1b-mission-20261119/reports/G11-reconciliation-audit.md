# Step G11: reconciliation audit of the orchestrator's records (Z11, Opus; read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

## Z11: reconciliation audit of the orchestrator's records

**Method.** I only read files and ran read-only commands. I changed no repository file. My notes are in `<session scratch folder>/m1b/Z11/` (`files_56.txt`, `files_57.txt`, `files_58.txt`, `g56.txt`, `g57.txt`, `g58.txt`, `prot.err`). Every command was read-only and exited 0, with two exceptions:
- `gh api …/protection` exited 1 (HTTP 403), as the records say.
- One broad `find /` ran too long. I stopped it. It changed nothing.

### Ranked discrepancies, with the exact correction

1. **The replay state is wrong.** Places: TRACKER F5 (written 06:44Z, "BLOCKED … driver waits"), TRACKER I.4a (still says "33 of 158 at 05:19Z"), ROADMAP U476 and NEXT_OBLIGATIONS row 0. Verdict: CONTRADICTED and STALE.
   - The record `results/round4-m1-replay-20261118/phase3/results.json` shows case 108 started at 06:41:58Z and case 109 at 06:44:18Z. That is before the tracker's 06:44Z "BLOCKED" update.
   - At 06:51:25Z, 114 of 158 cases are done: 110 AS_RECORDED, 1 EXIT_EQUAL_REASON_DIFFERS (case 005), and 3 NOT_RUN_NO_SOURCE (094, 097, 098). The backup branch has no file with the recorded SHA-256 for those three.
   - Row 0 says "cases 109 to 158". At 06:35Z the next case was 108. Because three cases have no source, "replay to 158" cannot finish. At most 155 cases can run.
   - Fix F5 to: "RUNNING again from 06:41:58Z (mains power); 114 of 158 at 06:51Z; 3 cases have no source, so at most 155 can run."

2. **Heavy processes run at the same time now.** Rule 11 and text 15 ("do not disturb the 158-case replay") are breached.
   - Live state: replay driver pid 79903 is running HOL pid 60247 (about 2.1 GB resident). At the same time a worker's `dafny verify impl/Refund.dfy gate/refund/Bindings.dfy` runs with z3, a worker's `tsx minter.ts` runs, and several `dafny_locked.sh` calls wait in the queue.
   - Swap is 8,590 of 9,216 MiB used (626 MiB free). Free pages are about 62 MiB.
   - Case 005 failed earlier with "Interrupt" at a resident size of 1,952 MiB. A second failure of that kind is a real risk.
   - Correction: pause the Dafny queue while a HOL case runs, or record this as a known risk.

3. **Owner authority rests on pasted texts.**
   - The graph labels assumptions as "ASSUMPTION (Q3a)", "(Q1)" and "(owner decisions Q1 and Q5)". Texts 1 and 2 are pasted texts with no words of the owner's own (OWNER_DECISIONS line 3; U473 calls this "an inference"). Write: "(Q3a: a pasted text taken as the owner's decision; inference, U473)".
   - The replay started on a pasted advisor text (U471: "Inference: the paste is the owner's instruction") and on Q6, which is also pasted.
   - The merge of pull request 54 had a pasted text as its basis (U471).
   - NEXT_OBLIGATIONS says L1 is "authorized by text 9 item 2, text 15 item 7". Both texts are pasted.
   - Wave 5 started on the owner's own words, which came after text 15 (pasted, "no additional parallel workers"). That is a valid basis. But OWNER_DECISIONS has no text 16 or 17, the cut-off pasted wave-5 mission is not saved, and wave 5 has no unsure.md entry and no ROADMAP section.
   - Correct uses of the owner's own words: merge 55 ("merge 55"), waves 1 and 4, texts 6 and 7.

4. **Some MACHINE-CHECKED results have no durable stored record.**
   - S3a, the orchestrator's run at 06:29Z: the only file is `scratch/m1b/Y10/S3a-noHex/my-audit.md`, the audit output written at 06:29:38Z. It is byte-equal to `gate/expected-audit.md`; I checked with `cmp`. No log of the verify run exists, so "exit 0, 1486" is stated only. The worker's run IS stored (`Y10/runs/S3a-noHex`: exit=0, "1486 verified"), and the proof file digest `0d67b483…` matches.
   - U5a, SinkCore: the orchestrator's record is `scratch/sinkcore.csv` (56 Passed, 28 rows of SinkCore). It is in the session scratch folder only.
   - S3: the runs are in `build/m1b-linked-refund/attempt-0001` and `attempt-0002` (a gitignored folder) and agree with U473: run 1 failed by the runner defect, run 2 passed.
   - The current `run_check.py`, with the FlatCore pin added in 244cf037, has NEVER run. It also cannot reproduce S3a, because the stored inputs still contain the HexConversion module.
   - Correction: copy these logs under `proposals/…/proofs/*/records/`. Until then, mark these cells "record: session scratch only".

5. **README.md line 106 claims too much.**
   - It says the model "produces output equal to the decision definition". But X3 allows a resource stop with a PREFIX of the output, also the empty one. Write instead: "either halts with output equal to the rendered decision, or stops at a resource limit with a prefix of it (possibly empty)".
   - It omits the processor-bits finding (X5: TBI0 and SA0).
   - It lists "an approved profile" as open, which contradicts Q1.
   - "158 recorded cases not replayed" is stale: 114 have run.
   - C3 says each corrected sentence is "marked with the date". The README correction has no marker.

6. **Pull request 56 is called documents only, but it carries scripts.**
   - Its squash subject says "(documents and a Dafny proof under proposals/…)" and its body says "Records and one proof". It carries 12 `.py` and 2 `.sml` files (for example `run_check.py`, `verify_m1_manifest.py`, `walk_sha1_chain.py`, `closure_export.sml`).
   - U475 corrected this mistake for pull request 57 only. Add a correction for 56 too.
   - The body says "18 worker reports". The file list has 17; the 18th (C1a) came in pull request 57.

7. **Some exits are stated only (no record found):**
   - the orchestrator's two `expect false;` runs (exits 4 and 0, "6 verified"). The worker's run is in `zero-review/results.json`.
   - "with a caller that authorizes on status 0 alone: exit 1, 9 rows differ". The script has no option for that variant, and `exit_status_controls_results.json` holds only the passing run.
   - the pull request 56 body's `check_frozen_pr_gate.py` and `check_links.py` exits (0; 0).

8. **The graph's section 2 is stale against section 7.** S3a, S4, U5, U7 and V1 ("the second extraction is NOT DONE") still show the old classes. The S3 "upgrade" column still asks for removal of the axiom.
   - The U5a upgrade is premature. The orchestrator's own open question (are inherited lemmas checked again?) is not answered. The W9 results and the D10 review show that Dafny 4.11 does NOT verify inherited bodies again.
   - Correction: add a pointer to section 7 in each changed row. Mark U5a "MACHINE-CHECKED for the lemmas verified in SinkCore itself; inherited model lemmas not checked again (open)".

9. **E3 class.** "MACHINE-CHECKED for the refusal" rests on one hosted REJECTED run (44454558079; I confirmed "outcome REJECTED"). Write: "one hosted run REJECTED (an instance, not a rule); E2 shows that a merge can bypass it".

10. **NEXT_OBLIGATIONS §1** says "Safety of a consumer rests on this lemma and on 'output is a prefix'". The prefix property is a model property only (X3). Add: "for the real process it also needs X8 and X9 (MISSING)".

11. **"Independent" used for same-machine, same-model work.** X7: "named by two workers independently". D12: "an independent parser". README line 102: "three independent reviews" (an earlier record; I did not check its basis). Write "separately, same model family and same machine".

12. **Gate run ids.**
    - ROADMAP U476 gives pull request 58 as head 685d07f5, run 44472601209. The present head is fa4f62e7, run 44473309248, exit 3, UNSUPPORTED. Run 44473281459 (head ffa315e7) also gave exit 3.
    - U475 names no run for pull request 57. It is run 44469061507, exit 3, UNSUPPORTED (I read the log).

13. **Case 005 "ran out of memory" is an inference.** The record says: "Interrupt" in TheoryReader.sml:68, after 27.4 s, `timed_out` false, maximum resident size 1,952 MiB. Write: "interrupted while it loaded theories (probably memory pressure; not shown)".

14. **Small inconsistencies.**
    - TRACKER I.1d and RESULTS.md say the audit covered 33 files; `run_check` audited 34.
    - D6 "486 SIGKILL runs": there were 520 runs with 486 kills. The 206 kills inside an open transaction are confirmed.

15. **Wrong solver path in the rules.** Rule 4 of WAVE4_RULES gives `.toolchain/z3-4.12.1/z3`, which does not exist. The gate uses `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1`. This is the probable cause of the "wrong solver path" exit 4 in U475.

### (1) MACHINE-CHECKED rows

| Link | Record found | Digest recomputed | Verdict |
| --- | --- | --- | --- |
| S2, U1, U4 | Slice 1 and F2.0 records exist (`proposals/forge2-pillar2-*/records`) | – | CONSISTENT |
| S3 | worker CSVs: 1489 rows, all Passed (1342 Std + 89 other refund rows + 58 new); `build/` attempts 1 and 2 | RefundSpec `90a21c71`, Refund `04168824`, RefundExact `58d354e9`, LinkedRefund `0d67b483`, FlatCore `a89484e3`: all equal | CONSISTENT (record not durable) |
| S3a | worker run stored; orchestrator's run: audit file only | proof file equal; audit equal to the baseline | orchestrator's verify run UNSUPPORTED (stated only) |
| S5 | `export-0003` on the backup branch: output 3,621 bytes `58154ddf`, input = FlatCore | equal | CONSISTENT |
| X1–X4, X14 | tracked `final-cases/e4-0001` and `fs-r4-0001` logs show "CHECKED …" lines; the theorems are at lines 238–297 | – | CONSISTENT |
| V1 | executable `b8ed5ec2`; slices `3c67983c` and `68d3f080` | recomputed: equal | CONSISTENT |
| E3 | run 44454558079 REJECTED | – | CONSISTENT as a run; the class claims too much (item 9) |
| U5a (section 7) | scratch `sinkcore.csv` only | SinkCore `198474e4` equals the worker's file | UNSUPPORTED as a durable record; premature (item 8) |

### (2) Numbers

All of these agree with the records:
- the 45 links and the counts 12/9/7/17 (I recounted the tables);
- 1489 = 1342 + 147, and 58 rows of the new modules;
- 1486 (1339 Std rows; the 3 rows of HexConversion are gone);
- 56 and 28 (SinkCore);
- the 53 submissions: 9 correct ones admitted, 4 correct ones refused, 7 wrong or dishonest ones admitted, 31 refused, plus 2 dead-code ones;
- 8,011 / 6,363 / 68, and 82 planted results;
- 486 kills;
- 18 rows (exit-status controls);
- the replay counts 32, 33, 65, 82 and 108 (each correct within its stated minute).

Stale: items 1, 5, 8 and 12.

### (3) Timestamps

All merge times (pull requests 48 to 57), the close time of 53, the commit times and the status times of U473 to U476 agree with GitHub and git. Errors exist only in the TRACKER F5 and I.4a rows (item 1). The earlier clock errors are already corrected by U471 and U472.

### (6) Live state, now

- Branch `docs/m1b-wave4` at fa4f62e7. The only uncommitted tracked file is TRACKER.md (the wave-5 section).
- The local `main` ref is stale: 8e772b55, while origin/main is cc20207b.
- 21 extra worktrees from older sessions exist.
- Pull request 58 is OPEN; its gate gave exit 3 (UNSUPPORTED). Older open pull requests: 1, 2, 3, 5, 14, 15, 34, 36, 37.
- `main` is `protected:false` and the protection endpoint answers HTTP 403. The repository is private.
- Power: AC, 80%, not charging.
- Processes: see items 1 and 2.

### (7) Rules

- Pull requests 56, 57 and 58 touch no protected path (108, 14 and 212 files, compared against `PROTECTED_DIRS` and `PROTECTED_FILES` in `gate/incremental.py`).
- unsure.md changes only by appends: one hunk per pull request, 0 removed lines. The working tree has no diff of unsure.md.

| step | status | evidence or blocker |
| --- | --- | --- |
| G11 reconciliation | REPORTED | this report; the scratch files above |
| durable records for S3a, U5a, S3 | OPEN | item 4 |
| tracker, ROADMAP and NEXT_OBLIGATIONS replay state | OPEN | item 1 |

What I could not determine: who typed the merges of 56 and 57 (GitHub shows one account for the owner and the agent); whether case 005 failed from lack of memory.
