# Refund read boundary and runtime audit — U315

CURRENT none. M1 open. Stage12 unauthorized. `end_to_end=false`.
Parent commit: `dde26bed545bb1f5fc87efe0410ddcace239e531` (U310).

Four new HOL lemmas establish the published filesystem model's exact ready-read
and error-buffer behavior. They do not establish that the physical runtime
implements that model. The smallest open link is a single concrete `ffiread`
transition: OS result, complete returned bytes, filesystem relation, return state,
and the frame required by `ffi_interfer_ok` must agree together.

## Actual checks

| Command/check | Actual exit(s) | Result |
| --- | --- | --- |
| Model bundles 0001–0006 | 1/1/1/1/1/1 | Two parser failures, three status-proof failures, one error-frame proof failure preserved |
| Status-goal diagnostic | 0 | Exact residual assumptions and goal printed |
| Model bundle 0007 / repeat / fresh exact import | 0/0/0 | Four checked statements; four byte-identical exports |
| Wrong ready status / changed error frame | 1/1 | Intended statement refusals after all four positive checks |
| Native control runners, first/repeat | 0/0 | Eight process observations in each run; table below gives child exits |
| LLDB static/script check | 1 | Disassembly succeeded; this build lacks the Python interpreter |
| Directory launch / known-valid launch | 1/1 | Debugger failed before a breakpoint; no native exit or buffer capture established |
| Historical checksum / two signature verifications | 0/0/0 | 311 historical members and both exact native builds match |
| Replay identity preflight | 0 | 21 snapshots and three source pins match; replay gate remains NO_GO |
| Evidence readback | 0 | 147 theory nodes,870 closure files,2659 prior bindings,2727 historical chain files,50 protected paths |
| Independent clean full-chain replay | NOT RUN | Independent environment and bootstrap provenance not validated |

[Exact commands and records](COMMANDS.md). No recompilation, new signature,
protected change, deployment, or stage transition occurred. Incidental read-only
path errors and the published-page HTTP403 remain recorded.

## Checked model statements

`forge_refundReadBoundaryTheory` contains exactly these four theorems:

1. `read_ready`: readable descriptor, matching inode content, and a defined
   numchars head give the exact successful read and `bumpFD` result.
2. `ffi_read_ready`: with an eight-byte descriptor and a large enough input
   buffer, a successful modeled read gives the complete status/count/padding/
   data/untouched-tail array and the exact returned filesystem.
3. `ffi_read_ready_status`: those ready-state lookups and guards, plus the exact
   returned `FFIreturn`, imply `HD bytes' = 0w`.
4. `ffi_read_unavailable`: with the same length guards and modeled `read = NONE`,
   the result is `FFIreturn (1w::n0::pad1::pad2::read_tail) fs`. The filesystem and
   every remaining buffer byte are unchanged.

The complete statements are independently written in [expected.sml](records/expected.sml).
The fresh kernel import compares every statement, including every antecedent.
All four have zero explicit hypotheses and zero new tagged axioms. The complete
147-node theory ancestry contains only the existing Boolean foundations
`SELECT_AX`, `INFINITY_AX`, `ETA_AX`, and `BOOL_CASES_AX`. The audit hashes870
closure files and verifies all2659 U310 parent bindings. DISK_THM imports, HOL's
logic/kernel, Poly/ML, the host, and its loader remain trusted. This local import
does not constitute independent clean source replay or independent reviewer approval.

The status proof passes on its fourth actual proof attempt. First the monadic
expression remained inside an assumption. Moving it to the goal exposed a
constructor equality. Substitution reduced the goal to `HD (0w::rest) = 0w`;
the existing `listTheory.HD` equation closes it. The error-frame lemma passes on
its second attempt using the existing `listTheory.LUPDATE_def`. The earlier
`choice` and `tail` parser collisions occur before those respective proofs.
No failing proof exceeds five attempts. No original statement, approved input
domain, error predicate, event trace, heap relation, or compiler premise changed.

## Native results and their limits

Both runs use the same unchanged executable. CPU limit:30 seconds per child;
core dumps disabled. The complete environment and descriptor setup are recorded.
The two eight-case observation records agree exactly.

| Child input/output setup | Actual exits, first/repeat | Captured stdout / stderr |
| --- | --- | --- |
| Valid62-byte request in regular file | 0/0 | Exact expected64 bytes / empty |
| Empty regular-file EOF | 0/0 | Empty / empty |
| Malformed wire input `(` | 0/0 | Empty / empty |
| Closed stdin | 0/0 | Empty / empty |
| Write-only stdin | 0/0 | Empty / empty |
| Empty nonblocking pipe, writer held open | 0/0 | Empty / empty |
| Nonblocking pipe with ready request, writer closed | 0/0 | Exact expected64 bytes / empty |
| Stdout pipe with no reader | -13/-13 | Stdout not captured / empty stderr |

