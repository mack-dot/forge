# Exact runtime counterexample and candidate property — review only

Stage 12 remains unauthorized. No existing theorem, gate, policy, lock, image or
accepted claim is changed by this proposal. The candidate below is NOT RUN.

## Actual finding

The exact Stage 7 ELF `8ced2ab6…` executed under a pinned Ubuntu QEMU 8.2.2
binary and returned 0. Its retained trace reports initial SP
`0x2aaaab2abc30`, below the public theorem's Sv48 lower bound
`0x7fff80000000`. Thus the observed launch does not satisfy `valid_entry` and
cannot instantiate the existing public theorem. An exit-zero test cannot repair
that contradiction. See the raw observation and trace under
`results/campaign-resume-2026-11-02/`.

The program source, executable bytes and existing theorem remain unchanged.
The original mounted-file load failed with 1 and no instruction trace. A private
hash-identical copy with mode 0555 ran successfully. Its path/permission change
does not establish an admitted deployment of the historical signed container.

## Existing execution environment options

The inspected QEMU 8.2.2 and 11.1.3 loaders allocate a stack through
`target_mmap(0, size + guard, ...)`. RISC-V's default unmapped base is derived
from the address-space size. `-s` controls stack size; `-B` and `-R` control
address-space mapping/reservation. No direct initial-stack-address option was
identified in these paths. No random address adjustment, altered ELF, register
injection, custom loader or changed model was used to manufacture compatibility.

Keeping the current native-entry contract would require an execution environment
that actually meets its complete preconditions. No such environment is currently
established. This proposal does not authorize a new VM, native host or kernel.

## Additional candidate proposition

[InitializedTermination.v.proposed](InitializedTermination.v.proposed) contains
the complete candidate statement and proof text. It says that every state made
by the existing model's initializer for this exact image terminates normally
with status 0 under its `may_fail` configuration and allocation limit. It does
not require the public theorem's `valid_entry` or `valid_input` premises.

This is logically a stronger abstract-model statement, with a broader domain.
It is not an interpretation of the existing public theorem as covering more
states. It does not establish a Linux-valid initialization, QEMU-to-LPS refinement,
arbitrary-input GCD correctness, compiler correctness or whole-service behavior.

Feasibility is an inference only: the existing `Execution.selftest_exits_c`
quantifies over SP, random data, argv, environment, UID and hardware arguments;
the current termination proof does not explicitly use its two validity premises.
The proposed proof still must actually compile and pass independent checking.
No successful candidate proof is claimed.

## Precise requested intent decision

Approve or reject **only the exact additional abstract-model proposition and
feasibility-check source in the linked proposed file**. This is a proposed scope
decision, not authorization to weaken an existing contract or relabel the current
QEMU observation as proved. It is not approval of Stage 12.

After that decision, an authorized feasibility run can use the existing pinned
Rocq checker, existing ELF/image/proof modules and published soundness lemma.
Planned compile form, NOT RUN:

```text
rocq compile
  -Q /work/_build/default/theories OssFuzzTheorems.Core
  -Q /work/.forge-stage7/own-proof/attempt-0003/source Forge.Binary
  -Q <private-candidate-directory> ForgeCandidate
  <private-candidate-directory>/InitializedTermination.v
```

Only use prior source modules after the unmodified own-proof run actually passes.
The next complete proposal must also bind this exact proposition with the
published wrapper, audit its assumptions and check its full dependency closure
with the established independent kernel. Plain module compilation is insufficient
for a new accepted software claim.

Any integration into protected schema/policy/locks requires a separate exact-byte
review package. Any new release or signature requires its own exact request and
authorization. Existing consumed release requests cannot be reused. Keep
`end_to_end=false` until all required links and the new scope are established.
