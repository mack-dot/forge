# CONTROL_MATRIX: launch-path controls for the M1 refund executable (worker W-launch, 2026-11-19)

Executable: `orch-A/ffi-c-audit/refund`, SHA-256 `b8ed5ec2…7bb8`, CDHash `7c0eef46…4229d` (read and executed only;
never changed). Control: `launch/launcher.py` (prototype, unverified Python). No HOL, no Dafny, no git, no network.
Class of every row: TESTED-UNPROVED at best. "Tested" is not "proved". Every test here was run by the author of the
control. **Independent attack run: none for every row** (the red team cannot run them).

States: **CLOSED-BY-ENFORCED-CONTROL (tested)** = an enforced launcher step removes the attack, and a test shows the
attack succeeds on a naive consumer (or on a mutant launcher) and fails through the launcher.
**OPEN** = no enforced control, reason given. **OWNER-OPTION** = a fix exists that only the owner can adopt.

Test exit codes (actual, `commands.txt`): `test_ac1.py` 0 (6 rows), `test_ac2.py` 0 (18 rows), `test_ac3.py` 0 (9 rows),
`test_positive_and_mutants.py` 0 (10 positive controls equal to the direct run, 5 mutants). 0 rows not as expected.

## 1. Matrix

| Row | Class / sub-case | X8 v2 premise violated | Control (launcher step) | Naive result (attack) | Launcher result | Test file | Exit | Independent attack run | State |
|---|---|---|---|---|---|---|---|---|---|
| AC1-a | exit 0, stdout prefix 1000/4044 B (CE-1, non-blocking full stdout) | N11, N21, N22 | L4 fresh blocking pipe; L9 drain to EOF; D7 | naive_exit: COMPLETE | AUTHORIZED(40) = honest (CLI's own stdout was the hostile pipe) | tests/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC1-b | exit 0, empty stdout, stdin closed (CE-2) | N09, N20 | L4 fresh stdin pipe; L8 | naive_exit: COMPLETE, 0 B | AUTHORIZED(40) = honest | tests/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC1-c | exit 0, stdout closed (CE-2) | N11, N22 | L4; CLI exits 4 when its own fd 1 is closed | naive_exit: COMPLETE | CLI rc 4, no line → consumer REFUSED | tests/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC1-d | real process: exit 0 + strict prefix | decision rule (X8 C5) | D7 | naive_exit: COMPLETE | REFUSED D7 | tests/test_ac1.py; MUT-3 | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC1-e | real process: exit 0 + empty | decision rule | D6 | naive_exit: COMPLETE | REFUSED D6 | tests/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC1-f | 49 planted: all strict prefixes, frame+LF, frame+space, two frames | decision rule | D5–D7 | COMPLETE 49/49 | 0/49 not refused | tests/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested; finite) |
| AC2-a | DYLD_INSERT_LIBRARIES, fixed forged frame (CE-3) | N15 | L4 empty env; L0 | naive_parse: AUTHORIZED(999) | AUTHORIZED(40) = honest; L0 refuses visible DYLD_* | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-b | DYLD_INSERT adaptive forger vs full D0–D12 echo check | N15 | L4 empty env (echo check alone does NOT stop it) | naive_echo: REJECT → AUTHORIZED(400) | NOT_AUTHORIZED = honest | tests/test_ac2.py; MUT-1 | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-c/d | DYLD_LIBRARY_PATH / DYLD_FALLBACK_LIBRARY_PATH, fake libSystem | N15 | L4 empty env | no effect observed (shared cache) | honest | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (by construction; the attack did not succeed even on naive, so no failing side) |
| AC2-e | DYLD_PRINT_LIBRARIES (dyld honours DYLD_* here) | N15 | L4; D4 | 7232 B stderr; naive_parse still decides | honest | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-f | CML_HEAP_SIZE=1 in caller env | N15 | L4 empty env | no effect observed (full output) | honest | tests/test_ac2.py | 0 | none | recorded; no failing side |
| AC2-g | hardened-runtime COPY (`codesign -s - -o runtime`) + DYLD_INSERT | N15 | dyld ignores DYLD_* for it; launcher refuses copy (digest) | naive_echo: NOT_AUTHORIZED (injection ignored) | REFUSED L2 | tests/test_ac2.py; static/dyld_hr_*.log | 0 | none | OWNER-OPTION (new bytes 1b78c1e2…, new CDHash 341d62cd…, new pin; second barrier only) |
| AC2-h | replaced binary at the path | N16, N17 | L2 SHA-256 of bytes read once | naive_echo: AUTHORIZED(400) | REFUSED L2 | tests/test_ac2.py; MUT-2 | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-i | symlink at the path → fake | N16, N17 | L1 O_NOFOLLOW (+ L2) | naive_echo: AUTHORIZED(400) | REFUSED L1 | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-j | symlink → genuine file | none | L1 policy | – | REFUSED L1 (false refusal by design) | tests/test_ac2.py | 0 | none | recorded (availability cost) |
| AC2-k | PATH points to a fake | N16, N17 | L1 absolute path only; L4 argv[0] = private copy | naive_echo: AUTHORIZED(400) | REFUSED L1 | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-l | attacker cwd + relative path | N16, N17 | L1; L4 cwd = private dir | naive_echo: AUTHORIZED(400) | REFUSED L1; CLI from that cwd with abs path: honest | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-m | image at exec ≠ checked bytes (TOCTOU; simulated swap) | N16, N17 | L3 private copy from the hashed memory bytes; L6+L7 kernel CDHash of the RUNNING process checked before any input | MUT-4: AUTHORIZED(400) | REFUSED L7 | tests/test_ac2.py; MUT-4 | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested; simulated, a real race was not produced). Residual: CDHash is 160-bit truncated SHA-256 over the code directory, not the file SHA-256 |
| AC2-o | inherited file descriptors in the caller | N09, N11, N21 | L4 close_fds; fresh pipes | probe: extra fds 3, 4 | probe: only 0,1,2 fifo, blocking | tests/test_ac3.py AC3-a | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC2-n1 | DYLD_INSERT in the caller env of the LAUNCHER via `/usr/bin/python3` | launcher integrity | the shim (platform binary) prunes DYLD_* | – | honest | tests/test_ac2.py | 0 | none | CLOSED (by OS behaviour, observed once; not a launcher control) |
| AC2-n2 | DYLD_INSERT into the framework `python3.9` (no hardened runtime) | launcher integrity | none inside launcher | forged frame instead of a decision line | consumer: REFUSED (no line); an adaptive forger could print a valid line | tests/test_ac2.py | 0 | none | OPEN: the interpreter is not hardened |
| AC2-n3 | DEVELOPER_DIR redirects `/usr/bin/python3` to an attacker python | launcher integrity | none inside launcher | forged decision line | consumer ACCEPTS AUTHORIZED(400) | tests/test_ac2.py | 0 | none | **OPEN**: the consumer must start the launcher as `/usr/bin/env -i /usr/bin/python3 -B -I <abs>/launcher.py` |
| AC2-n4/n5 | same attacks under `/usr/bin/env -i` | launcher integrity | consumer invocation rule | – | honest | tests/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) only if the consumer follows the rule |
| AC3-a | launch state: env, cwd, fds, O_NONBLOCK, signal mask, dispositions | N09, N11, N14, N15, N21 | L4 + _child_setup | probe: env 2, DYLD var, nonblock fd 1, blocked 14,28,30, non-default 13,15,25 | probe: env 0, fds 0–2 blocking fifo, mask empty, all SIG_DFL, core 0 | tests/test_ac3.py; MUT-5 | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC3-b | read error: stdin a directory | N09, N10 | L4 | naive_exit: COMPLETE, 0 B | honest | tests/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (state excluded; tested via AC3-a) |
| AC3-c | write error: stdout read-only | N11, N12 | L4 | naive_exit: COMPLETE, 0 B | honest | tests/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (state excluded) |
| AC3-d | EAGAIN: non-blocking stdin; short reads (1-byte feed) | N09, N10 | L4 blocking pipe | naive_exit: COMPLETE, 0 B | honest with every read short | tests/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested) |
| AC3-e | EPIPE with inherited SIGPIPE SIG_IGN | N11, N14 | L4 SIG_DFL; L9 reader open to EOF | naive_exit: COMPLETE | not run through launcher (state cannot arise; AC3-a shows SIG_DFL) | tests/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (by construction + AC3-a; no direct launcher run) |
| AC3-f | EPIPE with SIGPIPE default | N11 | same | signal 13 (safe) | – | tests/test_ac3.py | 0 | none | recorded (safe direction) |
| AC3-g | EINTR: SIGWINCH, SIGURG, SIGCHLD, SIGINFO, SIGIO, SIGCONT, STOP/CONT while blocked in read | N14, N10 | L4 SIG_DFL, no handler in program | – | honest (1 run) | tests/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (tested once; argument: no handler ⇒ no EINTR) |
| AC3-h | partial writes (4044 B output, PIPE_BUF 512) | N11, N12, N22 | L9 | – | honest | tests/test_ac3.py | 0 | none | tested (positive) |
| AC3-i | C abort (shape of clen ≠ 8 / short array) | N07, N10/N12 | D2 | FAILED sig 6 (safe) | REFUSED D2 | tests/test_ac3.py | 0 | none | CLOSED (safe already; launcher refuses) |
| AC3-j | C misreport at states the launcher cannot reach: clen ≠ 8, short array, 32-bit fd cut, close of fd 0–2 | N07, N10, N12 (+R6) | none (arguments come from the compiled code) | not run | not run | – | NOT RUN | none | OPEN: model gap R6; OWNER-OPTION `basis_ffi_model_total.patch` (A-3) |
| AC3-k | signals from another process of the same user (SIGKILL/SIGTERM mid-write) | N13 | D1/D2 refuse a killed run | not run | not run | – | NOT RUN | none | OPEN (out of scope adversary; N13 stays ASSUMPTION) |
| T-1 | caller-chosen resource limits (RLIMIT_NOFILE, CPU, STACK, DATA) | N16 | only RLIMIT_CORE set | not run | not run | – | NOT RUN | none | OPEN (not tested; expected safe direction only) |
| T-2 | time-of-check gap on the private copy (same-uid writer between L3 and exec) | N16, N17 | L7 detects a different image; L11 re-hash | simulated only (AC2-m) | – | tests/test_ac2.py | 0 | none | residual: a same-uid writer is out of scope |
| T-3 | the launcher itself (unverified Python, CPython 3.9.6, libSystem, csops) | all ENFORCED rows | none | – | – | – | – | none | OPEN: trusted, not proved |
| T-4 | launcher → consumer channel (decision line + exit code) | – | consumer rule `parse_decision_line` + code match | – | – | tests/common.py | – | none | OPEN: whoever controls the launcher's stdout can forge the line (AC2-n3) |

