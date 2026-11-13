# U360–U363: installer exclusion route, profile comparison, installed state, clean replay, tree audit

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Nothing committed.
No profile is approved. No authorization state changed. No file was deleted
except two containers that this session created.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms; exact-statement import), FAILED, ASSUMED, OPEN,
NOT_RUN. An exit code alone is not semantic verification.

## 1. Newly discharged obligations (U360)

Theory `forge_refundInstallHandler`, PROVED, local scope. No new constant, no
axiom, no `cheat`. Parents: published CakeML theories and the U298 bridge.

| Theorem | Statement |
| --- | --- |
| `arm8_install_handler_ok` | `is_arm8_machine_config mc ⇒ install_interfer_ok pc cbspace (mc with install_interfer := H)`, where `H` returns to register 30, writes the byte array at the address in register 2 and puts that address in register 0 |
| `arm8_install_handler_exists` | `is_arm8_machine_config mc ⇒ ∃h. install_interfer_ok pc cbspace (mc with install_interfer := h)` |
| `installed_modulo_install_handler` | `is_arm8_machine_config mc ∧ W ⇒ installed … (mc with install_interfer := H) …`. `W` is the published `installed` with `good_init_state` unfolded and its one `install_interfer_ok` clause replaced by `T` |
| `install_exclusion_suffices` | `is_arm8_machine_config mc ∧ W ∧ E ⇒ ∃mc2. is_arm8_machine_config mc2 ∧ installed … mc2 … ∧ machine_sem mc2 ffi ms = machine_sem mc ffi ms` |

`E` is the frozen U298 exclusion, unchanged:
`∀j ms' ffi'. evaluate mc ffi j ms = (TimeOut,ms',ffi') ⇒ mc.target.get_pc ms' ≠ mc.install_pc`.

Meaning: if installer exclusion holds for a machine record, the record does
not need a correct install handler. The published compiler theorem then
applies to `mc2`, and `mc` has the same behaviors. This does not prove `E`.
It moves the installer question from "the native installer is correct" to
"the installer entry is never reached".

Run directory: `results/refund-install-handler-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_case.py explore-0001 …` | 1 | SCRIPT ERROR: undeclared goal-printing names. Not counted. |
| `run_case.py explore-0002 …` | 0 | Handler goal reduced to register and memory goals. Nothing stored. |
| `run_case.py explore-0003 …` / `explore-0004 …` | 1 / 1 | SCRIPT ERROR: theory path; then a type error in the statement construction. Not counted. |
| `run_case.py explore-0005 …` | 0 | Handler lemma proved in the goal manager. |
| `run_case.py explore-0006 …` / `explore-0007 …` | 1 / 1 | SCRIPT ERROR: no current theory; then a read of an unfinished goal. Not counted. |
| `run_case.py explore-0008 …` / `explore-0009 …` / `explore-0010 …` | 0 / 0 / 0 | Weak-installed lemma proved; final step diagnosed; all three goals proved in the goal manager. |
| `run_case.py proof-0001 proof-0001.sml …` | 0 | Four theorems checked; `REMOVED_CLAUSES 1`; four exports. |
| `run_case.py import import.sml …` | 0 | Four statements rebuilt from the published definitions, `aconv`; `DISK_THM` only; 343 closure nodes; four Boolean axioms. |
| `run_case.py repeat proof-0001.sml …` | 0 | Exports byte-identical. |
| `run_case.py missing-exclusion …` | 1 | `Exact statement mismatch: missing installer exclusion`. |
| `run_case.py wrong-return-register …` | −24 | RESOURCE STOP: CPU limit 600 s in proof search after the harness check. Not counted as a rejection. |
| `run_case.py wrong-return-register-v2 …` | 1 | Bounded tactic proves the original, then fails for a handler that returns to register 29. |
| `run_case.py search-install-pc …` | 0 | Observation, section 2. |

Proof source SHA256 `7162863d4bcfaab5343d6646d0cc6cdea96df1162226ee7b8ea2917e497ffb7d`; theory data
`a1438f1b0db21378a95678a9b535200cb8eb5bb1d0f6b6803c9c1e86257123da`.
No failing `store_thm` attempt occurred.

