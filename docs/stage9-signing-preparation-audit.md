# Stage 9 signing preparation audit

The exact 11 approved additions are installed. **Complete independent receipt
and artifact validation is not confirmed.** A local audit found three inputs
that the real receipt validator did not reject. Stage 9 remains CURRENT.
`end_to_end=false`.

This audit used only file inspection, Python syntax checks, identity checks and
direct calls to the approved JSON receipt validator. It did not run Rocq,
Cosign, Docker, a workflow, runner registration or deployment. It did not mock
a checker or produce a signature. No Stage 9 proof or provenance claim follows
from these checks.

## Checks present in the approved code

The positive workflow has separate `proof` and `sign` jobs. `sign` depends on
`proof` and downloads this run's named unsigned artifact. Both check out the
exact dispatched commit. The workflow gives the proof job `contents: read`;
only signing has `id-token: write`. The approved producer performs actual
compilation and complete independent kernel checking before it writes a
receipt. That code path has not executed in Stage 9.

Before calling Cosign, `producer.sign` calls `context` and `validate_receipt`.
It compares the request, expected canonical evidence and exact statement.
`context` checks the independently supplied implementation-lock digest, 60
bound files and the contract locks. This includes the repository's accepted
ELF. The receipt validator checks:

- Equality of request nonce and source commit.
- Receipt files against their supplied manifest, including the exact file set.
- The report's artifact digest, theorem names, valid-entry witness,
  assumption lists and list of 579 checked modules.
- Reported successful compilation and wrapper commands, the recorded kernel
  exit code and the required leading `rocqchk` flags.
- Actual kernel-log bytes against the report's log digest.
- Before/after upstream identity manifests against the approved identity.

These are useful checks. The report and its file manifest still come from the
producer. They do not independently establish that a fresh kernel execution
occurred. That claim depends on the exact trusted producer job, its isolation,
and the authenticated GitHub run and artifact handoff. A matching nonce in a
JSON document alone is not evidence of recency.

## Actual safe-check results

| Command | Exit code | Scope |
| --- | --- | --- |
| `python3 scripts/check_stage9_installation.py` | 0 | All 11 exact bytes; syntax; workflow structure; 60 locked files; 45 pinned Python dependency files. |
| `python3 scripts/audit_stage9_receipts.py --output results/stage9/implementation-adoption/receipt-audit-0001 --work build/stage9-receipt-audit-0001` | 1 | Real receipt-validator audit; three unexpected non-rejections. |

The audit copied genuine historical Stage 7 logs as **untrusted negative
fixtures**. It attached a new synthetic request nonce and deliberately invalid
dependency digests (`!` repeated 64 times). No fresh proof ran for that request.
Every fixture is labelled `accepted_evidence=false`. The copied ELF was then
changed or omitted in two cases. Their receipt manifests were regenerated.

| Negative fixture | Observed validator result |
| --- | --- |
| Invalid dependency hashes | Returned a receipt digest without rejection. |
| Substituted copied ELF, with updated manifest | Returned a receipt digest without rejection. |
| Missing copied ELF, with updated manifest | Returned a receipt digest without rejection. |
| Request nonce mismatch | Rejected: `STALE_PROOF_RECEIPT`. |
| File changed after manifest creation | Rejected: `PROOF_RECEIPT_BYTES`. |

All cases contain the invalid dependency map. The first case establishes that
this map is accepted. The next two show that changing or omitting the copied
ELF adds no rejection. These results concern `validate_receipt`, not a complete
workflow, signature verifier or release admission. There is no underlying
kernel or Cosign exit code for this audit; neither tool ran.

## Precise gaps and required disposition

1. `release.validate_receipt` checks the dependency map's length and the length
   of each value. It does not require hexadecimal SHA-256 values, compare the
   map's keys with the checked dependency closure, or rehash those `.vo` bytes.
   The producer collects actual hashes, but the later validator does not
   independently establish that binding.
2. The validator compares the report's ELF digest with policy. It does not
   require `linux/gcd-selftest.elf` or compare its actual bytes with that digest.
   A manifest can describe a different ELF, or omit it, and still pass this
   helper. The locked repository ELF is checked elsewhere; this is a gap in
   binding the receipt's copied artifact to that exact accepted ELF.
3. The signing function does not rehash the downloaded `packaged.elf` or
   independently inspect the built image. The earlier packaging function does
   extract and hash a real container file, and the later observer checks an
   actual deployed file. Those paths remain unexecuted in Stage 9. Their
   existence does not establish an independent signing-time package check.

Do not treat the negative fixtures as valid evidence or sign them as release
claims. Do not infer a full signing bypass from a local helper result. Keep the
approved gate unchanged. Any repair must have an exact, separately approved
patch and updated implementation identity. A future repair must retain fresh
full proof checking, complete closure accounting, exact artifact comparisons
and all existing negative controls. It cannot replace the trusted-producer
assumption with an unsupported claim that logs authenticate execution.

## Preserved records and reproduction

The [adoption directory](../results/stage9/implementation-adoption/) contains
exact commands, raw stdout/stderr, actual exit codes and before-identities.
The [audit result](../results/stage9/implementation-adoption/receipt-audit-0001/result.json)
records each observation. Per-case directories retain generated manifests,
invalid dependency maps and the substituted bytes. `inputs.json` binds all
historical inputs. Historical files and failures were not changed.

The original 4,197,005-byte kernel log is already published in the lossless
[Stage 7 archive](../results/stage7/published/stage7-complete/records.tar.xz).
The archive SHA-256 is
`103288d5e758874b013aacb8150a11f4ceaaff0f4ef71256011efa112fb53686`.
The log SHA-256 is
`17f533b4873ea0ba11ede10140b6b1c41289402398737056862e00508e935758`.
In a clean checkout, extract that file before running the audit:

```sh
tar -xJf results/stage7/published/stage7-complete/records.tar.xz results/stage7/own-proof/attempt-0001/linux/independent-kernel.log
python3 scripts/audit_stage9_receipts.py --output NEW_OUTPUT --work NEW_WORK
```

Use new output directories. The expected **current diagnostic result** is 1;
this preserves a failing security audit, not a successful Stage 9 EXIT. The
script requires Python 3.10.11 and the exact approved files through `context`.
The installation script additionally requires the pinned local Stage 7 Python
dependency directories. No new proof or signing capability is installed by
either diagnostic script.
