# Actual command ledger

These commands ran locally. Durations are observations, not benchmarks.
The scenario directories retain exact input bytes, scripts, output logs, and invocation records.
An exporter exit 0 does not establish a proof. Expected negative proof exits are listed explicitly.
No hosted run, independent-device restore, signing or admission ran.

## abstract-module

Actual exit: `1`. Wall seconds: `1.252307500`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/abstract-module/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/abstract-module.dfy
```

[Record](records/abstract-module/command.json), [stdout](records/abstract-module/stdout.log), [stderr](records/abstract-module/stderr.log).

## bridge-0001

Actual exit: `0`. Wall seconds: `7.067698459`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundCertifiedProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-0001/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-0001/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-0001/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-0001/audit.sml
```

[Record](records/bridge-0001/command.json), [stdout](records/bridge-0001/stdout.log), [stderr](records/bridge-0001/stderr.log).

## bridge-import

Actual exit: `0`. Wall seconds: `7.025525709`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundCertifiedProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/relation-imported/forge_refundCompiledInputBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/relation-imported/forge_refundCompiledInputBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-import/audit.sml
```

[Record](records/bridge-import/command.json), [stdout](records/bridge-import/stdout.log), [stderr](records/bridge-import/stderr.log).

## bridge-repeat

Actual exit: `0`. Wall seconds: `7.450822708`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundCertifiedProg_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-repeat/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-repeat/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-repeat/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/bridge-repeat/audit.sml
```

[Record](records/bridge-repeat/command.json), [stdout](records/bridge-repeat/stdout.log), [stderr](records/bridge-repeat/stderr.log).

## build-0001

Actual exit: `0`. Wall seconds: `20.819422208`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet build Source/DafnyDriver/DafnyDriver.csproj --configuration Release --no-self-contained -m:2 -p:RestoreLockedMode=true
```

[Record](records/build-0001/command.json), [stdout](records/build-0001/stdout.log), [stderr](records/build-0001/stderr.log).

## build-0002

Actual exit: `0`. Wall seconds: `15.713228125`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet build Source/DafnyDriver/DafnyDriver.csproj --configuration Release --no-self-contained -m:2 -p:RestoreLockedMode=true
```

[Record](records/build-0002/command.json), [stdout](records/build-0002/stdout.log), [stderr](records/build-0002/stderr.log).

## build-0003

Actual exit: `0`. Wall seconds: `4.432631833`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet build Source/DafnyDriver/DafnyDriver.csproj --configuration Release --no-self-contained -m:2 -p:RestoreLockedMode=true
```

[Record](records/build-0003/command.json), [stdout](records/build-0003/stdout.log), [stderr](records/build-0003/stderr.log).

## export-0001

Actual exit: `1`. Wall seconds: `0.383960792`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/export-0001/output.sexp /Users/mackianni/forge/proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy
```

[Record](records/export-0001/command.json), [stdout](records/export-0001/stdout.log), [stderr](records/export-0001/stderr.log).

## export-0002

Actual exit: `1`. Wall seconds: `0.387854541`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/export-0002/output.sexp /Users/mackianni/forge/proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy
```

[Record](records/export-0002/command.json), [stdout](records/export-0002/stdout.log), [stderr](records/export-0002/stderr.log).

## export-0003

Actual exit: `0`. Wall seconds: `0.378458833`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/export-0003/output.sexp /Users/mackianni/forge/proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy
```

[Record](records/export-0003/command.json), [stdout](records/export-0003/stdout.log), [stderr](records/export-0003/stderr.log).

## export-repeat

Actual exit: `0`. Wall seconds: `1.248612959`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/export-repeat/output.sexp /Users/mackianni/forge/proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy
```

[Record](records/export-repeat/command.json), [stdout](records/export-repeat/stdout.log), [stderr](records/export-repeat/stderr.log).

## hol-0001

Actual exit: `1`. Wall seconds: `3.793141000`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-0001/proof.sml
```

