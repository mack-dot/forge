# Stage 9 implementation approval and adoption

Status: the exact 11 additions are applied. Execution is not authorized.
Stage 9 remains CURRENT. `end_to_end=false`.

The user approved the proposal published at
[`06b40caa6bf5fb6963756b39646413559f84c61d`](https://github.com/mack-dot/forge/commit/06b40caa6bf5fb6963756b39646413559f84c61d).
Its tree is `914bc59e048f075ccf7a6fbc8cdc4b51305b5cc9`.
The approval covers only the additions in the published
[manifest](provenance-implementation/approval-manifest.json).

| Bound input | SHA-256 |
| --- | --- |
| Approval manifest | `5ea08fb8e32d875adc1ab3bb690599602cd622a7c61223f8cc56d4c5bbe972fa` |
| Complete patch | `25410a1397fb5d8ea8a616359924afadabc0da64b4bc800ca3aab1f3244642b7` |
| Installed implementation lock | `6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa` |

The published manifest contains all 11 target paths, byte counts and individual
SHA-256 digests. The published proposal blobs matched the local inputs before
application. Both `git apply --check` and `git apply` returned 0. All targets
then matched their approved candidate bytes and hashes. All 1,446 snapshotted
pre-existing files were unchanged at adoption.
[The adoption record](../results/stage9/implementation-adoption/identity.json)
contains the exact commands, exit codes and target identities. Empty command
outputs are retained as empty log files, not omitted results.

The user's scope is explicit: no workflow dispatch, public Sigstore signing,
runner registration or deployment execution. No other protected change is
approved. This record transcribes conversational approval; it is not a digital
signature from the user and is not provenance evidence for an executable.

The two installed workflows have only `workflow_dispatch` triggers. Publishing
their approved source files does not authorize dispatch. No Stage 9 EXIT has
run. The safe installation check returned 0. The separate adversarial receipt
audit returned 1 and exposed validation gaps. Its deliberately invalid fixtures
are never accepted proof evidence. See the
[signing preparation audit](../docs/stage9-signing-preparation-audit.md).

The approved implementation stays unchanged despite those findings. The
[runner provisioning plan](stage9-runner-provisioning.md) is a review document,
not permission to install, register, sign or deploy. Stop before execution.
