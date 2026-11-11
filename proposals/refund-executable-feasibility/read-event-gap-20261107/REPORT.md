# U328 — Read-error event replay is formally incompatible with the guarded basis model

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
Parent U327: `2874d5cd3879a110fc41f161d83dc0493fcb994d`.

Four new checked theorems connect U327's status-zero result to the complete
event-replay requirement in U310. They also close the proposed `ext` route:
the basis oracle handles `read` itself and never delegates that call to `ext`.
This is a model-level obstruction with explicit premises. It is not a proved
native counterexample or a proof that every software assurance route is impossible.

## Checked statements

| Theorem in forge_refundReadEventGapTheory | Result |
| --- | --- |
| basis_read_ignores_ext | For every state,configuration and byte buffer,the basis read result is identical for arbitrary ext and ext'. |
| basis_stdin_read_total | Under wfFS,STD_streams and the existing fd0/configuration/capacity guards,the basis oracle returns a result with first byte0. |
| stdin_error_event_rejected | Under those guards,a read event whose input projection is the request buffer and whose output first byte is1 causes extract_fs_with_numchars to return NONE,for every suffix. |
| stdin_error_complete_trace_rejected | If a prefix replays to the guarded state,adding that read event makes extract_fs return NONE for the entire prefix,event and arbitrary suffix. |

The last theorem retains every byte pair and the entire prefix and suffix:

```text
extract_fs_with_numchars ext (cl0,fs0) prefix = SOME (cl,fs) ∧
wfFS fs ∧ STD_streams fs ∧ LENGTH conf = 8 ∧ w82n conf = 0 ∧
LENGTH read_tail ≥ w22n [n1;n0] ∧
MAP FST pairs = n1::n0::pad1::pad2::read_tail ∧
HD (MAP SND pairs) = 1w ⇒
extract_fs ext (cl0,fs0)
  (prefix ++ IO_event (ExtCall «read») conf pairs :: suffix) = NONE
```

U310 requires replay to return `SOME (fastForwardFD fs 0)`. The checked result
therefore prevents a direct application of that replay claim to an error event
meeting these premises. An arbitrary `ext` cannot repair the read call. An
earlier external call could change a model state; the theorem expressly requires
the resulting state to satisfy its guards. That premise was not dropped.

All four theorems pass on their first proof attempt. Proof/repeat/import exit0.
The four generated exports match byte for byte. The imported statements have
zero hypotheses,zero tagged axioms,and only DISK_THM tags. The closure has217
theory nodes and1287 parent files. Its only axioms are the existing Boolean
SELECT_AX,INFINITY_AX,ETA_AX and BOOL_CASES_AX. Readback checks2668 input bindings,
50 protected paths and the frozen mission. This is same-host cached-parent
assurance,not independently controlled source replay.

Proof source SHA256:
`902821b55ffa3991c677640aeba8eec4d901e25cceb3c12a4680b45c24846d19`.
Theory data SHA256:
`60261ea96a993d62c971769d642c9ab1b9dbc558ccd31f41d9e4e3ef00202357`.

## Scope review

The locked RefundSpec and protocol hashes match. The mathematical refund
contract covers all typed contexts and responses; it has no POSIX descriptor
availability premise. The protocol requires fallback for its listed provider
and wire failures and distinguishes these integration obligations from its
source datatype theorem. It does not supply a no-error assumption for native
stdin. The inspected modeled stdio and runtime correspondence documents are
explicitly unadopted proposals. Absence of a POSIX requirement is not approval
to exclude native errors from the owner's current goal.

Published `TextIOProof.read_spec` allows `InvalidFD` only when file content is
unavailable or the descriptor mode is not ReadMode. `IOFS` retains wfFS and
`STDIO` retains STD_streams. Published `basis_ffi_oracle` intercepts read before
the extension branch. These facts explain the obstruction; it is not a missing
lookup rewrite. Source identities and scope files are in `records/readback.json`.
The eight inspected CakeML source files match the pinned commit.

The actual program calls `TextIO.inputAllFrom None`,then dispatches and prints.
The TextIO source closes and rethrows an exception from inputAll; refund_main
has no enclosing handler. These are source inspection findings. No new theorem
about the native exception class or process exit is inferred from them.

## Separate generic FFI proof attempt

The published `cfTheory.app_ffi_def` and `cfHeapsBaseTheory.FFI_part` support
an explicit oracle transition and full event list. A separate candidate theorem
uses them to specify the unchanged TextIO read function when that transition
returns the exact status1 buffer. It retains the complete buffer,oracle state,
names,event append and InvalidFD exception. It defines no new semantics or
oracle and changes no existing theorem. The transition premise itself would
still need a native proof; it is not accepted as a new trust assumption.

The candidate did **not reach its theorem**. Its first operation,`load "cfLib"`,
exits1 through cfDivLib,cfTacticsLib and HOL helperLib at numLib.DECIDE. There is
no new theory export and no residual goal for the candidate. Its statement and
tactics remain unchecked. Full stderr is preserved. The error has no captured
errno; causation by U320's mkstemp denial is not established. This loader route
is now stopped. No same-context retry,solver replacement or security workaround
was attempted. See [NEXT-STEP.md](NEXT-STEP.md).

## Actual exits

| Command/check | Actual exit | Result |
| --- | ---: | --- |
| Four-theorem proof / repeat / fresh import |0/0/0|Accepted exact claims and identical exports |
| Wrong replay result / omitted error event |1/1|Intended exact-statement refusals |
| Artifact/closure/source readback |0|217 nodes,1287 closure files,2668 inputs; protected inputs unchanged |
| CakeML source pin / eight-source diff |0/0|Pinned commit and inspected sources match |
| Generic TextIO error proof candidate |1|cfLib loader failure; theorem not reached |
| Generic failure-record readback |0|Failure and absence of export confirmed |
| New native execution / hosted run / independent21-snapshot replay |NOT RUN|No additional external authority or complete replay chain |

The negative controls test exact claim binding,not native attacks or universal
falsity of a changed claim. The four accepted proof claims remain separate from
the failed candidate. No specifications,premises,proof machinery,or protected
files were modified. Logical Success,native exit0,and actual OS effects remain
distinct. Memory,loader/linking,full FFI correspondence and independent assurance
remain open. The software-only boundary and explicit ISA/OS/HOL trust remain.
