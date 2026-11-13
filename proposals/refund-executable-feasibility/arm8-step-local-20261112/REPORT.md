# U346: unchanged ARM8 step inspection passes locally

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
This packet records one local HOL run. No hosted action, native execution,
publication or protected edit occurred.

## Actual result

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_recorded.py inspect-arm8-steps-0001` in `results/refund-arm8-step-local-20261112/attempt-0001` | 0 | `arm8_stepLib` loads. Six words give seven published step theorems. `NATIVE_STEP_COMPLETE`. |
| Six-step composition; syscall and frame relation; native execution | NOT RUN | Separate obligations. |

The argv, cwd and sources are those of U316's `inspect-arm8-steps`:
source SHA256 `d124bc112181f5eb83d314a5b91666cb1f5f2358a73e55e2b8049f2798c6d922`,
ARM8 heap `787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9`,
HOL revision `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`. U316 recorded exit 1 in
`arm8_stepLib`/`numLib.DECIDE` for this command. All 16 checked tool and
source files match before and after. The cwd listing is unchanged.
Limits: CPU 600 s, wall 900 s, zero core dumps. Wall 6.216 s; child CPU
5.963 s user and 0.902 s system; max RSS 365887488 bytes.

## Step theorems obtained

Each theorem is `NextStateARM8 s = SOME ...` under explicit hypotheses. The
hypotheses name the four instruction bytes at `s.PC`, `s.PSTATE.EL = 0w`,
`s.exception = NoException`, `aligned 2 s.PC` and control-register bits.

| Word | Theorems | Effect in the published model |
| --- | --- | --- |
| `37f800c0` | 2 | Test bit 31 of `REG 0`: fall through `PC + 4`, or branch `PC + 24` |
| `52800028` | 1 | Set `REG 8` to the constant 1 |
| `39000268` | 1 | Store the low byte of `REG 8` at address `REG 19` |
| `a9417bfd` | 1 | Load two registers from the stack frame |
| `a8c24ff4` | 1 | Load two registers and adjust the stack pointer |
| `d65f03c0` | 1 | Return: `PC := REG 30` |

The exact statements and all hypotheses are in
[stdout.log](records/inspect-arm8-steps-0001/stdout.log), SHA256
`12e499c0938b85b9d30c3690d935cdaa713aaf408ff7f677b04edc79d3dc881e`.

## Limits

These are instances of the published L3 ARMv8 model. They are not a
composed six-step theorem. They do not cover the `read` system call, the
function prologue, the complete FFI frame condition or the physical
processor. U316's word binding to the native file is reused, not repeated.
Same machine and cached heap; no independent replay.

## Next check

Compose the six steps into one error-return theorem with explicit code,
stack, separation and return-address premises. Compare its memory effect
with the `read_error_generic` buffer (status byte 1) of U345.
