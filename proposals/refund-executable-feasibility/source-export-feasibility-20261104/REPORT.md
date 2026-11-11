# Exact refund source export: unsupported frontend constructs

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
The preceding goal turn made progress by committing the tracking checkpoint at
`df1484b77380c165305b8d43ac7f5bc9a05bf08b`. This experiment tests its next action.
No repository stage, approved claim, verifier policy or native executable changed.
Remote GitHub state and hosted measurements were not refreshed in this experiment.

## Result and exact boundary

The unchanged pinned upstream Dafny frontend builds and runs. It **cannot export
the exact FlatCore source**. Its module-count guard fails before any refund AST
is produced. The same exact source fails again with the same diagnostic.
The unchanged upstream `plus_one.dfy` exports successfully. Enclosing only that
example in a named module causes the same module-count failure. These are tool
applicability checks, not behavioral correctness or security proofs.

A separate diagnostic copy removes only FlatCore's outer module declaration and
closing brace. It preserves the complete method and every contract byte. It then
fails on the `Iff` operator in the unchanged ensures clause. This diagnostic copy
is not the original source, an approved adapter, or an established equivalence.
No contract was stripped to obtain success. There is no refund S-expression.
HOL parsing, source/model equivalence and their adversarial proof controls are
NOT RUN. The complete source-to-model assurance link remains NOT_ESTABLISHED.

The first failure is at [Bake.cs:23](records/upstream-source/Source/DafnyDriver/Commands/Bake.cs),
where `ProgramToString` requires exactly two compile modules. The diagnostic
failure reaches `ResolvedBinOpcodeToString`, whose supported cases omit `Iff`.
The frontend also states that unsupported features are not always rejected.
Its successful extraction would therefore remain an explicit trust boundary;
parsing success alone would not prove source-semantic preservation.

## Actual commands and exits

Commands ran from `/Users/mackianni/forge` unless their saved `command.json` says
otherwise. `run.py` below means
`python3 -B results/refund-source-binding-2026-11-04/attempt-0001/run.py`.
Every subprocess has its actual argv, working directory, log and numeric result
in `records/`. Negative extraction outcomes are checked by their exact reasons.

| Command/check | Actual exit | Observation |
| --- | --- | --- |
| `run.py source` | 0 | Git init/fetch/checkout/identity/fsck all 0; exact upstream commit |
| `run.py sdk` | 0 | Vendor metadata/download/extract/info all 0; archive SHA512 matches metadata |
| `run.py build` | 0 | Unchanged frontend builds; 6 warnings, 0 errors |
| `run.py export` | 4 | CLI version command 0; export lacks Z3 lookup; no AST |
| `run.py export-with-solver` | 4 | Explicit option does not resolve Z3 for this command; same lookup failure |
| `run.py export-with-path` | 1 | Existing pinned Z3 found through local PATH symlink; module-count failure |
| `run.py source-repeat` | 1 | Same exact source and same module-count failure |
| `run.py example` | 0 | Unchanged published plus_one example exports 854 bytes |
| `run.py module-control` | 1 | Same example inside a named module fails the module-count guard |
| `run.py module-free-diagnostic` | 1 | Complete unchanged method/contracts reach unsupported ResolvedOpcode Iff |
| Initial / corrected identity readback | 1/0 | Raw archive hash and contentHash distinguished; no package-authentication claim |
| Prior snapshot byte comparison / diagnosis | 1/0 | Old API snapshot has one extra final LF; Git checkout matches its Git blob |
| Refund HOL parsing, equivalence, full proof replay | NOT RUN | No exported refund AST |

The Z3 lookup failures are setup failures, not proof rejections. The actual solver
is the existing Z3 4.12.1 binary; no solver source or accepted toolchain was edited.
`--version` on this source-built DafnyDriver returns `0.0.0.0`; identity is the
exact source commit, dependency records and binary hashes, not that version text.
No proof attempt count was reset. U290 remains stopped after five failed attempts.

