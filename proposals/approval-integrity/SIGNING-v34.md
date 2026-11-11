# Stage 9 signing experiment under v3.4 (prepared; nothing here has run)

Installed: main `f4f8a68c1e226c5ac45d8336598cd6b9e021298a` (#24), lock
`9bf8f905c9359cd6e5f926657ff434354b80028f45417f962635d6ee86284c90`. Approved lineage:
#24 → #23 → #21 → ratified baseline `19c4896b` (U149). The procedure is the EXIT part of
`proposals/provenance-hosted-v33/INSTALL.md` with these changes.

## Changes from the v3.3 procedure

1. **Lock:** use `9bf8f905…` everywhere `a809f701…` appears.
2. **Source commit C:** an approved main merge whose lineage passes (today `f4f8a68c`).
   Later merges to main do not change C's lineage, but every one must be an approved,
   non-bypass PR, or later releases fail.
3. **Verifier token:** owner-held, read-only, limited to `mack-dot/forge` (Contents,
   Pull requests, Actions, Metadata: read). In the verifier's environment only. Never
   given to the agent. The exposed B3 token must be revoked (owner attested "done").
4. **Lineage cost:** each positive `release.verify` makes about 25 GitHub API calls. On
   2026-10-29, GitHub returned intermittent HTTP 503 on `pulls/N` (3 of 4 audit runs).
   A 503 gives `GITHUB_HTTP_STATUS:503`, so the EXIT is `not_established` (exit 1), never
   a pass. Re-run that case; keep every attempt.

## Recommended order (each step is its own authorization)

1. **No-signing rehearsal at v3.4** (dispatch `provenance.yml`, variable unset): a new
   request at C, run name = challenge, sign job skipped, then `verify_rehearsal.py`
   checks with the installed code. Cost: about 36 minutes; nothing public is signed.
   It shows that the hosted path works with the new lock before any permanent Rekor
   entry exists.
2. **Signing experiment:** a new request at C; the owner sets `FORGE_SIGNING_AUTHORIZED`,
   dispatches R1 (`provenance.yml`) and R2 (`provenance-negative.yml`), then deletes
   the variable. Public, permanent effect: 6 Rekor entries under
   `provenance.yml@refs/heads/main` and 1 under `provenance-negative.yml@refs/heads/main`.
3. **EXITs:** `write_controller_config.py` with lock `9bf8f905…`, then the six cases
   through the bootstrap, `deployed-identity` last. Acceptance: each EXIT `passed` with
   harness exit 0. `end_to_end` stays false.
