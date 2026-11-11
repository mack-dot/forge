# Exact ARM8 refund exception composition — @ENTRY@

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.

`forge_refundRejectCompiledTheory.refund_error_compiled_precise` is **PROVED**.
It composes U286's exact initialized refund error behavior with the existing
CakeML ARM8 compiler correctness theorem. The complete event list, exception
witness, initial heap frame and final source-heap relation are retained.
All machine and resource premises remain explicit. The existing native program
was neither recompiled nor executed in this checkpoint.

## Exact statement and premise audit

[expected.sml](records/expected.sml) gives the complete, separately written
expected statement. A fresh HOL import checks alpha-equivalence against both
new exported theorems. The full checked printout is in
[import-0001/stdout.log](records/import-0001/stdout.log).

Eight conjunctive premise groups remain:

| Premise | Discharged here? |
| --- | --- |
| `installed code cbspace data data_sp info.lab_conf.ffi_names (heap_regs arm8_backend_config.stack_conf.reg_names) mc info.lab_conf.shmem_extra ms` | No; exact compiler code/data/configuration are bound, but physical installation is not established |
| `read_limits arm8_config (set_oracle arm8_backend_config oracle) mc ms = (stack_limit,heap_limit)` | No; exact modeled resource relation remains |
| `wfFS fs` | No; retained from U286 |
| `STD_streams fs` | No; retained from U286 |
| `stdin_content fs = SOME text` | No; retained from U286 |
| `refund_run_wire (implode text) = INL err` | No; retained from U286 |
| `is_arm8_machine_config mc` | No; includes state, FFI/interference, entry and installer conditions |
| `∀po. is_safe_for_space (:64) (basis_ffi ext cl fs) po arm8_config (set_oracle arm8_backend_config oracle) refund_prog (stack_limit,heap_limit)` | No; every pointer oracle is required |

Under precisely these premises, the conclusion is:

```sml
∃h1 h2.
  SPLIT (st2heap (basis_proj1,basis_proj2)
    (SexpProg_st_2 (basis_ffi ext cl fs,K (K F)))) (h1,h2) ∧
  STDIO fs h1 ∧
  ∃io.
    machine_sem mc (basis_ffi ext cl fs) ms = {Terminate Success io} ∧
    ∃st3 exn.
      io = st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
        (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
      RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
      extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0)
```

The initial `h1,h2` witnesses remain outside the machine behavior. The exact
same `h2` occurs in the final heap relation. This is the source-level heap
relation carried by the compiler behavior claim; it is not an independently
established relation to the physical C heap. The trace equals the entire final
source FFI event list. No event is filtered, dropped or replaced by output bytes.

The exact `refund_arm8_compiled` theorem binds `refund_prog`, ARM8 code130436
bytes, bitmap2531 words and the emitted configuration. Its syntax condition and
the published backend configuration facts are discharged by existing proofs.
U286 supplies source non-failure through the existing `sem_satisfies` rule.
The two ARM8 machine-configuration implications are applied while retaining
their `is_arm8_machine_config` premise. No caller/environment premise was
silently removed; U286's exact four source conditions remain unchanged.

The only new helper, `exception_event_witness`, makes the existing event
projection an explicit existential event list. It retains the predicate `P`
verbatim. Temporary kernel hypotheses for the source's existential body are
eliminated with `CHOOSE`; the final theorems have no open hypotheses. This is
ordinary checked existential reasoning, not an unchecked assumption or axiom.
All original theorem source and data files retain their identities.

## Actual commands and controls

`R` means `records/run.py`; `I` means `records/import.py`. Their full executed
argv, sources, completion markers, stdout and stderr are preserved per case.
All HOL runs in this branch were serial.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Initial input inventory / corrected freeze_inputs.py | 1/0 | Different manifest schemas; failure retained |
| R inspect-0001 inspect.sml diagnostic | 0 | Original statements and compiler premises inspected before construction |
| R proof-0001 proof.sml | 0 | Helper and exact composition pass on their first attempts |
| R repeat accepted.sml | 0 | Same source and four byte-identical exports |
| I import-0001 audit.sml import | 0 | Both complete expected statements accepted on first import |
| I wrong-code wrong-code.sml import | 1 | Empty code substituted in installed premise; exact claim refused |
| I missing-space missing-space.sml import | 1 | Universal space premise omitted; exact claim refused |
| I short-trace short-trace.sml import | 1 | Full trace equation replaced with empty trace; exact claim refused |
| `/usr/bin/shasum -a 256 -c .../identity-0001/chain.sha256` | 0 |311 historical artifact/test-record members match |
| `/usr/bin/codesign --verify --strict --verbose=2` on both existing builds | 0/0 | Existing signatures verify; no signing performed |
| Replay source inventory first/corrected | 1/0 | Historical source filename corrected; partial snapshots retained |
| readback.py | 0 |486 theory nodes,2659 parent file bindings,2727 historical chain files |
| Independent full-chain replay or new native execution | NOT RUN | Plan and source bundle prepared only |

Each negative control fails at `Exact statement mismatch:
refund_error_compiled_precise`. These controls check binding to the approved
claim, not universal falsity or physical attacks. No malformed expected term
or infrastructure failure is counted as an adversarial rejection.

