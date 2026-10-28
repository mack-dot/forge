<!-- forge-proof-gate -->
**Forge: rejected**

Revision: `33d913d43867ce7b37a4928884220b1b4adb6f2c`. Gate exit: `1`.

| Claim | Required behavior | Result | Apply proof |
| --- | --- | --- | --- |
| C1 | A transfer preserves total funds. | not established | — |
| C2 | Every resulting account balance is non-negative. | not established | — |
| C3 | An accepted identical retry returns Ok without repeating its effect. | not established | — |
| C4 | A fresh valid transfer terminates and performs the exact debit and credit. | not established | — |
| C5 | Every other request is rejected without changing either state map. | not established | — |

The candidate changes protected inputs without approval bound to their exact content.

**Scope:** sequential Dafny ledger source only; `end_to_end=false`.
Snapshot reuse trusts Dafny/Boogie dependency tracking and assumes no internal cache-checksum collision.
[Reproduction evidence and checker logs](https://github.com/mack-dot/forge/actions/runs/40743715513).
