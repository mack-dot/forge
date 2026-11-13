# U357–U359: resource inspection, replay not run, initializer on `installed`, installer call site

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Nothing committed.
Every proof result here is local: same machine, same agent, cached parent
theories. None is independent verification. An exit code alone is not
semantic verification; each PROVED row also has a kernel tag check
(`DISK_THM` only, no hypotheses, no tagged axioms) and an exact-statement import.

Statuses: PROVED (HOL kernel accepted it in this session, local scope),
FAILED, ASSUMED, NOT_RUN.

## 1. Resource recovery: 0 GiB recovered; target not reached

Read-only inspection. Facts: [resource-inspection.json](records/resource-inspection.json).
Nothing was deleted or pruned. Free space moved from 6.6 GiB to 12.3 GiB during
the work because the system released swap files; that is not a cleanup result.
Target 20 GiB. **Deficit at the end: 7.7 GiB** (it varies with swap).

| Candidate | Size | Owner | State | Risk if removed |
| --- | --- | --- | --- | --- |
| `/private/tmp/claude-501/-Users-mackianni-spm-release-loop/f3faa3b8-…` | 14.34 GiB by `du` | Another Claude session, project `spm-release-loop` | ACTIVE: 8607 files changed in the last hour; a Postgres server runs from a data directory inside it; copies in progress | Destroys running work. `du` overstates the gain: the copies are APFS clones. |
| `/private/tmp/claude-501/-Users-mackianni-spm/2eef8509-…` | 6.24 GiB | Earlier Claude session, project `spm` | Idle since 2026-11-08 | Directories `wt-*` look like git worktrees; possible unpushed work. |
| `/private/tmp/claude-501/-Users-mackianni-spm/c624b68b-…` | 0.96 GiB | Earlier Claude session, project `spm` | Not inspected further | Unknown. |
| Docker VM `/var/lib/desktop-containerd` | 13.97 GiB | Docker Desktop, all projects | Not listed by `docker system df` | Content unknown; may hold unique images; needs a Docker Desktop cleanup. |
| Docker volumes | 6.95 GiB | Other-project databases; Forge pinned-builder cache | 21 of 48 in use | Excluded by the owner's rule. |
| Docker images, reclaimable | 0.35 GiB | Mixed | Untagged images | Uniqueness unknown; excluded. |
| Docker build cache | under 1 MB | — | — | Safe, but no gain; not pruned. |
| Swap files | 14–16 GiB | macOS | In use | Freed by the system or a restart; a restart stops the active sessions. |
| `~/Library/Caches` | 3.1 GiB | Other applications | Not inspected | Low, but not Forge. |
| `~/forge-*` sibling clones | 2.44 GiB | Forge, earlier stages | Idle | Earlier Tier 3: per-path approval. |

Docker findings: the VM file system holds 28.97 GiB and the host image
allocates 30.43 GiB, so a trim gains about nothing. Two containers of another
project started minutes before the inspection, so the Docker VM is in live use.

## 2. Clean replay: NOT_RUN

Not started. Blockers: free disk below the 20 GiB target; the Docker VM is
shared with a live session of another project; 13–14 GiB of swap in use on a
16 GiB host. No same-machine cached run is presented as a replay.

## 3. Initialization closure

### 3.1 `is_arm8_machine_config mc` — a model choice, with an explicit instance

`forge_refundInitializerInstalled.arm8_machine_model_instance`, PROVED, local:

```
⊢ is_arm8_machine_config
    (mc with <|target := arm8_target; len_reg := 1; ptr_reg := 0; len2_reg := 3;
               ptr2_reg := 2; callee_saved_regs := [19; 20; 21; 22; 23; 24; 25; 26; 27; 28]|>)
```

Any machine record with these six fields satisfies the predicate. The other
fields (entry addresses, program addresses, interference oracles) stay free.
This discharges the premise by instantiation of the abstract machine record.
It shows the predicate is satisfiable. It is not a property of the physical
machine: that the processor and runtime behave as this record is part of the
`installed` premise and of the physical assumptions.

