# TypeScript and the compiled ledger model

`ledger.ts` is a handwritten implementation of the approved sequential ledger
contract. It uses `bigint` for account IDs, request IDs, balances, and amounts.
It copies maps on accepted transfers and leaves both maps unchanged on retries
and rejection. The caller must supply a WellFormed state.

This implementation has finite comparison-test evidence. It has no source proof.
The Dafny source retains its separate source-proof evidence.

## Run the model and checks

Install the exact packages from `package-lock.json` using the pinned Node and
npm versions. `toolchain/javascript-pins.json` also records observed installed
package content for this platform. Original npm tarball integrity was not
independently replayed in this session; the user performed the installation.

```sh
python3 scripts/javascript_env.py
python3 scripts/build_model.py
node --import tsx app/main.ts
npx --no-install tsc --noEmit
python3 gate/gate.py --backend typescript --impl ts/ledger.ts --tier standard --evidence build/stage3/typescript-evidence.json
python3 scripts/exit_stage_3.py --case correct-typescript
python3 scripts/exit_stage_3.py --case self-transfer
python3 scripts/exit_stage_3.py --case evidence-labels
python3 scripts/exit_stage_3.py --case reproducibility
```

The app calls the compiled Dafny ledger through `interop/model.ts`, which
converts bigint/map inputs to the actual generated runtime's values and converts
its outputs back. It prints `Ok` then `Rejected`. The bridge contains no ledger
transition implementation.

The Node loader uses the installed tsx package without the CLI's local IPC
server. The user approved it as the demo EXIT replacement. The original command,
`npx tsx app/main.ts`, ran and exited 1 because local IPC was denied. Its failure
remains in the execution record; it is not reported as a passing command.

## Build identity and trust boundary

The build script invokes Dafny's real JavaScript compiler with the pinned solver,
resource limit, and included-file verification. It retains the unmodified output
as `build/js/ledger.js`. The generated file does not expose CommonJS exports, so
the script appends the tracked `interop/export.cjs` visibility footer and writes
`build/js/ledger.cjs`. No generated transition logic is rewritten. The module
identity covers both pieces, and `build/js/build.json` records the actual build
command, input hashes, generated-source hash, and final module hash.

The TypeScript backend first reruns the real Dafny source gate, builds the model,
and invokes fast-check through the supported tsx Node loader. Acceptance records:

- The TypeScript source collection's digest and C1–C5 spec bindings.
- Method `tested_against_proved_model`, with the actual seed, run count, bounds,
  operation categories, and comparison counts.
- The separate source-proof artifact and evidence digests for the reference.
- The exact generated module digest and reproduction command.
- Explicit assumptions about the compiler, generated runtime, export footer,
  conversion bridge, Node, and test harness.

The TypeScript source manifest covers the fixed ledger module layout and its
shared type file. The bug fixture additionally depends on the correct ledger.
This adapter does not promise dependency discovery for arbitrary TypeScript or
dynamic module loading. Expanding the module layout requires an explicit adapter
and manifest update. Supporting dependencies and checker code are separately
hashed as trusted inputs.

The existing `standard` tier permits model-comparison testing. The `critical`
tier requires source proof and rejects this evidence. No policy was weakened for
TypeScript. A source proof remains attached to Dafny source bytes. It is not
attached to the generated JS module or the handwritten TS artifact.
`source_to_module_proved=false` and `end_to_end=false` remain explicit.

## Property-test scope

The fixed seed is 3032026. Each of 300 runs contains seven directed operations
and up to 40 generated operations. Generated balances range from 0 through
2^128; generated arbitrary amounts range from -2^128 through 2^128. Derived
insufficient-funds amounts can exceed the initial balance by one. The implementation
uses bigint rather than restricting its numeric representation to this test range.
Account IDs include a negative integer and 2^80. One fixed example starts with
balances 2^100 and 2^120.

The suite compares complete states and outcomes after each operation. It also
checks that the candidate did not mutate its input maps. The corpus includes
exact-balance transfers, accepted retries, changed-payload ID conflicts,
self-transfers, unknown accounts, nonpositive amounts, insufficient funds, and
values above Number.MAX_SAFE_INTEGER. Generated operations can repeat request
IDs. Accepted histories are built through real model transitions.

The planted `bugs/self_transfer.ts` credits a self-transfer without debiting it.
fast-check must fail with an actual comparison assertion and a counterexample;
a syntax error, missing module, or unexpected exception does not count. The gate
must also reject it and emit no accepted evidence.

Successful comparisons apply only to executed cases. They do not establish all
possible sequences, all WellFormed histories, arbitrary account sets, concurrency,
persistence, network behavior, or deployed behavior. The compiler/runtime/bridge
link is an assumption, not a checked compiler-correctness proof.
