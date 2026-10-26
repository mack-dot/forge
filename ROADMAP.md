# Forge: proof-gated changes

**CURRENT: Stage 4 — CHANGE LOOP**

This is the execution plan and decision record. Stages 0–3 are DONE. The
approved ledger refinement passed the real Dafny gate. The schema, policy,
artifact-binding, replay, and Stage 1 regression checks produced their required
results. The user approved the tested Node-loader demo invocation, which ran
with exit 0. Stage 4 is CURRENT. Its local snapshot gate has passed rejection
and reproducibility controls. Linux CI inventory succeeded and its observed
pins are recorded. The real affected-claims and unapproved-spec PR EXITs passed.
The exact fee proposal is published for human approval. The approved-spec EXIT
remains incomplete; Stage 4 is CURRENT.
Uncertainties and runtime-provenance limits are recorded
in the append-only [unsure.md](unsure.md) log.

The long-term horizon and irreducible limits live in [VISION.md](VISION.md).

## Mission

Build an open-source system for general software engineering in which
non-deterministic LLM agents propose code and established, deterministic
checkers decide what is accepted.

Every accepted artifact must carry reproducible evidence. The evidence must
state exactly what was established, about which artifact, under which
assumptions, and by which method.

**LLMs propose, checkers dispose. Humans approve intent (specs), not code.**

## Operating mode — read every run

1. Read this file. If it is missing, recreate it from the stages below and set
   Stage 0 to CURRENT.
2. Work only on the CURRENT stage. Do not start a later stage, even partially.
3. A stage is complete only when every EXIT command has actually run and
   produced its required behavior. Record each exact command, real numeric exit
   code, and result here. Then mark that stage DONE, set the next stage CURRENT,
   and stop. Stage 10 has no successor.
4. Keep the final response to at most 20 lines: stage, EXIT command table with
   real exit codes, and blockers. No narrative.
5. A documentation task does not complete an implementation stage. Keep
   unexecuted checks marked NOT RUN. Never substitute expected codes for actual
   codes.
6. Append uncertain findings to `unsure.md`. Never edit, delete, reorder, or
   overwrite an existing entry. Resolve an entry by appending a new entry that
   refers to its ID. Distinguish observations, inferences, and open questions.

## Hard rules

- Use established tools: Dafny, Rocq, Lean, TLA+/TLC, Verus, Kani, Theorem's
  published pipeline, and sigstore/in-toto. Select the backend needed by the
  current stage; do not install all backends in advance.
- Never write a custom verifier, decoder, machine semantics, proof checker,
  SMT wrapper that judges correctness, or axiom system. Gate code may dispatch
  established tools, bind their results to artifacts, and enforce policy.
- Never simulate or mock a check, or report it as passed unless the real command
  ran and exited as required. If a toolchain cannot be installed or run, STOP,
  report the exact error, and change nothing else.
- Protected files are `spec/**`, `spec.lock`, `policy/**`, and `gate/**`.
  Never modify them to make something pass. To change a spec, write
  `proposals/<name>.md` with the exact diff and a plain-English reason. STOP for
  human approval. Approval must cover the actual proposed change.
- Implementations must not contain `assume`, `{:axiom}`, `{:verify false}`,
  `Admitted`, `sorry`, axiom declarations, or bodiless lemmas. The gate rejects
  these. Deliberately invalid fixtures are rejection tests, never accepted code.
- Evidence must not overclaim. Keep `end_to_end=false` unless every link from
  spec to deployed artifact is covered by a checked method. Tested does not mean
  proved. Bounded model checking does not establish an unbounded proof.
- Pin every tool version. Use resource limits rather than time limits for
  acceptance checks. Include no timestamps in evidence. The same fully specified
  inputs must produce byte-identical evidence.
- Do not echo files or reread them without a reason. Fix only what tool output
  points to. Make at most five attempts per failing proof, then report the
  blocker in at most five lines.

## Intended users and first useful release

The initial target is a small, critical component inside an ordinary software
project. Examples include a ledger, refund rules, idempotent requests, booking
invariants, and permission decisions. Stages 0–3 establish the first useful
demonstration. They do not establish general support for arbitrary applications.

The intended workflow is: approve behavior, propose an implementation, run the
checks, and inspect a plain-English claim report. The user should not need to
write a proof merely to understand what a change establishes. Authoring and
maintaining difficult specifications may still require specialist knowledge.

Different tasks need different evidence. Tests and measurements remain useful
for integrations, performance, UI behavior, and model quality. The policy must
preserve these distinctions. Broad usefulness, acceptable cost, and ease of
adoption are hypotheses to measure in Stage 10.

## Core data model

Design for these records. Implement only what the CURRENT stage requires.

```text
Claim: {
  id, statement_plain_english, spec_ref, spec_sha
}

Artifact: {
  kind: source | module | binary | container,
  sha256, build_cmd
}

Evidence: {
  claim_id, artifact_sha, method, tool, tool_version, result,
  assumptions[], trusted_base[], reproduce_cmd, producer
}

method:
  unit_tested
  property_tested
  tested_against_proved_model
  bounded_model_checked
  eval_measured
  runtime_monitored
  source_proof
  binary_proof
  kernel_checked_proof

Policy: per code tier, required claims and their minimum acceptable methods.
Gate: backend-agnostic evidence validation against policy; no method upgrades.
```

Stage 1 should use the applicable fields directly. Stage 2 formalizes their
schema. Its bundle envelope must also carry `end_to_end`, schema and policy
versions, and the links among claims, artifacts, and evidence. Avoid creating
the later schema or adapters during Stage 0.

## Design reasoning and acceptance boundaries

### 1. The gate coordinates checks

The gate's authority comes from established checkers and protected policy.
Parsing a result, comparing a digest, or checking a required claim is gate work.
Inventing semantics or deciding whether a logical proposition is true is not.
An unknown result, crash, exhausted resource budget, or missing proof fails
acceptance. It does not demonstrate that a claim is false.

### 2. Intent needs precise boundaries

Before freezing the initial ledger spec, make these decisions explicit: account
existence, amount domain, zero amounts, balance limits, retry identifiers,
identifier reuse with different arguments, and the state included in “no effect.”
Decide whether rejected requests create retry records. These choices affect C3
and C5. They must not emerge accidentally from implementation details.

For the first ledger, scope claims to the specified state transition. Do not
claim concurrency safety, crash recovery, durable storage, or distributed
exactly-once execution unless those behaviors are specified and checked. C4 is
the success of a valid operation, not a claim about network delivery or scheduler
fairness. Include termination in its contract.

