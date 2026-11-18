# M1 chain replay on the rebuilt pinned tools (2026-11-18)

`end_to_end=false`. No M1 theorem is claimed and M1 stays open.
"Replayed" means: a fresh HOL run of a committed script exited 0 and
exported its theory. This is a same-machine replay with the same pins.
It is not a clean-room replay and not an independent replay.

Owner decision: text 4 in
`proposals/round4-20261117/OWNER_CLOSEOUT_TEXTS.md` (its own run, budget
21,600 s). Run by one background agent, 170 tool calls, 2026-11-18
05:37Z to 07:34Z. Entry: `unsure.md` M1R-1. Records: `records/` (297
files, `MANIFEST.json`; in text files the home prefix is written
`<HOME>`). The run folders themselves are under `results/` and are not
tracked.

## Result

| Check | Actual exit / result |
| --- | --- |
| Forge theories planned; replayed with exit 0; failed; blocked | 71; 71; 0; 0 |
| Fresh `.dat`, `.sig`, `.sml` equal to the SHA-256 in the old packet records | 71 of 71 equal, 0 different |
| Import check `imp4-0001` of `forge_refundSlideProfileA` | exit 0; IMPORTED_COUNT 15, MISMATCH_COUNT 0 |
| `fs` joint-premise run (`fs-0002.sml`, unchanged), new theory `forge_refundInputSat` | exit 0 at the first attempt of this replay; 13 theorems, 1 definition |
| Import check of `forge_refundInputSat` (written in this run) | exit 0; IMPORTED_COUNT 8, MISMATCH_COUNT 0 |
| Commands recorded | 92: 90 exit 0; 1 exit 1 (a Holmake dry run, missing include folder, no HOL process); 1 stopped by the agent after 20 s and run again |
| Upstream tool objects that were missing and were built first | 16 theories, 3 library objects; Holmake exit 0 each; 0 existing theory files changed (1,913 listed before) |
| Time used | 7,034 s of 21,600 s; no sleep gap |

New in this run: `refund_profile_a_sl_all_premises_satisfiable_at_0x4000`
(the eleven premises of `refund_profile_a_sl` hold together for one
constructed state at slide 0x4000). The same script failed once on
2026-11-17 in an earlier form (`fs-0001`) and could not run as `fs-0002`
then, because its parent theories had been deleted.

## Checks by the coordinating agent (not by the replay agent)

| Check | Result |
| --- | --- |
| `commands.json`: count of `actual_exit` values | 90 × 0, 1 × 1, 1 × none (stopped), as reported |
| `summary.json` totals; `comparison.json` | 71 planned, 71 exit 0; 72 rows `equal` |
| `tooltree-compare-final.json` | `existing_changed` 0, `existing_missing` 0, 75 new files |
| SHA-256 of the fresh `forge_refundSlideProfileATheory.dat`, `.sig`, `.sml` against `m1-slide-s4-s6-20261117` | equal (`4ff2a7e2…`, `d61d4460…`, `065df441…`); file written 2026-11-18 07:25Z |
| SHA-256 of the fresh `forge_refundImageTheory.dat`, `.sig` against `m1-loader-memory-20261115` | equal (`f778ed26…`, `32cedef9…`) |
| SHA-256 of the restored executable against the tracked copy | equal (`b8ed5ec2…7bb8`) |
| `fs-r4-0001/stdout.log`; `fs-imp-r4-0001/stdout.log` | theorem saved and checked, `EXACT_COMPLETE`; `IMPORTED_COUNT 8 MISMATCH_COUNT 0` |
| Tracked files of the repository changed by the run | 0 |

These are spot checks of 2 of the 71 theories plus the records. The
other 69 comparisons are the replay agent's.

## Limits

- "Equal" means equal to hashes that the earlier runs on this machine
  recorded. It shows that the committed scripts give the same theories
  again on tools rebuilt from the same pins. It does not show that the
  statements are the right ones.
- Not replayed: Forge theories outside the closure of
  `forge_refundSlideProfileA` (for example `forge_refundWriteArgs`,
  `forge_refundWriteWord`, `forge_refundInstallReach`), the negative
  controls and the repeat cases of the packets, and every import check
  except `imp4-0001`.
