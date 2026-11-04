# Preserved records

All small command, proof, failure and inspection records are copied without
changing their bytes. Large HOL debug heaps remain in the original local
records and the private raw archive. Their hashes are in
`omitted-debug-heaps.json`; no failed proof history was deleted.

Archive: `/Users/mackianni/forge-backups/forge-refund-compiler-relation-2026-11-04-0001.tar.gz`.
SHA256: `ff3e243b043e7bfc148dd3704564b77319b7af3f91efdbc1123712fb209cca7a`.
Size38757739 bytes; mode0600. All100 members were read and their hashes checked;
actual exit0. The archive excludes its later validation and commit records.
This is a local recovery archive, not evidence of an independent device copy.

The first postflight comparison returned1 because it used the main Git worktree
against the baseline from the owner workspace. Six gate/script paths differ
between those workspaces. That comparison does not establish a change during
this experiment. The corrected check used the original owner workspace and all
30 frozen hashes matched:exit0. Both outcomes are preserved. The main Git and
pinned CakeML tracked diffs were clean. No source was edited to make the check
pass. See `postflight-location-error.json` and `original-inputs-postflight.json`.

Parent record commit:d0269c051390ffe76b41ba1e522568870f3a4f83, local only.
The parent model report and all its recorded failures remain unchanged.
`SHA256.json` protects review-packet identity; it is not producer authentication.
