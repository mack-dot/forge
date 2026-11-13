# U352–U356: resource recovery, replay stop, basis instance, initializer 6→2, U298 lemmas, assurance profiles

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Nothing committed.
Every proof result here is local: same machine, same agent, cached parent
theories. None is independent verification. An exit code alone is not
semantic verification; each PROVED row also has a kernel tag check
(`DISK_THM` only, no hypotheses, no tagged axioms) and an exact-statement import.

Statuses: PROVED (HOL kernel accepted it in this session, local scope),
FAILED, ASSUMED, NOT_RUN.

## Phase 1 — Resource recovery: target not reached

Read-only inspection. Facts are in [disk-inspection.json](records/disk-inspection.json).

| Item | Size or state | Class |
| --- | --- | --- |
| Data volume | 460 GiB; 3.2 GiB free at the start of this phase; 6.7 GiB free at the end | — |
| Swap | 14–18 files of 1 GiB; 12.9–14.2 GiB in use | Released by the system or by a restart |
| Running HOL or PolyML processes | 0 | — |
| `results/` | 35.5 GiB | Evidence; preserved |
| `.toolchain/` | 8.9 GiB | Pinned tools and cached theories; preserved |
| Claude scratch of two other projects under `/private/tmp/claude-501` | 13.15 + 7.20 GiB | Not Forge; unknown to this session; not touched |
| Forge session scratch | under 0.01 GiB | Mine; holds only copies of recorded files |
| Docker disk image | 30.2 GiB on disk for about 8.6 GB of images and volumes | Other projects share it; not touched |
| `~/Library/Caches` | 3.1 GiB | Not Forge; not touched |
| Sibling clones `~/forge-*` | 2.4 GiB | Earlier Tier 3: per-path owner approval |

Deletions that are already authorized: none found. The owner's earlier
approvals (U188 era) were for named items and are consumed. The
`DELETION-PROPOSAL.md` of 2026-11-01 is a proposal; its Tier 1 paths no longer
exist. So nothing was deleted and cleanup recovered 0 GiB. The rise from 3.2
to 6.7 GiB came from the system releasing swap files after the serial runs.

Available: 6.7 GiB. Target: 20 GiB. **Deficit: 13.3 GiB.**

Candidates for the owner, largest first: the two other-project Claude scratch
directories (20.35 GiB, if those sessions are finished); a restart (swap);
Docker Desktop space reclaim; `~/Library/Caches`.

## Phase 2 — Clean replay: NOT_RUN (stopped by the Phase 1 rule)

The target was not reached, so the replay phase stopped. No container was
started. No same-machine cached run is presented as replay. The prerequisite
from U350 stands: pinned HOL, CakeML and PolyML sources equal upstream trees.

## Phase 3 — `read_error_basis_instance`: PROVED, local

Cause of the earlier `No match` (U351), shown by run `explore-0002`:
the goal term of U351 was built from two separately parsed quotations. Its
premise held a variable `rest : α list`; its conclusion held `rest : word8 list`.
The premise `MAX n 2048 ≤ LENGTH rest` therefore did not match the conjunct of
the instantiated theorem, stayed as a goal, and `match_mp_tac` of the oracle
lemma failed on it. That goal term was not the intended statement. This was a
goal-construction error of the agent, not a counterexample and not a tactic
defect. The intended statement, parsed as one quotation, is proved by the
unchanged tactic.

```
FD fd fdv ∧ NUM n nv ∧ n < 256² ∧ MAX n 2048 ≤ LENGTH rest ∧
MEM «read» ns ∧ ¬MEM «» ns ∧ read fd fs n = NONE ⇒
app p TextIO_read_v [fdv; nv]
  (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
   one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns events))
  (POSTe e. &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
     one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns
            (events ++ [IO_event (ExtCall «read») (n2w8 fd)
               (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))
```

