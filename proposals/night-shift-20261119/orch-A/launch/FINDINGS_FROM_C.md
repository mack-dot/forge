# Findings on launcher.py from the red team (2026-11-19T15:51:36Z); static, from C's worker, NOT independently run; C itself could not read the file
- F1 (HIGH if true): the launcher does not reset its OWN SIGCHLD. A caller that starts it with SIGCHLD = SIG_IGN makes the
  kernel reap the child; CPython `subprocess` then reports return code 0; the signal and exit-code checks never fire.
- F2: the CDHash check binds the image of the pid at the check instant, not the exec'd image (needs a same-uid writer;
  out of the stated scope; the row wording "binds the exec'd image" is too strong).
- F3: the request write has no deadline (availability).
State: TO CHECK by A (reading and one probe through the author's test harness). Rows AC1, AC3-i and every row that
rests on the exit status are NOT to be called CLOSED until F1 is settled.

## Update 2026-11-19T16:15:20Z: C-LAUNCH-01 (RUN by C; not re-run by A)
C ran `orch-C/c22-launch-conformance/test_process_lifecycle.py` (b2e9ec8ecc16…) against launcher.py (v1): exit 1; 24 tests,
22 ok, 2 FAIL: with SIGCHLD ignored, a child that wrote the full frame and then aborted or exited 3 is AUTHORIZED.
Agrees with review F-01 and the author's in-process probe. Repaired in launcher_v2.py (author's tests; A re-ran, exit 0).
C's file has NOT been run against launcher_v2.py (v2 refuses `pinned_cdhash=None`, which C's test child uses).

## Update 2026-11-19T16:17:29Z: C re-ran its conformance file on both versions (C's runs; not re-run by A)
Test file d5ceda71d243… (changed by C for the image check). launcher.py: exit 1 twice (24 tests, the same 2 FAIL).
launcher_v2.py: exit 0 twice (24 tests OK; with SIGCHLD ignored it refuses with "V2 child status unknown (ECHILD)").
So the process-lifecycle rows (prefix, extra byte, non-zero exit, signal, time-out, stderr, overflow, empty child
environment, SIGCHLD ignored) now have ONE independent conformance run, with a /bin/bash test child. NOT covered by
any independent run: the real refund program, injected code at load, a wrong image hash, the FFI C code.
The column "independent attack run: none" in CONTROL_MATRIX_v2.md is stale for those lifecycle rows only.