[Record](records/hol-0001/command.json), [stdout](records/hol-0001/stdout.log), [stderr](records/hol-0001/stderr.log).

## hol-0002

Actual exit: `1`. Wall seconds: `4.824151833`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-0002/proof.sml
```

[Record](records/hol-0002/command.json), [stdout](records/hol-0002/stdout.log), [stderr](records/hol-0002/stderr.log).

## hol-0003

Actual exit: `1`. Wall seconds: `4.731897417`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-0003/proof.sml
```

[Record](records/hol-0003/command.json), [stdout](records/hol-0003/stdout.log), [stderr](records/hol-0003/stderr.log).

## hol-0004

Actual exit: `0`. Wall seconds: `166.523684417`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-0004/proof.sml
```

[Record](records/hol-0004/command.json), [stdout](records/hol-0004/stdout.log), [stderr](records/hol-0004/stderr.log).

## hol-missing-contract

Actual exit: `1`. Wall seconds: `124.632431500`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-missing-contract/proof.sml
```

[Record](records/hol-missing-contract/command.json), [stdout](records/hol-missing-contract/stdout.log), [stderr](records/hol-missing-contract/stderr.log).

## hol-repeat

Actual exit: `0`. Wall seconds: `206.032492958`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-repeat/proof.sml
```

[Record](records/hol-repeat/command.json), [stdout](records/hol-repeat/stdout.log), [stderr](records/hol-repeat/stderr.log).

## hol-swapped-fields

Actual exit: `1`. Wall seconds: `132.925779375`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-swapped-fields/proof.sml
```

[Record](records/hol-swapped-fields/command.json), [stdout](records/hol-swapped-fields/stdout.log), [stderr](records/hol-swapped-fields/stderr.log).

## hol-swapped-inputs

Actual exit: `1`. Wall seconds: `5.982871417`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-swapped-inputs/proof.sml
```

[Record](records/hol-swapped-inputs/command.json), [stdout](records/hol-swapped-inputs/stdout.log), [stderr](records/hol-swapped-inputs/stderr.log).

## hol-trailing

Actual exit: `1`. Wall seconds: `4.400143500`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-trailing/proof.sml
```

[Record](records/hol-trailing/command.json), [stdout](records/hol-trailing/stdout.log), [stderr](records/hol-trailing/stderr.log).

## hol-wrong-amount

Actual exit: `1`. Wall seconds: `131.774495959`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/hol-wrong-amount/proof.sml
```

[Record](records/hol-wrong-amount/command.json), [stdout](records/hol-wrong-amount/stdout.log), [stderr](records/hol-wrong-amount/stderr.log).

## import-0001

Actual exit: `0`. Wall seconds: `7.600977708`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/import-0001/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/import-0001/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/import-0001/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/import-0001/audit.sml
```

[Record](records/import-0001/command.json), [stdout](records/import-0001/stdout.log), [stderr](records/import-0001/stderr.log).

## missing-contract

Actual exit: `0`. Wall seconds: `1.129070583`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/missing-contract/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/missing-contract.dfy
```

[Record](records/missing-contract/command.json), [stdout](records/missing-contract/stdout.log), [stderr](records/missing-contract/stderr.log).

## named-example

Actual exit: `0`. Wall seconds: `1.219210583`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/named-example/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0001/named-module-control.dfy
```

[Record](records/named-example/command.json), [stdout](records/named-example/stdout.log), [stderr](records/named-example/stderr.log).

## nested-module

Actual exit: `1`. Wall seconds: `1.260602209`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/nested-module/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/nested-module.dfy
```

[Record](records/nested-module/command.json), [stdout](records/nested-module/stdout.log), [stderr](records/nested-module/stderr.log).

## nonempty-frame

Actual exit: `1`. Wall seconds: `1.225478958`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/nonempty-frame/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/nonempty-frame.dfy
```

