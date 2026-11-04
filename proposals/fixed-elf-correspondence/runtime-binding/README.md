# Bind the fresh runtime observation to the checked fixed trace

CURRENT none. Stage12 unauthorized. `end_to_end=false`.
Verdict: PARTIALLY_ESTABLISHED. This is a review-only supplement.

The existing observer records a successful finite execution. It does not enforce
the full trace identity. A new actual control sets entry a0 to1 before capture.
The unchanged ELF overwrites that register and still exits0. The old observer
correctly records a successful observation, but it cannot establish that the
new initial state equals the initializer used by the existing projection proof.
This was a missing integration check, not a false authoritative claim by that
observer: its original scope was explicitly observation only.

The small wrapper now runs the existing observer afresh, then requires the whole
trace and relevant LOAD bytes to match held identities. It checks execution
identities, exact QEMU arguments, actual parent/observer exits and scope flags.
It anchors the complete runtime input manifest outside that manifest, in this
separately reviewed source. Missing, altered or jointly rewritten packet inputs
cannot choose a new accepted expectation. Input identities are checked again
after execution. The CLI cannot import an old output directory as a fresh run.

These are byte-identity and orchestration checks, not an ISA decoder, machine
semantics or new proof checker. Review must authenticate the wrapper's exact
bytes and expectations. Its local result is not a signature, proof receipt or
admission. Trusted host/producer assumptions remain. It does not protect against
an attacker who controls the invoking host, Docker or the reviewed wrapper.

## Actual commands and outcomes this session

| Execution | Actual exit | Result |
| --- | ---: | --- |
| `python3 -B entry_experiment.py` |0|Baseline and changed-entry observer0/0; both QEMU exits0; traces differ |
| Original producer checks around those observations |0|Same held observer package bytes |
| `python3 -I -B run_bound_observation.py --runtime-packet ... --out .../bound-final` |0|Fresh execution; exact whole-trace/LOAD/identity binding; 6.806321s local wall time |
| `python3 -B test_matrix.py` |0|16 cases matched:1 valid comparison0 and15 expected refusals1 |
| Actual changed-entry capture comparison |1|TRACE_IDENTITY_MISMATCH despite actual QEMU exit0 |
| Trace edit/extra bytes/missing trace |1/1/1|Reject changed or incomplete trace |
| LOAD substitution/stale ELF/changed harness/missing command |1/1/1/1|Reject actual bytes or bound execution identity |
| Parent nonzero/boolean-false status/observer termination |1/1/1|Require actual integer0 and no observer kill |
| Unsupported end-to-end flag |1|Reject scope upgrade |
| Missing anchor/coordinated packet-manifest edit/existing output |1/1/1|Reject before fresh observer launch |
| Held proof-source postflight |0|All30 sources match prior full-kernel input anchors |

The initial wrapper smoke run preceded the final command-field guard and result
label correction. Its raw records remain. The reported final run uses the exact
source hash below, pinned before and after execution. Test-only test_capture.py
compares records and explicitly makes no freshness/provenance claim. The public
wrapper CLI accepts only a runtime packet and a new output path.

No new kernel replay was needed: no theorem, proof object, assumption or machine
semantics changed. The597-module/86-assumption replay is the prior actual result.
No new hosted execution, billed runner-minute measurement or savings claim.

## Exact binding and reproduction

- New wrapper SHA256: `251252a55e422b6184c818de9d1d0c572426cb670c9d9a3ccaefb16adc7d8472`.
- Exact ELF SHA256: `8ced2ab6c7160338899056fe51bacb23d86d81705eacfdd1e992cf5252bdaeb6`.
- Held complete trace: `526c4a2107262bd8624cc19e9762fa4875d536e0b7697324a1a2b468bdf9ed49`.
- Changed-entry trace: `cb4aa0c00230e4654ee0daf1704b302e5d9cd6e7042e4f006687375aa5085aa8`.
- Existing runtime archive: `55eec1b9063b6982c23acf6d8d6624dbbc85fabe9e1fed191c070e57ffc37912`.
- Existing runtime manifest: `24afcae2976fbcf38a024afc29455d310510d7eedb40320cb982fc226bdd5db0`.

The held trace's458 pre-exit lines are identical to the original trace used for
the existing projection. Prior trace-binding.json records that equality. The
projection source95e121bb... / objectefebc592... is in the checked597-module
closure. Translation/capture trust and the physical Model relation remain
explicit in the parent CORRESPONDENCE.md; hashing cannot prove those premises.

Authenticate the runtime archive and this wrapper against the independent
review packet. Extract the existing archive with the standard safe data filter.
Use the existing pinned Docker checker image. Then run:

```sh
python3 -I -B run_bound_observation.py --runtime-packet /absolute/extracted/runtime-packet --out /absolute/new/output
```

The wrapper has no dependency on the owner's worktree paths. The two experiment
drivers retain their exact local paths as command records; they are not a new
general test framework. Full commands, stdout/stderr, raw capture bytes and
test fixtures are preserved in execution-records.tar.gz and records-manifest.json.
The coordinated-packet fixture records only its two changed files; all remaining
bytes were copied from the held runtime archive, which remains unchanged.

An otherwise valid host may produce a different SP, trace format or initial state.
This exact profile must refuse that difference until applicability is separately
checked. Do not weaken the match or silently reuse the old initializer.

## Next approval boundary

Review this source together with the parent's exact conditional contract and
profile. profile-extension.json.proposed is inactive. No protected producer,
consumer, policy, workflow or acceptance profile was changed. New provenance
must come from a fresh authorized producer execution; signing copied local
results cannot substitute for it. Physical entry/Model correspondence, QEMU/
Linux fidelity and required progress remain T1-T6 assumptions requiring review.

PR37 remains draft/open atfc85ecc2, with no submitted reviews in this session.
PR36 remains separate. Publishing this local supplement as a draft PR needs
the corresponding authorization; it would permit existing automatic PR checks,
not merge, claim adoption, dispatch, signing, admission or deployment.
The owner's independent backup is reported. Its exact hashes/restore remain
unverified; this session obtained no independent-copy location or new evidence.
