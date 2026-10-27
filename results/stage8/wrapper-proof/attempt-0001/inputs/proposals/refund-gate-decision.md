# Decision on the Stage 8 refund gate

The user approved exactly the three additions in
[revision d2d557e2dcd564049fbd97171b0af67659eacf81](https://github.com/mack-dot/forge/blob/d2d557e2dcd564049fbd97171b0af67659eacf81/proposals/refund-gate.md),
bound to its published manifest, patch digest and individual file digests.

> This approval is limited to `gate/refund.py`, `gate/refund/Bindings.dfy`, and `gate/refund/hostile.ts` as proposed. It does not authorize any unspecified changes to protected files, weakened verification rules, or real payment execution.

The approved candidates were checked against that public Git tree. Their exact
bytes were copied to the previously absent targets:

| Target | SHA-256 |
| --- | --- |
| `gate/refund.py` | `da370619a34d64d1fe82bf8d4cf4d54e3d8068a2d19a36ac0192d2d322a5d4fb` |
| `gate/refund/Bindings.dfy` | `d689b18a64aa2cdc7c705e8d6b953c401e3f866f8311d624238b563e1d7a621d` |
| `gate/refund/hostile.ts` | `cc3db1659761d16bb123fd984ec84ece6b58c6ec1eebe925602a9f8122987dea` |

Patch SHA-256: `e957da8b4af6a4f3df44d615b2e69eab1360569a7a11bbfa7c4dba430c70ab66`.
Manifest SHA-256: `84793263039606c004c926a982ff9b0e545c74612d9d484822e68889f39f37fd`.
The adoption record is `results/stage8/gate-adoption/identity.json`.

The user also authorized implementation of the unprotected integration adapter
and EXIT harness, all required real checks and negative controls, with particular
attention to stale/duplicate dispatch, proof coverage and method separation.
This records conversational approval, not a signed attestation or proof result.
The historical proposal remains unchanged. `end_to_end=false`.
