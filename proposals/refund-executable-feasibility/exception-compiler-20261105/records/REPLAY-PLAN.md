# Independent full-chain replay preparation — NOT RUN

This packet prepares source inputs and acceptance checks. It does not report an
independent environment, authenticated independent producer, or complete replay.
`replay-preparation.json` binds21 snapshots:15 local theory scripts and6 inspected
upstream files. `inputs.json` binds the producing run's2659 parent-file paths.
Those cached objects are comparison targets, not independent proof inputs.

## Required independent environment

Use a clean environment controlled by the reviewer. Do not mount this workspace
or import its `.hol` objects, heaps, theory data or proof cache as proof evidence.
Obtain and verify the exact source pins independently:

| Tool | Source revision |
| --- | --- |
| CakeML | cd9155694c16831373ab695a670794f23282ed62 |
| HOL4 | 9783a49979c94c401ff8c0e51b2eefae7ea95ae3 |
| Poly/ML | 4557554077078decce4ce5f90da00a713cfc32e4 |

Rebuild the standard tools and all required upstream theories using their
published build machinery. Record bootstrap inputs, compiler versions, host,
actual exits and output hashes. Import tags may still say DISK_THM after a clean
build; their origin must be independently rebuilt and documented. The four
Boolean foundations and trust in logic/kernel/host remain explicit.

Current sandbox restrictions and the historical Holmake refusal are not resolved
by this document. Do not reroute a denied operation or treat this plan as a new
execution permission. An authorized independent execution environment is a
prerequisite. No worker, container, service or deployment is started here.

## Replay order and checks

1. Independently verify the approved specification and U262 Unicode relation,
   then U294 source/model binding and U295 byte correspondence. Keep the
   unverified frontend/shared-interpretation review visible. This source branch
   is not replaced by native tests or the HOL-only replay below.
2. Rebuild the upstream ancestors in `dependency-snapshot.json`. Replay the
   custom source chain in dependency order: forge_refund, forge_refund_compile,
   forge_refund_call, forge_refund_io, forge_refundCertifiedProg,
   forge_refundWireProg, forge_refundStdioProg, forge_refundWholeProg.
3. Replay forge_refundArm8Compile and forge_refundArm8Proof. Compare the exact
   emitted code, bitmaps, configuration and assembly with the existing U275/U276
   records. This is planned independent reproduction, not a reason to recompile
   in the producing workspace. Do not accept changed bytes merely because tests pass.
4. Replay forge_refundRejectDirect, forge_refundRejectSemantics,
   forge_refundRejectBasis and forge_refundPreciseBehavior, then the accepted
   forge_refundRejectCompiled source. All15 local theory sources are under
   `replay-sources/`; exact original locations and hashes are recorded.
   The new proof's `FORGE_ERROR_OUT` selects only its output directory. Historical
   runners have path/output settings; record any relocation separately and
   preserve theorem source and expected terms. Do not copy producing heaps.
5. Compare the exact new statements with `expected.sml` using the fresh HOL
   kernel and `audit-tail.sml`. Require no open hypotheses/new tagged axioms,
   the recorded theory ancestry, and all eight premise groups. Repeat the new
   source and compare all four exports. Run wrong-code, missing-space and
   short-trace controls; each must fail at the intended statement comparison.
6. Independently bind both existing native builds, their signatures, runtime
   objects, assembly/linker inputs and all native execution records. The recorded
   standard checksum command is in `native-readback/commands.json`. Verify
   signatures without creating new signatures. Prior local ad hoc signatures
   do not establish release authority or trusted independent production.
7. For a clean native reproduction, preserve the exact pinned Clang/SDK/linker
   commands and compare resulting bytes at each available boundary. Do not
   change flags or signing metadata to force an identity match. Native execution
   requires the appropriate ARM64 environment. Repeat the existing positive,
   malformed-input, mutation and reproducibility controls only there. Preserve
   actual stdout, stderr, process status, failures and limits. No release signing,
   protected adoption, deployment or Stage12 is authorized.
8. Independently review each retained physical/FFI/resource premise against
   `PHYSICAL-NEXT.md` and the U296 runtime matrix. Report PROVED, TESTED, ASSUMED
   or NOT_ESTABLISHED for each. A perfect replay of a conditional theorem does
   not discharge its physical assumptions or establish end-to-end correctness.

Required outputs: complete commands/exits, fresh source and tool identities,
proof ancestry and assumptions, byte comparisons, negative-control reasons,
native stream/status records, environment provenance, and an independently
reviewed assurance matrix. No acceptance result may rely only on a producer's
manifest or completion marker. Independent full-chain replay remains NOT RUN.
