# W-x8: X8 and X11 statements (condensed by Orchestrator A; DRAFTING; nothing proved; nothing run)
Files: `X8_statement.txt` (ddfc8e20…), `X11_statement.txt` (57458035…), `tests_proposed.txt` (c6388ce5…).
Main points (by reading; UNCHECKED; review pending):
1. In the composed theorem (MF-0002) `s`, `envmc`, `fs`, `cl` are universally quantified. So X8 need not show that the
   C code IS a fixed `envmc`. Build `envmc_R`, `fs_R`, `s_R` from ONE real execution: `next_interfer` a guarded fill;
   `ffi_interfer` = the real effect at the OBSERVED calls and `refund_abs_ffi` elsewhere (stored
   `refund_abs_ffi_contract_at` covers the other states); `numchars` from the real read/write counts. Then the all-states
   FFI premise holds for `envmc_R` if the real effect meets the contract AT THE OBSERVED CALLS. U393 (a state the run does
   not reach) does not block X8 in this form. CakeML uses the same idea ("constructed oracles", targetPropsScript 248-302).
2. Two model-side lemmas needed (MISSING; estimated hours): T-TRACE, T-ENV.
3. A-CPU-ISA is needed only for the encoder's instruction subset. The toolchain holds an UNBUILT, NOT RUN proof that the L3
   model equals the Arm ASL v8.6 model on that subset (`arm8/asl-equiv/l3_equivalenceProofScript.sml`), under premises
   (no VHE; flat memory) whose truth on this machine is UNKNOWN. ASL → silicon stays an axiom.
4. New premise A-X18 (`interference_ok` freezes all registers; whether the kernel keeps x18 is UNKNOWN): needs a decode
   lemma "no code word names x18" (MISSING).
5. A-ENTRY-ARGV resolved by reading (the bitmaps domain lies below `_argc`; 5 dyld binds, all outside the proved slices).
6. The exit status is not needed (decide by strict parse of the complete stdout).
7. X11: 20 event kinds with premise and class; no pthread/sigaction/timer/mmap/mprotect imports; SIGPIPE default kills.
   Page protections, TBI/SA0/E0E, x18, VHE, libSystem threads: UNKNOWN. Every OS row ends at the axiom A-KERNEL-PRESERVE.
Defect found in an earlier draft: `drafts/M1_EXACT_CLAIM.md:294-309` uses `∃ext` and takes `envmc`, `fs` as given.
Tests proposed (NOT RUN): T1, T5 static; T2 (DYLD probe), T3, T4 (lldb) need the owner's approval.
