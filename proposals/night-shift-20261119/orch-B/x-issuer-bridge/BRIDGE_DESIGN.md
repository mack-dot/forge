# Issuer bridge: make the M1 native result load-bearing for issuance (task x-issuer-bridge)

Status: DESIGN + reference code + finite tests. Nothing is applied. M1-B stays OPEN. `end_to_end=false`.
Classes: MACHINE-CHECKED / ASSUMPTION / TESTED-UNPROVED / MISSING. Every test here is TESTED-UNPROVED.

## 1. The change (smallest form)

Today `minter.ts` signs when the compiled `RefundFinality.Check` returns `Issue` (ledger U2). The native
executable decides nothing (X15, X16 MISSING). The bridge adds ONE conjunct before `sign(...)`:

    sign  <=>  Check(pre, hash, t) = Issue(token)                         (a) unchanged
          AND  Bridge(inRange(x), fields(token, plan), launch(x), strictParse(stdout)) = Sign   (b) new

`x` = the flat inputs of `Check` (below). Order inside the issuer process: shape check -> `Check` ->
range check -> ONE hardened launch of the pinned native executable on `x` -> strict decision -> sign.
Any failure answers `{ok:false, reason:"native: <REASON>"}` and signs nothing. The Dafny check stays.
Reference code: `launcher.py` (launch), `decide.py` (range, wire, decision), `frame.py` (byte-equal copy of
`drafts/fail-closed/frame.py`, SHA-256 `cf939007…3e12`). Decision function stated and proved in
`dafny/Bridge.dfy`. A TypeScript port inside the issuer process is the adoption form (OWNER_APPROVAL.md).

## 2. The six compared fields

| field | Dafny side (from the verdict) | native side (strict parse of the one frame) |
|---|---|---|
| authorized | `verdict.Issue?` | atom 2 = `True` |
| amount | `token.intent.amount` | atom 3, canonical decimal |
| reason | UTF-8(`token.intent.reason`) | atom 4 bytes |
| charge id | UTF-8(`token.intent.chargeId`) | atom 5 bytes |
| request id | UTF-8(`token.requestId`) | atom 6 bytes |
| count | `|plan|` | atom 7 |

After the six fields agree, `decide.py` also requires `stdout == render_fields(expected)` byte for byte.
That step is unreachable (the strict parser already requires `render(parse(s)) == s`); mutant
`D-skip-bytes` survives for that reason (an equivalent mutant, kept as defence in depth).

## 3. Encoding of the inputs to the executable