[Record](records/nonempty-frame/command.json), [stdout](records/nonempty-frame/stdout.log), [stderr](records/nonempty-frame/stderr.log).

## relation-0001

Actual exit: `0`. Wall seconds: `7.718894084`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-0001/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-0001/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-0001/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-0001/audit.sml
```

[Record](records/relation-0001/command.json), [stdout](records/relation-0001/stdout.log), [stderr](records/relation-0001/stderr.log).

## relation-import

Actual exit: `0`. Wall seconds: `2.792899334`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/relation-imported/forge_refundSourceRelationTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/relation-imported/forge_refundSourceRelationTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-import/audit.sml
```

[Record](records/relation-import/command.json), [stdout](records/relation-import/stdout.log), [stderr](records/relation-import/stderr.log).

## relation-repeat

Actual exit: `0`. Wall seconds: `2.789895958`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refund_call_experiment`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol run --holstate=/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-repeat/preload.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-repeat/imported/forge_refundSourceBindingTheory.sig /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-repeat/imported/forge_refundSourceBindingTheory.sml /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/relation-repeat/audit.sml
```

[Record](records/relation-repeat/command.json), [stdout](records/relation-repeat/stdout.log), [stderr](records/relation-repeat/stderr.log).

## root-code

Actual exit: `1`. Wall seconds: `1.241423125`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/root-code/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/root-code.dfy
```

[Record](records/root-code/command.json), [stdout](records/root-code/stdout.log), [stderr](records/root-code/stderr.log).

## sequence-int

Actual exit: `1`. Wall seconds: `0.785176833`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/sequence-int/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/sequence-int.dfy
```

[Record](records/sequence-int/command.json), [stdout](records/sequence-int/stdout.log), [stderr](records/sequence-int/stderr.log).

## swapped-fields

Actual exit: `0`. Wall seconds: `1.188545625`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/swapped-fields/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/swapped-fields.dfy
```

[Record](records/swapped-fields/command.json), [stdout](records/swapped-fields/stdout.log), [stderr](records/swapped-fields/stderr.log).

## swapped-inputs

Actual exit: `0`. Wall seconds: `1.134284541`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/swapped-inputs/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/swapped-inputs.dfy
```

[Record](records/swapped-inputs/command.json), [stdout](records/swapped-inputs/stdout.log), [stderr](records/swapped-inputs/stderr.log).

## two-modules

Actual exit: `1`. Wall seconds: `1.201428250`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/two-modules/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/two-modules.dfy
```

[Record](records/two-modules/command.json), [stdout](records/two-modules/stdout.log), [stderr](records/two-modules/stderr.log).

## upstream-example

Actual exit: `0`. Wall seconds: `1.226477834`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/upstream-example/output.sexp /Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/examples/plus_one.dfy
```

[Record](records/upstream-example/command.json), [stdout](records/upstream-example/stdout.log), [stderr](records/upstream-example/stderr.log).

## wrong-amount

Actual exit: `0`. Wall seconds: `1.155750208`.
Working directory: `/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat`.

```sh
/Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/sdk/dotnet /Users/mackianni/forge/.toolchain/experiments/refund-dafny-frontend-20261104/dafny-compat/Binaries/net8.0/DafnyDriver.dll bake /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/wrong-amount/output.sexp /Users/mackianni/forge/results/refund-source-binding-2026-11-04/attempt-0002/fixtures/wrong-amount.dfy
```

[Record](records/wrong-amount/command.json), [stdout](records/wrong-amount/stdout.log), [stderr](records/wrong-amount/stderr.log).

## Identity and outcome readback

Actual exit: `0`. This checks bindings and prior recorded outcomes. It is not a semantic verifier.

```sh
python3 -B results/refund-source-binding-2026-11-04/attempt-0002/readback.py
```

[Audit](records/readback.json), [script](records/readback.py), [command](records/readback-command.json).