- The 16 upstream theories built in this run have no stored hash.
- The executable was checked by SHA-256 only. It was not executed.
- The items that block M1 in `m1-closure-audit-20261116` stay open:
  approval of Profile A, the link from the approved R1–R5 contract to
  the HOL model, the compiler-premise ledger, a clean replay, an
  independent replay. The joint-premise theorem is for one slide
  (0x4000) and one constructed state.
- The recorded tool-identity list of `run_arm8_case.py` cannot match
  after a rebuild: 4 of its 15 files differ, 11 are the same.
- One slip of the replay agent, reported by itself: a read-only
  `git status` inside the CakeML checkout after it was told to run no
  git command there. No file changed.

## Final report of the replay agent (its text; home prefix written `<HOME>`)

M1 CHAIN REPLAY, 2026-11-18. end_to_end=false. No M1 theorem is claimed. "Replayed" = a fresh HOL run of a committed script exited 0 and exported its theory. It is not "proved end to end".

RESULT IN ONE LINE: 71 of 71 planned theories replayed with exit 0; all 71 have `.dat`, `.sig` and `.sml` byte-identical (SHA-256) to the hashes in the old packet records; import check imp4-0001 exit 0; the fs joint-premise run passed at the first attempt (never passed before). Time used: 7,034 s of 21,600 s.

### 1. Table
Columns: order | theory | source packet | exit | wall s | statement comparison | note. Comparison "equal" = fresh `.dat` (statements) and `.sig` equal the recorded SHA-256.