### 3. Protected inputs need an external baseline

Checking `spec.lock` against files in the same proposed change detects accidental
drift. It does not authorize an agent to change both. Stage 4 must compare with a
trusted baseline and bind approval to the spec diff and revision. Gate code,
policy, workflow configuration, and tool options must come from trusted inputs.
An untrusted PR must not replace the gate that accepts it.

Initial creation of planned files establishes a baseline. Later planned work,
such as the Stage 2 adapter refactor, must preserve existing rejection behavior.
If a change requires weaker acceptance rules or a changed spec, use a proposal
and stop. Negative tests that alter protected inputs use disposable copies;
they do not edit the approved baseline.

### 4. Evidence methods form a policy relation, not a universal ranking

A binary no-crash proof does not establish ledger conservation. A kernel-checked
theorem can concern a different property or artifact. Testing, bounded checking,
source proofs, and runtime monitoring answer different questions.

Interpret “minimum method” through explicit allowed methods for each claim,
artifact kind, scope, and assumptions. A higher-sounding label cannot satisfy an
unrelated requirement. Keep one method per evidence record. Several records can
describe different checks of the same artifact.

### 5. Artifact identity includes the relevant inputs

Hash the exact artifact bytes. For a source collection, define a canonical
manifest of paths and content digests, including the dependency closure. Bind
the result to the approved spec, toolchain, verification options, and policy.
Recompute digests; do not trust values supplied by a proposal.

A matching digest and valid JSON do not prove that a checker ran. Until Stage 9
adds signed provenance, acceptance must use a trusted local or CI checker run.
Handwritten evidence cannot grant itself authority by naming a trusted producer.

### 6. Determinism needs a complete execution contract

Lock versions, distributions, checksums, platform, relevant environment settings,
solver options, seeds, and resource budgets. Canonicalize evidence ordering and
serialization. Keep wall-clock durations, host paths, run identifiers, and raw
diagnostic logs outside canonical evidence. Record benchmarks separately.

