# Fresh backup procedure review

The previously prepared copy_backup.sh was read independently of its earlier
success notes. New tests used real copied archives, not mock transfer results.
Original archives and the prior session's frozen files were not changed.

| New check | Actual child exit | Observation |
| --- | --- | --- |
| Original archives and manifests | 0 | 10,160 members each; hashes, sizes, embedded manifests and raw/sanitized mapping agree |
| Fresh intact copies | 0 | Accepted |
| One byte truncated from copied raw archive | 1 | Digest mismatch before archive use |
| Space appended to copied sanitized manifest | 1 | Digest mismatch |
| Invalid destination argument | 2 | Refused before any SSH invocation |
| Shell syntax | 0 | Valid syntax, not a transport result |

Procedure properties: destination allowlist; SSH host verification is not
disabled; source checked first; a new remote directory with umask 077; no
overwrite of an existing remote directory; four exact files plus the checker
copied; remote checks performed before success; result fetched back. It does
not delete evidence. The retained result explicitly does not assert independent
storage from hashes alone. The checker validates all archive member types and
paths without extracting or printing source contents.

Limits: no remote host was supplied, no SSH/scp transfer was executed, and
remote Python/xz availability was not tested. It copies the curated November 1
archives, not the full Stage 9 image/controller freeze or subsequent records.
No independent backup is established. A separate person's review has not occurred.

## Exact remaining steps

1. Owner names a private destination on a physically independent machine or
   storage system. Confirm that it is not a VM or mounted folder backed by this
   Mac's disk. Record destination owner, host identity and storage independence.
2. Owner verifies its SSH host key using an independent channel and confirms
   Python 3 with tarfile/lzma support. Do not disable SSH host-key checks.
3. Run the already prepared procedure with the actual SSH host:

   ```sh
   sh /Users/mackianni/forge/results/ops-readiness/integration-2026-11-02/copy_backup.sh user@independent-host
   ```

   This remains NOT RUN. Select a new destination directory if an earlier
   partial copy exists, through a reviewed procedure; do not erase it.
4. Retain the remote checker result, transfer exit codes, and remote filesystem
   identity. Confirm both full archive hashes and both manifest hashes against
   the original pinned values in check_archives.py. All 20,320 member checks
   must pass; do not use a local-only checksum as remote evidence.
5. A second read of the retained remote copy should reproduce both archive
   hashes. Pair that read-back record with the independently confirmed storage
   identity. Only then append a resolution to unsure.md.
6. Preserve the new review/proposal records separately and decide how to back
   up the full binary/container/controller evidence. The curated archives must
   not be described as a complete system backup.

Evidence: results/ops-readiness/review-2026-11-02/archive-check.json and
backup-controls.json. No secret values were printed.
