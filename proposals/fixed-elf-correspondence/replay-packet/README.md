# Fixed-ELF independent replay packet

Scope: fixed GCD1071/462 result21 in register a0 before termination, modeled
exit0 and its ExitEv0 realization, plus the existing process-prefix roots.
No authoritative claim/profile or physical-runtime theorem is installed.

Verify the archive SHA256 against the separately held review packet before
extracting or running this code. An in-archive manifest alone is not authority.
The exact Docker checker image must already be available by the pinned digest.
No download or installation occurs during replay. Docker and an amd64-capable
Linux execution environment with the existing1CPU/4GiB profile are required.

Run `python3 -B replay.py --out /absolute/new/output-directory`.
This rebuilds Behavior and ExitBridge, checks both exact object digests and
runs the unchanged full recursive Rocq checker with all roots. It preserves
commands, exit codes, raw kernel output, closure digests and assumptions.
The optional `--rebuild-only` performs compilation/identity checks only.
It cannot count as an independent full replay. No use of `-norec` is permitted.

All host-mounted proof dependencies, available corresponding sources, published
audit tools and Python dependencies are included. Image-internal dependencies
come from the pinned checker image and are hashed by the unchanged runner.
The historical source paths in expected.json are provenance references; no
replay command accesses the original owner's workspace. This is a replay of
held base objects plus fresh new proofs, not a rebuild of the whole toolchain.

QEMU/GDB observation and its raw runtime records are a separate evidence set.
This packet does not prove QEMU/Linux correctness, authenticate a new producer,
claim an independent physical-machine run, sign evidence or admit a release.
