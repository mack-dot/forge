# Read-only lookup errors

These were source-navigation errors, not verifier or solver executions.
No existing file was modified or removed.

- A shell read batch ended with an rg search over guessed files
  `polyml/libpolyml/{exceptions,errors}.cpp`. The whole batch exited2.
  Exact error: `rg: .toolchain/experiments/refund-cakeml-20261104/polyml/libpolyml/exceptions.cpp: No such file or directory (os error 2)`.
- A later source read included a guessed `polyml/basis/PolyML.sml` path.
  Exact error: `rg: .toolchain/experiments/refund-cakeml-20261104/polyml/basis/PolyML.sml: No such file or directory (os error 2)`.
  A subsequent command in that shell batch succeeded; the reported whole-batch
  exit was0. No separate process status was retained for the intermediate rg.

Scoped searches found the actual `libpolyml/run_time.h`, `run_time.cpp`, and
`basis/PolyMLException.sml` files. The source identity audit then exited0.
No proof failure or negative-control credit is attributed to these lookups.
