# Decision on the Stage 8 snapshot repair

The user approved the exact one-file repair at
[76f58de25fb5ebe305831432907e42a4210add40](https://github.com/mack-dot/forge/blob/76f58de25fb5ebe305831432907e42a4210add40/proposals/refund-hostile-snapshot.md),
bound to its published manifest and SHA-256 digests.

> Approval applies only to `gate/refund/hostile.ts` and the proposed prototype-preserving snapshot replacement. No other protected changes are authorized.

The published candidate, manifest, patch and original target were checked
against that commit's tree. The exact patch was applied with `git apply`.
Both its dry-run and actual application returned 0.

- Original file SHA-256: `cc3db1659761d16bb123fd984ec84ece6b58c6ec1eebe925602a9f8122987dea`.
- Applied file SHA-256: `0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a`.
- Patch SHA-256: `127daf49e2864495ab0651e35e54e0028ca29008f60b091ca43f4d95e27701a5`.
- Manifest SHA-256: `98645de7678354a2892aa48ab4a7d96bcd7ca92ccd13d9b0576be9ba4d54224e`.

All other protected files remain unchanged. The historical proposal and failure
records remain unchanged. Adoption records are in
`results/stage8/snapshot-repair-adoption/identity.json`.

The user requires real field/prototype mutation rejection checks and fresh runs
of all three Stage 8 EXIT commands. This is conversational approval of exact
bytes, not a proof result or permission for any other protected edit.
`end_to_end=false`.