Python records `-13` for termination by SIGPIPE. It is not shell status141 or a
normal application return. An empty placeholder stdout file in that case is
not evidence of zero bytes written. Native errno values and internal FFI status
bytes were not captured. Descriptor setup and whole-process observations do not
prove which exception was raised or which modeled event occurred.

The pinned LLDB23.1.5 binary and library match the earlier observer identities.
Static disassembly reaches the exact `ffiread` call and negative-result branch.
Its Python command fails because scripting support is absent. The command-only
directory-input launch then fails with `no such process`; a known-valid input
fails at the same launch step. Both debugger exits are1. No native child status,
post-read register, or new buffer/frame measurement is inferred. This launch
route is stopped. No observer replacement or permission bypass was attempted.

## Smallest unresolved correspondence

The published `read` definition returns success whenever its descriptor, mode,
inode, and numchars-head premises hold. The checked status lemma makes that
consequence explicit. The IO_fs record does not encode O_NONBLOCK, errno, or
signals. Real readable descriptors can encounter OS errors. The empty
nonblocking-pipe observation is useful evidence of process behavior; it is not
a checked syscall or FFI-trace counterexample.

In the pinned C source, `ffiread` calls `read(fd,&a[4],n)`. If the result is
negative, the C branch stores1 at `a[0]`. The absence of other explicit C stores
does not prove that the syscall preserved the buffer or file position. The
published model requires both preservation facts on its error branch, and its
own source warns about the physical file-position discrepancy.

Thus the required one-call relation must connect all of the following, without
adding an axiom or changing the model:

- The actual fd0, descriptor bytes, request count and full buffer to the model.
- Actual return/error and all resulting buffer bytes to `ffi_read`.
- Physical offset/content effects to its returned filesystem, including errors.
- Return PC, valid machine state, required saved registers and every program-domain
  byte outside the output array to `ffi_interfer_ok`.

No available checked infrastructure currently supplies that relation for this
exact Clang object and Darwin syscall. Published CakeML work expressly leaves
the C/OS boundary in the trusted base. [Primary sources and scope](records/PUBLISHED-SOURCES.md).
It would be unsound to assume that `numchars` represents every OS error, to map a
native error to modeled EOF without preserving the trace, or to use exit0 as a
proof of logical `Success`. Closed/unreadable descriptors also do not satisfy
the normal `STD_streams` premise merely because the process terminates.

The next smallest physical experiment is specified in [NEXT-CHECK.md](NEXT-CHECK.md).
It requires a working authorized observer and measures one read call. It remains
finite evidence. A universal result still needs an established concrete semantics
and a checked refinement, or an explicitly reviewed environmental assumption.
No such assumption is silently adopted here.

## Premise correction and independent replay

U310's report described `is_arm8_machine_config` too broadly. Its definition
fixes only `arm8_target`, pointer/length registers0/1 and2/3, and callee-saved
registers19–28. Installation, entry, memory and FFI conditions instead occur under
`installed` and `good_init_state`. The original theorem and U310 packet are
unchanged. [ASSURANCE.md](ASSURANCE.md) corrects the grouping and retains every
physical, memory, installation, resource, linker, loader and OS obligation.

The21 prepared U310 source snapshots still match their original files. CakeML,
HOL and Poly/ML revisions and tracked source contents match their pins. These
local identity checks do not establish independent source provenance, bootstrap
trust or a reviewer-controlled clean environment. The prior Docker socket denial
and historical Holmake refusal have no demonstrated environment change; neither
was retried or bypassed. No clean replay ran. The existing replay plan remains
the prerequisite-controlled next full-chain procedure.

## Exact identities

| Artifact | SHA256 |
| --- | --- |
| Accepted model source | `2ebad35c506b95ab9a3f209341777514fbd75e679fb0f673e91d32553845fa7a` |
| Reproduced theory data | `32d97ebfdd39e761c4b9ea8905a2f6090df23b9c9985dafc2c508b266abaf050` |
| Exact native executable, both builds | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| Pinned runtime C source | `e65a58121bcf7c32501ed01f75783f08ec30653192b2265665a9cdae199ab2a1` |
| Runtime object | `74f9efbf5132301386c2656638f826e6e5fec2593e99d406aa9618851dc94a55` |
| Generated assembly | `4c750e4f9ecf75ff1f0bf5af7bfbdd0600ee2ca0e1564fcadc299db55c3a1757` |
| Exact code payload | `3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb` |
| Bitmap payload | `68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76` |

The readback also verifies134 unchanged U310 packet members and100 U296 members.
All50 protected paths and the frozen mission bytes match. Existing local ad hoc
signatures verify; they do not establish release authority or trusted independent
production. No native file was changed or signed in this run.

## Preservation checks

The full staged whitespace check exits2 for exact debugger/proof logs, generated
HOL exports and pinned upstream sources. The authored Markdown check exits0.
Those evidence bytes remain unchanged. `records/whitespace-checks.json` and its
full output retain the distinction. All original failures remain available.