### 3.2 `memory_assumption` — exact statement and discharge from `installed`

Exact statement (`stack_to_labProofScript.sml:3209`): there are words `ptr2`,
`ptr3`, `ptr4`, `bitmap_ptr` such that registers `find_name names 2`, `3`, `4`
hold `ptr2`, `ptr3`, `ptr4`; the five words at `ptr2` hold the bitmap start,
bitmap end, data end, code-buffer position and code-buffer end; the code
buffer is empty; `ptr2 ≤ ptr4`; `ptr2`, `ptr4`, `bitmap_ptr` are byte-aligned;
at least 1024 words lie between `ptr2` and `ptr4`; and memory over the domain
splits into the bitmap words, `data_sp` further words, and the heap/stack
words from `ptr2` to `ptr4`.

Native memory-layout obligations behind it, which only the physical process
can satisfy: the two heap registers and their alignment; the five header
words; the bitmap bytes; disjointness of bitmap and heap regions; mapped,
writable heap/stack of at least 1024 words; the code-buffer bounds. Earlier
finite observations (runtime matrix M4–M8) are consistent with these for the
captured runs. They do not prove the quantified statement.

`forge_refundInitializerInstalled.refund_initialization_installed`, PROVED, local:

```
is_arm8_machine_config mc ∧
installed bytes cbspace (FST (to_stack arm8_config cfg refund_prog)) data_sp ffi_names
          (heap_regs arm8_backend_config.stack_conf.reg_names) mc shmem ms
⇒ ∃tar m dm sdm.
    good_init_state mc ms bytes cbspace tar m dm sdm ∧
    <conclusion of refund_initialization_aligned for these witnesses,
     with cbpos := mc.target.get_pc ms + n2w (LENGTH bytes)>
```

`installed` is the published installed-state predicate
(`targetSemScript.sml:487`), the single premise the published compiler theorem
uses for the machine state. So `memory_assumption` is no longer a separate
premise: it follows from `installed`. The helper lemma `heap_region_extends`
is generic in the word size and uses the tactic of the published proof of
`compile_correct'` (`backendProofScript.sml`, lines 4568–4617).

What remains open: `installed` itself for the physical process. Existing
compiler evidence gives the exact bitmaps and code. Existing loader and
runtime evidence is finite observation. Neither proves `installed`, which
quantifies over all interference and all steps. It stays ASSUMED under either
profile.

Run directory: `results/refund-initializer-installed-local-20261112/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_stack_case.py explore-0001 ...` | 1 | SCRIPT ERROR: a helper file was loaded with plain `use`, which skips HOL quotation processing. Not counted. |
| `run_stack_case.py explore-0002 ...` | 1 | Machine-model instance proved in the goal manager; main goal reached `memory_assumption`; then SCRIPT ERROR on an undeclared name. Not counted. |
| `run_stack_case.py explore-0003 ...` | 0 | Generic heap lemma proved in the goal manager; main goal reduced to exactly the heap conjunct. Nothing stored. |
| `run_stack_case.py installed-0001 installed-0001.sml ...` | 0 | Three theorems checked; `REMAINING_ANTECEDENTS 2`; four exports. |
| `run_stack_case.py audit audit.sml ...` | 0 | Three exact statements; premises are the predicate and `installed`; no `memory_assumption` premise; 487 closure nodes; four Boolean axioms. |
| `run_stack_case.py repeat installed-0001.sml ...` | 0 | Exports byte-identical. |
| `run_stack_case.py missing-installed ...` | 1 | `Exact statement mismatch: missing installed premise`. |
| `run_stack_case.py other-bitmaps ...` | 1 | `Exact statement mismatch: installed state for other bitmaps`. |

Source SHA256 `902dd23679f33fd11651aa02c88394b79a1999c68efaa0b0640cfdd97f552832`;
theory data `767dfbf8eca8f5ccf1f95ae522f32b9be9f7a836400174f275d175db8b0a1255`.
Limits per child: CPU 600 s, wall 900 s; no timeout; max RSS about 3.0 GiB.