```
 1|forge_refund|verified-backend-20261104|0|36.1|equal|Holmake -j1; first dry run exit 1 (see 3), fixed
 2|forge_refund_compile|compiler-relation-20261104|0|12.0|equal|Holmake -j1
 3|forge_refund_call|caller-20261104|0|86.3|equal|Holmake -j1
 4|forge_refund_io|io-schema-20261104|0|16.1|equal|Holmake -j1
 5|forge_refundCertifiedProg|certified-library-20261104|0|52.2|equal|Holmake -j1
 6|forge_refundWireProg|stdio-contract-20261104|0|76.2|equal|Holmake -j1
 7|forge_refundStdioProg|stdio-contract-20261104|0|68.2|equal|Holmake -j1
 8|forge_refundWholeProg|whole-program-20261104|0|92.3|equal|Holmake -j1
 9|forge_refundArm8Compile|arm8-compile-20261104|0|82.3|equal|Holmake -j1; refund.S SHA-256 = recorded 4c750e4f…1757
10|forge_refundLabClosure|m1-p1-lab-closure-20261113|0|124.5|equal|first launch stopped by me after 20 s (see 3)
11|forge_refundLabResolve|m1-p1-lab-closure-20261113|0|96.3|equal|
12|forge_labRegionInvariant|m1-p1-lab-closure-20261113|0|10.0|equal|
13|forge_labRegionStep|m1-p2-lab-invariant-20261113|0|12.0|equal|
14|forge_labRegionWalk|m1-p2-lab-invariant-20261113|0|8.0|equal|
15|forge_refundLabRun|m1-p2-lab-invariant-20261113|0|210.7|equal|
16|forge_labRegionAligned|m1-lab-exclusion-20261113|0|20.1|equal|
17|forge_targetInstallPrefix|m1-p3-prefix-20261113|0|6.0|equal|
18|forge_simZeroCase|m1-p3-zero-case-20261113|0|6.0|equal|
19|forge_simLayout|m1-p3-layout-20261113|0|6.0|equal|
20|forge_simRoot|m1-p3-root-20261113|0|12.1|equal|
21|forge_simReplay|m1-p3-replay-20261113|0|86.3|equal|
22|forge_refundLabFiltered|m1-exact-exclusion-20261114|0|292.9|equal|
23|forge_refundExactExclusion|m1-exact-exclusion-20261114|0|50.2|equal|
24|forge_refundExclusionChain|m1-exact-exclusion-20261114|0|58.2|equal|
25|forge_installHandlerIrrelevant|m1-exact-exclusion-20261114|0|50.2|equal|
26|forge_refundExclusionFinal|m1-exact-exclusion-20261114|0|36.1|equal|
27|forge_refundCompileFacts|m1-compile-facts-20261114|0|80.3|equal|preload rebuilt by hash (see 4)
28|forge_refundExclusionArm8|m1-compile-facts-20261114|0|54.2|equal|
29|forge_compileCorrectLabFacts|m1-compile-correct-20261114|0|172.6|equal|
30|forge_targetInstallBridge|target-install-bridge-20261105|0|8.0|equal|direct mode
31|forge_refundInstallHandler|m1-exclusion-profile-20261113|0|22.1|equal|
32|forge_refundExclusionSource|m1-compile-correct-20261114|0|54.2|equal|
33|forge_compileCorrectControl|m1-compile-correct-20261114|0|178.6|equal|
34|forge_refundExclusionReal|m1-compile-correct-20261114|0|50.2|equal|
35|forge_refundSourceNonFail|m1-source-nonfail-20261115|0|56.2|equal|
36|forge_refundStartupClause|m1-source-nonfail-20261115|0|54.1|equal|
37|forge_refundRejectNonFail|m1-reject-startup-20261115|0|146.5|equal|
38|forge_refundCmlMainStep|m1-reject-startup-20261115|0|16.1|equal|direct mode (ARMv8)
39|forge_refundStartupBridge|m1-reject-startup-20261115|0|66.2|equal|
40|forge_refundCmlMainFrame|m1-loader-memory-20261115|0|16.0|equal|direct mode (ARMv8)
41|forge_loaderMemLemmas|m1-loader-memory-20261115|0|58.2|equal|
42|forge_refundImage|m1-loader-memory-20261115|0|264.9|equal|reads the executable; peak RSS 4,768 MiB
43|forge_refundLoaderMemory|m1-loader-memory-20261115|0|64.2|equal|
44|forge_refundEntrySat|m1-loader-memory-20261115|0|58.2|equal|
45|forge_refundInstalledDomains|m1-memory-domain-20261115|0|56.2|equal|
46|forge_refundInstalledAssembly|m1-memory-domain-20261115|0|62.2|equal|
47|forge_refundFfiFacts|m1-residual-20261115|0|76.3|equal|
48|forge_refundResidual|m1-residual-20261115|0|72.2|equal|
49|forge_refundEnvModel|m1-env-model-20261116|0|100.3|equal|
50|forge_refundFficloseStep|m1-fficlose-stub-20261116|0|12.0|equal|direct mode (ARMv8)
51|forge_refundFficloseBridge|m1-fficlose-stub-20261116|0|94.3|equal|
52|forge_refundFficloseAssert|m1-fficlose-compose-20261116|0|10.0|equal|direct mode (ARMv8)
53|forge_refundFficloseCompose|m1-fficlose-compose-20261116|0|74.2|equal|
54|forge_refundCallSite|m1-callsite-20261116|0|72.3|equal|
55|forge_refundSignedLen|m1-signed-len-20261116|0|74.2|equal|
56|forge_refundFfiwriteStep|m1-ffiwrite-20261116|0|24.1|equal|direct mode (ARMv8)
57|forge_refundFfiwritePath|m1-ffiwrite-20261116|0|120.4|equal|
58|forge_refundFfiwriteCompose|m1-ffiwrite-20261116|0|72.3|equal|
59|forge_refundFfiwriteSite|m1-ffiwrite-20261116|0|74.2|equal|
60|forge_refundFfiwriteUnaligned|m1-ffiwrite-success-20261116|0|8.0|equal|direct mode (ARMv8)
61|forge_refundFfiwriteSuccess|m1-ffiwrite-success-20261116|0|76.2|equal|
62|forge_refundFfiwriteFault|m1-ffiwrite-success-20261116|0|6.0|equal|direct mode (ARMv8)
63|forge_refundWriteReach|m1-write-reach-20261116|0|78.3|equal|
64|forge_refundCmlMainSlide|m1-slide-s1-s2-20261117|0|24.1|equal|direct mode (ARMv8)
65|forge_refundSlideEntry|m1-slide-s1-s2-20261117|0|104.4|equal|
66|forge_refundCmlMainFrameSlide|m1-slide-s3-20261117|0|20.1|equal|direct mode (ARMv8); S3 copy folder
67|forge_refundSlideDomains|m1-slide-s3-20261117|0|86.3|equal|S3 copy folder
68|forge_refundSlideInstalled|m1-slide-s3-20261117|0|90.3|equal|S3 copy folder
69|forge_refundSlideSat|m1-slide-s3-20261117|0|96.3|equal|S3 copy folder
70|forge_refundProfileA|m1-profile-a-slide0-20261117|0|88.3|equal|
71|forge_refundSlideProfileA (e4-0001)|m1-slide-s4-s6-20261117|0|108.4|equal|S3 copy folder; marker EXACT_COMPLETE
72|import check imp4-0001 (no theory)|m1-slide-s4-s6-20261117|0|78.3|stdout equal to packet except timing|IMPORTED_COUNT 15, MISMATCH_COUNT 0
73|forge_refundInputSat (fs joint premise)|m1-slide-s4-s6-20261117, fs-0002.sml unchanged|0|84.3|no stored statement|first attempt; 13 theorems + 1 definition
74|import check of forge_refundInputSat|none: written in this run|0|72.2|exact match, see below|IMPORTED_COUNT 8, MISMATCH_COUNT 0
```