## 2. Installer exclusion: NOT established

Frozen obligation `E` for the exact refund program: unchanged, not proved, not
weakened.

Exact failure point. The published lab-to-target theorems conclude a behavior
relation (`semantics_compile`, `lab_to_targetProofScript.sml:11295`) or an end
state for some clock (`compile_correct`, line 7677). `search-install-pc`
searched 32526 stored theorems and definitions in 330 theories (the ancestry
of `backendProof`). 20 mention `install_pc`. Four have a program-counter
inequality in their conclusion: three definitions (`start_pc_ok_def`,
`state_rel_def`, `share_mem_state_rel_def`) and
`ffi_entry_pcs_NOT_install_OR_halt_pc`, which is about FFI entry addresses.
No stored theorem concludes that a target evaluator prefix has a program
counter different from `install_pc`. Local theorems of the published scripts
are not stored and were read in source only.

Why no shortcut exists:

- Syntax: the executable holds the installer call (U359) and the stub list is
  not install-free (U355). The published proof uses the no-shared-memory
  disjunct of `no_install_or_no_share_mem`, not `no_install` (U297).
- Behavior: with a correct handler, a run that reaches the installer is a
  legal run. A behavior theorem cannot rule it out.

What a proof needs: an instrumented simulation with two parts. (a) Lab level:
for the exact program, evaluation never executes the `Install` line. (b)
Target level: a prefix state has `PC = install_pc` only when the lab step is
that line. Neither is published.

Minimal explicit assumption, if the proof is not done: `E` itself, as a named
premise of the final theorem. It is the exact premise of the U298 bridge and
of `install_exclusion_suffices`.

Consequences of assuming `E`:

1. The clause `install_interfer_ok` leaves the installed-state assumption
   (PROVED, section 1).
2. The final theorem is conditional on a property of the model's own
   execution. It is not an environment assumption. It can be proved later
   without a change to the statement.
3. For an input on which `E` is false, the theorem claims nothing.

Consequence of the alternative (keep `install_interfer_ok` inside
`installed`): the native routine `cml_install` is compiled without `EVAL`, and
the code buffer is mapped read/execute (U296, matrix rows F4, M8). So that
clause is likely false for a faithful model of the physical machine. The
final theorem would then have a premise that the real machine does not meet.
This is an inference from source and a memory map. No faulting run exists.

## 3. Profile A and Profile B

[PROFILES.md](PROFILES.md): 13 assumptions, trusted boundaries, consequences,
recommendation. Recommendation: Profile A for M1 with the read-error exclusion
named in the claim; `E` as the installer assumption in either profile.
Neither is approved.

## 4. Physical installed state

[INSTALLED-STATE.md](INSTALLED-STATE.md): proven facts, clause-by-clause
status, six missing obligations, unverified claims. `installed` for the
physical process stays NOT_ESTABLISHED.

## 5. Clean replay

Prerequisites, measured at the start (2026-11-13T17:34Z):

| Prerequisite | Requirement | Measured | Holds |
| --- | --- | --- | --- |
| Host free disk | at least 20 GiB (U352) | 39.1 GiB | yes |
| Swap | not near the U350 state (15 GiB in use) | 3.8 GiB in use of 5 GiB | yes |
| Docker VM storage | room for the build | 398.7 GiB free in the VM file system; host image 32 GiB | yes |
| Docker VM in live use by another project | none (U357) | 0 running containers; 23 stopped containers of another project, not touched | yes |
| HOL processes on the host | none | none | yes |

Scope that ran: the two theorems with no CakeML parent, `ffiread_error_return`
(U348) and `install_call_site_step` (U359), each with its fresh import and
one control. This is the first step of the U350 plan.

