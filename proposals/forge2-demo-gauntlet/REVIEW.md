# Wave Gate 3: the one fresh-context review and its disposition

One review, by an agent with a fresh context, of the new executable
code: `scripts/demo_gauntlet.py` and `tests/demo-gauntlet/sink_tool.ts`.
The reviewer got the code and the claim, not my results. Date:
2026-11-19 (UTC). 14 tool calls, about 9.5 minutes. It worked in a
scratch clone and ran the script and four broken components of its own.

## 1. Result

| Class | Count | Findings |
| --- | --- | --- |
| An attack succeeds and the default full run exits 0 | 0 | — |
| FAIL-OPEN at a reduced flood size | 1 | R1: with `--flood-mb` below about 250, an issuer that keeps every byte of the flood passed the memory bound |
| HIGH (hygiene) | 2 | R2, R3: on two failure paths a sampler thread kept the script alive after "GAUNTLET FAILED", with the issuer process still running |
| MEDIUM | 2 | R4 (a partial run exited 0 with the word PASSED), R5 (one printed count could not be other than 0) |
| LOW | 5 | R6 to R10 |

My statements that were too strong before the review: "commands of
this script that start Dafny or Z3: 0 of 5" measured nothing (R5);
"35 attack attempts, 0 effects from them" printed two constants (R7);
the memory bound was printed as held at every flood size (R1).

## 2. Disposition (repairs in one pass; NOT reviewed again)