### 2. Totals
- Theories planned 71 (9 in the tool tree, 61 of deps-e4, forge_refundSlideProfileA). Replayed with exit 0: 71. Failed: 0. Blocked: 0 (after the allowed upstream builds). Not reached: 0. BLOCKED_NO_SOURCE: 0.
- Statement comparison: 71 equal, 0 different. 1,225 exported theorem and definition names in total. Stdout of the 63 case runs against the packet logs: 4 identical, 58 identical except "took … to build" lines, 1 (f1-0001) differs only in the S3 path inside a compiler warning.
- fs: `fs-r4-0001` = packet file `fs-0002.sml`, byte-identical (SHA-256 e69e2753…fe46), no repair needed. No `LEMMA_FAILED`, no oracle theorem. Failing attempts in this replay: 0 (old failing attempt fs-0001 of 2026-11-17 counts as 1 of 5). Stored: `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` (∃s h stk e envmc fs cl. 11 premise conjuncts) and `refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000`. My import check shows the joint statement is aconv to the antecedent of the stored `refund_profile_a_sl` at sl = 0x4000w under seven ∃; 14 stored items have only the DISK_THM tag; 3 wrong statements were rejected. The second theorem has a structural check only.
- Time: T0 2026-11-18T05:37:06Z, last command ended 07:34:20Z = 7,034 s of 21,600 s. Sleep gaps: 0 s. 92 commands recorded.

### 3. Failed, stopped or blocked items
- BLOCKER FOUND IN PHASE 0 (resolved with your permission): the tool tree lacked upstream objects that the chain imports. Built with dry run first, `nice -n 15 Holmake --no-cache -j1`, new files only:
  - `up-dafny-proofs`, cwd `cakeml/compiler/dafny/proofs`, target `dafny_to_cakemlProofTheory.uo`: exit 0, 108.4 s, 11 theories (dafny_ast, dafny_freshen, result_monad, dafny_to_cakeml, dafny_misc, dafny_semanticPrimitives, dafnyProps, dafny_evaluate, dafny_evaluateProps, dafny_freshenProof, dafny_to_cakemlProof).
  - `up-sexp-to-dafny`, cwd `cakeml/compiler/dafny`, target `sexp_to_dafnyTheory.uo`: exit 0, 14.0 s.
  - `up-arm8-config-proof`, cwd `cakeml/compiler/backend/arm8/proofs`, target `arm8_configProofTheory.uo`: exit 0, 1,174.1 s; 4 theories (asmSigned, arm8_targetProofLemmas, arm8_targetProof, arm8_configProof) and 3 library objects (arm8_stepLib.ui, arm8_stepLib.uo, arm8_targetProofLib.uo). arm8_targetProofLemmas was not in my list of 15 (16 upstream theories in total).
  - `up-arm8-steplib`: dry run only, nothing to build (the command above had built it).
  - Check after the builds and again at the end: "0 existing theory files changed" (1,913 files listed before; 75 new theory files = 48 upstream + 27 Forge).
- T01 first dry run, environment failure, no HOL process: `caffeinate -i -s nice -n 15 <TC>/HOL/bin/Holmake --no-cache -j1 -n forge_refundTheory.uo` in `…/cakeml/compiler/dafny/forge_refund_experiment`, exit 1. Last lines: "Holmake: Attempt to recurse into non-existent directory: $(CAKEMLDIR)/compiler/dafny/forge_refundProg_experiment" / "(Probably a result of bad INCLUDES spec.)". Cause: the recorded Holmakefile of forge_refundCertifiedProg has `INCLUDES = ../forge_refundProg_experiment`. Fix: I created that folder EMPTY; Holmakefile text unchanged. Rerun exit 0.
- C10 first launch: I stopped my own driver and its HOL child about 20 s after the start (status STOPPED_BY_OPERATOR, no exit code) to relaunch the driver detached from the tool timeout. Not a proof attempt. Partial folder renamed `proof-0001.replay-stopped-by-operator-0001`. Rerun exit 0.
- Proof failures: none. Memory failures: none. Guard refusals: none.

