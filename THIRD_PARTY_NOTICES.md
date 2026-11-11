# Third-party notices

Forge is licensed under the Apache License 2.0 (see `LICENSE`). Some files in
this repository contain or are derived from third-party material under the
licenses below.

## theorem-labs/oss-verify-proofs and theorem-labs/rocq-linux-process-semantics

Used at pinned commits `bf6a65114ed2e255098e213e183e83f63c2cabcc` and
`f1006fe8178338a499b5e5c41be83006c4edd058`. Both carry the same MIT license
text at those commits (sha256 `052099c05c4c…` of the LICENSE file).

Where it appears here: logs and records under `results/stage7/`, including
source and compiled proof files inside
`results/stage7/published/*/records.tar.xz`; `examples/binary/*.v` imports
the LinuxProcessSemantics library.

```text
MIT License

Copyright (c) 2026 Theorem Labs, PBC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Tools that are downloaded, not stored here

The Dafny release binaries (MIT, Copyright (c) Microsoft Corporation), Z3
(bundled with Dafny), Sigstore Cosign and moby/BuildKit (Apache-2.0), the
Theorem Labs checker images, and the npm packages in `package.json` (MIT or
Apache-2.0) are fetched at pinned versions and digests. These binaries, images
and packages are not redistributed in this repository. Some Dafny, CakeML and
HOL4 source files are stored here as recorded inputs. See the next section.

## Upstream source files stored as recorded inputs

The feasibility records under `proposals/refund-executable-feasibility/` hold
copies of selected upstream files. `.gitignore` does not exclude these paths.
This list names the known locations. It is not a verified complete inventory.

- Dafny (MIT, Copyright (c) Microsoft Corporation). Compiler source files and
  standard library files, for example
  `source-export-feasibility-20261104/records/upstream-source/`,
  `verified-backend-20261104/frontend/`, `source-model-binding-20261104/frontend/`,
  `byte-boundary-20261104/records/*/inputs/library/Std/` and
  `unicode-20261104/library/`. License text:
  `source-export-feasibility-20261104/records/upstream-source/LICENSE.txt`.
- CakeML (BSD 3-Clause, Copyright (c) 2026, Anthony Fox, Google LLC, Ramana
  Kumar, Magnus Myreen, Michael Norrish, Scott Owens, Yong Kiam Tan, and other
  contributors listed at https://cakeml.org). Source files in `upstream/` and
  `records/upstream*/` directories, for example
  `verified-backend-20261104/upstream/` and
  `arm8-assurance-audit-20261104/upstream/basis/basis_ffi.c`. Compiled
  `basis_ffi.o` files and generated `refund.S` files in
  `native-execution-20261104/`, `native-audit-20261104/` and
  `arm8-compile-20261104/` derive from CakeML. License text:
  `verified-backend-20261104/upstream/LICENSE`.
- HOL4. Source files in `environment-recovery-20261106/records/sources/HOL/`,
  `native-error-instructions-20261105/records/upstream/HOL/`,
  `closure-install-20261105/records/upstream-additional/HOL/`,
  `exception-focused-20261104/records/builder-source-inspection/HOL/` and
  `word-oracle-validation-20261105/records/upstream-HOL/`. No HOL4 license or
  copyright file is copied in these directories. The HOL4 license terms are
  not verified here.