| Finding | What I did |
| --- | --- |
| R1 | REPAIRED. The memory bound is checked only for a flood of 512 MiB or more (twice the limit of 256 MiB). Below that the script prints "NOT CHECKED", the run is REDUCED, and the exit code is 3, not 0. One more memory sample is taken after the flood is read to its end. STATED, not repaired: at 600 MiB an issuer that keeps less than 256 MiB of the flood (about 43 percent) passes the bound |
| R2 | REPAIRED. The flood section stops its sampler in a `finally`; the sampler threads are daemon threads; the issuer process is killed in a `finally` of Act 2 |
| R3 | REPAIRED. The control sampler of Act 3 ends in a `finally` |
| R4 | REPAIRED. The acts are sorted and without repeats. A partial or reduced run prints "NOT COMPLETE", has `complete: false` in its record and exits 3 |
| R5 | REPAIRED. The count is removed. The output says that the sampler is the only check and that a short process can be missed |
| R6 | REPAIRED IN PART. No process is left out by a text match. The control counts only prover processes whose command line holds the output path of this run's compile. An empty or failed process list is an error. NOT repaired: the sampler counts the whole machine, so another Dafny job makes Act 3 fail (stated in the demo document) |
| R7 | REPAIRED. Attempts are counted as they are made. The effect count is computed from the final outbox |
| R8 | REPAIRED. Every answer line has a time limit of 120 s and must be one line; after the input is closed the issuer's output must be empty |
| R9 | REPAIRED. `operations.json` writes `<repository>` and `<home>` in place of the paths |
| R10 | REPAIRED IN PART. The docstring states the real upper limit. NOT changed: `sink_tool.ts report` on a path with no database creates an empty database before it fails (the demo's paths do not reach this); the 2.5 s lead of the common start can fail as "late" on a loaded machine (fail-closed) |

Left open: no second review of the repairs (the directive allows one
review); the reviewer did not check a flood above 600 MiB, one full
`1,2,3` run in one process, the demo document or the mutation runner.

## 3. The review text (verbatim)

Review of `scripts/demo_gauntlet.py` and `tests/demo-gauntlet/sink_tool.ts`. I found no path where an attack succeeds and the default full run (`--flood-mb 600`, all acts) still exits 0. I found one confirmed hole in the memory bound at small floods, two confirmed hangs on failure paths, and several weaker items.

All experiments ran in a scratch clone in the session scratch folder (`review3/base`). I changed no file in the repository and left no child process.

### Findings

**R1. FAIL-OPEN at reduced flood size, CONFIRMED. `demo_gauntlet.py` lines 77, 344, 353, 470, 487-489.**
The memory bound is an absolute 256 MiB of growth. It does not depend on the flood size. For any `--flood-mb` below about 250, an issuer that keeps every flood byte passes. The final line still reads "GAUNTLET PASSED", because `complete` looks only at `acts`.
- Reproduction: in the clone, add `leak.push(Buffer.from(chunk))` as the first statement of the `data` handler in `ts/refund-finality/minter.ts`. Run `python3 scripts/demo_gauntlet.py --acts 2 --flood-mb 200`.
- Result: exit 0, "resident memory: 71 MiB before, 222 MiB sampled peak", kernel peak 304 MiB, PASSED.
- The same mutant at `--flood-mb 600` fails correctly: "GREW WITH THE FLOOD (497 MiB)", exit 1.
- An issuer that keeps less than about 40% of the bytes also passes at 600 (reasoned, not run).
- At 64 MiB the flood takes 0.03 s, shorter than one 50 ms sampler period. "Sampled peak during the flood" can then hold no sample from the flood.
- Repair: refuse the memory claim when `flood_mib` is below a floor such as 4 × the limit. Otherwise print "memory bound NOT CHECKED at this size" and make the final line "REDUCED" instead of "PASSED". Take one RSS sample after the valid request.

**R2. HIGH (hygiene), CONFIRMED. Lines 320-338.**
The 2d sampler thread is not a daemon. It stops only on the `BrokenPipeError` path. Any other exception between `sampler.start()` and `stop.set()` leaves it running. The script prints "GAUNTLET FAILED" and then never exits, because Python still holds the issuer's stdin, so the issuer lives and the sampler loops.
- Reproduction: in the clone, make the issuer write the "message too long" line twice. Run `--acts 2 --flood-mb 8`.
- Result: "GAUNTLET FAILED: act 2: the issuer answered another message". After 90 s the Python process and the `minter.ts` process were both still alive.
- Repair: wrap the flood section in `try/finally: stop.set(); sampler.join()`. Use `daemon=True`. Close the issuer's stdin, or kill the issuer, in a `finally` of `act2`.

**R3. HIGH (hygiene), CONFIRMED. Lines 401-403.**
`control = Watch()` has no `try/finally`. If `compile_core` raises, the control thread never stops and the process hangs after "GAUNTLET FAILED". The causes include a Dafny failure and a core that differs from the record.
- Reproduction: a copy of the script with one extra space in `BOOKING_FOOTER`, run with `--acts 3`.
- Result: "CORE_MODULE: the compiled core is not the module of the evidence record", then still running after 120 s.
- Repair: `try: compile_core(...) finally: seen_at_compile = control.end()`. Make the `Watch` thread a daemon.

**R4. MEDIUM, CONFIRMED by run. Lines 487-490.**
A partial run exits 0. The line reads "GAUNTLET PARTIAL (acts 2 only): PASSED ... Every required result was observed in this run."
- A caller that reads only the exit code, or greps for "PASSED", takes a skipped act as a pass.
- `--acts 3,1` runs act 1 before act 3 but prints "acts 3,1". `--acts 3,2,1` runs all three acts and reports PARTIAL.
- Repair: sort and de-duplicate `acts`. Give a partial run its own exit code (for example 3) and no word "PASSED". Write `complete: false` into `record.json`.

**R5. MEDIUM, PLAUSIBLE (by reading). Lines 442-448.**
`own` cannot be other than 0 and `len(during)` cannot differ from `len(optimizers)`. The loop appends exactly one command per optimizer, each with `argv[0] == 'node'`. The printed "commands of this script that start Dafny or Z3: 0 of 5" measures nothing. A Dafny that `swap.ts` starts as a grandchild is visible only to the sampler.
- The real evidence is the sampler alone, at about 8 samples per second (200 samples in the run I observed).
- Repair: remove the line, or state that the sampler is the only check.

**R6. LOW, PLAUSIBLE. Lines 371-374, 405.**
- The sampler ignores every process line that contains `demo_gauntlet`. A prover whose command line holds that text is not seen, for example in a checkout folder with that name.
- A Dafny of another job can satisfy the positive control (`seen_at_compile > 0`). The sampler counts the whole machine.
- An empty `ps` output counts as 0.
- Robustness note: a Dafny of the other job during the exchange makes Act 3 fail. I did not see this in my runs.
- Repair: exclude by the script's own pid and its ancestors, not by text. For the control, require a process whose command line holds this run's `booking-core` output path. Require `ps` to exit 0 with non-empty output.

**R7. LOW, PLAUSIBLE. Lines 356-361.**
`attempts_without_effect` is arithmetic on constants, and `'effects_of_attack_attempts': 0` is a literal. The final store check backs them (state 50, the two settled ids, 2 outbox rows, empty audit), and I judge that check sound. The record presents derived numbers as if measured.
- Repair: count attempts as they are made. Compute effects as outbox rows minus the two authorized rows.

**R8. LOW, PLAUSIBLE. Lines 192-198, 333.**
- The issuer's stdout is never read to its end. Extra lines after the last answer are not seen.
- `ask` and the `readline` at line 333 have no time limit. An issuer that does not answer hangs the demo.
- Repair: after `stdin.close()`, read stdout to its end and require it to be empty. Add a time limit.

**R9. LOW, CONFIRMED. Lines 104-110, 411-412.**
`operations.json` holds absolute private paths: the home folder in the Dafny path, the `rustc` path, the `--remap-path-prefix` value and the `v2_fast` path. `record.json` holds none (grep found 0). `build/` is ignored by git. The risk is only a copy of `operations.json` into a tracked record.
- Repair: store `rel()` paths, or replace ROOT and HOME before the write.

**R10. LOW, by reading. Lines 22, 470; `sink_tool.ts` line 14.**
- The docstring says the flood goes up to 10240. The code accepts up to 1048576 (1 TiB).
- `sink_tool.ts report` on a path with no database creates the file and the tables before it throws. The demo's fixed paths do not reach this.
- The 2500 ms common-start lead can fail as "late" on a loaded machine. That direction is fail-closed.

### Checked and found correct
- **Race (2b):** a sink mutant that reads the stored state before `BEGIN IMMEDIATE` gave "committed 8, rejected as stale 0" and exit 1 in 3 of 3 runs. The processes overlap, and "exactly one commit" comes from the sink's check, not from the demo's order. `onTime` is taken before the wait.
- **Flood (2d):** the pipe order forces the issuer to consume every byte and the line end before it answers the valid request. The write cannot be silently short. A second "message too long" answer is detected (R2 run), so the answer cannot belong to something else.
- **Store checks:** every check of the store runs after its attack (2a, 2b, 2c, end).
- **Forged token:** its domain, spec lock, checker id and pre-state hash equal those of a real token, and its text is canonical. Only the signature check rejects it.
- **Act 1:** the work folder is new, and the script requires the record id, the verdict and tool exit 0. All 4 verdicts were as required in my run.
- **Act 3:** the script requires the counts to equal the Slice 3 record, 0 tokens for the adversary, 0 effects of refused attempts, and unchanged core bytes. My run gave 84 commits, and the sampler saw 2 during the compile and 0 during the exchange.
- **Exit codes:** a `Failed` gives exit 1 and a crash gives exit 2. No exception path ends with exit 0.
- **Writes:** only under `build/demo-gauntlet/`.

### Not checked
- A flood above 600 MiB.
- A full `1,2,3` run in one process. I ran act 2 alone and acts 1 and 3 together.
- The internals of `spec_clearing.py`, the `swap.ts` reference check and the sandbox profile.
- The untracked `docs/demo-gauntlet.md` and `proposals/forge2-demo-gauntlet/`.
- Behavior under real memory pressure, where the macOS compressor can lower RSS.
