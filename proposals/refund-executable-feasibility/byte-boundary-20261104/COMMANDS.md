# Byte-boundary command ledger

Local observations only. No native, hosted, signing or admission command ran.
Dafny CSV timing fields are not reproducible proof certificates. HOL exports are compared byte for byte.

## dafny-0001

Actual exit: `4`. Wall seconds: `29.178966541`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-0001/inputs`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/dafny-0001/command.json), [stdout](records/dafny-0001/stdout.log), [stderr](records/dafny-0001/stderr.log).

## dafny-0002

Actual exit: `0`. Wall seconds: `30.169841375`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-0002/inputs`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/dafny-0002/command.json), [stdout](records/dafny-0002/stdout.log), [stderr](records/dafny-0002/stderr.log).

## dafny-repeat

Actual exit: `0`. Wall seconds: `35.883924417`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-repeat/inputs`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/dafny-repeat/command.json), [stdout](records/dafny-repeat/stdout.log), [stderr](records/dafny-repeat/stderr.log).

## frontend-verify

Actual exit: `0`. Wall seconds: `29.730848791`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/frontend-verify/inputs`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/frontend-verify/command.json), [stdout](records/frontend-verify/stdout.log), [stderr](records/frontend-verify/stderr.log).

## dafny-lossy

Actual exit: `4`. Wall seconds: `35.896916667`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-lossy/inputs`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/dafny-lossy/command.json), [stdout](records/dafny-lossy/stdout.log), [stderr](records/dafny-lossy/stderr.log).

## dafny-swapped

Actual exit: `4`. Wall seconds: `36.065867792`.
Working directory: `/Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-swapped/inputs`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny verify Boundary.dfy --solver-path /Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1 --resource-limit 1000000 --verification-time-limit 0 --cores 1 --verify-included-files --log-format 'csv;LogFileName=verification.csv'
```

[Record](records/dafny-swapped/command.json), [stdout](records/dafny-swapped/stdout.log), [stderr](records/dafny-swapped/stderr.log).

## dafny-audit

Actual exit: `0`. Wall seconds: `3.207533833`.
Working directory: `/Users/mackianni/forge`.

```sh
/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny audit /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/inputs/Boundary.dfy --report-format md --report-file /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/dafny-audit/audit.md
```

[Record](records/dafny-audit/command.json), [stdout](records/dafny-audit/stdout.log), [stderr](records/dafny-audit/stderr.log).

## hol-0001

Actual exit: `1`. Wall seconds: `12.790607167`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0001/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0001/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0001/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0001/audit.sml
```

[Record](records/hol-0001/command.json), [stdout](records/hol-0001/stdout.log), [stderr](records/hol-0001/stderr.log).

## hol-0002

Actual exit: `1`. Wall seconds: `12.541875375`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0002/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0002/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0002/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0002/audit.sml
```

[Record](records/hol-0002/command.json), [stdout](records/hol-0002/stdout.log), [stderr](records/hol-0002/stderr.log).

## hol-0003

Actual exit: `0`. Wall seconds: `12.478697833`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0003/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0003/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0003/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-0003/audit.sml
```

[Record](records/hol-0003/command.json), [stdout](records/hol-0003/stdout.log), [stderr](records/hol-0003/stderr.log).

## hol-repeat

Actual exit: `0`. Wall seconds: `15.607222000`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-repeat/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-repeat/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-repeat/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-repeat/audit.sml
```

[Record](records/hol-repeat/command.json), [stdout](records/hol-repeat/stdout.log), [stderr](records/hol-repeat/stderr.log).

## hol-lossy

Actual exit: `1`. Wall seconds: `14.341187750`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-lossy/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-lossy/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-lossy/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-lossy/audit.sml
```

[Record](records/hol-lossy/command.json), [stdout](records/hol-lossy/stdout.log), [stderr](records/hol-lossy/stderr.log).

## hol-swapped

Actual exit: `1`. Wall seconds: `15.211845625`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-swapped/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-swapped/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-swapped/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-swapped/audit.sml
```

[Record](records/hol-swapped/command.json), [stdout](records/hol-swapped/stdout.log), [stderr](records/hol-swapped/stderr.log).

## hol-import

Actual exit: `1`. Wall seconds: `12.602343084`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/relation-imported/forge_refundByteBoundaryTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/relation-imported/forge_refundByteBoundaryTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import/audit.sml
```

[Record](records/hol-import/command.json), [stdout](records/hol-import/stdout.log), [stderr](records/hol-import/stderr.log).

## hol-import-0002

Actual exit: `0`. Wall seconds: `11.950787208`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundWireProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/preload.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/relation-imported/forge_refundByteBoundaryTheory.sig /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/relation-imported/forge_refundByteBoundaryTheory.sml /Users/mackianni/forge/results/refund-byte-boundary-2026-11-04/attempt-0001/hol-import-0002/audit.sml
```

[Record](records/hol-import-0002/command.json), [stdout](records/hol-import-0002/stdout.log), [stderr](records/hol-import-0002/stderr.log).

## Evidence readback

Actual exit: `0`. Identity/outcome audit only.

```sh
python3 -B results/refund-byte-boundary-2026-11-04/attempt-0001/readback.py
```

[Record](records/readback.json).