## Exact identities and dependency limits

| Input/artifact | Identity |
| --- | --- |
| Upstream frontend commit | `6eb1ed63544a2e22c151db9b575f4308b8f329b0` |
| Upstream frontend tree | `ab2b12b545d8b6e725c47ac067f8c07705a47bd6` |
| SDK / runtime / host RID | 8.0.111 / 8.0.11 / osx-arm64 |
| Exact FlatCore SHA256 | `a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d` |
| Built DafnyDriver SHA256 | `b598f5b5dd170a4775db0decd9e090e01bd4e467b97d0e68fa8c4588fac024c6` |
| Built DafnyCore SHA256 | `ab4503211701c06582bb6c6627ee5f362062361362505c8c31cbcb12ffc6504d` |
| Existing Z3 SHA256 | `7d15df1e4ba8f60b0808dce02ec85e0dd6dac4b975231a2f7b35fe8789464208` |
| Unchanged native refund SHA256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The recorded readback checks 103 build-output files, six generated dependency
locks, 127 package archive hashes/metadata pairs, and 50 protected repository
inputs. The original source, mission, compiler proof and native artifact remain
unchanged. No native execution occurred. The SDK and dependency cache are local
experiment files. No service or persistent infrastructure was introduced.

The SDK archive is bound to release metadata obtained over the vendor's HTTPS
endpoint. This is not a signature or proof of compiler correctness. NuGet logs
explicitly report skipped package-signature verification. Archive hashes match
local archive sidecars; metadata content hashes match captured locks. The latter
hashes exclude the signature file, as described by the
[NuGet metadata specification](https://github.com/NuGet/Home/wiki/Nupkg-Metadata-File).
They are different from hashes of the complete signed ZIP. This audit does not
independently recompute NuGet contentHash or authenticate package producers.
The initial failed comparison and corrected scope are preserved. The first
build-identities record also retains an unresolved tree placeholder; the explicit
`build-identities-0002.json` supersedes that field with the actual Git tree.
None of these experimental outputs is admitted as authoritative evidence.

## Smallest next action and acceptance conditions

The direct export route is stopped at a demonstrated frontend compatibility
limit. The next local task is a separately reviewable compatibility proposal for
the existing upstream frontend, covering its module-selection rule and `Iff`
serialization. Reuse the published Dafny parser and HOL semantics. Do not create
a new parser, silently erase contracts, or promote this diagnostic copy to the
verified source. Further unsupported constructs may appear; they are not known
passing cases and must remain explicit.

Any experimental compatibility change must retain the exact original source,
all nine inputs, all six outputs, all contracts, and the full integer/Unicode
relation. Require explicit module/dependency handling and rejection of ambiguity.
Once exact-source extraction is possible, use the published CakeML parser and
HOL kernel to check the exported AST's behavior and its relation to the existing
constructed method. Check any required renaming, sequencing and representation
relations; do not assume AST identity. Preserve wrong-result, swapped-field,
missing-contract and substituted-source negative cases for the applicable new
binding. These acceptance checks have NOT RUN.

Local proposals and safe experiments remain authorized. This is not approval to
replace an accepted checker, source, specification or trust profile. Any proposed
frontend or source adapter requires independent review and the relevant exact
approval before protected adoption. Publication, push, merge, dispatch, signing,
admission and deployment retain their separate boundaries.

The other remaining M1 links are unchanged: applicable installed state and memory
frames; physical ARM/FFI/OS/interference; resource sufficiency and native exit;
clean independent full-chain replay; accepted claim/profile and new provenance
and admission. The owner-reported off-machine copy still lacks checked archive
hashes and an independent restore. Earlier local recovery is not that evidence.

Verdict: exact-source export **UNSUPPORTED** by the pinned frontend; M1 and
integration EXIT **NOT_ESTABLISHED**. Hosted refund measurements **NOT RUN**.
No Stage12 work. No end-to-end correctness claim.