## 2. Native assumptions N09..N22 (X8 v2) under this launcher

| N | X8 v2 class | Under launcher.py | How |
|---|---|---|---|
| N09 A-FD0-SETUP | ENFORCED-BY-LAUNCHER | ENFORCED (tested AC3-a, AC1-b, AC3-d) | subprocess pipe, blocking; parent sole writer; closed after the request |
| N10 A-FD0-SEM | ASSUMPTION | not enforceable | kernel/C semantics; short reads tested once (AC3-d) |
| N11 A-FD1-SETUP | ENFORCED-BY-LAUNCHER | ENFORCED (AC3-a, AC1-a) | fresh blocking pipe; drained to EOF; SIGPIPE SIG_DFL; mask empty; stderr separate |
| N12 A-FD1-SEM | ASSUMPTION | not enforceable | kernel/C semantics |
| N13 A-FD1-PARTIAL | ASSUMPTION | not enforceable | killed run → D1/D2 REFUSED, so a cut never decides |
| N14 A-SIG-DFL | ENFORCED-BY-LAUNCHER | ENFORCED (AC3-a, MUT-5) | _child_setup: all dispositions SIG_DFL, mask empty; new session (no terminal signals) |
| N15 A-LOADER | ENFORCED-BY-LAUNCHER | ENFORCED for the child (AC2-a/b, MUT-1); NOT for the launcher's own interpreter (AC2-n2/n3) | env = {}; L0 check; consumer must use `env -i` |
| N16 A-ENTRY | ASSUMPTION | partly: the image is the pinned one (L2, L7); dyld/_main/malloc state not enforced | – |
| N17 A-IMG-STABLE | ASSUMPTION | partly: L7 CS_VALID + CDHash at start (kernel then validates pages) | page-level enforcement is the kernel's |
| N18 A-NO-SHARED | ASSUMPTION | not enforced | – |
| N19 A-NO-DEBUGGER | ASSUMPTION | not enforced (same-uid task port; no PT_DENY_ATTACH) | – |
| N20 A-ENTRY-STDIN | ENFORCED-BY-LAUNCHER | ENFORCED | the launcher writes exactly `wire(fields)` and closes |
| N21 A-STDOUT-EMPTY | ENFORCED-BY-LAUNCHER | ENFORCED | fresh pipe; only the child holds the write end (close_fds; parent's copy closed by subprocess) |
| N22 A-OUT-DELIVER | ENFORCED-BY-LAUNCHER | ENFORCED (read to EOF, bound+1 kept, overflow → D5) | no byte count against the child's writes (not observable) |

## 3. Adversary scope

In scope (caller's environment): DYLD_* and other variables, PATH, cwd, relative or symlinked paths, a replaced file at
the path, inherited fds, closed or non-blocking stdio, ignored or blocked signals, DEVELOPER_DIR.
OUT of scope: anyone who can replace `launcher.py`, the Python interpreter, libSystem or the OS; anyone with the
user's privileges during or after exec (same-uid writer, debugger, task port, kill); root. Consequence: the gaps
T-2, AC3-k, N18, N19 are recorded, not closed.

## 4. Doubts

- csops CDHash binds the code directory (20-byte truncated SHA-256), not the file SHA-256; L2 binds the source bytes.
- AC2-c/d/f: "no effect observed" for one library and one value; not a proof that those variables are harmless.
- AC3-g: one run. AC2-m: a simulated swap, not a real race.
- Hardened-runtime copy: only "DYLD_INSERT_LIBRARIES is ignored" was measured; library validation was not measured
  separately. The copy stays in `launch/hr/` (re-signed COPY; the original was not touched).
- The CDHash pin was read from `codesign -dv` output; a second independent read of it was not made.