Method: a fresh `debian:bookworm-slim` container
(`sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc`,
linux/arm64). Inside it: PolyML `45575540…` and HOL `9783a499…` fetched from
GitHub by commit, commit and tree IDs checked, PolyML built with the recorded
configure options, HOL built with `bin/build`, the ARM8 step heap built with
`Holmake`. No host toolchain, heap or cached theory was mounted. Only the six
proof sources (hashes equal to the host records) and the script were mounted,
read-only. One path differs from the host: the preload file names the
container path of `arm8_stepLib`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `docker run … sh /inputs/replay.sh` (attempt-0001) | 30 | Both proofs exit 0. The two imports and two controls exit 1: SCRIPT ERROR, the script passed the stored path of the theory files. Not counted as rejections. |
| `docker run … sh /inputs/replay.sh` (attempt-0002, one path line corrected) | 0 | All twelve build steps 0; cases below. |
| attempt-0002 `compose-0001` | 0 | `ffiread_error_return` checked; `NATIVE_STEP_COMPLETE`. |
| attempt-0002 `compose-import` | 0 | Exact statement; `DISK_THM` only; 97 closure nodes. |
| attempt-0002 `wrong-status` | 1 | `Exact statement mismatch: wrong status byte`. |
| attempt-0002 `install-site-0001` | 0 | `install_call_site_step` checked. |
| attempt-0002 `install-import` | 0 | Exact statement; `DISK_THM` only; 97 closure nodes. |
| attempt-0002 `wrong-target` | 1 | `Exact statement mismatch: wrong branch target`. |
| `python3 -I -B verify_cases_r4.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding only. |

Build times in attempt-0002: PolyML 198 s, HOL 811 s, ARM8 step 34 s.
The exported theory files (`.dat`, `.sig`, `.sml`) of both theorems are
byte-identical to the macOS host exports of 2026-11-12, in both attempts. The
heaps differ between the two attempts and from the host; they are not
compared.

Limits. Same physical host, same agent, same Docker VM: this is a clean
replay, not an independent replay. Debian packages are not pinned (versions
are in `packages.txt`). Source identity rests on Git SHA-1 and GitHub.

NOT_RUN: clean replay of every CakeML-dependent theorem (`read_error_generic`,
the oracle and instance lemmas, the initializer chain, the bridge, and
today's `forge_refundInstallHandler`). They need the CakeML compiler proofs
built from source. That build was not attempted: no measured time or memory
bound exists for it on this host, and the Docker VM has 7.65 GiB of memory.
Host swap in use rose to 7.8 GiB of 8 GiB at the end of attempt-0002; free
disk was 32 GiB at the end.

Run directories: `results/m1-clean-replay-20261113/attempt-0001` and
`attempt-0002`.

## 6. Working-tree audit (read-only)

| Item | Count | Finding |
| --- | --- | --- |
| Modified tracked documents: `ROADMAP.md`, `unsure.md`, `FORGE_MISSION_STATUS.md` | 3 | Before this session: 901 added lines, 0 removed lines. Append-only rule holds |
| Modified tracked ELF files under `results/stage7` and `results/stage9` | 10 | Mode change 100644 → 100755 only. Content equals `HEAD` (same blob; 1240 bytes each). Cause not determined |
| Untracked proposal packets `*-20261112` | 9 | 642 manifest members; 0 hash mismatches; 0 unlisted files |
| Untracked entries under `results/` | 350 before this session | By design: commit `77a31eba` is a snapshot "excluding results/". 36 GiB. Not hashed here |
| New in this session | 2 result directories, 1 packet | Listed in `MANIFEST.json` |

Nothing was discarded, reverted, staged or committed. The mode change was not
reverted: it is a change to preserved evidence and needs an owner decision.

## 7. Remaining obligations

1. `E` for the exact program, or the owner's acceptance of `E` as a named
   assumption.
2. Owner choice between Profile A and Profile B; approved assumption list.
3. `installed` for the physical process: the six obligations of
   INSTALLED-STATE.md.
4. Clean replay of the CakeML-dependent theorems; independent replay by
   another operator and host.
5. ARM8: prologue, call frame and success path of `ffiread`.
6. Resource condition; malformed-input behavior; admission (M2).

Next minimal proof obligation: lemma N1 on the route to `E`. By evaluation in
HOL, the location `Install_location` is not in the call-reachable set of the
exact word program from its start location. This is a finite check on the
compiled program. It is NOT_RUN and its truth is not known. If it holds, the
remaining step is the two-part instrumented simulation of section 2.
