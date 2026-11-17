# M1 trusted computing base (U401 audit)

Date: 2026-11-16. Audit only. `end_to_end=false`. No profile approved.

Columns: (1) covered by a Forge theorem? (2) established external
result? (3) can be an explicit contract? (4) does trusting it weaken the
intended M1 claim? (5) smallest additional evidence.

"External result" entries are from my general knowledge of the
literature. I did not check them against sources in this run.

| Component | 1 Theorem | 2 External result | 3 Contract | 4 Weakens M1? | 5 Smallest evidence |
| --- | --- | --- | --- | --- | --- |
| HOL4 kernel, PolyML | No | LCF-style kernel; widely used. Candle and HOL Light results do not cover this kernel | No (foundation) | No. M1 names an "independent checker", not a verified one | Independent replay on a second machine. A second checker (OpenTheory export) is research, not M1 |
| CakeML compiler correctness | `compile_correct'` replayed (U386); instance conditional | Published proof | Its premises are the contract | No, this is the chosen route (mission 3D item 1) | Clean rebuild from pinned sources; show how `backend_config_ok`, `mc_init_ok`, `opt_eval_config_wf` are discharged |
| CakeML basis FFI oracle `basis_ffi` | Used as the model | Published, used by all basis proofs | Yes | No under Profile A. Read errors on an open descriptor are outside the claim | Owner decision on Profile A |
| L3 ARMv8 semantics | No | Published model, validated by testing, not derived from Arm's specification | Yes: "processor behaves as the model for the instructions used at EL0" | No for level B. Yes for level C | List of instruction words used; none for M1 |
| Relation to Arm's official specification | No | None used here. Arm publishes a machine-readable specification; no link to L3 is used | No | Level C only | Research |
| `SCTLR_EL1.A`, `E0E`, EL0 state | Explicit premises (U398) | — | Yes | No if stated | State them in the profile |
| Mach-O extraction | File slices proved equal to `code`, bitmaps (U389) | — | Yes | Small: ML reader and Python offsets are trusted | A second, independent extraction of the two slices and the hash |
| Loader maps the file | No | None | Yes: `refund_image_mem sl m` | No if stated | Slide-generic theorem, so the contract can be true |
| PIE slide | No. All composed theorems at slide 0 | — | Slide 0 is a contract that is probably false | YES. A false premise makes the claim empty for real runs | Slide-generic theorem, or a measured non-PIE artifact with a new hash |
| Dynamic linking (`__got`) | No. `g` is a variable | — | Yes: "slot holds the address of the named function" | No under Profile A (inside the C boundary) | None for M1 |
| C run-time, `_main`, path to `cml_main` | No | — | Yes: `refund_entry_pre` plus heap premises | No if stated | Joint satisfiability of all premises of the final theorem |
| C FFI code `basis_ffi.c` | Partial: `close`, `write` paths conditional (U393–U401) | CakeML trusts it | Yes, per reachable call | No under Profile A. But the literal clause is probably false (U393) | Restate as the simulation assumption |
| `libSystem`, kernel | No | — | `close_call_rel`, `write_call_rel` (assumed) | No under Profile A | None for M1 |
| Processor, memory, other threads, signals | No | — | `interference_ok` holds for the identity environment only (U392) | No if stated | None for M1 |
| File system and input | No | — | `wfcl`, `wfFS`, `STD_streams`, valid wire input | No if stated. Absent input is OPEN | A theorem or exclusion for absent input |
| Approved contract to HOL model | OPEN (last record) | — | No. This is the claim itself | YES. Without it the theorem is about a model body, not the approved R1–R5 Unicode contract | Re-audit; then a checked representation relation and the Unicode transfer |
| Proof import and case tooling (`run_case.py`, tag checks, exact-statement scripts) | No | — | — | It can hide a defect. Three defective exits-0 were found by reading statements (U393, U398) | Independent replay with a separately written statement checker |
| `refund_alloc_oracle` versus published `oracle` | Compile equation proved for `refund_alloc_oracle` | — | — | No, if the final theorem uses only `refund_alloc_oracle` and the stored `code` | Confirm in the final statement |

## Not substitutes

Hashes, signatures, reproducible builds and hardware attestation
identify an artifact or a platform. They do not show behaviour. None of
them discharges any row above. A constructed witness shows that a
premise set is satisfiable. It is not an execution.

## What must be trusted for a Path A claim

1. HOL4 kernel and PolyML.
2. Published CakeML definitions and the `basis_ffi` oracle.
3. The L3 model for the instructions used.
4. One simulation assumption: the real process, from the assumed entry
   state, refines the model machine with the abstract environment. This
   single item contains the loader, dyld, the C run-time, `basis_ffi.c`,
   `libSystem`, the kernel and the processor.
5. The input and file-system premises.
6. The file reader and offsets of U389.

Item 4 is large. Path A states it; it does not prove it.
