# Corrections to apply to the X8/X11 draft before it can be stated (2026-11-19T14:44:42Z); the draft files are unchanged
Sources: A's reviewer W-x8rev (`review/REPORT.md`) and red team C (message C-PREM-01; files `orch-C/c9-x8/`). All by
reading unless marked RUN. Nothing here is machine-checked.
1. (C) New assumption A-F0-REAL: at EL0 the L3 model also reads SCTLR_EL1.A (alignment checking) and PSTATE bits; `erase`
   keeps them. The abstraction must take these bits from the REAL state, and "the kernel keeps every system-register bit
   that the L3 model reads constant over the run" must be assumed (X11 row E14 names only E0E/EL/TBI/SA0).
2. (C, W-x8rev) Interference indexing: `next_interfer` advances on normal steps only, not on FFI steps; the trace includes
   the 27 entry instructions. The draft's "m-th U event" is off; the constructed function must be indexed by the count of
   normal steps of the model run. Fixable; the trace lemma (worker W-trace) must use the right index.
3. (C) Clause (f) is FALSE for killed runs as written: a write that never returned can leave bytes in the pipe
   (PIPE_BUF = 512 here, RUN by C: getconf; chunks up to 2048). The time-out/killed clause must say: the observed stdout is
   a prefix of `fd1_written` of an EXTENSION of the observed events (W-x8rev found the same gap: an in-flight write).
4. (C, W-x8rev) Overclaim: "strict parse ⇒ correct" needs a fail-closed argument for runs that violate a native
   premise. The consumer cannot observe A-KERNEL-PRESERVE, A-FFI-FRAME, A-FD0-READ afterwards; the loader class (CE-3)
   already falsifies it for A-LOADER. So these premises must be ENFORCED by the launcher or stay assumptions; the theorem
   concludes nothing when one fails.
5. (W-x8rev) Add "SP preserved or 16-aligned" to the kernel and FFI premises; cite `machine_sem_total` and the add-clock
   lemmas for behaviour existence; define the returned bytes as the real post-call bytes.
6. (C) The analogy with CakeML's constructed oracles is overstated (CakeML builds them from a MODEL run). Proposed tests
   T2 and T4 cannot fail in the relevant direction; add a perturbation differential under the launcher contract.
Holds by reading (both reviewers): the off-trace abstract effect avoids U393; the read/write byte clauses against
`basis_ffi.c:160-189` (given the launcher contract: blocking pipes, sole stdin reader, default SIGPIPE, empty mask); the
entry clause. C's negative runs (RUN, exit 0): 9 signal runs while blocked in read/write give the exact frame; truncated
stdin gives no strict frame; one thread.
