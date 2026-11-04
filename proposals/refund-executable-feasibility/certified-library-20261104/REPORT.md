# Refund library contract through the existing translator

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.
Parent documentation commit: `341afa16e43b3783be3ac39136dfe403b35926a9`.
This is a local, unadopted implementation proposal. It establishes model and
library-call properties. It does not establish native refund execution.

## Exact result and implementation boundary

The existing CakeML translator produces code and a checked translation theorem
for `refund_fields`. This total function returns the same six refund fields:
authorization, amount, reason, charge ID, request ID and intent count. It uses
the existing `eligible` definition. No input restriction or approved rule changed.
Integers remain mathematical integers. Model strings remain arbitrary byte
strings. The earlier full Unicode source proof remains separate; its complete
binding to this program and native input/output remains open.

Two checked theorems establish the new link:

| Theorem | Exact scope |
| --- | --- |
| `refund_fields_original_method` | For every typed model input, the six returned fields agree with the unchanged Dafny-generated method under its existing primitive caller and clock32 |
| `refund_verified_spec` | The proposed library function accepts all nine typed values and returns the represented complete result under the published CF application judgment, with an empty owned heap and its frame guarantees |

The first theorem relates a HOL nested product to the original method's flat
six-field CakeML tuple. It does not claim arbitrary contextual equivalence of
the two code bodies. The second theorem supplies a library contract for the new
implementation; it does not repair the old raw method's CF proof. Its postcondition
covers authorized and rejected requests. It does not add bank effects or retry
state. The intent count remains a modeled result, not a payment execution.

The actual old wrapper and generated method remain unchanged. The new library
function uses forward argument order and nested result representation. The old
wrapper cannot adopt it without an explicit adapter or a checked replacement
wrapper. No adoption, policy change or replacement of historical evidence ran.

## Actual proof and adversarial commands

Commands ran from `/Users/mackianni/forge`. Let `OUT` denote
`results/refund-certified-library-2026-11-04/attempt-0001`.

| Command | Actual exit | Result |
| --- | --- | --- |
| `python3 -B "$OUT/run.py" library-0001` | 1 | Missing direct theory imports; preserved |
| `python3 -B "$OUT/run.py" library-0002` | 1 | Boolean representation equality remained open |
| `python3 -B "$OUT/run.py" library-0003` | 1 | Boolean type-stamp definition remained folded |
| `python3 -B "$OUT/run.py" library-0004` | 1 | Wrong theory qualifier for that definition; preserved |
| `python3 -B "$OUT/run.py" library-0005` | 0 | Both full-result and library-call theorems checked |
| Altered-amount child of `run_controls.py` | 1 | Required failure at `refund_fields_original_method`; no theory export |
| Swapped-wrapper-IDs child of `run_controls.py` | 1 | Required failure at `refund_verified_spec`; no theory export |
| `python3 -B "$OUT/run.py" repeat` | 0 | Six byte-identical exports; exact positive source restored |
| `python3 -B "$OUT/run_controls.py"` | 0 | Both refusal reasons and positive reproduction checked |
| Fresh HOL process with `closure-audit.sml` | 0 | 192 theory nodes; zero own theorem hypotheses; four foundation axioms |
| `python3 -B "$OUT/readback.py"` | 0 | Saved records, six exports,30 frozen inputs and original wrapper identity checked |
| Dependency snapshot attempts1/2/final | 1/1/0 | Loader source path and kernel-module classification corrected; all failures retained |

The amount mutation changes an authorized amount to `amount + 1`. It cannot
satisfy the original method relation. The wrapper mutation exchanges charge and
request arguments. It cannot satisfy the required library result. These are
intended proof refusals, not native test executions or an assertion that every
failed proof establishes a counterexample.

Exact argv, working directories, logs, source snapshots and numeric exits are
in `records/proof-*/command.json` and `records/acceptance-matrix.json`.
Earlier incomplete proof heaps remain in the raw directory. None was accepted.

## Exact identities and checking limits

- Positive source SHA256:
  `2ef6fd80d2fcccbc092096e2e20fc5d616af1a99fe00e1e949450f55e3e31632`.
- Repeated theory data SHA256:
  `5ffd9d6f201fb279acba5abbb30b24c55b950982f84dc2724c36fdd966e6c91a`.
- Original wrapper source remains
  `44ac5c9ecb51f13002cb7b762608ab39d4a0967053f34cc2d85adc6d9fd12e22`.
- Original wrapper data remains
  `ecda3e2a6d3dfd8eb71c251f5a76f8f7634be849f24208c2f0a706188ab3100d`.
- CakeML remains `cd9155694c16831373ab695a670794f23282ed62`.
- HOL remains `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`.

The dependency snapshot follows existing HOL loader records. It hashes191
theory file sets, the HOL executable and the initial CakeML heap. The remaining
`min` node is the kernel seed. Exact paths and digests are in
`records/dependency-snapshot.json`. Five relevant upstream source identities
are also recorded. Both tracked upstream source diffs return0.

The fresh process imports and inspects the graph; it does not replay every
upstream source. The positive build and repeat rerun the new proof source.
Imported `DISK_THM` remains an explicit trust boundary. The closure contains
`SELECT_AX`, `INFINITY_AX`, `ETA_AX` and `BOOL_CASES_AX`. No new axiom was added.
This is not independent human review or authenticated producer evidence. A hash
manifest identifies bytes; it does not authorize them.

## Why the route changed

The third old-normalizer diagnostic completed annotation stripping, then did
not return from normalization before manual interruption: dispatcher1, child
signal2. It exported no candidate or theory. Exact method inspection returned0.
Its source shows nested Boolean expressions. The published normalizer may
traverse a non-value right operand twice, and its fresh-name lookup repeatedly
scans used names. This is a source-based explanation to investigate, not a
profiled or proved complexity result. No fourth unchanged call was made.

This proposal instead uses the existing translator's checked function relation
and proves agreement with the unchanged method. It does not assume normalization
correctness or substitute a bounded refund example. The original full contract
and domain remain required. Raw diagnostic records are preserved under
`results/refund-normalised-method-2026-11-04/attempt-0002/`.

## Next assurance link and approval packet

Next authorized experiment, NOT RUN: compose this complete library result with
the existing strict wire decoder, response schema and published TextIO rules.
Prove the accepted-output path and malformed/trailing-input rejection for the
actual proposed wrapper. Preserve the old wrapper and its adversarial history.
Then bind the same checked whole program to the existing compiler's exact
machine-code result and its entry, resource, FFI and runtime premises.

Before protected adoption, review the exact implementation and theorem hashes,
the complete R1–R5 relation, the changed calling convention, the Unicode/model
binding, the checker closure and all permitted assumptions. A native claim and
admission profile need their own exact approval and independent review. This
local proposal does not authorize publication, merge, signing, dispatch,
admission or deployment.

M1 remains `NOT_ESTABLISHED`. Whole-program I/O, the exact native executable,
concrete/runtime correspondence and new authenticated admission remain open.
Native execution and hosted refund measurements are NOT RUN. No performance
improvement is claimed. The owner reports an off-machine copy; exact archive
hashes and restore on that copy remain unverified. GitHub controls were not
refreshed in this experiment. M2–M4 remain subsequent work.
