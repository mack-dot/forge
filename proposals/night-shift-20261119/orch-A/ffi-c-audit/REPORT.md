# A9 native FFI audit (condensed by Orchestrator A; re-run by A: `python3 -I run_native_ffi_tests.py` exit 0,
# results byte-equal to the worker's `native_ffi_results.json`, folder `ffi-c-audit-recheck/`)
Executable: `refund` SHA-256 b8ed5ec2…7bb8 (copy). 15 native runs. No HOL. Class of every row: TESTED-UNPROVED unless said.

## Counterexamples reproduced on the real process
- CE-1 (T10): stdout a non-blocking pipe with 1000 bytes free. Exit status 0, stderr empty, stdout = the first 1000 bytes
  of the 4044-byte frame. So "exit status 0 and empty stderr ⇒ complete output" is FALSE for the real process.
  Cause by reading: `write` returns −1 (EAGAIN) → `basis_ffi.c:182-184` sets a[0]=1 → `InvalidFD` uncaught → normal exit.
  The model never fails a write on fd 1 (`liveFS`): the model gives the full frame on Success. Safe direction (a prefix).
- CE-2 (T03–T06, T08, T09, T16): closed/read-only/full stdout, closed/directory/non-blocking stdin: exit 0, EMPTY stdout.
- CE-3 (T13): `DYLD_INSERT_LIBRARIES=./forged.dylib`: a constructor writes a complete well-formed frame
  `(refund-result-v1 True 999 returned_item forged forged 1)` and `_exit(0)`: exit 0, stderr empty; `frame.strict_accepts`
  accepts it. DANGEROUS direction. It is the loader/environment boundary, not an FFI call. The binary is ad hoc signed
  (flags 0x20002), no hardened runtime. New NATIVE assumption A-LOADER: the launcher scrubs `DYLD_*` (or the binary
  enforces library validation, or a static executable). MISSING today.
- No FFI-level divergence in the dangerous direction was found: every reachable FFI divergence gives an empty or
  strict-prefix stdout, or a signal (T07: −13).

## FFI index list of the executable
0 read (reached: conf n2w8 0, alen 4100, n 4096); 1 write (reached: conf n2w8 1, alen 2052); 2 close and 3 open_in (only on
the dead `Some fname` branch: source argument, formal exclusion MISSING). No get_arg*/exit FFI in `ffi_names`.

## Named NATIVE assumptions
N-FFI-ARGS (MISSING; write success MACHINE-CHECKED U400), A-FD0-READ, A-FD1-WRITE (refined: a write may FAIL; safety then
rests on prefix-freeness + strict parse), A-SIG, A-NOSTDIO-FD1, A-EXIT, A-LOADER (new, MISSING), A-ENV-HEAP.
