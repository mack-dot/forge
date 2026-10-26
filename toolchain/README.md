# Stage 0 toolchain

Run these commands from the repository root on the recorded Darwin ARM64 host.
The exact versions, digests, and verification options are in `pins.json`.
This is a local toolchain setup, not a claim of cross-platform reproducibility.

## Installation

Obtain the official Dafny 4.11.0 ARM64 macOS release archive at the URL in
`pins.json`. Save it as `.toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip`.
Verify its digest before extraction:

```sh
shasum -a 256 -c <<'CHECKSUM'
c90c75e7d5db9c6ccbb7127840dfe43f0ac938b039a7ebed146d8ead383a572f  .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip
CHECKSUM
unzip -q .toolchain/downloads/dafny-4.11.0-arm64-macos-13.zip -d .toolchain/dafny-4.11.0
```

Stop if checksum validation fails. Extract only into a new installation directory.
The archive includes its .NET runtime and two Z3 executables. These checks use
bundled Z3 4.12.1 explicitly.

Node 24.3.0 and Python 3.10.11 were already installed on this host. Stage 0 reuses
them. Their version commands and executable digests are checked; their original
installer archives were not independently authenticated. That remains a disclosed
toolchain trust assumption in `pins.json` and `../unsure.md` U015.

## Reproduce the EXIT checks

Set the current shell's path. This does not change global shell configuration.

```sh
export PATH="$PWD/.toolchain/dafny-4.11.0/dafny:$PATH"
shasum -a 256 -c toolchain/checksums.sha256
dafny --version
.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --version
node --version
python3 --version
```

The checksum manifest is specific to the recorded local runtime paths. It checks
the archive and listed executables, not every file in each runtime installation.

Run the positive control:

```sh
dafny verify toolchain/smoke/True.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files
```

Expected: exit 0, `1 verified, 0 errors`.

Run the negative control as a separate command:

```sh
dafny verify toolchain/smoke/False.dfy --solver-path .toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files
```

Expected: exit 4, `0 verified, 1 error`, with a diagnostic for the false
postcondition `1 + 1 == 3`. Another nonzero exit, a crash, or a missing solver
does not satisfy this control. Do not repair the false lemma to make it verify.

The resource limit is 1,000,000 Z3 resource units. The CLI's time-limit value 0
disables the wall-clock verification limit. Both commands use one worker and the
same solver. The actual run outputs are in `results/true.log` and
`results/false.log`; commands and real exit codes are recorded in `../ROADMAP.md`.

These controls demonstrate that this installed checker accepts and rejects the
selected fixtures. They establish no ledger, application, or deployed-binary claim.
