# Refund loaded-entry observations

CURRENT stage: none. M1 remains open. Stage 12 is unauthorized.
`end_to_end=false`. This packet adds finite native observations. It does not
establish universal executable correctness or approve a new assurance profile.

The exact refund executable stops at a hardware breakpoint at `cake_main`.
Its loaded code and bitmap bytes match the HOL-derived artifacts. Corrected
capture, repeat and full-map capture each produce the expected fixture output
and exit 0. The full-map capture records x0–x30, SP, PC and CPSR before and after
inspection, plus complete VM-region metadata. Their recorded values agree.

## Executed checks

All local commands use `/Users/mackianni/forge` as their root. Let
`R=results/refund-entry-observation-2026-11-04`. Exact argv, tool hashes, outputs
and numeric results are retained under `records/` in this packet.

| Command or check | Actual exit | Scope |
| --- | --- | --- |
| Installed LLDB help, native debug map and symbol dump | 0/0/0 | Read-only diagnostics |
| Installed LLDB: exact native file without dependencies | 0 | Complete symbol table reads successfully |
| Installed LLDB: dependency-loading diagnostics 0006/0009/0011 | child -10 each | SIGBUS in symbol parsing; no target execution |
| Direct dyld-file inspection | 0 | Does not establish the shared-cache path works |
| Direct libSystem path / invalid `image list -v` diagnostic | 1/1 | No on-disk dylib at that path; unsupported debugger option; both preserved |
| Existing Command Line Tools debugger with dependencies | child -10 | Same observed limitation; no installation or target execution |
| Upstream archive and bundle download | 0/0 | Both match the separately fetched official release digests |
| `python3 -B $R/upstream-observer/verify.py` | 0 | Existing GitHub CLI verifies exact upstream source and signer identities |
| Wrong upstream source-digest control | 1 | Explicit SourceRepositoryDigest mismatch; not a network error |
| Initial archive decompressor / tar listing | 1/0 | Required 1 GiB decoder window exceeds default; incomplete listing refused |
| Corrected listing / selected extraction | 0/0 and 0/0 | Explicit decoder memory limit; only observer files extracted |
| Authenticated upstream debugger target-open diagnostic | 0 | Exact native file and dependencies load |
| `python3 -B $R/attempt-0004/run.py` | 0 | Native exit 0; code/output match; bitmap comparison fails 1 |
| `python3 -B $R/attempt-0005/run.py` | 0 | Corrected named bitmap pointer; native exit 0 |
| `python3 -B $R/attempt-repeat/run.py` | 0 | Identical observer source; native exit 0 |
| `python3 -B $R/validate_captures.py` | 0 | Six byte comparisons return 0; all claimed scalar relationships checked |
| Altered captured-code comparison | 1 | One-byte observation corruption refused; mutant never executed |
| `python3 -B $R/attempt-fullmap/run.py` / readback | 0/0 | Native exit 0; 203 VM regions; all 34 recorded registers unchanged |
| Existing compiler behavior proof | IN_PROGRESS | Original invocation remains live; no terminal theorem result yet |

The earlier three launch failures remain in the
[previous observation packet](../entry-observation-20261104/REPORT.md).
Attempt 0004 is also retained as a failed complete capture: LLDB assigned the
bitmap expression result to `$3`, while the command read `$0`. The comparison
refused those bytes. Attempt 0005 uses the named `$forge_bitmap` value. Expected
bytes and acceptance conditions did not change. No failed attempt counts as a
passing proof. No fourth launch used the unchanged crashing debugger.

## Artifact and observer identities

| Object | SHA-256 |
| --- | --- |
| Complete existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| HOL-derived and observed code: 130436 bytes | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
| HOL-derived and observed bitmaps: 2531 words | `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76` |
| Exact fixture stdout | `629d44e9f09823060942f4b75007dcf87ddce9c505314a4b74f9ac19d9d84cee` |
| LLVM 23.1.5 release archive, tar.zst | `503de30ef90311e0b143623801b19af2250adac6d69faed65ad0051170202e3b` |
| Upstream LLDB executable | `33eff00615b4cd5629f29626a4472c631c2d4dacec86178371c49929b46b9287` |
| Upstream liblldb | `10c2268480d12dff79b612f13e762e6749861ceb67d55b228b27c5a91b5f966f` |
| Existing Apple debugserver | `fad3bed0ed81389180c4d1154e122ec86d33e758a922536cb1b95d56addb33b4` |

