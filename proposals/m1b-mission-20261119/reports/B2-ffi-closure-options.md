# Step B2: closing the execution argument: FFI refinement against a minimal runtime (X2, Opus, read-only; no HOL run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

X2 (ffi-refinement), step B2. I worked read-only. I changed no repository file and did no HOL run. I copied the executable (SHA `b8ed5ec2…7bb8`, 238,776 bytes) and inspected the copy only with `nm -n`, `otool -tV` and `otool -l`, all exit 0. I never ran it. One accidental `find /` ran in the background. It was read-only, and I stopped it.
Draft: <session scratch folder>/m1b/X2/FFI_CLOSURE_OPTIONS.md (sections 1–9). Supporting listings: nm.txt and tv.txt in the same folder.

## Inventory (short)
- **Entry:** LC_MAIN entryoff 152900 = `_main` 0x100025544, 47 words. `_main` calls `cml_memory_size` twice (44 words). With the env variables unset, each call returns 1 GiB. It then calls `malloc(2 GiB)`, stores heap/stack/stackend, and does `bl cml_main`. `cml_main` runs 27 words.
- **FFI stubs** (1 word each): read, write and exit are reachable. close and open_in are not reachable by inspection (U396). install is excluded in the model.
- **C FFI functions:**
  - `_ffiread`: 28 words, plus 2 cold paths of 10 words.
  - `_ffiwrite`: 32 words, plus 2 cold paths of 10 words.
  - `_cml_exit`: 16 words. Success at halt_pc with x0 = 0 gives `exit(0)`. Resource_limit_hit gives a nonzero exit plus a stderr line (targetSemScript.sml 138–140; arm8_configProofScript.sml 15).
- **Import stubs:** 22 × 3 words. Used on the path: getenv, malloc, read, write, exit.
- **Total:** about 200 distinct hand-written words run natively inside the file. dyld, libSystem and the kernel are outside the file and not pinned.
- **Reachable arguments:**
  - write: fd 1. U400 gives x1 = 8 and n+off+4 ≤ alen, but only for successful write events.
  - read: no call-site theorem exists.
- **New facts (by reading, not proved):**
  - The compiled code takes the fd only from c[4..7], while the model uses all 8 bytes.
  - On invalid arguments the oracle returns an error byte (fsFFIScript.sml 307–362), but the C code aborts. So even ag32's oracle-conditional contract form fails for the present C code.
  - In pinned L3, `svc` raises UNDEFINED_FAULT (arm8Script.sml 2425–2434) and NextStateARM8 then returns NONE. So every route must end at a named kernel assumption.
  - EAGAIN on a non-blocking stdin is not covered by Q2.

## Comparison
New work is in units of 65 M1 entries. All estimates are mine, with low confidence except A.

| | Closed down to | Residual TCB | New work | Main risk |
|---|---|---|---|---|
| A | model machine plus one stated relation | everything below the model | 0.1–0.4 (high confidence) | the relation is a restatement of the conclusion or false |
| B1 | the `bl` into libSystem | libSystem (5 functions, unpinned), XNU, dyld, L3 | 0.55–1.1 | unverifiable libSystem axioms; malloc shares the heap |
| B2a | `svc` on XNU, plus dyld | unstable syscall ABI, dyld | 0.6–1.3 | Apple ABI changes; holds for one OS build |
| B2b | Silver ISA (ag32 only exists for Silver) | Silver hardware | 1.5–3 | not the machine you deploy |
| B2c | `svc` on Linux, ELF loader | three syscall relations, execve, L3 | 0.7–1.5 | needs a Linux host and owner approval |

- The pinned tree has no bare-metal or verified arm8 runtime. It has only ag32: `ag32_interference_implemented` (ag32_basis_ffiProofScript.sml 7095) and `machine_sem_Terminate_FUNPOW_next` (348). These are usable as a proof template.
- B2c makes slide 0 true for a static non-PIE file. That removes the S1–S6 slide argument for that artifact.
- About 25 of U345–U409 name exact bytes and must be redone for any new runtime.

## Recommendation (ordered)
1. **L1:** prove `refund_ffi_contract_at_totalise`. HOL time: minutes.
2. **L2:** prove that the real-effect machine and the totalised machine agree when every reachable call satisfies V. HOL time: hours.
3. **L3:** prove V for write (including failed write events), V for read, and that no close or open_in event happens. HOL time: hours. After steps 1–3, Route A is honest, and Q3b covers it.
4. **Owner decision:** B1 or B2c. A new runtime means a NEW executable, a NEW artifact hash, and about 25 byte-level proofs redone.
5. **B2c runtime:** about 70 words that fail closed through `exit_group` on invalid arguments, with step theorems up to each `svc`. HOL time: hours.
6. **Native simulation:** an ag32-shaped FUNPOW lift plus a numchars witness lemma. HOL time: hours to days.
7. **Final theorem:** the top theorem with transitive identity checks, then an independent replay. Needs owner approval.

My conclusion: the present C runtime is the wrong foundation for a closed argument, because its boundary is libSystem.

