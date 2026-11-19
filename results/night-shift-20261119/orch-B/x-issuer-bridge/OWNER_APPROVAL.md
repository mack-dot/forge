# What the owner must approve to adopt the issuer bridge (nothing is applied)

## Decisions (owner text needed)
1. The native executable becomes a SECOND necessary condition for every token (N-version issuance).
   A native fault now blocks issuance (availability cost), never authorizes alone.
2. The pin: `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` and its deployed path
   (today the only copy in the repository is `proposals/forge2-m1-conformance/artifacts/refund-arm64-macho`,
   mode 0644, inside the M1 conformance bundle).
3. The stderr policy (any byte refuses), the timeout (10 s) and the env allow-list (`CML_HEAP_SIZE=256`,
   `CML_STACK_SIZE=256`, nothing else).
4. Acceptance of the named assumptions OS-EXEC, OS-DYLD, A-LOADER (as enforced by the launcher), OS-PIPE,
   OS-FD, OS-PGRP, OS-WAIT, OS-FS (incl. the same-uid TOCTOU), OS-CLOCK, A-ENV-HEAP, A-LAUNCHER-HOST.
5. The range: texts at most 256 UTF-16 units, no U+0000, valid Unicode; integers 0..2^63−1 (same as the
   issuer's shape domain). Everything outside: refuse.

## Files that would change (exact list)
| file | change | protected (WORKER_RULES list)? |
|---|---|---|
| `ts/refund-finality/native_bridge.ts` (NEW) | TypeScript port of `launcher.py` + `decide.py` (spawn with `env` allow-list, `detached` process group, pipes, caps, timeout, strict parser port of `frame.strict_parse`) | no |
| `ts/refund-finality/minter.ts` | after `check(...)` returns a body: call the bridge on the same `pre`/`transition`; refuse with `native: <REASON>`; two new arguments (native path, pinned digest) | no |
| `ts/refund-finality/encoding.ts` | `checkerSha256Of` also covers the native digest and `native_bridge.ts` (the issuer identity changes) | no |
| `tests/refund-finality/suite.ts`, `tests/refund-finality/issuer_exports_probe.ts` | start the minter with the new arguments; bridge rows (the 64 tests here, ported) | no |
| `scripts/exit_slice1.py` | reads `minter.ts`; hashes and expected ids change | no (only `scripts/javascript_env.py`, `scripts/build_model.py` are protected) |
| `scripts/exit_m1_conformance.py`, `scripts/demo_gauntlet.py` | reference `minter.ts` (re-check; `exit_m1_conformance.py` is inside the M1 conformance bundle, SHA `96179077…`) | no |
| `package.json`, `package-lock.json`, `tsconfig.json` | NO change needed (standard library only) | yes (untouched) |
| `gate/`, `policy/`, `spec/`, `schemas/`, `.github/`, `governance/`, `spec.lock`, `clearing/` | NO change needed | yes (untouched) |

## Bundles and pins that change
- Slice 1 records: `proposals/forge2-slice1-refund-finality/records/evidence.json`, `regression.json`,
  `links-final.json`, `removed-check-copies.json` record `minter.ts` (and encoding) hashes: a new Slice 1
  regression run and a new evidence bundle are needed.
- Every deployed sink's pinned `checkerSha256` changes (sink config, not `sink.ts` code).
- M1 conformance bundle (`proposals/forge2-m1-conformance`, Wave Gate 1 bundle `f55391da…`): unchanged if the
  executable is not moved and `exit_m1_conformance.py` is not edited; re-check if it is.
- `ASSURANCE_LEDGER.json`: X15, X16, STRICT-FRAME, A-LOADER rows (section 6 of BRIDGE_DESIGN.md), by the
  orchestrator after an applied and re-run change only.
