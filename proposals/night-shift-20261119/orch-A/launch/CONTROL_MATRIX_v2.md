# CONTROL_MATRIX_v2: launch-path controls, round 2 (worker W-launch, 2026-11-19)

Applies review_launcher.txt (F-01..F-16) and FINDINGS_FROM_C.md (F1..F3). CONTROL_MATRIX.md (round 1) is unchanged.
Control: `launcher_v2.py` (prototype, UNVERIFIED Python). `launcher.py` (v1) is unchanged and is the failing side.
Executable: `ffi-c-audit/refund` SHA-256 `b8ed5ec2…7bb8`, CDHash `7c0eef46…4229d` (read and executed only).
Every result is TESTED-UNPROVED. The author of the control ran every test. **Independent attack run: none, for every row.**

States:
- CLOSED-BY-ENFORCED-CONTROL (tested): the attack succeeds on v1, a naive consumer or a mutant, and fails on v2.
- NO-FAILING-SIDE: the attack did not succeed on any side, so the test cannot show that the control matters.
- EXCLUDED-BY-CONSTRUCTION: the launcher cannot be given the hostile state; there is a positive control only.
- OPEN: the reason is given in the row.
- OWNER-OPTION: only the owner can adopt the fix.

Actual exit codes (`commands.txt`):

| Test | Exit | Notes |
|---|---|---|
| `tests_v2/test_v2_findings.py` | 0 | 16 rows. The first two runs exited 1 because of test defects: a wrong `ulimit` order, and a 7 s bound that 1 MB rendering exceeded. |
| `tests_v2/test_mutants_v2.py` | 0 | 4 mutants. The first run exited 1: the MUT-2v2 mutant did not also remove L11. |
| Old suite (copied to `tests_v2/old/`, launcher path set by a parameter), against v1 | 0, 0, 0, 0 | |
| Old suite against v2: `test_ac1`, `test_ac2`, `test_ac3` | 0, 0, 0 | |
| Old suite against v2: `test_positive_and_mutants` | **1** | 10 of 10 positive rows are equal. MUT-1 and MUT-3 are OK. MUT-2 and MUT-4 used the `pinned_cdhash=None` bypass that v2 removed (F-08), so MUT-2 changes outcome and MUT-4 raises `V5`. `test_mutants_v2.py` replaces them. |
| `tests_v2/f01_probe_v1.sh` | 0 | |
| `tests_v2/f01_probe_inproc.sh` | 0 | |

Orchestrator A ran `recheck-A/` (round 1, exit 0 ×4, 15:43Z). It is recorded in `commands.txt`.

## F-01 probe on the UNCHANGED launcher.py (actual)

| Caller state | fake = exact accept frame, then exit 7 | fake = exact accept frame, then abort |
|---|---|---|
| none | REFUSED D3 | REFUSED D2 (signal 6) |
| caller `SIG_IGN`, then exec `env -i python3 … launcher.py` (driver sees SIG_IGN) | **REFUSED D3** | **REFUSED D2** |
| caller `SA_NOCLDWAIT` (ctypes), then exec | REFUSED D3 | REFUSED D2 |
| `SIG_IGN` set INSIDE the launcher process (measurement) | **AUTHORIZED(40)** | **AUTHORIZED(40)** |
| `SA_NOCLDWAIT` set INSIDE the launcher process (measurement) | **AUTHORIZED(40)** | **AUTHORIZED(40)** |

Reading:
- The defect is real in the code. XNU auto-reaps, and CPython then invents status 0.
- The CALLER-exec route did not reproduce on this macOS: 4 of 4 runs refused, although `SIG_IGN` was inherited.
- My guess, NOT verified: exec keeps the disposition but not the auto-reap flag.

## 1. Matrix