The input inventory initially expected a `files` wrapper in U296's direct
path-to-hash manifest. The replay inventory initially used `proof.sml` for
U282, whose saved argv names `export-proof.sml`. Both actual failures are kept.
Incidental missing-file and no-match inspections are recorded separately; an
uncaptured pipeline child exit remains unknown. No proof/import failure or
retry was needed for the new composition. U290/U297 stopped routes remain closed.

## Exact identities and trust boundary

| Artifact | SHA256 |
| --- | --- |
| New proof source | `4c0a0c2a6e27cfd3b2b1e1e510f301bff47d731ef44c8ba03ca9645c132e6a56` |
| New theory data | `6b8a9a3cb7ecf6746d407b22d840f414b2d6d4e2618c8afc87680a6c94f0917f` |
| New signature | `62758a0e816dc40b41f2ead2af875d4c630d897e8f6ecb56655eb2c7213db55f` |
| New structure | `ea991f540e1560c536dcb6a9fac0b4bf6c60d730596627706d5a782dc9d44d22` |
| New HTML | `7139afbb0896eb0468d2e351233bfe424b20b8b14400be91f9cb194cedae5828` |
| U286 parent data | `3c358b38b4617b8b29349fb90200c639150a582a8da6aad2c78bee092e7a8f28` |
| U296 precise-helper data | `e5034a037556f3d86c895e73d6523425ce781ca42e4972ddaa3220a4efa40c4c` |
| Existing executable, both builds | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Exact embedded compiler code | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
| Exact embedded bitmaps | `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76` |

Fresh readback checks both existing executable hashes and their full code/bitmap
slices using the preserved standard-tool offsets. The311-member checksum chain
binds native build and test records. Its historical results remain56 native
processes with exit0; they were not rerun. Byte identity and signature validity
do not establish the physical loader relation or trusted release provenance.

[dependency-snapshot.json](records/dependency-snapshot.json) lists486 theory
nodes and2659 parent file bindings, including duplicate-location records from
the source and compiler audits. All two imported theorem tags have zero open
hypotheses/new tagged axioms and only DISK_THM. The four existing foundations
remain `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
This confirms the reported theory ancestry, not a complete dynamic ML-loader
audit or an elimination of trust in HOL's logic/kernel, Poly/ML and the host.

The readback also checks50 protected paths, the frozen mission, U286's append-only
journal bytes,370 parent packet members and2727 prior chain files. CakeML/HOL
tracked sources remain unchanged; all three tool source pins match. The fresh
audit/checksum processes are separate from proof construction on the same host.
They are not clean independent full-chain replay or independent authentication.

## Assurance matrix

| Claim | Status | Limit |
| --- | --- | --- |
| Exact initialized source error contract | PROVED | U286's four source conditions; original statements unchanged |
| Exact compiler composition with full error/event/heap predicate | PROVED | All eight premise groups above |
| Exact program/code/bitmap compiler identity | PROVED | Existing pinned compiler theorem reused |
| Export repeat, complete statement import, controls and artifact/signature checks | TESTED | Actual results above; same host |
| HOL logic/kernel, foundations, loader, cached parent data and host | ASSUMED | Dependencies visible; independent rebuild pending |
| Physical installed state, FFI, interference and resource adequacy | NOT_ESTABLISHED | Retained premises are not physical proofs |
| Arbitrary real I/O failure, unavailable stdin and OS exit contract | NOT_ESTABLISHED | Not implied by the conditional source/target theorem |
| Independent full-chain reproduction and assurance | NOT_ESTABLISHED |21 source snapshots and replay plan prepared; replay NOT RUN |
| Complete M1/native correctness | NOT_ESTABLISHED | end_to_end=false |

Logical `Success`, modeled FFI events, native process exit status and physical
OS behavior are distinct. The exception has logical Success in these semantics.
Neither normal ML return nor OS exit0 follows. The precise compiler theorem
retains universal space safety; without it, the established compiler relation
allows Resource_limit_hit prefixes. A finite input test cannot discharge that
universal premise, and the approved Unicode/integer input domain is unchanged.

## Smallest next physical check and replay preparation

[PHYSICAL-NEXT.md](records/PHYSICAL-NEXT.md) isolates the exact `ffiread` C/ABI
relation to the published `ffi_read` oracle. One concrete concern is its error
branch: the model returns the unchanged filesystem, while the pinned source
comment itself warns about unspecified real file position on errors. This is
an explicit unresolved relation, not a proved Darwin counterexample. Check it
before treating the error-path model as physical behavior. The required buffer,
register and memory frame must also be proved with an established method.

[REPLAY-PLAN.md](records/REPLAY-PLAN.md) and
[replay-preparation.json](records/replay-preparation.json) prepare independent
source replay, acceptance checks and exact artifact comparisons. They do not
authorize a denied execution context or count as a completed replay. Separate
lower-pass/initializer work, resource adequacy, physical memory/FFI/OS relations,
source interpretation review, independent assurance and provenance remain open.
No protected change, release signing, deployment or Stage12 occurred.
