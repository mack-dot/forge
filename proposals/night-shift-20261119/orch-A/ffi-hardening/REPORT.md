# A23 FFI hardening packet (condensed by Orchestrator A; digests of patch, patched image and rebuilt original re-checked by A)
- REPRODUCIBILITY: with the recorded commands (same clang, ld, SDK digests) the ORIGINAL `basis_ffi.o`, `refund.o` and the
  image rebuild byte-exactly: `orig-rebuild/refund` SHA-256 b8ed5ec2…7bb8 (A: `shasum` exit 0).
- Model vs C differences (original C): error byte in the model vs abort in C (read/write clen ≠ 8, short array; open_in
  1 ≤ alen < 9); descriptor truncated to 32 bits in C (conf 2^32 reads stdin; 2^32+1 writes stdout: unit cases R09, W06);
  close of fd 0/1/2 really closes in C (model: error byte); at alen = 0 (and read/write alen < 4) the MODEL's oracle FAILS
  (FFI_failed: the run halts) — it does not return. So U393 still falsifies the all-states premise after any patch.
- Patch `basis_ffi_model_total.patch` (ea344ad0…f357; UNAPPLIED to the toolchain): error byte where the model returns one;
  halt where the model's oracle fails; unsigned lengths; full 64-bit descriptor decode. Unit comparison against a
  transcription of the model: patched C agrees in 47 of 48 cases (original: 24); the one left: open_in of a real file.
- Patched image `patched/refund-model-total` (ba89fef3…c89): byte-identical behaviour on 2,684 vectors and 15 native tests;
  CakeML code slice, entry stub, `__DATA` byte-identical at the same addresses; 6 stub branch words, C text, GOT, header move.
- Decision recorded as OWNER_REQUIRED A-3. All of this: TESTED-UNPROVED.
