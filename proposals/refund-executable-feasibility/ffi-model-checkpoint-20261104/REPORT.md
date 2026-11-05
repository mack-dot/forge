# Refund correspondence checkpoint — U287

CURRENT stage: **none**. Active milestone: **M1**. Stage 12 is unauthorized.
Integration EXIT: **NOT_ESTABLISHED**. `end_to_end=false`.

The live model check has saved the first two of four required FFI equations.
It has no terminal exit or complete accepted export at this checkpoint. The
compiler behavior proof also remains live. Neither job was stopped or duplicated.
This packet preserves the checkpoint; later results must use a new record.

## Evidence and actual results

Let `R=results/refund-ffi-observation-2026-11-04` in the owner workspace.
The [prior observation packet](../ffi-observation-20261104/REPORT.md) preserves
both full native captures, 38 passing byte comparisons and the first syntax
failure. Those native checks were not rerun for this documentation update.

| Command or check | Actual exit | Meaning |
| --- | --- | --- |
| `python3 -B $R/run_model_check.py positive-0002` | IN_PROGRESS | Saved `observed_ffi_0` and `observed_ffi_1`; equations 2/3 and complete export remain pending |
| `python3 -B $R/run_model_check.py constructor-diagnostic` | 1 | Nonexistent `wordsSyntax.dest_word` API; no semantic proof attempted |
| `python3 -B $R/run_model_check.py constructor-diagnostic-0002` | 1 | Diagnostic renamed the output environment key; no semantic proof attempted |
| `python3 -B $R/run_model_check.py constructor-diagnostic-0003` | 0 | Existing typed constructors build all four equations; no theorem checked or exported |
| Complete equation reconstruction | 0 | All four original equations reconstruct exactly from the twelve byte arrays; input identity only |
| Input-construction replacement guard | 1 | First proof marker already present; assertion prevented the signal and replacement |
| `python3 -B $R/checkpoint-U287.py` | 0 | Saved records, exact source/native identities and both original live jobs checked |
| Prepared constructor proof `positive-0003` | NOT RUN | Kept as a proposal; do not duplicate the progressing original job |
| Altered-read-byte / wrong-write-descriptor controls | NOT RUN | Must reject at the intended HOL equation after the positive check |
| Model proof reproduction / fresh import and closure | NOT RUN | No complete positive export yet |
| Existing `run_behavior.py 0001 repeat` | IN_PROGRESS | Original runner47209/Holmake47239; no terminal result |

The diagnostic failures and successful construction run predate this checkpoint.
Their exact command records, sources and logs are copied under `records/`.
The live model and compiler logs are explicitly snapshots. The guard failure
did not create an interruption record or send a signal. Missing exit codes stay
null in [checkpoint.json](records/checkpoint.json).

## Exact identities and trust limits

- Native refund executable SHA-256:
  `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8`.
- Live model source SHA-256:
  `0c761f4a6516ab53d2d63087c10a396bbf75daa2a03464140b2de52cc07fad73`.
- Prepared constructor source SHA-256:
  `7fad635b24005ac0d7dc3a9a0b5a33e91d19f634ff1c87607e95d0f7b429ac68`.
- Standard HOL heap SHA-256:
  `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`.

The proof uses the existing `basis_ffi_oracle no_ext` and `fsFFI` semantics.
No model, theorem premise, expected output, axiom or acceptance policy changes.
The optional construction path uses `wordsSyntax.mk_wordii` and
`listSyntax.mk_list`. Its diagnostic checks term construction, not truth.

Even a completed four-equation check would prove finite model conformance for
one recorded request. It would not prove that the complete physical filesystem
equals the model witness, or that every native FFI call implements the model.
Full memory frames, physical ARM control state, installation, interference,
resources and native exit remain unresolved. The source/model relation over
the full approved integer and Unicode domain remains required. No domain is
restricted to this fixture. The fixed RISC-V evidence remains supporting work.

## Next actions and completion evidence

| Order | Authorized local action | Required evidence |
| --- | --- | --- |
| 1 | Finish the two original jobs | Real terminal exit; exact conclusions and all retained premises |
| 2 | Check the FFI mutations | Altered returned byte and fd substitution rejected for the intended semantic reason |
| 3 | Reproduce and inspect exports | Exact repeated proof objects, fresh theory import, dependency closure and assumption audit |
| 4 | Complete the remaining source/runtime connection | Source initialization and event extraction; full domain, installed state, FFI/OS, resource and exit relations proved or explicitly bounded |
| 5 | Prepare independent complete-chain review | Exact claim, environment, assumptions, dependency identities, reproduction commands and failed controls |
| 6 | Complete operational and admission requirements | Independent-copy archive hashes and restore; authorized new provenance and admission; effective controls verified at the boundary |

U284 owns the separate source-event and initialization work. This checkpoint
does not rerun or adopt that work. The unrelated swarm experiment does not alter
this mission's active state. M2 admission, M3 reuse and M4 usability remain later
priorities. Hosted refund measurements remain **NOT RUN**.

Local recording and unsigned documentation commits are authorized. Protected
claim/profile or policy changes, publication, push, merge, dispatch, signing,
release admission and deployment require the applicable explicit authorization
and independent review. This packet grants none of them. The owner's report of
a backup on another device does not verify the exact archive hashes or restore.
