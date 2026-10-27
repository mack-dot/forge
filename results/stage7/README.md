# Stage 7 records

All three EXIT commands have passed:

| Command | Harness exit | Checker result |
| --- | --- | --- |
| `python3 scripts/exit_stage_7.py --case upstream-replay` | 0 | Proof and binding wrapper: 0; both independent kernel checks: 0. |
| `python3 scripts/exit_stage_7.py --case invalid-proof` | 0 | Prepared proof: 1; True certificate: 0; binding rejection: 1. |
| `python3 scripts/exit_stage_7.py --case own-proof` | 0 | Termination, valid-entry witness and both bindings: 0; independent check of 579 modules: 0; final identities match. |

Stage 7 is DONE. Stage 8 is CURRENT and has not started. `end_to_end=false`. See
[the scope and trust boundaries](../../docs/stage7-binary.md).

Small records are available as ordinary files. The complete operational record
set, including large manifests, binary proof objects, and full checker logs, is
in [the completed tar/xz archive](published/stage7-complete/records.tar.xz).
[The index](published/stage7-complete/records-index.json) gives each
original path, size, and SHA-256. Extract from the repository root with:

```sh
tar -xJf results/stage7/published/stage7-complete/records.tar.xz
```

The packager checks every archived file against its original bytes. It retains
the originals and refuses to replace a record set. Operational metadata is not
canonical proof evidence. No omitted timing or memory measurement means zero.

Upstream attempt 0001 preserves the macOS case-collision failure. Attempt 0002
preserves the recording-wrapper error before proof checking. Attempt 0003 is
the successful complete replay. All original failure bytes remain unchanged.

The exact own [ELF](accepted/own/gcd-selftest.elf), [canonical evidence](accepted/own/evidence.json),
and [complete audit](accepted/own/assumption-audit.json) are also ordinary files.
Each own theorem has 13 permitted primitive assumptions; its complete closure
has 86. The earlier upstream-and-negative archive remains unchanged. Serializing
records twice and comparing them is not a second independent proof replay.