**Next independently checkable obligation:** `refund_ffi_contract_at_totalise`. Informally: if f meets the per-call contract wherever V holds, then "f on V, else the refund_abs_env effect" satisfies `refund_ffi_contract_at`. It needs only stored theories and is runtime-independent. Its statement is in section 6 of the draft, and it is not type-checked.

## Smallest counterexample (U393/U394, exact)
- Index 2 (close), entry 0x100004080, readable arrays, x3 = 0 (alen = 0), aligned x30.
- The real code reaches 0x1000252A4 in 6 steps (`zero_alen_reaches_assert_block`, assert-0001, exit 0). From there it calls `_fficlose.cold.2`, then `___assert_rtn`, and never returns to x30, which the contract requires.
- With clen ≠ 8 and positive alen, it reaches 0x1000252A8 in 8 steps.
- write has the same problem: `ffi_write_accepts_wrong_clen` (U397) shows the oracle returns where the C code aborts.

## Could not determine
- The number of read calls per run and the buffer size (I infer 2 or more).
- Whether macOS arm64 accepts a non-dyld static executable (general knowledge says no; not checked).
- Whether the stored CakeML `code` term stays the same under a new C runtime (expected; not checked).
- What libSystem read/write touch in memory.
- Whether stdin can be non-blocking in deployment.
- ag32 FFI code size in words (I counted proof lines only).
- The exit status on an uncaught `Fail` (V observed exit 0 with empty output).

## Links for the top-level graph (present runtime)

| from | to | statement | class | evidence | what would upgrade it |
|---|---|---|---|---|---|
| dyld hand-off | `_main` | none | ASSUMPTION | Q3a; entryoff checked only in ML (V M1) | in-HOL load-command check |
| `_main` + getenv + malloc | `refund_entry_pre_sl` | none (P1–P6) | ASSUMPTION | Q3a; e4-0001 stdout 240–265 | entry step theorems plus library relations |
| cml_main | 0x1000040D0 | `cml_main_run_sl` | MACHINE-CHECKED | HOL4 s1-0001 (U405) | replay |
| entry state | installed state (28 of 30 clauses) | `refund_installed_from_entry_reduced_sl` | MACHINE-CHECKED | HOL4 a3-0006 (U407) | replay |
| source | model output equation | `refund_profile_a_sl` | MACHINE-CHECKED | HOL4 e4-0001 (U409) | replay; H2 identity checks |
| FFI env | `refund_env_ok_sl` (all states) | `refund_env_ok_sl_def` | ASSUMPTION | Q3b; probably false (U393, U409) | reachable-call form |
| write call | `br x16` | `cake_ffiwrite_to_import_branch` | MACHINE-CHECKED | HOL4 U397 | 12-conjunct residual |
| write GOT slot | libSystem write | none | ASSUMPTION | Q3b | bind-table check |
| libSystem write + XNU | `write_call_rel` | premise | ASSUMPTION | Q3b; U397 | syscall relation (B2) |
| write return | caller | `cake_ffiwrite_path_returns` | MACHINE-CHECKED | HOL4 wsucc-0002 (U398) | replay |
| reachable write calls | clen = 8, bound | `refund_terminating_run_reaches_valid_write_call` | MACHINE-CHECKED | HOL4 args-0006 (U400), successful events only | failed-event invariant |
| read call | real `_ffiread` + `read_call_rel` | none (only `ffiread_error_return`, U348) | MISSING | U348 limits | B1.1–B1.3 |
| program | no close / open_in event | none | MISSING | inspection only (U396) | B1.5 |
| path theorems | reachable-call env predicate | none | MISSING | U405 "NOT RUN" | steps 1–3 |
| model machine_sem | real process | none | MISSING | V C1 (A3 not formalized) | simulation (step 6) |
| halt x0 = 0 | `exit(0)` | none | MISSING | targetSemScript 138–140 (model only) | exit step theorem |
| real stdout/exit | model output | none | TESTED-UNPROVED | 2,466 vectors, attempt-0006 | simulation |

For the B2c replacement, every link is MISSING except two, which are ASSUMPTION (not approved): the execve/ELF-loader entry state, and the three `svc` relations. Section 9.2 of the draft has that table.

**FIRST MISSING link:** in execution order, the read FFI call (prologue, `read_call_rel`, success suffix and reachable-call facts), because the program reads stdin before it writes. In proof order, the first missing link is L1 (`refund_ffi_contract_at_totalise`).

| step | status | evidence or blocker |
|---|---|---|
| B2 (X2 ffi-refinement) | REPORTED | FFI_CLOSURE_OPTIONS.md in the scratch folder above; sources basis_ffi.c 71–885, fsFFIScript.sml 187–362, targetSemScript.sml 138–366, export_arm8Script.sml 22–116, ag32_basis_ffiProofScript.sml 143–366 and 7095–7520, arm8Script.sml 2425, arm8_stepScript.sml 19; U348, U393–U401, U405, U409; otool/nm on a copy, exit 0; no HOL run |
