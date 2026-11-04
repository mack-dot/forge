# Refund native execution assurance checkpoint — U276

CURRENT stage: none. M1 remains open. Stage12 is unauthorized.
`end_to_end=false`. This package does **not** establish complete native correctness.
It records exact native bytes, finite executions, preserved failures, and the
remaining proof and trust boundaries. U262's Unicode proof was not rerun.

## Actual results

`OUT` is `results/refund-native-audit-2026-11-04/attempt-0004` in the owner workspace.
The package's `records/` directory preserves this checkpoint's files. Earlier
reports retain their original proof evidence. Commands below ran locally.

| Command or recorded invocation | Actual exit | Result |
| --- | --- | --- |
| `python3 -B $OUT/link_native.py .../compile-0001` | 0 | Two assemblies, links and local signature checks pass; complete executables match |
| `python3 -B $OUT/run_native.py native-cases-0001 .../native-build-0001` | 0 | 22 typed outputs match; six malformed observations recorded |
| `python3 -B $OUT/run_native.py native-cases-repeat .../native-repeat-0001` | 0 | Same 28 cases; all 84 stream pairs match |
| HOL extraction0001 dispatcher | 130 | Manually interrupted during expanded-term formatting; child exit not recorded |
| `python3 -B $OUT/run_extraction.py extraction-0002` | 0 | Existing HOL evaluator derives 130436 code bytes and2531 bitmap numerals |
| `python3 -B $OUT/compare_native_identity.py` | 0 | Both linked code/bitmap slices match HOL;311 file hashes checked with system SHA tool |
| Fresh copied executable `codesign --verify --strict` | 0/0 | Both existing local ad hoc signatures validate |
| One-byte mutant `shasum -a 256 -c` / `codesign --verify --strict` | 1/1 | Intended digest/signature refusals; mutant never executed or signed |
| `python3 -B $OUT/exception-diagnosis-0001/run.py` | 0 | Inspection only; two residual goals printed; no accepted theorem |
| `python3 -B $OUT/check_chain_inputs.py` | 0 |2727 files,2262 closure files,108 runtime inputs,56 execution records and50 protected files checked |

The historical preparation README and build-time `native_execution:NOT_RUN`
fields remain unchanged. They describe the earlier preparation/link checkpoints.
The subsequent execution records above supersede those status observations.

## Exact artifact identities

