# Forge

Proof-gated changes for software engineering.

**LLMs propose, checkers dispose. Humans approve intent (specs), not code.**

Agents propose implementations. Established checkers determine which claims are
accepted. Every accepted artifact must carry reproducible evidence naming the
claim, exact artifact, method, tool version, assumptions, and trusted components.
Tests, bounded checks, and proofs retain their distinct meanings.

## Current status

- Stage 0 is complete. Dafny 4.11.0 and bundled Z3 4.12.1 ran successfully.
  The true smoke lemma verified with exit 0. The false lemma was rejected with
  exit 4 for its false postcondition.
- Stage 1 is complete. The [ledger implementation](impl/Ledger.dfy) satisfies
  C1–C5 in the approved [specification](spec/LedgerSpec.dfy), bound by
  [spec.lock](spec.lock). The real Dafny verifier checked 12 obligations.
- The gate produced [source-proof evidence](evidence.json). Repeated runs
  produced identical bytes. All four planted bugs passed the basic unit suite
  and were rejected by the gate. [Actual results](results/stage1.json) record
  checker, gate, and scenario exit codes separately.
- Stage 2 is complete. The [schema](schemas/evidence.schema.json) validates
  both evidence formats. The [tier policy](policy/tiers.yaml) rejects insufficient
  methods, and the gate rejects altered artifact and claim bindings. Imported
  evidence must match a fresh checker run. All Stage 1 regressions still pass.
- Stage 3 is complete. The compiled model and TypeScript implementation run.
  The correct TypeScript passed 300 property runs and 3,506 state comparisons;
  the planted self-transfer bug failed. Evidence labels and reproducibility
  checks passed, as did all prior-stage regressions.
- The user approved `node --import tsx app/main.ts` as the demo EXIT. It exited
  0 and printed `Ok` then `Rejected`. The original CLI's IPC failure is retained
  in the execution record. Stage 4 is current. Its local incremental gate has
  passed dependency and replay controls. The real PR workflow remains pending.
  See [the change-loop notes](docs/stage4-change-loop.md) for scope and limits.
- The repository is public at [mack-dot/forge](https://github.com/mack-dot/forge).
  Publication uses the connected GitHub app. The append-only findings log records
  repository access and snapshot verification.

## Follow the work

| File | Purpose |
| --- | --- |
| [ROADMAP.md](ROADMAP.md) | Stages 0–10, CURRENT stage, required EXIT checks, and actual run results. |
| [unsure.md](unsure.md) | Append-only uncertainties, findings, corrections, and resolutions. |
| [proposals/initial-ledger.md](proposals/initial-ledger.md) | Approved behavior, examples, exact initial spec diff, and digest. |
| [toolchain/README.md](toolchain/README.md) | Local setup and reproduction of the Stage 0 checks. |
| [toolchain/pins.json](toolchain/pins.json) | Pinned versions, verification settings, and disclosed trust assumptions. |
| [gate/README.md](gate/README.md) | Run the Stage 1 gate and its rejection checks; understand their scope. |
| [evidence.json](evidence.json) | Canonical C1–C5 source-proof evidence for the exact recorded inputs. |
| [results/stage1.json](results/stage1.json) | Actual Stage 1 EXIT results and negative-control codes. |
| [results/stage1/evidence.json](results/stage1/evidence.json) | Exact archived Stage 1 evidence before the Stage 2 refactor. |
| [results/stage2.json](results/stage2.json) | Actual schema, policy, replay, and Stage 1 regression results. |
| [ts/README.md](ts/README.md) | JavaScript build, TypeScript comparisons, reproduction, and limits. |
| [results/stage3.json](results/stage3.json) | Actual Stage 3 results, approved demo invocation change, and retained failures. |
| [results/stage3/typescript-evidence.json](results/stage3/typescript-evidence.json) | Comparison-test evidence linked to the separate source proof and generated module. |
| [VISION.md](VISION.md) | Long-term directions and irreducible limits. |
| [AGENTS.md](AGENTS.md) | Instructions for agents working in this repository. |

Agents must work only on the CURRENT stage. Do not modify a protected spec, lock,
policy, or gate to make a check pass. Spec changes require a proposal and human
intent approval. Keep `unsure.md` append-only. Record real commands and exit codes;
never report a planned or simulated check as a result.

## Assurance boundary

Stage 1 establishes the specified sequential ledger transition at Dafny source
level, under its recorded assumptions and trusted base. It does not cover a
compiled binary, deployment, persistence, concurrency, or an entire application.
`end_to_end=false` records those missing links. It is not a failed proof result.
Existing Node and Python runtime provenance limits remain recorded in `unsure.md`.
The evidence is unsigned. The gate reruns its checker before accepting imported
evidence; schema validation alone makes no proof claim. Stage 9 plans signed
provenance. Validator-package provenance limits are also disclosed in `unsure.md`.
The handwritten TypeScript uses `tested_against_proved_model`. The Dafny source
uses `source_proof`. The compiler, generated runtime, and TypeScript conversion
bridge remain assumptions; no proof covers the generated JavaScript module.

## License

A license has not yet been selected. Public visibility alone does not grant an
open-source license. License selection remains an open release item.
