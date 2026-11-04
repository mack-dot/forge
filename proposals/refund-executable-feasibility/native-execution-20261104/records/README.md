# Native artifact preparation

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
This directory contains prepared downstream steps. No native refund link,
signature, extraction or execution has run here.

Actual checks: Python parsing returned0 for `link_native.py` and `run_native.py`.
See `preparation-final.json` for the checked source hashes. The SML extraction
has not run. Neither syntax checks nor prepared code establish behavior.

The original Forge task owns the running compiler invocation at
`../../refund-arm8-compile-2026-11-04/attempt-0001/compile-0001/`.
Its source isb7e12fcf; it targets the checked `refund_prog_def`. That task owns
session60920. This task cannot poll that handle: its read-only poll returned
`Unknown process id 60920`. This is a session-visibility failure, not evidence
that the compiler stopped. The invocation must not be restarted from that error.

The prepared link step requires a successful terminal compiler record and exact
assembly/theory hashes. It binds the prior runtime objects, clang, linker and
SDKSettings hashes. It records the clang driver's linker plan, performs two
local links, verifies the ad hoc signatures, and compares complete executable
hashes. U269 authorizes only this local Apple arm64 signature. The step has not
run, and no reproduction result is inferred.

The prepared execution step checks every frozen wire-file hash. It supplies the
28 inputs through closed stdin pipes and records exact stdout/stderr and process
status. Test resource settings are256MiB heap and256MiB stack. These are test
conditions, not new source preconditions or a proved sufficient memory bound.
The22 typed cases compare complete expected output and test exit0. The six
malformed cases record output observations; their complete native error and
exit-status contract stays INCOMPLETE even when no output is observed. Every
result keeps `end_to_end=false`.

`extract_compiled.sml` uses the existing HOL evaluator and syntax libraries to
materialize code bytes and bitmap numerals from the compiled theory. It must run
only after that exact theory succeeds. These values still need comparison with
the final executable through established artifact tools. An object-file hash
alone does not discharge installed memory, loader, FFI or real OS I/O premises.

Next command, **NOT RUN**, after the compiler record reports actual exit0:

```text
python3 -B results/refund-native-audit-2026-11-04/attempt-0004/link_native.py /Users/mackianni/forge/results/refund-arm8-compile-2026-11-04/attempt-0001/compile-0001
```

All actions create new result directories. Existing compiler and proof failures
remain preserved. A failed link or reproduction must be diagnosed before another
attempt. No release signing, publication, deployment or protected change is
authorized by this preparation.