| Artifact | SHA256 |
| --- | --- |
| Original `spec/refund/RefundSpec.dfy` | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` |
| U262 `UnicodeRelation.dfy` | `804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990` |
| Whole-program source | `37d623cc2437f391d4a0e72afcc72ed0b541e82f985dc5a2dfbe73a29e3ef4d0` |
| Whole-program theory data | `52b94fa448fa6de315cab80251ed5cdf46184a576e9478644b374e8071b19ded` |
| Compiler application source | `b7e12fcf2754d115eb80d0f49fb07c06d629b956ed2e9f0d1a6213b2be60202c` |
| Compilation theory data | `30076203f55c9f0fa85dec0ebcb62d5ee41961b46055727fe26c9299e55dd78a` |
| Generated `refund.S`, both builds | `4c750e4f9ecf75ff1f0bf5af7bfbdd0600ee2ca0e1564fcadc299db55c3a1757` |
| `refund.o`, both builds | `5e8b6050b8d5632a0df532966ea244b08d3e9b3f68145f0e99765f4cb2978ee7` |
| Published runtime C source | `e65a58121bcf7c32501ed01f75783f08ec30653192b2265665a9cdae199ab2a1` |
| `basis_ffi.o`, both builds | `74f9efbf5132301386c2656638f826e6e5fec2593e99d406aa9618851dc94a55` |
| Exact signed `refund`, both builds and all56 executions | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
|130436 embedded compiler code bytes | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
|2531 embedded little-endian64 bitmap words | `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76` |

`identity-0001/result.json` records code file offset16592 and bitmap offset180248.
Fresh `nm` and `otool` outputs establish the symbols and section mappings used
for those byte comparisons. This is an identity check using established tools,
not a custom Mach-O decoder or a proof of what dyld installs into memory.

The full CodeDirectory hash is
`7c0eef4687359f32f0f393e9063a96024fd4229d3db9bceec5e961e4368552ac`.
The signature is ad hoc and linker-generated. It authenticates no release
identity or producer. U269 authorized only these local signatures. No new
release signing, publication, admission or deployment occurred.

`chain-inputs-0001/manifest.json` binds source/theory inputs, recorded commands,
runtime headers, compiler binaries, named linker inputs and execution records.
The linker plan identifies `ld`, libLTO, libclang_rt, `-lm` and `-lSystem`.
The executed file's load commands name `/usr/lib/libSystem.B.dylib`.
The actual linker file-read closure and loaded dyld shared-cache bytes were
not captured. Their exact identity remains NOT_ESTABLISHED. Current hashes of
named implicit inputs do not retroactively prove which bytes the loader used.

## Compiler theorem and premise audit

The applicable generic theorem is `backendProof.compile_correct`, at line4952
of the pinned `compiler/backend/proofs/backendProofScript.sml`. It requires:

```text
compile asm_conf c prog = SOME (bytes,bitmaps,c')
let (s,env) = THE (prim_sem_env ffi) in
  not (semantics_prog s env prog Fail)
  and backend_config_ok asm_conf c
  and mc_conf_ok mc
  and mc_init_ok asm_conf c mc
  and installed bytes cbspace bitmaps data_sp c'.lab_conf.ffi_names
        (heap_regs c.stack_conf.reg_names) mc c'.lab_conf.shmem_extra ms
=> machine_sem mc ffi ms SUBSET
     extend_with_resource_limit (semantics_prog s env prog)
```

This display is a reading aid. The exact pinned SML source is preserved under
`chain-inputs-0001/pinned-sources/`; its hash is in the manifest. Do not replace
the theorem with the display. `refund_arm8_compiled` supplies the compilation
equation with `set_oracle arm8_backend_config oracle`, exact code/data/config,
FFI names, symbols, lengths, empty shared-memory extras and syntax validity.
Its accepted exports reproduce. The separate `refund_compiled_behavior`
composition is still building dependencies at this checkpoint. It has no
terminal exit or accepted result here.

| Premise or boundary | Status for this physical executable | Evidence and remaining condition |
| --- | --- | --- |
| Exact compilation equation | PROVED | `refund_arm8_compiled`; compile/repeat0/0; six identical exports |
| Source non-Fail and canonical output | PROVED, conditional model claim | `refund_semantics`; requires `wfcl`, `wfFS`, `STD_streams` and canonical serialized stdin; no physical environment witness |
| Backend configuration | PROVED for published model configuration | `arm8_backend_config_ok`; exact set-oracle composition is still pending |
| Encoder, register and target configuration | PROVED conditionally | `arm8_machine_config_ok`, `arm8_init_ok`, `arm8_compile_correct` require `is_arm8_machine_config`; this identifies arm8_target, argument registers0–3 and saved registers19–28 |
| Physical CPU implements the target transition relation | ASSUMED, not discharged | No trace/refinement proof maps this Apple CPU and OS execution to `arm8_target` |
| `target_state_rel`, `target_configured` | NOT_ESTABLISHED | Initial machine registers, target validity, endianness, alignment, link register and memory domain need a concrete state witness |
| `code_loaded` and `bytes_in_mem` | TESTED at file boundary only | All compiled bytes match both files; ASLR/loader/relocation/page mappings and executing memory remain unproved |
| `start_pc_ok` | NOT_ESTABLISHED | Entry/FFI/install/halt PCs,16-byte offsets, domain exclusions, alignment and FFI index lookup must hold in the loaded state |
| `interference_ok` | ASSUMED, not discharged | Interrupts, concurrent interference and the next-state oracle must preserve the required projection |
| `ffi_interfer_ok` | NOT_ESTABLISHED | Each real FFI call must match modeled byte buffers, return PC, target state, saved registers and memory preservation; no C/ABI/OS proof exists here |
| `install_interfer_ok` | NOT_ESTABLISHED | `cml_install` source uses memmove/cache handling; its machine-code relation, preservation and return value are unproved, even if the request path is expected not to install code |
| Heap/stack/bitmap domains in `installed` | NOT_ESTABLISHED | Need aligned ordered bounds, minimum1024 words, disjoint domains, coherent byte/word memory and exact initialized pointers |
| Five initial heap words in `installed` | NOT_ESTABLISHED | Must contain bitmap start/end/spare end and code end/buffer end. C allocation and wrapper source inspection are not a proof |
| Bitmap contents and spare region | TESTED for bitmap file bytes; remaining premise NOT_ESTABLISHED |2531 exact words match; `word_list`, spare memory, domain/alignment and loaded address relation need proof |
| Code-buffer range and wraparound | NOT_ESTABLISHED | `good_init_state` requires range membership, separation and `cbspace + LENGTH bytes < dimword`; concrete loaded-state witness absent |
| FFI-name order and shared memory | PROVED for compiler metadata; installation NOT_ESTABLISHED | The compilation equation fixes names and empty `shmem_extra`; installed stubs, FFI entry list and MMIO consistency still need proof |
| Modeled external FFI oracle equals real stdin/stdout | NOT_ESTABLISHED | `basis_ffi` models filesystem/command-line behavior; POSIX read/write, short transfers, EOF, errors and signals require a refinement relation |
| Resource sufficiency / complete output | NOT_ESTABLISHED | `extend_with_resource_limit` permits termination with a trace prefix. No `is_safe_for_space` proof or `read_limits` equality discharges this. Tests use256MiB heap/stack only |
| Halt result equals physical process status | NOT_ESTABLISHED | Modeled halt Success uses register0=0; assembly branches to `cml_exit`, whose C source calls `exit(arg)`. Stub/ABI/C/library/kernel correspondence is unproved |

`installed_def` and `good_init_state_def` are preserved in full. Their nested
predicates remain obligations even when this table summarizes them. No premise
was silently removed. ASSUMED marks a trust requirement for a physical claim;
it does not assert that the requirement has been independently validated.

## I/O and assurance matrix

PROVED means a checked logical claim with its stated premises and imported-proof
trust. TESTED means a finite observation or artifact check. ASSUMED means an
explicit trust condition. NOT_ESTABLISHED means the required link is still open.

| Claim | Status | Exact evidence / limit |
| --- | --- | --- |
| Full Unicode source relation, empty strings, reasons and caller IDs | PROVED | U262 `EncodedInjective`, `SameReasons`, `StringRoundTrip`, `Equivalent`; source hash above; accepted final/repeat0/0; local transport commit73728c2efa94b452637dfd10f36546f6f8a08d23 |
| Dafny source relation is exactly the independently encoded HOL AST relation | NOT_ESTABLISHED | Existing source and HOL results remain separate; source hashes do not supply a cross-logic semantic bridge |
| HOL refund fields preserve the modeled original method | PROVED | `refund_fields_original_method`, `refund_verified_spec`; U267 source2ef6fd80 and data5ffd9d6f; full hashes in chain manifest |
| Complete wire decoding, dispatch and six-field serialization | PROVED in model | `refund_run_wire_valid`, `refund_render_fields_roundtrip`, `refund_dispatch_valid`; strict decode/trailing/malformed theorems in U268 |
| Modeled stdin consumption through EOF and stdout | PROVED for canonical source requests | `refund_main_valid`, `refund_whole_prog_spec`, `refund_request_whole_prog_spec`, `refund_semantics`; U270/U271; whole build/repeat0/0 |
| Modeled malformed input raises Fail at application level | PROVED | `refund_dispatch_error`, `refund_main_error` with POSTe; this is not a whole-program or native exit theorem |
| Exception-to-declaration and whole-program error behavior | NOT_ESTABLISHED | U274's five failures remain; new inspection0 exposes the final declaration/heap obligations only |
| Exact compiler code and bitmap file payload | TESTED, with HOL-derived expected values | extraction0002 exit0; comparison0; code/bitmap hashes and offsets above |
| Native Unicode, empty IDs, integer amounts, reasons and caller IDs for frozen cases | TESTED |22 typed cases per build;44 exact complete outputs, including huge integers, Unicode/NUL/escaped IDs and business refusals |
| Native malformed-input and EOF observations | TESTED | Six closed-pipe malformed cases per build;12 processes exit0 with empty stdout/stderr. No promised native rejection status is proved |
| Universal physical I/O, exceptions, short I/O, OS errors and process exit | NOT_ESTABLISHED | No transport/runtime refinement theorem;56 cases cannot discharge this claim |
| Native reproduction | TESTED locally | Two byte-identical signed files,56 exit0 executions,84 identical stream pairs; same host/toolchain/cache |
| Artifact mutation detection | TESTED | One compiled code byte changed; standard digest/signature checks return1/1; no functional mutation inference |
| Proof dependency closure | TESTED identity; imported proof trust ASSUMED |378 nodes,377 theory file sets,10 own tags, zero explicit hypotheses; DISK_THM; bool.SELECT_AX/INFINITY_AX/ETA_AX/BOOL_CASES_AX |
| Kernel, Poly/ML, Dafny/Z3, platform tools, OS and hardware fidelity | ASSUMED | Pinned identities and known foundation axioms are recorded; no bootstrap/physical correctness proof here |
| Clean independent full-chain replay without producer workspace/cache | NOT_ESTABLISHED; NOT RUN | No complete final proof chain exists to replay. Fresh imports/copies on this host are not independent reproduction |
| Complete specification-to-native-execution correctness | NOT_ESTABLISHED | All missing links above remain; `end_to_end=false` |

## Exception diagnosis and smallest next experiment

All five original failures were inspected and rehashed. Build0001 fails at
missing imports. Build0002 fails the required lemma. Diagnostics0001/0002 fail
at variable renaming. Build0003 removes that renaming but still fails inside
the composite proof. Both original heap hashes remain unchanged.

The new, separately justified inspection uses the third saved heap. It does not
export a theorem or make a sixth full-lemma attempt. All steps through app/heap
extraction, POSTe reduction, clock addition and witness selection complete.
The exact residual goals and hypotheses are in `exception-diagnosis-0001/stdout.log`:

```text
exists ck1 ck2.
  evaluate_dec_list (st1 with clock := ck1) env1
    (SNOC (Dlet NoLocs (Pcon NONE [])
      (App Opapp [Var (Short "refund_main"); Unit])) prog)
  = (st' with clock := ck2, Rerr (Rraise v))

exists h3 h4. SPLIT3 (st2heap p st') (h3,h2,h4) and Q v h3
```

The hypotheses already contain `st2heap p st' = heap`, `SPLIT3 heap
(h_f,h2,h_g)` and `Q v h_f`. Thus the second goal has direct existing witnesses;
the inspection does not claim to have checked its proof. The first goal is the
remaining call/declaration stitching obligation. No semantic contradiction or
exact failed tactic inside that branch has yet been established.

**Next experiment, NOT RUN:** inspect only this first branch. Supply its two
clock witnesses, apply `evaluate_dec_list_append`, and print the residual goal
after each single existing declaration/evaluation rewrite. Stop at the first
failure or residual expression. Do not rebuild the full theorem. This determines
whether the missing fact concerns environment lookup, clock normalization, or
propagation of `Rerr (Rraise v)`. Only then propose a focused lemma with the same
premises. The exact prepared diagnostic is `next-branch-inspection.sml`.

Finish the separate, already-running compiler behavior composition without
starting a duplicate. Full runtime/loader and cross-logic proofs remain separate
obligations even if that conditional theorem passes. Independent clean replay
comes after those links exist. No valid-input restriction, specification change,
new axiom or proof-machinery modification is proposed by this checkpoint.