## 4. U298 exclusion: NOT established; reduced to one call site

Frozen obligation, unchanged: every formal `TimeOut` prefix of the target
evaluator has a program counter different from `mc.install_pc`.

Observation on the exact native code ([entry-branches.json](records/install-site/entry-branches.json);
hand-written field extraction, not a proof): the 130436 code bytes hold
exactly one direct branch whose target is the installer entry (code start
− 32): word `17fffb6b` at code offset 4660. There are 325 direct branches to
the halt entry and one to each of four FFI entries.

`forge_refundInstallSite.install_call_site_step`, PROVED, local: with the four
bytes `6b fb ff 17` at the program counter and the usual state premises, one
step of the published ARMv8 model sets `PC := PC − 4692` and changes no memory,
register or stack pointer. At code offset 4660 that target is code start − 32.
So the exact executable contains an instruction that jumps to the installer
entry. This agrees with the stub lemmas of U355.

Consequence: no syntactic exclusion exists for this executable. The exclusion
is a reachability claim: the instruction at code offset 4660 is never
executed, and no indirect branch targets the installer entry.

Attempt at the complete theorem: not completed. The published
lab-to-target theorems give behavior inclusion and do not export the
program-counter invariant this needs. No statement was weakened. Smallest
unresolved subgoal: for the exact program and every clock, the target program
counter is never the address of code offset 4660 and never `mc.install_pc`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B scan_entry_branches.py` | 0 | Observation recorded; native and code hashes match. |
| `run_arm8_case.py install-site-0001 install-site-0001.sml` | 0 | `CHECKED install_call_site_step`; four exports. |
| `run_arm8_case.py import ...` | 0 | Exact statement; `DISK_THM` only; 97 closure nodes; four Boolean axioms. |
| `run_arm8_case.py wrong-target ...` | 1 | `Exact statement mismatch: wrong branch target`. |
| `run_arm8_case.py repeat ...` | 0 | Exports byte-identical. |

Theory data SHA256 `0b23f5f8740d46dcd49e9b69dea1e2ad224d9a5ff6b6bb4116e2744a94c7a9af`.

## 5. Assurance profiles: separate, neither approved

Unchanged from [U356](../m1-replay-closure-20261112/REPORT.md).

- Profile A, standard CakeML oracle: read errors on open descriptors are
  excluded by an explicit environment assumption. The `installed` premise of
  section 3.2 is part of this profile's assumptions.
- Profile B, extended oracle: native read-error behavior needs the further
  model, contract and proof obligations listed in U356.

Effect of this packet on both: the initializer no longer has separate memory,
register or alignment premises; it depends on `installed` and the machine
model. The installer question (section 4) is the same in both profiles: either
prove the reachability claim or keep an explicit installer assumption.

## Evidence integrity

`python3 -I -B verify_cases_r3.py` exits 0. On a copy with one byte appended
to an exported theory it exits 1; on a copy with an acceptance marker added to
a control stream it exits 1. It binds bytes, exits and markers; it binds the
scanned word to the proof source and the scan to the native executable hash.
It does not show that a theorem is true or who made a file.

## Premise chain of the initializer after this packet

```
refund_initialization_code        14 conditions   (U347)
  → refund_initialization_machine  6             (U349)  nine config conditions
  → refund_initialization_aligned  2             (U354)  FFI registers, alignment
  → refund_initialization_installed              (this packet)
        premises: is_arm8_machine_config mc   [model choice; instance proved]
                  installed ... mc ... ms     [published predicate; ASSUMED for the physical process]
```

## Remaining obligations

1. Clean and independent replay of every theorem (blocked by resources).
2. `installed` for the physical process: stays an assumption unless a
   loader and runtime correspondence is proved.
3. U298: unreachability of the installer call site, or an explicit installer
   assumption.
4. Owner choice between Profile A and Profile B; approved assumption list.
5. ARM8: prologue, call frame and success path of `ffiread`.
6. Resource condition; malformed-input behavior; admission (M2).