The upstream package is from the
[official llvmorg-23.1.5 release](https://github.com/llvm/llvm-project/releases/tag/llvmorg-23.1.5).
The expected source and signer commit is
`392dfff97d29b59d77e5cac6d4b6ef2585fe7117`, obtained independently from the official
tag. The verified certificate identity is the upstream
`.github/workflows/release-binaries.yml@refs/tags/llvmorg-23.1.5` workflow.
The source ref, source digest, signer digest and hosted-runner requirement are
explicit CLI constraints. The frozen workflows and verified bundle are retained.
This authenticates the downloaded observer package's declared producer. It does
not prove that debugger correct or authenticate these locally produced captures.

The installed Apple LLDB variants report `lldb-1700.0.9.502` on this recorded
macOS 27.0.1 host. Their dependency-symbol failures motivated the isolated
upstream observer. No global tool installation, compiler replacement, proof
framework, service, executable rebuild or signing operation occurred. Existing
Apple debugserver is selected explicitly. The original native bytes remain intact.

## Updated correspondence evidence

OBSERVED refers to the finite debugger run. DERIVED refers to arithmetic on its
recorded values. Neither label means a universal machine-semantics theorem.
The full obligation list remains in the
[compiler/runtime premise matrix](../arm8-assurance-audit-20261104/REPORT.md).

| Relationship | Status | Actual evidence or unresolved condition |
| --- | --- | --- |
| Exact file identity | OBSERVED | Native file digest unchanged before and after every run |
| Loaded instruction bytes | OBSERVED | All 130436 bytes match the HOL-derived code; hardware breakpoint confirmed after launch |
| Initial PC | OBSERVED / DERIVED | Equals loaded module base plus file-entry offset 0x40d0; 4-byte aligned |
| Initial GPRs, FP alias, LR, SP and CPSR | OBSERVED | 34 named values; full-map run rechecks all 34 unchanged before resume |
| Stack alignment | DERIVED | Observed SP is 16-byte aligned; not a universal launch guarantee |
| Heap/stack scalar bounds | DERIVED | x1 < x2 < x3; word-aligned; total span 536870912 bytes |
| Heap/stack VM permissions | OBSERVED | Four adjacent 134217728-byte rw- regions cover the complete recorded span |
| Loaded bitmaps | OBSERVED | 20248 bytes match all 2531 HOL-derived words in three accepted captures |
| Five heap-header pointers | OBSERVED / DERIVED | Bitmap bounds differ by 20248; extra-data end equals bitmap end; code-buffer start equals PC+130436; buffer length 428; no scalar wrap |
| Bitmap/heap separation | DERIVED | Recorded intervals are disjoint; full separation-logic relation still open |
| Code and bitmap mappings | OBSERVED | Code lies in r-x __TEXT; bitmaps lie in rw- __DATA |
| All initial heap contents and byte/word model correspondence | NOT_ESTABLISHED | VM permissions do not supply the universal model-memory relation; unread contents remain explicit |
| Physical ARM control state | UNOBSERVED | EL/control registers, translation/tag configuration and complete arm8_ok relation are not discharged by GPR/CPSR capture |
| Floating-point relation | Configuration fact only | Published target has fp_reg_count=0; this is not a new floating-point state proof |
| Library loading | OBSERVED metadata only | UUIDs and load addresses recorded; loaded dependency bytes and OS/loader semantics remain unproved |
| FFI state, ABI frame and external interference | NOT_ESTABLISHED | The stopped entry observation does not prove universal return, memory-frame or scheduling conditions |
| Functional fixture result and process exit | OBSERVED | Same frozen eligible request; exact expected stdout, empty stderr and native exit 0 |
| All-input resource sufficiency and process exit | NOT_ESTABLISHED | No full-domain safe-for-space theorem or complete native FFI/exit refinement follows |
| Full source/Unicode/HOL binding | NOT_ESTABLISHED as complete chain | Earlier source/model proofs remain; no new bridge is inferred from one fixture |
| Clean independent final-chain replay | NOT RUN | Same-host reproduction is not independent replay |
| Authenticated Forge claim and release admission | NOT_ESTABLISHED | Upstream observer provenance is distinct from new Forge evidence provenance |

ASLR is enabled. Load addresses differ across captures. Code bytes, bitmap bytes
and fixture streams reproduce exactly. Raw register/address logs do not. Local
elapsed times are diagnostic timings; no speedup or hosted-cost claim is made.
The observer evaluates only a pointer read with `--allow-jit false`. It neither
injects a target-side helper nor changes the executable to obtain the observation.
Debugger instrumentation remains part of the observation's trust boundary.
Matching recorded registers and payloads is not a proof that all machine state
is unchanged by observation.

## Remaining path

Finish the original compiler behavior proof. Inspect its actual theorem and
premises, then require binding controls and reproducible exports. Do not restart
the live invocation. The separate exception branch keeps its own evidence and
authorization boundaries. These observations can support a conditional assurance
argument, but cannot replace the missing semantic relations or resource theorem.

Next, discharge the remaining source/model and runtime obligations or prepare an
exact, independently reviewable assumption profile. Do not silently narrow the
approved domain. Preserve independent replay, exact review, new authenticated
provenance/admission and off-machine archive hash/restore as separate requirements.

Integration EXIT: **NOT_ESTABLISHED**. No Stage 12, publication, protected policy
change, merge, dispatch, release signing, admission or deployment ran here.
