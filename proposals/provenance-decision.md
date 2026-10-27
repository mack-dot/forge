# Stage 9 provenance contract approval and adoption

The user approved the exact three additions in `proposals/provenance.md` at
commit `097431cf458e5c62332575b09e953224471fa64d`.

Approval manifest SHA-256:
`92c56b5d36c44242a826905f2c7194052b802b7079d0d0130d686dbf885551cf`.
Patch SHA-256:
`ebbbeb7e19c3b3cec846a91133e01653a53bc5bd6b95f63645a8e1ec0c338dff`.

The approved targets and exact SHA-256 digests are:

- `spec/provenance/protocol.md`:
  `2784bdd04f0c89871e243df2402bd689546595835e28e7480fff5968e705ed69`.
- `policy/provenance.json`:
  `9e27f627a2b1924fc2f4f86346efaa06755a2c47a366fb3437e54a105d65f22b`.
- `spec/provenance/spec.lock`:
  `43610d8123ce21fdd1f9dac9469f78ad3efcb3af271a86011a18790099811a33`.

The user's approval excludes gate implementation, workflows, signing,
production deployment and future protected changes. It authorizes preparation
of a separate reviewable implementation/workflow proposal, then a stop at its
approval boundary. No Stage 9 acceptance result follows from this decision.

The public commit/tree and all six proposal files matched. The real patch
dry-run and application each returned 0. Applied files match every approved
digest. All 1,360 snapshotted prior files remain unchanged at adoption.
Commands, actual codes and identity records are in
`results/stage9/contract-adoption/identity.json`.

This records conversational human approval. It is not a cryptographic user
signature, signature-verification result, or formal proof.
Stage 9 remains CURRENT; all six EXITs remain NOT RUN; `end_to_end=false`.