Dafny documents stable solver resource counts for the same Z3 build and platform.
That supports resource-based limits; it is not a promise of identical behavior
across arbitrary machines. [Dafny verification optimization](https://dafny.org/dafny/VerificationOptimization/VerificationOptimization)

### 7. All proof dependencies must be covered

Verification must include the required declarations and dependencies. Reject
verification bypasses, skipped members, unapproved external assumptions, and
missing obligations. Prefer the established tool's parser and audit facilities
over inventing a language parser or relying only on keyword searches.

Dafny provides audit and verification controls. In version 4.11.0, `dafny audit`
can return zero while reporting findings. The gate must inspect the findings;
an exit code alone is insufficient. Validate this behavior with real negative
fixtures in Stage 1. [Dafny 4.11.0 reference](https://dafny.org/v4.11.0/DafnyRef/DafnyRef#13618-dafny-audit)

### 8. Deployed binary coverage requires explicit links

The planned chain is:

```text
approved intent → versioned spec → checked claim about exact binary bytes
                → evidence bound to binary SHA-256
                → release/container identity → observed deployment identity
```

Stage 7 checks a property of a particular binary through the published pipeline.
The property must match the claim being advertised. A no-crash proof cannot be
used as evidence for C1–C5. Stage 9 checks provenance and release identity, and
must compare the deployed digest with the approved release digest before
claiming that the checked artifact was deployed.

For a container, record both the container digest and the contained binary
digest. Account for linked libraries, entrypoint, configuration, runtime, and
external services within the claim's scope or list them as gaps and assumptions.
A signature authenticates evidence; it does not prove program behavior.
Rebuilding the same bytes establishes reproducibility, not compiler correctness.

Keep `end_to_end=false` when a required link is missing. Even a complete artifact
chain retains its stated model and trusted-base assumptions. No stage may infer
whole-service correctness from a proof of one component.

### 9. Incremental verification must preserve coverage

Stage 4 needs a complete dependency map. Cache keys include the member, all
relevant dependencies, the spec, toolchain, options, and policy. Dependency
uncertainty must trigger broader verification or block acceptance. Cached proof
reuse requires matching inputs and trusted origin. Count checked and reused
obligations separately. Do not equate changed lines with affected claims.

### 10. Measure results without inventing benefits

Stage 6 records all attempts, failed runs, prompts, responses, available provider
token categories, verifier time, and human interventions. Missing token data is
unknown, never zero. Fixed inputs and seeds make experiments repeatable; new
LLM runs and wall-clock measurements need not reproduce identical numbers.
Report recorded results separately from reruns and make no extrapolation.

Stage 10 requires two actual weeks of observation. Report the number and kinds
of PRs observed. A period with little activity cannot establish broad usefulness.

## Stage index

| Stage | Name | Status |
| --- | --- | --- |
| 0 | TOOLCHAIN | DONE |
| 1 | LEDGER DEMO | DONE |
| 2 | EVIDENCE SCHEMA + POLICY | DONE |
| 3 | TYPESCRIPT INTEGRATION | DONE |
| 4 | CHANGE LOOP | CURRENT |
| 5 | SPEC TOOLING | NOT STARTED |
| 6 | SECOND DOMAIN + REUSE MEASUREMENT | NOT STARTED |
| 7 | BINARY LAYER | NOT STARTED |
| 8 | ML BOUNDARY | NOT STARTED |
| 9 | PROVENANCE | NOT STARTED |
| 10 | SHADOW MODE | NOT STARTED |

## EXIT command conventions

Commands for unfinished stages below are planned interfaces, not run results.
Create only the commands required by the CURRENT stage. Finalize each exact
invocation, options, and fixture before running it, and record that invocation
in the execution record. Never mark a stage DONE from this planning table.

Scenario scripts may prepare inputs, invoke established tools, and check
expected results. They must not implement a verifier. For every negative test,
record both the raw checker exit code and the scenario script exit code. A
scenario script may return zero when rejection was expected and observed.
Missing tools, syntax errors, and process crashes do not count as the intended
negative result. Record the diagnostic and claim or policy rule that caused it.

### Stage 0 — TOOLCHAIN

**Status: DONE**

Install pinned Dafny with its bundled Z3, Node, and Python. Select host-compatible
distributions and record exact versions and checksums before installation.
Use the official Dafny 4.11.0 release as the Dafny pin. Node 24.3.0 and Python
3.10.11 were already installed and are reused. Their version and executable
checksum checks passed. The Dafny archive matched its official checksum before
extraction. Bundled Z3 4.12.1 is selected explicitly. Pins and resource settings
are in `toolchain/pins.json`. Original Node/Python installer provenance remains a
disclosed trust assumption, not a verified claim; see `unsure.md` U015.
[Dafny release](https://github.com/dafny-lang/dafny/releases/tag/v4.11.0)

Create two tiny smoke fixtures: a true arithmetic lemma with a body, and a false
arithmetic lemma with a body. Use the same locked verification settings for both.
Confirm resource-limit and timeout-disable options against the pinned CLI before
the runs. No ledger, gate, policy, or later-stage scaffolding belongs here.

| EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `dafny --version` | Prints the locked Dafny version; exits 0. | 0 — `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| `node --version` | Prints the selected Node version; exits 0. | 0 — `v24.3.0` |
| `python3 --version` | Prints the selected Python version; exits 0. | 0 — `Python 3.10.11` |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | Trivial true lemma verifies. | 0 — 1 verified, 0 errors |
| `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files` | False postcondition fails verification. | 4 — 0 verified, 1 error; expected rejection |
| `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints the selected bundled Z3 version. | 0 — `Z3 version 4.12.1 - 64 bit` |

Both verification commands wrote raw outputs to `toolchain/results/true.log` and
`toolchain/results/false.log` using shell output redirection. The false result
names the postcondition `1 + 1 == 3`; it is not an infrastructure failure.
Reproduction instructions are in [toolchain/README.md](toolchain/README.md).
The stage transition ends this run. No Stage 1 implementation was created.

### Stage 1 — LEDGER DEMO

**Status: DONE**

The user approved [the initial ledger contract](proposals/initial-ledger.md) as
written. Candidate SHA-256
`e9bdfd511d3cffb04c533dcc62252cabf84a825d5577ea5999d18bc25e0bda0f`
is frozen in `spec/LedgerSpec.dfy` and `spec.lock`. The real Dafny verifier
accepted the concrete refinement with 12 verified obligations and zero errors.
The final gate and all EXIT scenarios passed. The approved spec bytes are
unchanged. [Archived Stage 1 evidence](results/stage1/evidence.json) records C1–C5 as `source_proof` and keeps
`end_to_end=false`. [Actual results](results/stage1.json) record the real codes.

Create `spec/LedgerSpec.dfy` as an abstract module, `impl/Ledger.dfy` as its
refinement, `gate/gate.py`, and `spec.lock`. The lock contains the spec SHA and
Dafny version. Freeze the approved behavior before implementation repairs.

| Claim | Required behavior |
| --- | --- |
| C1 — conservation | A transfer preserves total funds. |
| C2 — non-negative | Every resulting account balance is non-negative. |
| C3 — idempotent retries | Repeating the same request does not repeat its effect. |
| C4 — progress | A valid transfer terminates and succeeds. |
| C5 — invalid → no effect | An invalid transfer is rejected and leaves the specified state unchanged. |

Self-transfers are invalid and must be rejected. Bind diagnostics to claim IDs.
Check the concrete refinement; abstract declarations alone establish no
implementation result. Audit forbidden constructs and all proof dependencies.

Plant `self_transfer` (creates money), `off_by_one` (`<` instead of `<=`),
`retry_double`, and `sneaky_assume`. Keep a fixed, deliberately incomplete unit
suite that passes these fixtures. Demonstrate each rejection through the gate.
Report `sneaky_assume` as a forbidden assumption, with the affected claim named
and unestablished; do not invent a counterexample from an audit failure.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes source-proof evidence; exits 0. | 0 — accepted C1–C5 |
| `python3 scripts/exit_stage_1.py --case reproducibility` | Runs the gate twice and byte-compares evidence; exits 0 on equality. | 0 — both gate runs and `cmp` exited 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | Unit suite passes each fixture; gate rejects all four and names affected claims/rules. | 0 — all four unit runs exited 0; all four gates exited 1 |
| `python3 scripts/exit_stage_1.py --case spec-lock` | A changed spec with its old lock is rejected in a disposable copy. | 0 — gate exited 1 with `SPEC_LOCK` |
| `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects a candidate without the approved refinement relationship. | 0 — gate exited 1 with `SOURCE_SCOPE` |
| `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects bodiless lemmas, axiom lemmas, and disabled verification. | 0 — each direct auditor exited 2; each gate exited 1 |

The final negative-control results were:

| Fixture | Basic unit exit | Checker exit | Gate exit | Claim or policy diagnostic |
| --- | --- | --- | --- | --- |
| `self_transfer` | 0 | 4 — verification | 1 | C1 and C5 not established |
| `off_by_one` | 0 | 4 — verification | 1 | C4 not established |
| `retry_double` | 0 | 4 — verification | 1 | C1 and C3 not established |
| `sneaky_assume` | 0 | 2 — audit comparison | 1 | Forbidden assumption; C1–C5 not established |

The basic unit suite exercises an ordinary transfer and a missing-account
rejection. It deliberately misses these bugs. Unit success is recorded as
`unit_tested`; it is not proof. A failed proof obligation means that the checker
did not establish the claim. An audit failure does not supply a counterexample.

The gate delegates proof decisions to pinned Dafny and Z3. It checks the exact
approved spec, an explicit refinement declaration, the required verified
obligations, and an empty Dafny audit report. See [gate/README.md](gate/README.md)
for commands, evidence identity, source-format restrictions, and trusted inputs.
The spec-lock test changes only a disposable copy. It does not establish
authorization for changing both the spec and lock in a proposed change.

Canonical evidence SHA-256:
`8389e88aac8526ce48dd8ef70c8e6e40f53ccf5360465b79cb8cec27b3c66df3`.
Those exact bytes and the original gate/scenario sources were preserved under
`results/stage1/` before the Stage 2 refactor. Root `evidence.json` now holds the
current policy-bound format. The archived scripts are historical source records.
Raw commands, exit codes, and diagnostics are retained locally under
`build/stage1/<case>/`; repeated runs archive prior logs under
`build/stage1-history/`. These generated directories are not publication inputs.
The portable result summary is [results/stage1.json](results/stage1.json).

This stage transition ends the run. Stage 2 is CURRENT; no Stage 2 files were
created. The user authorized continuation through the full roadmap, with binary
and deployment work deferred to their planned stages; see `unsure.md` U024.

### Stage 2 — EVIDENCE SCHEMA + POLICY

**Status: DONE**

Define JSON Schema for the core model and bundle metadata. Create
`policy/tiers.yaml`. Refactor the gate into a backend-independent policy layer
with Dafny as one adapter. Preserve Stage 1 rejection behavior. Use an established,
pinned JSON Schema validator. JSON validation establishes structure only.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_2.py --case schema` | The schema validates actual Stage 1 evidence. | 0 — exact Stage 1 archive and current evidence validate; two malformed inputs rejected with 1 |
| `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Hand-edited `source_proof` evidence with a wrong artifact SHA is rejected. | 0 — three artifact-binding controls rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case method-policy` | A tier requiring `source_proof` rejects `unit_tested` evidence. | 0 — unit, bounded-check, and unrelated kernel-proof labels rejected with gate exit 1 |
| `python3 scripts/exit_stage_2.py --case round-trip` | Supplied valid evidence must reproduce through a fresh real checker run. | 0 — gate and byte comparison each exited 0 |
| `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects altered policy, claims, trusted inputs, coverage, producer, or document keys. | 0 — all 15 negative gate calls exited 1 for the intended rule |

The refactored gate command also exited 0:
`python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json`.
It produced schema version `2.0.0` evidence bound to policy `forge-ledger` version
`1.0.0`, tier `critical`, with policy and trusted-input hashes. The five records
remain `source_proof`; `end_to_end=false`. The real Dafny run established 12
obligations. The schema also accepts archived format-1 evidence without upgrading
its authority or adding a policy binding that was absent from the original run.

Established validators: jsonschema 4.21.1 and PyYAML 6.0.1. Their installed
dependencies and file hashes are pinned in `toolchain/requirements-stage2.txt`
and `toolchain/validator-pins.json`. These preinstalled packages ran successfully;
no installation or archive authentication is claimed. See U025 for the limit.

The core checks structure, current artifact and approved-claim bindings, explicit
allowed methods, and selected policy identity. The Dafny adapter retains proof,
audit, source-scope, and result-coverage checks. Imported evidence must also match
a fresh checker result. The producer-name tampering control reached that final
comparison and was rejected. Schema-only validation prints `SCHEMA_VALID`, never
`ACCEPTED`, and writes no accepted bundle.

All Stage 1 scenario commands were rerun against the refactored gate:

| Regression command | Actual exit code | Required raw behavior retained |
| --- | --- | --- |
| `python3 scripts/exit_stage_1.py --case reproducibility` | 0 | Gate 0 twice, `cmp` 0 |
| `python3 scripts/exit_stage_1.py --case planted-bugs` | 0 | Units 0 each; three verifier exits 4; sneaky audit 2; gates 1 each |
| `python3 scripts/exit_stage_1.py --case spec-lock` | 0 | Gate 1 for stale lock in disposable copy |
| `python3 scripts/exit_stage_1.py --case contract-binding` | 0 | Gate 1 for missing approved refinement |
| `python3 scripts/exit_stage_1.py --case audit-controls` | 0 | Direct audits 2 and gates 1 for all three proof-escape controls |

`cmp evidence.json build/stage1/reproducibility/evidence.json` also exited 0.
The approved spec and `spec.lock` are unchanged. The evidence digest is
`0400b148904360eb3fde1940acaf73ba0a1342f9244da8cf1f69046a6c9d4e16`.
Actual results are in [results/stage2.json](results/stage2.json). Raw local logs
are under `build/stage2/` and `build/stage1/`; previous runs are archived.

Stage 2 is DONE. Stage 3 is CURRENT. This transition ends the run. No TypeScript
integration, later-stage adapter, binary layer, or deployment code was created.

### Stage 3 — TYPESCRIPT INTEGRATION

**Status: DONE**

Compile the Dafny ledger core to JavaScript. Import it from `app/main.ts`.
Add handwritten `ts/ledger.ts` and pinned fast-check property tests against the
Dafny model. Record fixed seeds and run counts. Cover sequences of operations,
including retries and invalid requests, and preserve the spec's numeric domain.
Record handwritten TypeScript results as `tested_against_proved_model`.
The source proof remains attached to Dafny source; generated JS is a distinct
artifact with a recorded build link and explicit compiler/runtime assumptions.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `node --import tsx app/main.ts` | Uses locked local dependencies; prints `Ok` then `Rejected`; exits 0. User-approved replacement for the original CLI invocation. | 0 — exact expected output; rerun after approval also exited 0 |
| `python3 scripts/exit_stage_3.py --case correct-typescript` | Real property tests pass on correct TypeScript. | 0 — 300 runs, 3,506 compared transitions, no skips |
| `python3 scripts/exit_stage_3.py --case self-transfer` | Real property tests fail on the planted TS self-transfer bug. | 0 — actual fast-check exit 1 and gate exit 1; real shrunk counterexample |
| `python3 scripts/exit_stage_3.py --case evidence-labels` | Source proof and TS comparison results have distinct, correct methods and digests. | 0 — source and comparison gates 0; critical-tier rejection 1 |

The pinned JS packages are installed and runnable. The original install attempt
exited 1 with `getaddrinfo ENOTFOUND registry.npmjs.org`; the user then installed
them externally. `npm ls --depth=0` exited 0 with the requested exact versions.
Their lock and observed installed content are pinned in `package-lock.json` and
`toolchain/javascript-pins.json`. Original tarball integrity was not independently
replayed here.

The compiled-model build command, `python3 scripts/build_model.py`, exited 0.
Dafny verified 12 obligations, then generated JS. The script preserves that output
and adds only a tracked CommonJS export footer. The model module digest is
`2387fcdf5fcfb6d9bc4a05e752b55549cd001ada104431a5bf1311e92ce2b567`.
The original approved spec and `spec.lock` are unchanged.

`node --import tsx app/main.ts` exited 0 and printed exactly `Ok` then `Rejected`.
This supported loader works within current permissions. The tsx CLI version
probe exited 1 with `listen EPERM` for its local socket. The user authorized IPC,
but the host refused an elevated retry because `sandbox_approval=false`.
That refused retry did not run and has no process exit code.

The original `npx tsx app/main.ts` command subsequently ran and exited 1 with
`listen EPERM`. Its `cli-demo` scenario also exited 1. The user then approved the
previously proposed replacement, `node --import tsx app/main.ts`. That exact
replacement ran again with exit 0 and the expected output. This is an approved
invocation change, not a claim that the original CLI command passed. The spec,
lock, policy, comparison corpus, and evidence methods are unchanged. See U030.

Supplemental real checks:

| Command | Actual exit code | Observed result |
| --- | --- | --- |
| `npx --no-install tsc --noEmit` | 2, then 0 | Fixed the reported example tuple type; implementation unchanged |
| `python3 scripts/exit_stage_3.py --case reproducibility` | 0 | Two real builds and gate runs; generated module and evidence byte-identical |
| `python3 scripts/exit_stage_3.py --case loader-demo` | 0 | Real loader invocation printed exactly the two expected lines |
| `python3 gate/gate.py --schema-only results/stage3/typescript-evidence.json` | 0 | Schema validation only; no proof claim |

All five Stage 1 and all five Stage 2 scenario commands were rerun and exited 0.
The real child codes, comparison counters, and preserved negative counterexample
are in [results/stage3.json](results/stage3.json) and `results/stage3/`.
Source evidence is `source_proof`; TypeScript evidence is
`tested_against_proved_model`. The critical tier rejects the latter. The compiler,
runtime, and conversion bridge remain assumptions, and `end_to_end=false`.
See [ts/README.md](ts/README.md) for the exact corpus and module-layout scope.

All Stage 3 EXITs, including the approved replacement invocation, are established.
Stage 3 is DONE; Stage 4 is CURRENT. This transition ends the run. No Stage 4
implementation or later-stage spec change was started.

### Stage 4 — CHANGE LOOP

**Status: CURRENT**

Investigation: `python3 scripts/probe_stage_4.py` ran with exit 0. It invokes
real Dafny commands on isolated copies. Full verification accepted the original
ledger (exit 0) and rejected a broken helper proof (exit 4). Selecting only
`Ledger.Apply` returned exit 0 in both cases. Selection therefore cannot replace
dependency coverage. The diagnostic accepts no artifacts and completes no
Stage 4 EXIT. Exact child commands and obligation counts are recorded in
`results/stage4-member-probe.json`; see `unsure.md` U033.

Local implementation: `gate/incremental.py` uses Dafny/Boogie snapshot caching,
audits both revisions, binds evidence to SHA-256 source identities, and rejects
changes to trusted inputs. `python3 scripts/check_stage_4_local.py` ran with
exit 0. A valid Apply edit checked 2 obligations and reused 10; broken helpers,
weakened helper contracts, and planted bugs were rejected. Repeated evidence
was byte-identical. The first local test driver run exited 1 because it expected
the wrong exit code for Dafny's bare-assume warning; that failure is preserved.
These local controls do not satisfy the real-PR EXITs below. See
`docs/stage4-change-loop.md`, `results/stage4-local.json`, and `unsure.md` U034–U036.

The exact saved reproduction command also ran with exit 0 and reproduced
identical evidence. Linux inventory then succeeded in
[Actions run 40397041174](https://github.com/mack-dot/forge/actions/runs/40397041174):
the inventory command exited 0, the true lemma exited 0, and the false lemma
exited 4. Exact child commands and measured pins are in
`results/stage4/ci-inventory.json`. The new Linux profile is now selected explicitly
by the PR gate. Its real-PR results are recorded below. The workflow runs
trusted checking and reporting code in separate jobs. These preparation checks
do not satisfy the real-PR EXITs.

Pre-publication regression record: `results/stage4/regressions.json` retains all
20 exact commands and real codes. The updated local controls exited 0. All five
Stage 1 scenarios exited 0. An initial Stage 2 method-policy check exited 1
because its fixture used stale evidence and reached `TRUSTED_INPUTS` first.
After the real source gate refreshed evidence (exit 0), all five Stage 2 scenarios
and all five supported Stage 3 scenarios exited 0. See U041 for the setup error;
no acceptance rule was relaxed. The actual loader demo printed `Ok` then `Rejected`.

Create a GitHub Action that computes affected claims from dependencies and
content hashes, invokes per-lemma/per-member verification, and posts a
plain-English claims table. Pin actions and dependencies. Use trusted gate and
policy inputs and isolate untrusted PR execution from credentials.

Demonstrate a fee requirement through `proposals/fees.md`. Stop for human
approval before changing the spec. After approval of that exact diff, create
spec v2, update the lock through the approved path, and reverify. Bind approval
to the revision; a later edit requires fresh approval. Block an agent attempt
to weaken C2. An approval label alone is insufficient evidence of approved text.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_4.py --case affected-claims` | A real PR without a spec change verifies only affected claims; logs checked/reused counts. | 0 |
| `python3 scripts/exit_stage_4.py --case unapproved-spec` | The real workflow rejects an unapproved spec change and the C2 weakening attempt. | 0 |
| `python3 scripts/exit_stage_4.py --case approved-spec` | After human approval, the real workflow accepts the new spec and records its new SHA. | NOT RUN |

Record PR and workflow run references. Local scenarios cannot substitute for
the required GitHub Action runs. Keep this stage CURRENT while approval is pending.

Actual EXIT execution: [run 40403180524](https://github.com/mack-dot/forge/actions/runs/40403180524),
job 121854084912, trusted revision `b2906e2f64f9e1ecd364d2dced55a391f736c236`.
Both exact commands above exited 0. `results/stage4/exit-run.json` and
`exit-affected-claims.json` / `exit-unapproved-spec.json` retain the API bindings,
actual checker receipts, comments, statuses, and real exit codes.

PR 1 / run 40402849081 accepted the valid Apply edit: gate 0; baseline checked 12;
candidate checked 2 and reused 10; literal replay 0 and byte-identical evidence.
PR 2 / run 40402945633 rejected an unapproved spec plus matching lock with gate 1.
PR 3 / run 40402975014 rejected C2 weakening with gate 1. Both failures reported
`UNAPPROVED_PROTECTED_CHANGE`, emitted no accepted evidence, and had successful
reporting jobs. The negative workflow failures are the required observations.

Pending intent approval: [proposals/fees.md](proposals/fees.md) contains the exact
unapplied spec and lock diff. Candidate spec SHA-256:
`2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.
It proposes one unit per fresh successful transfer, paid by the sender to fee
account 0. Retries and rejections pay no fee. The approved spec and lock remain
unchanged. Stop for approval of this exact text before applying it; no Stage 5 work.

### Stage 5 — SPEC TOOLING

**Status: NOT STARTED**

Render every claim in plain English. Generate accept/reject examples. Add a
checked witness of a non-trivial successful execution. Mutate implementations
and report which mutants the spec catches. Use isolated fixtures for deliberately
vacuous specs; do not weaken the approved spec.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_5.py --case vacuity` | Flags a spec that accepts implementations which reject everything. | NOT RUN |
| `python3 scripts/exit_stage_5.py --case mutations` | Lists killed and surviving mutants and the kill rate. | NOT RUN |

Report invalid mutants and inconclusive checks separately from kills. A witness
rules out the demonstrated vacuity; it does not prove that the spec captures all
human intent. A kill rate is a measured diagnostic, not a completeness theorem.

### Stage 6 — SECOND DOMAIN + REUSE MEASUREMENT

**Status: NOT STARTED**

Build a booking matcher with four claims: no double-booking; a valid request
gets a slot when one exists; cancellation frees the slot; retries are idempotent.
Reuse ledger lemma modules only where their premises actually apply.

Compare cold verification, shared files, and dependency-graph reuse on the same
workload and pinned environment. Count all tokens, attempts, verifier time, and
human interventions, including failures and setup attributable to each condition.
Record cache state, seeds, resource use, sample count, and hardware.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/benchmark_reuse.py` | Executes the three benchmark conditions and produces an auditable report. | NOT RUN |
| `python3 scripts/exit_stage_6.py --case report` | Recomputes report totals from recorded runs and confirms that no extrapolation is presented. | NOT RUN |

Separate reproduction of recorded totals from fresh experimental reruns.
Any reuse benefit is a result to measure, not an assumed outcome.

### Stage 7 — BINARY LAYER

**Status: NOT STARTED**

Use a Docker-capable host and Theorem's published Rocq/RISC-V pipeline. Pin an
upstream commit, image digest, semantics, and dependencies. Replay one published
upstream proof, then prove a no-crash property of a small C or Rust core through
that pipeline. Never replace missing upstream support with custom semantics or
a custom decoder. Record exact binary digests, theorem scope, assumptions, and
trusted components. Keep unrelated ledger claims unestablished at the binary layer.

Upstream publishes proofs about particular binaries under its Linux-process
model. These do not automatically cover another architecture or build.
[Published pipeline](https://github.com/theorem-labs/oss-verify-proofs)

The documented `oft check` path audits assumptions. Its independent `rocqchk`
pass is optional and can be expensive. Our EXIT requires that pass for the own
proof; an upstream replay alone is insufficient. “Audit clean” means no
assumptions outside the explicitly recorded upstream allowlist, not an empty
trusted base. [Upstream checking procedure](https://github.com/theorem-labs/oss-verify-proofs/blob/main/docs/checking.md)

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_7.py --case upstream-replay` | Invokes the pinned published pipeline and accepts a real upstream proof. | NOT RUN |
| `python3 scripts/exit_stage_7.py --case invalid-proof` | The real checker rejects a deliberately invalid proof for the intended reason. | NOT RUN |
| `python3 scripts/exit_stage_7.py --case own-proof` | Own binary proof passes the pipeline, `rocqchk`, and assumption audit. | NOT RUN |

Record the exact container, upstream, and `rocqchk` commands and all real codes.
Use `binary_proof` and `kernel_checked_proof` only for the scopes actually checked.
If the host, tooling, resource needs, or proof blocks progress, report the exact
blocker. Leave Stage 7 CURRENT and stop. A truthful blocked report is permitted;
it is not a completed stage and does not unlock Stage 8.

### Stage 8 — ML BOUNDARY

**Status: NOT STARTED**

Wrap an LLM-backed refund suggester in verified code. Enforce refund ≤ charge,
allowed reasons, and a safe fallback for timeout or invalid output. Treat model
responses as untrusted inputs. Define the charge and refund numeric domains in
the approved spec, including lower bounds. Keep effects behind the checked
boundary and name the assumptions of the external timeout mechanism.

Model quality is `eval_measured`. Wrapper properties use the method actually
checked. Tests of hostile responses supply additional testing evidence.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_8.py --case wrapper-proof` | The established verifier accepts the wrapper bounds and allowed outcomes. | NOT RUN |
| `python3 scripts/exit_stage_8.py --case hostile-outputs` | Fuzzed malicious outputs never violate bounds in the executed test corpus. | NOT RUN |
| `python3 scripts/exit_stage_8.py --case evidence-separation` | Evidence distinguishes proved wrapper properties, fuzz testing, and measured model quality. | NOT RUN |

Record fuzz seeds, counts, and limits. Do not turn “no violations observed” into
a universal proof. Keep application timeout behavior distinct from proof-run
resource limits.

### Stage 9 — PROVENANCE

**Status: NOT STARTED**

Sign evidence bundles using pinned sigstore/in-toto tooling. Before allowing a
deployment, verify the signer identity, artifact digest, and policy version.
Bind container packaging to the checked binary and verify deployed identity when
reporting deployment coverage. Keep canonical evidence separate from signature
envelopes and external transparency records, which may contain time metadata.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/exit_stage_9.py --case valid-bundle` | A valid signed bundle for the intended artifact and policy passes the release check. | NOT RUN |
| `python3 scripts/exit_stage_9.py --case unsigned` | An unsigned bundle is rejected. | NOT RUN |
| `python3 scripts/exit_stage_9.py --case wrong-signer` | A bundle from an unauthorized signer is rejected. | NOT RUN |
| `python3 scripts/exit_stage_9.py --case wrong-digest` | A valid signature over the wrong artifact digest is rejected. | NOT RUN |
| `python3 scripts/exit_stage_9.py --case wrong-policy` | A bundle for an unaccepted policy version is rejected. | NOT RUN |
| `python3 scripts/exit_stage_9.py --case deployed-identity` | Actual deployed digest matches the accepted release; a mismatch is reported and prevents a coverage claim. | NOT RUN |

Run the established signature verifier for the actual accept/reject decision.
Signing an unsupported claim does not make it established.

### Stage 10 — SHADOW MODE

**Status: NOT STARTED**

Run the gate on a real host repository's PRs in report-only mode for two actual
weeks. Do not block merges during this experiment. Log what the gate would have
blocked, why, and which claims and methods were involved. Distinguish an actual
defect from missing evidence, an intentional policy rejection, and a tool failure.

| Planned EXIT command | Required behavior | Actual exit code |
| --- | --- | --- |
| `python3 scripts/report_shadow.py` | Reads the real observation log and reports blocks, false positives, and cost per PR for the full period. | NOT RUN |

Include observation dates, sample size, human adjudication, unknown cases, and
cost denominators in the operational report. Those records are separate from
timestamp-free canonical evidence. Do not simulate elapsed weeks or claim a
false-positive rate without a defined review process and denominator.

## Execution record

Stage 0–3 EXIT checks are complete. The true arithmetic lemma was
verified; the false arithmetic lemma was rejected for its false postcondition.
The ledger refinement establishes C1–C5 at source level under the recorded
assumptions. No binary, deployment, or whole-application claim is established.
Stage 2 schema, policy, identity, and replay checks passed, including every
Stage 1 regression. Stage 3's model-comparison checks and approved demo invocation
also passed. Stage 4 is CURRENT.

Commands ran from the repository root. The required `dafny --version` invocation
used `export PATH="$PWD/.toolchain/dafny-4.11.0/dafny:$PATH"` in that shell. Other
Dafny checks below used its explicit local path. No global PATH was changed.

For each future run, append the following facts here before advancing a stage:

| Stage / case | Exact command | Expected behavior | Actual exit code | Observed result / log reference |
| --- | --- | --- | --- | --- |
| 0 / Node version | `node --version` | Prints selected version | 0 | `v24.3.0` |
| 0 / Python version | `python3 --version` | Prints selected version | 0 | `Python 3.10.11` |
| 0 / installation prerequisite, first attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | `curl: (6) Could not resolve host: github.com`; see `unsure.md` U008–U009 |
| 0 / installation prerequisite, second attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U009–U010 |
| 0 / installation prerequisite, third attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U010–U011 |
| 0 / installation prerequisite, fourth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; see `unsure.md` U011–U012 |
| 0 / installation prerequisite, fifth attempt | `curl --fail --location --silent --show-error --output .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip https://github.com/dafny-lang/dafny/releases/download/v4.11.0/dafny-4.11.0-arm64-macos-13.zip` | Downloads the pinned archive before checksum validation | 6 | Same DNS error; the user subsequently supplied the archive; see `unsure.md` U012–U013 |
| 0 / archive checksum before extraction | `shasum -a 256 -c` with the checksum line shown in `toolchain/README.md` supplied on standard input | Matches the pinned archive SHA-256 | 0 | Archive: OK |
| 0 / extraction | `unzip -q .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip -d .toolchain/dafny-4.11.0` | Extracts the validated distribution | 0 | Completed |
| 0 / Dafny version | `dafny --version` | Prints locked version | 0 | `4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2` |
| 0 / bundled Z3 version | `.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version` | Prints selected solver version | 0 | `Z3 version 4.12.1 - 64 bit` |
| 0 / CLI option validation | `.toolchain/dafny-4.11.0/dafny/dafny verify --help` | Confirms resource limit, time-limit 0, solver path, and worker options | 0 | Options confirmed from installed CLI |
| 0 / true lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/true.log 2>&1` | Verifies the true postcondition | 0 | [Raw output](toolchain/results/true.log): 1 verified, 0 errors |
| 0 / false lemma | `.toolchain/dafny-4.11.0/dafny/dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files > toolchain/results/false.log 2>&1` | Rejects the false postcondition | 4 | [Raw output](toolchain/results/false.log): 0 verified, 1 error; expected rejection |
| 0 / Node version, final run | `node --version` | Matches selected version | 0 | `v24.3.0` |
| 0 / Python version, final run | `python3 --version` | Matches selected version | 0 | `Python 3.10.11` |
| 0 / pinned local checksums | `shasum -a 256 -c toolchain/checksums.sha256` | Matches the archive and all four listed executables | 0 | All five entries: OK |
| 1 / draft syntax, attempt 1; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | `rbrace expected` at the attempted postcondition label; replaced labels with comments |
| 1 / draft syntax, attempt 2; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 2 | Ambiguous indentation warning at the C5 implication; parenthesized its premise |
| 1 / draft syntax, attempt 3; not an EXIT | `.toolchain/dafny-4.11.0/dafny/dafny resolve proposals/initial-ledger/LedgerSpec.dfy` | Parses and type-checks the proposed contract | 0 | `Dafny program verifier did not attempt verification`; no proof claim |
| 1 / planted bugs, first scenario run | `python3 scripts/exit_stage_1.py --case planted-bugs` | Rejects all fixtures and names the expected claims or rules | 1 | `self_transfer: expected claim/rule was not named`; corrected one-based diagnostic line mapping; see U020 |
| 1 / contract binding, first scenario run | `python3 scripts/exit_stage_1.py --case contract-binding` | Names the missing approved refinement relationship | 1 | Rejected for missing coverage instead of the expected refinement diagnostic; added explicit refinement preamble requirement; see U020 |
| 1 / final accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Accepts C1–C5 and writes evidence | 0 | Real Dafny proof accepted; `source_proof`; `end_to_end=false` |
| 1 / final reproducibility | `python3 scripts/exit_stage_1.py --case reproducibility` | Two accepted runs produce identical evidence bytes | 0 | Gate exits 0 and 0; actual `cmp` exit 0 |
| 1 / final planted bugs | `python3 scripts/exit_stage_1.py --case planted-bugs` | All four fixtures pass basic units but fail the gate | 0 | Units 0 each; gate 1 each; verifier 4 for first three, audit 2 for sneaky_assume |
| 1 / final spec lock | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects changed spec with stale lock | 0 | Disposable-copy gate exit 1; `SPEC_LOCK` |
| 1 / final contract binding | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing approved refinement | 0 | Disposable-copy gate exit 1; `SOURCE_SCOPE` |
| 1 / final audit controls | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects all three proof escape controls | 0 | Actual auditor exit 2 and gate exit 1 for each control |
| 1 / published evidence candidate comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Root evidence equals tested reproducibility output | 0 | Files are byte-identical |
| 2 / archived evidence schema | `python3 gate/gate.py --schema-only results/stage1/evidence.json` | Validates exact Stage 1 record structure only | 0 | `SCHEMA_VALID`; no proof acceptance claimed |
| 2 / accepted ledger | `python3 gate/gate.py --impl impl/Ledger.dfy --evidence evidence.json` | Runs actual backend and enforces schema and critical policy | 0 | C1–C5 accepted; policy-bound format 2; 12 obligations |
| 2 / schema | `python3 scripts/exit_stage_2.py --case schema` | Both actual formats validate; malformed controls fail | 0 | Schema-only children 0 and 0; malformed-input gates 1 and 1 |
| 2 / artifact mismatch | `python3 scripts/exit_stage_2.py --case artifact-mismatch` | Rejects changed record digest, coherent forged digest, and manifest digest | 0 | Three gates exited 1 with `ARTIFACT_MISMATCH` |
| 2 / method policy | `python3 scripts/exit_stage_2.py --case method-policy` | Rejects methods not allowed by critical policy | 0 | Three gates exited 1 with `METHOD_POLICY`; no ranking or upgrade |
| 2 / round trip | `python3 scripts/exit_stage_2.py --case round-trip` | Supplied evidence equals a fresh actual checker result | 0 | Gate 0; `cmp` 0 |
| 2 / policy controls | `python3 scripts/exit_stage_2.py --case policy-controls` | Rejects all 15 deliberately altered inputs | 0 | All gate calls exited 1; intended diagnostics retained |
| 2 / Stage 1 reproducibility regression | `python3 scripts/exit_stage_1.py --case reproducibility` | Retains byte-identical evidence across runs | 0 | Gate 0 twice; `cmp` 0 |
| 2 / Stage 1 planted-bug regression | `python3 scripts/exit_stage_1.py --case planted-bugs` | Retains all four intended rejections | 0 | Units 0; gates 1; verifiers 4 or audit 2 |
| 2 / Stage 1 spec-lock regression | `python3 scripts/exit_stage_1.py --case spec-lock` | Rejects a changed spec with old lock | 0 | Gate 1 with `SPEC_LOCK` |
| 2 / Stage 1 contract-binding regression | `python3 scripts/exit_stage_1.py --case contract-binding` | Rejects missing explicit approved refinement | 0 | Gate 1 with `SOURCE_SCOPE` |
| 2 / Stage 1 audit regression | `python3 scripts/exit_stage_1.py --case audit-controls` | Rejects the three proof escapes | 0 | Audits 2; gates 1 |
| 2 / final evidence comparison | `cmp evidence.json build/stage1/reproducibility/evidence.json` | Current root evidence equals tested reproducibility output | 0 | Byte-identical |
| 3 / JS toolchain installation | `npm install --cache .toolchain/npm-cache --prefer-offline --ignore-scripts --no-audit --no-fund --fetch-retries=0` | Installs pinned direct dependencies | 1 | `getaddrinfo ENOTFOUND registry.npmjs.org`; user later installed externally |
| 3 / installed dependency check | `npm ls --depth=0` | Prints exact requested installed versions | 0 | All five direct pins match |
| 3 / tsx CLI prerequisite | `npx --no-install tsx --version` | Runs the pinned CLI | 1 | tsx 4.21.0 printed, then `listen EPERM` for local IPC |
| 3 / real JS model build | `python3 scripts/build_model.py` | Compiles the actual approved model with pinned Dafny settings | 0 | 12 verified, 0 errors; module digest recorded |
| 3 / loader demo | `node --import tsx app/main.ts` | Runs actual generated ledger through the bridge | 0 | `Ok`, then `Rejected`; not a substituted npx result |
| 3 / TypeScript check, attempt 1 | `npx --no-install tsc --noEmit` | Type-checks the implementation, bridge, app, and properties | 2 | The example input array needed a one-element tuple shape |
| 3 / TypeScript check, attempt 2 | `npx --no-install tsc --noEmit` | Same static check after the reported tuple fix | 0 | No diagnostics |
| 3 / correct TypeScript | `python3 scripts/exit_stage_3.py --case correct-typescript` | Actual comparison properties and gate pass | 0 | 300 seeded runs; 3,506 comparisons |
| 3 / planted self-transfer | `python3 scripts/exit_stage_3.py --case self-transfer` | Actual comparison rejects the planted bug | 0 | fast-check 1; gate 1; counterexample retained |
| 3 / evidence labels | `python3 scripts/exit_stage_3.py --case evidence-labels` | Distinct methods, bound source/model/TS artifacts, no proof upgrade | 0 | Source and TS gates 0; critical-tier TS gate 1 |
| 3 / deterministic reproduction | `python3 scripts/exit_stage_3.py --case reproducibility` | Builds and evidence reproduce byte for byte | 0 | Both gate calls 0; actual cmp 0 |
| 3 / loader scenario | `python3 scripts/exit_stage_3.py --case loader-demo` | Records actual loader stdout | 0 | Exact expected lines; npx EXIT still pending |
| 3 / original CLI demo | `npx tsx app/main.ts` | Runs the original demo invocation | 1 | `listen EPERM` for its local IPC socket; raw report under `build/stage3/cli-demo/` |
| 3 / original CLI scenario | `python3 scripts/exit_stage_3.py --case cli-demo` | Requires original CLI exit 0 and expected output | 1 | Actual child command failed; not counted as a passing EXIT |
| 3 / approved replacement, final run | `node --import tsx app/main.ts` | Runs the user-approved replacement invocation | 0 | Printed exactly `Ok` then `Rejected`; supersedes the original demo invocation only |

Record failed attempts as well as successful ones. Keep negative-checker codes
separate from their scenario script's code. Do not erase earlier failures.
The first failed scenario reports predate automatic log archiving. Their raw
files were overwritten during development. The observed failures above and in
U020 are retained; no missing raw log has been reconstructed or claimed.
Stage 2 preparation had one parse-time script error, exit 1, from a Unicode dash
inside a Python bytes literal. No statements ran. The corrected UTF-8 script
exited 0. This was not a checker or toolchain failure; see U025 and the Stage 2
result record. All Stage 2 EXIT scenarios passed on their first run.

## Open items

- Runtime provenance: Node and Python installer origins were not independently
  authenticated. Their checked versions and executable hashes are pinned. Keep
  the disclosed trust assumptions in `toolchain/pins.json` and `unsure.md` U015.
- Stage 4: implement the change loop, trusted spec-approval baseline, and affected
  claim verification. Obtain approval of any concrete spec diff before applying
  it. Real PR and GitHub Action EXITs require an accessible repository.
- Publication: the user created [mack-dot/forge](https://github.com/mack-dot/forge).
  The connected app confirms public visibility, the mack-dot owner, and push
  access. The earlier 404/creation blocker is resolved. Publication uses that
  app because the local CLI could not connect and local `.git` writes are denied.
  Preserve the earlier failed commands as history; publication verification is
  recorded in the append-only `unsure.md` log.
- Distribution: choose an open-source license before describing a published
  repository as licensed for open-source reuse. Public visibility alone does
  not supply a license.