All assumptions of `read_error_generic` are kept, except the oracle equation,
which the lemma `basis_read_error_oracle` now discharges from
`read fd fs n = NONE`. Run directory:
`results/refund-ffi-instance-local-20261112/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py explore-0001 ...` | 1 | SCRIPT ERROR: oracle theory file not passed. Not counted. |
| `run_case.py explore-0002 ...` | 0 | Typed variables show the two `rest`; old goal fails at `match-oracle`; one-quotation goal proved in the goal manager. |
| `run_case.py instance-0001 instance-0001.sml ...` | 0 | `CHECKED read_error_basis_instance`; four exports. |
| `run_case.py repeat instance-0001.sml ...` | 0 | Exports byte-identical. |
| `run_case.py import import.sml ...` | 0 | Both theorems match explicit statements by `aconv`; `DISK_THM` only; 219 closure nodes; four Boolean axioms. |
| `run_case.py wrong-exception ...` | 1 | `Exact statement mismatch: wrong exception`. |
| `run_case.py instance-missing-read-none ...` | 1 | Harness proves the original; claim without `read fd fs n = NONE` ends `unsolved goals`. |
| `run_case.py oracle-missing-read-none ...` | 1 | Same check for `basis_read_error_oracle`. |
| `run_case.py oracle-repeat oracle-0001.sml ...` | 0 | Exports byte-identical to `oracle-0001` of U351. |

Instance source SHA256 `dd1147684d582c9990440277c752763dfa4819372d45917f9352d9cd827421d8`;
theory data `f2afe94b6d9a0cc152e6077876e0383016bbabcb103fea8497e5e29a00b37885`.
These runs used `--maxheap 1400`, a resource limit only.

## Phase 4 — Local obligations

### Initializer controls for U349

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_stack_case.py no-machine-config ...` | 1 | Harness proves the original; claim without the predicate ends `unsolved goals`. |
| `run_stack_case.py missing-memory ...` | −24 | RESOURCE STOP: CPU limit 600 s after the harness check. Not counted as a rejection. No acceptance marker. |
| `run_stack_case.py missing-memory-statement ...` | 1 | Statement-level form: `Exact statement mismatch: missing memory_assumption`. |

### Next initializer premises: 6 → 2, PROVED, local

`forge_refundInitializerAligned.refund_initialization_aligned`:

```
is_arm8_machine_config mc ∧
memory_assumption ... (memory domains dm ∩ byte_aligned, sdm ∩ byte_aligned)
⇒ <conclusion of refund_initialization_machine with the same two domains>
```

| Premise of U349 | Status now | How |
| --- | --- | --- |
| `is_arm8_machine_config mc` | kept | Fixes the abstract machine record |
| `memory_assumption` | kept, open | Needs the installed-memory relation |
| `target_io_regs ... = NONE` on saved registers | discharged | Published `target_io_regs_callee_saved` |
| `target_cc_regs ... = NONE` on saved registers | discharged | Published `target_cc_regs_callee_saved` |
| `dm` addresses are multiples of 8 | discharged | `dm := dm ∩ byte_aligned`; published `byte_aligned_MOD` |
| `sdm` addresses are multiples of 8 | discharged | `sdm := sdm ∩ byte_aligned`; same lemma |

The instantiation of `dm` and `sdm` is the one the published `compile_correct'`
proof uses. The result is an instance of U349's theorem for byte-aligned
domains, not a replacement. U349's six-premise theorem is unchanged.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_stack_case.py aligned-0001 aligned-0001.sml ...` | 0 | `REMAINING_ANTECEDENTS 2`; four `DISCHARGED_CONDITION` lines; four exports. |
| `run_stack_case.py audit audit.sml ...` | 0 | Statement rebuilt from the imported base, `aconv`; 2 premises; 486 closure nodes; four Boolean axioms. |
| `run_stack_case.py repeat aligned-0001.sml ...` | 0 | Exports byte-identical. |
| `run_stack_case.py unaligned-domain ...` | 1 | `Exact statement mismatch: unaligned memory domains`. |
| `run_stack_case.py missing-memory-statement ...` | 1 | `Exact statement mismatch: missing memory_assumption`. |

Source SHA256 `01e895f0fa7a28a91227162c41f46b26d8cde57a67f0dec89e90addf56ba365f`;
theory data `a4d3164e43af4e782a3dc0e071f7792ce8e4880f1cf2dd90cff49bf9d3639619`.

