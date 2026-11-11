# U327 — Checked stdin model limit under the software correctness boundary

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
Parent checkpoint: U326, commit `8a099278200fb4b242e1ca80b7d97c10b097211b`.

The new result identifies a semantic boundary. It is not another sandbox denial.
Four HOL theorems now show that a well-formed standard stdin stream has the
inputs required by the pinned read model. With the configuration and buffer
guards, the model returns a result and its first byte is zero. It cannot use
its read-error branch in this domain.

The theorem `forge_refundStdinDomainTheory.stdin_ffi_read_total` is:

```text
wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
LENGTH read_tail ≥ w22n [n1;n0] ⇒
∃bytes' fs'. ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
  SOME (FFIreturn bytes' fs') ∧ HD bytes' = 0w
```

The companion `stdin_ffi_read_status_zero` constrains every returned result.
`wf_read_inputs` and `stdin_read_inputs` supply the lookup and live-stream facts.
The proof reuses U315 `read_ready`, `ffi_read_ready`, and
`ffi_read_ready_status`. No definition, theorem statement, runtime, or trusted
proof machinery was changed. The first failed proof lacked constructor facts
in its local Metis context. Residual-goal inspection identified that issue.
Adding the existing option and pair theorems closed it.

The final source SHA256 is
`6791849e3c7f09dea6b09c7bb1f3b9d2bcb0458d1e1ca9352ae6094b7a64507f`.
The final theory data SHA256 is
`3192e34a57ac581727a3ce8c56770e7354242577d35bc4229903fe28020e671d`.
Fresh proof and repeat each exit0 and produce four byte-identical exports.
Fresh import exits0 and checks all four exact statements, zero hypotheses,
zero tagged axioms, and only the expected DISK_THM import tags. The dependency
closure contains148 theory nodes and876 hashed parent files. Its only axioms
are the four existing Boolean foundations: SELECT_AX, INFINITY_AX, ETA_AX,
BOOL_CASES_AX. This is local cached-parent assurance, not independent source replay.

## Why this matters for the native bridge

Pinned `basis_ffi.c` calls `read` once. A negative result causes status byte1.
Pinned `TextIOProgScript.sml` raises `InvalidFD` when that byte is1. By contrast,
the established stdin model theorem above forces byte0 under its premises.
Proving the native store instruction alone cannot close this domain gap.

Apple's archived `read(2)` documentation distinguishes EOF from errors and
permits EAGAIN for an empty nonblocking stream and EINTR for an interrupted
slow-device read. Trusting documented syscall behavior does not imply that
all reads succeed. This archived page is not an exhaustive version-specific
macOS15 or macOS27 syscall specification.
[Apple read(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/read.2.html).

A new local control directly calls libc `read(fd,buffer,16)` on an empty
nonblocking pipe. With its writer open, the return is-1 and errno35/EAGAIN.
With its writer closed, the return is0 and errno0. The16-byte sentinel buffer
stays unchanged in both observations. The exact refund executable then runs
on the corresponding descriptor in each case. Both children exit0 and emit
zero stdout/stderr bytes. The probe does not trace the child's internal syscall.
It establishes neither a universal buffer frame nor native exception identity.

Native SHA256:
`b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
The local observer reports macOS27.0.1,arm64. U326's hosted diagnostic used
macOS15.8.2. No OS-version parity claim follows. No new hosted run occurred.

## Remaining obligation

Establish the admitted physical stdin relation to `wfFS`, `STD_streams`, and
the model's complete byte/event trace. For any admitted native read that returns
status1, a direct status-preserving relation to this model domain is obstructed
by the checked status-zero theorem. A proof must identify an existing approved
premise that rules out that case, or an established semantic route that covers
it while preserving the required events. Neither has been established here.

This is not a demonstrated counterexample to the original refund contract or
a proof that all possible correspondence arguments fail. The physical-state
relation itself is still open. We did not add a no-error assumption, exclude
nonblocking input, drop an event, or replace the pinned semantics. Successful
partial reads, EOF, syscall frame effects, stdout, memory, initialization,
linking, loading, resource adequacy, and native exit correspondence still need
the remaining software proofs. See [ASSURANCE.md](ASSURANCE.md) and the
[smallest next experiment](NEXT-STEP.md).

## Actual checks and preserved failures

| Command/check | Actual exit | Result |
| --- | ---: | --- |
| Initial runner preflight |1|Wrong physical path for a generated signature; HOL not launched |
| Initial model proof |1|Missing option constructor fact in local proof context |
| Residual diagnostics1–4 |1/1/1/0|Interactive alias, context argument, then unresolved local subgoal; final residual printed |
| Corrected three-lemma proof |0|Lookup and status theorem established |
| Four-lemma proof / repeat / fresh import |0/0/0|Totality included; exact statements and exports checked |
| Wrong status / omitted stdin guard |1/1|Intended exact-statement refusals; not attempted false proofs |
| Native errno control wrapper |0|libc returns-1/EAGAIN35 and0/errno0; native children0/0 |
| Separate artifact readback |0|2665 current input bindings,50 protected paths and frozen mission match |
| CakeML pin / HOL pin / inspected source diff |0/0/0|Pinned revisions and four inspected sources unchanged |
| Hosted execution / ARM8 step proof / independent21-snapshot replay |NOT RUN|No additional hosted authority; full chain is incomplete |

Exact argv, full HOL logs, byte streams, dependency closure, and failures are
in `records/`. The local readback is by the producing agent. It is not an
independent reviewer or separately controlled replay. Prior evidence is retained.
No release signing, protected changes, deployment, or Stage12 occurred.