| Row | Class / sub-case | Review finding | X8 v2 premise | Control in v2 | Failing side (actual) | v2 result | Test | Exit | Independent attack run | State |
|---|---|---|---|---|---|---|---|---|---|---|
| AC1-a | CE-1: non-blocking full stdout given to the child | F-09 | N11, N21, N22 | L4 fresh blocking pipe; L9 drain to EOF; D7 | naive_exit: COMPLETE with 1000 of 4044 B | honest decision | tests_v2/old/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (child side). The launcher's own EAGAIN write path was exercised (F-09 row, 0 bytes free): line complete for v1 and v2, no failing side. |
| AC1-b | CE-2: stdin closed | – | N09, N20 | L4 | naive_exit: COMPLETE, 0 B | honest decision | old/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC1-c | CE-2: stdout closed | – | N11, N22 | CLI exit 4 | naive_exit: COMPLETE | rc 4, no line | old/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC1-d/e | real process: exit 0 with a prefix / with empty output | F-01 | decision rule | D6/D7; V2 own wait | naive_exit: COMPLETE; MUT-3 | REFUSED D7 / D6 | old/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC1-f | 49 planted prefixes and suffixes | – | D5–D7 | D5–D7 | COMPLETE 49/49 | 0/49 accepted | old/test_ac1.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (finite) |
| AC2-a | CE-3: DYLD_INSERT with a fixed frame | F-10 | N15 | L4 empty env (L0 is NOT counted as a control) | naive_parse: AUTHORIZED(999); MUT-1 | honest decision | old/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (child) |
| AC2-b | CE-3: adaptive forger against the echo check | F-12 | N15 | L4 empty env | naive_echo: REJECT becomes AUTHORIZED(400) | NOT_AUTHORIZED | old/test_ac2.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC2-c/d | DYLD_LIBRARY_PATH / DYLD_FALLBACK_LIBRARY_PATH | F-06 | N15 | L4 | none (no effect, even on naive) | honest decision | old/test_ac2.py | 0 | none | NO-FAILING-SIDE |
| AC2-e | DYLD_PRINT_LIBRARIES (stderr noise) | F-06 | N15 | L4; D4 | naive_parse gave the honest decision | honest decision | old/test_ac2.py | 0 | none | NO-FAILING-SIDE |
| AC2-f | CML_HEAP_SIZE=1 in the caller env | F-14 | N15, N16 | L4 | none observed | honest decision | old/test_ac2.py | 0 | none | NO-FAILING-SIDE. N16 values: in which environment they were measured is UNSURE (F-14). |
| AC2-g | hardened-runtime COPY | – | N15 | (re-sign: owner) | DYLD ignored on the copy | REFUSED L2 (new digest) | old/test_ac2.py | 0 | none | OWNER-OPTION |
| AC2-h/i/k/l | replaced binary, symlink, PATH, cwd | – | N16, N17 | L1, L2 | naive_echo: AUTHORIZED(400); MUT-2v2 | REFUSED L1/L2 | old/test_ac2.py; test_mutants_v2.py | 0; 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC2-j | symlink to the genuine file | – | – | L1 policy | – | REFUSED L1 | old/test_ac2.py | 0 | none | recorded: a false refusal by design |
| AC2-m | file at the caller path changes (TOCTOU) | F-04, C-F2 | N16, N17 | L2+L3: bytes read once; the copy is written from the same memory | – | – | – | – | none | CLOSED BY CONSTRUCTION (by reading; no race test) |
| AC2-m' | private copy differs at exec | F-04, C-F2 | N16, N17 | L7: csops CDHash of the pid at the check instant, before any input | MUT-4v2: AUTHORIZED(400) | REFUSED L7 | old/test_ac2.py; test_mutants_v2.py | 0; 0 | none | Defence-in-depth, SIMULATED (a different binary, no race). L7 binds the image at the check instant, not later pages. A same-uid race and a post-exec page change are OPEN (= T-2). |
| AC2-o | inherited caller fds | F-09 | N09, N11, N21 | close_fds | naive probe: extra fds 3, 4 | probe: fds 0–2 only | old/test_ac3.py AC3-a | 0 | none | CLOSED-BY-ENFORCED-CONTROL for the naive side. No launcher mutant for close_fds (F-09). |
| AC2-n1 | shim + DYLD_INSERT | – | launcher integrity | the OS prunes DYLD_* (shim) | none | honest decision | old/test_ac2.py | 0 | none | NO-FAILING-SIDE (OS behaviour) |
| AC2-n2 | framework python3.9 + DYLD_INSERT | – | launcher integrity | none | forged output | consumer refuses (no line) | old/test_ac2.py | 0 | none | OPEN (interpreter not hardened) |
| AC2-n3 | DEVELOPER_DIR redirects `/usr/bin/python3` | F-05 | launcher integrity | none | forged decision line ACCEPTED | – | old/test_ac2.py | 0 | none | OPEN |
| AC2-n4/n5 | the same attacks under `env -i` | F-05 | launcher integrity | consumer duty, enforced by no code | – | honest decision | old/test_ac2.py | 0 | none | **OPEN** (consumer obligation, see §3) |
| AC3-a | child launch state | F-09 | N09, N11, N14, N15, N21 | L4, _child_setup, V6 | naive probe: hostile state; MUT-5 (v1 run only; the v2 old-suite run stopped at MUT-4 before MUT-5); MUT-7v2 | probe2: env 0; fds 0–2 blocking FIFOs; mask empty; all SIG_DFL; own session (sid = pgid = pid); no controlling tty; rlimits CORE 0, STACK 8 MiB, FSIZE 0, CPU 10, NOFILE 64; task exception ports 0 | old/test_ac3.py; test_v2_findings.py; test_mutants_v2.py | 0; 0; 0 | none | CLOSED-BY-ENFORCED-CONTROL for the items listed. umask is inherited (022 seen; no effect found). DATA rlimit is not fixed. |
| AC3-b/c | read error (stdin a directory) / write error (stdout read-only) | F-06 | N09–N12 | L4 | naive_exit: COMPLETE, 0 B | positive control only | old/test_ac3.py | 0 | none | EXCLUDED-BY-CONSTRUCTION (positive control only) |
| AC3-d | EAGAIN on stdin; 1-byte feed | – | N09, N10 | L4 | naive_exit: COMPLETE, 0 B | honest decision | old/test_ac3.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| AC3-e | EPIPE with SIGPIPE ignored | F-06 | N11, N14 | L4, L9 | naive_exit: COMPLETE | not run through the launcher | old/test_ac3.py | 0 | none | EXCLUDED-BY-CONSTRUCTION (positive control only) |
| AC3-g | signals while the child is blocked in read | F-06 | N14 | L4 | – | honest decision (1 run) | old/test_ac3.py | 0 | none | NO-FAILING-SIDE (tested once, positive) |
| AC3-h | partial writes, 4044 B output | F-02 | N11, N12, N22 | L9 | – | honest decision | old/test_ac3.py | 0 | none | positive; only for requests below MAX_REQUEST_BYTES |
| AC3-i | C abort | F-01 | N07 | D2 + V2 own wait | – | REFUSED D2 | old/test_ac3.py; test_v2_findings.py | 0; 0 | none | CLOSED: with v2 also when SIGCHLD is ignored in the launcher (F-01 rows) |
| AC3-j | C misreport at states the launcher cannot reach | – | N07, N10, N12, R6 | none | not run | not run | – | NOT RUN | none | OPEN (R6); OWNER-OPTION (C patch, A-3) |
| AC3-k | same-uid signals or kill mid-write | – | N13 | D1/D2 | not run | not run | – | NOT RUN | none | OPEN (adversary out of scope) |
| NEW-1 | SIGCHLD SIG_IGN / SA_NOCLDWAIT in the launcher (status invented) | F-01, C-F1 | D2/D3 premise | V0 reset with read-back; V2 own `wait4`; ECHILD = REFUSED | v1 in-process: AUTHORIZED(40) in 4 of 4; MUT-6v2 | REFUSED D3/D2 in 4 of 4 | test_v2_findings.py; test_mutants_v2.py | 0; 0 | none | CLOSED-BY-ENFORCED-CONTROL (in-process route). The caller-exec route was NOT reproduced (v1 refused 4 of 4): NO-FAILING-SIDE for that route. |
| NEW-2 | FIFO at `--exe` | F-02 | – | V3: O_NONBLOCK open + S_ISREG | v1: HANG (6 s outer time-out) | REFUSED L2 | test_v2_findings.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| NEW-3 | large request with a child that does not read | F-02, C-F3 | N20 | V4: non-blocking write under the deadline; size bound 1 MiB | v1: HANG (9 s outer time-out) | REFUSED D1 (< 9 s wall; 5 s process limit + rendering) | test_v2_findings.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL. The rendering and copy phases are CPU-bound, with no deadline. |
| NEW-4 | request above 1 MiB | F-02 | – | V4 bound | (new) | REFUSED V4 | test_v2_findings.py | 0 | none | recorded: a false refusal by design |
| NEW-5 | EPIPE on the request write | F-07, F-08 | N20 | V4: EPIPE or short total = REFUSED; every write counted | v1: AUTHORIZED(40) | REFUSED V4 | test_v2_findings.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL. A short-write count error is fixed by reading only (not provoked). |
| NEW-6 | `pinned_cdhash=None` skips L7 | F-08 | N16, N17 | V5 | v1: AUTHORIZED(40) for a fake | REFUSED V5 | test_v2_findings.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL. Test hooks (feed_chunk, on_blocked, check_self) remain in the API: T-3. |
| NEW-7 | inherited Mach task exception ports | F-03 | N19 | V1: task_set_exception_ports(self, ALL\|CRASH\|CORPSE_NOTIFY, NULL) at start; the child inherits null ports | v1 child: masks 0xc00, 0x2000 present (also in a plain exec in this session; origin unknown). The CALLER-set masks (0x66) did NOT reach any exec'd image (3 of 3 routes). | v2 child: 0 ports | test_v2_findings.py; tests_v2/f03_excport_direct.log | 0 | none | NO-FAILING-SIDE for the caller-attack route (not reproduced). V1 removes the inherited ports (tested). Thread and host ports are not touched. Effect on crash reporting is UNSURE. |
| NEW-8 | caller rlimits (soft) | T-1, F-03 | N16 | V6 fixed values | v1 child: nofile 32, stack 1 MiB, cpu 3; MUT-7v2 | fixed values | test_v2_findings.py; test_mutants_v2.py | 0; 0 | none | CLOSED-BY-ENFORCED-CONTROL |
| NEW-9 | caller HARD nofile 32 | T-1 | – | V6: setrlimit fails, so REFUSED | v1: AUTHORIZED (honest) | REFUSED D12 | test_v2_findings.py | 0 | none | recorded: a false refusal by design; no failing side |
| NEW-10 | launcher gets SIGTERM | F-13 | – | V7 handler: kill the group, reap, remove the copy | v1: copy dir left | no dir left; child gone | test_v2_findings.py | 0 | none | CLOSED-BY-ENFORCED-CONTROL (cleanup) |
| NEW-11 | launcher gets SIGKILL | F-13 | – | none possible | copy dir left (v1, v2) | copy dir left; child gone after 0.5 s (EOF on stdin) | test_v2_findings.py | 0 | none | OPEN (cleanup only; fail-safe: no decision line) |
| NEW-12 | `site` / .pth code before the launcher | F-11 | launcher integrity | `-S` in the invocation rule (consumer duty) | with `-I`: site-packages is on sys.path; `distutils-precedence.pth` exists | `-I -S`: no site-packages; `site` not imported | tests_v2/f11_syspath.log | 0 | none | OPEN (consumer duty) |
| T-2 | same-uid writer between L3 and exec | F-04 | N16, N17 | L7 at the check instant | – | – | – | – | none | OPEN (out of scope) |
| T-3 | launcher_v2.py itself; CPython 3.9.6; libSystem; csops; ctypes struct layouts | F-08, F-11 | all ENFORCED rows | none | – | – | – | – | none | OPEN (trusted, not proved). New ctypes calls: sigaction layout, mach_task_self_, task_set_exception_ports. |
| T-4 | launcher-to-consumer channel | F-12 | – | the line carries request_sha256 | AC2-n3 | – | – | – | none | OPEN |

