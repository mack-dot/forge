# Evidence gate

The gate invokes an established checker and binds its result to exact inputs.
It does not implement program semantics, a proof checker, or an SMT decision
procedure. The default backend remains Dafny 4.11.0 with bundled Z3 4.12.1.

## Run

Complete [the toolchain setup](../toolchain/README.md) first. Stage 2 also uses
these installed, pinned Python packages:

```text
attrs==25.3.0
jsonschema==4.21.1
jsonschema-specifications==2023.12.1
referencing==0.33.0
rpds-py==0.17.1
PyYAML==6.0.1
```

[requirements-stage2.txt](../toolchain/requirements-stage2.txt) pins the versions.
[validator-pins.json](../toolchain/validator-pins.json) pins observed installed
file bytes, including the native dependency for this host. Original package
archives were not independently authenticated. These are local content pins,
not a claim of distributor identity or a portable lock for every platform.

```sh
python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json
python3 gate/gate.py --schema-only results/stage1/evidence.json
python3 gate/gate.py --check-evidence evidence.json --evidence build/replayed.json
```

The first command runs the actual backend and applies the default `critical`
tier. `--backend dafny` and `--tier critical` make those defaults explicit.
The second command validates structure only. Its `SCHEMA_VALID` output is not
acceptance or evidence that any proof ran. The third command validates supplied
evidence, runs the real backend again, and requires the resulting canonical
bundle to match. Input and output files must differ.

Exit 0 means that the requested operation succeeded. Exit 1 means rejection.
Exit 2 reports a configuration or execution error. A Dafny verification rejection
retains raw checker exit 4 in its diagnostic; an audit comparison rejection
retains audit exit 2. Scenario scripts return 0 when an expected rejection really
occurs. Always distinguish those codes.

## Responsibilities

- `gate.py` selects a backend from the explicit registry, pins dependencies,
  snapshots trusted inputs, runs the backend, and writes an accepted bundle.
- `core.py` uses the JSON Schema validator, binds artifact and claim identities,
  checks policy methods, and creates canonical bundle metadata. It contains no
  Dafny proof logic or fixed ledger claim list.
- `backends/dafny.py` owns the approved ledger scope, invokes the real Dafny audit
  and verifier, and checks their result coverage.
- `backends/typescript.py` reruns the Dafny source gate, compiles its model, and
  invokes real fast-check comparisons. It emits `tested_against_proved_model`.
  The registry imports only the selected adapter.
- `common.py` handles canonical JSON, hashes, paths, and duplicate-key rejection.
- `dependencies.py` checks installed validator versions and pinned file content.

The backend supplies the current artifact identity, approved claims, input file
set, and checker results. The core does not accept artifact identity from the
submitted evidence. Evidence data never selects executable Python code.

## Dafny acceptance checks

The adapter preserves the Stage 1 checks:

1. Check the approved `spec.lock`, exact spec digest, Dafny build, Python version,
   executable hashes, and fixed verification options.
2. Require the exact approved include and `module Ledger refines LedgerSpec`
   preamble. Permit one implementation file in `impl/` or `bugs/`, with no other
   includes. This is a conservative source-format restriction, not a Dafny parser.
3. Invoke the real Dafny auditor with `--compare-report` against the empty
   approved audit table. Copy that table into a temporary directory first, because
   Dafny writes mismatch diagnostics beside the comparison file.
4. Invoke the real verifier with the contract-binding harness,
   `--verify-included-files`, `--cores 1`, `--resource-limit 1000000`, and
   `--verification-time-limit 0`. The last option disables the time limit.
5. Require every recorded TRX result to pass and the required concrete and spec
   obligations to be present. An abstract declaration alone is insufficient.
6. Recheck all recorded source and trusted-input digests before acceptance.

Forbidden proof escapes are rejected by Dafny's parser/auditor. The approved
abstract spec contains the intended contract declaration; implementation proof
escapes and bodiless lemmas remain forbidden. The binding harness alone is not
proof coverage, so the explicit refinement and required-result checks also apply.