### 4. NOT replayed, NOT verified; changes
Not replayed or verified:
- Forge theories outside the closure of deps-e4, for example forge_refundWriteArgs, forge_refundWriteWord, forge_refundInstallReach, forge_refundAllocBackend, forge_refundLabExclusion, forge_refundLabRunInit, forge_refundCmlMainSat, forge_refundArm8Proof and the pre-U345 theories.
- Negative controls, repeat cases and import checks of the packets, except imp4-0001.
- No clean-room and no independent replay: same machine, same pins, same agent family. "Equal" means equal to hashes that the earlier runs recorded. The 16 upstream theories have no stored hash to compare.
- The executable was checked by SHA-256 only (b8ed5ec2…7bb8, equal). It was not executed. Profile A premises, the contract link R1–R5, the loader and the FFI assumptions stay as they were.
- The recorded tool-identity check of `run_arm8_case.py` cannot pass: 4 of its 15 files differ after the rebuild (bin/hol, cakeml-heap, arm8-heap, l3-heap); 11 are the same.

Path and environment changes:
- Holmake `-j 2` → `-j1`, `nice -n 15`, every command under `caffeinate -i -s`, a `-n` dry run before each Holmake command.
- The 9 ARMv8-step cases and bridge-0005 ran in direct mode (same argv, cwd, environment; my resource guard).
- f1, d3, a3, sat, e4, imp4, fs ran in `<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001`; dependency lists path-mapped; no case read the old S3 folder (0 of its 183 files changed).
- New folders under original names: 30 `results/refund-*-local-*` folders, `results/refund-native-audit-2026-11-04`, `results/refund-target-install-bridge-2026-11-05`; in the tool tree 10 `forge_*_experiment` folders plus the empty `forge_refundProg_experiment`. 273 restored files (sources, runners, lists, one old command record, the executable); no old built output was copied.
- One preload file (`preload.sml` of the exact-exclusion and compile-facts run folders) is in no packet. I rebuilt it as the first two lines of the stored three-line preload; its SHA-256 equals the recorded input hash c3cbcccc…de5e.
- `bridge-0005/command.json`: the old packet record was restored because every `run_case.py` reads it; after the fresh run it is kept as `command.packet-record-20261105.json`.
- Disclosure: after your condition "no git operation inside the tool tree" I ran one read-only `git status --short` in the cakeml checkout. No file changed; it was a slip.
- Holmake wrote `.hol/make-deps`, `.hol/logs`, `.uo`/`.ui` and lock files in upstream folders (accepted in your answer).

### 5. Records and resources
- Folder: `<HOME>/forge/results/round4-m1-replay-20261118/`
  - `plan.json` (72 steps, restore map), `commands.json` (92 commands, home prefix as `<HOME>`), `logs/` (211 files), `status.json`, `comparison.json`, `summary.json`
  - `tooltree-listing-before.json`, `upstream/tooltree-compare-after-upstream.json`, `tooltree-compare-final.json`, `upstream/*-dryrun-check.json`
  - `restore-record-results.json`, `restore-record-tooltree.json`, `environment-changes.json`, `arm8-tool-identity.json`, `budget.json`
  - `fs/attempts.json`; fs case folders `slide-s3-copy/attempt-0001/fs-r4-0001` and `fs-imp-r4-0001`; scripts in `scripts/`
- Fresh final theory: `<HOME>/forge/results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001/e4-0001/.hol/objs/forge_refundSlideProfileATheory.dat`
- Resources: peak child RSS 4,768 MiB (forge_refundImage); typical CakeML-context case 2.3 to 3.5 GiB. Memory free 31 to 59 percent, disk free 118 to 119 GiB, swap about 11 of 12 GiB used at the start. No sleep gap. One HOL process at a time. No process of mine is left running.
- Not done by me: no commit, no push, no edit of `unsure.md`, `ROADMAP.md`, memory or any tracking file. U-entries and tracking updates are for you.
