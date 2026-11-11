The recorded QEMU launch has a stack pointer outside the accepted Stage7 theorem's entry domain. This draft proposes an additional abstract-model termination claim for the same fixed ELF. It includes the completed local proof checks and integrity controls for independent review. The proposed claim and acceptance profile remain unapproved.

Exact head: `fc85ecc2c7f12caa6c8991fa002410bdf78dd51d`.
Base: `f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`.
Only14 files under `proposals/fixed-elf-assurance/**` change. The theorem sources are unchanged from the earlier local snapshot5bb008a1. That snapshot remains in the commit history.

The claim concerns normal exit0 for ELF SHA256 `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`, under the stated LPS initializer/model assumptions and arbitrary data memory. It does not establish arbitrary-input GCD correctness, universal QEMU refinement, or a new authorized release/runtime binding.

Recorded local validation:

| Check | Actual exit | Scope |
| --- | --- | --- |
| Termination theorem and published wrapper kernel check |0|569 modules;86 permitted closure assumptions. |
| Recorded observation-module kernel check |0|567 modules;86 permitted closure assumptions; finite21-state equality. |
| Fresh theorem/wrapper and observation-object rebuilds |0|Objects reproduced byte for byte. |
| Weaker statement fixture compilation |0|Valid20-state proposition under the same module/lemma names. |
| Corrupt / weaker proof-object identity guards |1/1|Exact held-anchor refusal before kernel launch. |
| Current trusted incremental gate on this proposal |3|UNSUPPORTED;14 uncovered proposal paths; no verification evidence written. |

The source packet contains the raw lossless-compressed kernel/runtime logs, actual dependency and assumption closures, and the26-member integrity-control archive. Inherited metadata flags have explicit corrections. The integrity anchor is a separately held local expectation; this does not establish durable provenance for an untrusted candidate-supplied expectation. The earlier signature authenticates the old release, not this new statement or runtime package.

The existing ordinary PR workflow may run automatically on publication. This draft adds no gate obligation or coverage exception. Its expected uncovered-change refusal must remain visible. Existing CI does not certify or admit the proposed theorem. The upload repair in PR36 remains a separate review boundary.

Publication is for draft review only. Intent adoption, any protected acceptance-profile change, independent exact-head review, merge, manual workflow execution, signing, admission and deployment retain separate authorization boundaries. `end_to_end=false`. Stage12 remains unauthorized. Node integration and generic cross-run receipt adoption stay disabled.