The source preamble rule can reject harmless alternate formatting or an extra
`include` word in a comment. This narrow backend does not promise to accept every
valid Dafny program. Expanding it requires preserving dependency closure and
existing rejection behavior.

For the TypeScript adapter, run:

```sh
python3 gate/gate.py --backend typescript --impl ts/ledger.ts --tier standard --evidence build/stage3/typescript-evidence.json
```

The `critical` tier rejects this comparison-test method. The adapter records the
separate reference source proof, generated-module digest, compiler/bridge trust
assumptions, and actual finite test scope. It does not upgrade TypeScript testing
or the generated JS build to proof. See [ts/README.md](../ts/README.md) for the
fixed module-layout scope, numeric domain, property corpus, and reproduction.

## Evidence and policy

[The schema](../schemas/evidence.schema.json) describes claims, artifacts, the
nine method labels, evidence records, and bundle metadata. It accepts the exact
archived Stage 1 format as well as the Stage 2 format. Imported legacy evidence
must be regenerated before full acceptance because it has no Stage 2 policy
binding. The legacy schema check does not upgrade its format or authority.

Stage 2 bundles name schema version `2.0.0`, backend, policy id/version/tier/digest,
and trusted input digests. Backend-specific details stay in `backend_details`.
The ledger artifact remains `kind=source`: its SHA-256 is the digest of the
canonical sorted source manifest, including the implementation and approved
spec. `build_cmd` is empty because no binary build is claimed.

[tiers.yaml](../policy/tiers.yaml) has two explicit policies. `critical` requires
`source_proof` for C1–C5. `standard` permits its listed test methods as well as
source proof; it retains the actual method. The `minimum_method` is a policy
label, not a numeric ranking. `allowed_methods` is the exact acceptance relation.
A kernel-proof label does not automatically satisfy an unrelated source claim.
The default remains `critical`; supplying a different tier inside an evidence
file cannot change the tier selected by the caller.

The core rejects changed artifact identities, stale policy bindings, changed
claim text/spec bindings, unknown claims, missing passing evidence, unsupported
methods, and unsupported end-to-end coverage. It also checks all trusted input
hashes. Even after those checks pass, imported evidence must reproduce through
a fresh real checker run. A forged producer name with correct hashes cannot
satisfy that comparison.

This remains a trusted local gate with unsigned evidence. Its files and policy
must be trusted inputs. Changing both a local spec and its lock is not human
approval. Trusted PR baselines and signed provenance remain later-stage work.
`end_to_end=false` is mandatory here. Source proof does not establish compiled
binary behavior, deployment, storage, concurrency, or whole-service correctness.

## Reproduce the checks

```sh
python3 scripts/exit_stage_2.py --case schema
python3 scripts/exit_stage_2.py --case artifact-mismatch
python3 scripts/exit_stage_2.py --case method-policy
python3 scripts/exit_stage_2.py --case round-trip
python3 scripts/exit_stage_2.py --case policy-controls
python3 scripts/exit_stage_1.py --case reproducibility
python3 scripts/exit_stage_1.py --case planted-bugs
python3 scripts/exit_stage_1.py --case spec-lock
python3 scripts/exit_stage_1.py --case contract-binding
python3 scripts/exit_stage_1.py --case audit-controls
```

Actual commands, raw codes, and diagnostics stay under `build/stage1/` and
`build/stage2/`. Repeated cases archive older runs under the corresponding
`*-history/` directories. These operational logs are separate from canonical
evidence. The Stage 1 evidence and original gate/scenario sources are preserved
under `results/stage1/`; they are historical snapshots, not alternate entrypoints.

Hand-edited evidence in the negative scenarios is explicitly invalid input,
never a claim that another tool or method actually ran. The basic Stage 1 unit
suite remains deliberately incomplete. Its success does not prove the ledger.

The schema implementation uses the established
[jsonschema 4.21.1 validator](https://python-jsonschema.readthedocs.io/en/v4.21.1/validate/).
Policy loading uses [PyYAML's safe loader](https://pyyaml.org/wiki/PyYAMLDocumentation).
JSON Schema checks structure; identity, allowed-method policy, and fresh-checker
reproduction are separate gate checks.
