<!-- forge-proof-gate -->
**Forge: accepted**

Revision: `f16b3688fbc97773b0a76e45eb427136bf1a124a`. Gate exit: `0`.

| Claim | Required behavior | Result | Apply proof |
| --- | --- | --- | --- |
| C1 | A transfer preserves total funds. | source_proof | reused |
| C2 | Every resulting account balance is non-negative. | source_proof | reused |
| C3 | An accepted identical retry returns Ok without repeating its effect. | source_proof | reused |
| C4 | A fresh valid transfer terminates, debits amount plus one from the sender, credits the recipient by amount, and credits fee account 0 by one. | source_proof | reused |
| C5 | Every other request is rejected without changing either state map. | source_proof | reused |

Candidate member obligations: **0 checked, 12 reused**.
The baseline was fully verified first. C1–C5 share the Apply obligation.
The exact saved reproduction command returned identical evidence.
Artifact SHA-256: `67fbe0f31b2a332aaae42adbedcee7402482381bde2610abe3ebc83384f1ba69`.

**Scope:** sequential Dafny ledger source only; `end_to_end=false`.
Snapshot reuse trusts Dafny/Boogie dependency tracking and assumes no internal cache-checksum collision.
[Reproduction evidence and checker logs](https://github.com/mack-dot/forge/actions/runs/40744116402).
