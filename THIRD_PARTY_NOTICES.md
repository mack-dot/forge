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

Dafny (MIT, Copyright (c) Microsoft Corporation), Z3 (bundled with Dafny),
Sigstore Cosign and moby/BuildKit (Apache-2.0), the Theorem Labs checker
images, and the npm packages in `package.json` (MIT or Apache-2.0) are fetched
at pinned versions and digests. They are not redistributed in this repository.