- argv = `[absolute path of the private copy]` only. The executable has no argv FFI (A's FFI list).
- stdin = exactly `sexp_to_string (refund_request c q o r e opened candidate a reason)`, built by
  `frame.render_request` (a Python transcription; TESTED-UNPROVED by 68 + 4 real runs earlier), no trailing
  byte, then EOF. This is the premise `stdin_content fs = SOME (explode (sexp_to_string (refund_request …)))`
  of `refund_profile_a_sl`.
- `c, q, reason` = UTF-8 bytes of the Dafny text (Unicode scalar values). One byte = one char, so every
  char is < 256 by construction. UTF-8 is the encoding of the linked flat contract (S3, `LinkedRefund.Decode`).
- `o, r, a` = the integers of the issuer message; `e` = `pre.refundEnabled`; `opened = True`,
  `candidate = True` (`Check` fixes both: `ContextOf … true`, `R.Candidate(…)`).
- Range (`decide.in_range`): texts are Python `str` with no U+0000, no lone surrogate (strict UTF-8 encode),
  at most 256 UTF-16 code units (the issuer's `MAX_TEXT`; so at most 768 UTF-8 bytes); integers are `int`
  (not `bool`) in 0..2^63−1; `enabled` is `bool`. Outside the range: REFUSE `OUT_OF_RANGE`, no launch.
- The stored HOL theorem covers every `mlstring` and every `int`, so the range is a strict subset of its
  domain. The theorem still allows a resource stop with an output PREFIX; the strict parse refuses every
  prefix. The observed resource boundary (5,368,027-byte id) is far above 768 bytes (TESTED, not proved).

## 4. Refusal reasons (first failing step decides; all of them sign nothing)

`OUT_OF_RANGE`, `PATH_NOT_ABSOLUTE`, `BINARY_OPEN_FAILED`, `BINARY_NOT_REGULAR`, `DIGEST_MISMATCH`,
`ENV_NOT_ALLOWED`, `LAUNCH_FAILED` (pre-launch) · `TIMEOUT` · `STDOUT_OVERFLOW` (cap = length of the one
acceptable ACCEPT frame for `x`, at least 37; so a trailing byte or a second frame is normally refused
here) · `STDERR_NONEMPTY` · `SIGNAL` · `EXIT_NONZERO` · `STDIN_INCOMPLETE` · `BINARY_CHANGED` (copy re-hashed
after the run) · `STDOUT_EMPTY` (CE-2) · `FRAME_EXTRA_BYTES` / `FRAME_TRUNCATED` (CE-1) / `FRAME_MALFORMED` ·
`REJECT_FRAME_NOT_CANONICAL` · `BOTH_REFUSE` / `DAFNY_REFUSE_NATIVE_AUTHORIZE` · `MISMATCH_AUTHORIZED`,
`_AMOUNT`, `_REASON`, `_CHARGE`, `_REQUEST`, `_COUNT`, `_BYTES` · `INTERNAL_ERROR` (any exception).
Exit status 0 is necessary, never sufficient. Policy for stderr: ANY stderr byte refuses.

## 5. Hardened launcher (`launcher.py`) and the OS assumptions it rests on

Done per launch: absolute path; open ONCE with `O_NOFOLLOW`, `fstat` regular, read from that descriptor,
SHA-256 vs the pin BEFORE any process exists; the hashed bytes (memory) are written with `O_EXCL` to a new
0700 directory, mode 0500; env = the fixed allow-list `{CML_HEAP_SIZE=256, CML_STACK_SIZE=256}` (nothing
inherited; `DYLD_*`/`LD_*`/other names or values refused); `close_fds`; `restore_signals`; new session and
process group; stdin pipe with exact bytes then EOF; stdout/stderr pipes whose CHILD ends are blocking
(only the parent's read ends are non-blocking); stdout and stderr caps; wall-clock timeout; `killpg(SIGKILL)`
on timeout, on overflow and after every run; cwd = a new empty 0700 directory; no shell.

TOCTOU that remains (macOS): there is no `fexecve(2)`; `posix_spawn`/`execve` take a PATH. The bytes that
run are read by the kernel from the private copy at exec time. A process with the SAME user id can replace
the copy between the write and the exec (and restore it before the post-run re-hash). Other users cannot
(0700 directory). Closing it needs a different user for the launcher, a read-only signed location, or the
code-signature cdhash check by the kernel (hardened runtime + a pinned cdhash), none of which exists today.

ASSUMPTIONS (all named, none proved): OS-EXEC (execve passes exactly the given argv and envp, runs the file
at the path), OS-DYLD (dyld reads `DYLD_*` only from envp; the executable has no `LC_DYLD_ENVIRONMENT` and no
`LC_RPATH` — checked with `otool -l`; it loads only `/usr/lib/libSystem.B.dylib`), A-LOADER (the loader adds
no code beyond that; now enforced by the env allow-list instead of MISSING), OS-PIPE (bytes read = bytes
written; EOF only after every write end closes), OS-FD (close_fds closes every other descriptor), OS-PGRP
(SIGKILL to the group kills every member; a member that calls `setsid` leaves the group: it can survive the
run, but it cannot change the decision after the launcher stopped reading), OS-WAIT (the reported status is
the child's), OS-FS (0700 is enforced; same-uid writes are possible: the TOCTOU above), OS-CLOCK
(monotonic clock), A-ENV-HEAP (256 MiB heap/stack as in every recorded run), A-LAUNCHER-HOST (the launcher's
own interpreter, its environment and its code are trusted; a `DYLD_INSERT_LIBRARIES` in the LAUNCHER's own
start environment is outside this design: observed, the framework Python aborts at start).

## 6. Ledger edges this would change (if adopted and re-run; nothing changes tonight)

| edge | today | after adoption |
|---|---|---|
| X15 process result -> caller decision | MISSING | TESTED-UNPROVED (code: launcher + decide); its decision FUNCTION as a model: MACHINE-CHECKED (`Bridge.dfy`, if the logs say exit 0) |
| X16 M1 decision -> token | MISSING | TESTED-UNPROVED (issuance needs native agreement) |
| STRICT-FRAME (assumption) | no consumer | discharged for this consumer by code (TESTED-UNPROVED), not by proof |
| A-LOADER (native assumption) | MISSING | TESTED-UNPROVED under OS-EXEC/OS-DYLD (launcher scrubs `DYLD_*`) |
| U2 Check -> signed token | TESTED-UNPROVED | TESTED-UNPROVED (one more conjunct) |
| U1c DAFNY-JS | ASSUMPTION | ASSUMPTION; but a wrong JS compile can no longer mint ALONE |
| X3, X5–X10, X13, S4–S6 | unchanged | unchanged: the bridge does NOT prove the binary |

What it gives: an N-version check. A wrong native binary alone, or a wrong Dafny-to-JS compile alone,
cannot cause a signature; both must agree on all six fields of the same inputs. Composed corollary (in
words, not a new theorem about the binary): under the bridge, a token exists only if the proved Dafny
checker (as compiled) issued AND the pinned native artifact (as run) printed one complete frame with the
same six fields. Proved part: only the implication about the decision FUNCTION (`BridgeSound`).

Common-mode failures (the two versions fail together; the bridge does not help): (1) the shared approved
spec and the shared Dafny source (`RefundSpec`/`Refund.dfy` feed both the JS compile and, through the
exporter S4, the HOL contract): a spec error is agreed on by both; (2) the shared input glue: one
`CheckInputs` feeds both sides, so a stale or forged pre-state is accepted by both (only the sink's
pre-state hash stops it); (3) the shared encoder/wire builder/parser inside the bridge (mutant `D-latin1-wire`
is a common-mode encoder fault: both sides see the same wrong bytes; only the UTF-8 literal test kills it);
(4) the bridge code, the issuer runtime (Node), the OS: single points; (5) an environment attacker who
injects a frame that ECHOES the correct six fields (CE-3 with a smarter library) agrees with Dafny: only
A-LOADER (the env scrub) defends; the N-version check does not; (6) the same-uid TOCTOU of section 5.