### U298 — first executable obligation: PROVED lemmas; exclusion still NOT_RUN

`forge_refundInstallStub`:

- `install_stub_has_install`: `⊢ ¬no_install (Install_code c)`
- `stubs_contain_install`: `⊢ MEM (Install_location,3,Install_code c) (stubs c)`

So the published stub list, which `data_to_word$compile` prepends to every
program, holds a function that is not install-free. The premise of the
published syntactic chain (`no_install_code`) cannot be taken from syntax of
the pre-`word_to_word` program. Not shown: that the exact post-pass refund
word program still holds the stub (not evaluated), and the exclusion itself.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py stub-0001 stub-0001.sml` | −24 | Two lemmas proved in-process; an optional third (`¬no_install_code (fromAList (stubs_md c))`) ran to the 120 s CPU limit. Nothing exported. Not counted. |
| `run_case.py stub-0002 stub-0002.sml` | 0 | Both lemmas checked; four exports. |
| `run_case.py import ...` / `wrong-polarity ...` | 1 / 1 | SCRIPT ERROR: parent theories loaded after the theory file. Not counted. |
| `run_case.py import-0002 import.sml stub-0002 ...` | 0 | Exact statements; 243 closure nodes; four Boolean axioms. |
| `run_case.py wrong-polarity-0002 ...` | 1 | `Exact statement mismatch: stub claimed install-free`. |

Unresolved U298 subgoal, unchanged: a target-level invariant that the program
counter never equals `mc.install_pc` on any formal prefix. The syntactic route
is now ruled out at the stub level by checked lemmas.

### Evidence integrity

`python3 -I -B verify_cases_r2.py` exits 0. On a copy with one byte appended to
an exported theory it exits 1; on a copy with an acceptance marker added to a
control stream it exits 1. The reader binds bytes, exits and markers. It does
not show that a theorem is true or who made a file.

## Phase 5 — Assurance profiles (neither is approved)

### Profile A — standard CakeML oracle

Environment restrictions, exact:

1. Every FFI call behaves as the published `basis_ffi cl fs` oracle. For
   `read` with a buffer of at least four bytes this is `ffi_read`: status 0
   with data given by `read fd fs n`, or status 1 with unchanged state exactly
   when the descriptor encoding is not 8 bytes, the buffer is too short for the
   request, or `read fd fs n = NONE` (descriptor absent, not in read mode,
   inode missing, or the `numchars` stream is exhausted).
2. Therefore excluded: any operating-system read error on an open, readable
   descriptor (for example `EIO`, `EINTR`, `EAGAIN`, `EFAULT`), and any change
   of descriptor state by another thread, process or signal handler.
3. The initial state satisfies `wfcl`, `wfFS`, `STD_streams` and
   `live_numchars` (runtime matrix S4–S7).
4. The machine satisfies the published installed-state predicate for an
   `is_arm8_machine_config` record, the processor behaves as the L3 model,
   and interference between steps preserves the projected state.

What the claim covers under A: for every request in the approved domain that
arrives on standard input in the stated wire form, the modeled machine
behavior is the specified six-field result, or stops early at a resource limit
with a prefix of that output. With U327, a read on well-formed standard input
never returns status 1, so the `InvalidFD` branch is not reachable there.

What it does not cover: native read errors; any environment that departs from
the oracle; correctness of `basis_ffi.c`, the loader, the operating system or
the processor (all assumed); guaranteed completion under finite memory;
malformed wire input (matrix row X3).

Still to prove or record under A: independent replay; `memory_assumption` from
the installed state; U298 exclusion or an explicit installer assumption; the
resource condition; an approved list of the assumptions above.

### Profile B — extended read-error oracle

Additional obligations beyond A:

1. A new oracle definition in which `read` on a readable descriptor can return
   status 1, with a stated effect on the file-system state. This changes the
   model and needs owner approval and a non-vacuity witness.
2. An approved contract clause for the refund program's behavior after a read
   error. The approved contract has none today (U328).
3. Library proofs under the new oracle for every basis function on the call
   path from `refund_main` to `TextIO.read`. `read_error_generic` (U345) gives
   the lowest step for any oracle. `read_error_basis_instance` shows it is
   consistent with the published oracle.
4. A whole-program theorem for the new oracle, and restatement of the Forge
   theorems that name `basis_ffi`.
5. Native side: `ffiread` returns status 1 exactly when the system call result
   is negative. `ffiread_error_return` (U348) covers six instructions at model
   level. Open: prologue and call frame, buffer-address binding, descriptor
   decoding, and the success path.
6. A narrower but still explicit operating-system assumption: on a negative
   result the buffer is unchanged.

### Comparison

| Aspect | Profile A | Profile B |
| --- | --- | --- |
| Native read errors on open descriptors | Excluded by assumption | In scope |
| Model or contract change | None | New oracle and new error clause; separate proposal |
| New proof work | None for the read path | Library, whole-program and native obligations 1–6 |
| Use of U345, U348, this packet's instance | Supporting evidence, off the critical path | On the critical path |
| Main residual risk | Real read errors are outside the claim | Size of the new proof and of the trusted model |

## Updated verification matrix (this continuation)

| Obligation | Exit(s) | Status | Theory data SHA256 | Replay |
| --- | --- | --- | --- | --- |
| `read_error_basis_instance`: proof, repeat, import; three controls | 0, 0, 0; 1, 1, 1 | PROVED | `f2afe94b…00b37885` | Clean NOT_RUN |
| `basis_read_error_oracle` (U351): import, repeat, control now run | 0, 0; 1 | PROVED | `b0927759…498e9a3c` | Clean NOT_RUN |
| `refund_initialization_machine` (U349) controls | 1; −24 (not counted); 1 | Controls complete with one resource stop | `8e8cb008…c4af72` | Clean NOT_RUN |
| `refund_initialization_aligned`: proof, audit, repeat; two controls | 0, 0, 0; 1, 1 | PROVED | `a4d3164e…d3639619` | Clean NOT_RUN |
| `install_stub_has_install`, `stubs_contain_install`: proof, import; control | 0, 0; 1 | PROVED | `300d83c7…f3f7a90c` | Clean NOT_RUN |
| `¬no_install_code (fromAList (stubs_md c))` | −24 | NOT proved: CPU limit, one attempt | — | — |
| U298 exclusion for the exact program | — | NOT_RUN | — | — |
| `memory_assumption` for the installed state | — | NOT_RUN | — | — |
| Native read errors on open descriptors | — | ASSUMED absent (Profile A) or open (Profile B) | — | — |
| Clean or independent replay of any theorem | — | NOT_RUN: disk deficit 13.3 GiB | — | — |
| Evidence reader; two altered copies | 0; 1, 1 | As intended | — | — |

Earlier rows (U345–U351) are unchanged; see
[the first continuation report](../m1-closure-20261112/REPORT.md).

## Updated dependency graph (changed edges only)

```
compile_correct premises for the exact program
  ├ initializer conditions      14 → 6 (U349) → 2 (this packet)
  │     ├ is_arm8_machine_config mc           [model choice, kept]
  │     └ memory_assumption (byte-aligned dm) [open; from installed state]
  ├ install handler
  │     ├ bridge theorems (U298)              [PROVED earlier]
  │     ├ syntactic no_install premise        [false for the stub list: PROVED lemmas]
  │     └ target-level exclusion              [NOT_RUN]
  └ FFI oracle
        ├ read error, unreadable descriptor   [basis_read_error_oracle PROVED]
        │     └ TextIO.read raises InvalidFD  [read_error_basis_instance PROVED]
        └ read error, open descriptor         [Profile A: ASSUMED absent; Profile B: open]
```

## Remaining obligations

1. Clean and independent replay of every theorem (blocked: 13.3 GiB deficit).
2. `memory_assumption` from the published installed-state predicate.
3. U298 target-level exclusion, or an explicit installer assumption.
4. Owner choice between Profile A and Profile B; approved assumption list.
5. ARM8: prologue, call frame and success path of `ffiread`.
6. Resource condition; malformed-input behavior; admission (M2).
