# Forge executable assurance report

CURRENT none. Stage12 unauthorized. Overall verdict: **PARTIALLY_ESTABLISHED**.
`end_to_end=false`. Complete accepted executable assurance: **NOT_ESTABLISHED**.

The new full independent replay passed: **597 modules**, exactly the
previous **86 allowed closure assumptions**, kernel exit0.
The fixed GCD result and explicit modeled ExitEv0 are now covered by this replay.
The exact concrete observations have a finite projected embedding into the
published LPS execution. Full QEMU/Linux state refinement remains unproved.

## Actual checks in this session

| Command / execution | Actual exit | Evidence |
| --- | ---: | --- |
| `python3 -B prepare_and_check.py`: Behavior fresh rebuild |0|Byte-identical object; reproduction.json |
| Same dispatcher: ExitBridge compilation |0|Exact typed behavioral/exit conjunction |
| Same dispatcher: complete recursive Rocq check |0|597 actual modules;86 assumptions;1540.643432s kernel wall time |
| ExitBridge separate rebuild |0|Byte-identical object; bridge-reproduction.json |
| Held-source postflight |0|All sources unchanged; source-postflight.json |
| `python3 -B observe_controls.py`: producer/baseline/postidentity |0/0/0|Ubuntu chain;413 observer members;404 LOAD bytes;guest/parent0 |
| Same dispatcher: actual register interference / postidentity |1/0|a2 changed21→22;guest/parent2;unchanged zero-exit assertion rejects |
| `python3 -B recheck_controls.py`: wrong result / halted state |1/1|Intended type mismatches; raw logs retained |
| Same dispatcher:9 existing observer marker controls |0|One positive0;eight intended refusals1 |
| `python3 -B identity_controls.py`: corrupted object / substituted ELF |1/1|Held identity refusal before kernel/guest launch |
| Baseline corrupted LOAD capture comparison |1|Expected cmp refusal; correct RO/text comparisons0/0 |
| Trace binding to original checked literals |0|458 pre-exit lines match;21 frames;intermediate a0=21 |
| Portable proof/runtime replay, relocated inputs |0/0|Two identical proof rebuilds;fresh observation;original worktrees not mounted |
| Effective rules / ruleset export |0/0|Independent review required;no required status checks/workflows |
| Classic branch-protection endpoint |1|HTTP404;effective rules were separately obtained |
| Local Git fsck and bundle verification |0|Held local commits/bundle intact;operational-commands.json |
| Original archive validation / local restore |0/0|Each archive10160 members;zero mismatches;not an off-machine test |
| Existing strict integration EXIT |1|Only off_machine_backup_confirmed remains false |

Full exact argv and stdout/stderr are in *-command.json, observation-commands.json,
control-commands.json, identity-control-commands.json, operational-commands.json
and the raw logs. Harness0 does not turn expected negative child exits into0.
All local commands ran on this machine. New hosted execution is NOT RUN.

## Identities

- ELF: `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
- Behavior source/object: `5a230c7e1b99652e720fbe134c383a66247a0f08f460ea98546f136831a731aa` / `f1d3b7e22f0ba9f40607f555c7fc15b85fdf84598bc1a5b6d47d7f1a33af8cca`.
- ExitBridge source/object: `4aeaf5603a9f24bac0a98647438019e256d16f1b727fb241decc3c50313229af` / `b433ae9a1f2f12554e2cc5527c8382829b880355094fa0d4174834386f7f01ee`.
- Full kernel log: `34f857e07117fd417c839fee4a7df645b5bc63390c84e3bf85d45b6c8cf3db8b`.
- Actual closure manifest: `8fd8997cc05a2e2402d1e7c01d369e1b15951123f97d2568a755fe2480176464`.
- Exact assumption list: `4e4901ddd2038bf1312872bbaf2db52bb99172266eed78c69a5ad19fa5775e47`.
- Fresh runtime trace: `526c4a2107262bd8624cc19e9762fa4875d536e0b7697324a1a2b468bdf9ed49`.

The anchored input pool can contain more objects than the actual checked closure.
The module names and loaded dependency digests, not just counts, are retained.
The unchanged checker recursively checks all imports; no -norec or axiom waiver.

## Claim boundary and shortest remaining path

Read CORRESPONDENCE.md for the full A/B/C/D distinction and field matrix.
The fixed result21 is in a0 before termination, not stdout or arbitrary-input GCD.
Reservation/FCSR/data-memory values are quantified. Model applicability,
instruction/capture fidelity, noninterference, Linux exit meaning and physical
progress remain explicit T1–T6 conditions requiring independent review.

The highest-value next change is review of the exact conditional contract and
profile in proposals/fixed-elf-correspondence/. The non-activated spec addition
passes git apply --check; it changes no accepted policy. After intent/profile
review, prepare the narrowly scoped existing producer/consumer binding update
described in APPROVAL-PACKET.md. A fresh authorized producer must execute the
selected checks, then bind the new claim/ELF/runtime/observations to independent
admission. The historical signature authenticates only the historical release.

PR37fc85 remains draft/open/unmerged with no submitted reviews at the fresh read.
The new supplement needs separate exact review. PR36 stays independent. No
publication, merge, dispatch, signing, admission or deployment occurred.

## Reproduction and operations

The proof packet carries all host proof inputs plus the unchanged audit tools.
The runtime packet carries the held ELF/QEMU, full observer tree and signed
observer-package inputs. Both require only the existing pinned checker image
and a compatible Docker runtime. Their manifests are integrity records, not
self-authenticating provenance. Use the separately reviewed archive digest.
Relocation and rebuild/runtime replay passed locally; independent physical-host
replay remains NOT RUN. Full kernel replay ran against the same exact held
objects; the relocated packet's kernel was not redundantly rerun.

- replay-packet.tar.gz: 1306062 bytes; SHA256 `3ae40b4c538928cc4b8c3bb2d4a01f6d771c0c464f2d139e93046cf7291bd4ac`.
- runtime-packet.tar.gz: 70158672 bytes; SHA256 `55eec1b9063b6982c23acf6d8d6624dbbc85fabe9e1fed191c070e57ffc37912`.

The70MB runtime packet stays in the owner evidence workspace, referenced by its
immutable digest. The owner reports another-device backup, but its exact archive
contents/location and restore remain unverified. Local restore success does not
close that condition. BACKUP-HANDOFF.md gives the exact independent restore step.

The first portable extraction failed1 because host Python3.10.11 lacks the
standard tar data-filter argument. The same filter ran successfully in the
existing pinned Python3.12.3 checker image. No filter was removed or tool installed.
All earlier OOM, wrong-range oracle, parser, observer-content and vDSO diagnostics
remain in the append-only evidence history. No old failure was rewritten as pass.