## 2. Native assumptions N09..N22 under launcher_v2.py

| N | Under v2 |
|---|---|
| N09 | ENFORCED (fresh blocking pipe for the child; only the parent's end is O_NONBLOCK) |
| N10 | ASSUMPTION |
| N11 | ENFORCED |
| N12 | ASSUMPTION |
| N13 | ASSUMPTION. A killed run is REFUSED. |
| N14 | ENFORCED in the CHILD (all SIG_DFL, empty mask). The launcher's own SIGCHLD is reset and checked (V0). |
| N15 | ENFORCED for the child. For the launcher's interpreter it is a consumer duty (OPEN). |
| N16 | Partly. The image is the pinned one (L2, L7). The rlimits are fixed (V6). The environment of the N16 measurements is UNSURE (F-14). |
| N17 | Partly. CDHash and CS_VALID are checked once, before input. CS_VALID is not re-checked. CS_KILL/CS_HARD are not required (ad hoc signed). |
| N18 | ASSUMPTION |
| N19 | ASSUMPTION. Task exception ports are reset to null (V1). Thread and host ports, debuggers and task ports of the same uid are not covered. |
| N20 | ENFORCED: every byte is counted, and EPIPE or a short total is REFUSED. The frame binds 4 of 9 fields (charge, request, amount, reason). original, remaining, enabled, opened and candidate are bound only by N20; request_sha256 is in the line. |
| N21 | ENFORCED |
| N22 | ENFORCED: read to EOF, bound+1 kept. ASSUMPTION: no libSystem exit flush to fd 1 (F-15). |

## 3. Consumer duties (no code enforces them)

1. Start the launcher as `/usr/bin/env -i /usr/bin/python3 -B -I -S /ABS/launcher_v2.py …`, from a trusted process.
2. Own the launcher's stdout pipe, and require one full line plus the matching exit code.
3. Check that request_sha256 matches the request bytes it intended.
4. Keep its own time-out on the launcher.
5. Do not run the launcher under a debugger.

## 4. Doubts

- F-01: I do not know why the caller-exec route did not auto-reap. One run per case.
- F-03: the origin of the ports 0xc00 and 0x2000 is unknown. Clearing EXC_CRASH or CORPSE_NOTIFY ports may affect crash reporting. I sent no exception message.
- V6 FSIZE 0 is safe for pipes (positive controls pass). A program that writes a file would get SIGXFSZ.
- Rendering a 1 MiB request costs about 2 s before the process deadline starts.
