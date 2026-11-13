# Physical installed state: proven facts, assumptions, unverified claims (U360)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
`installed` is the published predicate (`targetSemScript.sml:487`). It holds
`good_init_state` (`targetSemScript.sml:444`). The published compiler theorem
uses it as its one machine-state premise. For the physical process it is
NOT_ESTABLISHED. This file lists each clause.

## 1. Proven facts (HOL kernel, local scope, model level)

| Fact | Theorem | Entry |
| --- | --- | --- |
| Exact program compiles to the exact code, bitmaps and configuration | `refund_arm8_compiled` | U275, U291 |
| The machine predicate is satisfiable by an explicit record | `arm8_machine_model_instance` | U358 |
| `memory_assumption` and every other initializer premise follow from `installed` | `refund_initialization_installed` | U358 |
| An ideal install handler exists for every ARM8 machine record | `arm8_install_handler_ok`, `arm8_install_handler_exists` | U360 |
| `installed` without its `install_interfer_ok` clause gives `installed` for the record with the ideal handler | `installed_modulo_install_handler` | U360 |
| That weaker predicate plus installer exclusion gives the behaviors of a fully installed machine | `install_exclusion_suffices` | U360 |
| Handler replacement keeps `machine_sem` under exclusion | `machine_sem_install_irrelevant` | U298 |

These are facts about definitions and the abstract machine record. None is a
fact about the physical process.

## 2. Clauses of `installed`: status for the physical process

| Clause | Needs | Status | Matrix row |
| --- | --- | --- | --- |
| `target_state_rel`: `arm8_ok` (EL0, `E0E`, `SA0`, `TBI0`, `TBI1` clear, no exception, aligned PC) | Control-register values at entry | PC alignment DERIVED; CPSR OBSERVED; `SCTLR_EL1` and `TCR_EL1` UNOBSERVED | E1 |
| `target_state_rel`: PC, registers except 18, 26, 31, every byte of the program domain | A quantified memory and register relation | 34 entry values OBSERVED; relation ASSUMED | E2, E4, E7 |
| `target_configured` | An abstract state `t` that agrees with the record | Configuration facts PROVED; witness OPEN (model level) | E6 |
| `start_pc_ok`: halt, install and FFI entries at 16, 32 and 48+ bytes below the code start; outside program and shared domains | Arithmetic on the chosen record | Offsets DERIVED; complete predicate OPEN. The U290 route is closed after five attempts | E5, F1 |
| `interference_ok next_interfer` | Scheduler, signals, other threads, debugger preserve the projected state | ASSUMED | I1 |
| `ffi_interfer_ok` | Each FFI C function: valid state, return to the link register, frame condition, callee-saved registers | ASSUMED. One six-instruction path of `ffiread` PROVED at model level | F2, F3 |
| `install_interfer_ok` | The native installer implements `memmove`, returns the destination, keeps the frame | NOT_ESTABLISHED and likely false: the code buffer is mapped read/execute and the build has no `EVAL` (U296). Replaceable by installer exclusion (U360) | F4, M8 |
| `code_loaded`, `bytes_in_mem` | Loader places the exact bytes | 130436 bytes OBSERVED equal; loader ASSUMED | M1 |
| Data domain inside the program domain; byte-closed; shared domain disjoint | Domain choice for the record | Intervals DERIVED; witness OPEN (model level) | M3 |
| Memory words and bytes agree for every address | Complete memory relation | NOT_ESTABLISHED | M2 |
| Code-buffer clauses | Buffer in the program domain, outside data | Candidate 428 bytes DERIVED | M8 |
| Heap registers aligned and ordered; at least 1024 words | Entry values of two registers | OBSERVED for the captured runs | M4, E7 |
| Five header words | Words written by the C start-up code | OBSERVED for the captured runs | M6 |
| Bitmap words; disjoint from heap and stack | Loaded data section | 20248 bytes OBSERVED equal | M5 |
| `ffi_names`, no shared-memory entries | Compiler output | PROVED for the compiler; record witness OPEN (model level) | F1, F5 |

## 3. Exact missing obligations

Model level (provable in HOL; no physical input):

1. A complete record and abstract state: `start_pc_ok`, `target_configured`,
   the domain clauses and the `ffi_names` clause for one explicit machine
   record. The U290 route is closed; a new route is needed.

Physical correspondence (each needs a proof about native code or a named
assumption):

2. Start-up code: the C entry code in `basis_ffi.c` reaches the CakeML entry
   with the two heap registers, the five header words and the alignment that
   `installed` states. No proof exists. Evidence is OBSERVED entry captures.
3. FFI code: each FFI function used by the program meets `ffi_interfer_ok`.
   Proved: one error-return path of `ffiread` at model level.
4. Installer: exclusion for the exact program (U298), or a native installer
   proof. Neither exists.
5. Loader: the Mach-O loader gives the stated bytes, mappings and permissions.
6. Processor and operating system: the L3 model describes the processor;
   interference preserves the projected state; `SCTLR_EL1` and `TCR_EL1` bits
   have the stated values.

## 4. Unverified claims that must not be read as results

- "The process is installed" for any run. Finite captures agree with the
  clauses that were observed. They do not prove a quantified clause.
- "The installer is never called." The executable holds one call (code offset
  4660). No reachability theorem exists.
- Control-register bits of `arm8_ok`. They were never observed.
